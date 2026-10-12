# Konfiguration – PowerEverything3

Wo Werte herkommen, in welcher Reihenfolge sie überschreiben, und wie sie
validiert werden. Verbindet sich mit den Prinzipien [[EXPLICIT_OVER_IMPLICIT]]
und [[FAIL_FAST]].

---

## Modul `Everything3-PowerShell-Wrapper`

Das Modul hat **keine** Konfigurationsdatei und liest keine Umgebungsvariablen. Alle Werte kommen als
Funktionsparameter (mit Defaults im `param()`-Block). Einzige implizite Werte: Der DLL-Pfad ist fest
`$PSScriptRoot\Everything3_x64.dll`, der Instanzname fällt bei leerem `-InstanceName` auf `1.5a` zurück.

---

## Beispielskript `Find-ArchivesWithExtractedFolder.ps1`

### Quellen-Hierarchie (Ist-Zustand, höchste zuerst)

1. **Konfigurationsdatei** `Find-ArchivesWithExtractedFolder.config.ps1` neben dem Skript (oder `-ConfigFile`) —
   wird per Dot-Sourcing **im Skript-Scope ausgeführt** (Zeile 124–125). Sie überschreibt die Code-Defaults und kann
   technisch auch die bereits gebundenen Parameter (`$Live`, `$SendMail`, `$Path`, …) überschreiben.
2. **CLI-Parameter** (`param()`-Block) — gelten, solange die Konfigurationsdatei sie nicht neu setzt.
3. **Code-Defaults** im Abschnitt „Configuration (defaults)" des Skripts.

Keine Umgebungsvariablen außer `%ProgramFiles%` (Default-Pfad von `7z.exe`).

**Abweichung vom Template-Soll** (CLI vor Datei vor Default): Dass die Datei Parameter überschreiben kann und als Code
ausgeführt wird, ist ein Sicherheits- und Nachvollziehbarkeitsproblem (`docs/security/THREAT_MODEL.md` §2) → I3
(Konfiguration als Daten, ADR).

### Validierung beim Laden

- Parameter: `[ValidateRange]` (`MaxMails`, `LastMonths` 0–600, `ThrottleLimit` 1–64), `[ValidateSet]` (`SearchMode`).
- `-Path`: nicht existierende Pfade werden mit Warnung übersprungen; keiner übrig → Abbruch (`throw`).
- Werte aus der Konfigurationsdatei werden **nicht** validiert (z. B. `MailMinMB`, Mail-Adressen, `$SevenZip`); ein
  fehlendes `7z.exe` führt nur zu „content check N/A".
- Ziel nach I3: erlaubte Schlüssel als Liste, Typ-/Bereichsprüfung beim Laden, danach keine Mutation mehr.

---

## Secrets gehören NICHT in normale Konfigurationsdateien

- Einziges Secret ist das optionale `-SmtpCredential` (`[PSCredential]`) — **nur als Parameter**, nie in der
  Konfigurationsdatei (Details: `docs/architecture/CREDENTIAL_STRATEGY.md`, `docs/operations/SECRETS_MANAGEMENT.md`).
- Die echte `*.config.ps1` ist gitignored, weil sie interne Adressen (SMTP-Relay, Mail-Adressen, Servername) enthält —
  sie ist **intern**, aber kein Secret-Speicher.

---

## Konfigurationsobjekt — Verwendung

- Modul: Funktionen erhalten alles als Parameter — so bleibt es.
- Beispielskript: Die Werte sind Skript-Variablen, auf die Funktionen implizit zugreifen (z. B. `$SevenZip`,
  `$ContentIgnore`, `$SmtpServer`). Mit I6 (Funktionen trennen) werden sie als Parameter übergeben.

---

## Konfigurations-Tabelle

### Parameter des Beispielskripts

