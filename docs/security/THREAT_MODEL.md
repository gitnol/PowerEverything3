# Threat Model & Mitigationen – PowerEverything3

---

Leitfragen zum Finden von Bedrohungen: `security/THREAT_MODEL_GUIDE.md` (vom Template gepflegt).
Öffentliches oder potenziell öffentliches Repo: keine internen Hosts, Versionen oder Betroffenheiten konkreter Systeme —
die gehören nach `docs/local/` (`CONVENTIONS_COMMON.md` 3.1).

Stand: 2026-10-11 (Init, aus dem Code abgeleitet; Security-Currency-Abgleich siehe `security/DEPENDENCY_AUDIT.md`).
Prüfung auf eingebettete Anweisungstexte im analysierten Repository (Kommentare, README, Strings): keine gefunden.

Kontext: Das **Modul** läuft im Kontext des Aufrufers und liest nur. Das **Beispielskript** läuft laut README als
Administrator auf einem Fileserver, verarbeitet von Nutzern abgelegte Dateien und verschickt Mails — dort liegen die
größeren Risiken.

## 1. Manipulierte native DLL / DLL-Suchpfad (Code-Ausführung mit den Rechten des Aufrufers)

**Gefahr:** `Everything3SDK.psm1` lädt `Everything3_x64.dll` per `LoadLibrary($DllPath)` aus dem Modulordner
(Zeile 5, 155) ohne Prüfung von Signatur oder Hash. Wer den Modulordner beschreiben kann, kann eine eigene DLL
unterschieben; das Beispielskript importiert das Modul als Administrator (`Import-Module $EverythingModule -Force`,
Zeile 533) — der Code liefe dann mit Adminrechten. Zusätzlich stellt Zeile 10 das Modulverzeichnis prozessweit an den
Anfang von `$env:PATH`: Programme, die später in derselben Sitzung ohne vollen Pfad gestartet werden, würden zuerst
im Modulordner gesucht.

**Mitigation:**
- Modulordner nur für Administratoren beschreibbar ablegen (z. B. unter `%ProgramFiles%\PowerShell\Modules`).
- I2: Authenticode-Prüfung vor `LoadLibrary` (Status `Valid`, Signer voidtools) mit Fail-Fast; PATH-Änderung entfernen.
- Referenzwerte (Signer, SHA256, Version) in `docs/architecture/DEPENDENCIES.md`.

**Restrisiko:** Mittel – bis I2 hängt die Integrität allein an den Dateisystemrechten des Modulordners.

---

## 2. Konfigurationsdatei wird als Code ausgeführt und kann Schutzschalter überschreiben

**Gefahr:** `Find-ArchivesWithExtractedFolder.ps1` dot-sourct `$ConfigFile` (Zeile 124–125, Default: Datei neben dem
Skript, per `-ConfigFile` frei wählbar). Jeder Inhalt wird mit den Rechten des Skripts (Administrator) ausgeführt.
Außerdem kann die Datei Variablen wie `$Live`, `$SendMail` oder `$DebugTo` setzen und so die Schutzmechanismen
„Dry-Run ohne `-SendMail`" und „Debug-Empfänger ohne `-Live`" aushebeln — Mails an alle Besitzer, obwohl der
Aufrufer einen Testlauf wollte.

**Mitigation:**
- Skript- und Konfigurationsordner nur für Administratoren beschreibbar.
- I3: Konfiguration als Daten (`Import-PowerShellDataFile`), Liste erlaubter Schlüssel, Parameter nicht überschreibbar (ADR).

**Restrisiko:** Mittel – bis I3 vollständig von Dateirechten und Sorgfalt des Betreibers abhängig.

---

## 3. Parsen nutzerkontrollierter Archive mit Administratorrechten (7-Zip, .NET ZIP)

**Gefahr:** Phase 1c öffnet jedes gefundene Archiv: ZIP über `System.IO.Compression.ZipFile` (Zeile 215), alle
anderen Formate über `7z.exe l -slt`, `.tar.gz/.tar.bz2/.tar.xz/.tgz` zusätzlich per `7z x -so` dekomprimiert und
gestreamt (Zeile 184–205, 227). Archive auf Dateifreigaben stammen von beliebigen Nutzern. Speicherfehler im Parser
werden so mit Adminrechten erreicht — 7-Zip hat 2026 mehrere solcher Fixes veröffentlicht (u. a. CVE-2026-14266,
XZ-Dekompression, behoben in 26.02; weitere Parser-Fixes in 26.01 und unbenannte Sicherheitsfixes in 26.04). `WaitForExit()` ohne Timeout: ein präpariertes
oder sehr großes Archiv (Dekompressionsbombe bei `x -so`) kann den Lauf blockieren.

