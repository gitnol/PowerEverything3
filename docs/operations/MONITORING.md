# Monitoring & Betrieb – PowerEverything3

Das Modul ist eine interaktiv bzw. von Skripten genutzte Bibliothek ohne eigenen Betrieb. Überwacht wird nur ein
Lauf des Beispielskripts. Eine Zeitplanung liefert das Repository nicht (`docs/KNOWN_ISSUES.md` K4); plant der
Betreiber Läufe ein, gelten zusätzlich seine Regeln für geplante Aufgaben.

---

## Erfolgsindikatoren (Beispielskript)

| Indikator | Erwarteter Wert | Prüfung |
|-----------|----------------|---------|
| Exit-Code von `pwsh -File` | `0` | `$LASTEXITCODE` bzw. Ergebnis der aufrufenden Aufgabe |
| Letzte Transcript-Zeile | `Done after hh:mm:ss – hits: …, mails sent: N, failed: 0` | `Get-Content <OutputPath>\archives_with_extracted_folder_*.log -Tail 5` |
| CSV vorhanden und aktuell | Datei mit Zeitstempel des Laufs | `Get-ChildItem <OutputPath>\archives_with_extracted_folder_*.csv \| Sort-Object LastWriteTime \| Select-Object -Last 1` |
| Keine übersprungenen Pfade | keine Zeile „ATTENTION: … not in the Everything index and NOT searched" | `Select-String` im Transcript |
| Mailversand | `failed: 0` | letzte Transcript-Zeile |

---

## Exit-Codes

| Code | Bedeutung |
|------|-----------|
| `0` | Lauf vollständig (Warnungen zu einzelnen Pfaden/Mails möglich — Transcript prüfen) |
| `1` | Abbruch durch terminierenden Fehler (z. B. kein gültiger Pfad, `-SearchMode Everything` ohne Everything) |

---

## Manuelle Checks

```powershell
$log = Get-ChildItem <OutputPath>\archives_with_extracted_folder_*.log | Sort-Object LastWriteTime | Select-Object -Last 1
Get-Content $log -Tail 20
Select-String -Path $log -Pattern 'WARNING|ATTENTION|failed'
```

---

## Bekannte Warnsignale

| Signal | Mögliche Ursache | Maßnahme |
|--------|-----------------|---------|
| „Everything not usable – falling back to file-system scan" | Everything läuft nicht / Modul nicht ladbar | Everything starten; Lauf dauert sonst Stunden |
| Viele „Access error" / „Get-Acl failed" | Konto ohne ausreichende Rechte | Ausführungskonto prüfen (`docs/architecture/CREDENTIAL_STRATEGY.md`) |
| Viele „Owner SID … not found in AD" | Gelöschte Konten als Besitzer | Erwartbar; Treffer landen in der Sammelmail |
| „hits are not below any share" | Treffer außerhalb freigegebener Ordner | Mails zeigen lokale Pfade — `-ReplaceSource`/`-ReplaceTarget` nutzen |
| Phase 1c dauert ungewöhnlich lange | großes/präpariertes Archiv, `-CheckContentCrc` | ohne CRC laufen lassen; I4 (Timeout) |
