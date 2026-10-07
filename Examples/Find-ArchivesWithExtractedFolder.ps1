#Requires -Version 7.2

<#
.SYNOPSIS
	Finds archives (zip, 7z, rar, iso, tar.gz ...) that have already been extracted next to
	themselves (same-named folder exists), resolves the owners and notifies them by mail.

.DESCRIPTION
	Typical file-server clean-up: someone unpacks "Project.zip" into "Project\" and keeps both.
	This script finds such pairs and reports them – it never deletes anything.

	Workflow
	  Phase 1  Find archives via the Everything index (seconds) using the
	           Everything3-PowerShell-Wrapper module of this repository; falls back to a
	           file-system scan (parallel per top-level folder) when Everything is not usable
	           or a path is not indexed (with -SearchMode Everything such paths are skipped
	           instead). Then checks for a same-named folder.
	  Phase 1c Content check archive <-> folder (always): file list, size, timestamp; with
	           -CheckContentCrc additionally CRC32 per file. ZIP via .NET, other formats only with
	           7-Zip ($SevenZip), otherwise "content check N/A". Result: CSV columns
	           Content/ContentDetails and a "Content" column in the mail.
	  Phase 2  Owners: Get-Acl in parallel, AD lookup per unique SID via ADSI/LDAP
	           (no ActiveDirectory module / RSAT required).
	  Phase 3  CSV export (UTF-8 with BOM, opens fine in Excel).
	  Phase 4  One mail per owner (only with -SendMail; without -Live everything goes to $DebugTo).
	           Owners that cannot be mailed (unknown/deleted SID, disabled, no mail address,
	           BUILTIN\Administrators) are collected in one summary mail to $FallbackTo.

	Paths in mails are converted to UNC (\\server\share\...) using the SMB shares of the machine
	the script runs on – nested shares resolve to the outermost share.

	Configuration: defaults are in the section "Configuration (defaults)". An optional
	Find-ArchivesWithExtractedFolder.config.ps1 next to the script overrides them
	(template: Find-ArchivesWithExtractedFolder.config.example.ps1).

	Requirements: PowerShell 7.2+, Everything 1.5 (optional, for speed), domain-joined machine
	(for owner lookup), run as administrator (Get-Acl, Get-SmbShare).

.EXAMPLE
	# Dry run: CSV only, no mails
	.\Find-ArchivesWithExtractedFolder.ps1 -Path 'E:\Data\Projects'

.EXAMPLE
	# Whole server: all data shares (system shares, DFS roots and nested shares are skipped)
	.\Find-ArchivesWithExtractedFolder.ps1 -AllShares -SearchMode Everything

.EXAMPLE
	# Test mails: everything goes to $DebugTo, at most 3 mails
	.\Find-ArchivesWithExtractedFolder.ps1 -Path 'E:\Data\Projects' -SendMail -MaxMails 3

.EXAMPLE
	# Only the summary mail (owners that cannot be mailed) to $FallbackTo – users are never mailed
	.\Find-ArchivesWithExtractedFolder.ps1 -AllShares -SendMail -SummaryOnly

