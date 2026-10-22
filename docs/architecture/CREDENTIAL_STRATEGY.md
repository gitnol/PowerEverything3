# Credential-Strategie – PowerEverything3

Wo und wie Credentials für PowerShell-Automatisierung gespeichert und benutzt werden.
Konkretisiert `docs/operations/SECRETS_MANAGEMENT.md` für Windows / PowerShell.

---

## Bestand im Projekt

| Komponente | Credential | Herkunft |
|---|---|---|
| Modul → Everything | keines | lokale Named Pipe im Kontext des aufrufenden Benutzers |
| Beispielskript → AD (LDAP) | keines explizit | Windows-integriert (Kerberos) mit dem ausführenden Konto |
| Beispielskript → Dateisystem/SMB | keines explizit | ausführendes Konto (Administrator auf dem Fileserver) |
| Beispielskript → SMTP | optional `-SmtpCredential` (`[PSCredential]`) | vom Aufrufer übergeben; ohne Angabe anonymes Relay |

Weitere Credentials gibt es nicht. Neue kommen nur über `[PSCredential]`-Parameter hinzu — nie über die
Konfigurationsdatei.

---

## Erlaubte Speicherorte

| Credential-Typ | Empfohlener Store | Bemerkung |
|---|---|---|
| SMTP-Anmeldung für `-SmtpCredential` (interaktiv) | `Get-Credential` beim Aufruf | Nichts wird gespeichert |
| SMTP-Anmeldung für geplante Läufe | `SecretManagement`-Vault oder DPAPI-Datei (`Export-Clixml`) des Ausführungskontos | Nicht in `*.config.ps1` |
| Passwort eines Ausführungskontos (falls Betreiber plant) | gMSA oder Aufgabenplanung (verschlüsselt) | Im Repository nicht vorgesehen (`docs/KNOWN_ISSUES.md` K4) |

---

## DPAPI-Pattern (User-bound) für `-SmtpCredential`

```powershell
# Einmalig, als das Konto, das das Skript später ausführt
Get-Credential -Message 'SMTP-Anmeldung' | Export-Clixml -Path "$env:LOCALAPPDATA\PowerEverything3\smtp.cred.xml"

# Aufruf
.\Find-ArchivesWithExtractedFolder.ps1 -AllShares -SendMail -Live `
    -SmtpCredential (Import-Clixml "$env:LOCALAPPDATA\PowerEverything3\smtp.cred.xml")
```

**Wichtig:** DPAPI verschlüsselt mit dem Benutzerprofil; die Datei ist nur für das Konto lesbar, das sie angelegt hat.
Ablage außerhalb des Repositories (Profilordner), damit sie nicht versehentlich committet wird.

---

## `SecretManagement` (Alternative)

```powershell
Install-Module Microsoft.PowerShell.SecretManagement, Microsoft.PowerShell.SecretStore -Scope CurrentUser
Register-SecretVault -Name LocalStore -ModuleName Microsoft.PowerShell.SecretStore -DefaultVault
Set-Secret -Name 'PowerEverything3-Smtp' -Secret (Get-Credential)
.\Find-ArchivesWithExtractedFolder.ps1 -AllShares -SendMail -SmtpCredential (Get-Secret 'PowerEverything3-Smtp')
```

---

## Ausführungskonto

| Szenario | Konto | Hinweis |
|---|---|---|
| Modul interaktiv | aktueller Benutzer | Welche Treffer sichtbar sind, bestimmt die Everything-Instanz (Index-Umfang, Einstellungen) — ob NTFS-Rechte des Benutzers gefiltert werden, ist ungeprüft |
| Beispielskript auf dem Fileserver | dediziertes Konto mit lokalen Adminrechten auf diesem Server | Braucht `Get-Acl` auf allen Pfaden und `Get-SmbShare`; **kein** Domänen-Admin nötig (LDAP-Lesen reicht als Domänenbenutzer) |

---

## Anti-Pattern

```powershell
# Verboten: SMTP-Passwort in der Konfigurationsdatei
$SmtpPassword = '<klartext-passwort>'

# Verboten: Credential aus Klartext im Aufruf bauen
-SmtpCredential ([pscredential]::new('svc', (ConvertTo-SecureString '<klartext-passwort>' -AsPlainText -Force)))
```

---

## Logging-Regeln

- Das Beispielskript schreibt ein vollständiges Transcript (`Start-Transcript`). Credentials dürfen daher nie als
  Text ausgegeben werden — `[PSCredential]` wird nur an `Send-MailMessage` durchgereicht.
- Bei Fehlern: Auth-Failure als Ereignis („Sending to '…' failed: …") loggen, nie Anmeldedaten.

---

## Rotation

| Credential | Intervall | Trigger außerplanmäßig |
|---|---|---|
| SMTP-Anmeldung | nach Betreiber-Policy | Leak-Verdacht, Kontowechsel |
| DPAPI-Datei | bei jeder Passwortänderung neu anlegen | Kontowechsel (Datei an altes Konto gebunden) |

---

## Pflege

Trigger: neuer Service / neue Credential-Quelle / Rotation durchgeführt →
hier eintragen und in `docs/operations/SECRETS_MANAGEMENT.md` referenzieren.
