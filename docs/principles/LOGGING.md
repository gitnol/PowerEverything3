# Logging Strategy

## Regel

Logs sind das einzige Fenster in den Systemzustand eines laufenden Prozesses.
Jeder Log-Eintrag muss ohne Kontextwissen verständlich und filterbar sein.

## Konkrete Vorgaben

- **Level DEBUG:** Detaillierter Datenfluss (z.B. "Datei X gelesen, Hash: Y")
- **Level INFO:** Fachliche Meilensteine (z.B. "Dokument X erfolgreich verarbeitet")
- **Level WARNING:** Erwartete, aber behandelte Probleme (z.B. "Service Timeout, Versuch 1/3")
- **Level ERROR:** Unerwartete Fehler – muss zwingend den Stacktrace enthalten (z. B. Python `exc_info=True`,
  .NET `LogError(ex, …)`)
- **Kontext:** Jeder Eintrag muss IDs, Dateinamen oder Bezeichner enthalten.
  "Verarbeitung fehlgeschlagen" ist verboten.
  "Verarbeitung für Datei 'X.pdf' fehlgeschlagen" ist korrekt.
- Konsolenausgaben über `print()` sind für interaktive CLI-Tools akzeptabel.
  Bei automatisiertem Betrieb (Scheduler, Service) muss das Logging-Framework verwendet werden.

## Verwandt

- [[FAIL_FAST]]
- [[UNTRUSTED_DOCUMENT_CONTENT]]

## Projektspezifisch

<!-- Hier beim Befüllen ersetzen. Maßgeblich für die Update-Klassifizierung ist
     der Vergleich gegen die alte Template-Version (ALTES_PROJECT_AKTUALISIEREN.md,
     Schritt 2c/3): LOGGING.md ist konstruktionsbedingt immer Kategorie C. -->


- **Mechanismus:** Modul nur PowerShell-Streams (`Write-Verbose` für Ablauf, `Write-Warning` für Property-Fehler und
  unbekannte Properties); kein Logging-Framework, kein Event Log. `Test-EverythingConnection` nutzt bewusst `Write-Host`
  (interaktive Diagnose). Beispielskript: eigene Funktion `Write-Log` (Zeitstempel + farbige `Write-Host`-Ausgabe,
  Stufen `Info`/`Highlight`/`Action`/`Notice`), Warnungen per `Write-Warning`, Fortschritt per `Write-Progress`.
- **Debug-Modus:** `-Verbose` (Modul: Ladeschritte, DLL-Pfad, Suchparameter als JSON in `Find-Files`, Trefferzahlen).
  Das Beispielskript hat zusätzlich den fachlichen „Debug-Modus" für Mails (ohne `-Live` alles an `$DebugTo`) — das ist
  kein Log-Level (`docs/GLOSSARY.md`).
- **Nicht loggen:** Inhalte von `[PSCredential]`; keine Dateiinhalte. Personenbezogene Daten (Besitzername, Mail-Adresse)
  stehen fachlich bedingt in Transcript und CSV — deshalb gelten für diese Dateien die Regeln aus
  `docs/security/DATA_HANDLING.md` (Ablage, Löschung).
- **Ziel:** Modul → Aufrufer-Konsole/Streams. Beispielskript → Konsole **und** vollständiges Transcript
  (`Start-Transcript`) als `archives_with_extracted_folder_<Zeitstempel>.log` in `-OutputPath`.
