<#
.SYNOPSIS
Diagnose provisioning failures and suggest remediation steps.

.DESCRIPTION
Analyzes failed mailbox entries to identify root cause and recommend
specific remediation steps (manual fixes, retries, escalation).

Per ADR-004: Logging & Audit Trail

.PARAMETER SamAccountName
SamAccountName of failed mailbox to diagnose.

.PARAMETER DiagnoseAll
Analyze all failed mailboxes and provide summary report.

.PARAMETER BacklogPath
Path to JSON provisioning backlog file.

.EXAMPLE
Resolve-MailboxProvisioningFailure -SamAccountName smbx_001

Diagnose single failed mailbox and suggest fixes.

.EXAMPLE
Resolve-MailboxProvisioningFailure -DiagnoseAll | Format-Table

Analyze all failures and show summary.

.NOTES
Reads from JSON backlog only - no EXO/AD calls.
Suggests manual remediation or retry triggers.
#>

function Resolve-MailboxProvisioningFailure {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$SamAccountName = "",

        [Parameter(Mandatory = $false)]
        [switch]$DiagnoseAll,

        [Parameter(Mandatory = $false)]
        [string]$BacklogPath = ""
    )

    Write-Verbose "Resolving provisioning failures"

    if ([string]::IsNullOrWhiteSpace($BacklogPath)) {
        $BacklogPath = Join-Path (Split-Path $PSScriptRoot -Parent) "data\mailbox-provisioning-queue.json"
    }

    try {
        # ================================================================
        # STEP 1: Load backlog
        # ================================================================
        if (-not (Test-Path $BacklogPath)) {
            Write-Error "Backlog not found: $BacklogPath"
            return @()
        }

        $backlogContent = Get-Content -Path $BacklogPath -Raw
        $backlogData = $backlogContent | ConvertFrom-Json

        if (-not $backlogData) {
            Write-Output "No failed mailboxes to diagnose"
            return @()
        }

        if ($backlogData -isnot [System.Collections.IEnumerable] -or $backlogData -is [string]) {
            $backlogData = @($backlogData)
        }

        # ================================================================
        # STEP 2: Filter failed entries
        # ================================================================
        $failedEntries = @($backlogData | Where-Object { $_.Status -eq "FAILED_PERMISSIONS" -or $_.Status -eq "FAILED_MAILBOX" })

        if ($failedEntries.Count -eq 0) {
            Write-Output "No failed mailboxes found"
            return @()
        }

        # Filter by SamAccountName if provided
        if (-not [string]::IsNullOrWhiteSpace($SamAccountName)) {
            $failedEntries = @($failedEntries | Where-Object { $_.SamAccountName -eq $SamAccountName })
        }

        # ================================================================
        # STEP 3: Analyze each failure
        # ================================================================
        $diagnostics = @()

        foreach ($entry in $failedEntries) {
            $remediation = _DiagnoseFailure -Entry $entry

            $diagnostics += [PSCustomObject]@{
                SamAccountName = $entry.SamAccountName
                DisplayName = $entry.DisplayName
                ErrorCode = $entry.ErrorCode
                ErrorMessage = $entry.ErrorMessage
                RetryCount = if ($entry.RetryCount) { $entry.RetryCount } else { 0 }
                MaxRetries = if ($entry.MaxRetries) { $entry.MaxRetries } else { 5 }
                CanRetry = $remediation.CanRetry
                RecommendedAction = $remediation.Action
                Details = $remediation.Details
            }
        }

        Write-Log -Message "Failure diagnosis: Analyzed $($diagnostics.Count) failed mailbox(es)" `
            -Level INFO -Operation "Resolve-MailboxProvisioningFailure" -Status "COMPLETE"

        return $diagnostics
    }
    catch {
        $msg = "Failed to diagnose provisioning failures: $_"
        Write-Error $msg
        Write-Log -Message $msg -Level ERROR -Operation "Resolve-MailboxProvisioningFailure" -Status "FAILED"
        return @()
    }
}

function _DiagnoseFailure {
    param($Entry)

    $errorCode = $Entry.ErrorCode
    $retryCount = if ($Entry.RetryCount) { $Entry.RetryCount } else { 0 }
    $maxRetries = if ($Entry.MaxRetries) { $Entry.MaxRetries } else { 5 }

    # Diagnose by error code
    $diagnosis = switch ($errorCode) {
        "MailboxNotFound" {
            @{
                CanRetry = $true
                Action = "RETRY: Wait 60 minutes for EXO sync, then retry provisioning"
                Details = "Mailbox created on-prem but not visible in EXO yet (Azure AD Connect sync pending)"
            }
        }

        "PermissionError" {
            @{
                CanRetry = $true
                Action = "RETRY: Check service account has permissions to ACL group, then retry"
                Details = "Service account likely lacks permissions to modify group membership"
            }
        }

        "GroupNotFound" {
            @{
                CanRetry = $false
                Action = "ESCALATE: ACL group does not exist. Create group or update candidate ACLGroup"
                Details = "ACL group was not found in AD. Check group name spelling or create group first"
            }
        }

        "InvalidMailbox" {
            @{
                CanRetry = $false
                Action = "ESCALATE: Mailbox validation failed. Check SAM prefix, email format"
                Details = "Candidate data invalid (check SamAccountName prefix 'smbx_', email format)"
            }
        }

        "ADConnectDelay" {
            @{
                CanRetry = $true
                Action = "WAIT & RETRY: Azure AD Connect sync can take up to 60 min, retry after delay"
                Details = "Candidate not yet visible in Azure AD. Wait for next sync cycle"
            }
        }

        default {
            @{
                CanRetry = if ($retryCount -lt $maxRetries) { $true } else { $false }
                Action = if ($retryCount -lt $maxRetries) { "RETRY: Automatic retry available" } else { "ESCALATE: Max retries reached, manual intervention required" }
                Details = "Unknown error. Check logs for detailed message"
            }
        }
    }

    # Add retry availability
    if ($diagnosis.CanRetry -and $retryCount -ge $maxRetries) {
        $diagnosis.CanRetry = $false
        $diagnosis.Action = "ESCALATE: Max retries ($maxRetries) exceeded"
        $diagnosis.Details = "Automatic retries exhausted. Requires manual investigation and reset"
    }

    return $diagnosis
}

Export-ModuleMember -Function Resolve-MailboxProvisioningFailure
