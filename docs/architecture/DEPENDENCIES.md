# Externe Abhängigkeiten – PowerEverything3

Stand: 2026-10-11 (Init). CVE-/Lifecycle-Befunde zu diesen Abhängigkeiten: `docs/security/DEPENDENCY_AUDIT.md`.

---

## PSGallery-Module (Install-Module)

Zur Laufzeit: **keine.** Nur für Entwicklung/Quality Gates:

| Modul | Mindestversion | Zweck | Risiko bei Ausfall |
|-------|----------------|-------|-------------------|
| `Pester` | `5.7.1` (Pin ab I2 in `tests/RequiredModules.psd1`) | Gate 4 Unit-/Integrationstests | Keine Tests lauffähig; Laufzeit nicht betroffen |
| `PSScriptAnalyzer` | `1.25.0` (Init-Messung damit) | Gate 1 Linter | Keine Lint-Prüfung; Laufzeit nicht betroffen |

**Installationsbefehl (Entwickler, einmalig):**
```powershell
Install-Module -Name Pester -RequiredVersion 5.7.1 -Scope CurrentUser -Force -SkipPublisherCheck
Install-Module -Name PSScriptAnalyzer -Scope CurrentUser -Force

# Installation prüfen
Get-Module -Name Pester, PSScriptAnalyzer -ListAvailable | Select-Object Name, Version, Path
```

---

## Windows-/PowerShell-Bordmittel (kein Install-Module nötig)

| Modul / API | Zweck | Verfügbarkeit |
|-------|-------|--------------|
| `SmbShare` (`Get-SmbShare`) | Beispielskript: Datenfreigaben ermitteln, UNC-Pfade bilden | Windows (Server/Client) mit SMB-Server; Adminrechte nötig |
| `Microsoft.PowerShell.Security` (`Get-Acl`) | Beispielskript: Besitzer-SID von Ordnern/Archiven | Bestandteil von PowerShell 7 unter Windows |
| `Microsoft.PowerShell.Utility` (`Send-MailMessage`) | Beispielskript: Mailversand | PowerShell 7; Cmdlet ist laut Microsoft obsolet (`docs/security/DEPENDENCY_AUDIT.md`) |
| .NET `System.DirectoryServices` (ADSI/LDAP) | Beispielskript: SID → Konto, Mail, Status | PowerShell 7 unter Windows; Rechner in einer AD-Domäne |
| .NET `System.IO.Compression` (`ZipFile`) | Beispielskript: ZIP-Verzeichnis lesen; `ZipArchiveEntry.Crc32` ab .NET 7 (PowerShell 7.4) | PowerShell 7 |
| `kernel32.dll` (`LoadLibrary`) | Interop: DLL mit vollem Pfad laden | Windows |

---

## Externe Binaries

| Binary | Pfad | Zweck | Fehler-Verhalten |
|--------|------|-------|-----------------|
| `Everything3_x64.dll` (SDK 3.0.1.12, Authenticode: voidtools PTY LTD, SHA256 `450FAF011103C7DCE6049FDB7C8851E26578AC5D3A404A02E759529939D6F289`) | Modulordner (`$PSScriptRoot`) | Everything-SDK3-C-API (P/Invoke) | Modul-Import bricht mit „Fehler beim Laden der nativen DLL: <Pfad>" ab |
| `7z.exe` + `7z.dll` (optional, empfohlen ≥ 26.05) | `$SevenZip`, Default `%ProgramFiles%\7-Zip\7z.exe` | Beispielskript: Verzeichnis von 7z/rar/iso/tar.* lesen, `.tar.*` per `x -so` streamen | Nicht vorhanden → Inhaltsprüfung für Nicht-ZIP-Formate „content check N/A (no 7-Zip)"; Lauf geht weiter |

