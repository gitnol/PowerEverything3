# TODO – PowerEverything3

Einzige Quelle des Inkrementplans (KICKOFF verweist nur hierher). Pro Inkrement: Aufgaben und — falls über die
Standard-DoD hinaus nötig — zusätzliche Kriterien. Ein Inkrement gilt erst als erledigt, wenn die Standard-DoD
**und** seine eigenen Kriterien erfüllt sind.

Parkplatz für noch unspezifizierte Ideen: `BACKLOG.md`.
Bekannte Bugs ohne aktiven Fix: `KNOWN_ISSUES.md`.

---

## Standard-Definition of Done (gilt für jedes Inkrement — nicht abhaken, sie bleibt stehen)

- Code-Änderungen abgeschlossen, kein TODO-/FIXME-Kommentar offen
- Quality Gates grün (`CONVENTIONS_COMMON.md` §5; Befehle in `CONVENTIONS.md`)
- Integration-Tests grün, falls relevant
- Security-Checkliste aus `CONVENTIONS.md` durchgegangen (falls der Stack eine liefert)
- Trigger-Matrix in `KICKOFF.md` Phase 3a geprüft → alle relevanten Docs aktualisiert
  (`architecture/OVERVIEW.md`, `features/`, `architecture/`, `security/`, `GLOSSARY.md`, `KNOWN_ISSUES.md`, `LESSONS_LEARNED.md`)
- `STATE.md`: Tabellenzeile + „Nächster Schritt"-Abschnitt aktualisiert
- `CHANGELOG.md`: neuer Abschnitt mit Datum + Inkrement-Titel + Sections
  (Added / Changed / Fixed / Removed / Security / Confidence / Ungeprüft / Lessons Learned)
- KICKOFF Phase 3b vollständig (Struktur-Check, TODO-Verschiebung, Advocatus-Diaboli-Gate)
- Commit erstellt (`<type>(<scope>): <desc>`); Commit-Hash in `STATE.md` eingetragen

---

## Aktuell (Hohe Priorität)

### I2: Modul-Ladepfad und Manifest härten + Pester-Harness

Anlass: `Everything3SDK.psm1` Zeile 10 stellt das Modulverzeichnis prozessweit vor `$env:PATH` (beim Init verifiziert:
nach `Remove-Module` nicht zurückgesetzt, jeder `-Force`-Import wiederholt es) — Verstoß gegen `CONVENTIONS.md` §4.
Die DLL wird per `LoadLibrary` ohne Integritätsprüfung geladen, obwohl das Beispielskript als Administrator läuft
(`security/THREAT_MODEL.md` §1). Das Manifest exportiert per `'*'` und deklariert weder Mindestversion noch Edition
oder Architektur (KNOWN_ISSUES K2).

**Aufgaben:**

- [ ] Pester-Harness anlegen: `tests/RequiredModules.psd1` (Pester 5.7.1 gepinnt), `tests/Module.Tests.ps1`;
      Gate-Befehle aus `CONVENTIONS.md` §9 laufen.
- [ ] Test (behaviorales Rot): Import über die `.psd1` lässt `$env:PATH` unverändert → PATH-Zeile entfernen
      (`LoadLibrary` mit vollem Pfad reicht; Bindung der `DllImport`s an das geladene Modul per Live-Smoke belegen).
- [ ] Test (behaviorales Rot): Manifest deklariert `PowerShellVersion = '7.0'`, `CompatiblePSEditions = @('Core')`,
      `ProcessorArchitecture = 'Amd64'`, `FunctionsToExport` = die fünf öffentlichen Funktionen,
      `CmdletsToExport`/`AliasesToExport`/`VariablesToExport` = `@()`.
- [ ] Test (behaviorales Rot): DLL-Prüfung vor `LoadLibrary` — `Get-AuthenticodeSignature` muss `Valid` mit Signer
      voidtools liefern, sonst `throw` mit klarer Meldung (Fail-Fast); Prüflogik so schneiden, dass sie mit einer
      unsignierten Kopie in einem Temp-Verzeichnis testbar ist.
- [ ] README (EN/DE) „VSCode Considerations" anpassen (PATH-Handling entfällt).

**Zusätzliche DoD** (nur, was über die Standard-DoD hinausgeht):

- [ ] Gate 1: keine neuen PSScriptAnalyzer-Befunde gegenüber der Init-Messung (`CHANGELOG.md` I1); `PSUseToExportFieldsInManifest` (3) behoben.
- [ ] Live-Smoke `Test-EverythingConnection` gegen eine lokale Instanz nach dem Entfernen der PATH-Zeile erfolgreich (Ausgabe im Confidence-Block).

### I3: Beispielskript – Konfiguration als Daten statt Code (ADR)

Anlass: `Find-ArchivesWithExtractedFolder.ps1` Zeile 124–125 dot-sourct die Konfigurationsdatei im Skript-Scope. Sie
wird damit als Code mit Administratorrechten ausgeführt und kann außerdem CLI-Parameter wie `$Live` oder `$SendMail`
still überschreiben (`security/THREAT_MODEL.md` §2, `architecture/CONFIGURATION.md`).

