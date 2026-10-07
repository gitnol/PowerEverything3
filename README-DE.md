# Everything3 PowerShell Wrapper

[English version](README.md)

Ein leistungsstarker und benutzerfreundlicher PowerShell-Wrapper für die [Everything Search Engine](https://www.voidtools.com/) (Version 1.5+). Dieses Modul nutzt die `Everything3_x64.dll` aus dem Everything SDK, um eine extrem schnelle Dateisuche direkt aus der PowerShell-Konsole zu ermöglichen.

Getestet wurde es mit:
- PowerShell 7.5.2 und 7.6
- Everything 1.5.0.1423b-x64 (zuvor 1.5.0.1396a)
  - Webseite: https://www.voidtools.com/everything-1.5a/
  - Changelog: https://www.voidtools.com/forum/viewtopic.php?f=12&t=9787
- SDK Version 3.0.0.9 (enthaltene `Everything3_x64.dll`, signiert von voidtools PTY LTD)
  - Webseite: https://www.voidtools.com/forum/viewtopic.php?t=15853
  - Download: https://www.voidtools.com/Everything-SDK-3.0.0.9.zip
  - Größe: (503 KB - SHA256: 124685d35a5f49f3c1e9898853e166215748c893782c6a251f5dde58dacad4fa)
  - GitHub: https://github.com/voidtools/everything_sdk3

## Inhaltsverzeichnis

- [Everything3 PowerShell Wrapper](#everything3-powershell-wrapper)
  - [Inhaltsverzeichnis](#inhaltsverzeichnis)
  - [Features](#features)
  - [Anforderungen](#anforderungen)
  - [Quick Start](#quick-start)
  - [Funktionen](#funktionen)
  - [Anwendungsbeispiele](#anwendungsbeispiele)
    - [Einfache Suchen mit `Find-Files`](#einfache-suchen-mit-find-files)
    - [Erweiterte Suchen mit `Search-Everything`](#erweiterte-suchen-mit-search-everything)
    - [Alle Treffer und Existenzprüfung](#alle-treffer-und-existenzprüfung)
  - [Praxisbeispiel: Archive neben ihrem entpackten Ordner](#praxisbeispiel-archive-neben-ihrem-entpackten-ordner)
  - [VSCode-Besonderheiten](#vscode-besonderheiten)
  - [Änderungen](#änderungen)
  - [Lizenz \& Haftungsausschluss](#lizenz--haftungsausschluss)

---

## Features

- **Schnelle Verbindung:** Einfaches Verbinden und Trennen von der Everything-Instanz
- **Mächtige Suche:** Unterstützung für komplexe Abfragen, Regex, Groß-/Kleinschreibung und mehr
- **Eigenschaftsabruf:** Abrufen von Metadaten wie Größe, Erstellungsdatum und Attribute
- **Einfache Handhabung:** Praktische Wrapper-Funktion `Find-Files` für alltägliche Suchen
- **Verbindungstest:** Eine eingebaute Funktion zum Testen der Verbindung und zum Anzeigen von Diagnoseinformationen
- **VSCode-Kompatibilität:** Automatische Behandlung von VSCode-spezifischen DLL-Loading-Problemen

---

## Anforderungen

- **PowerShell 7.0** oder höher (das Modul nutzt PowerShell-7-Syntax wie `??`; Windows PowerShell 5.1 wird nicht unterstützt). Empfohlen wird **PowerShell 7.5** oder höher
- **[Everything](https://www.voidtools.com/downloads/) v1.5a** oder neuer muss installiert sein und laufen
- Die **`Everything3_x64.dll`** (aus dem offiziellen [Everything SDK](https://www.voidtools.com/support/everything/sdk/)) muss sich im selben Verzeichnis wie das Modul befinden

---

## Quick Start

1. **Klonen Sie das Repository:**
   ```sh
   git clone https://github.com/gitnol/PowerEverything3.git
   ```

2. **Importieren Sie das Modul** in Ihre PowerShell-Sitzung:
   ```powershell
   Import-Module .\Everything3-PowerShell-Wrapper.psd1 -Verbose
   ```

3. **Testen Sie die Verbindung:**
   ```powershell
   Test-EverythingConnection
   ```

4. **Dateien finden:**
   ```powershell
   Find-Files -Pattern "*.pdf" -MaxResults 10
   ```

---

## Funktionen

| Funktion                    | Beschreibung                                                                 |
|:---------------------------|:-----------------------------------------------------------------------------|
| `Find-Files`               | Eine einfache Wrapper-Funktion für die schnelle Suche nach Dateien          |
| `Search-Everything`        | Führt eine detaillierte Suche mit allen verfügbaren Optionen durch          |
| `Connect-Everything`       | Stellt eine Verbindung zum Everything-Client her                            |
| `Disconnect-Everything`    | Trennt die Verbindung zum Everything-Client                                 |
| `Test-EverythingConnection`| Überprüft die Verbindung zur Everything-Instanz und zeigt Statusinformationen an |

---

## Anwendungsbeispiele

### Einfache Suchen mit `Find-Files`

**Suche nach PDF- und DOCX-Dateien:**
```powershell
Find-Files -Pattern "*" -Extensions @("pdf", "docx") -MaxResults 10
```

**Suche nach Dateien mit Eigenschaften (Größe, Datum):**
```powershell
Find-Files -Pattern "invoice*" -IncludeProperties -MaxResults 5
```

**Regex-Suche nach Bilddateien mit Datumsmuster:**
```powershell
Find-Files -Pattern "regex:^\d{4}-\d{2}-\d{2}.*\.(jpg|png)$" -Verbose -MaxResults 10
# oder
Find-Files -Pattern '^\d{4}-\d{2}-\d{2}.*\.(jpg|png)$' -Regex -Verbose -MaxResults 10
```

### Erweiterte Suchen mit `Search-Everything`

**Finde die 5 größten Dateien über 100 MB und sortiere sie nach Größe:**
```powershell
# Verbindung manuell aufbauen
$client = Connect-Everything

# Suche ausführen und nach Größe absteigend sortieren
Search-Everything -Client $client -Query "size:>100mb" -MaxResults 5 -Properties "Size" -SortBy @{Property = "Size"; Descending = $true}

# Verbindung wieder trennen
Disconnect-Everything -Client $client
```

**Finde alle Dateien, die in den letzten 7 Tagen geändert wurden:**
```powershell
$client = Connect-Everything
Search-Everything -Client $client -Query "dm:last7days" -MaxResults 10 -Properties "DateModified"
Disconnect-Everything -Client $client
```

**Finde leere Dateien:**
```powershell
Find-Files -Pattern "size:0" -MaxResults 20
```

### Alle Treffer und Existenzprüfung

`-MaxResults 0` liefert **alle** Treffer. Die Eigenschaft `Exists` wird nur mit `-CheckExists` gefüllt – ein `Test-Path` je Treffer ist teuer (Everything-Ergebnisse kommen aus dem Index und sind in der Regel ohnehin aktuell).

```powershell
$client = Connect-Everything

# alle ZIP-Dateien über 100 MB unterhalb eines Ordners, mit Größe und Änderungsdatum
$zips = Search-Everything -Client $client -Query 'file: ext:zip size:>100mb "D:\Daten\"' -MaxResults 0 -Properties Size, DateModified
$zips | Select-Object FullPath, @{ n = 'GroesseMB'; e = { [math]::Round($_.Properties['Size'] / 1MB) } }

# Blättern: Treffer 101–200, nach Name sortiert
Search-Everything -Client $client -Query 'ext:pdf' -Offset 100 -MaxResults 100 -SortBy @{ Property = 'Name' }

# prüfen, ob jeder Treffer noch auf der Platte existiert (langsamer)
Search-Everything -Client $client -Query 'ext:iso' -MaxResults 50 -CheckExists | Where-Object { -not $_.Exists }

Disconnect-Everything -Client $client
```

Text-Eigenschaften (`Name`, `Path`, `Extension`, `Type`) kommen vollständig zurück. `Size` ist `$null`, wenn Everything die Größe nicht kennt (z.B. bei Ordnern).

---

## Praxisbeispiel: Archive neben ihrem entpackten Ordner

[`Examples/Find-ArchivesWithExtractedFolder.ps1`](Examples/Find-ArchivesWithExtractedFolder.ps1) ist ein vollständiges Script zur Fileserver-Bereinigung auf Basis dieses Moduls. Es findet Archive (`zip`, `7z`, `rar`, `iso`, `tar.gz`, …), zu denen am selben Ort bereits ein gleichnamiger Ordner existiert – also Archive, die entpackt und danach nicht gelöscht wurden.

- Sucht über den Everything-Index in Sekunden; fällt auf einen parallelen Dateisystem-Scan zurück, wenn Everything nicht verfügbar oder ein Pfad nicht indiziert ist
- `-AllShares` durchsucht alle Datenfreigaben des Servers (ohne Systemfreigaben, DFS-Wurzeln und verschachtelte Freigaben)
- Ermittelt die Besitzer der entpackten Ordner per ADSI/LDAP (kein ActiveDirectory-Modul/RSAT nötig)
- Schreibt eine CSV und verschickt optional eine Mail je Besitzer; Pfade in Mails werden zu `\\server\freigabe\...`
- Nicht anschreibbare Besitzer (gelöschte/deaktivierte Konten, ohne Mailadresse, BUILTIN\Administratoren) landen in einer Sammelmail an den Helpdesk
- **Inhaltsprüfung:** vergleicht jedes Archiv mit seinem entpackten Ordner und zeigt, ob das Archiv eine überflüssige Kopie ist (`identical` – kann gelöscht werden) oder im Ordner seitdem weitergearbeitet wurde (`changed`, mit neuen/fehlenden/geänderten Dateien)
  - Stufe 1, immer aktiv: Dateiliste, Größen und Zeitstempel aus dem Archiv-Inhaltsverzeichnis – es wird nichts entpackt, etwa eine Sekunde je Archiv
  - Stufe 2, `-CheckContentCrc`: vergleicht zusätzlich die CRC32 jeder Datei (liest alle Dateien – langsam, nur auf Wunsch)
  - ZIP wird immer geprüft; 7z, rar, iso, tar.gz usw. nur, wenn `7z.exe` (+ `7z.dll`) gefunden wird (`$SevenZip`, Standard `%ProgramFiles%\7-Zip`), sonst `N/A`
  - berücksichtigt alte ZIP-Dateinamen im DOS-Zeichensatz, den 1-Stunden-Versatz (Sommerzeit) von ZIP-Zeitstempeln und deren 2-Sekunden-Raster; Systemdateien wie `Thumbs.db` werden ignoriert
- Löscht nie etwas

```powershell
cd .\Examples
Copy-Item .\Find-ArchivesWithExtractedFolder.config.example.ps1 .\Find-ArchivesWithExtractedFolder.config.ps1   # danach anpassen

# Trockenlauf über den ganzen Server: nur CSV
.\Find-ArchivesWithExtractedFolder.ps1 -AllShares -SearchMode Everything

# Test: alle Mails an $DebugTo, höchstens 3
.\Find-ArchivesWithExtractedFolder.ps1 -AllShares -SendMail -MaxMails 3

# Produktiv: Mails an die Besitzer
.\Find-ArchivesWithExtractedFolder.ps1 -AllShares -SearchMode Everything -SendMail -Live

# eigener PC: alle lokalen Festplatten, mit CRC-Inhaltsprüfung
.\Find-ArchivesWithExtractedFolder.ps1 -Path ((Get-CimInstance Win32_LogicalDisk -Filter 'DriveType=3').DeviceID | ForEach-Object { $_ + '\' }) -SearchMode Everything -CheckContentCrc
```

Mit `-SearchMode Everything` werden Pfade, die nicht im Everything-Index sind, mit Warnung übersprungen (Zusammenfassung am Ende von Phase 1); mit `-SearchMode Auto` werden sie gescannt.

Als Administrator direkt auf dem Fileserver ausführen (nötig für `Get-Acl` und `Get-SmbShare`). Alle Parameter stehen in der Hilfe (`Get-Help .\Find-ArchivesWithExtractedFolder.ps1 -Full`). Die echte `*.config.ps1` sowie CSV- und Log-Dateien sind per `.gitignore` ausgeschlossen. Script und Mailtext sind auf Englisch; der Mailtext lässt sich in `New-MailBody` anpassen.

---

## VSCode-Besonderheiten

Das Modul enthält automatische Workarounds für VSCode-spezifische Probleme beim Laden nativer DLLs:

- **Automatisches DLL-Loading:** Die `Everything3_x64.dll` wird über `Kernel32::LoadLibrary()` explizit geladen
- **PATH-Behandlung:** Das Modul-Verzeichnis wird automatisch zum PATH hinzugefügt
- **Fehlerbehandlung:** Robuste Behandlung von VSCode-spezifischen Parameter-Binding-Problemen

Diese Maßnahmen stellen sicher, dass das Modul sowohl in der normalen PowerShell-Konsole als auch in VSCode korrekt funktioniert.

---

## Änderungen

**Archiv-Beispiel: Inhaltsprüfung und Index-Korrektur**
- Neu: Inhaltsprüfung Archiv ↔ entpackter Ordner (CSV-Spalten `Content`/`ContentDetails`, Spalte „Content“ in den Mails); Stufe 1 immer, Stufe 2 mit `-CheckContentCrc`; andere Formate als ZIP per 7-Zip, falls vorhanden
- Behoben: Ein leerer, aber indizierter Ordner wurde als „nicht im Everything-Index“ gemeldet (die Index-Prüfung zählt jetzt den Ordner selbst mit)
- Geändert: Mit `-SearchMode Everything` bricht ein nicht indizierter Pfad nicht mehr den ganzen Lauf ab – er wird mit Warnung übersprungen und am Ende von Phase 1 aufgelistet

**SDK 3.0.0.9, Fehlerkorrekturen und Archiv-Beispiel**
- `Everything3_x64.dll` auf SDK 3.0.0.9 aktualisiert (robustere Pipe-Verbindung, wenn Everything ausgelastet ist, Absturz- und Speicherfehler-Korrekturen im SDK – siehe [SDK-Changelog](https://www.voidtools.com/forum/viewtopic.php?t=15853))
- Behoben: P/Invoke-Signaturen nutzten `uint` für `SIZE_T`-Parameter/-Rückgaben (Index, Anzahl, Puffergröße) – jetzt `UIntPtr` (64 Bit auf x64), wie in `Everything3.h` deklariert
- Behoben: Text-Eigenschaften (`Name`, `Path`, `Extension`, `Type`) lieferten nur ihr erstes Zeichen (`Everything3_GetResultPropertyTextW` war ohne `CharSet.Unicode` deklariert)
- Behoben: Die Eigenschaft `Name` und die Sortierung nach `Name` wurden stillschweigend ignoriert (Property-ID `0` galt als „unbekannt“)
- Behoben: `$error` (automatische Variable) wurde in der Fehlerbehandlung überschrieben
- Neu: `-MaxResults 0` liefert alle Treffer; `-Offset` zum Blättern wird korrekt übergeben
- Neu: `-CheckExists` – `Exists` wird nur auf Wunsch geprüft (sonst `$null`). **Verhaltensänderung:** bisher lief `Test-Path` für jeden Treffer
- Schneller: Treffer werden in einer Liste statt mit `+=` gesammelt (5.000 Treffer: 6,3 s → 0,5 s)
- `Size` ist `$null` statt `18446744073709551615`, wenn unbekannt (z.B. Ordner)
- Das Laden des Moduls schreibt nicht mehr in die Konsole (Meldungen jetzt über `-Verbose`)
- Neues Beispiel: `Examples/Find-ArchivesWithExtractedFolder.ps1`
- Anforderungen korrigiert: PowerShell 7.0+

---

## Lizenz & Haftungsausschluss

[MIT](https://github.com/gitnol/PowerEverything3/blob/main/LICENSE)

Dieses Projekt wird ohne jegliche Gewährleistung zur Verfügung gestellt. Die Nutzung erfolgt auf eigene Verantwortung.

Dieses Projekt steht in keiner Verbindung zu VoidTools. Alle Markenzeichen gehören ihren jeweiligen Eigentümern. Dies ist ein reines Forschungs- und Entwicklungsprojekt.
