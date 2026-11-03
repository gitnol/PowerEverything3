# Bekannte Probleme – PowerEverything3

Bugs, Quirks und Einschränkungen, die **nicht** akut behoben werden, aber
dokumentiert sein müssen, damit niemand zweimal darüber stolpert.

**Abgrenzung:**

- `TODO.md` = Arbeit, die in einem priorisierten Inkrement aufgeräumt wird
- `KNOWN_ISSUES.md` = bekannt, akzeptiert oder verschoben; mit Workaround
- `BACKLOG.md` = noch unpriorisierte Ideen, keine konkreten Probleme

---

## Aktive Probleme

| # | Beschreibung | Reproduktion | Workaround | Akzeptanzgrund | Geplant für |
|---|---|---|---|---|---|
| K1 | Direkter Import der `.psm1` scheitert mit „Unable to find type [Everything3SDK]" — die Klassen des RootModule brauchen den `Add-Type`-Typ aus dem NestedModule. Der Kopf von `Everything3-Examples.ps1` (Zeile 6) empfiehlt genau diesen Import. | `Import-Module .\Everything3-PowerShell-Wrapper.psm1` in frischer `pwsh`-Sitzung (beim Init reproduziert) | `Import-Module .\Everything3-PowerShell-Wrapper.psd1` (wie README Quick Start) | Doku-Fehler in einer Beispieldatei, Modul selbst korrekt | `TODO.md` Niedrige Priorität |
| K2 | Modul-Import verändert prozessweit `$env:PATH` (Modulverzeichnis vorangestellt), auch nach `Remove-Module`; jeder erneute Import (`-Force`, wie im Beispielskript) stellt es erneut voran. Manifest deklariert keine Mindestversion → unter Windows PowerShell 5.1 Parserfehler statt klarer Meldung. | `$p=$env:PATH; Import-Module .\Everything3-PowerShell-Wrapper.psd1; Remove-Module Everything3-PowerShell-Wrapper; $env:PATH -eq $p` → `False` (beim Init reproduziert) | Modul in eigener `pwsh`-Sitzung nutzen | Wird mit Tests behoben | `I2` |
| K3 | Text-Properties (`Name`, `Path`, `Extension`, `Type`) werden in einen Puffer mit 1024 Zeichen gelesen; Verhalten des SDK bei längeren Werten (z. B. tiefe Pfade mit Long-Path-Support) ungeprüft — vermutlich abgeschnitten. `FullPath` nutzt 32768 Zeichen und ist nicht betroffen. | Treffer mit `Path` > 1023 Zeichen und `-Properties Path` abfragen | `FullPath` bzw. `Directory` des Treffers verwenden | Seltener Fall, erst mit Integrationstest belegbar | `I5` (Klärung) |
| K4 | Die Mail des Beispielskripts kündigt an, sie komme „automatisch, bis die Einträge bereinigt sind"; das Repository enthält aber keine Zeitplanung (kein Task-Scheduler-Setup). | `New-MailBody` im Beispielskript lesen | Betreiber richtet eine eigene geplante Aufgabe ein oder passt den Mailtext an | Betriebsentscheidung des Betreibers, nicht Teil des Beispiels | offen |
| K5 | `Search-Everything -MaxResults 0` sammelt alle Treffer im Speicher, bevor etwas zurückkommt. | `Search-Everything -Client $c -Query '*' -MaxResults 0` auf einem großen Index | Abfrage eingrenzen oder mit `-Offset`/`-MaxResults` blättern | Für die Zielanwendungen ausreichend | `BACKLOG.md` (Pipeline-Ausgabe) |
| K6 | Aus einer anderen Windows-Sitzung als Everything (z. B. geplante Aufgabe als SYSTEM ohne Anmeldung, Dienst): `Connect-Everything` meldet Erfolg, die erste Suche scheitert mit „Suche fehlgeschlagen mit Fehler: 3758096387“ (0xE0000003, DISCONNECTED). Die Meldung nennt weder Ursache noch Sitzungsbindung (Everything ab 1.5.0.1424b). | Aufgabe als SYSTEM anlegen, `Connect-Everything` + `Search-Everything` ausführen (2026-11-03 gemessen, eine Messung, nur Sitzung 0) | Skript in einer Sitzung des Benutzers laufen lassen oder Dateisystem-Fallback (`-SearchMode Scan` im Beispielskript) | Hersteller-Verhalten; verständlichere Meldung steht im Backlog | `BACKLOG.md` |

---

## Behobene Probleme

Letzte Einträge behalten bis zur nächsten Aufräum-Iteration (Spur für
Lessons Learned). Danach archivieren oder löschen.

| # | Beschreibung | Behoben in | Commit |
|---|---|---|---|
| (noch keine Einträge) | | | |

---

## Pflege

- Neuer Bug ohne sofortigen Fix → Eintrag hier; TODO-Punkt **nur**, wenn
  priorisiert wird.
- Eintrag wird behoben → in „Behobene Probleme" verschieben, in der nächsten
  Aufräum-Iteration löschen.
- Diese Datei steht in der Trigger-Matrix in `KICKOFF.md` Phase 3a.
