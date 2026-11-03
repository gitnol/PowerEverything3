# Lessons Learned – PowerEverything3

Strukturierter Index für gelernte Patterns. Jeder Eintrag benennt Scope und
Backport-Ziel, damit die Reflexions-Phase (REFLECTION.md Schritt 3) offene
generische Patterns als Backport-Vorschlag melden kann; eingespielt wird erst nach Freigabe
des Prompters (REFLECTION.md Schritt 3, Freigabe-Disziplin).

Neue Einträge entstehen aus dem „Lessons Learned"-Abschnitt der `CHANGELOG.md` —
dort kurze Beschreibung, hier der strukturierte Steckbrief.

---

## L1: PowerShell-Klassen mit Add-Type-Typen aus einem NestedModule nur über das Manifest importierbar
- Inkrement: I1
- Scope: generisch-stack
- Backport-Ziel: `stacks/powershell-automation/CONVENTIONS.md` §3 (Dateiorganisation)
- Status: offen

Referenziert eine `class` im RootModule einen per `Add-Type` erzeugten Typ, muss dieser Typ beim Parsen des RootModule
schon existieren; das garantiert nur `NestedModules` in der `.psd1`. Ein direkter `Import-Module …psm1` scheitert mit
`TypeNotFound` — Doku und Beispiele müssen daher immer die `.psd1` importieren (hier beim Init reproduziert, KNOWN_ISSUES K1).

---

## L2: Eine Hilfsfunktion namens wie ein PowerShell-Alias (`Rd`, `ls`, `cat`, `gc`) führt den Alias aus
- Inkrement: I9
- Scope: generisch-stack
- Backport-Ziel: `stacks/powershell-automation/CONVENTIONS.md` §2 (PowerShell Code-Richtlinien)
- Status: offen

Aliase haben in PowerShell Vorrang vor Funktionen gleichen Namens. Eine Hilfsfunktion `Rd` (Datei lesen) rief deshalb
`Remove-Item` auf und löschte `docs/TODO.md` (aus Git wiederhergestellt). Hilfsfunktionen nie wie Aliase benennen
(`Get-Alias <Name>` vor dem Anlegen prüfen) und vor Skripten, die Dateien umschreiben, `git status` sauber halten.
Nur ein Vorfall — Vorschlag, kein Beschluss.

---

## L3: `$env:TEMP` kann ein 8.3-Kurzname sein; Everything (und jeder Pfadvergleich) kennt nur den Langpfad
- Inkrement: I9
- Scope: projekt-spezifisch
- Backport-Ziel: —
- Status: projekt-intern

Die Fixture-Suche unter `C:\Users\VORNAM~1.NAC\...` lieferte 0 Treffer, bis der Pfad per `GetLongPathNameW` aufgelöst wurde
(`tests/Integration/FindFiles.Extensions.Integration.Tests.ps1`). Zu eng an Everything gebunden und ein einzelner Befund — kein
Backport-Kandidat; gilt im Projekt weiter.

---
## Pflege

- Neuer „Lessons Learned"-Block im `CHANGELOG.md` → Eintrag `## L<N>:` hier anlegen.
- Mehrere Patterns aus einem Inkrement → mehrere `## L<N>:`-Einträge.
- Scope-Werte:
  - `projekt-spezifisch` — nur für dieses Projekt relevant, kein Backport nötig.
  - `generisch-stack` — gehört in `docs_template/stacks/<stack>/CONVENTIONS.md` o.ä.
  - `generisch-base` — gehört in `docs_template/base/` (Prinzip, Basis-Convention, MANIFEST).
- Status `offen` → wird bei der nächsten Reflexion (REFLECTION.md Schritt 3) als Backport-Vorschlag gemeldet;
  bleibt `offen` bis zur Freigabe.
- Status `backported vN@<commit>` → Backport-Commit ins Template-Repo durchgeführt (Template-Stand
  Version + Commit, z. B. `v26@0a4c8f1`); der Tag `vN` folgt erst nach dem Pre-Tag-Gate (REFLECTION.md Schritt 3b).
- Status `projekt-intern` → Endzustand für `Scope: projekt-spezifisch` (kein Backport vorgesehen; die Lesson gilt
  im Projekt weiter). Wird in der Reflexion nicht als Backport-Kandidat gemeldet.
- Niemals Patterns löschen, auch wenn überholt — `Status: verworfen (<grund>)` setzen.
- Diese Datei steht in der Trigger-Matrix in `KICKOFF.md` Phase 3a.
