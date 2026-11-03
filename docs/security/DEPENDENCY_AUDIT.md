# Dependency-Audit – PowerEverything3

Wann und wie Abhängigkeiten auf bekannte Schwachstellen geprüft werden.
Verbindet sich mit `architecture/DEPENDENCIES.md` (Was ist drin?) und
`security/THREAT_MODEL.md` (Bedrohung: Vulnerable Dependencies).

---

## Wann auditieren

| Auslöser | Pflicht? |
|---|---|
| Vor jedem Release | Ja |
| Bei neuer oder aktualisierter Dependency | Ja, die betroffene + Transitive |
| Nach Sicherheitsmeldung (CVE) für eine genutzte Dep | Ja, sofort |
| Kadenz-Sweep (Scanner **und** Web-Advisory-/Best-Practice-Recherche für Base+Stack) | Default 14 Tage, Marker `**Nächster Security-Sweep:**` im `STATE.md`-Kopf — `principles/SECURITY_CURRENCY.md` |

---

## Audit-Vorgehen in diesem Projekt

Es gibt keine Paket-Manifest-/Lock-Datei und keine PSGallery-Laufzeitabhängigkeit; ein Scanner wie `pip-audit` hat
kein Gegenstück. Der Bestand ist klein und wird manuell geprüft:

| Abhängigkeit | Bestand feststellen | Advisory-Quellen |
|---|---|---|
| PowerShell 7 | `$PSVersionTable.PSVersion` auf dem Zielsystem | MSRC Update Guide, `PowerShell/Announcements` (GitHub), Lifecycle-Seite von Microsoft Learn |
| `Everything3_x64.dll` (SDK3) | `(Get-Item .\Everything3_x64.dll).VersionInfo`, `Get-AuthenticodeSignature`, `Get-FileHash` | voidtools-Forum (SDK3-Thread), NVD-Suche „voidtools" |
| Everything 1.5a | Versionsanzeige in Everything | voidtools-Forum (1.5-Alpha-Thread), NVD-Suche „voidtools" |
| 7-Zip (optional) | `(Get-Item $SevenZip).VersionInfo.FileVersion` | `https://www.7-zip.org/history.txt`, NVD |
| Pester / PSScriptAnalyzer (nur Entwicklung) | `Get-Module -ListAvailable Pester, PSScriptAnalyzer` | GitHub-Releases der Projekte |

> Ergebnis als datierte Zeile in „Befunde" unten (öffentliches Repo: nur generisch, keine konkreten internen Hosts).

---

## Schweregrad-Politik

| Severity | Reaktion |
|---|---|
| Critical | Sofort patchen (innerhalb 24h) oder Mitigation (Feature deaktivieren); blockiert das Inkrement |
| High | Blockiert das aktuelle Inkrement, bis gepatcht oder mitigiert (`principles/SECURITY_CURRENCY.md`) |
| Medium | Im nächsten regulären Inkrement |
| Low | Backlog; bei nächstem Major-Upgrade mitziehen |

Mitigation kann auch sein: Nutzung der verwundbaren Funktion entfernen,
falls Update nicht möglich ist.

---

## Befunde (datiert)

Ablage für Scanner- und Recherche-Ergebnisse (`principles/SECURITY_CURRENCY.md` → Artefakt). Neueste oben.
Öffentliches oder potenziell öffentliches Repo: die Betroffenheit **konkreter interner Hosts** nur in `docs/local/`,
hier nur generisch (`CONVENTIONS_COMMON.md` 3.1).

