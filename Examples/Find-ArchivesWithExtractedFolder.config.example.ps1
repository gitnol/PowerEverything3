# Template for Find-ArchivesWithExtractedFolder.config.ps1 (place it next to the script).
# Copy this file, adjust the values – the real config file is ignored by git.
# Everything not set here falls back to the defaults in the script.

# Size limits
$ReportMinMB = 10                  # from this size into CSV / result
$MailMinMB   = 100                 # from this size into mails

# Mail
$SmtpServer  = 'smtp.example.com'
$SmtpPort    = 25
$SmtpUseSsl  = $false              # $true if the relay offers STARTTLS with a valid certificate
$MailFrom    = 'helpdesk@example.com'
$DebugTo     = 'admin@example.com'     # receives all mails without -Live
$FallbackTo  = 'helpdesk@example.com'  # summary mail for owners that cannot be mailed
$MailSubject = 'Archives were not deleted after extraction'

# Contact shown in the mail
$ContactPhone = '+00 0000 0000'
$ContactEmail = 'helpdesk@example.com'

# Paths in mails as \\server\share\... (outermost matching SMB share)
$ShareAutoMapping = $true
# $UncServer      = 'fileserver01.example.local'   # default: FQDN of this machine
# $IgnoredShares  = @('print$', 'SYSVOL', 'NETLOGON')

# Optional: other archive types
# $ArchivePatterns = @('*.7z', '*.zip', '*.iso', '*.rar', '*.tar', '*.tgz', '*.gz', '*.bz', '*.bz2', '*.xz', '*.s7z')

# Optional: location of the Everything wrapper module (default: repository root)
# $EverythingModule = 'C:\Tools\PowerEverything3\Everything3-PowerShell-Wrapper.psd1'
