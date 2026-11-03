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

## 2026-11-03 Skill-Probelauf `everything-search` (Agentensitzung)

### Tested
- Ein frischer Subagent bekam nur den Skill, das Modul und vier Aufgaben an einem Fixture-Ordner (5 Treffer für PDF/DOCX plus
  zwei Köder-Dateien, ein leerer Unterordner, ein Kurzpfad). Alle vier Antworten stimmen mit dem Dateisystem-Orakel überein: 5 Dateien
  (Köder nicht dabei), leerer Ordner ist indexiert (1 Treffer ohne, 0 mit Backslash), Kurzpfad liefert 0, Langpfad 8 Dateien,
  SYSTEM-Task kann nicht suchen (Fallback nötig). Verwendet hat der Agent `ext:pdf;docx`, `Search-Everything` in `try/finally`
  und `GetLongPathNameW`; sein Hilfsordner wurde gelöscht.

### Changed
- `skills/everything-search/SKILL.md` nach den Rückmeldungen des Agenten: Snippet für `GetLongPathNameW` (getestet), Hinweis, dass ein
  Kurzpfad still 0 Treffer liefert, `Search-Everything` als Standardweg, Manifest im Repo-Root, und der Backslash-Befund präzisiert
  (gemessen: ohne `\` Ordner **und** alles darunter = 11, mit `\` nur darunter = 10, mit `file:` = 8) — die alte Formulierung „der Ordner
  selbst“ war ungenau.
- `docs/BACKLOG.md`: Warnung/Auflösung bei 8.3-Kurzpfaden.

### Confidence / Ungeprüft
- (a) Ein Lauf, ein Agent; die Aufgaben schrieb ich in Kenntnis der Fallen, der Agent hatte die Fallenliste im Skill — geprüft ist die
  Verständlichkeit, nicht ob ein Agent die Fallen ohne Skill findet. Andere Modelle ungetestet.
- (b) Die Verbesserungsvorschläge des Agenten (z. B. `Resolve-LongPath` im Modul) sind Vorschläge, nicht gemessen; nur das Snippet und die Zahlen wurden von mir geprüft.

---

## 2026-11-03 Reflexion nach I9/I10 (`KICKOFF.md` Phase 1c)

### Selbstkritik (Advocatus Diaboli, belegt)
- **Positiv:** Der Fix für Issue #1 ging test-first (3 von 6 Tests behavioral rot vor dem Fix, Commit 2f78893); Behauptungen im Skill
  sind gemessen (18 Syntaxfälle, zwei Everything-Versionen); DLL-Update mit Hash-, Signatur- und Exportabgleich; der Sweep
  hat die zu niedrige Empfehlung „PowerShell ≥ 7.6.5“ korrigiert (≥ 7.6.6, `security/DEPENDENCY_AUDIT.md`).
- **Negativ / angreifbar:**
  1. Mutationsprüfung der Find-Files-Änderung (Mutant im Kopierverzeichnis, 8 Tests): M1 `;`→`|` 3 rot, M4 ohne Guard 1 rot, M5 runde
     Klammern 5 rot, Kontrolle 0 rot — aber **M2 (kein `TrimStart('.')`) und M3 (kein `Where-Object`) überleben**: Everything 1.5.0.1424b
     akzeptiert `ext:.pdf;.docx` und `ext:pdf;` ohnehin. Beide Zeilen sind auf dieser Version äquivalent und bleiben als
     defensive Normalisierung (ältere Builds ungeprüft); die Aussage „führende Punkte werden akzeptiert“ stimmt, das Verdienst liegt bei Everything.
  2. Die Sitzungsmessung (K6) ist **eine** Messung, nur Sitzung 0 als SYSTEM.
  3. Der Skill existiert zusätzlich in einer internen Fassung des Maintainers: die Syntaxfakten können auseinanderlaufen.
  4. Mein Alias-Unfall (`Rd` → `Remove-Item`, L2) kostete `docs/TODO.md` bis zur Wiederherstellung aus Git.
- **Backport-Filter:** L2 (Alias-Kollision) → `generisch-stack`, Status `offen`, nur ein Vorfall (Vorschlag, nicht dringend). L3 (8.3-Kurzpfad)
  → `projekt-intern`. „Negativtests brauchen eine Positivkontrolle“ steht sinngemäß schon in `KICKOFF.md` Phase 2 — kein Backport.

### Checks (Schritt 0–2)
- Verletzung 1–4: 0 Treffer (`~~I#`, Doppelung offen/abgeschlossen, `### I#:` für Erledigtes). Health-Grep: alle Treffer betreffen
  offene Inkremente (I2–I7), legitim. Interna-Scan (`.internal-terms`): 0 Treffer. Cross-Refs: I8 stand in `TODO.md`, aber nicht in
  `STATE.md` „Offene Punkte“ — nachgetragen. Hotspot-Analyse nicht ausgeführt (erste Reflexion, keine Vergleichsbasis). Die
  `validate_project_docs.sh`-Variante lief nicht (Template-Skript hier nicht geprüft), die Checks wurden von Hand ausgeführt.
- Testgüte: Mutationsprüfung siehe oben; als Folge zwei Tests ergänzt (nur leere Einträge; leere Einträge neben echten Endungen,
  Fixture `noext`). Danach 8 Tests; M4 wird erkannt, M2/M3 bleiben äquivalent.

### Roadmap-Vorschlag (Schritt 2b, zur Entscheidung — `TODO.md` unverändert)
1. **I2** (Harness, Manifest, PATH): übernimmt `tests/Integration/` ins Pester-Harness (Pin 5.7.1) und das Fixture-Muster samt Langpfad-Helfer.
2. **I5** baut auf dem vorhandenen Fixture-Test auf (Langpfad-Helfer, Warten auf den Index); der Fall „Text-Property > 1023 Zeichen“ (K3) bleibt offen.
3. **I4** (7-Zip: Mindestversion jetzt 26.05, Timeout) ist klein und unabhängig. I8 baut auf I2 auf und wird danach gebündelt.

### Changed
- `STATE.md`: Marker „Nächste Reflexion“ → I12; I8 in „Offene Punkte“ nachgetragen; I1 ins Archiv `docs/changelog/ARCHIVE-STATE.md` rotiert.
- `LESSONS_LEARNED.md`: L2 (offen, generisch-stack), L3 (projekt-intern).

### Template-Backport (nur Vorschlag, kein Template-Commit)
- L2 für `stacks/powershell-automation/CONVENTIONS.md` §2: Hilfsfunktionen nie wie Aliase benennen. Freigabe steht aus.

---

## 2026-11-03 I10 – Sitzungsbindung gemessen (Everything 1.5.0.1424b)

### Tested
- Einmalige geplante Aufgabe als SYSTEM (Sitzung 0), Everything 1.5.0.1424b läuft in Sitzung 1, DLL 3.0.1.12: `Connect-Everything`
  gelingt, `Search-Everything` scheitert mit „Suche fehlgeschlagen mit Fehler: 3758096387“ = 0xE0000003
  (EVERYTHING3_ERROR_DISCONNECTED, `Everything3.h`). Das stützt die Aussage im Herstellerchangelog (IPC nur aus derselben Sitzung).
  Messskript: einmalige Aufgabe mit anschließendem Aufräumen (Aufgabe und Arbeitsordner entfernt, vom Maintainer in einer Admin-Shell ausgeführt).

### Changed
- `docs/KNOWN_ISSUES.md` K6 (Verhalten und Workaround), `docs/BACKLOG.md` (verständlichere Fehlermeldungen), README (EN/DE),
  `operations/SETUP.md`, `security/THREAT_MODEL.md` §6, `security/DEPENDENCY_AUDIT.md`, `architecture/DEPENDENCIES.md`, Skill.
- I10 aus `TODO.md` entfernt (erledigt), in `STATE.md` als abgeschlossen eingetragen.

### Confidence / Ungeprüft
- (a) Eine Messung, nur Sitzung 0 als SYSTEM; nicht getestet: zweite interaktive Sitzung (RDP/Benutzerwechsel), anderer Benutzer in
  derselben Sitzung, Everything als Dienst ohne GUI. Ursache der 0xE0000003 (Sitzungsprüfung) ist aus dem Changelog abgeleitet, nicht bewiesen.
- (b) Welche Pipe (`Everything IPC` / `Everything IPC Session 1`) die DLL nutzt, bleibt ungeklärt.

---

## 2026-11-03 README (EN/DE) aktualisiert

### Changed
- „Tested with“: PowerShell 7.6.9, Everything 1.5.0.1424b, SDK 3.0.1.12; Link auf den Release-Notes-Beitrag im voidtools-Forum.
- Anforderungen: PowerShell ≥ 7.6.6 empfohlen (Sicherheitskorrekturen, 7.4/7.5 Support-Ende 2026-11-10); Everything 1.5 in
  derselben Windows-Sitzung (Herstellerchangelog 1.5.0.1424b, nicht gemessen), Instanz `1.5a` entfällt mit dem 1424b-Installer.
- Neuer Abschnitt „Search Syntax Notes“/„Hinweise zur Suchsyntax“ (gemessene Stolperfallen), Changelog-Eintrag zu 1424b.
- `docs/TODO.md`: Niedrige-Priorität-Punkt „README Tested with / PowerShell 7.6 empfehlen“ erledigt und entfernt.

### Confidence / Ungeprüft
- (a) Der Forum-Link (`p=83688`) stammt aus der Angabe des Maintainers, das Ziel wurde nicht geöffnet.
- (b) Die Empfehlung 7.6.6 folgt den Advisory-Seiten vom Sweep (kein MSRC-Abgleich).

---

## 2026-11-03 I10 (Teil) – Everything 1.5.0.1424b getestet

### Tested
- Everything 1.5.0.1424b (Maintainer hat installiert), SDK-DLL 3.0.1.12, PowerShell 7.6.9: `Test-EverythingConnection` ✓,
  `Connect-Everything` (Standardinstanz) ✓, 6 Integrationstests grün, die 18 Syntaxfälle des Skills und die Klammer-/`;`-/`|`-Messung
  (Issue #1) liefern dieselben Ergebnisse wie auf 1.5.0.1423b.
- Instanz `1.5a`: `Connect-Everything -InstanceName '1.5a'` scheitert mit `0xE0000002` (EVERYTHING3_ERROR_IPC_PIPE_NOT_FOUND),
  der 1424b-Installer hat sie entfernt; der Standardaufruf verbindet mit der Standardinstanz (Fallback auf `1.5a` nur im Fehlerfall).
- Neu sichtbar: neben `\\.\pipe\Everything IPC` existiert `Everything IPC Session 1`.

### Changed
- README (EN/DE) „Tested with“ auf 1.5.0.1424b, `architecture/DEPENDENCIES.md`, `security/THREAT_MODEL.md` §6,
  `security/DEPENDENCY_AUDIT.md`; Skill-Hinweis auf beide gemessene Versionen.

### Confidence / Ungeprüft
- (a) Nicht getestet: Zugriff aus einer anderen Sitzung (z. B. geplante Aufgabe als SYSTEM, Remote-Sitzung) — braucht
  Adminrechte zum Anlegen einer einmaligen Aufgabe; I10 bleibt dafür offen. Ebenso das neue SDK-Feature „mehrere Sitzungen“.
- (b) Nicht geklärt: Welche der beiden Pipes (`Everything IPC` / `Everything IPC Session 1`) die DLL für die eigene Sitzung nutzt.

---

## 2026-11-03 I9 – SDK3 auf 3.0.1.12 aktualisiert + Security-Sweep

### Changed
- `Everything3_x64.dll`: SDK 3.0.0.9 → **3.0.1.12** (SDK-Changelog: Unterstützung mehrerer Sitzungen, besseres Warten auf
  ausgelastete Pipes). Quelle `https://www.voidtools.com/Everything-SDK-3.0.1.12.zip` (524889 Byte, SHA256 in
  `architecture/DEPENDENCIES.md`), geladen nach Freigabe in ein leeres Verzeichnis. Dateiversion 3.0.1.12, Authenticode `Valid`
  (voidtools PTY LTD), alle 26 vom Interop genutzten Funktionen stehen in der Exportliste, die Bibliotheksnamen im Binary sind
  unverändert. `Everything3SDK.psm1` blieb unverändert.
- Doku auf 3.0.1.12 gezogen (README EN/DE, DEPENDENCIES, MODULE, OVERVIEW, GLOSSARY, KICKOFF); Mindestversionen angehoben:
  PowerShell ≥ 7.6.6, 7-Zip ≥ 26.05.

### Security
- Sweep 2026-11-03 (Befunde in `security/DEPENDENCY_AUDIT.md`): PowerShell-Advisories CVE-2026-40400/-62801 (fixed ab 7.6.6;
  die Empfehlung ≥ 7.6.5 vom 2026-10-11 war zu niedrig — korrigiert), 7-Zip 26.05, Everything 1.5.0.1424b
  (Sitzungsbindung der IPC, Dienstprüfung), CVE-2025-12683 (laut Spiegeln bis 1.4.1.1029, kein Fix bestätigt).
  Marker auf 2026-11-17 gesetzt. Beim Sweep nicht abgedeckt: Pester und PSScriptAnalyzer (nur Entwicklung).

### Tested
- 6 Integrationstests (`tests/Integration`) und `Test-EverythingConnection` mit der neuen DLL gegen Everything 1.5.0.1423b grün.
- Skill-Syntaxfakten gemessen (18 Fälle, alle wie behauptet): `wfn:`, `*.log`, `file:`/`folder:`, `size:`, `ext:` (auch
  `.tar.gz` → `gz`), `!`, `regex:`, `dm:2020`, `empty:`, `case:`, `parent:`, `nopath:`, `dupe:size`, `<a|b>`.

### Confidence / Ungeprüft
- (a) Nicht getestet: Everything 1.5.0.1424b (nicht installiert) und damit die Sitzungsbindung; Ablauf aus einer anderen
  Sitzung; Verhalten bei mehreren Sitzungen (neues SDK-Feature) — alles in I10. Der Skill wurde nicht in einer Agentensitzung
  ausprobiert.
- (b) Ungeprüft übernommen: Beschreibung der PowerShell-Advisories nur aus den Advisory-Seiten (nicht gegen MSRC gegengeprüft);
  Spiegel-Angaben zu CVE-2025-12683. Der Abgleich der DLL-Signaturen beruht auf der Exportliste (`.def`), nicht auf einem
  Vergleich der Header-Typen.
- (c) Nicht gelesen: `Everything3.h` der neuen Version wurde nicht Zeile für Zeile mit den P/Invoke-Signaturen verglichen.
- Reflexions-Check (`KICKOFF.md` Phase 1c) durch I9 ausgelöst, nicht durchgeführt. Struktur-Check `validate_project_docs.sh`
  nicht ausgeführt.

### Lessons Learned
- In PowerShell hat der Alias `rd` Vorrang vor einer gleichnamigen Funktion: Eine Hilfsfunktion `Rd` löschte statt zu lesen
  `docs/TODO.md` (aus Git wiederhergestellt, Änderung danach neu angewendet). Hilfsfunktionen nie wie Aliase
  (`rd`, `ls`, `cat`, `gc` …) benennen.

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
