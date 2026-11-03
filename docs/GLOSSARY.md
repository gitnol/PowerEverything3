# Glossar – PowerEverything3

Ubiquitous Language für dieses Projekt. Jeder Begriff hat genau eine Bedeutung.
Synonyme oder doppelt belegte Begriffe schaffen Drift und werden vermieden.

LLM-Agenten konsultieren dieses Glossar, **bevor** sie Begriffe im Code, in
Commit-Messages oder in Doku verwenden.

---

## Begriffe

| Begriff | Bedeutung | Wo verwendet | Nicht zu verwechseln mit |
|---|---|---|---|
| Everything | Dateisuchmaschine von voidtools (hier Version 1.5a), die einen eigenen Index der NTFS-Volumes hält und über eine Named Pipe abfragbar ist | gesamtes Projekt | Windows-Suche / Windows-Indexdienst |
| Everything-Instanz | Laufende Everything-Installation, über ihren Instanznamen adressiert (Standard oder `1.5a`) | `Connect-Everything -InstanceName` | Everything-Dienst (nur der Hilfsdienst mit SYSTEM-Rechten) |
| SDK3 | Everything SDK Version 3 (`Everything3_x64.dll`, hier 3.0.1.12) — C-API für Everything 1.5 | `Everything3SDK.psm1` | Everything SDK 2 (`Everything64.dll`, Everything 1.4) — nicht unterstützt |
| Interop-Schicht | `Everything3SDK.psm1`: DLL laden + P/Invoke-Signaturen (`[Everything3SDK]`, `[Everything3Properties]`) | `Everything3SDK.psm1` | öffentliche API |
| Client | Verbindungs-Handle zur Everything-Instanz (`[Everything3Client]`); muss mit `Disconnect-Everything` freigegeben werden | `Connect-Everything`, `Search-Everything -Client` | Search-State |
| Search-State | Natives Objekt mit Suchtext und Optionen (Viewport, Match-Flags, Property-Requests, Sortierung) für genau eine Suche | `Search-Everything` | Result-List |
| Result-List | Natives Ergebnis einer Suche; wird nach dem Auslesen mit `Everything3_DestroyResultList` freigegeben | `Search-Everything` | Treffer |
| Treffer | Ein Ergebnis-Objekt `[Everything3Result]` mit `FullPath`, `Name`, `Directory`, `Properties`, `Exists` | Rückgabe von `Search-Everything`/`Find-Files` | Result-List |
| Viewport | Ausschnitt der Treffer: `-Offset` (Start) und `-MaxResults` (Anzahl, `0` = alle) | `Search-Everything` | Paging im Beispielskript (gibt es nicht) |
| Property | Vom Index gelieferte Eigenschaft eines Treffers (`Name`, `Path`, `Size`, `DateModified`, …), angefordert über ihre Property-ID | `Get-PropertyId`, `-Properties` | PowerShell-Objekteigenschaft |
| Indiziert | Ein Pfad ist im Everything-Index enthalten; im Beispielskript geprüft durch eine Suche nach dem Ordner selbst (Ergebnis ≥ 1) | `Find-ArchivesWithExtractedFolder.ps1` Phase 1a | „existiert auf der Platte" (`-CheckExists`) |
| Entpacktes Archiv | Archivdatei, neben der ein gleichnamiger Ordner liegt (auch `Name (2)` → `Name`) | Beispielskript Phase 1b | jedes beliebige Archiv |
| Inhaltsprüfung | Vergleich Archiv ↔ entpackter Ordner: Stufe 1 Dateiliste/Größe/Zeitstempel, Stufe 2 (`-CheckContentCrc`) zusätzlich CRC32; Ergebnis `identical`, `changed` oder `N/A` | Beispielskript Phase 1c | Integritätsprüfung der DLL |
| Besitzer | Owner (SID aus `Get-Acl`) des **entpackten Ordners**, aufgelöst per LDAP; Status `OK`, `Disabled`, `NoMail`, `Group`, `BuiltinAdmin`, `Unknown` | Beispielskript Phase 2 | Ersteller der Archivdatei (`ArchiveOwnerMail`) |
| Sammelmail | Eine Mail an `$FallbackTo` mit allen Treffern ohne mailbaren Besitzer | Beispielskript Phase 4 | Debug-Mail |
| Debug-Modus | Mailversand ohne `-Live`: alle Mails gehen an `$DebugTo` | Beispielskript | Dry-Run |
| Dry-Run | Lauf ohne `-SendMail`: nur CSV und Transcript, keine Mails | Beispielskript | Debug-Modus |
| Datenfreigabe | SMB-Freigabe des Servers vom Typ Dateisystem, ohne Sonderfreigaben (`C$`, `ADMIN$`, …) und `$IgnoredShares` | `Get-DataShares` | DFS-Stamm |
| DFS-Stamm | Ordner, der nur DFS-Links (Reparse Points) enthält; wird bei `-AllShares` übersprungen | `Test-DfsRoot` | Datenfreigabe |
| Mail-Pfad | Pfad, wie er in Mails erscheint: feste Ersetzung, sonst UNC über die äußerste passende Freigabe, sonst lokal | `Get-MailPath` | lokaler Pfad (`Folder`) |

---

## Verbotene Synonyme

Begriffe, die im Projekt-Kontext **nicht** mehr verwendet werden dürfen,
auch wenn sie umgangssprachlich gleichbedeutend wirken:

| Verbotener Begriff | Korrekt | Grund |
|---|---|---|
| „Datenbank" für den Everything-Index | Index | Projekt hat keine eigene Datenbank; nur der SDK-Aufruf heißt `Everything3_IsDBLoaded` |
| „löschen"/„aufräumen" für das Beispielskript | berichten, benachrichtigen | Das Skript löscht nie etwas; „Bereinigung" erledigen die Besitzer |
| „Owner des Archivs" als Mail-Empfänger | Besitzer (des entpackten Ordners) | Mails richten sich nach dem Ordner-Besitzer, nicht nach dem Archiv-Besitzer |

---

## Pflege

- Neuer Domänenbegriff im Code → **vor dem Commit** hier ergänzen.
- Begriff wird umbenannt → alter Eintrag bleibt mit Vermerk „ersetzt durch [Neu]"
  stehen (mindestens eine Inkrement-Generation als Übergangsphase).
- Begriff entfällt → Eintrag mit „deprecated [Datum]" markieren, nicht löschen.
- Diese Datei steht in der Trigger-Matrix in `KICKOFF.md` Phase 3a.
