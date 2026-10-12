# Datenschutz & Compliance – PowerEverything3

Kein formaler Compliance-Rahmen im Repository (öffentliches Open-Source-Projekt, MIT-Lizenz). Wer das
**Beispielskript** betreibt, verarbeitet personenbezogene Daten (Namen, Mail-Adressen, Kontostatus von Ordner-Besitzern)
und unterliegt damit der DSGVO bzw. dem eigenen Informationssicherheits-Rahmen — das regelt der Betreiber, nicht dieses
Repository.

---

## Datenklassen (kanonisch)

Alle Overlays (`llm-integration`, `document-intelligence`, `compliance-tisax`) verwenden diese vier Klassen und
ergänzen nur ihre Erlaubnis-Matrix bzw. das TISAX-Mapping.

| Klasse | EN | Beispiele | An externe Dienste / Cloud-Modelle |
|---|---|---|---|
| Öffentlich | public | veröffentlichte Texte, Demo-Daten | erlaubt |
| Intern | internal | allgemeine Geschäftskommunikation, interne Prozessdokumente | nach Prüfung des Dienstes (Checkliste unten) |
| Vertraulich | confidential | Kunden- und Lieferantendaten, Verträge, Preise, Strategie | **nur mit dokumentierter Freigabe und Auftragsverarbeitungsvertrag (AVV)** |
| Streng vertraulich | restricted | Personalakten, besondere Kategorien personenbezogener Daten, Konstruktions-/Tarifgeheimnisse | **nein** — nur lokal/On-Prem; Ausnahme nur mit ausdrücklichem DSGVO-/TISAX-Sign-off |

Projektbezug: Treffer des Moduls (Dateipfade, -namen, Größen, Zeitstempel) sind mindestens **Intern** — Dateinamen
können vertrauliche Inhalte verraten. Die Ausgaben des Beispielskripts (CSV, Transcript, Mails) sind **Vertraulich**
(personenbezogene Daten + Struktur des Fileservers).

---

## 1. Lokale Verarbeitung / Datenisolation

- Modul: ausschließlich lokal (Named Pipe zur lokalen Everything-Instanz); kein Netzwerkzugriff, keine Telemetrie.
- Beispielskript: liest lokal auf dem Fileserver, fragt das AD per LDAP ab und sendet Mails über das konfigurierte
  SMTP-Relay. Weitere externe Dienste gibt es nicht.
- Keine Air-Gap-Anforderung im Projekt.

---

## 2. Minimalprinzip (Data Minimization)

- An das SMTP-Relay gehen nur: Ordnerpfad (als UNC), Archivname, Größe, Ergebnis der Inhaltsprüfung, bei der
  Sammelmail zusätzlich Name und Status des Besitzers.
- Nicht weitergegeben: Dateiinhalte (nur Metadaten werden verglichen), Prüfsummen, SIDs (SIDs erscheinen nur in
  Transcript-Warnungen bzw. als Besitzername, wenn eine SID nicht auflösbar ist).
- Mails enthalten nur Treffer ab `$MailMinMB` (Default 100 MB); CSV ab `$ReportMinMB` (Default 10 MB).
- Kein LLM, kein Cloud-Dienst.

---

## 3. Output-Dateien und Speicherorte

| Datei | Inhalt | Sensitivität |
|-------|--------|-------------|
| `archives_with_extracted_folder_<Zeitstempel>.csv` | Pfade, Archivnamen, Größe, Inhaltsprüfung, Mail-Adresse/Name/Status der Ordner-Besitzer, Mail-Adresse des Archiv-Besitzers | Vertraulich |
| `archives_with_extracted_folder_<Zeitstempel>.log` (Transcript) | gesamte Konsolenausgabe: Freigaben mit lokalen Pfaden, Warnungen mit Pfaden und SIDs, Mail-Empfänger | Vertraulich |
| Mails an Besitzer / `$DebugTo` / `$FallbackTo` | Tabelle der eigenen Treffer bzw. aller Treffer ohne mailbaren Besitzer | Vertraulich |
| `Find-ArchivesWithExtractedFolder.config.ps1` | SMTP-Relay, Absender-/Empfängeradressen, ggf. Servername | Intern |

- Ablage: `-OutputPath` (Default: Skriptordner). Empfehlung: geschützter Ordner außerhalb des Repositories, Zugriff nur
  für das Ausführungskonto und die auswertende IT.
- `.gitignore`: `Examples/*.config.ps1`, `Examples/*.csv`, `Examples/*.log`, `*.log` — Ausgaben dürfen nie committet werden.

---

## 4. Zugriffsschutz

- Modul: Zugriff entspricht dem aufrufenden Benutzer und der Everything-Instanz (`docs/security/THREAT_MODEL.md` §6).
- Beispielskript: läuft mit lokalen Adminrechten auf dem Fileserver; LDAP lesend als Domänenbenutzer.
- Least Privilege: dediziertes Ausführungskonto, kein Domänen-Admin (`docs/architecture/CREDENTIAL_STRATEGY.md`).
- Secret-Speicherung und Rotation: siehe `docs/operations/SECRETS_MANAGEMENT.md`

---

## 5. Datenhaltung / Retention

- Jeder Lauf erzeugt **neue** CSV- und Transcript-Dateien (Zeitstempel im Namen) — sie akkumulieren, nichts wird
  überschrieben oder gelöscht.
- Eine Aufbewahrungsfrist legt das Skript nicht fest; der Betreiber ist für das Löschen verantwortlich
  (Empfehlung: nach Auswertung bzw. spätestens vor dem nächsten Lauf).
- Mails liegen in den Postfächern der Empfänger; dafür gilt die Mail-Aufbewahrung des Betreibers.

---

## 6. Compliance-Checkliste für neue Features

- [ ] Keine neuen persistenten Speicher ohne Retention-Konzept
- [ ] Kein Logging von sensiblen Inhalten (Passwörter, Nutzdaten, PII)
- [ ] Externe Services nur nach Compliance-Prüfung einführen
- [ ] Neue Spalten in CSV/Mail: Datenklasse prüfen und hier in der Tabelle eintragen
- [ ] Beispielwerte (Adressen, Hosts) bleiben fiktiv (`example.com`) — öffentliches Repository