**Mitigation:**
- 7-Zip aktuell halten (Stand 2026-11-03: ≥ 26.05); ohne 7-Zip prüft das Skript nur ZIP.
- I4: Versionsprüfung von `7z.exe` und Timeout je 7-Zip-Aufruf.
- Ausführungskonto mit minimalen Rechten statt Domänen-Admin (`docs/architecture/CREDENTIAL_STRATEGY.md`).

**Restrisiko:** Mittel – Parser-Schwachstellen sind nie ganz auszuschließen; Rechte des Kontos bestimmen den Schaden.

---

## 4. Personenbezogene Daten in CSV, Transcript und Mails; Mailversand ohne TLS

**Gefahr:** CSV (Zeile 683–684) und Transcript (Zeile 462) enthalten Besitzernamen, Mail-Adressen, Kontostatus und
die Ordnerstruktur des Fileservers; Default-Ablage ist der Skriptordner (`$OutputPath = $PSScriptRoot`), es gibt keine
Aufbewahrungsregel. Mails gehen per `Send-MailMessage` an Port 25 mit `$SmtpUseSsl = $false` (Zeile 102–104) —
Inhalte (Pfade, Namen) können im Netz mitgelesen werden; Microsoft markiert das Cmdlet als obsolet, weil es keine
sichere Verbindung garantiert.

**Mitigation:**
- `-OutputPath` auf einen geschützten Ordner außerhalb des Skript-/Repository-Ordners setzen; CSV/Logs nach Auswertung löschen (`docs/security/DATA_HANDLING.md`).
- `.gitignore` schließt `Examples/*.csv`, `*.log` und die echte Konfiguration aus.
- I7: TLS-Default und Mail-Transport per ADR entscheiden.

**Restrisiko:** Mittel – DSGVO-relevante Daten; Schutz hängt bis I7 an Betreiber-Konfiguration und Netzsegment.

---

## 5. HTML-Injection und Täuschung über Ordner- und Dateinamen in Mails

**Gefahr:** Ordner- und Archivnamen stammen von Nutzern und landen im HTML-Mailtext und in `file://`-Links
(`New-MailBody`, Zeile 386–440). Ohne Kodierung ließen sich Links oder Inhalte in eine „IT-Mail" einschleusen.

**Mitigation:**
- Alle Werte werden mit `[System.Net.WebUtility]::HtmlEncode` kodiert; Links über `ConvertTo-FileLink` (maskiert `%`,
  `#`, Leerzeichen) und zusätzlich HTML-kodiert.
- I6: Charakterisierungstest für `New-MailBody` mit feindlichen Namen (`<`, `"`, `#`, `%`).

**Restrisiko:** Gering – Kodierung vorhanden; ungetestet.

---

## 6. Everything-Dienst als lokale Angriffsfläche (Abhängigkeit)

**Gefahr:** Das Modul setzt eine laufende Everything-Instanz voraus. Für den Everything-Dienst (läuft als SYSTEM)
ist CVE-2025-12683 veröffentlicht: Die Named Pipe zwischen Dienst und GUI hat eine NULL-DACL — lokale Benutzer können
einen Denial of Service auslösen oder, mit weiteren Schwächen kombiniert, Rechte ausweiten. Betroffen sind laut Datenbank-Spiegeln Everything-Versionen bis
1.4.1.1029; ein Fix-Stand ist öffentlich nicht bestätigt, für 1.5.0.x nennt keine Quelle eine Aussage (Stand 2026-11-03). Zudem liefert Everything Dateinamen aus dem gesamten Index; ob Treffer
nach NTFS-Rechten des Abfragenden gefiltert werden, ist ungeprüft.

**Mitigation:**
- Everything-Dienst nur installieren, wo nötig; auf Mehrbenutzer-Systemen (Terminalserver) besonders abwägen.
- Everything aktuell halten, beim Kadenz-Sweep Vendor-Stand zu CVE-2025-12683 prüfen.
- Everything 1.5.0.1424b (2026-10-15) nimmt laut Herstellerchangelog IPC-Verbindungen nur noch von Clients derselben Sitzung
  an und prüft die Vertrauenswürdigkeit des Dienstes; das verkleinert die Angriffsfläche, bedeutet aber: Aufrufer aus
  anderer Sitzung (geplante Aufgabe ohne Anmeldung, Remote-Sitzung) erreichen Everything nicht mehr (I10).

**Restrisiko:** Mittel – außerhalb des Projektcodes, aber Voraussetzung für dessen Nutzung.

---

## Hinweise

- Dieses Dokument wird bei jeder neuen Funktion geprüft, die externe Eingaben verarbeitet
  oder auf sensible Ressourcen zugreift — anhand der Leitfragen in `security/THREAT_MODEL_GUIDE.md`.
- Neue Bedrohungen als ADR dokumentieren wenn sie eine Architekturentscheidung auslösen.