| Schlüssel | Typ | Default | Quelle(n) | Beschreibung |
|---|---|---|---|---|
| `Path` | `string[]` | `@()` | CLI | Zu durchsuchende Basispfade |
| `AllShares` | `switch` | aus | CLI | Alle Datenfreigaben des Servers durchsuchen (ohne DFS-Stämme, verschachtelte zusammengefasst) |
| `ReplaceSource` / `ReplaceTarget` | `string[]` | `@()` | CLI | Paarweise feste Pfadersetzung für Mails; Ziel leer/`auto` = UNC über Freigabe |
| `SendMail` | `switch` | aus | CLI | Mails wirklich senden (sonst Dry-Run) |
| `Live` | `switch` | aus | CLI | Mails an echte Besitzer (sonst alles an `$DebugTo`) |
| `SummaryOnly` | `switch` | aus | CLI | Nur die Sammelmail an `$FallbackTo` |
| `CheckContentCrc` | `switch` | aus | CLI | Inhaltsprüfung Stufe 2 (CRC32 je Datei, langsam) |
| `MaxMails` | `int` | `0` (unbegrenzt) | CLI | Höchstzahl Mails pro Lauf |
| `SearchMode` | `string` | `Auto` | CLI | `Auto` (Everything, Fallback Scan), `Everything` (nicht indizierte Pfade überspringen), `Scan` |
| `LastMonths` | `int` | `0` (alle) | CLI | Nur Archive, die in den letzten N Monaten geändert wurden |
| `ThrottleLimit` | `int` | `8` | CLI | Parallelität für Scan und `Get-Acl` |
| `OutputPath` | `string` | `$PSScriptRoot` | CLI | Ablage für CSV und Transcript |
| `ConfigFile` | `string` | `<Skriptordner>\Find-ArchivesWithExtractedFolder.config.ps1` | CLI | Pfad der Konfigurationsdatei |
| `SmtpCredential` | `PSCredential` | `$null` (anonymes Relay) | CLI | Optionale SMTP-Anmeldung |

### Werte im Skript (überschreibbar per Konfigurationsdatei)

| Schlüssel | Typ | Default | Quelle(n) | Beschreibung |
|---|---|---|---|---|
| `ArchivePatterns` | `string[]` | `*.7z, *.zip, *.iso, *.rar, *.tar, *.tgz, *.gz, *.bz, *.bz2, *.xz, *.s7z` | Code / FILE | Gesuchte Archivtypen |
| `ReportMinMB` | `int` | `10` | Code / FILE | Mindestgröße für CSV/Ergebnis |
| `MailMinMB` | `int` | `100` | Code / FILE | Mindestgröße für Mails |
| `SmtpServer` / `SmtpPort` / `SmtpUseSsl` | `string` / `int` / `bool` | `smtp.example.com` / `25` / `$false` | Code / FILE | SMTP-Relay (TLS-Default → I7) |
| `MailFrom` / `DebugTo` / `FallbackTo` | `string` | `helpdesk@example.com` / `admin@example.com` / `helpdesk@example.com` | Code / FILE | Absender, Debug-Empfänger, Empfänger der Sammelmail |
| `MailSubject` / `MailEncoding` | `string` / `Encoding` | englischer Betreff / UTF-8 | Code / FILE | Mail-Betreff und Kodierung |
| `ContactPhone` / `ContactEmail` | `string` | Beispielwerte | Code / FILE | Kontakt im Mailtext |
| `ShareAutoMapping` | `bool` | `$true` | Code / FILE | Pfade in Mails als `\\server\share\…` |
| `UncServer` | `string` | FQDN des ausführenden Rechners | Code / FILE | Servername in UNC-Pfaden |
| `IgnoredShares` | `string[]` | `print$, SYSVOL, NETLOGON, CertEnroll, REMINST, WsusContent, UpdateServicesPackages` | Code / FILE | Nicht durchsuchte Freigaben |
| `EverythingModule` | `string` | `..\Everything3-PowerShell-Wrapper.psd1` | Code / FILE | Pfad zum Modul-Manifest |
| `SevenZip` | `string` | `%ProgramFiles%\7-Zip\7z.exe` | Code / FILE | 7-Zip für Nicht-ZIP-Formate (`7z.exe` + `7z.dll`) |
| `ContentIgnore` | `string` (Regex) | `Thumbs.db`, `desktop.ini`, `.DS_Store`, `~$*`, `*.tmp`, `__MACOSX/` | Code / FILE | Systemdateien, die beim Inhaltsvergleich nicht zählen |

---

## Anti-Pattern

- **Konfiguration als ausführbarer Code** (Dot-Sourcing) — führt beliebigen Code mit den Rechten des Skripts aus.
- **Funktionen lesen Skript-Variablen implizit** statt Parameter zu bekommen (heute im Beispielskript).
- **Magic Defaults im Code** (`timeout=30` in jeder Funktion neu) statt zentralem Wert.

---

## Pflege

Trigger (siehe `KICKOFF.md` Phase 3a): neue Konfig-Quelle / neuer Schlüssel /
geänderte Präzedenz → diese Datei eintragen, Validierung implementieren,
Tabelle aktualisieren.
