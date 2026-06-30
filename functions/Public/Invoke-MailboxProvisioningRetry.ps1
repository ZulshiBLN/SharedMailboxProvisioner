<#
.SYNOPSIS
Manually retry failed mailbox provisioning.

.DESCRIPTION
Triggers manual retry for failed mailboxes, respecting max retry limit.
Logs retry reason and outcome for audit trail.

.PARAMETER SamAccountName
SamAccountName(s) to retry (comma-separated).

.PARAMETER RetryAll
Retry all failed mailboxes (respecting max retry limit).

.PARAMETER Force
Override max retry limit (use with caution - may retry exhausted items).

.EXAMPLE
Invoke-MailboxProvisioningRetry -SamAccountName smbx_001

Manually retry single mailbox.

.EXAMPLE
Invoke-MailboxProvisioningRetry -RetryAll

Retry all failed mailboxes.

.NOTES
Updates backlog with retry timestamp and increments retry count.
#>

function Invoke-MailboxProvisioningRetry {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$SamAccountName = "",

        [Parameter(Mandatory = $false)]
        [switch]$RetryAll,

        [Parameter(Mandatory = $false)]
        [switch]$Force,

        [Parameter(Mandatory = $false)]
        [string]$BacklogPath = ""
    )

    Write-Verbose "Invoking manual provisioning retry"

    if ([string]::IsNullOrWhiteSpace($BacklogPath)) {
        $BacklogPath = Join-Path (Split-Path $PSScriptRoot -Parent) "data\mailbox-provisioning-queue.json"
    }

    try {
        if (-not (Test-Path $BacklogPath)) {
            Write-Error "Backlog not found: $BacklogPath"
            return $false
        }

        $backlogContent = Get-Content -Path $BacklogPath -Raw
        $backlogData = $backlogContent | ConvertFrom-Json

        if (-not $backlogData) {
            Write-Output "No entries to retry"
            return $false
        }

        if ($backlogData -isnot [System.Collections.IEnumerable] -or $backlogData -is [string]) {
            $backlogData = @($backlogData)
        }

        # Filter entries to retry
        $toRetry = @()

        if ($RetryAll) {
            $toRetry = @($backlogData | Where-Object { $_.Status -eq "FAILED_PERMISSIONS" -or $_.Status -eq "FAILED_MAILBOX" })
        }
        elseif (-not [string]::IsNullOrWhiteSpace($SamAccountName)) {
            $toRetry = @($backlogData | Where-Object { $_.SamAccountName -eq $SamAccountName })
        }
        else {
            Write-Error "Specify -SamAccountName or -RetryAll"
            return $false
        }

        if ($toRetry.Count -eq 0) {
            Write-Output "No entries found to retry"
            return $false
        }

        # Update entries
        $retried = 0
        $skipped = 0

        foreach ($entry in $toRetry) {
            $retryCount = if ($entry.RetryCount) { $entry.RetryCount } else { 0 }
            $maxRetries = if ($entry.MaxRetries) { $entry.MaxRetries } else { 5 }

            if ($retryCount -ge $maxRetries -and -not $Force) {
                Write-Verbose "Skipping $($entry.SamAccountName): Max retries ($maxRetries) reached"
                $skipped++
                continue
            }

            # Update entry
            if (-not ($entry | Get-Member -Name "RetryCount")) {
                $entry | Add-Member -MemberType NoteProperty -Name "RetryCount" -Value 0
            }
            if (-not ($entry | Get-Member -Name "LastRetryAt")) {
                $entry | Add-Member -MemberType NoteProperty -Name "LastRetryAt" -Value $null
            }

            $entry.RetryCount = $retryCount + 1
            $entry.LastRetryAt = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            $entry.Status = "PENDING_RETRY"

            $retried++
        }

        # Write back to backlog
        if ($retried -gt 0) {
            $backlogData | ConvertTo-Json -Depth 10 | Set-Content -Path $BacklogPath

            Write-Output "Retry triggered: $retried mailbox(es)"
            Write-Log -Message "Manual retry: $retried mailbox(es) queued for retry (skipped: $skipped)" `
                -Level INFO -Operation "Invoke-MailboxProvisioningRetry" -Status "RETRY_QUEUED"

            return $true
        }
        else {
            Write-Output "No entries were retried"
            return $false
        }
    }
    catch {
        $msg = "Failed to invoke retry: $_"
        Write-Error $msg
        Write-Log -Message $msg -Level ERROR -Operation "Invoke-MailboxProvisioningRetry" -Status "FAILED"
        return $false
    }
}

Export-ModuleMember -Function Invoke-MailboxProvisioningRetry
