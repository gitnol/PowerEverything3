# Aktueller Projektstatus – PowerEverything3

Zuletzt aktualisiert: 2026-11-03
**Initialisiert mit:** docs_template v27@5ce0f84 → v27@2268889 → v28@63b85ec (2026-10-22, Delta-Update)
**Stack / Overlays:** powershell-automation / keine
**Letztes abgeschlossenes Inkrement:** I9 – SDK3 auf 3.0.1.12 aktualisiert + Security-Sweep (2026-11-03)
**Nächster Schritt:** I2 – Modul-Ladepfad und Manifest härten + Pester-Harness
**Nächste Reflexion:** zu Beginn der nächsten Session fällig — I9 (durch 3 teilbar) ist abgeschlossen, `KICKOFF.md` Phase 1c nicht durchgeführt; Marker sonst bei Abschluss von I3 (siehe `KICKOFF.md` Phase 1c → `docs/REFLECTION.md` — `docs/`-Drift prüfen + Template-Backport prüfen; danach Marker um 3 erhöhen)
**Nächster Security-Sweep:** 2026-11-17 (Intervall 14 Tage; letzter Sweep 2026-11-03; siehe `KICKOFF.md` Phase 1 Punkt 4a → `docs/principles/SECURITY_CURRENCY.md` — fällig, sobald heute ≥ diesem Datum; nach dem Sweep Marker = Sweep-Datum + Intervall)

---

## Nächster Schritt

I2 aus `docs/TODO.md`: Die Interop-Schicht `Everything3SDK.psm1` verändert beim Import prozessweit `$env:PATH` und lädt
die DLL ohne Integritätsprüfung; das Manifest exportiert per Wildcard und deklariert weder PowerShell-Version noch
Edition/Architektur. I2 behebt das test-first und legt dabei den Pester-Harness (`tests/`, Pester-Version gepinnt) an —
das Projekt hat bisher **keine** automatisierten Tests. Ausgangswert für Gate 1 (PSScriptAnalyzer, beim Init gemessen):
siehe `docs/CHANGELOG.md` I1.

---

## Abgeschlossene Inkremente

| # | Titel | Datum | Commit |
|---|-------|-------|--------|
| I1 | Projektdokumentation initialisiert (docs_template-Baseline) | 2026-10-11 | 54ba850 |
| I9 | SDK3 auf 3.0.1.12 aktualisiert + Security-Sweep | 2026-11-03 | 89d33e8 |

---

## Offene Punkte

| # | Beschreibung | Priorität |
|---|-------------|-----------|
| I2 | Modul-Ladepfad und Manifest härten (PATH-Seiteneffekt, DLL-Signaturprüfung, explizite Exporte, Versions-/Editions-Pinning) + Pester-Harness | Hoch |
| I3 | Beispielskript: Konfiguration als Daten statt Code (ADR) | Hoch |
| I4 | Beispielskript: 7-Zip-Mindestversion und Timeout für die Archivprüfung | Hoch |
| I5 | Integrationstests (read-only) gegen eine lokale Everything-Instanz | Mittel |
| I6 | Beispielskript testbar machen (Funktionen vom Ablauf trennen) + Unit-Tests der reinen Funktionen | Mittel |
| I7 | Mailversand: Transport-Entscheidung (ADR) und TLS-Default | Mittel |
| I10 | Rest aus I9: Everything 1.5.0.1424b testen, Sitzungsbindung messen, Instanz `1.5a` prüfen | Mittel |

---

## Risiken & Blocker

Eintragen, **sobald** ein Punkt erkannt ist — nicht erst, wenn er eskaliert.

| Risiko / Blocker | Auswirkung | Mitigation / Nächster Schritt | Owner | Status |
|---|---|---|---|---|
| Keine automatisierten Tests; die letzten Fixes betrafen P/Invoke-Signaturen (README-Changelog) | Regressionen in der Interop-Schicht bleiben unbemerkt (falsche Typbreiten → Abstürze oder abgeschnittene Werte) | Pester-Harness in I2, Integrationstests gegen echte Instanz in I5 | Maintainer | offen |
| PowerShell 7.4 und 7.5 erreichen am 2026-11-10 das Support-Ende; README nennt „getestet mit 7.5.2 und 7.6" | Nutzer auf 7.4/7.5 laufen danach ohne Sicherheitsupdates | README-Empfehlung auf 7.6 (LTS) anheben (TODO, Niedrig); Befund in `docs/security/DEPENDENCY_AUDIT.md` | Maintainer | offen |
| Everything 1.5 ist eine Alpha-Version; Pipe-/SDK-Verhalten kann sich zwischen Builds ändern | Modul kann nach einem Everything-Update brechen | Integrationstests (I5) nach jedem Everything-/SDK-Update laufen lassen | Maintainer | offen |
| Everything-Dienst: CVE-2025-12683 (Named Pipe mit NULL-DACL; lokale DoS bzw. Rechteausweitung in Kombination), laut Datenbank-Spiegeln betroffen bis 1.4.1.1029, kein Fix-Stand bestätigt (Sweep 2026-11-03) | Betrifft jeden Host, auf dem Everything als Dienst läuft — Voraussetzung des Moduls | Hinweis in `docs/operations/SETUP.md` und `docs/security/THREAT_MODEL.md` §6; beim nächsten Sweep Vendor-Stand prüfen | Maintainer | offen |
| PowerShell-Advisories 2026-09-11: CVE-2026-40400 (Windows) und CVE-2026-62801 (RCE per relativer Pfadumgehung), gepatcht ab 7.6.6 / 7.5.11 / 7.4.18 bzw. 7.4.20 | Ältere PowerShell-Stände auf Zielsystemen; 7.4/7.5 verlieren am 2026-11-10 den Support | Mindestens 7.6.6 empfehlen (aktuell 7.6.9, 2026-10-25); `docs/security/DEPENDENCY_AUDIT.md`, `operations/SETUP.md` | Maintainer | offen |