.EXAMPLE
	# Local fixed disks of this machine, dry run, with CRC content check
	.\Find-ArchivesWithExtractedFolder.ps1 -Path ((Get-CimInstance Win32_LogicalDisk -Filter 'DriveType=3').DeviceID | ForEach-Object { $_ + '\' }) -SearchMode Everything -CheckContentCrc

.EXAMPLE
	# Production: mails to the real owners
	.\Find-ArchivesWithExtractedFolder.ps1 -AllShares -SearchMode Everything -SendMail -Live

.EXAMPLE
	# Fixed replacement instead of the share (e.g. a drive letter); 'auto' = use the share for this source
	.\Find-ArchivesWithExtractedFolder.ps1 -Path 'E:\Data\Projects','D:\Data\Teams' -ReplaceSource 'E:\Data\Projects','D:\Data\Teams' -ReplaceTarget 'P:','auto'
#>
[CmdletBinding()]
param (
	[string[]]$Path           = @(),
	[switch]$AllShares,                            # search all data shares of this server
	[string[]]$ReplaceSource  = @(),               # optional fixed path prefixes to replace in mails
	[string[]]$ReplaceTarget  = @(),               # ... by these (pairwise); empty/'auto' -> UNC via share
	[switch]$SendMail,                             # actually send mails (default: CSV only)
	[switch]$Live,                                 # mails to the real owners (default: everything to $DebugTo)
	[switch]$SummaryOnly,                          # only the summary mail to $FallbackTo; users are never mailed
	[switch]$CheckContentCrc,                      # content check additionally via CRC32 (reads every file of the folder – slow)
	[ValidateRange(0, [int]::MaxValue)]
	[int]$MaxMails            = 0,                 # max. mails per run (0 = unlimited)
	[ValidateSet('Auto', 'Everything', 'Scan')]
	[string]$SearchMode       = 'Auto',            # Auto = Everything with fallback to scan; Everything = error instead of fallback
	[ValidateRange(0, 600)]
	[int]$LastMonths          = 0,                 # 0 = all archives; e.g. 3 = only modified in the last 3 months
	[ValidateRange(1, 64)]
	[int]$ThrottleLimit       = 8,                 # parallelism for scan and Get-Acl
	[string]$OutputPath       = $PSScriptRoot,     # CSV and transcript
	[string]$ConfigFile       = (Join-Path $PSScriptRoot 'Find-ArchivesWithExtractedFolder.config.ps1'),
	[PSCredential]$SmtpCredential = $null          # optional SMTP auth; empty = anonymous relay
)

Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

# ========================================================================
# Configuration (defaults) – overridden by the config file
# ========================================================================

$ArchivePatterns = @('*.7z', '*.zip', '*.iso', '*.rar', '*.tar', '*.tgz', '*.gz', '*.bz', '*.bz2', '*.xz', '*.s7z')

$ReportMinMB = 10                  # from this size into CSV / result
$MailMinMB   = 100                 # from this size into mails

$SmtpServer  = 'smtp.example.com'
$SmtpPort    = 25
$SmtpUseSsl  = $false              # $true if the relay offers STARTTLS with a valid certificate
$MailFrom    = 'helpdesk@example.com'
$DebugTo     = 'admin@example.com'     # receives all mails without -Live
$FallbackTo  = 'helpdesk@example.com'  # summary mail for owners that cannot be mailed
$MailSubject = 'Archives were not deleted after extraction'
$MailEncoding = [System.Text.Encoding]::UTF8

$ContactPhone = '+00 0000 0000'
$ContactEmail = 'helpdesk@example.com'

$ShareAutoMapping = $true          # paths in mails as \\server\share\...
$UncServer        = try { [System.Net.Dns]::GetHostEntry('').HostName } catch { $env:COMPUTERNAME }
$IgnoredShares    = @('print$', 'SYSVOL', 'NETLOGON', 'CertEnroll', 'REMINST', 'WsusContent', 'UpdateServicesPackages')

$EverythingModule = Join-Path $PSScriptRoot '..\Everything3-PowerShell-Wrapper.psd1'

# Content check archive <-> extracted folder (always on; ZIP via .NET, other formats only with 7-Zip)
$SevenZip      = Join-Path $env:ProgramFiles '7-Zip\7z.exe'   # portable: 7z.exe AND 7z.dll in one folder
$ContentIgnore = '(^|/)(Thumbs\.db|desktop\.ini|\.DS_Store|~\$[^/]*|[^/]*\.tmp)$|(^|/)__MACOSX/'   # regex on the relative path with '/'

if (Test-Path -LiteralPath $ConfigFile -PathType Leaf) {
	. $ConfigFile
} else {
	Write-Warning "No config file found ($ConfigFile) – using defaults."
}

# ========================================================================
# Functions
# ========================================================================

function Write-Log {
	param(
		[Parameter(Mandatory, Position = 0)][AllowEmptyString()][string]$Message,
		[ValidateSet('Info', 'Highlight', 'Action', 'Notice')][string]$Level = 'Info'
	)
	$text = '{0:HH:mm:ss}  {1}' -f (Get-Date), $Message
	switch ($Level) {
		'Info'      { Write-Host $text }
		'Highlight' { Write-Host $text -ForegroundColor Black -BackgroundColor Yellow }
		'Action'    { Write-Host $text -ForegroundColor Red }
		'Notice'    { Write-Host $text -ForegroundColor Cyan }
	}
}

# Resolves an owner SID to {SamAccountName, Name, EmailAddress, Status} via ADSI/LDAP.
# Status: OK | Disabled | NoMail | Group | BuiltinAdmin | Unknown
function Resolve-Owner([string]$sid) {
	$r = [ordered]@{ SamAccountName = 'unknown'; Name = 'unknown'; EmailAddress = ''; Status = 'Unknown'; Sid = $sid }
	if ([string]::IsNullOrEmpty($sid)) { return [PSCustomObject]$r }

	if ($sid -eq 'S-1-5-32-544') {   # BUILTIN\Administrators
		$r.SamAccountName = 'BUILTIN\Administrators'; $r.Name = 'BUILTIN\Administrators'; $r.Status = 'BuiltinAdmin'
		return [PSCustomObject]$r
	}

	try {
		$entry = [System.DirectoryServices.DirectoryEntry]::new("LDAP://<SID=$sid>")
		$entry.RefreshCache([string[]]@('sAMAccountName', 'name', 'mail', 'userAccountControl', 'objectClass'))
		$classes = @($entry.Properties['objectClass'])
		$mail    = [string]($entry.Properties['mail'] | Select-Object -First 1)
		$r.SamAccountName = [string]($entry.Properties['sAMAccountName'] | Select-Object -First 1)
		$r.Name           = [string]($entry.Properties['name'] | Select-Object -First 1)
		$r.EmailAddress   = $mail
		$r.Status = if ('computer' -in $classes) { 'Unknown' }
			elseif ('group' -in $classes) { 'Group' }
			elseif ([int]($entry.Properties['userAccountControl'] | Select-Object -First 1) -band 2) { 'Disabled' }   # ACCOUNTDISABLE
			elseif ($mail) { 'OK' } else { 'NoMail' }
		return [PSCustomObject]$r
	} catch { }   # not in AD -> at least try to translate the name

	try { $r.Name = ([System.Security.Principal.SecurityIdentifier]$sid).Translate([System.Security.Principal.NTAccount]).Value }
	catch { $r.Name = $sid }
	Write-Warning "Owner SID '$sid' ($($r.Name)) not found in AD."
	return [PSCustomObject]$r
}

# ---- Content check archive <-> extracted folder ----

# Runs 7z.exe with an argument list and returns its output (UTF-8). -ExtractFirst: decompress the archive
# with "7z x -so" first and stream it into this call (for .tar.gz etc. – nothing is written to disk).
function Invoke-SevenZip([string[]]$arguments, [string]$extractFirst) {
	$psi = [System.Diagnostics.ProcessStartInfo]::new($SevenZip)
	foreach ($a in $arguments) { $psi.ArgumentList.Add($a) }
	$psi.UseShellExecute = $false; $psi.CreateNoWindow = $true
	$psi.RedirectStandardOutput = $true; $psi.RedirectStandardError = $true
	$psi.StandardOutputEncoding = [System.Text.Encoding]::UTF8
	$psi.RedirectStandardInput = [bool]$extractFirst
	$p = [System.Diagnostics.Process]::Start($psi)
	$out = $p.StandardOutput.ReadToEndAsync(); $err = $p.StandardError.ReadToEndAsync()
	if ($extractFirst) {
		$psi2 = [System.Diagnostics.ProcessStartInfo]::new($SevenZip)
		foreach ($a in 'x', '-so', '-bd', $extractFirst) { $psi2.ArgumentList.Add($a) }
		$psi2.UseShellExecute = $false; $psi2.CreateNoWindow = $true
		$psi2.RedirectStandardOutput = $true; $psi2.RedirectStandardError = $true
		$q = [System.Diagnostics.Process]::Start($psi2)
		$qErr = $q.StandardError.ReadToEndAsync()
		try { $q.StandardOutput.BaseStream.CopyTo($p.StandardInput.BaseStream) } catch { }
		$p.StandardInput.Close(); $q.WaitForExit(); [void]$qErr.Result
	}
	$p.WaitForExit()
	return [PSCustomObject]@{ Exit = $p.ExitCode; Output = $out.Result; Error = $err.Result }
}

# Reads the directory of an archive (without extracting).
# Result: {Ok, Reason, Entries[{Rel, Len, Time, Crc}]}; Rel uses '/', Crc = $null if unknown.
function Get-ArchiveEntries([string]$archive) {
	$list = [System.Collections.Generic.List[PSCustomObject]]::new()
	try {
		if ($archive -match '\.zip$') {
			# entries without the UTF-8 flag are usually stored in the DOS code page (CP850 on Western
			# European Windows) – otherwise umlauts become '?'
			$zip = [System.IO.Compression.ZipFile]::Open($archive, 'Read', [System.Text.Encoding]::GetEncoding(850))
			try {
				foreach ($e in $zip.Entries) {
					if ($e.FullName.EndsWith('/') -or $e.FullName.EndsWith('\')) { continue }
					$crc = if ($zipHasCrc) { [Nullable[uint32]]$e.Crc32 } else { $null }   # ZipArchiveEntry.Crc32 needs .NET 7 / PowerShell 7.4
					$list.Add([PSCustomObject]@{ Rel = $e.FullName.Replace('\', '/'); Len = $e.Length; Time = $e.LastWriteTime.DateTime; Crc = $crc })
				}
			} finally { $zip.Dispose() }
			return [PSCustomObject]@{ Ok = $true; Reason = ''; Entries = $list }
		}
		if (-not $sevenZipAvailable) { return [PSCustomObject]@{ Ok = $false; Reason = 'content check N/A (no 7-Zip)'; Entries = $list } }

		$r = if ($archive -match '\.(tar\.(gz|bz2?|xz)|tgz|tbz2?)$') { Invoke-SevenZip @('l', '-slt', '-sccUTF-8', '-si', '-ttar') $archive }
		     else { Invoke-SevenZip @('l', '-slt', '-sccUTF-8', $archive) $null }
		if ($r.Exit -ne 0) { return [PSCustomObject]@{ Ok = $false; Reason = 'content check N/A (archive not readable/encrypted)'; Entries = $list } }

		$text = $r.Output -replace "`r", ''
		$start = $text.IndexOf("`n----------`n")
		if ($start -lt 0) { return [PSCustomObject]@{ Ok = $false; Reason = 'content check N/A (unknown 7-Zip output)'; Entries = $list } }
		foreach ($block in ($text.Substring($start + 12) -split "`n`n")) {
			$f = @{}
			foreach ($line in ($block -split "`n")) { $i = $line.IndexOf(' = '); if ($i -gt 0) { $f[$line.Substring(0, $i)] = $line.Substring($i + 3) } }
			if (-not $f.ContainsKey('Path')) { continue }
			if (($f['Attributes'] -like 'D*') -or $f['Folder'] -eq '+') { continue }
			$time = $null
			if ($f['Modified']) { $time = [datetime]::ParseExact($f['Modified'].Substring(0, [Math]::Min(19, $f['Modified'].Length)), 'yyyy-MM-dd HH:mm:ss', [Globalization.CultureInfo]::InvariantCulture) }
			$crc = if ($f['CRC']) { [Nullable[uint32]][Convert]::ToUInt32($f['CRC'], 16) } else { $null }
			$list.Add([PSCustomObject]@{ Rel = $f['Path'].Replace('\', '/'); Len = [long]$(if ($f['Size']) { $f['Size'] } else { 0 }); Time = $time; Crc = $crc })
		}
		return [PSCustomObject]@{ Ok = $true; Reason = ''; Entries = $list }
	} catch {
		$ex = $_.Exception; while ($ex.InnerException) { $ex = $ex.InnerException }   # strip the .NET invocation wrapper
		return [PSCustomObject]@{ Ok = $false; Reason = "content check N/A (archive not readable: $($ex.Message))"; Entries = $list }
	}
}

# Compares the archive content with the extracted folder.
# Level 1 (always): file list, size, timestamp (tolerance 2 s – ZIP resolution – or exactly 1 h – daylight saving).
# Level 2 (-crc): additionally CRC32 of every file. System files ($ContentIgnore) do not count.
# Result: {Status = identical | changed | N/A, Details}
function Compare-ArchiveWithFolder([string]$archive, [string]$folder, [bool]$crc) {
	$a = Get-ArchiveEntries $archive
	if (-not $a.Ok) { return [PSCustomObject]@{ Status = 'N/A'; Details = $a.Reason } }

	$files = @(Get-ChildItem -LiteralPath $folder -Recurse -File -Force -ErrorAction SilentlyContinue |
		ForEach-Object { [PSCustomObject]@{ Rel = $_.FullName.Substring($folder.Length + 1).Replace('\', '/'); Len = $_.Length; Time = $_.LastWriteTime; Path = $_.FullName } })
	$fH = @{}; foreach ($d in $files) { if ($d.Rel -notmatch $ContentIgnore) { $fH[$d.Rel.ToLowerInvariant()] = $d } }

	# variants: archive as is, or without a common root folder ("Project.zip" contains "Project/...")
	$variants = @(, $a.Entries)
	$roots = @($a.Entries | ForEach-Object { ($_.Rel -split '/')[0] } | Sort-Object -Unique)
	if ($roots.Count -eq 1 -and -not ($a.Entries | Where-Object { -not $_.Rel.Contains('/') })) {
		$p = $roots[0].Length + 1
		$variants += , @($a.Entries | ForEach-Object { [PSCustomObject]@{ Rel = $_.Rel.Substring($p); Len = $_.Len; Time = $_.Time; Crc = $_.Crc } })
	}
	$aH = $null; $best = -1
	foreach ($v in $variants) {
		$h = @{}; foreach ($e in $v) { if ($e.Rel -notmatch $ContentIgnore) { $h[$e.Rel.ToLowerInvariant()] = $e } }
		$t = @($h.Keys | Where-Object { $fH.ContainsKey($_) }).Count
		if ($t -gt $best) { $best = $t; $aH = $h }
	}

	$missing = @($aH.Keys | Where-Object { -not $fH.ContainsKey($_) })
	$new     = @($fH.Keys | Where-Object { -not $aH.ContainsKey($_) })
	$both    = @($aH.Keys | Where-Object { $fH.ContainsKey($_) })
	$changed = [System.Collections.Generic.List[string]]::new()
	$crcDiff = [System.Collections.Generic.List[string]]::new()
	$crcNA   = 0
	foreach ($k in $both) {
		$x = $aH[$k]; $o = $fH[$k]
		$timeOk = $true
		if ($x.Time) { $d = [Math]::Abs(($x.Time - $o.Time).TotalSeconds); $timeOk = ($d -le 2) -or ([Math]::Abs($d - 3600) -le 2) }
		if ($x.Len -ne $o.Len -or -not $timeOk) { $changed.Add($o.Rel); continue }
		if ($crc) {
			if ($null -eq $x.Crc) { $crcNA++ }
			elseif ([PE3Crc32]::File($o.Path) -ne $x.Crc) { $crcDiff.Add($o.Rel) }
		}
	}

	$parts = @()
	if ($new.Count)     { $parts += "$($new.Count) new" }
	if ($missing.Count) { $parts += "$($missing.Count) missing" }
	if ($changed.Count) { $parts += "$($changed.Count) changed" }
	if ($crcDiff.Count) { $parts += "$($crcDiff.Count) content changed (CRC)" }
	$basis = "$($both.Count) of $($aH.Count) files"
	if ($parts.Count -eq 0) {
		$extra = if (-not $crc) { '' }
			elseif ($crcNA -gt 0 -and $crcNA -eq $both.Count) { ', CRC not available (format without checksum)' }
			elseif ($crcNA -gt 0) { ', CRC partly not available' }
			else { ', CRC checked' }
		return [PSCustomObject]@{ Status = 'identical'; Details = "$basis identical$extra" }
	}
	$examples = @(@($new | ForEach-Object { $fH[$_].Rel }) + @($changed) + @($crcDiff) + @($missing | ForEach-Object { $aH[$_].Rel }) | Select-Object -First 3)
	return [PSCustomObject]@{ Status = 'changed'; Details = ('{0} (e.g. {1})' -f ($parts -join ', '), ($examples -join '; ')) }
}

function Test-MailAddress([string]$address) {
	return -not [string]::IsNullOrWhiteSpace($address) -and $address -match '^[^@\s]+@[^@\s]+\.[^@\s]+$'
}

# DFS namespace root? (contains only DFS links = reparse points, no data of its own)
function Test-DfsRoot([string]$dir) {
	if ($dir -match '\\DFSRoots(\\|$)') { return $true }
	$children = @(Get-ChildItem -LiteralPath $dir -Force -ErrorAction SilentlyContinue | Select-Object -First 50)
	return $children.Count -gt 0 -and -not ($children | Where-Object { -not ($_.Attributes -band [IO.FileAttributes]::ReparsePoint) })
}

# File shares of this machine (without C$, ADMIN$, IPC$ and $IgnoredShares).
# -Raw: share objects (Name, Path, Special, ShareType) instead of Get-SmbShare – for tests.
function Get-DataShares([object[]]$Raw) {
	try {
		if (-not $Raw) { $Raw = @(Get-SmbShare -ErrorAction Stop) }
		@($Raw |
			Where-Object { -not $_.Special -and "$($_.ShareType)" -eq 'FileSystemDirectory' -and $_.Path -and $_.Name -notin $IgnoredShares } |
			ForEach-Object {
				$p = if ($_.Path -match '^[A-Za-z]:\\?$') { $_.Path.Substring(0, 2) } else { $_.Path.TrimEnd('\') }
				[PSCustomObject]@{ Name = $_.Name; Path = $p; Hidden = $_.Name.EndsWith('$'); DfsRoot = (Test-DfsRoot $p) }
			})
	} catch {
		Write-Warning "Could not read shares (Get-SmbShare, admin rights?) – paths stay local: $($_.Exception.Message)"
		@()
	}
}

# Base paths for -AllShares: data shares without DFS roots; nested shares -> outermost only.
function Get-ShareBasePaths([PSObject[]]$shares) {
	$outer = [System.Collections.Generic.List[string]]::new()
	foreach ($s in ($shares | Where-Object { -not $_.DfsRoot } | Sort-Object { $_.Path.Length }, Path)) {
		$inside = $outer | Where-Object { $s.Path -eq $_ -or $s.Path.StartsWith($_ + '\', [StringComparison]::OrdinalIgnoreCase) }
		if (-not $inside) { $outer.Add($s.Path) }
	}
	return @($outer | ForEach-Object { if ($_ -match '^[A-Za-z]:$') { "$_\" } else { $_ } })
}

# Local path -> UNC via the outermost matching share (visible before hidden); $null if none.
function ConvertTo-SharePath([string]$localPath, [PSObject[]]$shares) {
	$hit = $shares |
		Where-Object { $localPath -eq $_.Path -or $localPath.StartsWith($_.Path + '\', [StringComparison]::OrdinalIgnoreCase) } |
		Sort-Object Hidden, @{ e = { $_.Path.Length } }, Name | Select-Object -First 1
	if (-not $hit) { return $null }
	return '\\{0}\{1}{2}' -f $UncServer, $hit.Name, $localPath.Substring($hit.Path.Length)
}

# Path for mails: 1. fixed replacement (only at folder boundaries); target empty/'auto'
# -> 2. via share; 3. otherwise the local path.
function Get-MailPath([string]$localPath, [string[]]$sources, [string[]]$targets, [PSObject[]]$shares) {
	for ($i = 0; $i -lt $sources.Count; $i++) {
		$q = $sources[$i]
		if ([string]::IsNullOrEmpty($q)) { continue }
		$q = $q.TrimEnd('\')
		if ($localPath -eq $q -or $localPath.StartsWith($q + '\', [StringComparison]::OrdinalIgnoreCase)) {
			$t = if ($i -lt $targets.Count) { $targets[$i] } else { '' }
			if ($t -and $t -ne 'auto') { return $t.TrimEnd('\') + $localPath.Substring($q.Length) }
			break
		}
	}
	if ($shares) {
		$unc = ConvertTo-SharePath $localPath $shares
		if ($unc) { return $unc }
	}
	return $localPath
}

# file:// link for Outlook: keep non-ASCII characters raw (Outlook does not open %C3%BC-encoded
# links), only encode characters that break URLs.
function ConvertTo-FileLink([string]$p) {
	$u = $p.Replace('%', '%25').Replace('#', '%23').Replace(' ', '%20').Replace('\', '/')
	if ($u.StartsWith('//')) { return 'file:' + $u }   # UNC
	return 'file:///' + $u                             # drive letter
}

function New-MailBody([PSObject[]]$entries, [string]$shownRecipient, [bool]$isSummary) {
	$enc = { param($s) [System.Net.WebUtility]::HtmlEncode([string]$s) }
	$sb  = [System.Text.StringBuilder]::new()

	if ($isSummary) {
		[void]$sb.Append(@"
<p style="font-family:verdana;background:#fff3cd;padding:6px"><b>Summary for IT:</b> no owner that can be mailed was found for the following entries
(unknown/deleted account, disabled, no mail address or BUILTIN\Administrators). Please clarify the owner or clean up yourself.</p>

"@)
	}
	[void]$sb.Append(@"
<font face="verdana">
Hello,
<p>the table below lists folders (first column) that contain the archive from the second column.<br/>
The archive has been extracted and a folder with the same name exists in the same location.<br/>
You receive this mail because you are the registered owner of that folder.<br/>
<br/>
Keeping both wastes valuable server storage and should be avoided.<br/>
<br/>
<b>Please delete either the archive or the folder.</b><br/>
(Alternatively, if their content differs, rename the archive or the folder.)<br/>
<br/>
<table border="1" cellpadding="3" style="border-collapse:collapse">
<tr><th>Folder</th><th>Archive</th><th>Size (MB)</th><th>Content (archive &harr; folder)</th>$(if ($isSummary) { '<th>Owner (folder)</th>' })</tr>

"@)
	foreach ($e in $entries) {
		$href = [System.Net.WebUtility]::HtmlEncode((ConvertTo-FileLink $e.Path))
		[void]$sb.Append('<tr><td><a href="').Append($href).Append('">').Append((& $enc $e.Path)).Append('</a></td>')
		[void]$sb.Append('<td>').Append((& $enc $e.Archive)).Append('</td>')
		[void]$sb.Append('<td align="right">').Append(('{0:N0}' -f $e.SizeMB)).Append('</td>')
		[void]$sb.Append('<td>').Append((& $enc $e.Content)).Append('</td>')
		if ($isSummary) { [void]$sb.Append('<td>').Append((& $enc $e.Owner)).Append('</td>') }
		[void]$sb.AppendLine('</tr>')
	}
	[void]$sb.Append(@"
</table>
<br/><br/>
(The list is sorted by size, descending, and contains archives of at least $MailMinMB MB.<br/>
Please also handle smaller archives in these folders.)<br/>
<br/>
This mail is sent automatically until the entries above have been cleaned up.<br/>
<br/>
<p>Thank you!<br/>
Your IT department<br/>
$(& $enc $ContactPhone)<br/>
<br/>
Questions: <a href="mailto:$($ContactEmail)?subject=Question%20about%20archive%20clean-up">$(& $enc $ContactEmail)</a><br/>
<br/>
Mail sent to: $(& $enc $shownRecipient)
</font>
"@)
	return $sb.ToString()
}

function Send-CleanupMail([string]$to, [string]$body) {
	$params = @{
		SmtpServer = $SmtpServer; Port = $SmtpPort; From = $MailFrom; To = $to; Subject = $MailSubject
		Body = $body; BodyAsHtml = $true; Encoding = $MailEncoding; UseSsl = $SmtpUseSsl
		ErrorAction = 'Stop'; WarningAction = 'SilentlyContinue'   # suppress the Send-MailMessage "obsolete" warning
	}
	if ($SmtpCredential) { $params['Credential'] = $SmtpCredential }
	Send-MailMessage @params
}

# ========================================================================
# Start
# ========================================================================

if (-not (Test-Path -LiteralPath $OutputPath -PathType Container)) { New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null }
$stamp      = Get-Date -Format 'yyyyMMdd_HHmm_ss'
$csvPath    = Join-Path $OutputPath "archives_with_extracted_folder_$stamp.csv"
$transcript = Join-Path $OutputPath "archives_with_extracted_folder_$stamp.log"
$watch      = [System.Diagnostics.Stopwatch]::StartNew()

Start-Transcript -LiteralPath $transcript | Out-Null
try {
	if ($SendMail) { Write-Log 'SendMail active – mails will be sent' -Level Highlight }
	else           { Write-Log 'Dry run – no mails (-SendMail missing)' -Level Highlight }
	if ($SummaryOnly)  { Write-Log "Summary only – the only mail goes to $FallbackTo, users are not mailed" -Level Highlight }
	elseif (-not $Live) { Write-Log "Debug mode – all mails go to $DebugTo (-Live missing)" -Level Highlight }

	# prepare the content check: ZIP via .NET (code page 850 for old ZIP names), other formats via 7-Zip
	Add-Type -AssemblyName System.IO.Compression, System.IO.Compression.FileSystem
	[System.Text.Encoding]::RegisterProvider([System.Text.CodePagesEncodingProvider]::Instance)
	$zipHasCrc = $null -ne [System.IO.Compression.ZipArchiveEntry].GetProperty('Crc32')
	$sevenZipAvailable = [bool]$SevenZip -and (Test-Path -LiteralPath $SevenZip -PathType Leaf)
	if (-not ('PE3Crc32' -as [type])) {
		Add-Type -TypeDefinition @'
using System; using System.IO;
public static class PE3Crc32 {
	static readonly uint[] T = new uint[256];
	static PE3Crc32() { for (uint i = 0; i < 256; i++) { uint c = i; for (int k = 0; k < 8; k++) c = (c & 1) != 0 ? 0xEDB88320u ^ (c >> 1) : c >> 1; T[i] = c; } }
	public static uint File(string path) {
		uint crc = 0xFFFFFFFFu; var buf = new byte[1 << 20];
		using (var fs = new FileStream(path, FileMode.Open, FileAccess.Read, FileShare.ReadWrite, 1 << 20, FileOptions.SequentialScan)) {
			int n; while ((n = fs.Read(buf, 0, buf.Length)) > 0) for (int i = 0; i < n; i++) crc = T[(crc ^ buf[i]) & 0xFF] ^ (crc >> 8);
		}
		return crc ^ 0xFFFFFFFFu;
	}
}
'@
	}
	Write-Log ('Content check: ZIP always{0}; other formats {1}{2}' -f `
		$(if ($zipHasCrc) { '' } else { ' (without CRC – needs PowerShell 7.4)' }),
		$(if ($sevenZipAvailable) { "via 7-Zip ($SevenZip)" } else { 'N/A (no 7-Zip)' }),
		$(if ($CheckContentCrc) { '; level 2 (CRC) active' } else { '' }))

	$shares = @()
	if ($ShareAutoMapping -or $AllShares) {
		$shares = Get-DataShares
		$dfs = @($shares | Where-Object DfsRoot)
		if ($dfs) { Write-Log ('DFS roots (links only, ignored): {0}' -f (($dfs | ForEach-Object { "$($_.Name) = $($_.Path)" }) -join ' · ')) }
		$shares = @($shares | Where-Object { -not $_.DfsRoot })
		Write-Log ('{0:N0} data shares: {1}' -f $shares.Count, $(if ($shares) { ($shares | Sort-Object Path | ForEach-Object { "$($_.Name) = $($_.Path)" }) -join ' · ' } else { 'none' }))
	}
	if ($AllShares) {
		$fromShares = @(Get-ShareBasePaths $shares)
		if ($fromShares.Count -eq 0) { throw '-AllShares: no data shares found on this machine.' }
		$Path = @($Path) + $fromShares
		Write-Log ('-AllShares: {0:N0} base paths (nested shares merged): {1}' -f $fromShares.Count, ($fromShares -join ' · ')) -Level Highlight
	}
	if (@($Path).Count -eq 0) { throw 'No -Path given (or use -AllShares).' }

	$Path = @($Path | Where-Object { $_ } | ForEach-Object { if ($_ -match '^[A-Za-z]:\\?$') { $_.Substring(0, 2) + '\' } else { $_.TrimEnd('\') } } | Where-Object {
		if (Test-Path -LiteralPath $_ -PathType Container -ErrorAction SilentlyContinue) { $true }
		else { Write-Warning "Path not found, skipped: $_"; $false }
	} | Select-Object -Unique)
	if ($Path.Count -eq 0) { throw 'No valid path – aborted.' }

	# ====================================================================
	# Phase 1a: find archives (Everything, otherwise file-system scan)
	# ====================================================================

	$since = if ($LastMonths -gt 0) { (Get-Date).AddMonths(-$LastMonths) } else { $null }
	if ($since) { Write-Log ('Time filter: only archives modified since {0:yyyy-MM-dd}' -f $since) -Level Highlight }

	$archives = [System.Collections.Generic.List[PSCustomObject]]::new()
	$toScan   = [System.Collections.Generic.List[string]]::new()
	$notIndexed = [System.Collections.Generic.List[string]]::new()   # only with -SearchMode Everything: skipped

	if ($SearchMode -eq 'Scan') {
		$Path | ForEach-Object { $toScan.Add($_) }
	} else {
		$client = $null
		try {
			Import-Module $EverythingModule -Force
			$client = Connect-Everything
			$exts = ($ArchivePatterns | ForEach-Object { ($_ -split '\.')[-1] } | Sort-Object -Unique) -join ';'
			foreach ($p in $Path) {
				$pathQuery = '"{0}\"' -f $p.TrimEnd('\')
				# Index check WITHOUT trailing "\": the folder itself counts – an empty but indexed
				# folder returns 1, only a path that is not indexed returns 0.
				if (@(Search-Everything -Client $client -Query ('"{0}"' -f $p.TrimEnd('\')) -MaxResults 1).Count -eq 0) {
					if ($SearchMode -eq 'Everything') {
						# do not abort the whole run (e.g. with -AllShares), but do not scan either
						Write-Warning "Path is not in the Everything index and is skipped (-SearchMode Everything): $p"
						$notIndexed.Add($p); continue
					}
					Write-Warning "Path is not in the Everything index, will be scanned: $p"
					$toScan.Add($p); continue
				}
				$query = '{0} file: ext:{1} size:>={2}mb !"\$RECYCLE.BIN\" !"\System Volume Information\"' -f $pathQuery, $exts, $ReportMinMB
				if ($LastMonths -gt 0) { $query += " dm:last${LastMonths}months" }
				$sw = [System.Diagnostics.Stopwatch]::StartNew()
				$hits = @(Search-Everything -Client $client -Query $query -MaxResults 0 -Properties Size, DateModified)
				foreach ($h in $hits) {
					$archives.Add([PSCustomObject]@{ FullName = $h.FullPath; Length = [long]$h.Properties['Size']; LastWriteTime = $h.Properties['DateModified'] })
				}
				Write-Log ('Everything: {0:N0} archives in {1} ({2:N0} ms)' -f $hits.Count, $p, $sw.ElapsedMilliseconds)
			}
		} catch {
			if ($SearchMode -eq 'Everything') { throw }
			Write-Warning "Everything not usable – falling back to file-system scan. Reason: $($_.Exception.Message)"
			$archives.Clear(); $toScan.Clear()
			$Path | ForEach-Object { $toScan.Add($_) }
		} finally {
			if ($client) { Disconnect-Everything -Client $client }
		}
	}

	if ($toScan.Count -gt 0) {
		# split every base path into top-level folders (recursive) plus the root (files only)
		$scanItems = [System.Collections.Generic.List[PSCustomObject]]::new()
		foreach ($p in $toScan) {
			$scanItems.Add([PSCustomObject]@{ Path = $p; Recurse = $false })
			Get-ChildItem -LiteralPath $p -Directory -ErrorAction SilentlyContinue |
				ForEach-Object { $scanItems.Add([PSCustomObject]@{ Path = $_.FullName; Recurse = $true }) }
		}
		Write-Log ('File-system scan of {0:N0} folders – this can take hours on large shares ...' -f $scanItems.Count) -Level Notice

		$scanItems | ForEach-Object -ThrottleLimit $ThrottleLimit -Parallel {
			$patterns = $using:ArchivePatterns
			$minBytes = [long]$using:ReportMinMB * 1MB
			$since    = $using:since
			$sw       = [System.Diagnostics.Stopwatch]::StartNew()
			# -Recurse is always set (otherwise -Include does not filter with -LiteralPath); -Depth 0 = root only
			$gci = @{ LiteralPath = $_.Path; File = $true; Include = $patterns; Recurse = $true; ErrorAction = 'SilentlyContinue'; ErrorVariable = 'gciErrors' }
			if (-not $_.Recurse) { $gci['Depth'] = 0 }
			$n = 0
			foreach ($f in (Get-ChildItem @gci)) {
				if ($f.Length -lt $minBytes) { continue }
				if ($since -and $f.LastWriteTime -lt $since) { continue }
				$n++
				[PSCustomObject]@{ FullName = $f.FullName; Length = $f.Length; LastWriteTime = $f.LastWriteTime }
			}
			foreach ($e in $gciErrors) { Write-Warning "Access error: $($e.TargetObject) – $($e.Exception.Message)" }
			Write-Host ('{0:HH:mm:ss}    done: {1} – {2:N0} archives ({3:mm\:ss})' -f (Get-Date), $_.Path, $n, $sw.Elapsed)
		} | ForEach-Object { $archives.Add($_) }
	}

	# ====================================================================
	# Phase 1b: same-named folder – only for the archives found
	# ====================================================================

	$candidates = @($archives | Sort-Object FullName -Unique | ForEach-Object {
		$name   = [System.IO.Path]::GetFileName($_.FullName)
		$folder = [System.IO.Path]::GetDirectoryName($_.FullName)
		# base name: "x.zip" -> "x", "x.tar.gz" -> "x"
		$base = if ($name -match '^(?<b>.+)\.tar\.(gz|bz2?|xz)$') { $Matches['b'] } else { [System.IO.Path]::GetFileNameWithoutExtension($name) }
		if ([string]::IsNullOrWhiteSpace($base)) { return }
		$exact     = Join-Path $folder $base
		$noSuffix  = Join-Path $folder ($base -replace '\s*\(\d+\)$', '')   # "Project (2)" -> "Project"
		# -ErrorAction SilentlyContinue: "access denied" must not abort the run
		$match = if     (Test-Path -LiteralPath $exact    -PathType Container -ErrorAction SilentlyContinue) { $exact }
		         elseif (Test-Path -LiteralPath $noSuffix -PathType Container -ErrorAction SilentlyContinue) { $noSuffix }
		if (-not $match) { return }
		[PSCustomObject]@{ ArchivePath = $_.FullName; ArchiveName = $name; Folder = $folder; ExtractedFolder = $match; SizeMB = [long][math]::Floor($_.Length / 1MB) }
	})
	Write-Log ('Phase 1 done – {0:N0} of {1:N0} archives have a same-named folder (>= {2} MB)' -f $candidates.Count, $archives.Count, $ReportMinMB)
	if ($notIndexed.Count -gt 0) {
		Write-Log ('ATTENTION: {0:N0} path(s) not in the Everything index and NOT searched: {1} – index them in Everything or run with -SearchMode Auto (scan)' -f $notIndexed.Count, ($notIndexed -join ' · ')) -Level Notice
	}

	# ====================================================================
	# Phase 1c: content check archive <-> extracted folder
	#   level 1 always (archive directory + folder listing), level 2 (CRC) with -CheckContentCrc
	# ====================================================================

	$content = @{}
	$sw = [System.Diagnostics.Stopwatch]::StartNew(); $n = 0
	foreach ($c in $candidates) {
		$n++
		Write-Progress -Activity 'Content check archive <-> folder' -Status $c.ArchiveName -PercentComplete ($n * 100 / [Math]::Max(1, $candidates.Count))
		$content[$c.ArchivePath] = Compare-ArchiveWithFolder $c.ArchivePath $c.ExtractedFolder $CheckContentCrc.IsPresent
	}
	Write-Progress -Activity 'Content check archive <-> folder' -Completed
	$stat = @($content.Values | Group-Object Status | ForEach-Object { "$($_.Name): $($_.Count)" }) -join ' · '
	Write-Log ('Phase 1c done – content check of {0:N0} archives in {1:mm\:ss}: {2}' -f $candidates.Count, $sw.Elapsed, $(if ($stat) { $stat } else { '–' }))

	# ====================================================================
	# Phase 2: owners (Get-Acl in parallel, AD per unique SID)
	# ====================================================================

	$uniquePaths = @(@(foreach ($c in $candidates) { $c.ExtractedFolder; $c.ArchivePath }) | Sort-Object -Unique)
	$ownerSid = @{}
	$uniquePaths | ForEach-Object -ThrottleLimit $ThrottleLimit -Parallel {
		$sid = $null
		try { $sid = (Get-Acl -LiteralPath $_ -ErrorAction Stop).GetOwner([System.Security.Principal.SecurityIdentifier]).Value }
		catch { Write-Warning "Get-Acl failed for '$_': $($_.Exception.Message)" }
		[PSCustomObject]@{ Path = $_; Sid = $sid }
	} | ForEach-Object { $ownerSid[$_.Path] = $_.Sid }

	$owners = @{}
	foreach ($sid in @($ownerSid.Values | Where-Object { $_ } | Sort-Object -Unique)) { $owners[$sid] = Resolve-Owner $sid }
	$unknown = Resolve-Owner $null
	Write-Log ('Phase 2 done – {0:N0} paths, {1:N0} different owners' -f $uniquePaths.Count, $owners.Count)

	$mailShares = if ($ShareAutoMapping) { $shares } else { @() }
	$results = @(foreach ($c in $candidates) {
		$sf = $ownerSid[$c.ExtractedFolder]; $sa = $ownerSid[$c.ArchivePath]
		$of = if ($sf -and $owners.ContainsKey($sf)) { $owners[$sf] } else { $unknown }
		$oa = if ($sa -and $owners.ContainsKey($sa)) { $owners[$sa] } else { $unknown }
		[PSCustomObject]@{
			SizeMB            = $c.SizeMB
			Folder            = $c.Folder
			MailPath          = Get-MailPath $c.Folder $ReplaceSource $ReplaceTarget $mailShares
			Archive           = $c.ArchiveName
			ExtractedFolder   = $c.ExtractedFolder
			Content           = $content[$c.ArchivePath].Status
			ContentDetails    = $content[$c.ArchivePath].Details
			FolderOwnerMail   = $of.EmailAddress
			FolderOwnerName   = $of.Name
			FolderOwnerStatus = $of.Status
			ArchiveOwnerMail  = $oa.EmailAddress
		}
	})
	$noShare = @($results | Where-Object { $_.MailPath -eq $_.Folder })
	if ($noShare.Count -gt 0) { Write-Warning ('{0:N0} hits are not below any share – mails show the local path (e.g. {1})' -f $noShare.Count, $noShare[0].Folder) }
	$totalMB = [long]0
	foreach ($r in $results) { $totalMB += $r.SizeMB }

	# ====================================================================
	# Phase 3: CSV
	# ====================================================================

	$results | Sort-Object @{ e = 'FolderOwnerMail' }, @{ e = 'SizeMB'; Descending = $true } |
		Export-Csv -LiteralPath $csvPath -Delimiter ';' -Encoding utf8BOM -NoTypeInformation
	Write-Log ('Phase 3 – CSV written: {0} ({1:N0} hits, {2:N0} MB)' -f $csvPath, $results.Count, $totalMB)

	# ====================================================================
	# Phase 4: one mail per owner; owners that cannot be mailed -> one summary mail
	# ====================================================================

	$mailItems = @($results | Where-Object { $_.SizeMB -ge $MailMinMB })
	$groups = $mailItems | Group-Object {
		if (($_.FolderOwnerStatus -in @('OK', 'Group')) -and (Test-MailAddress $_.FolderOwnerMail)) { $_.FolderOwnerMail } else { '' }
	} | Sort-Object Name

	$sent = 0; $failed = 0
	Write-Log ('Phase 4 – {0:N0} hits >= {1} MB for {2:N0} recipients' -f $mailItems.Count, $MailMinMB, @($groups).Count)
	if ($SendMail -and $SummaryOnly -and -not (@($groups) | Where-Object { [string]::IsNullOrEmpty($_.Name) })) {
		Write-Log 'No hits without a mailable owner – no summary mail needed.' -Level Notice
	}
	if ($SendMail) {
		foreach ($g in $groups) {
			if ($MaxMails -gt 0 -and $sent -ge $MaxMails) { Write-Log "Limit of $MaxMails mail(s) reached – skipping the rest." -Level Notice; break }
			$isSummary = [string]::IsNullOrEmpty($g.Name)
			if ($SummaryOnly -and -not $isSummary) { continue }
			$ownerMail = if ($isSummary) { $FallbackTo } else { $g.Name }
			$to        = if ($Live -or $SummaryOnly) { $ownerMail } else { $DebugTo }
			$entries = @($g.Group | Sort-Object SizeMB -Descending | ForEach-Object {
				[PSCustomObject]@{
					Path = $_.MailPath; Archive = $_.Archive; SizeMB = $_.SizeMB
					Owner = '{0} ({1})' -f $_.FolderOwnerName, $_.FolderOwnerStatus
					# no switch here: inside a switch $_ would be the tested value instead of the CSV row
					Content = if ($_.Content -eq 'identical') { 'identical – the archive can be deleted' }
					          elseif ($_.Content -eq 'changed') { "folder was changed: $($_.ContentDetails)" }
					          else { 'content check N/A' }
				}
			})
			$body = New-MailBody -entries $entries -shownRecipient $ownerMail -isSummary $isSummary
			try {
				Send-CleanupMail -to $to -body $body
				$sent++
				Write-Log ('Mail to {0}{1} – {2} entries' -f $to, $(if ($to -ne $ownerMail) { " (for $ownerMail)" }), $entries.Count) -Level Action
			} catch {
				$failed++
				Write-Warning "Sending to '$to' failed: $($_.Exception.Message)"
			}
		}
	}

	Write-Log ('Done after {0:hh\:mm\:ss} – hits: {1:N0} ({2:N0} MB), mails sent: {3}, failed: {4}' -f $watch.Elapsed, $results.Count, $totalMB, $sent, $failed)

	# result for further processing in the pipeline
	$mailItems | Sort-Object @{ e = 'FolderOwnerMail' }, @{ e = 'SizeMB'; Descending = $true }
}
finally {
	Stop-Transcript | Out-Null
}
