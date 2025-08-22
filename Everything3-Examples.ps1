# Everything3 PowerShell Wrapper - Beispiele
# 
# Voraussetzungen:
# 1. Everything 1.5 muss installiert und gestartet sein
# 2. Everything3_x64.dll muss im gleichen Verzeichnis wie das Modul liegen
# 3. Das Modul muss importiert sein: Import-Module .\Everything3-PowerShell-Wrapper.psm1

#region Einfache Beispiele mit Find-Files

Write-Host "=== Einfache Beispiele mit Find-Files ===" -ForegroundColor Cyan

# Beispiel 1: Alle PDF-Dateien suchen
Write-Host "`n1. Suche nach PDF-Dateien:" -ForegroundColor Yellow
try {
    $pdfFiles = Find-Files -Pattern "*.pdf" -MaxResults 10
    Write-Host "Gefunden: $($pdfFiles.Count) PDF-Dateien"
    $pdfFiles | Select-Object Name, Directory | Format-Table -AutoSize
}
catch {
    Write-Warning "Fehler bei PDF-Suche: $($_.Exception.Message)"
}

# Beispiel 2: Suche mit mehreren Dateierweiterungen
Write-Host "`n2. Suche nach Textdateien (txt, doc, docx):" -ForegroundColor Yellow
try {
    $textFiles = Find-Files -Pattern "*" -Extensions @("txt", "doc", "docx") -MaxResults 5
    Write-Host "Gefunden: $($textFiles.Count) Textdateien"
    $textFiles | Select-Object Name, Directory | Format-Table -AutoSize
}
catch {
    Write-Warning "Fehler bei Textdatei-Suche: $($_.Exception.Message)"
}

# Beispiel 3: Suche mit zusätzlichen Eigenschaften
Write-Host "`n3. Suche mit Dateieigenschaften:" -ForegroundColor Yellow
try {
    $filesWithProps = Find-Files -Pattern "test*" -IncludeProperties -MaxResults 5
    Write-Host "Gefunden: $($filesWithProps.Count) Dateien"
    foreach ($file in $filesWithProps) {
        Write-Host "Datei: $($file.Name)" -ForegroundColor Green
        Write-Host "  Pfad: $($file.Directory)"
        Write-Host "  Größe: $($file.Properties.Size) Bytes" -NoNewline
        if ($file.Properties.Size -gt 0) {
            $sizeKB = [math]::Round($file.Properties.Size / 1KB, 2)
            Write-Host " ($sizeKB KB)"
        }
        else {
            Write-Host ""
        }
        Write-Host "  Geändert: $($file.Properties.DateModified)"
        Write-Host "  Existiert: $($file.Exists)"
        Write-Host ""
    }
}
catch {
    Write-Warning "Fehler bei Eigenschafts-Suche: $($_.Exception.Message)"
}

#endregion

#region Erweiterte Beispiele mit direkter Client-Nutzung

Write-Host "`n=== Erweiterte Beispiele mit Client-Management ===" -ForegroundColor Cyan

# Beispiel 4: Manuelle Client-Verwaltung für mehrere Suchen
Write-Host "`n4. Mehrere Suchen mit einem Client:" -ForegroundColor Yellow
$client = $null
try {
    # Client verbinden
    $client = Connect-Everything
    Write-Host "✓ Verbunden mit Everything"
    
    # Erste Suche: Alle .exe Dateien
    $exeFiles = Search-Everything -Client $client -Query "*.exe" -MaxResults 5
    Write-Host "EXE-Dateien gefunden: $($exeFiles.Count)"
    
    # Zweite Suche: Große Dateien (>100MB)
    $largeFiles = Search-Everything -Client $client -Query "size:>100mb" -MaxResults 5 -Properties @("Size")
    Write-Host "Große Dateien gefunden: $($largeFiles.Count)"
    foreach ($file in $largeFiles) {
        $sizeMB = [math]::Round($file.Properties.Size / 1MB, 2)
        Write-Host "  $($file.Name): $sizeMB MB"
    }
    
    # Dritte Suche: Kürzlich geänderte Dateien
    $recentFiles = Search-Everything -Client $client -Query "dm:today" -MaxResults 3 -Properties @("DateModified")
    Write-Host "Heute geänderte Dateien: $($recentFiles.Count)"
    foreach ($file in $recentFiles) {
        Write-Host "  $($file.Name): $($file.Properties.DateModified)"
    }
    
}
catch {
    Write-Warning "Fehler bei erweiterten Suchen: $($_.Exception.Message)"
}
finally {
    if ($client) {
        Disconnect-Everything -Client $client
        Write-Host "✓ Client getrennt"
    }
}

