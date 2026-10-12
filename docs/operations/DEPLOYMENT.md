# Deployment – PowerEverything3

Default-Template; derzeit liefert kein Stack eine eigene Variante. Beschreibt die
Mindest-Inhalte, die jedes Projekt dokumentiert haben muss; stack-spezifische Setup- und
Betriebsdetails stehen in `operations/SETUP.md` und `operations/RUNBOOK.md`.

Verbindet sich mit `operations/SETUP.md` (Erst-Setup), `operations/RUNBOOK.md`
(Betrieb) und `operations/SECRETS_MANAGEMENT.md`.

---

## Umgebungen

| Umgebung | Zweck | Datenquelle | Wer darf deployen |
|---|---|---|---|
| dev | Entwicklung und Tests auf einem Windows-x64-Rechner mit Everything 1.5a | lokaler Index, Temp-Fixtures | Entwickler:in |
| Betreiber-Testlauf | Beispielskript als Dry-Run bzw. mit `-SendMail` ohne `-Live` auf dem Zielserver | echte Freigaben, Mails nur an `$DebugTo` | Betreiber-Admin |
| Betreiber-Produktion | Beispielskript mit `-SendMail -Live` | echte Freigaben, Mails an Besitzer | Betreiber-Admin nach erfolgreichem Testlauf |

Unterschiede zwischen den Umgebungen entstehen ausschließlich über Parameter und die lokale Konfigurationsdatei
(siehe `architecture/CONFIGURATION.md`), nicht über Code-Branches.

---

## Build

Kein Build-Schritt. Ausgeliefert wird der Repository-Inhalt (Modulordner mit `.psd1`, `.psm1`, `Everything3SDK.psm1`
und `Everything3_x64.dll`, dazu `Examples/`).

**Reproduzierbar:**
- [x] Keine Paketauflösung zur Laufzeit; die einzige Binärdatei ist versioniert (SHA256 in `architecture/DEPENDENCIES.md`)
- [ ] Gates laufen in sauberer Umgebung (CI fehlt; Kandidat nach I2)

---

## Release

Bisher gibt es weder Tags noch Versionssprünge (`ModuleVersion = '0.1.0'`); Änderungen stehen im README-Changelog.
Mindestablauf ab dem ersten Release:

| Schritt | Verantwortung | Verifikation |
|---|---|---|
| Dependency-Audit + Security-Currency-Abgleich (Pflicht vor jedem Release) | Maintainer | datierter Eintrag in `security/DEPENDENCY_AUDIT.md` → Befunde (`principles/SECURITY_CURRENCY.md`) |
| Gates grün (PSScriptAnalyzer, Pester; Integrationstests gegen lokale Instanz) | Maintainer | Gate-Ausgabe im CHANGELOG-Eintrag |
| `ModuleVersion` erhöhen, README-Changelog mit Version, Git-Tag `vX.Y.Z` | Maintainer | Tag zeigt auf den geprüften Commit |
| Optional: Veröffentlichung PSGallery | Maintainer | `Publish-Module` validiert das Manifest (`docs/BACKLOG.md`) |

---

## Rollback

**Bedingung:** Ein neuer Stand bricht Suche oder Beispielskript beim Nutzer/Betreiber.

| Schritt | Befehl / Aktion |
|---|---|
| 1. Letzte stabile Version identifizieren | `git log --oneline` bzw. (ab dem ersten Release) `git tag` |
| 2. Rollback ausführen | `git checkout <commit-oder-tag>` im Modulordner bzw. vorherige Kopie des Modulordners wiederherstellen |
| 3. Verifikation | `Import-Module .\Everything3-PowerShell-Wrapper.psd1 -Force; Test-EverythingConnection` |
| 4. Datenmigration | entfällt (keine Datenhaltung) |

---

## Post-Deploy-Verifikation

- [ ] `Test-EverythingConnection` grün
- [ ] Beispielskript-Dry-Run ohne neue Warnungstypen im Transcript
- [ ] Erste Testmails (`-SendMail -MaxMails 3`) korrekt formatiert

---

## Pflege

Trigger: neue Umgebung / geänderter Build-Befehl / geänderter Rollback-Pfad →
hier eintragen. Vor jedem nicht-trivialen Architektur-Change prüfen, ob diese
Datei betroffen ist.
