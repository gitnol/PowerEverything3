# Runbook – PowerEverything3

Häufige Operationen und Troubleshooting für Modul und Beispielskript.

---

## Häufige Commands

```powershell
# Modul laden und Verbindung prüfen
Import-Module .\Everything3-PowerShell-Wrapper.psd1 -Force
Test-EverythingConnection

# Beispielskript: Dry-Run über alle Datenfreigaben
.\Examples\Find-ArchivesWithExtractedFolder.ps1 -AllShares -SearchMode Everything

# Beispielskript: nur Sammelmail an $FallbackTo
.\Examples\Find-ArchivesWithExtractedFolder.ps1 -AllShares -SendMail -SummaryOnly

# Beispielskript: Produktion (Mails an Besitzer)
.\Examples\Find-ArchivesWithExtractedFolder.ps1 -AllShares -SearchMode Everything -SendMail -Live

# Ausführliches Logging
.\Examples\Find-ArchivesWithExtractedFolder.ps1 -Path 'D:\Daten' -Verbose

# Fehlerdetails anzeigen
$Error[0] | Format-List * -Force
```

---

## Troubleshooting

### „Fehler beim Verbinden mit Standard- und '1.5a'-Everything-Instanzen"
→ Everything 1.5a läuft nicht oder unter anderem Instanznamen: Everything starten, ggf. `-InstanceName` angeben.
→ `Test-EverythingConnection` zeigt Version und ob der Index geladen ist.

### „Fehler beim Laden der nativen DLL: …\Everything3_x64.dll"
→ DLL fehlt im Modulordner oder der Prozess ist kein x64-Prozess (`[Environment]::Is64BitProcess`).

### „Unable to find type [Everything3SDK]" / „Der Typ [Everything3SDK] wurde nicht gefunden"
→ Die `.psm1` wurde direkt importiert. Stattdessen `Import-Module .\Everything3-PowerShell-Wrapper.psd1` (KNOWN_ISSUES K1).

### Parserfehler beim Import (z. B. bei `??`)
→ Windows PowerShell 5.1 statt PowerShell 7 — mit `pwsh` starten.

### „Path is not in the Everything index and is skipped (-SearchMode Everything)"
→ Pfad in Everything indizieren (Laufwerk/Ordner in den Index-Einstellungen) oder mit `-SearchMode Auto` scannen lassen.
→ Am Ende von Phase 1 listet „ATTENTION: … NOT searched" alle übersprungenen Pfade.

### „Could not read shares (Get-SmbShare, admin rights?)"
→ Skript nicht als Administrator gestartet; Pfade bleiben lokal, `-AllShares` bricht ab.

### Inhaltsprüfung meldet „content check N/A (no 7-Zip)"
→ `7z.exe` und `7z.dll` unter `$SevenZip` bereitstellen (portabel: beide in einen Ordner; `7za.exe` reicht nicht).

### „Sending to '…' failed"
→ SMTP-Relay/Port prüfen, Relay-Berechtigung des Servers, ggf. `-SmtpCredential` + TLS (`docs/security/AUTHENTICATION.md`).

### Lauf hängt in Phase 1c
→ Ein 7-Zip-Aufruf blockiert (kein Timeout, I4). Prozess `7z.exe` im Task-Manager beenden; betroffenes Archiv steht in
der Fortschrittsanzeige („Content check archive <-> folder").

---

## Deployment-Checkliste (Beispielskript auf einem Fileserver)

- [ ] PowerShell ≥ 7.2 (empfohlen 7.6.x) auf dem Zielsystem
- [ ] Everything 1.5a läuft und indiziert die Datenlaufwerke
- [ ] Modulordner inkl. DLL an einem nur für Administratoren beschreibbaren Ort
- [ ] `*.config.ps1` angelegt — **ohne** Credentials; Ordner nur für Administratoren beschreibbar (THREAT_MODEL §2)
- [ ] `-OutputPath` auf geschützten Ordner außerhalb des Skriptordners (DATA_HANDLING §3)
- [ ] Dry-Run (ohne `-SendMail`) geprüft, dann Testmails (`-SendMail -MaxMails 3`), erst dann `-Live`
- [ ] 7-Zip in empfohlener Mindestversion oder bewusst ohne 7-Zip (nur ZIP-Prüfung)
