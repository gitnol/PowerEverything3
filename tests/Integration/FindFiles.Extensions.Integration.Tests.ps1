#Requires -Version 7.0
# Integrationstest fuer Find-Files -Extensions (GitHub-Issue #1) gegen eine lokale Everything-1.5-Instanz.
# Nur lesend; geschrieben wird allein in ein eigenes Fixture-Verzeichnis unter $env:TEMP (docs/testing/INTEGRATION_TESTS.md).
# Aufruf: Invoke-Pester tests/Integration -TagFilter Integration -Output Detailed

BeforeDiscovery {
    Import-Module (Join-Path (Split-Path $PSScriptRoot -Parent | Split-Path -Parent) 'Everything3-PowerShell-Wrapper.psd1') -Force
    $script:EverythingAvailable = $false
    try {
        $probe = Connect-Everything
        Disconnect-Everything -Client $probe
        $script:EverythingAvailable = $true
    }
    catch {
        Write-Warning "Everything nicht erreichbar - Integrationstests werden uebersprungen: $($_.Exception.Message)"
    }
}

BeforeAll {
    Import-Module (Join-Path (Split-Path $PSScriptRoot -Parent | Split-Path -Parent) 'Everything3-PowerShell-Wrapper.psd1') -Force

    # Everything indiziert lange Pfade, nicht 8.3-Kurznamen ($env:TEMP kann ein Kurzname sein, z. B. C:\Users\VORNAM~1.NAC)
    if (-not ('PE3IT.LongPath' -as [type])) {
        Add-Type -Namespace PE3IT -Name LongPath -MemberDefinition @'
[System.Runtime.InteropServices.DllImport("kernel32.dll", CharSet = System.Runtime.InteropServices.CharSet.Unicode, SetLastError = true)]
public static extern uint GetLongPathNameW(string shortPath, System.Text.StringBuilder longPath, uint bufferSize);
'@
    }
    $sb = [System.Text.StringBuilder]::new(32768)
    [void][PE3IT.LongPath]::GetLongPathNameW($env:TEMP, $sb, [uint32]$sb.Capacity)
    $tempLong = if ($sb.Length -gt 0) { $sb.ToString() } else { $env:TEMP }
    $script:Fixture = Join-Path $tempLong ('PE3-IT-{0:yyyyMMddHHmmss}' -f (Get-Date))
    New-Item -ItemType Directory -Path $script:Fixture | Out-Null

    # Treffer fuer pdf/docx: a.pdf, b.docx, e.PDF. Fallen: Endung steckt nur im NAMEN, aehnliche Endung (.doc).
    'a.pdf', 'b.docx', 'e.PDF', 'c.txt', 'd.doc', 'report_docx_notes.txt', 'pdfinfo.txt', 'docxlist.xml', 'noext' |
        ForEach-Object { Set-Content -LiteralPath (Join-Path $script:Fixture $_) -Value 'x' }

    $script:Scope = '"{0}\"' -f $script:Fixture
    $script:FixtureCount = @(Get-ChildItem -LiteralPath $script:Fixture -File).Count

    # Echtzeit-Index: auf die Fixture-Dateien warten (mit Timeout)
    $client = Connect-Everything
    try {
        $deadline = (Get-Date).AddSeconds(30)
        while (@(Search-Everything -Client $client -Query $script:Scope -MaxResults 0).Count -lt $script:FixtureCount) {
            if ((Get-Date) -gt $deadline) { throw "Everything hat '$($script:Fixture)' nicht indiziert (Index-Umfang pruefen)" }
            Start-Sleep -Milliseconds 250
        }
    }
    finally { Disconnect-Everything -Client $client }

    # Orakel: Erwartung aus dem Dateisystem, nicht aus eigener Annahme (principles/ORACLE_AND_RATCHET.md)
    function script:Get-Expected([string[]]$Ext) {
        Get-ChildItem -LiteralPath $script:Fixture -File |
            Where-Object { $_.Extension.TrimStart('.') -in $Ext } |
            ForEach-Object Name | Sort-Object
    }
    function script:Get-FoundName($Result) {
        # leeres Ergebnis (Suche ohne Treffer) ist ein gueltiger Fall: $null | ForEach-Object liefe sonst einmal mit $null
        @($Result | Where-Object { $null -ne $_ } | ForEach-Object Name) | Sort-Object
    }
}

AfterAll {
    # Sicherheitsnetz: nur das eigene Fixture unter $env:TEMP mit Praefix PE3-IT- loeschen, nie einen Suchtreffer-Pfad
    if ($script:Fixture -and (Split-Path -Leaf $script:Fixture) -like 'PE3-IT-*') {
        Remove-Item -LiteralPath $script:Fixture -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Describe 'Find-Files -Extensions' -Tag 'Integration' -Skip:(-not $script:EverythingAvailable) {
    It 'findet zwei Endungen ohne Punkt' {
        $r = Find-Files -Pattern "$script:Scope *" -Extensions 'pdf', 'docx' -MaxResults 0
        Get-FoundName $r | Should -Be (Get-Expected 'pdf', 'docx')
    }
    It 'findet zwei Endungen mit fuehrendem Punkt' {
        $r = Find-Files -Pattern "$script:Scope *" -Extensions '.pdf', '.docx' -MaxResults 0
        Get-FoundName $r | Should -Be (Get-Expected 'pdf', 'docx')
    }
    It 'findet eine einzelne Endung' {
        $r = Find-Files -Pattern "$script:Scope *" -Extensions 'pdf' -MaxResults 0
        Get-FoundName $r | Should -Be (Get-Expected 'pdf')
    }
    It 'liefert keine Dateien, deren Name nur die Endung enthaelt' {
        $names = Get-FoundName (Find-Files -Pattern "$script:Scope *" -Extensions 'pdf', 'docx' -MaxResults 0)
        $names | Should -Contain 'a.pdf'   # nicht leer: sonst waeren die Negativ-Pruefungen unten wertlos
        $names | Should -Not -Contain 'docxlist.xml'
        $names | Should -Not -Contain 'report_docx_notes.txt'
        $names | Should -Not -Contain 'pdfinfo.txt'
    }
    It 'laesst die Suche bei einer Liste nur aus leeren Eintraegen unveraendert' {
        @(Find-Files -Pattern "$script:Scope *" -Extensions '' -MaxResults 0).Count | Should -Be $script:FixtureCount
    }
    It 'ignoriert leere Eintraege neben echten Endungen' {
        $r = Find-Files -Pattern "$script:Scope *" -Extensions 'pdf', '' -MaxResults 0
        Get-FoundName $r | Should -Be (Get-Expected 'pdf')
    }
    It 'laesst die Suche ohne -Extensions unveraendert (alle Fixture-Dateien)' {
        @(Find-Files -Pattern "$script:Scope *" -MaxResults 0).Count | Should -Be $script:FixtureCount
    }
    It 'schraenkt ein Pattern mit OR auf oberster Ebene ebenfalls ein' {
        # c.txt und b.docx sind keine PDFs - es darf nichts zurueckkommen
        @(Find-Files -Pattern "$script:Scope c.txt|$script:Scope b.docx" -Extensions 'pdf' -MaxResults 0).Count | Should -Be 0
    }
}