Die SDK-DLL stammt laut README aus `Everything-SDK-3.0.1.12.zip` (524889 Byte, SHA256 des ZIP `D35ED05F339D82B9E7ADD43FDA82EFC497EE5B09818B8FE0152FD90737B614FC` — im README in Kleinbuchstaben). Die Lizenz der
weiterverteilten DLL ist im Repository nicht dokumentiert (offener Punkt, `docs/BACKLOG.md` → PSGallery).

---

## Externe Services / APIs

| Service | URL / Endpunkt | Zweck | Fallback bei Ausfall |
|---------|---------------|-------|---------------------|
| Everything 1.5a (lokale Instanz, Prozess oder Dienst) | Named Pipe der Instanz (Standard; `1.5a` nur bei älteren Alpha-Installationen — 1.5.0.1424b entfernt sie), nur lokal | Suche im Index | Modul: `throw` nach Fallback auf Instanz `1.5a`. Beispielskript: `-SearchMode Auto` → Dateisystem-Scan, `Everything` → Abbruch |
| Active Directory | `LDAP://<SID=…>` über den Domänencontroller der eigenen Domäne (implizit) | Beispielskript: Besitzer-Konto, Mail-Adresse, Kontostatus | Unbekannte SID → Name per `SecurityIdentifier.Translate`, Status `Unknown` → Sammelmail |
| SMTP-Relay | `$SmtpServer:$SmtpPort` (Default `smtp.example.com:25`, ohne TLS) | Beispielskript: Mails an Besitzer / Debug / Sammelmail | Warnung je fehlgeschlagener Mail, Zähler „failed" |
| DNS | `[System.Net.Dns]::GetHostEntry('')` | Beispielskript: FQDN für UNC-Pfade | Fallback `$env:COMPUTERNAME` |

Credentials: nur optional für SMTP (`docs/security/AUTHENTICATION.md`).

---

## Systemabhängigkeiten

| Ressource | Mindestversion / Pfad | Zweck |
|-----------|----------------------|-------|
| Windows | x64, Version, auf der Everything 1.5 läuft (README nennt keine Mindestversion) | native DLL, Named Pipe, SMB/ACL-Cmdlets |
| PowerShell | ≥ 7.0 (Modul: `??`-Operator, Klassen); ≥ 7.2 (Beispielskript, `#Requires -Version 7.2`); ≥ 7.4 für CRC aus ZIP-Einträgen; empfohlen 7.6 (LTS, ≥ 7.6.6; aktuell 7.6.9) | Sprachfeatures, `ForEach-Object -Parallel`, `ProcessStartInfo.ArgumentList` |
| Everything | 1.5a (README: getestet 1.5.0.1424b und 1.5.0.1423b; Sitzungsbindung gemessen: Suche aus Sitzung 0 scheitert mit 0xE0000003) | Index + SDK3-Pipe |
| Modulordner | `Everything3_x64.dll` neben `.psd1`/`.psm1` | DLL-Pfad ist fest `$PSScriptRoot` |

---

## Upgrade-Hinweise

- **Everything3_x64.dll / SDK:** Signaturen gegen das neue `Everything3.h` abgleichen (`SIZE_T` → `UIntPtr`,
  `CharSet.Unicode`, Property-IDs); danach Integrationstests (I5) und `Test-EverythingConnection`. SHA256 und
  Signaturstatus hier aktualisieren.
- **Everything (Alpha-Builds):** nach Update Integrationstests laufen lassen; Pipe-/Instanznamen können sich ändern.
- **7-Zip:** Ausgabeformat von `7z l -slt` wird geparst (`Path = `, `Size = `, `Modified = `, `CRC = `, `Attributes`,
  `Folder`) — nach Major-Updates prüfen. Mindestversion folgt den Sicherheitsfixes (I4).
- **PowerShell:** 7.4/7.5 Support-Ende 2026-11-10; 7.6 enthält Breaking Changes gegenüber 7.4
  (z. B. `Join-Path -ChildPath` ist `string[]`) — Beispielskript nach Umstieg einmal komplett laufen lassen.
