Write-Verbose "=== DEBUG: Everything3SDK.psm1 wird geladen von: $PSCommandPath ==="
Write-Verbose "PSScriptRoot: $PSScriptRoot"

$ModulePath = $PSScriptRoot
$DllPath = Join-Path $ModulePath "Everything3_x64.dll"
Write-Verbose "DLL-Pfad: $DllPath"
Write-Verbose "DLL existiert: $(Test-Path $DllPath)"

# Modul-Pfad zu PATH hinzufügen für DLL-Loading
$env:PATH = "$ModulePath;$env:PATH"
Write-Verbose "Modul-Pfad zu PATH hinzugefügt"

#region P/Invoke Definitions

# Korrigierte C# Wrapper-Klasse für Everything3 SDK
$Everything3Type = @"
using System;
using System.Runtime.InteropServices;
using System.Text;

public static class Everything3SDK
{
    // Client connection functions
    [DllImport("Everything3_x64.dll", CharSet = CharSet.Unicode, CallingConvention = CallingConvention.StdCall)]
    public static extern IntPtr Everything3_ConnectW(string instanceName);

    [DllImport("Everything3_x64.dll", CallingConvention = CallingConvention.StdCall)]
    public static extern bool Everything3_DestroyClient(IntPtr client);

    // Search state functions
    [DllImport("Everything3_x64.dll", CallingConvention = CallingConvention.StdCall)]
    public static extern IntPtr Everything3_CreateSearchState();

    [DllImport("Everything3_x64.dll", CallingConvention = CallingConvention.StdCall)]
    public static extern bool Everything3_DestroySearchState(IntPtr searchState);

    [DllImport("Everything3_x64.dll", CharSet = CharSet.Unicode, CallingConvention = CallingConvention.StdCall)]
    public static extern bool Everything3_SetSearchTextW(IntPtr searchState, string searchText);

    [DllImport("Everything3_x64.dll", CallingConvention = CallingConvention.StdCall)]
    public static extern bool Everything3_SetSearchViewportOffset(IntPtr searchState, uint offset);

    [DllImport("Everything3_x64.dll", CallingConvention = CallingConvention.StdCall)]
    public static extern bool Everything3_SetSearchViewportCount(IntPtr searchState, uint count);

    [DllImport("Everything3_x64.dll", CallingConvention = CallingConvention.StdCall)]
    public static extern bool Everything3_SetSearchMatchCase(IntPtr searchState, bool matchCase);

    [DllImport("Everything3_x64.dll", CallingConvention = CallingConvention.StdCall)]
    public static extern bool Everything3_SetSearchMatchWholeWords(IntPtr searchState, bool matchWholeWords);

    [DllImport("Everything3_x64.dll", CallingConvention = CallingConvention.StdCall)]
    public static extern bool Everything3_SetSearchMatchPath(IntPtr searchState, bool matchPath);

    [DllImport("Everything3_x64.dll", CallingConvention = CallingConvention.StdCall)]
    public static extern bool Everything3_SetSearchRegex(IntPtr searchState, bool regex);

    // Search execution
    [DllImport("Everything3_x64.dll", CallingConvention = CallingConvention.StdCall)]
    public static extern IntPtr Everything3_Search(IntPtr client, IntPtr searchState);

    [DllImport("Everything3_x64.dll", CallingConvention = CallingConvention.StdCall)]
    public static extern bool Everything3_DestroyResultList(IntPtr resultList);

    // Result retrieval
    [DllImport("Everything3_x64.dll", CallingConvention = CallingConvention.StdCall)]
    public static extern uint Everything3_GetResultListViewportCount(IntPtr resultList);

    [DllImport("Everything3_x64.dll", CallingConvention = CallingConvention.StdCall)]
    public static extern uint Everything3_GetResultListCount(IntPtr resultList);

    [DllImport("Everything3_x64.dll", CharSet = CharSet.Unicode, CallingConvention = CallingConvention.StdCall)]
    public static extern uint Everything3_GetResultFullPathNameW(IntPtr resultList, uint index, StringBuilder fileName, uint fileNameSize);

    [DllImport("Everything3_x64.dll", CharSet = CharSet.Unicode, CallingConvention = CallingConvention.StdCall)]
    public static extern uint Everything3_GetResultNameW(IntPtr resultList, uint index, StringBuilder fileName, uint fileNameSize);

