# Everything3 PowerShell Wrapper

[German Translation / Deutsche Übersetzung](README-DE.md)

A powerful and user-friendly PowerShell wrapper for the [Everything Search Engine](https://www.voidtools.com/) (Version 1.5+). This module utilizes the `Everything3_x64.dll` from the Everything SDK to enable extremely fast file searches directly from the PowerShell console.

Tested with:
- PowerShell 7.5.2 and 7.6
- Everything 1.5.0.1423b-x64 (previously 1.5.0.1396a)
  - Website: https://www.voidtools.com/everything-1.5a/
  - Changelog: https://www.voidtools.com/forum/viewtopic.php?f=12&t=9787
- SDK Version 3.0.0.9 (included `Everything3_x64.dll`, signed by voidtools PTY LTD)
  - Website: https://www.voidtools.com/forum/viewtopic.php?t=15853
  - Download: https://www.voidtools.com/Everything-SDK-3.0.0.9.zip
  - Size: (503 KB - SHA256: 124685d35a5f49f3c1e9898853e166215748c893782c6a251f5dde58dacad4fa)
  - GitHub: https://github.com/voidtools/everything_sdk3

## Table of Contents

- [Everything3 PowerShell Wrapper](#everything3-powershell-wrapper)
  - [Table of Contents](#table-of-contents)
  - [Features](#features)
  - [Requirements](#requirements)
  - [Quick Start](#quick-start)
  - [Functions](#functions)
  - [Usage Examples](#usage-examples)
    - [Simple Searches with `Find-Files`](#simple-searches-with-find-files)
    - [Advanced Searches with `Search-Everything`](#advanced-searches-with-search-everything)
    - [All Results and Existence Check](#all-results-and-existence-check)
  - [Practical Example: Archives Left Next to Their Extracted Folder](#practical-example-archives-left-next-to-their-extracted-folder)
  - [VSCode Considerations](#vscode-considerations)
  - [Changelog](#changelog)
  - [License \& Disclaimer](#license--disclaimer)

---

## Features

- **Fast Connection:** Easy connection and disconnection from the Everything instance
- **Powerful Search:** Support for complex queries, regex, case sensitivity, and more
- **Property Retrieval:** Retrieve metadata such as size, creation date, and attributes
- **Simple Handling:** Convenient wrapper function `Find-Files` for everyday searches
- **Connection Testing:** Built-in function to test connection and display diagnostic information
- **VSCode Compatibility:** Automatic handling of VSCode-specific DLL loading issues

---

## Requirements

- **PowerShell 7.0** or higher (the module uses PowerShell 7 syntax such as `??`; Windows PowerShell 5.1 is not supported). **PowerShell 7.5** or higher is recommended
- **[Everything](https://www.voidtools.com/downloads/) v1.5a** or newer must be installed and running
- The **`Everything3_x64.dll`** (from the official [Everything SDK](https://www.voidtools.com/support/everything/sdk/)) must be located in the same directory as the module

---

## Quick Start

1. **Clone the repository:**
   ```sh
   git clone https://github.com/gitnol/PowerEverything3.git
   ```

2. **Import the module** into your PowerShell session:
   ```powershell
   Import-Module .\Everything3-PowerShell-Wrapper.psd1 -Verbose
   ```

3. **Test the connection:**
   ```powershell
   Test-EverythingConnection
   ```

4. **Find files:**
   ```powershell
   Find-Files -Pattern "*.pdf" -MaxResults 10
   ```

---

## Functions

| Function                    | Description                                                                    |
|:---------------------------|:-------------------------------------------------------------------------------|
| `Find-Files`               | A simple wrapper function for quick file searches                             |
| `Search-Everything`        | Performs detailed searches with all available options                         |
| `Connect-Everything`       | Establishes a connection to the Everything client                             |
| `Disconnect-Everything`    | Disconnects from the Everything client                                        |
| `Test-EverythingConnection`| Verifies the connection to the Everything instance and displays status information |

---

## Usage Examples

### Simple Searches with `Find-Files`

**Search for PDF and DOCX files:**
```powershell
Find-Files -Pattern "*" -Extensions @("pdf", "docx") -MaxResults 10
```

**Search for files with properties (size, date):**
```powershell
Find-Files -Pattern "invoice*" -IncludeProperties -MaxResults 5
```

**Regex search for image files with date pattern:**
```powershell
Find-Files -Pattern "regex:^\d{4}-\d{2}-\d{2}.*\.(jpg|png)$" -Verbose -MaxResults 10
# or
Find-Files -Pattern '^\d{4}-\d{2}-\d{2}.*\.(jpg|png)$' -Regex -Verbose -MaxResults 10
```

### Advanced Searches with `Search-Everything`

**Find the 5 largest files over 100 MB and sort by size:**
```powershell
# Manually establish connection
$client = Connect-Everything

# Execute search and sort by size in descending order
Search-Everything -Client $client -Query "size:>100mb" -MaxResults 5 -Properties "Size" -SortBy @{Property = "Size"; Descending = $true}

# Disconnect
Disconnect-Everything -Client $client
```

**Find all files modified in the last 7 days:**
```powershell
$client = Connect-Everything
Search-Everything -Client $client -Query "dm:last7days" -MaxResults 10 -Properties "DateModified"
Disconnect-Everything -Client $client
```

**Find empty files:**
```powershell
Find-Files -Pattern "size:0" -MaxResults 20
```

### All Results and Existence Check

`-MaxResults 0` returns **all** results. The `Exists` property is only filled when `-CheckExists` is set – a `Test-Path` per result is expensive (Everything results come from the index and are usually current anyway).

```powershell
$client = Connect-Everything

# all ZIP files larger than 100 MB below a folder, with size and modification date
$zips = Search-Everything -Client $client -Query 'file: ext:zip size:>100mb "D:\Data\"' -MaxResults 0 -Properties Size, DateModified
$zips | Select-Object FullPath, @{ n = 'SizeMB'; e = { [math]::Round($_.Properties['Size'] / 1MB) } }

# paging: results 101-200, sorted by name
Search-Everything -Client $client -Query 'ext:pdf' -Offset 100 -MaxResults 100 -SortBy @{ Property = 'Name' }

# verify that each result still exists on disk (slower)
Search-Everything -Client $client -Query 'ext:iso' -MaxResults 50 -CheckExists | Where-Object { -not $_.Exists }

Disconnect-Everything -Client $client
```

Text properties (`Name`, `Path`, `Extension`, `Type`) are returned as full strings. `Size` is `$null` when Everything does not know it (e.g. folders).

---

## Practical Example: Archives Left Next to Their Extracted Folder

[`Examples/Find-ArchivesWithExtractedFolder.ps1`](Examples/Find-ArchivesWithExtractedFolder.ps1) is a complete file-server clean-up script built on this module. It finds archives (`zip`, `7z`, `rar`, `iso`, `tar.gz`, …) for which a folder with the same name already exists in the same location – i.e. archives that were extracted and then kept.

- Searches via the Everything index in seconds; falls back to a parallel file-system scan if Everything is not available or a path is not indexed
- `-AllShares` searches all data shares of the server (skips system shares, DFS roots and nested shares)
- Resolves the owners of the extracted folders via ADSI/LDAP (no ActiveDirectory module/RSAT needed)
- Writes a CSV and optionally sends one mail per owner; paths in mails are converted to `\\server\share\...`
- Owners that cannot be mailed (deleted/disabled accounts, no mail address, BUILTIN\Administrators) end up in one summary mail to the helpdesk
- **Content check:** compares every archive with its extracted folder and tells whether the archive is a redundant copy (`identical` – it can be deleted) or the folder has been worked on since (`changed`, with new/missing/changed files)
  - level 1, always on: file list, sizes and timestamps from the archive directory – nothing is extracted, takes about a second per archive
  - level 2, `-CheckContentCrc`: additionally compares the CRC32 of every file (reads all files – slow, only on request)
  - ZIP is always checked; 7z, rar, iso, tar.gz etc. only if `7z.exe` (+ `7z.dll`) is found (`$SevenZip`, default `%ProgramFiles%\7-Zip`), otherwise `N/A`
  - handles old ZIP file names in the DOS code page, the 1-hour daylight-saving offset of ZIP timestamps and their 2-second resolution; system files such as `Thumbs.db` are ignored
- Never deletes anything

```powershell
cd .\Examples
Copy-Item .\Find-ArchivesWithExtractedFolder.config.example.ps1 .\Find-ArchivesWithExtractedFolder.config.ps1   # then adjust

# dry run on the whole server: CSV only
.\Find-ArchivesWithExtractedFolder.ps1 -AllShares -SearchMode Everything

# test: all mails go to $DebugTo, at most 3
.\Find-ArchivesWithExtractedFolder.ps1 -AllShares -SendMail -MaxMails 3

# production: mails to the owners
.\Find-ArchivesWithExtractedFolder.ps1 -AllShares -SearchMode Everything -SendMail -Live

# your own PC: all local fixed disks, with CRC content check
.\Find-ArchivesWithExtractedFolder.ps1 -Path ((Get-CimInstance Win32_LogicalDisk -Filter 'DriveType=3').DeviceID | ForEach-Object { $_ + '\' }) -SearchMode Everything -CheckContentCrc
```

With `-SearchMode Everything`, paths that are not in the Everything index are skipped with a warning (summary at the end of phase 1); with `-SearchMode Auto` they are scanned.

Run it as administrator on the file server itself (needed for `Get-Acl` and `Get-SmbShare`). See the comment-based help (`Get-Help .\Find-ArchivesWithExtractedFolder.ps1 -Full`) for all parameters. Your real `*.config.ps1`, CSV and log files are excluded via `.gitignore`.

---

## VSCode Considerations

The module includes automatic workarounds for VSCode-specific issues when loading native DLLs:

- **Automatic DLL Loading:** The `Everything3_x64.dll` is explicitly loaded via `Kernel32::LoadLibrary()`
- **PATH Handling:** The module directory is automatically added to the PATH
- **Error Handling:** Robust handling of VSCode-specific parameter binding issues

These measures ensure that the module functions correctly in both the regular PowerShell console and VSCode.

---

## Changelog

**Archive example: content check and index fix**
- New: content check archive ↔ extracted folder (CSV columns `Content`/`ContentDetails`, column "Content" in mails); level 1 always, level 2 with `-CheckContentCrc`; formats other than ZIP via 7-Zip if available
- Fixed: an empty but indexed folder was reported as "not in the Everything index" (the index check now counts the folder itself)
- Changed: with `-SearchMode Everything` a path that is not indexed no longer aborts the whole run – it is skipped with a warning and listed at the end of phase 1

**SDK 3.0.0.9, fixes and archive example**
- Updated `Everything3_x64.dll` to SDK 3.0.0.9 (more robust pipe connection when Everything is busy, crash and memory-corruption fixes in the SDK – see the [SDK changelog](https://www.voidtools.com/forum/viewtopic.php?t=15853))
- Fixed: P/Invoke signatures used `uint` for `SIZE_T` parameters/return values (index, count, buffer size) – now `UIntPtr` (64-bit on x64), as declared in `Everything3.h`
- Fixed: text properties (`Name`, `Path`, `Extension`, `Type`) only returned their first character (`Everything3_GetResultPropertyTextW` was declared without `CharSet.Unicode`)
- Fixed: the property `Name` and sorting by `Name` were silently ignored (property ID `0` was treated as "unknown")
- Fixed: `$error` (automatic variable) was overwritten in error handling
- New: `-MaxResults 0` returns all results; `-Offset` for paging is passed correctly
- New: `-CheckExists` – `Exists` is only checked on request (`$null` otherwise). **Behaviour change:** previously `Test-Path` ran for every result
- Faster: results are collected in a list instead of `+=` (5,000 results: 6.3 s → 0.5 s)
- `Size` is `$null` instead of `18446744073709551615` when unknown (e.g. folders)
- Loading the module no longer writes to the console (messages moved to `-Verbose`)
- New example: `Examples/Find-ArchivesWithExtractedFolder.ps1`
- Requirements corrected: PowerShell 7.0+

---

## License & Disclaimer

[MIT](https://github.com/gitnol/PowerEverything3/blob/main/LICENSE)

This project is provided without any warranty. Use at your own risk.

This project is not affiliated with VoidTools. All trademarks belong to their respective owners. This is a pure research and development project.