**Aufgaben:**

- [ ] ADR-001 „Konfigurationsformat des Beispielskripts": `.psd1` über `Import-PowerShellDataFile` (nur Daten) vs.
      dot-sourced `.ps1`; Migrationspfad für bestehende `*.config.ps1`.
- [ ] Test (behaviorales Rot): eine Konfigurationsdatei mit ausführbarem Ausdruck wird nicht ausgeführt.
- [ ] Test (behaviorales Rot): die Konfiguration kann `-Live`, `-SendMail`, `-Path` nicht überschreiben.
- [ ] Erlaubte Schlüssel als Liste, Typ-/Bereichsprüfung beim Laden (Fail-Fast); unbekannter Schlüssel → Fehler.
- [ ] `*.config.example.*`, README (EN/DE) und `docs/features/ARCHIVE_CLEANUP.md` nachziehen.

**Zusätzliche DoD** (nur, was über die Standard-DoD hinausgeht):

- [ ] Tests laufen ohne Administratorrechte und ohne Mailversand (`-SearchMode Scan` auf ein Temp-Fixture, kein `-SendMail`).

### I4: Beispielskript – 7-Zip-Mindestversion und Timeout für die Archivprüfung

Anlass: Die Inhaltsprüfung lässt `7z.exe` fremde Archive von Dateifreigaben mit Administratorrechten parsen
(`Invoke-SevenZip`, Zeile 184–205; `.tar.gz`/`.tar.xz` werden per `x -so` dekomprimiert). 7-Zip 26.02–26.04 schließen
u. a. CVE-2026-14266 (XZ-Heap-Overflow, RCE); `WaitForExit()` hat keinen Timeout (`security/THREAT_MODEL.md` §3).

**Aufgaben:**

- [ ] Test (behaviorales Rot): ein hängender 7-Zip-Aufruf (Stub-Prozess) wird nach einem Timeout beendet und als
      „content check N/A (timeout)" gemeldet statt den Lauf zu blockieren.
- [ ] 7-Zip-Version (`FileVersion` von `7z.exe`) prüfen; unter der Mindestversion (Stand Sweep 2026-10-11: 26.04)
      Nicht-ZIP-Formate als `N/A` melden und warnen.
- [ ] Mindestversion als `$script:`-Konstante mit Quelle/Datum; `docs/architecture/DEPENDENCIES.md` verweist darauf.

**Zusätzliche DoD** (nur, was über die Standard-DoD hinausgeht):

- [ ] Grund des `N/A` steht in der CSV-Spalte `ContentDetails`.

---

## Mittlere Priorität

### I5: Integrationstests (read-only) gegen eine lokale Everything-Instanz

**Aufgaben:**

- [ ] `tests/Integration/Search.Integration.Tests.ps1` (Pester-Tag `Integration`): Fixture-Ordner unter `$env:TEMP`
      anlegen, warten bis Everything ihn indexiert hat (mit Timeout), dann `Name`, `Path`, `Extension`, `Size`,
      `DateModified`, `Attributes`, Sortierung, `-Offset` und `-MaxResults 0` prüfen.
- [ ] Erwartungswerte aus dem Dateisystem (`Get-Item`) als Orakel, nicht aus eigener Annahme
      (`principles/ORACLE_AND_RATCHET.md`).
- [ ] Fall „Text-Property länger als 1023 Zeichen" (KNOWN_ISSUES K3) als Test aufnehmen.
- [ ] Läuft Everything nicht: Tests mit klarer Meldung überspringen, nicht scheitern.

### I6: Beispielskript testbar machen + Unit-Tests der reinen Funktionen

**Aufgaben:**

- [ ] Funktionen vom Ablauf trennen (Einstiegsskript nur `param()` + Ablauf, Funktionen dot-source-bar), Verhalten unverändert.
- [ ] Charakterisierungstests mit Mutationsprüfung (`KICKOFF.md` Phase 2): `Get-MailPath`, `ConvertTo-SharePath`,
      `Get-ShareBasePaths`, `Get-DataShares -Raw`, `ConvertTo-FileLink`, `Test-MailAddress`, `New-MailBody`
      (HTML-Encoding), `Compare-ArchiveWithFolder` mit ZIP-Fixtures (identisch / geändert / gemeinsamer Wurzelordner).

### I7: Mailversand – Transport-Entscheidung (ADR) und TLS-Default

**Aufgaben:**

- [ ] ADR: `Send-MailMessage` (laut Microsoft obsolet, garantiert keine sichere Verbindung) vs. MailKit vs. Microsoft Graph.
- [ ] Default von `$SmtpUseSsl` festlegen (heute `$false`, Port 25) und begründen.
- [ ] `docs/architecture/CONFIGURATION.md`, `docs/operations/SETUP.md`, README nachziehen.

### I9: SDK3 auf 3.0.1.12 prüfen und ggf. aktualisieren

