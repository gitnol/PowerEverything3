# Fehlerbehandlung – PowerEverything3

Wo und wie Fehler erkannt, propagiert, behandelt und gemeldet werden.
Konsolidiert Regeln, die sonst in `CONVENTIONS.md`, `principles/FAIL_FAST.md`,
`principles/CONTRACTS.md` und `principles/LOGGING.md` verstreut sind.

---

## Fehler-Hierarchie (Ist-Zustand)

- Das Projekt hat **keine eigenen Fehlertypen.** Modul und Beispielskript werfen terminierende Fehler per
  `throw "<Text>"` (Modul: deutsche Texte, Beispielskript: englische).
- Native Fehler kommen als Zahl aus `Everything3_GetLastError()` und werden in den Meldungstext eingebaut
  („Fehler beim Verbinden … Fehler: <Code>", „Suche fehlgeschlagen mit Fehler: <Code>").
- Ziel (`docs/BACKLOG.md` → Refactoring): `ErrorRecord` mit Kategorie (`ConnectionError`, `InvalidArgument`,
  `ObjectNotFound`) und stabiler `FullyQualifiedErrorId`, damit Aufrufer und Tests Fehlerarten unterscheiden können,
  ohne Meldungstexte zu parsen.

---

## Boundary vs. interne Fehler

