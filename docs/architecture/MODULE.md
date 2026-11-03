# PowerShell-Modul – PowerEverything3

Aufbau, Manifest, Tests, Verteilung und mitgelieferte native Binärdatei des Moduls `Everything3-PowerShell-Wrapper`.
Gilt zusammen mit `CONVENTIONS.md` (Exportliste: Abschnitt „Dateiorganisation"; Seiteneffekte beim Import: Abschnitt
„Prozessweite Side-Effects") und `architecture/DEPENDENCIES.md`.

Stand der Bestandsaufnahme: 2026-10-22 (docs_template v28). Abweichungen vom Zielbild sind mit **offen** markiert und
stehen als Aufgaben in `docs/TODO.md` (I2 bzw. I8).

---

## Aufbau

Das Modul liegt direkt im Repository-Root, nicht in einem eigenen Unterordner:

```text
PowerEverything3/
├── Everything3-PowerShell-Wrapper.psd1   # Manifest: Version, NestedModules, Exportliste
├── Everything3-PowerShell-Wrapper.psm1   # RootModule: Klassen, öffentliche Funktionen, interne Helfer
├── Everything3SDK.psm1                   # NestedModule: lädt die DLL, P/Invoke-Signaturen (Add-Type)
├── Everything3_x64.dll                   # native SDK3-DLL (Abschnitt „Native Binärdateien")
├── Everything3-Examples.ps1              # interaktive Beispiele, kein Teil des Moduls
└── Examples/                             # Beispielskript Fileserver-Bereinigung, kein Teil des Moduls
```

Ladereihenfolge: Das Manifest lädt zuerst `Everything3SDK.psm1` (NestedModules), danach das RootModule. Die Klassen
`Everything3Client` und `Everything3Result` im RootModule referenzieren den `Add-Type`-Typ `Everything3SDK`; das geht
nur, weil das NestedModule vorher lädt (`docs/LESSONS_LEARNED.md` L1).

| Funktion | Sichtbarkeit | Zweck |
|---|---|---|
| `Connect-Everything`, `Search-Everything`, `Disconnect-Everything`, `Find-Files`, `Test-EverythingConnection` | öffentlich | API laut `docs/features/EVERYTHING_SEARCH.md` |
| `Get-PropertyId`, `ConvertFrom-FileTime` | intern | Property-Mapping, FILETIME-Umrechnung |

- **Abweichung vom Template-Aufbau** (`Public/`, `Private/`, `bin/`, eine Funktion je Datei): Das Modul ist klein
  (RootModule 425 Zeilen, Interop 168 Zeilen); eine Aufteilung würde Pfade für Nutzer, die aus dem Klon importieren,
  nicht ändern, ist aber nicht geplant. Entscheidung offen (`docs/TODO.md` I8).
- **Strict Mode:** Keine der beiden `.psm1` setzt `Set-StrictMode -Version 3.0` — **offen** (I8).
- Der Import hat keine Wirkung außerhalb des Moduls: kein `$env:PATH`, keine TLS-Einstellung, keine Ausgabe
  (`CONVENTIONS.md`, Abschnitt „Prozessweite Side-Effects"). **Offen:** `Everything3SDK.psm1` stellt das
  Modulverzeichnis vor `$env:PATH` (`docs/KNOWN_ISSUES.md` K2, Fix in I2). Ausgaben beim Import nur über
  `Write-Verbose` — erfüllt.
- **Importiert wird immer das Manifest** (`Import-Module …\Everything3-PowerShell-Wrapper.psd1` bzw. per Name). Nur das
  Manifest filtert die Exporte und prüft Mindestversion und Architektur; wer die `.psm1` direkt importiert, umgeht
  die Prüfungen — hier scheitert der Direktimport zusätzlich an der Ladereihenfolge (L1). Das gilt auch für Tests
  und Beispielskripte. Stand: README, `operations/SETUP.md` und das Beispielskript (`$EverythingModule`, Zeile 118)
  importieren die `.psd1`; der Kopfkommentar von `Everything3-Examples.ps1` nennt noch die `.psm1`
  (`docs/KNOWN_ISSUES.md` K1, `docs/TODO.md` Niedrige Priorität).

---

## Manifest

| Schlüssel | Regel | Stand `Everything3-PowerShell-Wrapper.psd1` |
|---|---|---|
| `ModuleVersion` | Drei Stellen nach SemVer: Major bei Bruch (Funktion entfernt oder umbenannt, Pflichtparameter oder Rückgabe geändert), Minor bei neuer Funktion, Patch sonst. **Einzige Quelle der Version** — README, Release Notes und Installationsordner übernehmen sie von hier. | `'0.1.0'`, bisher nie erhöht (`operations/DEPLOYMENT.md` „Release") |
| `GUID` | Einmal erzeugen, nie ändern. | gesetzt |
| `RootModule` | `'Everything3-PowerShell-Wrapper.psm1'` | erfüllt |
| `NestedModules` | `@('Everything3SDK.psm1')` — muss vor dem RootModule laden (L1). | erfüllt |
| `PowerShellVersion` | Mindestversion; der Import bricht darunter mit klarer Meldung ab. Ohne Angabe scheitert das Modul unter Windows PowerShell 5.1 erst mit Parserfehlern (`??`-Operator, Klassen). Nach Sicherheitskorrekturen der Laufzeit anheben (`docs/principles/SECURITY_CURRENCY.md`). | fehlt — **offen** (I2: `'7.0'`) |
| `CompatiblePSEditions` | `@('Core')`. Nur eine Angabe: Ab PowerShell 6 wertet PowerShell sie lediglich beim Import aus dem System32-Modulpfad aus; ausgeschlossen wird Windows PowerShell über `PowerShellVersion`. | fehlt — **offen** (I2) |
| `ProcessorArchitecture` | `'Amd64'` (native x64-DLL). Der Import bricht bei abweichender Prozessarchitektur mit klarer Meldung ab. | fehlt — **offen** (I2) |
| `FunctionsToExport` | Explizite Liste der fünf öffentlichen Funktionen — Regel: `CONVENTIONS.md`, Abschnitt „Dateiorganisation". | `'*'` — **offen** (I2) |
| `CmdletsToExport`, `VariablesToExport`, `AliasesToExport` | `@()` — nicht weglassen und nicht `'*'`. Ein fehlender Schlüssel filtert nicht. | `'*'` — **offen** (I2) |
| `RequiredModules` | Keine: Das Modul braucht zur Laufzeit keine weiteren Module (`architecture/DEPENDENCIES.md`). | nicht gesetzt — erfüllt |
| `PrivateData.PSData.ReleaseNotes` | Kurz, mit Verweis auf den Changelog — keine zweite Fassung. Nutzer-Changelog steht heute im README. | leer |

Die Exportliste steht **nur im Manifest**. **Offen:** `Everything3-PowerShell-Wrapper.psm1` endet mit
`Export-ModuleMember -Function @(…)` (fünf Namen); wirksam ist die Schnittmenge beider Listen. Entfernen, sobald I2
die Liste ins Manifest geschrieben hat (I8).

`Author`, `CompanyName`, `Copyright` und `PrivateData` sind öffentliche Metadaten: Für dieses öffentliche Repository
gelten die Interna-Regeln aus `docs/CONVENTIONS_COMMON.md` 3.1.

---

## Modultests

Gehören zu Gate 4 (`CONVENTIONS.md` §9) und laufen ohne Everything-Instanz. Es gibt noch keine Tests; Harness und
die Fälle „exportiert genau die fünf Funktionen" und „Import ändert PATH nicht" legt I2 an (Muster:
`testing/UNIT_TESTS.md` §3). Ergänzend gehört dazu:

```powershell
# tests/Module.Tests.ps1
BeforeAll {
    $script:Manifest = Join-Path $PSScriptRoot '..\Everything3-PowerShell-Wrapper.psd1'
}

Describe 'Modulvertrag' {
    It 'Manifest ist gueltig' {
        { Test-ModuleManifest -Path $script:Manifest -ErrorAction Stop } | Should -Not -Throw
    }
    It 'filtert jede Exportart ausdruecklich und ohne Platzhalter' {
        $daten = Import-PowerShellDataFile $script:Manifest
        foreach ($schluessel in 'FunctionsToExport', 'CmdletsToExport', 'VariablesToExport', 'AliasesToExport') {
            $daten.ContainsKey($schluessel) | Should -BeTrue -Because "ohne $schluessel filtert das Manifest nicht"
            @($daten[$schluessel]) -contains '*' | Should -BeFalse -Because "$schluessel enthaelt '*'"
        }
    }
}
```

Weitere Zustände, die das Modul beim Import nicht verändern darf, als eigene Fälle ergänzen (Liste in
`CONVENTIONS.md`, Abschnitt „Prozessweite Side-Effects").

---

## Native Binärdateien

1. **Ablage und Herkunft:** `Everything3_x64.dll` liegt im Modulordner (Root, nicht `bin/`), in `.gitattributes` als
   `binary`. Herkunft (SDK 3.0.1.12), Signaturprüfung (voidtools PTY LTD) und SHA-256 stehen in
   `architecture/DEPENDENCIES.md` („Externe Binaries"). Zielbild laut Template: die Prüfsumme steht nur im Modulcode,
   `DEPENDENCIES.md` nennt Herkunft, Version und Signaturergebnis — umstellen mit der Prüfsummenprüfung (I8).
2. **Vor dem Laden prüfen:** Heute keine Prüfung (`security/THREAT_MODEL.md` §1). Zielbild: Prüfsumme bei jedem
   Import; Authenticode-Signatur (`Get-AuthenticodeSignature`) beim Austausch der DLL prüfen und eintragen. I2 plant
   eine Authenticode-Prüfung bei jedem Import — Abgleich mit dem Zielbild **offen** (I8).
3. **Mit vollem Pfad laden, nicht über `PATH`:** `Everything3SDK.psm1` lädt die DLL vorab mit vollem Pfad
   (`[Kernel32]::LoadLibrary($DllPath)`, Zeile 155) — die `DllImport`-Deklarationen nennen nur den Dateinamen,
   erfüllt. **Offen:** zusätzlich die `PATH`-Erweiterung (K2, I2). `LoadLibrary` ist ohne `CharSet` deklariert und
   bindet damit die ANSI-Variante; Pfade mit Zeichen außerhalb der ANSI-Codepage können scheitern. Das Modul
   verlangt PowerShell 7, dort leistet `[System.Runtime.InteropServices.NativeLibrary]::Load` dasselbe ohne eigenen
   `Kernel32`-Typ (I8).
4. **Typ nur einmal anlegen:** erfüllt — `Add-Type` nur, wenn `[System.Management.Automation.PSTypeName]'Everything3SDK'`
   fehlt. Nach Austausch der DLL oder einem Modulupdate eine neue Sitzung starten (`CONVENTIONS.md`, Abschnitt
   „Prozessweite Side-Effects", `Add-Type`).

Zielbild für `Everything3SDK.psm1` (Prüfsumme aus `DEPENDENCIES.md`, nach I8 nur noch hier):

```powershell
Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

$script:DllPfad   = Join-Path $PSScriptRoot 'Everything3_x64.dll'
$script:DllSha256 = '450FAF011103C7DCE6049FDB7C8851E26578AC5D3A404A02E759529939D6F289'   # SDK 3.0.1.12
$ist = (Get-FileHash -LiteralPath $script:DllPfad -Algorithm SHA256).Hash
if ($ist -ne $script:DllSha256) { throw "Pruefsumme der DLL stimmt nicht: $script:DllPfad" }
$null = [System.Runtime.InteropServices.NativeLibrary]::Load($script:DllPfad)
if (-not ('Everything3SDK' -as [type])) {
    Add-Type -TypeDefinition $Everything3Type   # DllImport("Everything3_x64.dll", …) wie bisher
}
```

Abhängigkeiten der DLL sucht Windows nur per Dateiname. Die SDK-DLL 3.0.1.12 nennt nur Windows-Systembibliotheken
(`KERNEL32`, `USER32`, `OLEAUT32`, `ole32`, `mscoree`; geprüft 2026-11-03 per Namenssuche im Binärcode, nicht per
Importtabelle). Bringt eine neue SDK-Version eigene DLLs mit, diese ebenso vorab laden und den Fall testen.

---

## Installation und Verteilung

Heute: Klonen und aus dem Arbeitsverzeichnis importieren (README „Quick Start", `operations/SETUP.md`); für
dauerhafte Nutzung empfiehlt `SETUP.md`, den Modulordner an einen nur für Administratoren beschreibbaren Ort zu
kopieren. Kein Release, keine Veröffentlichung (PowerShell Gallery: `docs/BACKLOG.md`).

- **Versionierter Ordner:** `<Modulpfad>\Everything3-PowerShell-Wrapper\<ModuleVersion>\` — der Ordnername muss dem
  Manifestnamen entsprechen, sonst findet `Import-Module` per Name das Modul nicht. Eine unversionierte Kopie veraltet
  unbemerkt; liegt daneben ein Versionsordner, lädt PowerShell den Versionsordner. In README/SETUP noch nicht
  beschrieben — **offen** (I8).
- **Aus einem Commit installieren**, nicht aus dem Arbeitsverzeichnis, und nur die Moduldateien:
  `git archive <ref> Everything3-PowerShell-Wrapper.psd1 Everything3-PowerShell-Wrapper.psm1 Everything3SDK.psm1 Everything3_x64.dll LICENSE`;
  danach prüfen: `Get-Module Everything3-PowerShell-Wrapper -ListAvailable | Select-Object Name, Version, ModuleBase`.
- **Ort nach Rechten wählen:** Das Beispielskript läuft als Administrator und importiert das Modul — es gehört dann in
  den Modulpfad für alle Benutzer (`$env:ProgramFiles\PowerShell\Modules`), den nur Administratoren schreiben. In den
  Modulpfad des Benutzers schreibt jeder Prozess dieses Benutzers; eine dort ausgetauschte `.psm1` oder DLL liefe beim
  nächsten Import mit Adminrechten (`security/THREAT_MODEL.md` §1). Pfade per `$env:PSModulePath -split ';'`
  ermitteln, nicht fest annehmen.

---

## Typische Fallen

| Symptom | Ursache | Fix |
|---|---|---|
| Neue Funktion fehlt nach dem Import, ohne Fehler | Name steht im Manifest, aber nicht im `Export-ModuleMember` der `.psm1` (wirksam ist die Schnittmenge) | Liste nur im Manifest (I8) |
| Interne Helfer (`Get-PropertyId`, `ConvertFrom-FileTime`) öffentlich sichtbar | `'*'` im Manifest ohne `Export-ModuleMember`, oder `.psm1` direkt importiert | Manifest mit expliziter Liste importieren; Modultest „exportiert genau …" |
| `Unable to find type [Everything3SDK]` beim Import | `.psm1` direkt importiert, NestedModule nicht geladen (L1, K1) | Manifest importieren |
| Nach dem Update fehlen neue Funktionen | Altkopie ohne Versionsordner, oder die Sitzung hält das alte Modul | Versionsordner; `Get-Module -ListAvailable`; neue Sitzung |
| Parserfehler unter Windows PowerShell 5.1 statt klarer Meldung | `PowerShellVersion` fehlt | Mindestversion setzen (I2) |
| Erster Aufruf einer nativen Funktion scheitert | DLL nicht vorab geladen | vorab mit vollem Pfad laden |
| Andere Programme der Sitzung laden DLLs aus dem Modulordner | Import hat `$env:PATH` erweitert (K2) | Vorabladen statt `PATH` (I2); Modultest „Import ändert PATH nicht" |
| Nach DLL-Austausch weiter altes Verhalten | Typ aus `Add-Type` und geladene DLL sind nicht entladbar | Neue Sitzung |

---

## Pflege

Trigger: neue oder entfernte öffentliche Funktion, Versionswechsel, neue oder ausgetauschte native DLL, geänderter
Installationsweg → diese Datei + `Everything3-PowerShell-Wrapper.psd1` + ggf. `architecture/DEPENDENCIES.md`,
README (EN/DE) und `docs/CHANGELOG.md`.
