# Coding Conventions – PowerEverything3

Stack: PowerShell 7.0+ (Beispielskript 7.2+) | keine Laufzeit-Module; native `Everything3_x64.dll` (P/Invoke) | Windows x64

> Gilt **zusammen mit** `docs/CONVENTIONS_COMMON.md` (stack-übergreifend: Commit-Format, Encoding,
> öffentliche Repos/Interna, Quality Gates, parallele Agenten). Diese Datei regelt die
> Stack-Spezifika und hat dort Vorrang.

> **Sprache:** `docs/` ist deutsch (Template-Default). Das Projekt ist öffentlich und zweisprachig: `README.md`
> (Englisch, maßgeblich für Nutzer) und `README-DE.md` (Übersetzung) werden **gemeinsam** gepflegt. Code-Kommentare und
> Meldungen sind heute gemischt (Modul deutsch, Beispielskript englisch; `docs/BACKLOG.md` → Technische Schuld).

> **Stack-Abweichung:** Das Projekt ist primär ein PowerShell-**Modul** mit nativer DLL, kein Task-Scheduler-Skript.
> Nicht zutreffende Template-Abschnitte (REST/HATEOAS, JSON-Bodies, SQL Server, Task-Scheduler-XML) sind gestrichen;
> Lücke gemeldet in `docs/BACKLOG.md` → Template-Evolution.

---

## 1. Git & Versionierung

Commit-Format, Scope-Wahl, `git add`-Regeln und Zeilenenden: `docs/CONVENTIONS_COMMON.md` §1–§2;
Commit-Pflicht pro Inkrement: `docs/KICKOFF.md` Phase 3b. Stack-spezifisch nur:

- Scope-Beispiele: `fix(I2): manifest exports`, `feat(search): pipeline output`, `docs(readme): tested versions`
- **Öffentliches Repository:** Interna-Hook aktiv halten (`git config core.hooksPath tools/git-hooks`), Beispielwerte
  nur `example.com`.
- `Everything3_x64.dll` ist per `.gitattributes` binär; nur durch eine geprüfte DLL aus dem offiziellen SDK ersetzen
  (Signatur + SHA256 in `docs/architecture/DEPENDENCIES.md` nachziehen).

## 2. PowerShell Code-Richtlinien