| Ebene | Verhalten im Projekt |
|---|---|
| **Boundary Modul** (exportierte Funktionen) | Ungültiger Zustand → `throw` (z. B. „Client ist nicht mit Everything verbunden"). `Connect-Everything` versucht bei leerem Instanznamen zusätzlich die Instanz `1.5a`, erst dann `throw`. `Test-EverythingConnection` fängt alles und gibt Hinweise per `Write-Host` aus (Diagnosefunktion, wirft nie). |
| **Interop** (`Everything3SDK.psm1`) | DLL nicht ladbar → `throw` beim Modul-Import (Fail-Fast). `Add-Type` mit `-ErrorAction Stop`. |
| **Property-Abruf je Treffer** | Fehler einzelner Properties → `Write-Warning`, der Treffer bleibt erhalten. Unbekannter Property-Name → `Write-Warning`, Property wird ignoriert. |
| **Boundary Beispielskript** | `Set-StrictMode -Version 3.0`, `$ErrorActionPreference = 'Stop'`; Konfigurationsfehler (`No -Path`, `No valid path`, `-AllShares` ohne Freigaben) → `throw` → Exit-Code 1 bei `pwsh -File`. Transcript wird im `finally` beendet. |
| **Pro-Element-Fehler im Beispielskript** | Zugriffsfehler beim Scan, `Get-Acl`-Fehler, unbekannte SIDs, fehlgeschlagener Mailversand → `Write-Warning`, Lauf geht weiter; Mail-Fehler werden gezählt („failed: N"). |
| **Everything nicht nutzbar (Beispielskript)** | `-SearchMode Auto` → Warnung und Fallback auf Dateisystem-Scan; `-SearchMode Everything` → `throw`. Nicht indizierter Pfad: `Auto` scannt, `Everything` überspringt mit Warnung und Zusammenfassung am Ende von Phase 1. |

---

## Was geloggt und was gerethrowt wird

- **Boundary** fängt → loggt → konvertiert in Antwortformat. Das Level richtet sich nach der Art des Fehlers
  (Level-Semantik: `docs/principles/LOGGING.md`):
  - **unerwartet** (Programmierfehler, Infrastruktur ausgefallen) → terminierender Fehler; PowerShell gibt den
    Fehlerdatensatz (Meldung + Position) aus, im Beispielskript landet er im Transcript. Ein eigener Stacktrace-Log
    (`$_.ScriptStackTrace`) existiert nicht;
  - **erwartet, fachlich** (Pfad fehlt, Zugriff verweigert, Archiv nicht lesbar) → `Write-Warning` ohne Stacktrace.
- **Mittelschichten** lassen Fehler durch — **kein doppeltes Logging** desselben Fehlers.
- **Kein leeres `catch {}` ohne Grund.** Stand Init gibt es zwei leere `catch`-Blöcke im Beispielskript
  (Zeile 172: LDAP-Lookup — danach folgt eine Warnung; Zeile 200: Abbruch des Pipe-Kopierens zwischen zwei
  7-Zip-Prozessen) → Kommentar ist vorhanden, Logging auf Debug-Niveau fehlt (PSScriptAnalyzer
  `PSAvoidUsingEmptyCatchBlock`).

---

## Retry-Strategien

- Keine Retries im Projekt. Einziger Fallback: `Connect-Everything` probiert genau eine zweite Instanz (`1.5a`).
- Mailversand wird nicht wiederholt (fehlgeschlagene Mails nur gezählt) — ein erneuter Lauf erzeugt die Mail neu.

---

## Feindliche Eingaben — kein Absturz an Systemgrenzen

Alles, was von außen kommt, ist feindlich: Archive und Ordnernamen auf Dateifreigaben, Suchtexte, Konfiguration,
Antworten der DLL. Ergebnis ist **immer ein behandelbarer Fehler**, nie ein Prozessabsturz, ein hängender Prozess oder
verlorene Nutzerdaten.

> Abgrenzung zu [[FAIL_FAST]]: Fail Fast bricht die **Operation** früh und laut ab.
> Diese Regel sorgt dafür, dass dabei nicht der **Prozess** oder die Arbeit des Nutzers
> mitgerissen wird. Abgrenzung zu [[UNTRUSTED_DOCUMENT_CONTENT]]: dort geht es um fremden
> Inhalt im LLM-Prompt (Injection/Fälschung), hier um die Robustheit des Prozesses.

Projektbezug:

- **Native Aufrufe:** Falsche P/Invoke-Signaturen führen zu Speicherfehlern statt Exceptions — deshalb exakte
  Signaturen nach `Everything3.h` und Integrationstests (I5).
- **Fremde Archive:** `Get-ArchiveEntries` fängt Lesefehler und meldet „content check N/A (…)"; ein **hängender**
  7-Zip-Prozess wird heute nicht abgefangen (`WaitForExit()` ohne Timeout) → I4.
- **Ordnernamen in Mails** werden HTML-kodiert (`HtmlEncode`), Links mit `ConvertTo-FileLink` maskiert.
- **Speicher:** `-MaxResults 0` lädt alle Treffer (`docs/KNOWN_ISSUES.md` K5).
- **Jeder Crash-Fix bringt einen kleinen synthetischen Regressionstest mit**, der vor dem
  Fix nachweislich abgestürzt ist (behaviorales Rot, `KICKOFF.md` Phase 2).
- **Robustheitstest über alle Einstiegspunkte**, sobald es Tests gibt: alle exportierten Funktionen (Liste aus
  `(Get-Module Everything3-PowerShell-Wrapper).ExportedFunctions`) mit leeren, falschen und riesigen Parametern
  aufrufen; nur Fehler, kein Absturz/Hänger.

---

## Konvertierungstabelle

| Fehlerfall | Wo | Exit-Code (`pwsh -File`) | Log-Level | Bemerkung |
|---|---|---|---|---|
| DLL nicht ladbar | Modul-Import | `1` (Aufrufer bricht ab) | Fehler | „Fehler beim Laden der nativen DLL" |
| Everything nicht erreichbar | `Connect-Everything` | `1` | Fehler | nach Fallback auf Instanz `1.5a` |
| Suche fehlgeschlagen | `Search-Everything` | `1` | Fehler | enthält `Everything3_GetLastError()` |
| Client nicht verbunden | `Search-Everything` | `1` | Fehler | Programmierfehler beim Aufrufer |
| Unbekannte Property / Property-Fehler | `Search-Everything` | — | Warnung | Treffer bleibt erhalten |
| Kein gültiger Pfad / keine Freigaben | Beispielskript | `1` | Fehler | Konfigurationsfehler |
| Everything nicht nutzbar, `-SearchMode Auto` | Beispielskript | — | Warnung | Fallback Dateisystem-Scan |
| Archiv nicht lesbar/verschlüsselt, kein 7-Zip | Beispielskript Phase 1c | — | — | Status `N/A` in CSV/Mail |
| `Get-Acl`/LDAP/Mailversand scheitert | Beispielskript | — | Warnung | Lauf geht weiter; Mail-Fehler gezählt |

---

## Anti-Pattern

- **`throw` mit reinem Text** statt `ErrorRecord` mit Kategorie — heute Standard im Projekt, Ziel siehe oben.
- **Catch-and-rethrow ohne Mehrwert** — entfernen.
- **Stilles Wegfangen** in der Mitte des Aufruf-Stacks — Fail-Fast wird ausgehebelt.
- **Diagnosefunktion als Fehlerquelle für Automaten:** `Test-EverythingConnection` wirft nie; Skripte, die eine
  Verbindung voraussetzen, prüfen mit `Connect-Everything` selbst.

---

## Pflege

Trigger (siehe `KICKOFF.md` Phase 3a): neue Exception-Klasse / neue Boundary
/ neue Retry-Stelle → diese Datei + Konvertierungstabelle aktualisieren.
