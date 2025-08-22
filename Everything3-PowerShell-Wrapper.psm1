# Everything3 PowerShell Wrapper - Vollständig korrigiert
# Erfordert Everything3_x64.dll im gleichen Verzeichnis oder im PATH


#region Helper Classes

class Everything3Client {
    [IntPtr]$Handle
    [bool]$IsConnected

    Everything3Client([string]$instanceName) {
        $this.Handle = [Everything3SDK]::Everything3_ConnectW($instanceName)
        $this.IsConnected = $this.Handle -ne [IntPtr]::Zero
        
        if (-not $this.IsConnected) {
            $error = [Everything3SDK]::Everything3_GetLastError()
            throw "Fehler beim Verbinden mit Everything-Instanz '$instanceName'. Fehler: $error"
        }
    }

    [void] Dispose() {
        if ($this.IsConnected -and $this.Handle -ne [IntPtr]::Zero) {
            [Everything3SDK]::Everything3_DestroyClient($this.Handle)
            $this.Handle = [IntPtr]::Zero
            $this.IsConnected = $false
        }
    }
}

class Everything3Result {
    [string]$FullPath
    [string]$Name
    [string]$Directory
    [hashtable]$Properties = @{}
    [bool]$Exists

    Everything3Result([string]$fullPath) {
        $this.FullPath = $fullPath
        $this.Name = [System.IO.Path]::GetFileName($fullPath)
        $this.Directory = [System.IO.Path]::GetDirectoryName($fullPath)
        $this.Exists = Test-Path -LiteralPath $fullPath -ErrorAction SilentlyContinue
    }
}

#endregion

#region Private Functions

function Get-PropertyId {
    param([string]$PropertyName)
    
    $propertyMap = @{
        'Name'         = [Everything3Properties]::EVERYTHING3_PROPERTY_ID_NAME
        'Path'         = [Everything3Properties]::EVERYTHING3_PROPERTY_ID_PATH
        'FullPath'     = [Everything3Properties]::EVERYTHING3_PROPERTY_ID_FULL_PATH
        'Size'         = [Everything3Properties]::EVERYTHING3_PROPERTY_ID_SIZE
        'DateCreated'  = [Everything3Properties]::EVERYTHING3_PROPERTY_ID_DATE_CREATED
        'DateModified' = [Everything3Properties]::EVERYTHING3_PROPERTY_ID_DATE_MODIFIED
        'DateAccessed' = [Everything3Properties]::EVERYTHING3_PROPERTY_ID_DATE_ACCESSED
        'Attributes'   = [Everything3Properties]::EVERYTHING3_PROPERTY_ID_ATTRIBUTES
        'Type'         = [Everything3Properties]::EVERYTHING3_PROPERTY_ID_TYPE
        'Extension'    = [Everything3Properties]::EVERYTHING3_PROPERTY_ID_EXTENSION
    }
    
    return $propertyMap[$PropertyName]
}

function ConvertFrom-FileTime {
    param([ulong]$FileTime)
    
    try {
        if ($FileTime -eq 0 -or $FileTime -eq 0xFFFFFFFFFFFFFFFF) {
            return $null
        }
        return [DateTime]::FromFileTime($FileTime)
    }
    catch {
        return $null
    }
}

#endregion

#region Public Functions

function Connect-Everything {
    <#
    .SYNOPSIS
    Verbindet sich mit der Everything-Suchmaschine.
    #>
    [CmdletBinding()]
    param(
        [string]$InstanceName = $null
    )
    
    try {
        Write-Verbose "Verbinde mit Everything-Instanz: $($InstanceName ?? 'Standard')"
        return [Everything3Client]::new($InstanceName)
    }
    catch {
        if ([string]::IsNullOrEmpty($InstanceName)) {
            Write-Verbose "Standard-Verbindung fehlgeschlagen, versuche '1.5a'-Instanz"
            try {
                return [Everything3Client]::new("1.5a")
            }
            catch {
                throw "Fehler beim Verbinden mit Standard- und '1.5a'-Everything-Instanzen: $($_.Exception.Message)"
            }
        }
        else {
            throw
        }
    }
}