- **CmdletBinding + Param:** Jede exportierte Funktion und jedes Skript mit `[CmdletBinding()]` und `param()`-Block.
- **Approved Verbs:** Nur [genehmigte PowerShell-Verben](https://docs.microsoft.com/powershell/scripting/developer/cmdlet/approved-verbs-for-windows-powershell-commands) für Funktionsnamen.
  Bestehende öffentliche Namen (`Find-Files`) bleiben trotz `PSUseSingularNouns` — Umbenennen bräche Nutzer (§9).
- **Fehlerbehandlung:** Skripte mit `$ErrorActionPreference = 'Stop'` (Beispielskript zusätzlich `Set-StrictMode -Version 3.0`).
  `try/catch` für alle externen Aufrufe. Kein leeres `catch {}` ohne Kommentar **und** Logging (`docs/architecture/ERROR_HANDLING.md`).
- **Eingabevalidierung:** `[ValidateNotNullOrEmpty()]`, `[ValidateRange()]`, `[ValidateSet()]` in `param()`-Blöcken. Fail-Fast vor Business-Logik.
- **Keine Magic Strings:** Konstanten (Pfade, Mindestversionen, Puffergrößen) als `$script:`-Konstante am Dateianfang.
- **Ausgabe:** Im Modul-Kern Diagnose nur über `Write-Verbose`/`Write-Warning`; das Modul schreibt beim Laden nichts auf
  die Konsole. Ausnahmen (bewusst): `Test-EverythingConnection` (interaktive Diagnose) und `Write-Log` im Beispielskript
  nutzen `Write-Host` — Umstellung auf `Write-Information` steht in `docs/TODO.md`.
- **Bare-Aufruf einer wertrückgebenden Funktion leckt in den Output-Stream:** PowerShell
  schreibt **jeden** nicht zugewiesenen Ausdruck in die Pipeline. Rückgaben von P/Invoke-Aufrufen, die nur zur
  Seitenwirkung erfolgen, explizit verwerfen — so wie im Modul üblich:
  ```powershell
  [void][Everything3SDK]::Everything3_SetSearchMatchCase($searchState, $MatchCase.IsPresent)   # ✓
  [Everything3SDK]::Everything3_SetSearchMatchCase($searchState, $true)                         # ✗ bool leckt in die Ausgabe
  ```
  Tests, die nur „Output ist nicht null" prüfen, **maskieren** diesen Bug — exakt prüfen (`Count`, Typ/Wert).

### 2.1 P/Invoke und native Handles (projektspezifisch)

- **Signaturen exakt nach `Everything3.h`:** `SIZE_T` → `UIntPtr`, `DWORD` → `uint`, `UINT64` → `ulong`, `BOOL` → `bool`;
  Funktionen mit `W`-Suffix bzw. Textausgabe mit `CharSet = CharSet.Unicode`; `CallingConvention.StdCall`.
- **Property-IDs** nur aus `[Everything3Properties]`; ID `0` (`Name`) ist gültig — Prüfungen immer `$null -ne $id`.
- **Handles in `try/finally` freigeben** (Search-State, Result-List); jede neue Funktion, die einen Client öffnet,
  schließt ihn im `finally`.
- **`Add-Type` nur einmal pro Prozess:** vor `Add-Type` per `[System.Management.Automation.PSTypeName]` prüfen, ob der Typ existiert.
- **Puffer:** Größen als Konstante; Verhalten bei zu kleinem Puffer per Integrationstest belegen (`docs/KNOWN_ISSUES.md` K3).

## 3. Dateiorganisation

- **Modul:** Manifest `.psd1` ist der einzige Import-Einstieg; Interop (`Everything3SDK.psm1`) als `NestedModules`,
  öffentliche API im RootModule. Klassen im RootModule dürfen den `Add-Type`-Typ nur referenzieren, weil das
  NestedModule vorher lädt (`docs/LESSONS_LEARNED.md` L1).
- **Beispielskripte** liegen unter `Examples/` bzw. im Root (`Everything3-Examples.ps1`) und nutzen nur exportierte
  Funktionen (`docs/architecture/PROJECT_LAYOUT.md`). Ihre echte Konfiguration (`*.config.ps1`) ist gitignored; versioniert
  wird nur `*.config.example.ps1`.
- **Größe:** Das Beispielskript (737 Zeilen) überschreitet das Template-Richtmaß (Funktionen in eigene Dateien ab
  ~300 Zeilen); Aufteilung ist I6.
- **`FunctionsToExport` in der `.psd1` immer EXPLIZIT, niemals `'*'`.** Ebenso `CmdletsToExport`, `AliasesToExport`,
  `VariablesToExport` als leere Liste, solange nichts exportiert wird. Stand Init verletzt (`'*'`) → I2.
- **Manifest deklariert die Laufzeit:** `PowerShellVersion`, `CompatiblePSEditions = @('Core')`,
  `ProcessorArchitecture = 'Amd64'` — Fail-Fast beim Import statt Parserfehler. Stand Init fehlt → I2.
- **Encoding-Ausnahmen** (Vorrang vor `CONVENTIONS_COMMON.md` §2, sonst gilt UTF-8 ohne BOM):
  - **Testdateien mit Nicht-ASCII-Zeichen** (deutsche `It`-Texte) als UTF-8 **mit BOM** — sonst meldet
    PSScriptAnalyzer `PSUseBOMForUnicodeEncodedFile`. Details: `testing/UNIT_TESTS.md` 7.6.
  - **Modulquellen:** heute UTF-8 ohne BOM **mit** Nicht-ASCII (Umlaute, `✓`) → 5 PSSA-Befunde; Entscheidung ASCII vs.
    BOM steht in `docs/TODO.md` (Niedrig). Bis dahin keine weiteren Nicht-ASCII-Zeichen in neue Modulzeilen.
  - **Zeilenenden:** `.ps1`, `.psm1` und `.psd1` mit LF sind unkritisch (PowerShell liest beides), es gilt
    `CONVENTIONS_COMMON.md` §2. Ausnahme: Authenticode-signierte Dateien — die Signatur gilt für die Bytes, sie
    bleiben wie signiert (in `.gitattributes` als `binary`).

## 4. Prozessweite Side-Effects — Save/Restore-Pflicht

PowerShell-Skripte/Module mutieren häufig **prozessweite** Zustände, die die
gesamte Session überleben. Folgende Stellen sind besonders heimtückisch, weil
ein logischer „Logout"/`Disconnect`/Skript-Ende den Zustand **nicht** automatisch
zurücksetzt:

- `$env:*` und `[Environment]::SetEnvironmentVariable(... 'Process')` — **im Projekt verletzt:**
  `Everything3SDK.psm1` stellt das Modulverzeichnis vor `$env:PATH` (`docs/KNOWN_ISSUES.md` K2, Fix in I2)
- `[System.Net.ServicePointManager]::SecurityProtocol` (TLS-Set — wirkt auf **jede** Verbindung der Session)
- `Set-Location` (CWD) ohne `Push-Location`/`Pop-Location`
- `$ErrorActionPreference`, `$ProgressPreference`, `$VerbosePreference` global statt lokal
- `Add-Type` und `LoadLibrary` (lassen sich nicht entladen — nur über Typ-Existenz-Check schützen; die native DLL bleibt
  bis Prozessende geladen)

**Pflicht-Pattern:** vor der Mutation den alten Wert einmalig in einem
modul-/skript-skopierten `$script:`-Slot sichern, am Ende (Disconnect, Cleanup,
`finally`, `$MyInvocation.MyCommand.ScriptBlock.Module.OnRemove`) restaurieren. Mehrfach-Aufrufe nicht den bereits
mutierten Wert sichern lassen (Flag-Guard). Besser: Mutation ganz vermeiden (hier: DLL mit vollem Pfad laden).

## 5. Pfade & Dateisystem

- **Pfade immer als `[System.IO.Path]`-Methoden** oder `Join-Path` — nie String-Konkatenation mit `\`
- **`-LiteralPath`** für alle Pfade aus Suchtreffern oder von Nutzern (Klammern/Wildcards in Ordnernamen)
- **Test-Path vor Zugriff:** Externe Ressourcen (UNC-Pfade, `7z.exe`) vor Verwendung prüfen
- **Credentials niemals in Variablen für $env:** Nur `[PSCredential]`-Parameter (`docs/architecture/CREDENTIAL_STRATEGY.md`)

## 6. Security-Checkliste vor jedem Commit

- [ ] Keine Hardcoded-Credentials; keine echten Hostnamen/Adressen (öffentliches Repo) — nur `example.com`
- [ ] Echte `*.config.ps1`, CSV- und Log-Ausgaben in `.gitignore`, nichts davon gestaged
- [ ] Kein `Invoke-Expression` mit nicht-validierten Strings (Command-Injection); Prozessaufrufe nur mit
      `ProcessStartInfo.ArgumentList` (wie `Invoke-SevenZip`)
- [ ] Logging: keine Passwörter/Tokens; Transcript enthält personenbezogene Daten → Ablage laut `docs/security/DATA_HANDLING.md`
- [ ] Prozessweite State-Mutationen (`$env:`, TLS, `Set-Location`) haben Save/Restore oder entfallen (Sektion 4)
- [ ] `FunctionsToExport` ist eine **explizite Liste** (kein `'*'`); keine privaten Helfer in der öffentlichen API (Sektion 3)
- [ ] Native DLL nur aus geprüfter Quelle; Signatur/Hash dokumentiert (`docs/architecture/DEPENDENCIES.md`)
- [ ] Mail-/HTML-Ausgaben: alle Fremdwerte mit `HtmlEncode` (Beispielskript `New-MailBody`)
- [ ] **Gefährliche Schalter** verlangen eine bewusste Bestätigung (Sektion 6.1)

## 6.1 Sicherheits-Pattern: bewusste Bestätigung gefährlicher Schalter

Wenn ein Skript eine sichere Default-Option und eine folgenreiche Option hat, muss die folgenreiche Variante
**bewusst** bestätigt werden. Das Beispielskript setzt das bereits zweistufig um: ohne `-SendMail` keine Mails
(Dry-Run), ohne zusätzliches `-Live` gehen alle Mails an `$DebugTo`. Offener Fall: `-SmtpCredential` ohne TLS
überträgt die Anmeldung im Klartext — Kandidat für das Muster (Entscheidung in I7):

```powershell
param([pscredential]$SmtpCredential, [switch]$Force)
if ($SmtpCredential -and -not $SmtpUseSsl -and -not $Force) {
    Write-Warning 'SMTP-Anmeldung ohne TLS wird im Klartext übertragen.'
    throw 'Refused -SmtpCredential without TLS: set $SmtpUseSsl = $true or confirm with -Force.'
}
```

Der Throw passiert **vor** teurem Setup (Scan, Inhaltsprüfung) — sonst erfährt der Nutzer erst nach Stunden vom Abbruch.

Die Template-Pattern „Defense-in-Depth für Test-Credentials" und „Newline-Validierung für Single-Command-APIs" sind
gestrichen: Das Projekt hat keine Test-Credentials und keine Befehls-API.

---

## 7. Autonomes Arbeiten & Fehlerbehebung

- Bei Fehlern: nicht sofort abbrechen. `$Error[0]` und Stack-Trace lesen.
- Nur Dateien verändern, die für das aktuelle Inkrement relevant sind.
- Keine Suche gegen die Everything-Instanz des Entwicklers ausgeben, deren Treffer private Pfade zeigen könnten —
  Tests arbeiten mit Fixtures unter `$env:TEMP`.
- Am Ende jedes Inkrements: `docs/TODO.md`, `docs/CHANGELOG.md`, `docs/STATE.md` aktualisieren.

---

## 8. Dokumentationspflichten (Trigger-Regeln)

### Neuer Parameter / Konfigurationsoption
→ `README.md` **und** `README-DE.md` + `docs/features/` + (Beispielskript) `docs/architecture/CONFIGURATION.md`

### Neue externe Abhängigkeit (Modul, Binary, API)
→ `docs/architecture/DEPENDENCIES.md`

### Verhaltensänderung für Nutzer
→ README-Changelog (EN + DE) + `docs/CHANGELOG.md`

### STATE.md (immer nach jedem Inkrement)
1. Freitext "Letztes abgeschlossenes Inkrement: …"
2. Tabelle: neue Zeile `| I# | Titel | Datum | Commit-Hash |`

---

## 9. Quality Gates — pre-commit (Definition of Done)

Für PowerShell greifen zwei der vier Gates der Definition of Done:

```powershell
Invoke-ScriptAnalyzer -Path . -Recurse -Severity Warning              # Gate 1 — Linter (PSScriptAnalyzer)
Invoke-Pester tests/ -ExcludeTag Integration -Output Detailed          # Gate 4 — Unit-Tests (Pester, ab I2)
Invoke-Pester tests/ -TagFilter Integration -Output Detailed           # Integrationstests gegen lokale Everything-Instanz (ab I5)
```

Gate 2 (Formatter) und Gate 3 (statische Typanalyse) haben in PowerShell kein
eigenständiges Standard-Werkzeug; PSScriptAnalyzer-Regeln decken Stilfragen mit ab.

**Gate 1 im Bestand:** Die Init-Messung (`docs/CHANGELOG.md` I1) enthält Altbefunde. Bis zu deren Abbau gilt:
**keine neuen Befunde** in geänderten Dateien. Bewusst akzeptiert (kein Stopp):

| Regel | Fundstelle | Grund |
|---|---|---|
| `PSUseSingularNouns` | `Find-Files` (öffentliche API) | Umbenennen bräche Nutzer |
| `PSUseDeclaredVarsMoreThanAssignments` | `Examples/*.config.example.ps1` | Variablen werden vom Skript nach Dot-Sourcing gelesen (entfällt mit I3) |
| `PSReviewUnusedParameter` | `-SmtpCredential` im Beispielskript | Fehlalarm: im Skript-Scope von `Send-CleanupMail` genutzt |
| `TypeNotFound` (Information) | `Everything3-PowerShell-Wrapper.psm1` | Typ entsteht erst zur Laufzeit per `Add-Type` |

Ein `tools/git-hooks/pre-commit.local` mit diesen Gates ist möglich (der Interna-Hook ruft es auf,
`docs/CONVENTIONS_COMMON.md` 3.1), wird aber erst mit dem Pester-Harness (I2) sinnvoll.
