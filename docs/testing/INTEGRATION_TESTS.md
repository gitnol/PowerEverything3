# Integration Test Conventions – PowerEverything3

Stack: PowerShell 7+ gegen eine **lokale Everything-1.5a-Instanz** (Named Pipe über `Everything3_x64.dll`).
Stand Init: noch keine Integrationstests — geplant in I5 (`docs/TODO.md`).

Warum Integrationstests hier Pflicht sind: Die P/Invoke-Schicht lässt sich nicht mocken, und die zuletzt behobenen
Fehler (falsche Typbreiten `uint` statt `UIntPtr`, fehlendes `CharSet.Unicode`, Property-ID `0`) zeigen sich nur gegen
eine echte Instanz — als falsche oder abgeschnittene Werte, nicht als Exception.

---

## 1. Grundprinzip: Nur lesen, nur eigene Fixtures

Integrationstests **lesen** ausschließlich über das Modul. Geschrieben wird nur in ein eigenes Fixture-Verzeichnis unter
`$env:TEMP`, das der Test selbst anlegt und im `AfterAll` wieder entfernt:

```powershell
BeforeAll {
    Import-Module (Join-Path (Split-Path $PSScriptRoot -Parent | Split-Path -Parent) 'Everything3-PowerShell-Wrapper.psd1') -Force
    $script:Fixture = Join-Path $env:TEMP ("PE3-IT-{0:yyyyMMddHHmmss}" -f (Get-Date))
    New-Item -ItemType Directory -Path $script:Fixture | Out-Null
    Set-Content -LiteralPath (Join-Path $script:Fixture 'alpha.txt') -Value 'a'
    # ... weitere Fixture-Dateien mit bekannten Größen/Zeitstempeln
    $script:Client = Connect-Everything
    # warten, bis Everything die Fixtures indiziert hat (Echtzeit-Index, mit Timeout)
    $deadline = (Get-Date).AddSeconds(30)
    while (@(Search-Everything -Client $script:Client -Query ('"{0}\"' -f $script:Fixture) -MaxResults 0).Count -lt 1) {
        if ((Get-Date) -gt $deadline) { throw "Everything hat '$($script:Fixture)' nicht indiziert (Index-Umfang prüfen)" }
        Start-Sleep -Milliseconds 250
    }
}
AfterAll {
    if ($script:Client) { Disconnect-Everything -Client $script:Client }
    if ($script:Fixture -and $script:Fixture.StartsWith($env:TEMP)) { Remove-Item -LiteralPath $script:Fixture -Recurse -Force }
}
```

**Sicherheitsnetz:** Das Aufräumen löscht nur Pfade unter `$env:TEMP` mit dem Präfix `PE3-IT-` — nie einen Pfad aus
einem Suchtreffer. Suchen der Tests sind immer auf das Fixture-Verzeichnis eingeschränkt, damit keine privaten Pfade
des Entwicklerrechners in Testausgaben landen.

Läuft keine Everything-Instanz, werden die Tests mit klarer Meldung übersprungen (`Set-ItResult -Skipped` bzw.
`-Skip:`-Bedingung), nicht als Fehler gewertet.

---

## 2. Orakel: Erwartungswerte aus dem Dateisystem

Erwartungswerte kommen aus `Get-Item` auf die Fixture-Dateien (Größe, `LastWriteTime`, Attribute, Name, Pfad) — nie aus
eigener Annahme (`principles/ORACLE_AND_RATCHET.md`). Zu prüfen:

| Fall | Erwartung |
|---|---|
| `-Properties Name, Path, Extension, Type` | vollständige Zeichenketten (Regression „nur erstes Zeichen") |
| `-Properties Size` | Bytes wie `Get-Item`; Ordner → `$null` |
| `-Properties DateModified, DateCreated` | `[datetime]` wie `Get-Item` (Toleranz: Auflösung des Index) |
| `-SortBy @{ Property = 'Name' }` / `'Size'` absteigend | Reihenfolge wie `Sort-Object` auf den Fixtures |
| `-Offset 1 -MaxResults 1`, `-MaxResults 0` | Ausschnitt bzw. alle Fixture-Treffer |
| Pfad länger als 1023 Zeichen mit `-Properties Path` | klärt `docs/KNOWN_ISSUES.md` K3 |

---

## 3. Mailversand und AD nur manuell

Das Beispielskript wird **nicht** automatisch gegen ein echtes SMTP-Relay oder das AD getestet. Ende-zu-Ende-Läufe
in Tests nutzen `-SearchMode Scan` auf einem Temp-Fixture **ohne** `-SendMail`. Mailinhalte werden in Unit-Tests
über `New-MailBody` bzw. einen Mock von `Send-MailMessage` geprüft (`testing/UNIT_TESTS.md` §4).

---

## 4. Test-Assertions: Nie per Pipe aufrufen

Selbst geschriebene Assertion-Hilfsfunktionen (ohne Pester) haben oft **keinen**
`[Parameter(ValueFromPipeline)]`-Parameter. Pipe-Input wird dann still verworfen —
`$Value` bleibt `$null` und die Assertion schlägt fälschlicherweise fehl.

```powershell
function Assert-NotNull {
    param($Value, [string]$Because = '')
    if ($null -eq $Value) { throw "Erwartet: nicht null. $Because" }
}

# ✓ Richtig – direkter Aufruf
Assert-NotNull $myObject

# ✗ Falsch – $myObject wird NICHT übergeben ($Value = $null), Assertion schlägt fehl
$myObject | Assert-NotNull
```

Mit Pester (`Should`-Cmdlets): kein Problem, Pester implementiert `ValueFromPipeline`
korrekt. Dieser Hinweis gilt nur für eigene Assertion-Helfer ohne Pester.

---

## 5. Schreib-Pfade immer PSScriptRoot- oder TEMP-basiert, nie CWD-relativ

Ein Default wie `$OutputDir = '.\out'` erzeugt je nach Startverzeichnis unterschiedliche Ordner. Fixtures liegen unter
`$env:TEMP`, Testausgaben (falls nötig) an Repo-Root verankert:

```powershell
[string] $OutputDir = (Join-Path (Split-Path $PSScriptRoot -Parent) 'out')   # out/ dann in .gitignore
```

---

## 6. Was nicht automatisiert getestet wird

| Bereich | Grund | Alternative |
|---------|-------|-------------|
| Mailversand an echte Empfänger | Nebenwirkung bei Dritten | `-SendMail -MaxMails 3` ohne `-Live` (alles an `$DebugTo`), manuell |
| AD-Auflösung von Besitzern | braucht Domäne und echte Konten | manueller Dry-Run auf dem Zielserver, CSV prüfen |
| `-AllShares` / `Get-SmbShare` | braucht Adminrechte und echte Freigaben | `Get-DataShares -Raw` mit Testobjekten (Unit), Dry-Run manuell |
| Everything-Dienst-Konfiguration | Systemkonfiguration des Entwicklerrechners | `Test-EverythingConnection` als Vorab-Check |
