# Everything3 PowerShell Wrapper

Ein leistungsstarker und benutzerfreundlicher PowerShell-Wrapper für die [Everything Search Engine](https://www.voidtools.com/) (Version 1.5+). Dieses Modul nutzt die `Everything3_x64.dll` aus dem Everything SDK, um eine extrem schnelle Dateisuche direkt aus der PowerShell-Konsole zu ermöglichen.

## Inhaltsverzeichnis

  - [✨ Features](https://www.google.com/search?q=%23-features)
  - [📋 Anforderungen](https://www.google.com/search?q=%23-anforderungen)
  - [🚀 Quick Start](https://www.google.com/search?q=%23-quick-start)
  - [⚙️ Funktionen](https://www.google.com/search?q=%23%EF%B8%8F-funktionen)
  - [💡 Anwendungsbeispiele](https://www.google.com/search?q=%23-anwendungsbeispiele)

-----

## ✨ Features

  - **Schnelle Verbindung:** Einfaches Verbinden und Trennen von der Everything-Instanz.
  - **Mächtige Suche:** Unterstützung für komplexe Abfragen, Regex, Groß-/Kleinschreibung und mehr.
  - **Eigenschaftsabruf:** Abrufen von Metadaten wie Größe, Erstellungsdatum und Attribute.
  - **Einfache Handhabung:** Praktische Wrapper-Funktion `Find-Files` für alltägliche Suchen.
  - **Verbindungstest:** Eine eingebaute Funktion zum Testen der Verbindung und zum Anzeigen von Diagnoseinformationen.

-----

## 📋 Anforderungen

  - **PowerShell 5.1** oder höher
  - **[Everything](https://www.voidtools.com/downloads/) v1.5a** oder neuer muss installiert sein und laufen.
  - Die **`Everything3_x64.dll`** (aus dem offiziellen [Everything SDK](https://www.voidtools.com/support/everything/sdk/)) muss sich entweder im selben Verzeichnis wie das Modul oder in einem Ordner befinden, der in der `PATH`-Umgebungsvariable aufgeführt ist.

-----

## 🚀 Quick Start

1.  **Klonen Sie das Repository:**

    ```sh
    git clone https://github.com/gitnol/PowerEverything3.git
    ```

2.  **Importieren Sie das Modul** in Ihre PowerShell-Sitzung:

    ```powershell
    Import-Module .\Everything3-PowerShell-Wrapper.psd1 -Verbose
    ```

3.  **Testen Sie die Verbindung:**

    ```powershell
    Test-EverythingConnection
    ```

4.  **Dateien finden\!**

    ```powershell
    Find-Files -Pattern "*.pdf" -MaxResults 10
    ```

-----

## ⚙️ Funktionen

| Funktion                  | Beschreibung                                                               |
| :------------------------ | :------------------------------------------------------------------------- |
| `Find-Files`              | Eine einfache Wrapper-Funktion für die schnelle Suche nach Dateien.        |
| `Search-Everything`       | Führt eine detaillierte Suche mit allen verfügbaren Optionen durch.        |
| `Connect-Everything`      | Stellt eine Verbindung zum Everything-Client her.                         |
| `Disconnect-Everything`   | Trennt die Verbindung zum Everything-Client.                              |
| `Test-EverythingConnection` | Überprüft die Verbindung zur Everything-Instanz und zeigt Statusinformationen an. |

-----

## 💡 Anwendungsbeispiele

Hier sind einige praktische Beispiele, um die Mächtigkeit des Moduls zu demonstrieren.

### Einfache Suchen mit `Find-Files`

**Suche nach PDF- und DOCX-Dateien:**

```powershell
Find-Files -Pattern "*" -Extensions @("pdf", "docx") -MaxResults 10
```

**Suche nach Dateien mit Eigenschaften (Größe, Datum):**

```powershell
Find-Files -Pattern "invoice*" -IncludeProperties -MaxResults 5
```

**Verwende Regex, um nach Bilddateien zu suchen, die mit einem Datumsmuster beginnen:**

```powershell
Find-Files -Pattern "regex:^\d{4}-\d{2}-\d{2}.*\.(jpg|png)$" -Verbose -MaxResults 10
# oder
Find-Files -Pattern '^\d{4}-\d{2}-\d{2}.*\.(jpg|png)$' -Regex -Verbose -MaxResults 10
```

### Erweiterte Suchen mit `Search-Everything`

Für komplexe Abfragen oder wenn mehrere Suchen nacheinander ausgeführt werden sollen, ist die manuelle Steuerung des Clients effizienter.

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

## ❌ Lizenz & Haftungsausschluss

[MIT](https://github.com/gitnol/PowerEverything3/LICENSE)

Ich hafte für nichts. Wenn ihr es nutzt, dann auf eigene Gefahr :)