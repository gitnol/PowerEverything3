# Feature: Entpackte Archive auf Fileservern finden und melden (Beispielskript)

---

## Zweck

`Examples/Find-ArchivesWithExtractedFolder.ps1` findet Archive, neben denen ein gleichnamiger, bereits entpackter
Ordner liegt, prüft, ob der Ordner seit dem Entpacken verändert wurde, und benachrichtigt die Ordner-Besitzer per Mail —
ohne selbst etwas zu löschen.

---

## Technologie / Abhängigkeiten

- Modul `Everything3-PowerShell-Wrapper` (Phase 1a), Fallback paralleler Dateisystem-Scan (`ForEach-Object -Parallel`)
- .NET `System.IO.Compression` (ZIP), optional `7z.exe` + `7z.dll` (andere Formate)
- `Get-Acl`, `Get-SmbShare`, ADSI/LDAP, `Send-MailMessage`
- PowerShell ≥ 7.2, Administratorrechte, Domänenmitgliedschaft (`docs/architecture/DEPENDENCIES.md`)

---

## Ablauf

| Phase | Was passiert | Ergebnis |
|---|---|---|
| 1a | Archive ≥ `ReportMinMB` über Everything suchen (Indexprüfung je Pfad), sonst/Fallback Scan | Liste Archive |
| 1b | Gleichnamigen Ordner prüfen (`x.zip` → `x`, `x.tar.gz` → `x`, `x (2).zip` → `x`) | Kandidaten |
| 1c | Inhaltsprüfung Archiv ↔ Ordner (Stufe 1 immer, Stufe 2 mit `-CheckContentCrc`) | `identical` / `changed` / `N/A` |
| 2 | Besitzer-SID von Ordner und Archiv (`Get-Acl`, parallel), Auflösung je SID per LDAP | Besitzer mit Status |
| 3 | CSV (`;`, UTF-8 mit BOM) nach `OutputPath` | CSV + Transcript |
| 4 | Nur mit `-SendMail`: eine Mail je Besitzer (Treffer ≥ `MailMinMB`), nicht mailbare in eine Sammelmail | Mails |

Parameter und Konfigurationswerte: `docs/architecture/CONFIGURATION.md`.

---

## Parameter (Auswahl)

| Parameter | Typ | Pflicht | Default | Validierung | Beschreibung |
|-----------|-----|---------|---------|-------------|-------------|
| `-Path` | `[string[]]` | Nein (oder `-AllShares`) | `@()` | nicht existierende Pfade → Warnung, keiner übrig → `throw` | Basispfade |
| `-AllShares` | Switch | Nein | aus | keine Freigaben → `throw` | alle Datenfreigaben des Servers |
| `-SearchMode` | `[string]` | Nein | `Auto` | `[ValidateSet('Auto','Everything','Scan')]` | Suchstrategie |
| `-SendMail` | Switch | Nein | aus | — | ohne: Dry-Run (keine Mails) |
| `-Live` | Switch | Nein | aus | — | ohne: alle Mails an `$DebugTo` |
| `-MaxMails` | `[int]` | Nein | `0` | `[ValidateRange(0, [int]::MaxValue)]` | Mail-Limit pro Lauf |
| `-LastMonths` | `[int]` | Nein | `0` | `[ValidateRange(0, 600)]` | nur kürzlich geänderte Archive |

Das Skript kennt **kein** `-WhatIf`; die sichere Variante ist der Lauf ohne `-SendMail`.

---

## Geschäftsregeln

- **Nie löschen.** Das Skript liest und meldet nur.
- **Archivtypen:** `$ArchivePatterns` (Default 7z, zip, iso, rar, tar, tgz, gz, bz, bz2, xz, s7z).
- **Inhaltsprüfung Stufe 1:** gleiche relative Pfade (ohne Groß/Klein), gleiche Größe, Zeitstempel ±2 s
  (ZIP-Auflösung) oder genau 1 h ±2 s (Sommerzeit). Systemdateien laut `$ContentIgnore` zählen nicht. Hat das Archiv
  einen gemeinsamen Wurzelordner, wird auch die Variante ohne diesen verglichen — die mit den meisten Übereinstimmungen gilt.
- **Inhaltsprüfung Stufe 2:** zusätzlich CRC32 je Datei (liest alle Dateien des Ordners).
- **ZIP-Namen** ohne UTF-8-Flag werden mit Codepage 850 gelesen.
- **Mail-Empfänger:** Besitzer des **entpackten Ordners**, wenn Status `OK` oder `Group` und Adresse gültig;
  sonst Sammelmail an `$FallbackTo` (Status `Unknown`, `Disabled`, `NoMail`, `BuiltinAdmin`).
- **Mail-Pfade:** feste Ersetzung (`-ReplaceSource/-ReplaceTarget`, nur an Ordnergrenzen) vor UNC über die äußerste
  passende Freigabe (sichtbare vor versteckten) vor lokalem Pfad.
- **`-AllShares`:** ohne Sonderfreigaben, `$IgnoredShares` und DFS-Stämme; verschachtelte Freigaben → nur die äußerste.

---

## Kritische Patterns

- Schutzschalter `-SendMail`/`-Live` nicht aufweichen (`docs/CONVENTIONS.md` §6.1).
- Alle Fremdwerte in Mails mit `HtmlEncode`; Links über `ConvertTo-FileLink`.
- Pfade aus Treffern immer mit `-LiteralPath`.

---

## Bekannte Einschränkungen

| Einschränkung | Ursache | Status |
|---------------|---------|--------|
| Konfigurationsdatei wird als Code ausgeführt und kann Parameter überschreiben | Dot-Sourcing | Geplant in I3 |
| 7-Zip-Aufrufe ohne Timeout, keine Versionsprüfung | `Invoke-SevenZip` | Geplant in I4 |
| Funktionen nicht separat testbar | Funktionen und Ablauf in einer Datei | Geplant in I6 |
| Mailtext verspricht wiederkehrende Mails, Zeitplanung fehlt | Betriebsentscheidung | K4, Akzeptiert |
| Mail ohne TLS per Default, `Send-MailMessage` obsolet | Default `$SmtpUseSsl = $false` | Geplant in I7 |

---

## Bekannte Fallstricke

- Ohne Everything und mit `-SearchMode Auto` scannt das Skript — auf großen Freigaben Stunden.
- `-SearchMode Everything` überspringt nicht indizierte Pfade (Warnung + Liste am Ende von Phase 1).
- CSV und Transcript enthalten personenbezogene Daten (`docs/security/DATA_HANDLING.md`).

---

## Teststrategie

- I6: Charakterisierungstests der reinen Funktionen (`Get-MailPath`, `ConvertTo-SharePath`, `Get-ShareBasePaths`,
  `Get-DataShares -Raw`, `ConvertTo-FileLink`, `Test-MailAddress`, `New-MailBody`, `Compare-ArchiveWithFolder`) mit
  Mutationsprüfung; ZIP-Fixtures im Temp-Ordner.
- I3/I4: Ende-zu-Ende ohne Adminrechte und ohne Mails (`-SearchMode Scan`, Temp-Fixture, kein `-SendMail`).
- Kritische Testfälle: Konfiguration kann `-Live` nicht setzen; hängender 7-Zip-Aufruf → `N/A (timeout)`;
  feindliche Ordnernamen werden in Mails kodiert.
