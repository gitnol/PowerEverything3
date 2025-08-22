# Everything3 PowerShell Wrapper

Ein leistungsstarker und benutzerfreundlicher PowerShell-Wrapper für die [Everything Search Engine](https://www.voidtools.com/) (Version 1.5+). Dieses Modul nutzt die `Everything3_x64.dll` aus dem Everything SDK, um eine extrem schnelle Dateisuche direkt aus der PowerShell-Konsole zu ermöglichen.

Getestet wurde es mit:
- PowerShell 7.5.2
- Everything 1.5.0.1396a-x64
  - Webseite: https://www.voidtools.com/everything-1.5a/
  - Download: https://www.voidtools.com/Everything-1.5.0.1396a.x64-Setup.exe 
  - Größe: (1703 KB - SHA256: 37f8f9359346b78a5e9820b5bae73044366a299eaaeba2d8a56fadf46bcc577e)
- SDK Version 3.0.0.4
  - Webseite: https://www.voidtools.com/forum/viewtopic.php?t=15853
  - Download: https://www.voidtools.com/Everything-SDK-3.0.0.4.zip 
  - Größe: (216 KB - SHA256: 48d76d7e90b2a3ea8f6db7626f27bd8f001e3163c826dae5de979430b226e62d) 
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
  - [VSCode-Besonderheiten](#vscode-besonderheiten)
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

- **PowerShell 5.1** oder höher. Empfohlen wird **PowerShell 7.5.2** oder höher
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

---

## VSCode-Besonderheiten

Das Modul enthält automatische Workarounds für VSCode-spezifische Probleme beim Laden nativer DLLs:

- **Automatisches DLL-Loading:** Die `Everything3_x64.dll` wird über `Kernel32::LoadLibrary()` explizit geladen
- **PATH-Behandlung:** Das Modul-Verzeichnis wird automatisch zum PATH hinzugefügt
- **Fehlerbehandlung:** Robuste Behandlung von VSCode-spezifischen Parameter-Binding-Problemen

Diese Maßnahmen stellen sicher, dass das Modul sowohl in der normalen PowerShell-Konsole als auch in VSCode korrekt funktioniert.

---

## Lizenz & Haftungsausschluss

[MIT](https://github.com/gitnol/PowerEverything3/blob/main/LICENSE)

Dieses Projekt wird ohne jegliche Gewährleistung zur Verfügung gestellt. Die Nutzung erfolgt auf eigene Verantwortung.

Dieses Projekt steht in keiner Verbindung zu VoidTools. Alle Markenzeichen gehören ihren jeweiligen Eigentümern. Dies ist ein reines Forschungs- und Entwicklungsprojekt.