#endregion

#region Spezielle Suchfunktionen

Write-Host "`n=== Spezielle Suchfunktionen ===" -ForegroundColor Cyan

# Beispiel 5: Regex-Suche
Write-Host "`n5. Regex-Suche:" -ForegroundColor Yellow
try {
    $regexFiles = Find-Files -Pattern "test\d+\.txt" -Regex -MaxResults 5
    Write-Host "Mit Regex gefunden: $($regexFiles.Count) Dateien"
    $regexFiles | ForEach-Object { Write-Host "  $($_.Name)" }
}
catch {
    Write-Warning "Fehler bei Regex-Suche: $($_.Exception.Message)"
}

# Beispiel 6: Case-sensitive Suche
Write-Host "`n6. Groß-/Kleinschreibung beachten:" -ForegroundColor Yellow
try {
    $caseSensitive = Find-Files -Pattern "Test*" -CaseSensitive -MaxResults 5
    Write-Host "Case-sensitive gefunden: $($caseSensitive.Count) Dateien"
    $caseSensitive | ForEach-Object { Write-Host "  $($_.Name)" }
}
catch {
    Write-Warning "Fehler bei case-sensitive Suche: $($_.Exception.Message)"
}

#endregion

#region Praktische Anwendungsfälle

Write-Host "`n=== Praktische Anwendungsfälle ===" -ForegroundColor Cyan

# Beispiel 7: Duplizierte Dateien finden (gleicher Name, verschiedene Ordner)
Write-Host "`n7. Suche nach möglicherweise duplizierten Dateien:" -ForegroundColor Yellow
function Find-PotentialDuplicates {
    param([string]$FileName)
    
    try {
        $duplicates = Find-Files -Pattern $FileName -IncludeProperties
        if ($duplicates.Count -gt 1) {
            Write-Host "Potentielle Duplikate für '$FileName':" -ForegroundColor Green
            $duplicates | Group-Object Name | Where-Object Count -gt 1 | ForEach-Object {
                Write-Host "  Dateiname: $($_.Name)" -ForegroundColor Cyan
                $_.Group | ForEach-Object {
                    $sizeMB = if ($_.Properties.Size) { [math]::Round($_.Properties.Size / 1MB, 2) } else { "?" }
                    Write-Host "    $($_.Directory) ($sizeMB MB, $($_.Properties.DateModified))"
                }
            }
        }
        else {
            Write-Host "Keine Duplikate für '$FileName' gefunden"
        }
    }
    catch {
        Write-Warning "Fehler bei Duplikat-Suche: $($_.Exception.Message)"
    }
}

Find-PotentialDuplicates -FileName "readme.txt"

# Beispiel 8: Dateien nach Größe analysieren
Write-Host "`n8. Top 5 größte Dateien im System:" -ForegroundColor Yellow
$client = $null
try {
    $client = Connect-Everything
    
    # Suche nach allen Dateien, sortiert nach Größe (absteigend)
    $largestFiles = Search-Everything -Client $client -Query "size:>1mb" -MaxResults 5 -Properties @("Size", "DateModified") -SortBy @{Property = "Size"; Descending = $true }
    
    Write-Host "Größte Dateien:" -ForegroundColor Green
    foreach ($file in $largestFiles) {
        $sizeMB = [math]::Round($file.Properties.Size / 1MB, 2)
        Write-Host "  $($file.Name): $sizeMB MB ($($file.Directory))"
    }
}
catch {
    Write-Warning "Fehler bei Größen-Analyse: $($_.Exception.Message)"
}
finally {
    if ($client) { Disconnect-Everything -Client $client }
}