| Datum | Quelle (Scanner / URL) | Paket / Version | Befund | betrifft uns? (Begründung) | Maßnahme / Restrisiko |
|---|---|---|---|---|---|
| 2026-11-03 | https://www.voidtools.com/Everything-SDK-3.0.1.12.zip (`Changes.txt`), lokal: `Get-AuthenticodeSignature`, `Get-FileHash` | `Everything3_x64.dll` 3.0.1.12 (ersetzt 3.0.0.9) | SDK-Änderungen: Unterstützung mehrerer Sitzungen, besseres Warten auf ausgelastete Pipes; Signatur `Valid` (voidtools PTY LTD), SHA256 siehe `architecture/DEPENDENCIES.md`; alle 26 genutzten Funktionen in der Exportliste; Bibliotheksnamen im Binary unverändert (KERNEL32, USER32, OLEAUT32, ole32, mscoree) | Ja — mitgelieferte Binary | DLL ersetzt; Integrationstests (6) und `Test-EverythingConnection` gegen 1.5.0.1423b grün; 1424b ungetestet (I10) |
| 2026-11-03 | lokal gemessen (Everything 1.5.0.1424b, SDK 3.0.1.12) | Everything 1.5.0.1424b | Verbindung aus der eigenen Sitzung funktioniert; Pipes `Everything IPC` und `Everything IPC Session 1`; Instanz `1.5a` nicht mehr vorhanden (Fehler 0xE0000002); 6 Integrationstests und 18 Syntaxfälle unverändert grün | Ja | Aufruf aus anderer Sitzung ungemessen (I10) |
| 2026-11-03 | https://www.voidtools.com/forum/viewtopic.php?f=12&t=9787 (Changelog 1.5.0.1424b, 2026-10-15) | Everything 1.5.0.1424b | IPC nur noch von Clients derselben Sitzung; Clients prüfen die Vertrauenswürdigkeit des Dienstes; Absturz bei kombinierten Suchen behoben; Installer entfernt die Beta-Instanz `1.5a` samt Dienst | Ja — Modul braucht eine erreichbare Instanz; Aufrufe aus anderer Sitzung und der Fallback auf `1.5a` sind betroffen | I10: installieren, messen, Doku anpassen; Hinweis in THREAT_MODEL §6 |
| 2026-11-03 | NVD/Spiegel (cvefeed.io, vuldb.com, PT dbugs), Websuche „voidtools Everything vulnerability CVE 2026“ | Everything (Dienst), CVE-2025-12683 | Betroffen laut Spiegeln bis 1.4.1.1029; weder Vendor-Advisory noch Fix-Version bestätigt; für 2026 kein neuer CVE zu voidtools gefunden (Suche ohne Treffer ≠ Beweis der Abwesenheit) | Indirekt — wie 2026-10-11; ob 1.5.0.x betroffen ist, nennt keine Quelle | THREAT_MODEL §6 unverändert gültig; nächster Sweep prüft erneut |
| 2026-11-03 | https://github.com/PowerShell/Announcements/issues/98 und /99, Releases-Seite | PowerShell < 7.6.6 / < 7.5.11 / < 7.4.18 (CVE-2026-40400, nur Windows) bzw. < 7.4.20 (CVE-2026-62801, alle Plattformen) | Relative Path-Traversal, Codeausführung aus dem Netzwerk (Beschreibung laut Advisory-Seite); veröffentlicht 2026-07-20/2026-09-11, plus .NET-Advisories 2026-08/09; aktuell 7.6.9, 7.5.13, 7.4.22 (alle 2026-10-25) | Ja — Laufzeitumgebung aller Skripte; die Empfehlung ≥ 7.6.5 vom 2026-10-11 war zu niedrig | Empfehlung auf ≥ 7.6.6 angehoben (SETUP, DEPENDENCIES); lokal läuft 7.6.9; 7.4/7.5 Support-Ende 2026-11-10 |
| 2026-11-03 | https://www.7-zip.org/history.txt | 7-Zip 26.05 (2026-10-21) | Eintrag „Some bugs and vulnerabilities were fixed“ ohne CVE-Nummern | Ja — Beispielskript (wie 2026-10-11) | Mindestversion in Doku und I4 auf 26.05 angehoben |
| 2026-10-11 | https://www.7-zip.org/history.txt | 7-Zip < 26.04 | 26.01 (CVE-2026-48092 … -48112, Archiv-Handler), 26.02 (CVE-2026-14266, XZ-Heap-Overflow, RCE), 26.03 (CVE-2026-58052, Mark-of-the-Web), 26.04 („some bugs and vulnerabilities were fixed") | Ja — Beispielskript lässt `7z.exe` fremde Archive als Administrator parsen, `.tar.xz` per `x -so` (XZ-Decoder); MotW irrelevant (nichts wird auf Platte entpackt) | Mindestversion 26.04 empfehlen, Versionsprüfung + Timeout in I4; bis dahin Hinweis in `operations/SETUP.md` |
| 2026-10-11 | https://cvefeed.io/vuln/detail/CVE-2025-12683 (NVD-Eintrag „Deferred") | Everything (Dienst), Version nicht angegeben | Named Pipe Dienst↔GUI mit NULL-DACL: lokale DoS, in Kombination Rechteausweitung; CNA-Score uneinheitlich (5.8 bis 7.8) | Indirekt — Modul braucht Everything; Risiko für jeden Host mit Everything-Dienst | Hinweis in THREAT_MODEL §6 und SETUP; Vendor-Stand beim nächsten Sweep prüfen |
| 2026-10-11 | https://learn.microsoft.com/powershell/scripting/install/powershell-support-lifecycle | PowerShell 7.4 / 7.5 / 7.6 | 7.4 (LTS) und 7.5 Support-Ende 2026-11-10; 7.6 LTS seit 2026-03-18, Support bis 2028-11-14 | Ja — README nennt „getestet mit 7.5.2 und 7.6", Modul erlaubt ≥ 7.0 | README-Empfehlung auf 7.6 anheben (TODO, Niedrig) |
| 2026-10-11 | Drittquellen (ManageEngine-Schwachstellen-DB, OSV) — MSRC-Bestätigung offen | PowerShell < 7.6.5 (bzw. < 7.4.19 / < 7.5.10) | CVE-2026-58612, -59119, -70337, -70338, -50523 (u. a. Rechteausweitung, Code-/Command-Injection lokal), Fix in 7.6.5 (2026-08) | Ja — Laufzeitumgebung aller Skripte; als Administrator ausgeführtes Beispielskript besonders | 7.6 ≥ 7.6.5 empfehlen; beim nächsten Sweep gegen MSRC verifizieren |
| 2026-10-11 | https://learn.microsoft.com/powershell/module/microsoft.powershell.utility/send-mailmessage | `Send-MailMessage` | Cmdlet obsolet, „garantiert keine sicheren Verbindungen"; kein eingebauter Ersatz | Ja — Mailversand des Beispielskripts, Default ohne TLS | ADR in I7 (MailKit / Graph / Beibehalten mit STARTTLS-Pflicht) |
| 2026-10-11 | Websuche (NVD/allgemein) | .NET `System.IO.Compression` | Keine aktuelle CVE zu `ZipArchive` gefunden (Suche ohne Treffer ≠ Beweis der Abwesenheit) | — | beim nächsten Sweep erneut prüfen |
| 2026-10-11 | Websuche voidtools-Forum | Everything 1.5 Alpha, SDK 3.0.0.9 | Keine Sicherheits-Changelogs für Alpha-Builds gefunden (Entwickler listet Änderungen erst zur Beta/Release) | Unklar | Integrationstests nach jedem Update (I5); Stand beim Sweep prüfen |
| 2026-10-11 | lokal: `Get-AuthenticodeSignature`, `Get-FileHash` | `Everything3_x64.dll` 3.0.0.9 | Signatur `Valid` (voidtools PTY LTD, mit Zeitstempel; Signer-Zertifikat abgelaufen 2026-05-21), SHA256 siehe `architecture/DEPENDENCIES.md` | Referenzwert für die Integritätsprüfung (I2) | Prüfung muss zeitgestempelte Signaturen akzeptieren |

---

## SBOM (optional)

Kein SBOM-Werkzeug für PowerShell-Skriptmodule im Einsatz. Die Stückliste ist die Tabelle in
`architecture/DEPENDENCIES.md` (inkl. SHA256 der mitgelieferten DLL).

---

## Was nicht ausreicht

- **„Wir nutzen nur populäre Bibliotheken"** — populär ≠ sicher (siehe
  `event-stream`, `colors.js`, `xz-utils`).
- **GitHub Dependabot allein** — erkennt mitgelieferte Binaries (`Everything3_x64.dll`) und Systemwerkzeuge (7-Zip)
  nicht.
- **Einmaliger Audit beim Projektstart** — Audits müssen wiederholt werden,
  weil neue CVEs ständig erscheinen.
- **Scanner-Lauf allein** — hier gibt es ohnehin keinen; die Web-Recherche nach `principles/SECURITY_CURRENCY.md`
  ist die tragende Prüfung.

---

## Pflege

Trigger (siehe `KICKOFF.md` Phase 3a): neue Dependency hinzugefügt /
CVE-Meldung erhalten / Audit-Tool geändert → diese Datei + Audit-Artefakt
aktualisieren.
