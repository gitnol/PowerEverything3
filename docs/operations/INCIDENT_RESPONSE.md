# Incident Response – PowerEverything3

Was zu tun ist, wenn ein Sicherheitsvorfall, ein kritischer Bug oder ein
Datenverlust eintritt. Vor Eskalation lesen, nicht erst während der Krise.

Verbindet sich mit `security/THREAT_MODEL.md`, `operations/SECRETS_MANAGEMENT.md`
und `operations/RUNBOOK.md` (Stack-spezifisch).

---

## Klassifizierung

| Stufe | Definition | Beispiele | Reaktionsfenster |
|---|---|---|---|
| **P0 – Kritisch** | Datenverlust, Datenleck, Produktion komplett offline | Credentials in git, kompromittierter API-Key, DB-Korruption | sofort |
| **P1 – Hoch** | Kernfunktion ausgefallen, sensible Daten gefährdet aber nicht abgeflossen | Auth-Service unten, Logging-Bug exponiert PII | < 2 Stunden |
| **P2 – Mittel** | Funktion eingeschränkt, kein Daten-/Sicherheitsrisiko | Performance-Einbruch, einzelner Endpoint kaputt | < 24 Stunden |
| **P3 – Niedrig** | Kosmetischer / nicht-blockierender Defekt | UI-Bug, falsche Fehlermeldung | Backlog |

---

### Projektbezogene Beispiele

| Vorfall | Stufe | Erste Maßnahme |
|---|---|---|
| Manipulierte `Everything3_x64.dll` im Modulordner entdeckt (Signatur/Hash weicht ab, `docs/architecture/DEPENDENCIES.md`) | P0 | Modul nicht mehr laden, betroffene Hosts isolieren, DLL aus dem offiziellen SDK neu beziehen und prüfen |
| CSV/Transcript des Beispielskripts (Besitzernamen, Mail-Adressen) in falsche Hände oder ins Repository gelangt | P1 | Datei entfernen (bei Commit: History bereinigen, bevor gepusht wird), Datenschutz des Betreibers informieren |
| Beispielskript versehentlich mit `-Live` an alle Besitzer gemailt | P2 | Lauf abbrechen, Korrekturmail über Helpdesk; Ursache klären (z. B. Konfigurationsdatei setzt `$Live`, THREAT_MODEL §2) |
| Interne Hostnamen/Adressen in einem Commit des öffentlichen Repositories | P1 | Vor dem Push: Commit lokal bereinigen; nach dem Push: Abwägung/Rotation, `docs/CONVENTIONS_COMMON.md` 3.1 |

---

## Vorgehen (5 Phasen)

### 1. Eindämmen (Contain)

Ziel: weiteren Schaden verhindern, Beweise sichern. Erst danach analysieren.

- Bei Credential-Leak: betroffenes Secret **sofort** invalidieren (siehe
  `SECRETS_MANAGEMENT.md` → Rotation).
- Bei aktivem Angriff: betroffene Komponente isolieren (Service stoppen,
  Netzwerk-Zugriff sperren).
- Logs und betroffene Artefakte sichern, **bevor** etwas verändert wird
  (Forensik-Pfad).
- Bei P0: weitere Personen benachrichtigen (siehe Eskalationspfad unten).

### 2. Bewerten (Assess)

- **Was ist betroffen?** Welche Daten, welche Nutzer, welche Systeme?
- **Wann hat es begonnen?** Logs prüfen → Zeitfenster eingrenzen.
- **Welcher Vektor?** Welche Schwachstelle / welches Versagen hat es ermöglicht?
- **Wer muss informiert werden?** Intern (Stakeholder), extern (Kunden,
  Auditor, Datenschutzbehörde bei DSGVO-Relevanz).

Output: kurzer Status (1 Absatz), an Eskalationsstelle übergeben.

### 3. Kommunizieren (Communicate)

- **Intern zuerst.** Stakeholder informieren, bevor sie es von außerhalb hören.
- **Faktentreu.** Was wir wissen, was wir nicht wissen, was wir gerade tun.
  Keine Spekulation.
- **Extern nur abgestimmt.** Bei DSGVO-Verstoss: Meldepflicht 72h
  (Datenschutzbehörde); Compliance-Rahmen siehe `security/DATA_HANDLING.md`.

### 4. Beheben (Eradicate & Recover)

- Wurzelursache fixen, nicht nur Symptom (Code-Fix, Konfigurations-Härtung,
  Patch-Update).
- Verifikation: Reproduziert sich der Vorfall im fix-validierten Stand? Nein.
- Wiederherstellung: Service wieder hochfahren, Datenintegrität prüfen.
- Monitoring intensivieren für 24–72h.

### 5. Post-Mortem

Innerhalb von 5 Werktagen nach P0/P1-Vorfall:

- **Zeitleiste:** wer hat wann was bemerkt / getan.
- **Wurzelursache:** technisch + prozessual (5-Why-Analyse).
- **Lessons Learned:** was schief lief, was gut lief. Einträge in
  `LESSONS_LEARNED.md` und `CHANGELOG.md`.
- **Maßnahmen:** konkrete TODO-Punkte oder ADRs, um Wiederholung zu verhindern.
- **Update Threat Model:** falls die Bedrohung neu ist → Eintrag in
  `security/THREAT_MODEL.md`.

---

## Eskalationspfad

| Vorfall-Stufe | Wer wird wann benachrichtigt |
|---|---|
| P0 | Maintainer des Repositories (Rolle) sofort; beim Betreiber dessen IT-Sicherheitsverantwortliche:r und ggf. Datenschutz |
| P1 | Maintainer des Repositories bzw. IT-Verantwortliche:r des Betreibers innerhalb 1 Stunde |
| P2 | Im nächsten regulären Sync |
| P3 | Backlog-Eintrag, keine Sonder-Eskalation |

---

## Checkliste für die ersten 15 Minuten bei P0/P1

- [ ] Schaden eingedämmt (Service / Secret / Netzwerk-Pfad)?
- [ ] Logs gesichert?
- [ ] Eskalation losgeschickt?
- [ ] Zeitstempel des Beginns notiert?
- [ ] Aktuell aktive Personen kennen jeweils ihren Teil-Auftrag?

---

## Pflege

Trigger: nach jedem P0/P1-Vorfall: Post-Mortem-Hinweis hier integrieren falls
generalisierbar (z.B. Eskalationsweg ändert sich). Sonst nur projektspezifische
Anpassung der Eskalations-Tabelle.
