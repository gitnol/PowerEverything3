# Backlog – PowerEverything3

Parkplatz für Ideen, Verbesserungen und Aufgaben, die noch **nicht** für ein
konkretes Inkrement priorisiert sind.

**Abgrenzung:**

- `TODO.md` = aktuelle, priorisierte Arbeit mit Definition of Done
- `BACKLOG.md` = noch nicht eingeplant, kein DoD nötig
- `KNOWN_ISSUES.md` = bekannte Probleme mit Workaround, nicht aktiv geplant

Wenn ein Backlog-Punkt für ein Inkrement vorgesehen wird → Verschiebung von
`BACKLOG.md` nach `TODO.md` (mit DoD ergänzen).

---

## Ideen / Features

- Veröffentlichung in der PowerShell Gallery — Manifest-Metadaten (`Description`, `ProjectUri`, `LicenseUri`, `Tags`)
  fehlen; Voraussetzung sind die Manifest-Fixes aus I2 und eine Klärung, ob die mitgelieferte DLL weiterverteilt werden darf.
- Treffer als Pipeline-Stream statt Array ausgeben — `-MaxResults 0` sammelt heute alle Treffer im Speicher
  (`Search-Everything` → `$results.ToArray()`); bei Abfragen wie `*` auf großen Servern teuer.
- `es.exe` (Everything-Kommandozeile) als zweites Orakel für Integrationstests (I5) — nur, wenn es auf Testhosts verfügbar ist.
- Schichtregel als Pester-AST-Test: Beispielskripte rufen nur exportierte Funktionen auf, nie `[Everything3SDK]`
  direkt (`docs/architecture/PROJECT_LAYOUT.md`).
- 8.3-Kurzpfade in Queries: `Search-Everything` liefert dafür still 0 Treffer (von einem Probelauf als leicht mit „Ordner leer“
  verwechselbar gemeldet) — bei einem Muster wie `~1` im Pfad warnen oder per `GetLongPathNameW` auflösen (Skill-Probelauf 2026-11-03).
- Verständliche Fehlermeldungen: SDK-Fehlercodes (z. B. 0xE0000002 pipe not found, 0xE0000003 disconnected) übersetzen; bei 0xE0000003 auf die Sitzungsbindung von Everything ab 1.5.0.1424b hinweisen (`docs/KNOWN_ISSUES.md` K6).

---

## Refactoring-Kandidaten

- Eigene Fehlertypen statt String-`throw` (heute deutsche Meldungstexte, keine Kategorie) — Auslöser: erste Funktion,
  deren Aufrufer Fehlerarten unterscheiden muss (`docs/architecture/ERROR_HANDLING.md`).
- `Everything3Client` ohne Finalizer/`IDisposable`-Muster — vergessene `Disconnect-Everything` halten die
  Pipe-Verbindung bis Prozessende; Auslöser: Nutzung in langlaufenden Sessions/Diensten.
- Beispielskript (737 Zeilen) in Funktionsmodul + schlankes Einstiegsskript zerlegen — Teil von I6, darüber hinaus
  ggf. eigenes Modul `ArchiveCleanup`.

---

## Technische Schuld

- Sprachmix: Meldungen und Kommentare im Modul Deutsch, im Beispielskript und README Englisch — Nutzer sehen gemischte
  Fehlermeldungen; wird teurer, je mehr Tests Meldungstexte prüfen.
- `ModuleVersion = '0.1.0'` wurde trotz Verhaltensänderungen (z. B. `-CheckExists`, README-Changelog) nie erhöht;
  README-Changelog hat keine Versionsnummern — ohne Versionen keine sauberen Rollbacks/Release-Notes.
- PSScriptAnalyzer-Altbefunde (Init-Messung 146 Warnungen, Details `CHANGELOG.md` I1) — Großteil `PSAvoidUsingWriteHost`
  in `Everything3-Examples.ps1`; ohne Abbau bleibt Gate 1 nur als „keine neuen Befunde" prüfbar.

---

## Template-Evolution / Stack-Lücken

Hier landen Projekt-Charakteristiken, für die kein passender Stack/Overlay
existierte. Jeder Eintrag ist eine potenzielle Template-Erweiterung — so sind
z.B. `react-web` und die document-intelligence-Overlays entstanden.

- Stack-Lücke: PowerShell-**Modul-Bibliothek** mit mitgelieferter nativer DLL (P/Invoke) — `powershell-automation`
  ist auf Task-Scheduler-Automation und REST-Clients ausgerichtet; es fehlen Vorgaben zu Modul-Manifest
  (`PowerShellVersion`, `CompatiblePSEditions`, `ProcessorArchitecture`, explizite Exporte), PSGallery-Publishing,
  Auslieferung/Signaturprüfung nativer Binaries und Interop-Tests gegen eine lokale Dienst-Instanz — 2026-10-11 PowerEverything3

---

## Verworfen (mit Begründung)

Punkte, die geprüft und bewusst nicht weiterverfolgt wurden. Bleiben als Spur
sichtbar, damit derselbe Punkt nicht in jeder Session erneut diskutiert wird.

- (noch keine Einträge)
