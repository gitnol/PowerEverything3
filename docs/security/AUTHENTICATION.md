# Authentication – PowerEverything3

Jeder Auth-Mechanismus, den Modul und Beispielskript verwenden. Die Abschnitte des Stack-Templates zu Windows
Credential Manager (`TUN.CredentialManager`) und SSH-Key-Authentifizierung sind gestrichen — das Projekt nutzt beides
nicht.

---

## Auth-Übersicht

| Ziel | Verfahren | Secret-Ablageort | Anlage |
|------|-----------|-----------------|--------|
| Everything (lokale Instanz) | keine Authentifizierung; Named Pipe im Kontext des aufrufenden Benutzers | — | — |
| Active Directory (Beispielskript, Phase 2) | Windows-integriert (Kerberos/NTLM) über ADSI `LDAP://<SID=…>` | — (Anmeldung des ausführenden Kontos) | — |
| Dateisystem / SMB-Freigaben (Beispielskript) | Token des ausführenden Kontos (lokale Adminrechte) | — | — |
| SMTP-Relay (Beispielskript, Phase 4) | anonym (Default) oder SMTP-AUTH mit `-SmtpCredential` | DPAPI-Datei oder `SecretManagement` des Ausführungskontos, sonst interaktiv | Einmalig manuell (`docs/architecture/CREDENTIAL_STRATEGY.md`) |

---

## 1. Windows-integrierte Authentifizierung (AD-Abfrage)

`Resolve-Owner` öffnet `[System.DirectoryServices.DirectoryEntry]::new("LDAP://<SID=$sid>")` ohne explizites
Credential — die Anmeldung läuft implizit mit dem Konto, unter dem das Skript läuft.

**Voraussetzungen:**
- Rechner und ausführendes Konto gehören zur AD-Domäne der Besitzer-SIDs.
- Lesender LDAP-Zugriff auf `sAMAccountName`, `name`, `mail`, `userAccountControl`, `objectClass` (Standard für Domänenbenutzer).
- Lokale Adminrechte auf dem Fileserver für `Get-Acl` auf allen Pfaden und `Get-SmbShare`.

**Kein Domänen-Admin nötig.** Fehlt die Domäne, werden Besitzer per `SecurityIdentifier.Translate` nur benannt,
Status `Unknown` → Sammelmail.

---

## 2. SMTP-Anmeldung (`-SmtpCredential`)

- Default: anonymes Relay (`$SmtpCredential = $null`), Port 25, ohne TLS (`$SmtpUseSsl = $false`).
- Mit Anmeldung: `[PSCredential]` als Parameter übergeben; es wird nur an `Send-MailMessage -Credential` weitergereicht.
- **SMTP-AUTH ohne TLS überträgt die Anmeldung im Klartext** — wer `-SmtpCredential` nutzt, muss `$SmtpUseSsl = $true`
  setzen. Heute erzwingt das Skript das nicht (Kandidat für das `-Force`-Pattern, `docs/CONVENTIONS.md` §6.1; Entscheidung in I7).

Ablage und Aufruf: `docs/architecture/CREDENTIAL_STRATEGY.md` (DPAPI-Datei im Profil des Ausführungskontos oder
`SecretManagement`).

---

## Security-Checkliste

- [ ] Kein Plaintext-Passwort im Quellcode oder in `*.ps1`-Konfigurationsdateien
- [ ] DPAPI-Dateien (`*.xml`) außerhalb des Repositories, nur für das Ausführungskonto lesbar
- [ ] Ausführungskonto mit minimalen Rechten — lokaler Admin auf dem Fileserver, kein Domänen-Admin
- [ ] `-SmtpCredential` nur zusammen mit TLS (`$SmtpUseSsl = $true`)
- [ ] Bei Konto- oder Passwortwechsel: DPAPI-Datei neu anlegen (an das alte Konto gebunden)
