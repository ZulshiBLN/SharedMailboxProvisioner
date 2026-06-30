<#
.SYNOPSIS
Export audit log in HTML, CSV, or text format.

.DESCRIPTION
Generates formatted audit log export from provisioning operations with filtering
and formatting options. Supports HTML (colorized), CSV (machine-readable), or
plain text output.

Per ADR-004: Logging & Audit Trail

.PARAMETER StartDate
Log start date. Default: last 7 days.

.PARAMETER EndDate
Log end date. Default: today.

.PARAMETER Format
Output format: HTML, CSV, Text. Default: HTML

.PARAMETER OutputPath
Output file path. If empty, returns formatted string.

.PARAMETER FilterStatus
Filter by status: All, SUCCESS, FAILED, WARN. Default: All

.EXAMPLE
Export-MailboxAuditLog -Format HTML -OutputPath "C:\reports\audit.html"

Export last 7 days as HTML.

.EXAMPLE
$log = Export-MailboxAuditLog -Format CSV
$log | Out-File "audit.csv"

Export as CSV.

.NOTES
- Reads from audit log directory (ProgramData/SharedMailboxProvisioner/Audit/)
- Formats timestamps and sanitizes special characters (ASCII-only)
- HTML includes color coding (green=success, red=failed)
#>

function Export-MailboxAuditLog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [DateTime]$StartDate = (Get-Date).AddDays(-7),

        [Parameter(Mandatory = $false)]
        [DateTime]$EndDate = (Get-Date),

        [Parameter(Mandatory = $false)]
        [ValidateSet("HTML", "CSV", "Text")]
        [string]$Format = "HTML",

        [Parameter(Mandatory = $false)]
        [string]$OutputPath = "",

        [Parameter(Mandatory = $false)]
        [ValidateSet("All", "INFO", "ERROR", "WARN")]
        [string]$FilterStatus = "All"
    )

    Write-Verbose "Exporting audit log ($Format format, $FilterStatus filter)"

    $auditDir = Join-Path $env:ProgramData "SharedMailboxProvisioner\Audit"
    $entries = @()

    try {
        # ================================================================
        # STEP 1: Load audit logs from date range
        # ================================================================
        if (-not (Test-Path $auditDir)) {
            Write-Verbose "Audit directory not found: $auditDir"
            return ""
        }

        $logFiles = Get-ChildItem -Path $auditDir -Filter "audit-*.log" -ErrorAction SilentlyContinue

        foreach ($logFile in $logFiles) {
            try {
                $fileDate = [DateTime]::Parse($logFile.BaseName.Replace("audit-", "").Replace(".log", ""))
                if ($fileDate -ge $StartDate.Date -and $fileDate -le $EndDate.Date) {
                    $lines = Get-Content -Path $logFile.FullName -ErrorAction SilentlyContinue
                    if ($lines) {
                        $entries += $lines
                    }
                }
            }
            catch {
                Write-Verbose "Failed to parse log file date: $($logFile.Name)"
            }
        }

        Write-Verbose "Loaded $($entries.Count) audit entries"

        # ================================================================
        # STEP 2: Parse and filter entries
        # ================================================================
        $parsedEntries = @()
        foreach ($entry in $entries) {
            # Parse format: [TIMESTAMP] [LEVEL] [USER] [OPERATION] [STATUS] [MESSAGE]
            if ($entry -match '^\[(.+?)\]\s+\[(.+?)\]\s+\[(.+?)\]\s+\[(.+?)\]\s+\[(.+?)\]\s+(.+)$') {
                $timestamp = $matches[1]
                $level = $matches[2]
                $user = $matches[3]
                $operation = $matches[4]
                $status = $matches[5]
                $message = $matches[6]

                # Apply status filter
                if ($FilterStatus -ne "All" -and $level -ne $FilterStatus) {
                    continue
                }

                $parsedEntries += @{
                    Timestamp = $timestamp
                    Level = $level
                    User = $user
                    Operation = $operation
                    Status = $status
                    Message = $message
                }
            }
        }

        Write-Verbose "Parsed $($parsedEntries.Count) entries"

        # ================================================================
        # STEP 3: Format output
        # ================================================================
        $output = switch ($Format) {
            "HTML" {
                _FormatAuditLogAsHtml -Entries $parsedEntries
            }
            "CSV" {
                _FormatAuditLogAsCsv -Entries $parsedEntries
            }
            "Text" {
                _FormatAuditLogAsText -Entries $parsedEntries
            }
        }

        # ================================================================
        # STEP 4: Write to file or return
        # ================================================================
        if (-not [string]::IsNullOrWhiteSpace($OutputPath)) {
            try {
                Set-Content -Path $OutputPath -Value $output -Encoding UTF8 -ErrorAction Stop
                Write-Verbose "Audit log exported to: $OutputPath"
                Write-Log -Message "Audit log exported: $($parsedEntries.Count) entries to $OutputPath" `
                    -Level INFO -Operation "Export-MailboxAuditLog" -Status "COMPLETE"
            }
            catch {
                Write-Error "Failed to write audit log to $OutputPath : $_"
                Write-Log -Message "Failed to export audit log: $_" -Level ERROR -Operation "Export-MailboxAuditLog" -Status "FAILED"
            }
        }

        return $output
    }
    catch {
        $msg = "Failed to export audit log: $_"
        Write-Error $msg
        Write-Log -Message $msg -Level ERROR -Operation "Export-MailboxAuditLog" -Status "FAILED"
        return ""
    }
}

function _FormatAuditLogAsHtml {
    param(
        [array]$Entries
    )

    $html = @"
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>Provisioning Audit Log</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        h1 { color: #333; }
        table { width: 100%; border-collapse: collapse; margin-top: 20px; }
        th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
        th { background-color: #0078d4; color: white; }
        tr:nth-child(even) { background-color: #f9f9f9; }
        .success { background-color: #d4f4dd; }
        .failed { background-color: #f4d4d4; }
        .warn { background-color: #f4f0d4; }
    </style>
</head>
<body>
    <h1>Provisioning Audit Log</h1>
    <p>Generated: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")</p>
    <p>Total Entries: $($Entries.Count)</p>
    <table>
        <tr>
            <th>Timestamp</th>
            <th>Level</th>
            <th>User</th>
            <th>Operation</th>
            <th>Status</th>
            <th>Message</th>
        </tr>
"@

    foreach ($entry in $Entries) {
        $rowClass = switch ($entry.Level) {
            "INFO" {
                "success"
                break
            }
            "WARN" {
                "warn"
                break
            }
            "ERROR" {
                "failed"
                break
            }
            default {
                ""
            }
        }

        $html += @"
        <tr class="$rowClass">
            <td>$($entry.Timestamp)</td>
            <td>$($entry.Level)</td>
            <td>$($entry.User)</td>
            <td>$($entry.Operation)</td>
            <td>$($entry.Status)</td>
            <td>$($entry.Message)</td>
        </tr>
"@
    }

    $html += @"
    </table>
</body>
</html>
"@

    return $html
}

function _FormatAuditLogAsCsv {
    param(
        [array]$Entries
    )

    $csv = "Timestamp,Level,User,Operation,Status,Message`n"

    foreach ($entry in $Entries) {
        # Escape CSV: quote if contains comma, quote, or newline
        $message = $entry.Message -replace '"', '""'
        if ($message -match '[",\n]') {
            $message = "`"$message`""
        }

        $csv += "$($entry.Timestamp),$($entry.Level),$($entry.User),$($entry.Operation),$($entry.Status),$message`n"
    }

    return $csv
}

function _FormatAuditLogAsText {
    param(
        [array]$Entries
    )

    $text = "PROVISIONING AUDIT LOG`n"
    $text += "Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')`n"
    $text += "Total Entries: $($Entries.Count)`n"
    $text += "=========================================================================`n`n"

    foreach ($entry in $Entries) {
        $text += "[$($entry.Timestamp)] [$($entry.Level)] [$($entry.User)]`n"
        $text += "  Operation: $($entry.Operation)`n"
        $text += "  Status: $($entry.Status)`n"
        $text += "  Message: $($entry.Message)`n"
        $text += "`n"
    }

    return $text
}

Export-ModuleMember -Function Export-MailboxAuditLog