    // Property requests
    [DllImport("Everything3_x64.dll", CallingConvention = CallingConvention.StdCall)]
    public static extern bool Everything3_AddSearchPropertyRequest(IntPtr searchState, uint propertyId);

    [DllImport("Everything3_x64.dll", CallingConvention = CallingConvention.StdCall)]
    public static extern uint Everything3_GetResultPropertyTextW(IntPtr resultList, uint index, uint propertyId, StringBuilder buffer, uint bufferSize);

    [DllImport("Everything3_x64.dll", CallingConvention = CallingConvention.StdCall)]
    public static extern ulong Everything3_GetResultPropertyUINT64(IntPtr resultList, uint index, uint propertyId);

    [DllImport("Everything3_x64.dll", CallingConvention = CallingConvention.StdCall)]
    public static extern uint Everything3_GetResultPropertyDWORD(IntPtr resultList, uint index, uint propertyId);

    // Sort functions
    [DllImport("Everything3_x64.dll", CallingConvention = CallingConvention.StdCall)]
    public static extern bool Everything3_AddSearchSort(IntPtr searchState, uint propertyId, bool ascending);

    // Error handling
    [DllImport("Everything3_x64.dll", CallingConvention = CallingConvention.StdCall)]
    public static extern uint Everything3_GetLastError();

    // Version info
    [DllImport("Everything3_x64.dll", CallingConvention = CallingConvention.StdCall)]
    public static extern uint Everything3_GetMajorVersion(IntPtr client);

    [DllImport("Everything3_x64.dll", CallingConvention = CallingConvention.StdCall)]
    public static extern uint Everything3_GetMinorVersion(IntPtr client);

    // DB Status
    [DllImport("Everything3_x64.dll", CallingConvention = CallingConvention.StdCall)]
    public static extern bool Everything3_IsDBLoaded(IntPtr client);
}

public static class Everything3Properties
{
    public const uint EVERYTHING3_PROPERTY_ID_NAME = 0;
    public const uint EVERYTHING3_PROPERTY_ID_PATH = 1;
    public const uint EVERYTHING3_PROPERTY_ID_SIZE = 2;
    public const uint EVERYTHING3_PROPERTY_ID_EXTENSION = 3;
    public const uint EVERYTHING3_PROPERTY_ID_TYPE = 4;
    public const uint EVERYTHING3_PROPERTY_ID_DATE_MODIFIED = 5;
    public const uint EVERYTHING3_PROPERTY_ID_DATE_CREATED = 6;
    public const uint EVERYTHING3_PROPERTY_ID_DATE_ACCESSED = 7;
    public const uint EVERYTHING3_PROPERTY_ID_ATTRIBUTES = 8;
    public const uint EVERYTHING3_PROPERTY_ID_FULL_PATH = 240;
}
"@

$typeExists = $null -ne ([System.Management.Automation.PSTypeName]'Everything3SDK').Type
Write-Verbose "Everything3SDK Type bereits geladen: $typeExists"

$typeExists = $null -ne ([System.Management.Automation.PSTypeName]'Everything3SDK').Type
Write-Verbose "Everything3SDK Type bereits geladen: $typeExists"

if (-not $typeExists) {
    try {

        Write-Host "Lade native DLL explizit: $DllPath" -ForegroundColor Yellow
        
        # Kernel32 LoadLibrary P/Invoke definieren
        $Kernel32Type = @"
using System;
using System.Runtime.InteropServices;

public static class Kernel32
{
    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern IntPtr LoadLibrary(string lpFileName);
    
    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern bool FreeLibrary(IntPtr hModule);
}
"@

        # Kernel32 Type laden falls noch nicht vorhanden
        if (-not ([System.Management.Automation.PSTypeName]'Kernel32').Type) {
            Add-Type -TypeDefinition $Kernel32Type
        }
        
        # DLL laden (Weil in VSCode es ansonsten nicht funktioniert)
        $hModule = [Kernel32]::LoadLibrary($DllPath)
        if ($hModule -eq [IntPtr]::Zero) {
            throw "Fehler beim Laden der nativen DLL: $DllPath"
        }
        Write-Verbose "Native DLL erfolgreich geladen, Handle: $hModule"

        Add-Type -TypeDefinition $Everything3Type -ErrorAction Stop
        Write-Verbose "Everything3SDK Types über temporäre Datei geladen"
    }
    finally {
        Write-Verbose "Finishe: Alles geladen, DLL Handle: $hModule"
    }
}

#endregion