# Beispiel 9: Dateien nach Datum filtern
Write-Host "`n9. Kürzlich erstellte und geänderte Dateien:" -ForegroundColor Yellow
$client = $null
try {
    $client = Connect-Everything
    
    # Dateien der letzten 7 Tage
    $recentFiles = Search-Everything -Client $client -Query "dm:last7days" -MaxResults 10 -Properties @("DateModified", "DateCreated", "Size")
    
    Write-Host "Dateien der letzten 7 Tage:" -ForegroundColor Green
    $recentFiles | Sort-Object { $_.Properties.DateModified } -Descending | ForEach-Object {
        $sizeMB = if ($_.Properties.Size -gt 0) { [math]::Round($_.Properties.Size / 1MB, 2) } else { 0 }
        Write-Host "  $($_.Name) - $($_.Properties.DateModified) ($sizeMB MB)"
    }
}
catch {
    Write-Warning "Fehler bei Datums-Filter: $($_.Exception.Message)"
}
finally {
    if ($client) { Disconnect-Everything -Client $client }
}

# Beispiel 10: Leere Dateien und Ordner finden
Write-Host "`n10. Leere Dateien finden:" -ForegroundColor Yellow
try {
    $emptyFiles = Find-Files -Pattern "size:0" -IncludeProperties -MaxResults 10
    Write-Host "Leere Dateien: $($emptyFiles.Count)" -ForegroundColor Green
    $emptyFiles | ForEach-Object {
        Write-Host "  $($_.FullPath)"
    }
}
catch {
    Write-Warning "Fehler bei Leer-Datei-Suche: $($_.Exception.Message)"
}

#endregion

#region Performance-Tests

Write-Host "`n=== Performance-Tests ===" -ForegroundColor Cyan

# Beispiel 11: Performance-Vergleich
Write-Host "`n11. Performance-Test:" -ForegroundColor Yellow
function Test-SearchPerformance {
    param([string]$Query, [int]$MaxResults = 1000)
    
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    
    try {
        $results = Find-Files -Pattern $Query -MaxResults $MaxResults
        $stopwatch.Stop()
        
        Write-Host "Query: '$Query'" -ForegroundColor Green
        Write-Host "  Ergebnisse: $($results.Count)"
        Write-Host "  Zeit: $($stopwatch.ElapsedMilliseconds) ms"
        Write-Host "  Durchsatz: $([math]::Round($results.Count / ($stopwatch.ElapsedMilliseconds / 1000), 0)) Ergebnisse/Sekunde"
        
        return $results.Count
    }
    catch {
        $stopwatch.Stop()
        Write-Warning "Fehler bei Performance-Test: $($_.Exception.Message)"
        return 0
    }
}

# Verschiedene Queries testen
$queries = @("*.txt", "*.exe", "size:>10mb", "*test*", "ext:pdf;doc;docx")
$totalResults = 0

foreach ($query in $queries) {
    $count = Test-SearchPerformance -Query $query -MaxResults 100
    $totalResults += $count
    Start-Sleep -Milliseconds 100  # Kurze Pause zwischen Tests
}

Write-Host "`nGesamte Ergebnisse getestet: $totalResults" -ForegroundColor Cyan

#endregion

#region Erweiterte Suchfunktionen

Write-Host "`n=== Erweiterte Suchfunktionen ===" -ForegroundColor Cyan

