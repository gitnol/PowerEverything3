---
name: everything-search
description: Fast file and folder search on Windows through the index of Everything 1.5 (voidtools) using the PowerEverything3 PowerShell module, instead of Get-ChildItem -Recurse. Use whenever files or folders have to be found, counted or analysed by name, extension, size, date or path on local drives - "where is the file", "find all PDFs", "largest files on D:", "what changed last week", duplicates, disk clean-up analysis - or when the user mentions Everything, voidtools or the Everything SDK, or wants a PowerShell script that uses Everything as a fast search source.
---

# Everything search (PowerEverything3)

Everything reads the NTFS index (MFT/USN) and answers searches over millions of files in milliseconds.
Prefer it over a recursive file system scan on local NTFS drives. The module `PowerEverything3` wraps the
Everything SDK3 (`Everything3_x64.dll`) and is read-only: it only searches, it never changes files.

## Requirements

- Windows x64, PowerShell 7+, Everything **1.5** (not 1.4) installed and **running in the same Windows session**.
  The vendor changelog for 1.5.0.1424b lists "IPC connections only accepted from clients in the same session", so
  a scheduled task without a logged-on session cannot reach Everything. Plan a fallback (file system scan).
- Import the module **only through the manifest** (`.psd1`). Importing the `.psm1` directly fails with
  "Unable to find type [Everything3SDK]" (`docs/KNOWN_ISSUES.md` K1).

## Quick start

```powershell
Import-Module <path-to-repo>\Everything3-PowerShell-Wrapper.psd1
Test-EverythingConnection        # is Everything reachable?

$client = Connect-Everything
try {
    Search-Everything -Client $client -Query 'file: ext:zip;7z size:>100mb "D:\Data\"' `
        -MaxResults 0 -Properties Size, DateModified
}
finally { Disconnect-Everything -Client $client }   # always release the native handles
```

- `-MaxResults 0` returns **all** hits (default of `Find-Files` is 1000). All hits are collected in memory first
  (`docs/KNOWN_ISSUES.md` K5): count first, then narrow the query or page with `-Offset`.
- Result objects have `FullPath`, `Name`, `Directory`; with `-Properties` the values are in `.Properties['Size']`
  (`$null` when unknown, e.g. folders). Available: `Name, Path, FullPath, Size, DateCreated, DateModified,
  DateAccessed, Attributes, Type, Extension`. `Exists` is only filled with `-CheckExists` (a `Test-Path` per hit is slow).
- `Find-Files -Pattern '*' -Extensions pdf, docx` is the short form for extension searches (leading dots are accepted).
  **Needs commit 2f78893 or newer**: before that it built `(ext:a|ext:b)` and returned nothing.
- Always `Disconnect-Everything` in `finally`. Do not call `[Everything3SDK]` directly from your own scripts.

## Search syntax - verified pitfalls

These were measured against Everything 1.5.0.1423b with SDK 3.0.1.12 (test:
`tests/Integration/FindFiles.Extensions.Integration.Tests.ps1`; the short reference below was also checked case by case on 2026-11-03).

| Write | Do not write | Why |
|---|---|---|
| `ext:pdf;docx` | `ext:pdf\|docx` | `\|` is OR: this means "`ext:pdf` OR name contains `docx`" and returns false hits such as `docxlist.xml` |
| `ext:pdf\|ext:docx` or `<ext:pdf\|ext:docx>` | `(ext:pdf\|ext:docx)` | Round brackets do **not** group: `* (ext:pdf)` returns 0 hits. Grouping is `< >` |
| a **long** path in `"D:\Folder\"` | the 8.3 short path | Everything indexes long paths: `$env:TEMP` may be a short name (`C:\Users\NAME~1.X\...`), a search for it finds nothing. Resolve with `GetLongPathNameW` first |

Short reference: `a b` AND, `a|b` OR, `!a` NOT, `< >` grouping, `"D:\Dir\"` path below the folder (trailing `\`),
`file:` / `folder:`, `ext:zip;7z`, `size:>100mb`, `dm:last7days` (modified; `dc:` created), `parent:"D:\Dir"`
(direct children), `wfn:Name.txt` (whole name), `*.log` wildcards, `regex:...`, `dupe:size`, `empty:`.

## Checks before relying on a result

- Index coverage: Everything only knows the drives and folders configured in Everything (usually local NTFS).
  Network drives and UNC paths are normally missing. Count the folder itself without trailing backslash:
  `Search-Everything -Client $c -Query '"D:\Data"' -MaxResults 0` - 0 hits means not indexed, then fall back to
  `Get-ChildItem` and say so. With a trailing backslash an empty folder also gives 0 (measured: empty folder -> 1 without,
  0 with `\`).
- Results are the index state (USN-current, normally seconds). Confirm with `Test-Path` before deleting or moving anything.
- Everything also lists hidden and system files; exclude the recycle bin with `!"\$RECYCLE.BIN\"` if needed.

## Testing scripts that use the module

Integration tests write only into their own fixture folder under `$env:TEMP` (resolved to the long path),
wait until Everything has indexed it, and compare the result with the file system as oracle.
See `docs/testing/INTEGRATION_TESTS.md` and the example test above. Run: `Invoke-Pester tests/Integration -TagFilter Integration`.