function Search-Everything {
    <#
    .SYNOPSIS
    Führt eine Suche mit der Everything-Suchmaschine durch.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [Everything3Client]$Client,
        
        [Parameter(Mandatory)]
        [string]$Query,
        
        [int]$MaxResults = 1000,
        [int]$Offset = 0,
        [switch]$MatchCase,
        [switch]$MatchWholeWord,
        [switch]$MatchPath,
        [switch]$Regex,
        [string[]]$Properties = @(),
        [hashtable]$SortBy = @{}
    )
    
    if (-not $Client.IsConnected) {
        throw "Client ist nicht mit Everything verbunden"
    }
    
    # Search state erstellen
    $searchState = [Everything3SDK]::Everything3_CreateSearchState()
    if ($searchState -eq [IntPtr]::Zero) {
        throw "Fehler beim Erstellen des Search State"
    }
    
    try {
        # Suchoptionen konfigurieren
        [void][Everything3SDK]::Everything3_SetSearchTextW($searchState, $Query)
        [void][Everything3SDK]::Everything3_SetSearchViewportOffset($searchState, [uint32]$Offset)
        [void][Everything3SDK]::Everything3_SetSearchViewportCount($searchState, [uint32]$MaxResults)
        [void][Everything3SDK]::Everything3_SetSearchMatchCase($searchState, $MatchCase.IsPresent)
        [void][Everything3SDK]::Everything3_SetSearchMatchWholeWords($searchState, $MatchWholeWord.IsPresent)
        [void][Everything3SDK]::Everything3_SetSearchMatchPath($searchState, $MatchPath.IsPresent)
        [void][Everything3SDK]::Everything3_SetSearchRegex($searchState, $Regex.IsPresent)
        

        # Property-Requests hinzufügen
        $propertyIds = @()
        foreach ($prop in $Properties) {
            $propId = Get-PropertyId -PropertyName $prop
            if ($propId) {
                [void][Everything3SDK]::Everything3_AddSearchPropertyRequest($searchState, $propId)
                $propertyIds += @{Name = $prop; Id = $propId }
            }
            else {
                Write-Warning "Unbekannte Eigenschaft: $prop"
            }
        }

        # FIX: Wenn benutzerdefinierte Eigenschaften angefordert werden, wird der Pfad nicht mehr standardmäßig mitgeliefert.
        # Wir müssen ihn daher ebenfalls explizit anfordern, damit Everything3_GetResultFullPathNameW ihn finden kann.
        if ($Properties.Count -gt 0) {
            $fullPathId = Get-PropertyId -PropertyName 'FullPath'
            if ($fullPathId) {
                [void][Everything3SDK]::Everything3_AddSearchPropertyRequest($searchState, $fullPathId)
            }
        }
        
        # Sortierung hinzufügen
        if ($SortBy.Count -gt 0) {
            $sortPropId = Get-PropertyId -PropertyName $SortBy.Property
            if ($sortPropId) {
                $ascending = -not $SortBy.Descending
                [void][Everything3SDK]::Everything3_AddSearchSort($searchState, $sortPropId, $ascending)
            }
        }
        
        # Suche ausführen
        Write-Verbose "Führe Suche aus: $Query"
        $resultList = [Everything3SDK]::Everything3_Search($Client.Handle, $searchState)
        
        if ($resultList -eq [IntPtr]::Zero) {
            $error = [Everything3SDK]::Everything3_GetLastError()
            throw "Suche fehlgeschlagen mit Fehler: $error"
        }
        
        try {
            # Ergebnis-Anzahl abrufen
            $viewportCount = [int][Everything3SDK]::Everything3_GetResultListViewportCount($resultList)
            $totalCount = [int][Everything3SDK]::Everything3_GetResultListCount($resultList)
            
            Write-Verbose "Gefunden $totalCount Ergebnisse insgesamt, gebe $viewportCount zurück"
            
            # Ergebnisse verarbeiten
            $results = @()
            for ($i = 0; $i -lt $viewportCount; $i++) {
                # Vollständigen Pfad abrufen
                $pathBuffer = New-Object System.Text.StringBuilder(32768)
                $pathLength = [Everything3SDK]::Everything3_GetResultFullPathNameW($resultList, [uint32]$i, $pathBuffer, [uint32]$pathBuffer.Capacity)
                Write-Verbose("Pathlength: " + $pathLength)
                if ($pathLength -gt 0) {
                    $fullPath = $pathBuffer.ToString()
                    $result = [Everything3Result]::new($fullPath)
                    
                    # Zusätzliche Eigenschaften abrufen
                    foreach ($propInfo in $propertyIds) {
                        # Write-Verbose("propInfo.Name: " + $propInfo.Name)
                        try {
                            if ($propInfo.Name -in @('DateCreated', 'DateModified', 'DateAccessed')) {
                                $value = [Everything3SDK]::Everything3_GetResultPropertyUINT64($resultList, [uint32]$i, $propInfo.Id)
                                $result.Properties[$propInfo.Name] = ConvertFrom-FileTime -FileTime $value
                            }
                            elseif ($propInfo.Name -eq 'Size') {
                                $value = [Everything3SDK]::Everything3_GetResultPropertyUINT64($resultList, [uint32]$i, $propInfo.Id)
                                $result.Properties[$propInfo.Name] = $value
                            }
                            elseif ($propInfo.Name -eq 'Attributes') {
                                $value = [Everything3SDK]::Everything3_GetResultPropertyDWORD($resultList, [uint32]$i, $propInfo.Id)
                                $result.Properties[$propInfo.Name] = $value
                            }
                            else {
                                $textBuffer = New-Object System.Text.StringBuilder(1024)
                                $textLength = [Everything3SDK]::Everything3_GetResultPropertyTextW($resultList, [uint32]$i, $propInfo.Id, $textBuffer, [uint32]$textBuffer.Capacity)
                                if ($textLength -gt 0) {
                                    $result.Properties[$propInfo.Name] = $textBuffer.ToString()
                                }
                            }
                        }
                        catch {
                            Write-Warning "Fehler beim Abrufen der Eigenschaft $($propInfo.Name) für $fullPath : $($_.Exception.Message)"
                        }
                    }
                    
                    $results += $result
                }
            }
            
            return $results
            
        }
        finally {
            [void][Everything3SDK]::Everything3_DestroyResultList($resultList)
        }
        
    }
    finally {
        [void][Everything3SDK]::Everything3_DestroySearchState($searchState)
    }
}