# Beispiel 12: Benutzerdefinierte Suchfunktion für Projekte
function Find-ProjectFiles {
    param(
        [string]$ProjectName,
        [string[]]$SourceExtensions = @("cs", "vb", "cpp", "h", "py", "js", "php", "java"),
        [int]$MaxResults = 100
    )
    
    Write-Host "`nSuche nach Projekt-Dateien für: $ProjectName" -ForegroundColor Yellow
    
    try {
        # Suche in Ordnern mit Projektnamen
        $folderQuery = "folder:$ProjectName"
        $projectFolders = Find-Files -Pattern $folderQuery -MaxResults 10
        
        Write-Host "Projekt-Ordner gefunden: $($projectFolders.Count)"
        
        # Suche nach Source-Dateien in diesen Ordnern
        $sourceQuery = "$ProjectName " + (($SourceExtensions | ForEach-Object { "ext:$_" }) -join "|")
        $sourceFiles = Find-Files -Pattern $sourceQuery -MaxResults $MaxResults -IncludeProperties
        
        Write-Host "Source-Dateien gefunden: $($sourceFiles.Count)" -ForegroundColor Green
        
        # Gruppiere nach Erweiterung
        $grouped = $sourceFiles | Group-Object { [System.IO.Path]::GetExtension($_.Name).TrimStart('.') }
        
        foreach ($group in $grouped | Sort-Object Name) {
            Write-Host "  .$($group.Name): $($group.Count) Dateien"
            $totalSize = ($group.Group | Where-Object { $_.Properties.Size } | Measure-Object -Property { $_.Properties.Size } -Sum).Sum
            if ($totalSize -gt 0) {
                Write-Host "    Gesamtgröße: $([math]::Round($totalSize / 1KB, 2)) KB"
            }
        }
        
        return $sourceFiles
        
    }
    catch {
        Write-Warning "Fehler bei Projekt-Suche: $($_.Exception.Message)"
        return @()
    }
}

# Beispiel-Projekt suchen
$projectFiles = Find-ProjectFiles -ProjectName "test" -MaxResults 20

# Beispiel 13: Dateisystem-Analyse
Write-Host "`n13. Dateisystem-Analyse:" -ForegroundColor Yellow
function Get-FileSystemStats {
    $client = $null
    try {
        $client = Connect-Everything
        
        Write-Host "Analysiere Dateisystem..." -ForegroundColor Green
        
        # Top-Level Statistiken
        $allFiles = Search-Everything -Client $client -Query "*" -MaxResults 1000 -Properties @("Size")
        $totalFiles = $allFiles.Count
        $totalSize = ($allFiles | Where-Object { $_.Properties.Size } | Measure-Object -Property { $_.Properties.Size } -Sum).Sum
        
        Write-Host "Gesamt-Statistik (Stichprobe von $totalFiles Dateien):"
        Write-Host "  Gesamtgröße: $([math]::Round($totalSize / 1GB, 2)) GB"
        Write-Host "  Durchschnittliche Dateigröße: $([math]::Round($totalSize / $totalFiles / 1KB, 2)) KB"
        
        # Top Erweiterungen
        $extensions = $allFiles | Group-Object { [System.IO.Path]::GetExtension($_.Name).TrimStart('.').ToLower() } | 
        Sort-Object Count -Descending | Select-Object -First 10
        
        Write-Host "`nTop 10 Dateierweiterungen:"
        foreach ($ext in $extensions) {
            $extName = if ($ext.Name -eq "") { "(keine)" } else { $ext.Name }
            Write-Host "  .$extName`: $($ext.Count) Dateien"
        }
        
    }
    catch {
        Write-Warning "Fehler bei Dateisystem-Analyse: $($_.Exception.Message)"
    }
    finally {
        if ($client) { Disconnect-Everything -Client $client }
    }
}

Get-FileSystemStats

#endregion

#region Hilfsfunktionen

Write-Host "`n=== Hilfsfunktionen ===" -ForegroundColor Cyan

