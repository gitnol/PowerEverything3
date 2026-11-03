# Feature: Everything-Suche aus PowerShell (Modul)

---

## Zweck

Dateien und Ordner in Sekunden über den Index von Everything 1.5 finden und als PowerShell-Objekte mit
ausgewählten Eigenschaften weiterverarbeiten.

---

## Technologie / Abhängigkeiten

- `Everything3-PowerShell-Wrapper.psd1` (Import-Einstieg) mit `Everything3SDK.psm1` (P/Invoke) und `Everything3_x64.dll`
- Laufende lokale Everything-1.5a-Instanz (Named Pipe), PowerShell ≥ 7.0, Windows x64
- Details: `docs/architecture/DEPENDENCIES.md`

---

## Öffentliche Funktionen

| Funktion | Zweck |
|---|---|
| `Connect-Everything [-InstanceName]` | Client öffnen; leerer Name → Standardinstanz, dann Fallback `1.5a` |
| `Search-Everything -Client -Query …` | Suche mit allen Optionen, liefert `[Everything3Result[]]` |
| `Disconnect-Everything -Client` | Client freigeben |
| `Find-Files -Pattern …` | Komfort-Wrapper: verbindet, sucht, trennt |
| `Test-EverythingConnection` | Diagnose (Version, Index geladen, Testsuche) mit Konsolenausgabe |

---

## Parameter

`Search-Everything`:

| Parameter | Typ | Pflicht | Default | Validierung | Beschreibung |
|-----------|-----|---------|---------|-------------|-------------|
| `-Client` | `[Everything3Client]` | Ja | — | muss verbunden sein, sonst `throw` | Verbindung aus `Connect-Everything` |
| `-Query` | `[string]` | Ja | — | — | Everything-Suchsyntax (z. B. `ext:pdf size:>100mb`), wird unverändert übergeben |
| `-MaxResults` | `[int]` | Nein | `1000` | `[ValidateRange(0, [int]::MaxValue)]` | Anzahl Treffer; `0` = alle |
| `-Offset` | `[int]` | Nein | `0` | `[ValidateRange(0, [int]::MaxValue)]` | Start des Viewports (Paging) |
| `-Properties` | `[string[]]` | Nein | `@()` | unbekannte Namen → Warnung | `Name`, `Path`, `FullPath`, `Size`, `Extension`, `Type`, `DateCreated`, `DateModified`, `DateAccessed`, `Attributes` |
| `-SortBy` | `[hashtable]` | Nein | `@{}` | — | `@{ Property = 'Size'; Descending = $true }` |
| `-CheckExists` | Switch | Nein | aus | — | `Exists` per `Test-Path` je Treffer füllen (langsam), sonst `$null` |
| `-MatchCase`, `-MatchWholeWord`, `-MatchPath`, `-Regex` | Switch | Nein | aus | — | Suchoptionen von Everything |

`Find-Files`: `-Pattern` (Pflicht), `-Extensions` (wird zu `Pattern ext:a;b`, führende Punkte werden entfernt), `-IncludeProperties` (Size, DateModified,
DateCreated, Attributes), `-CaseSensitive`, `-Regex`, `-MaxResults`, `-CheckExists`, `-InstanceName`.

---

## Ergebnisobjekt `[Everything3Result]`

| Eigenschaft | Inhalt |
|---|---|
| `FullPath` | vollständiger Pfad (Puffer 32 768 Zeichen) |
| `Name`, `Directory` | aus `FullPath` abgeleitet (`[System.IO.Path]`) |
| `Properties` | Hashtable der angeforderten Eigenschaften; Datumswerte als `[datetime]` (aus FILETIME), `Size` = `$null`, wenn unbekannt (z. B. Ordner) |
| `Exists` | nur mit `-CheckExists` gefüllt |

---

## Geschäftsregeln

- Werden Properties angefordert, fordert das Modul zusätzlich `FullPath` an — sonst liefert das SDK den Pfad nicht.
- `UINT64_MAX` bei `Size` bedeutet „unbekannt" → `$null`; FILETIME `0` oder `UINT64_MAX` → `$null`.
- Sortierung nur nach einer Property; unbekannte Sortier-Property wird still ignoriert.

---

## Kritische Patterns

- Import nur über die `.psd1` (`docs/KNOWN_ISSUES.md` K1).
- Client immer im `finally` trennen; `Find-Files` macht das selbst.
- P/Invoke-Signaturen und Puffergrößen: `docs/CONVENTIONS.md` §2.1.

---

## Bekannte Einschränkungen

| Einschränkung | Ursache | Status |
|---------------|---------|--------|
| Text-Properties evtl. auf 1023 Zeichen begrenzt | Puffer 1024 Zeichen | K3, Klärung in I5 |
| `-MaxResults 0` lädt alle Treffer in den Speicher | Ergebnis wird als Array gesammelt | K5, Akzeptiert |
| Modul-Import ändert `$env:PATH` prozessweit | `Everything3SDK.psm1` Zeile 10 | K2, Fix in I2 |
| Nur lokale Instanz, nur x64, nur PowerShell 7 | SDK3/DLL, Syntax | Akzeptiert (Scope-Grenzen in `docs/architecture/OVERVIEW.md`) |

---

## Bekannte Fallstricke

- Abfragen ohne Einschränkung (`*`) mit `-MaxResults 0` auf großen Indizes sind teuer.
- `-CheckExists` macht pro Treffer einen Dateisystemzugriff — bei Tausenden Treffern langsam.
- Everything-Suchsyntax ist mächtig (`regex:`, Pfadfilter in Anführungszeichen); Suchtexte aus fremden Quellen nur
  bewusst durchreichen, sie können den Suchumfang beliebig erweitern.

---

## Teststrategie

- Unit (ab I2): `tests/Module.Tests.ps1` — Manifest, Exporte, kein `$env:PATH`-Seiteneffekt.
- Integration (I5, Tag `Integration`): `tests/Integration/Search.Integration.Tests.ps1` gegen Temp-Fixtures, Orakel =
  Dateisystem (`Get-Item`); Fälle: Properties, Sortierung, Offset/MaxResults 0, lange Pfade.
- Pester-Beschreibung: `Describe 'Search-Everything' { ... }`
