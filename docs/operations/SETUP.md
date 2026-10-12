# Entwicklungsumgebung Setup – PowerEverything3

---

## Voraussetzungen

- Windows x64
- PowerShell ≥ 7.0 für das Modul, ≥ 7.2 für das Beispielskript (`$PSVersionTable.PSVersion` prüfen)
  - Windows PowerShell 5.1 wird **nicht** unterstützt (Syntax `??`); empfohlen: PowerShell 7.6 (LTS) in der aktuellen
    Patch-Version (≥ 7.6.5, `docs/security/DEPENDENCY_AUDIT.md`)
- Everything 1.5a installiert und gestartet (https://www.voidtools.com/everything-1.5a/). Hinweis zum Everything-Dienst:
  `docs/security/THREAT_MODEL.md` §6 (CVE-2025-12683)
- `Everything3_x64.dll` liegt im Modulordner (im Repository enthalten)
- Nur Beispielskript: Domänenmitgliedschaft, lokale Adminrechte, optional 7-Zip ≥ 26.04 (`7z.exe` **und** `7z.dll`),
  erreichbares SMTP-Relay
- Nur Entwicklung: Pester 5.7.1, PSScriptAnalyzer (`docs/architecture/DEPENDENCIES.md`)

---

## Installation

### PowerShell 7+

```powershell
winget install Microsoft.PowerShell
# oder: https://github.com/PowerShell/PowerShell/releases
```

### Execution Policy (einmalig, aktueller Benutzer)

```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### Repository und Modul

```powershell
git clone https://github.com/gitnol/PowerEverything3.git
cd PowerEverything3
Import-Module .\Everything3-PowerShell-Wrapper.psd1 -Verbose   # immer die .psd1 (KNOWN_ISSUES K1)
Test-EverythingConnection
```

Für dauerhafte Nutzung den Modulordner (inkl. DLL) an einen nur für Administratoren beschreibbaren Ort kopieren
(`docs/security/THREAT_MODEL.md` §1).

### Entwicklungswerkzeuge

```powershell
Install-Module -Name Pester -RequiredVersion 5.7.1 -Scope CurrentUser -Force -SkipPublisherCheck
Install-Module -Name PSScriptAnalyzer -Scope CurrentUser -Force
git config core.hooksPath tools/git-hooks          # Interna-Hook aktivieren (pro Klon)
# .internal-terms im Repo-Root anlegen: ein interner Begriff pro Zeile (Hosts, Domänen, Konten),
# Zeilen mit # sind Kommentare — gitignored, nie committen (docs/CONVENTIONS_COMMON.md 3.1)
```

### Konfiguration des Beispielskripts

```powershell
cd .\Examples
Copy-Item .\Find-ArchivesWithExtractedFolder.config.example.ps1 .\Find-ArchivesWithExtractedFolder.config.ps1
# Werte anpassen — die echte *.config.ps1 ist gitignored und enthält keine Secrets
```

---

## Wichtige Commands

```powershell
# Modul: Suche
Find-Files -Pattern "*.pdf" -MaxResults 10
$c = Connect-Everything; Search-Everything -Client $c -Query 'size:>100mb' -Properties Size -MaxResults 5; Disconnect-Everything -Client $c

# Beispielskript: Dry-Run (nur CSV + Transcript, keine Mails)
.\Examples\Find-ArchivesWithExtractedFolder.ps1 -Path 'D:\Daten' -SearchMode Everything

# Beispielskript: Testmails (alle an $DebugTo, höchstens 3)
.\Examples\Find-ArchivesWithExtractedFolder.ps1 -Path 'D:\Daten' -SendMail -MaxMails 3

# Hilfe
Get-Help .\Examples\Find-ArchivesWithExtractedFolder.ps1 -Full

# Quality Gates (docs/CONVENTIONS.md §9)
Invoke-ScriptAnalyzer -Path . -Recurse -Severity Warning
Invoke-Pester tests/ -ExcludeTag Integration -Output Detailed   # ab I2
```

---

## Credentials / Konfiguration

| Variable / Parameter | Beschreibung | Fundort |
|---------------------|-------------|---------|
| `-SmtpCredential` | Optionale SMTP-Anmeldung des Beispielskripts | DPAPI-Datei oder `SecretManagement` des Ausführungskontos (`docs/architecture/CREDENTIAL_STRATEGY.md`) |
| `Find-ArchivesWithExtractedFolder.config.ps1` | SMTP-Relay, Absender/Empfänger, Kontakt — keine Secrets | lokal neben dem Skript, gitignored; Schlüssel: `docs/architecture/CONFIGURATION.md` |

> **Niemals Credentials in die Konfigurationsdatei schreiben.** Interne Hostnamen/Adressen gehören nur in die lokale
> Konfiguration bzw. `docs/local/`, nie in versionierte Dateien.