function Disconnect-Everything {
    <#
    .SYNOPSIS
    Trennt die Verbindung zur Everything-Suchmaschine.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [Everything3Client]$Client
    )
    
    $Client.Dispose()
    Write-Verbose "Everything-Client getrennt"
}

function Find-Files {
    <#
    .SYNOPSIS
    Praktische Wrapper-Funktion für die Dateisuche mit Everything.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Pattern,
        
        [int]$MaxResults = 1000,
        [string[]]$Extensions = @(),
        [switch]$IncludeProperties,
        [switch]$CaseSensitive,
        [switch]$Regex,
        [string]$InstanceName = $null
    )
    
    $client = $null
    try {
        # Mit Everything verbinden
        $client = Connect-Everything -InstanceName $InstanceName
        
        # Query mit Erweiterungen erstellen
        $query = $Pattern
        if ($Extensions.Count -gt 0) {
            $extQuery = ($Extensions | ForEach-Object { "ext:$_" }) -join "|"
            $query = "$Pattern ($extQuery)"
        }
        
        # Eigenschaften festlegen
        $properties = @()
        if ($IncludeProperties) {
            $properties = @("Size", "DateModified", "DateCreated", "Attributes")
        }
        
        # Suche ausführen
        $searchParams = @{
            Client     = $client
            Query      = $query
            MaxResults = $MaxResults
            Properties = $properties
            MatchCase  = $CaseSensitive
            Regex      = $Regex
        }
        Write-Verbose($searchParams | ConvertTo-Json)
        return Search-Everything @searchParams
        
    }
    finally {
        if ($client) {
            Disconnect-Everything -Client $client
        }
    }
}

function Test-EverythingConnection {
    <#
    .SYNOPSIS
    Testet die Verbindung zu Everything und zeigt Systeminformationen an.
    #>
    [CmdletBinding()]
    param()
    
    Write-Host "=== Everything3 Verbindungstest ===" -ForegroundColor Cyan
    
    try {
        $client = Connect-Everything
        try {
            Write-Host "✓ Erfolgreich mit Everything verbunden" -ForegroundColor Green
            
            # Version abrufen
            try {
                $majorVersion = [Everything3SDK]::Everything3_GetMajorVersion($client.Handle)
                $minorVersion = [Everything3SDK]::Everything3_GetMinorVersion($client.Handle)
                Write-Host "✓ Everything Version: $majorVersion.$minorVersion" -ForegroundColor Green
            }
            catch {
                Write-Host "⚠ Konnte Versionsinformationen nicht abrufen" -ForegroundColor Yellow
            }
            
            # DB-Status prüfen
            try {
                $dbLoaded = [Everything3SDK]::Everything3_IsDBLoaded($client.Handle)
                if ($dbLoaded) {
                    Write-Host "✓ Everything-Datenbank ist geladen" -ForegroundColor Green
                }
                else {
                    Write-Host "⚠ Everything-Datenbank ist nicht geladen" -ForegroundColor Yellow
                }
            }
            catch {
                Write-Host "⚠ Konnte DB-Status nicht prüfen" -ForegroundColor Yellow
            }
            
            # Test-Suche
            Write-Host "Führe Test-Suche durch..." -NoNewline
            $testResults = Search-Everything -Client $client -Query "*.txt" -MaxResults 5
            Write-Host " ✓ Erfolgreich ($($testResults.Count) Ergebnisse)" -ForegroundColor Green
            
        }
        finally {
            Disconnect-Everything -Client $client
        }
        
    }
    catch {
        Write-Host "✗ Verbindung fehlgeschlagen: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host ""
        Write-Host "Fehlerbehebung:" -ForegroundColor Yellow
        Write-Host "1. Stellen Sie sicher, dass Everything 1.5 läuft"
        Write-Host "2. Überprüfen Sie, ob Everything3_x64.dll im PATH ist"
        Write-Host "3. Versuchen Sie es mit Administratorrechten"
    }
}

#endregion

#region Module Exports

Export-ModuleMember -Function @(
    'Connect-Everything',
    'Search-Everything', 
    'Disconnect-Everything',
    'Find-Files',
    'Test-EverythingConnection'
)

#endregion

# Modul-Initialisierung
Write-Verbose "Everything3 PowerShell Wrapper geladen. Verwenden Sie Test-EverythingConnection zum Testen."
Write-Host "Everything3 PowerShell Wrapper bereit. Verwenden Sie Test-EverythingConnection zum Testen der Verbindung." -ForegroundColor Green