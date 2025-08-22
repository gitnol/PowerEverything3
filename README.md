# Everything3 PowerShell Wrapper

A powerful and user-friendly PowerShell wrapper for the [Everything Search Engine](https://www.voidtools.com/) (Version 1.5+). This module utilizes the `Everything3_x64.dll` from the Everything SDK to enable extremely fast file searches directly from the PowerShell console.

Tested with:
- PowerShell 7.5.2
- Everything 1.5.0.1396a-x64
  - Website: https://www.voidtools.com/everything-1.5a/
  - Download: https://www.voidtools.com/Everything-1.5.0.1396a.x64-Setup.exe 
  - Size: (1703 KB - SHA256: 37f8f9359346b78a5e9820b5bae73044366a299eaaeba2d8a56fadf46bcc577e)
- SDK Version 3.0.0.4 
  - Website: https://www.voidtools.com/forum/viewtopic.php?t=15853
  - Download: https://www.voidtools.com/Everything-SDK-3.0.0.4.zip 
  - Size: (216 KB - SHA256: 48d76d7e90b2a3ea8f6db7626f27bd8f001e3163c826dae5de979430b226e62d) 
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
  - [VSCode Considerations](#vscode-considerations)
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

- **PowerShell 5.1** or higher. **PowerShell 7.5.2** or higher is recommended
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

---

## VSCode Considerations

The module includes automatic workarounds for VSCode-specific issues when loading native DLLs:

- **Automatic DLL Loading:** The `Everything3_x64.dll` is explicitly loaded via `Kernel32::LoadLibrary()`
- **PATH Handling:** The module directory is automatically added to the PATH
- **Error Handling:** Robust handling of VSCode-specific parameter binding issues

These measures ensure that the module functions correctly in both the regular PowerShell console and VSCode.

---

## License & Disclaimer

[MIT](https://github.com/gitnol/PowerEverything3/blob/main/LICENSE)

This project is provided without any warranty. Use at your own risk.

This project is not affiliated with VoidTools. All trademarks belong to their respective owners. This is a pure research and development project.