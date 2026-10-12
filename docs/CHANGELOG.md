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