# Beispiel 14: Interaktive Suche
function Start-InteractiveSearch {
    Write-Host "`n14. Interaktive Suche (Eingabe 'quit' zum Beenden):" -ForegroundColor Yellow
    
    $client = $null
    try {
        $client = Connect-Everything
        Write-Host "✓ Everything Client verbunden" -ForegroundColor Green
        
        do {
            $query = Read-Host "`nSuchbegriff eingeben"
            
            if ($query -eq "quit" -or $query -eq "exit") {
                break
            }
            
            if ([string]::IsNullOrWhiteSpace($query)) {
                continue
            }
            
            try {
                $startTime = Get-Date
                $results = Search-Everything -Client $client -Query $query -MaxResults 10 -Properties @("Size", "DateModified")
                $endTime = Get-Date
                $duration = ($endTime - $startTime).TotalMilliseconds
                
                Write-Host "Gefunden: $($results.Count) Ergebnisse in $([math]::Round($duration, 0)) ms" -ForegroundColor Green
                
                foreach ($result in $results) {
                    $size = if ($result.Properties.Size) { "$([math]::Round($result.Properties.Size / 1KB, 1)) KB" } else { "? KB" }
                    $modified = if ($result.Properties.DateModified) { $result.Properties.DateModified.ToString("dd.MM.yyyy HH:mm") } else { "?" }
                    
                    Write-Host "  📄 $($result.Name)" -ForegroundColor Cyan
                    Write-Host "     $($result.Directory)" -ForegroundColor Gray
                    Write-Host "     $size | $modified | Existiert: $($result.Exists)" -ForegroundColor Gray
                }
                
                if ($results.Count -eq 0) {
                    Write-Host "  Keine Ergebnisse gefunden." -ForegroundColor Yellow
                }
                
            }
            catch {
                Write-Warning "Suchfehler: $($_.Exception.Message)"
            }
            
        } while ($true)
        
    }
    catch {
        Write-Error "Fehler beim Starten der interaktiven Suche: $($_.Exception.Message)"
    }
    finally {
        if ($client) {
            Disconnect-Everything -Client $client
            Write-Host "✓ Everything Client getrennt" -ForegroundColor Green
        }
    }
}

# Beispiel 15: Konfiguration testen
function Test-EverythingConfiguration {
    Write-Host "`n15. Everything-Konfiguration testen:" -ForegroundColor Yellow
    
    try {
        # Teste Verbindung zur Standard-Instanz
        Write-Host "Teste Standard-Instanz..." -NoNewline
        $client1 = $null
        try {
            $client1 = Connect-Everything
            Write-Host " ✓ Erfolgreich" -ForegroundColor Green
        }
        catch {
            Write-Host " ✗ Fehlgeschlagen: $($_.Exception.Message)" -ForegroundColor Red
        }
        finally {
            if ($client1) { Disconnect-Everything -Client $client1 }
        }
        
        # Teste Verbindung zur 1.5a-Instanz
        Write-Host "Teste 1.5a-Instanz..." -NoNewline
        $client2 = $null
        try {
            $client2 = Connect-Everything -InstanceName "1.5a"
            Write-Host " ✓ Erfolgreich" -ForegroundColor Green
        }
        catch {
            Write-Host " ✗ Fehlgeschlagen: $($_.Exception.Message)" -ForegroundColor Red
        }
        finally {
            if ($client2) { Disconnect-Everything -Client $client2 }
        }
        
        # Teste eine einfache Suche
        Write-Host "Teste Basis-Suchfunktionalität..." -NoNewline
        try {
            $testResults = Find-Files -Pattern "*.txt" -MaxResults 1
            Write-Host " ✓ Erfolgreich ($($testResults.Count) Ergebnis(se))" -ForegroundColor Green
        }
        catch {
            Write-Host " ✗ Fehlgeschlagen: $($_.Exception.Message)" -ForegroundColor Red
        }
        
        # Teste Eigenschaften-Abfrage
        Write-Host "Teste Eigenschaften-Abfrage..." -NoNewline
        try {
            $propResults = Find-Files -Pattern "*" -MaxResults 1 -IncludeProperties
            if ($propResults.Count -gt 0 -and $propResults[0].Properties.Count -gt 0) {
                Write-Host " ✓ Erfolgreich" -ForegroundColor Green
            }
            else {
                Write-Host " ⚠ Teilweise (keine Eigenschaften erhalten)" -ForegroundColor Yellow
            }
        }
        catch {
            Write-Host " ✗ Fehlgeschlagen: $($_.Exception.Message)" -ForegroundColor Red
        }
        
    }
    catch {
        Write-Error "Konfigurationstest fehlgeschlagen: $($_.Exception.Message)"
    }
}

Test-EverythingConfiguration

#endregion

Write-Host "`n=== Beispiele abgeschlossen ===" -ForegroundColor Green
Write-Host "Für eine interaktive Suche verwenden Sie: Start-InteractiveSearch" -ForegroundColor Cyan
Write-Host "Weitere Hilfe: Get-Help Find-Files -Full" -ForegroundColor Cyan