# Changelog – PowerEverything3

Format orientiert sich an [Keep a Changelog](https://keepachangelog.com/).
Einträge chronologisch absteigend (neueste oben). Jeder Eintrag entspricht
genau einem Inkrement (= einem Commit oder einer eng zusammengehörigen
Commit-Serie). Roadmap-Änderungen (KICKOFF Phase 1 Punkt 2a), Reflexions-Refreshs und
Post-Mortems erhalten einen kurzen Eintrag ohne I#.

Nicht alle Sektionen sind in jedem Eintrag nötig — leere Sektionen weglassen.

Die Änderungshistorie **vor** I1 (SDK-Update 3.0.0.9, P/Invoke-Fixes, Beispielskript) steht im README-Abschnitt
„Changelog"; dieses Dokument beginnt mit der Einführung der Projektdokumentation.

---

## 2026-11-03 Öffentlicher Skill `everything-search` (ohne I#, auf Wunsch des Maintainers; Roadmap unverändert)

### Added
- `skills/everything-search/SKILL.md` (englisch, ohne Interna): Nutzung des Moduls, Voraussetzungen, Suchsyntax-Stolperfallen
  mit Messbeleg (runde Klammern gruppieren nicht, `ext:a;b` statt `ext:a|b`, 8.3-Kurzpfade), Prüfungen vor dem Verlassen auf
  Treffer. README (EN/DE) um Abschnitt und Changelog ergänzt, `docs/architecture/PROJECT_LAYOUT.md` um `skills/` und `tests/`.
- I9 (SDK 3.0.1.12 prüfen) in `docs/TODO.md` angelegt.

### Security
- DLL-Befund (2026-11-03): `Everything3_x64.dll` im Repo = SDK 3.0.0.9, Authenticode `Valid` (voidtools PTY LTD), SHA256
  wie in `DEPENDENCIES.md`. Online liegt SDK 3.0.1.12 (HEAD-Abfrage, nicht geladen). Everything 1.5.0.1424b (2026-10-15)
  ändert IPC-Sicherheit und Dienstprüfung — Verträglichkeit mit der 3.0.0.9-DLL ungeprüft (I9).

### Confidence / Ungeprüft
- (a) Nicht getestet: Skill nicht in einer Agentensitzung ausprobiert; Everything 1.5.0.1424b nicht installiert; die
  Aussage „nur Clients derselben Sitzung" stammt aus dem Herstellerchangelog, nicht aus eigener Messung.
- (b) Ungeprüft übernommen: SDK-3.0.1.12-Version und Datum aus Forenbeitrag und HTTP-Header; Inhalt/Version der DLL im ZIP unbekannt.
- (c) Die Syntaxfakten im Skill sind am 2026-11-03 gegen 1.5.0.1423b gemessen (Fix-Eintrag unten); Rangfolge von `|` gegenüber
  Leerzeichen wurde bewusst nicht als Regel aufgenommen. Zusätzlich gemessen: leerer Ordner → 1 Treffer ohne, 0 mit
  abschließendem `\`. Die übrige Kurzreferenz (`wfn:`, `parent:`, `dupe:`, `regex:`, `dm:` …) stammt aus der Everything-Doku und ist nicht gemessen.
- Struktur-Check: `validate_project_docs.sh` nicht ausgeführt; Advocatus-Diaboli-Gate manuell im Chat. Security-Sweep laut
  `STATE.md` seit 2026-10-25 fällig, nicht durchgeführt.

---

## 2026-11-03 Fix – `Find-Files -Extensions` (GitHub-Issue #1)

### Fixed
- `Everything3-PowerShell-Wrapper.psm1` (`Find-Files`): Die Endungs-Suche wurde als `Pattern (ext:a|ext:b)` gebaut und lieferte
  unter Everything 1.5.0.1423b **0 Treffer** (runde Klammern gruppieren dort nicht; Gruppierung ist `< >`). Jetzt
  `Pattern ext:a;b`, führende Punkte werden entfernt. Der Vorschlag aus dem Issue (`ext:a|b`) wurde bewusst nicht
  übernommen: `|` bedeutet dort „`ext:a` ODER Name enthält `b`" und lieferte im Test `docxlist.xml` und
  `report_docx_notes.txt` als Fehltreffer.

### Added
- `tests/Integration/FindFiles.Extensions.Integration.Tests.ps1` (Tag `Integration`, 6 Fälle, eigenes Fixture unter
  `$env:TEMP`, Erwartung aus dem Dateisystem als Orakel; wird ohne laufendes Everything übersprungen). Vor dem Fix: 3 rot
  (Assertion `Expected @('a.pdf', …), but got $null`), nach dem Fix: 6 grün.

### Confidence / Ungeprüft
- (a) Nicht getestet: Everything 1.5.0.1409a (Instanz `1.5a`, Pipe war nicht erreichbar) und alle anderen Builds; Verhalten mit
  Pattern, die selbst `|` auf oberster Ebene enthalten, ist nur durch einen Fall belegt (kein Unterschied zu `<Pattern>`-Klammerung gemessen).
- (b) Das Issue meldet Version „1.5a"; ob der Fehler dort identisch auftritt, ist nicht belegt.
- (c) Pester-Harness (`tests/RequiredModules.psd1`) gibt es noch nicht (I2); der Test lief mit Pester 5.7.1 direkt.
- Struktur-Check: `validate_project_docs.sh` nicht ausgeführt (Template-Repo nicht geprüft), Checks manuell offen.

---

## 2026-10-11 I1 – Projektdokumentation initialisiert (docs_template-Baseline)

### Added
- `docs/` nach docs_template v27@5ce0f84, Stack `powershell-automation`, keine Overlays; Conditional-Dateien
  `architecture/REMOTE_EXECUTION.md`, `operations/TASK_SCHEDULER.md` und `architecture/DOMAIN_MODEL.md` entfernt
  (Bedingung trifft nicht zu), `testing/INTEGRATION_TESTS.md` projektspezifisch behalten.
- Feature-Dokumente `docs/features/EVERYTHING_SEARCH.md` (Modul) und `docs/features/ARCHIVE_CLEANUP.md` (Beispielskript).
- Einstiegsdateien `AGENTS.md` und `CLAUDE.md` im Repo-Root (Zeiger auf `docs/KICKOFF.md`).
- Interna-Hook `tools/git-hooks/pre-commit` + `commit-msg` (öffentliches Repository, `CONVENTIONS_COMMON.md` 3.1).
- Inkrementplan I2–I7 in `docs/TODO.md` aus den beim Lesen des Codes gefundenen Schwachstellen.

### Changed
- Vorab-Commits (eigene `chore:`-Commits): `.gitattributes` mit `* text=auto eol=lf` (Arbeitsbaum auf LF normalisiert;
  der Index war bereits LF) und `*.dll binary`; `.gitignore` um Stack-/Secret-Muster, `/docs/local/` und
  `/.internal-terms` ergänzt.

### Security
- Security-Currency-Abgleich beim Init (Stand 2026-10-11): PowerShell-Lifecycle und -CVEs, 7-Zip-CVEs,
  Everything-Dienst CVE-2025-12683, `Send-MailMessage`-Status — Befunde datiert in
  `docs/security/DEPENDENCY_AUDIT.md`, Bedrohungen in `docs/security/THREAT_MODEL.md`.
- Gemessene Ausgangslage Gate 1 (PSScriptAnalyzer 1.25.0, `Invoke-ScriptAnalyzer -Path . -Recurse -Severity Warning, Error`):
  149 Befunde = 146 Warnungen + 3 `TypeNotFound`-Hinweise. Verteilung: `PSAvoidUsingWriteHost` 112,
  `PSUseDeclaredVarsMoreThanAssignments` 13 (davon 12 in der Konfigurationsvorlage — erwartbar, die Variablen nutzt das
  Skript), `PSUseSingularNouns` 7, `PSUseBOMForUnicodeEncodedFile` 5, `PSUseToExportFieldsInManifest` 3,
  `TypeNotFound` 3, `PSAvoidUsingEmptyCatchBlock` 2, `PSUseShouldProcessForStateChangingFunctions` 2,
  `PSAvoidOverwritingBuiltInCmdlets` 1, `PSReviewUnusedParameter` 1 (Fehlalarm: `$SmtpCredential` wird im Skript-Scope genutzt).
- Beim Init reproduziert (eigene `pwsh`-Prozesse, ohne Suche): direkter `.psm1`-Import scheitert (`TypeNotFound`,
  KNOWN_ISSUES K1); `$env:PATH` bleibt nach `Remove-Module` verändert (K2); exportiert werden genau die fünf
  öffentlichen Funktionen, keine Variablen. `Everything3_x64.dll`: Authenticode `Valid`, Signer voidtools PTY LTD,
  Dateiversion 3.0.0.9, mit Zeitstempel (Signer-Zertifikat selbst seit 2026-05-21 abgelaufen).

### Confidence / Ungeprüft
- (a) Nicht getestet: keine Suche gegen Everything ausgeführt, Beispielskript nicht gestartet (Admin-/AD-/SMTP-Abhängigkeiten);
  Aussagen zu Phasen und Mailverhalten stammen aus dem Code-Lesen.
- (b) Ungeprüft übernommen: README-Angaben „getestet mit PowerShell 7.5.2/7.6 und Everything 1.5.0.1423b";
  CVE-Fix-Stände für PowerShell 7.6.5 stammen aus Drittquellen (MSRC-Bestätigung offen); betroffene Versionen von
  CVE-2025-12683 sind öffentlich nicht angegeben. K3 (Puffer 1024 Zeichen) ist eine Vermutung aus dem Code.
- (c) Alle Quelldateien vollständig gelesen; die Template-Prinzipien unter `docs/principles/` unverändert übernommen
  (nur `LOGGING.md` projektspezifisch ergänzt), nicht einzeln gegen das Projekt geprüft.
- Struktur-Check: `validate_project_docs.sh docs --stack powershell-automation` → Exit 0.

### Lessons Learned
- PowerShell-Klassen mit Add-Type-Typen aus einem NestedModule nur über das Manifest importierbar — Scope: generisch-stack
  Backport-Ziel: `stacks/powershell-automation/CONVENTIONS.md` §3 | Status: offen
  Referenziert eine Klasse im RootModule einen `Add-Type`-Typ aus einem NestedModule, scheitert der direkte Import der
  `.psm1` mit `TypeNotFound`; Doku und Beispiele müssen die `.psd1` importieren.
  → Spiegel-Eintrag in `LESSONS_LEARNED.md` als `## L1:`.
