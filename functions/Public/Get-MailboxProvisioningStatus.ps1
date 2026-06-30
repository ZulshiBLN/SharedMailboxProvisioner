<#
.SYNOPSIS
Query provisioning status of specific mailbox(es) or batch.

.DESCRIPTION
Retrieves detailed status information including timeline of operations,
current state, error details, and retry history from the provisioning backlog.

Per ADR-004: Logging & Audit Trail

.PARAMETER SamAccountName
SamAccountName to query (e.g., 'smbx_001'). If empty, returns all pending mailboxes.

.PARAMETER ShowTimeline
Include timeline of all operations (created, attempted, retried, etc.)

.PARAMETER BacklogPath
Path to JSON provisioning backlog file.

.EXAMPLE
Get-MailboxProvisioningStatus -SamAccountName smbx_001

Get status of single mailbox.

.EXAMPLE
Get-MailboxProvisioningStatus -ShowTimeline | Format-Table

Get all pending mailboxes with timeline.

.NOTES
Reads from JSON backlog (created by New-SharedMailboxRemote).
No external dependencies (EXO, AD).
#>

function Get-MailboxProvisioningStatus {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$SamAccountName = "",

        [Parameter(Mandatory = $false)]
        [switch]$ShowTimeline,

        [Parameter(Mandatory = $false)]
        [string]$BacklogPath = ""
    )

    Write-Verbose "Querying provisioning status: $SamAccountName"

    if ([string]::IsNullOrWhiteSpace($BacklogPath)) {
        $BacklogPath = Join-Path (Split-Path $PSScriptRoot -Parent) "data\mailbox-provisioning-queue.json"
    }

    try {
        # ================================================================
        # STEP 1: Load backlog
        # ================================================================
        if (-not (Test-Path $BacklogPath)) {
            Write-Error "Backlog not found: $BacklogPath"
            Write-Log -Message "Status query: Backlog file not found" `
                -Level ERROR -Operation "Get-MailboxProvisioningStatus" -Status "NO_BACKLOG"
            return @()
        }

        $backlogContent = Get-Content -Path $BacklogPath -Raw
        $backlogData = $backlogContent | ConvertFrom-Json

        if (-not $backlogData) {
            Write-Verbose "Backlog is empty"
            return @()
        }

        if ($backlogData -isnot [System.Collections.IEnumerable] -or $backlogData -is [string]) {
            $backlogData = @($backlogData)
        }

        # ================================================================
        # STEP 2: Filter by SamAccountName if provided
        # ================================================================
        if ([string]::IsNullOrWhiteSpace($SamAccountName)) {
            $entries = @($backlogData)
            Write-Verbose "Returning all $($entries.Count) backlog entries"
        }
        else {
            $entries = @($backlogData | Where-Object { $_.SamAccountName -eq $SamAccountName })
            Write-Verbose "Found $($entries.Count) entries for $SamAccountName"
        }

        if ($entries.Count -eq 0) {
            Write-Verbose "No entries found matching criteria"
            return @()
        }

        # ================================================================
        # STEP 3: Format status for each entry
        # ================================================================
        $results = @()

        foreach ($entry in $entries) {
            $statusObj = [PSCustomObject]@{
                SamAccountName = $entry.SamAccountName
                DisplayName = $entry.DisplayName
                Email = $entry.Email
                CurrentStatus = $entry.Status
                ErrorCode = if ([string]::IsNullOrWhiteSpace($entry.ErrorCode)) { "None" } else { $entry.ErrorCode }
                ErrorMessage = if ([string]::IsNullOrWhiteSpace($entry.ErrorMessage)) { "None" } else { $entry.ErrorMessage }
                CreatedAt = $entry.CreatedAt
                CompletedAt = if ([string]::IsNullOrWhiteSpace($entry.CompletedAt)) { "Pending" } else { $entry.CompletedAt }
                RetryCount = if ($entry.RetryCount) { $entry.RetryCount } else { 0 }
                MaxRetries = if ($entry.MaxRetries) { $entry.MaxRetries } else { 5 }
                LastRetryAt = if ([string]::IsNullOrWhiteSpace($entry.LastRetryAt)) { "Never" } else { $entry.LastRetryAt }
            }

            # Add timeline if requested
            if ($ShowTimeline) {
                $timeline = @()

                if (-not [string]::IsNullOrWhiteSpace($entry.CreatedAt)) {
                    $timeline += "[CREATED] $($entry.CreatedAt)"
                }

                if (-not [string]::IsNullOrWhiteSpace($entry.MailboxCreatedAt)) {
                    $timeline += "[MAILBOX_CREATED] $($entry.MailboxCreatedAt)"
                }

                if (-not [string]::IsNullOrWhiteSpace($entry.LastRetryAt)) {
                    $timeline += "[RETRIED] $($entry.LastRetryAt) (attempt $($entry.RetryCount) of $($entry.MaxRetries))"
                }

                if (-not [string]::IsNullOrWhiteSpace($entry.CompletedAt)) {
                    $timeline += "[COMPLETED] $($entry.CompletedAt)"
                }

                $statusObj | Add-Member -MemberType NoteProperty -Name Timeline -Value ($timeline -join " → ")
            }

            $results += $statusObj
        }

        Write-Log -Message "Status query: Retrieved $($results.Count) mailbox status record(s)" `
            -Level INFO -Operation "Get-MailboxProvisioningStatus" -Status "SUCCESS"

        return $results
    }
    catch {
        $msg = "Failed to query provisioning status: $_"
        Write-Error $msg
        Write-Log -Message $msg -Level ERROR -Operation "Get-MailboxProvisioningStatus" -Status "FAILED"
        return @()
    }
}

Export-ModuleMember -Function Get-MailboxProvisioningStatus
