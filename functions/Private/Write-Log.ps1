<#
.SYNOPSIS
Write message to audit and error logs

.DESCRIPTION
Centralized logging function for all SharedMailboxProvisioner operations.
Writes to audit logs (INFO/WARN) and error logs (ERROR) with proper formatting.
Never logs sensitive data (passwords, tokens, keys).

Per ADR-004: Logging & Audit Trail

Log locations:
  Audit: $env:ProgramData\SharedMailboxProvisioner\Audit\audit-YYYY-MM-DD.log
  Error: $env:ProgramData\SharedMailboxProvisioner\Errors\errors-YYYY-MM-DD.log
#>

function Write-Log {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$Message,

        [Parameter(Mandatory = $false)]
        [ValidateSet('INFO', 'WARN', 'ERROR')]
        [string]$Level = 'INFO',

        [Parameter(Mandatory = $false)]
        [string]$Operation = "",

        [Parameter(Mandatory = $false)]
        [string]$Status = "",

        [Parameter(Mandatory = $false)]
        [string]$LogPath = ""
    )

    # Determine log directory
    if (-not $LogPath) {
        $LogPath = Join-Path $env:ProgramData 'SharedMailboxProvisioner'
    }

    # Create log directories if needed
    $auditDir = Join-Path $LogPath 'Audit'
    $errorDir = Join-Path $LogPath 'Errors'

    foreach ($dir in @($auditDir, $errorDir)) {
        if (-not (Test-Path $dir)) {
            try {
                New-Item -ItemType Directory -Path $dir -Force -ErrorAction Stop | Out-Null
            }
            catch {
                Write-Error "Failed to create log directory $dir : $_"
                return
            }
        }
    }

    # Format timestamp (ISO 8601)
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $dateYmd = Get-Date -Format 'yyyy-MM-dd'

    # Get user context
    $user = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
    if (-not $user) {
        $user = $env:USERNAME
    }

    # Build log entry
    $logEntry = "[$timestamp] [$Level] [$user]"
    if ($Operation) {
        $logEntry += " [$Operation]"
    }
    if ($Status) {
        $logEntry += " [$Status]"
    }
    $logEntry += " $Message"

    # Write to audit log (INFO, WARN always; ERROR too)
    $auditLogFile = Join-Path $auditDir "audit-$dateYmd.log"
    try {
        Add-Content -Path $auditLogFile -Value $logEntry -Encoding UTF8 -ErrorAction Stop
    }
    catch {
        Write-Error "Failed to write audit log: $_"
    }

    # Write to error log (ERROR only)
    if ($Level -eq 'ERROR') {
        $errorLogFile = Join-Path $errorDir "errors-$dateYmd.log"
        try {
            Add-Content -Path $errorLogFile -Value $logEntry -Encoding UTF8 -ErrorAction Stop
        }
        catch {
            Write-Error "Failed to write error log: $_"
        }
    }

    # Also write to console (for immediate feedback)
    $consolePrefix = switch ($Level) {
        'INFO' {
            '[INFO]'
        }
        'WARN' {
            '[WARN]'
        }
        'ERROR' {
            '[ERROR]'
        }
    }

    Write-Output "$consolePrefix $Message"
}

function Remove-OldLogs {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [int]$AuditRetentionDays = 90,

        [Parameter(Mandatory = $false)]
        [int]$ErrorRetentionDays = 30,

        [Parameter(Mandatory = $false)]
        [string]$LogPath = ""
    )

    if (-not $LogPath) {
        $LogPath = Join-Path $env:ProgramData 'SharedMailboxProvisioner'
    }

    $auditDir = Join-Path $LogPath 'Audit'
    $errorDir = Join-Path $LogPath 'Errors'

    # Remove old audit logs
    if (Test-Path $auditDir) {
        $cutoffDate = (Get-Date).AddDays(-$AuditRetentionDays)
        Get-ChildItem -Path $auditDir -Filter "audit-*.log" | Where-Object { $_.LastWriteTime -lt $cutoffDate } | Remove-Item -Force
        Write-Output "[INFO] Removed audit logs older than $AuditRetentionDays days"
    }

    # Remove old error logs
    if (Test-Path $errorDir) {
        $cutoffDate = (Get-Date).AddDays(-$ErrorRetentionDays)
        Get-ChildItem -Path $errorDir -Filter "errors-*.log" | Where-Object { $_.LastWriteTime -lt $cutoffDate } | Remove-Item -Force
        Write-Output "[INFO] Removed error logs older than $ErrorRetentionDays days"
    }
}