Anlass (2026-11-03): Das Repo liefert `Everything3_x64.dll` aus SDK 3.0.0.9 (`Everything-SDK-3.0.0.9.zip`, 515026 Byte,
Stand 2025-10-11). Auf voidtools.com liegt `Everything-SDK-3.0.1.12.zip` (524889 Byte, Last-Modified 2026-10-16 — Header
per HEAD-Abfrage gelesen, ZIP nicht geladen). Everything 1.5.0.1424b (2026-10-15) ändert laut Changelog die IPC-Sicherheit
(nur Clients derselben Sitzung) und prüft die Vertrauenswürdigkeit des Dienstes; der Installer entfernt die Instanz `1.5a`.
Ob die 3.0.0.9-DLL damit weiter funktioniert, ist ungeprüft; lokal läuft 1.5.0.1423b.

**Aufgaben:**

- [ ] ZIP in ein leeres Verzeichnis laden (Download vorher freigeben), SHA256, Authenticode und `FileVersion` der DLL prüfen.
- [ ] `Everything3.h` der neuen Version gegen die Signaturen in `Everything3SDK.psm1` abgleichen (Änderungen seit 3.0.0.9).
- [ ] Integrationstests (I5 bzw. `tests/Integration/`) und `Test-EverythingConnection` gegen 1.5.0.1423b **und** 1.5.0.1424b.
- [ ] DLL, SHA256, Signaturstatus in `docs/architecture/DEPENDENCIES.md` und README („Tested with“) nachziehen;
      Security-Sweep-Befund (`docs/security/DEPENDENCY_AUDIT.md`) datiert eintragen.

---

## Niedrige Priorität

- [ ] `Everything3-Examples.ps1`: Import-Hinweis im Kopf auf die `.psd1` korrigieren (KNOWN_ISSUES K1); beim
      Ausführen nicht alle Beispiele (inkl. Systemweit-Suchen) sofort starten, sondern nur Funktionen definieren.
- [ ] README: „Tested with" aktualisieren und PowerShell 7.6 (LTS) empfehlen (7.4/7.5 Support-Ende 2026-11-10).
- [ ] Encoding der Modulquellen entscheiden: ASCII vs. UTF-8 mit BOM (`PSUseBOMForUnicodeEncodedFile`, 5 Dateien).
- [ ] `Test-EverythingConnection`: Ausgabe über `Write-Information`/Objekt statt `Write-Host`.
- [ ] Advocatus-Diaboli-Hook (`.claude/settings.json`, `KICKOFF.md` Phase 1 Punkt 7) nach Freigabe durch den
      Maintainer einrichten; bis dahin das Gate vor jedem Commit manuell ausführen.

### I8: Modulvertrag an `architecture/MODULE.md` und CONVENTIONS (v28) angleichen

Anlass: Das Template-Update auf v28 (2026-10-22) brachte `architecture/MODULE.md` und neue Regeln in
`CONVENTIONS.md` §2/§3. Der Code weicht dort ab, wo I2 nicht schon ansetzt (Stellen in `MODULE.md` und
`CONVENTIONS.md` als „offen" markiert). Nach I2 einplanen — mehrere Punkte bauen auf dessen Manifest und Harness auf.

**Aufgaben:**

- [ ] `Set-StrictMode -Version 3.0` am Anfang von `Everything3SDK.psm1` und `Everything3-PowerShell-Wrapper.psm1`;
      Unit- und Integrationstests laufen danach grün.
- [ ] `Export-ModuleMember` am Ende von `Everything3-PowerShell-Wrapper.psm1` entfernen (Liste nur im Manifest);
      Modultest „exportiert genau die fünf Funktionen" bleibt grün.
- [ ] DLL-Prüfung mit `MODULE.md` „Native Binärdateien" abgleichen: SHA-256 bei jedem Import im Modulcode,
      Authenticode beim Austausch der DLL (I2 plant Authenticode bei jedem Import); danach steht die Prüfsumme nur im
      Code, `architecture/DEPENDENCIES.md` nennt Herkunft, Version und Signaturergebnis.
- [ ] DLL per `[System.Runtime.InteropServices.NativeLibrary]::Load` laden statt über den eigenen `Kernel32`-Typ
      (`LoadLibrary` ohne `CharSet` bindet die ANSI-Variante).
- [ ] `[CmdletBinding()]` an `Get-PropertyId` und `ConvertFrom-FileTime`; `[OutputType()]` an den fünf öffentlichen
      Funktionen.
- [ ] Installation in einen versionierten Ordner (aus einem Commit, Modulpfad für alle Benutzer) in README (EN/DE)
      und `operations/SETUP.md` beschreiben.
- [ ] Entscheiden: Template-Aufbau (`Public/`, `Private/`, `bin/`) übernehmen oder die Abweichung in `MODULE.md` als
      bewusst festhalten.

**Zusätzliche DoD** (nur, was über die Standard-DoD hinausgeht):

- [ ] Keine „offen"-Markierung mit Verweis auf I8 mehr in `MODULE.md` und `CONVENTIONS.md`.

---

## Abgeschlossen

- I1 Projektdokumentation initialisiert (docs_template-Baseline) — [ABGESCHLOSSEN 2026-10-11]
