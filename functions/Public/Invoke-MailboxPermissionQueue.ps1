<#
.SYNOPSIS
Process provisioning backlog queue and assign mailbox permissions

.DESCRIPTION
Processes pending mailboxes from the provisioning backlog queue.
For each mailbox awaiting permission assignment:
1. Attempts to resolve mailbox in Exchange Online
2. Assigns FullAccess + SendAs to ACL group
3. Assigns FullAccess only to Admin group (if provided)
4. Updates backlog status (JSON + CSV export)
5. Manages retry logic (max 5 attempts = 75 min with 15 min intervals)

This function runs on a schedule (ScheduledTask every 15 minutes).
Handles the 60-minute Azure AD Connect sync delay gracefully.

Per ADR-006: Active Directory Integration & Candidate Selection

.PARAMETER BacklogPath
Path to JSON provisioning backlog file
Default: C:\Repos\SharedMailboxProvisioner\data\mailbox-provisioning-queue.json

.PARAMETER MaximumRetries
Maximum number of permission assignment attempts
Default: 5 (which equals ~75 minutes with 15 min intervals)

.PARAMETER CleanupDaysOld
Delete completed entries older than this many days
Default: 30

.EXAMPLE
Invoke-MailboxPermissionQueue

Process all pending mailboxes in backlog queue

.EXAMPLE
Invoke-MailboxPermissionQueue -BacklogPath "C:\custom\backlog.json" -MaximumRetries 8

Use custom backlog file and allow more retries

.NOTES
- Runs as ScheduledTask every 15 minutes
- Handles mailbox not found errors gracefully (continues retrying)
- Updates JSON backlog with retry count and error details
- Exports CSV copy for manual inspection
- Auto-cleans completed entries after 30 days
- Idempotent: safe to run multiple times
#>

function Invoke-MailboxPermissionQueue {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$BacklogPath = "C:\Repos\SharedMailboxProvisioner\data\mailbox-provisioning-queue.json",

        [Parameter(Mandatory = $false)]
        [int]$MaximumRetries = 5,

        [Parameter(Mandatory = $false)]
        [int]$CleanupDaysOld = 30
    )

    Write-Verbose "Starting mailbox permission queue processing"

    try {
        # ================================================================
        # STEP 1: Load and validate backlog
        # ================================================================
        Write-Verbose "Loading provisioning backlog from: $BacklogPath"

        if (-not (Test-Path -Path $BacklogPath)) {
            Write-Verbose "Backlog file not found: $BacklogPath (first run?)"
            Write-Log -Message "Backlog file not found (no pending mailboxes)" `
                -Level INFO -Operation "Invoke-MailboxPermissionQueue" -Status "NO_BACKLOG"
            return [PSCustomObject]@{
                ProcessedCount = 0
                SuccessCount = 0
                FailedCount = 0
                RetryingCount = 0
                Summary = "No backlog file found"
            }
        }

        $backlog = Get-Content -Path $BacklogPath -ErrorAction Stop | ConvertFrom-Json
        Write-Verbose "Backlog loaded: $($backlog.entries.Count) total entries"

        # ================================================================
        # STEP 2: Find pending entries
        # ================================================================
        $pendingEntries = $backlog.entries | Where-Object {
            $_.status -eq "MAILBOX_CREATED_AWAITING_PERMISSIONS"
        }

        if (-not $pendingEntries) {
            Write-Verbose "No pending mailboxes in queue"
            Write-Log -Message "No pending mailboxes in permission queue" `
                -Level INFO -Operation "Invoke-MailboxPermissionQueue" -Status "NO_PENDING"
            return [PSCustomObject]@{
                ProcessedCount = 0
                SuccessCount = 0
                FailedCount = 0
                RetryingCount = 0
                Summary = "No pending mailboxes"
            }
        }

        Convert-ToArray -InputObject $pendingEntries -OutVariable pendingArray | Out-Null
        Write-Verbose "Processing $($pendingArray.Count) pending mailbox(es)"

        # ================================================================
        # STEP 3: Process each pending mailbox
        # ================================================================
        $stats = @{
            processed = 0
            successful = 0
            failed = 0
            retrying = 0
        }

        foreach ($entry in $pendingArray) {
            Write-Verbose "Processing: $($entry.samAccountName)"

            $stats.processed++

            # Check retry limit
            if ($entry.retryCount -ge $MaximumRetries) {
                Write-Verbose "Max retries exceeded for $($entry.samAccountName)"

                $entry.status = "FAILED_PERMISSIONS"
                $entry.completedAt = (Get-Date).ToUniversalTime().ToString("o")
                $entry.errors += @{
                    timestamp = (Get-Date).ToUniversalTime().ToString("o")
                    errorCode = "MaxRetriesExceeded"
                    errorMessage = "Max retries ($MaximumRetries) exceeded. Mailbox never appeared in EXO."
                }
                $entry.notes = "Admin intervention required - check EXO sync status"

                Write-Log -Message "Max retries exceeded for mailbox: $($entry.mailboxName)" `
                    -Level ERROR -Operation "Invoke-MailboxPermissionQueue" -Status "MAX_RETRIES"

                $stats.failed++
                continue
            }

            # Try to assign permissions
            $permissionResult = _AssignMailboxPermissions -Entry $entry

            if ($permissionResult.Success) {
                # Success: Update status
                $entry.status = "PERMISSIONS_SET"
                $entry.completedAt = (Get-Date).ToUniversalTime().ToString("o")
                $entry.notes = "Permissions assigned successfully"

                Write-Verbose "Permissions assigned: $($entry.mailboxName)"
                Write-Log -Message "Mailbox permissions assigned: $($entry.mailboxName)" `
                    -Level INFO -Operation "Invoke-MailboxPermissionQueue" -Status "PERMISSIONS_SET"

                $stats.successful++

                # Update AD attribute (final status)
                _UpdateADMailboxStatus -SamAccountName $entry.samAccountName -Status "SUCCESS"
            }
            else {
                # Failed: Increment retry count and update timestamp
                $entry.lastAttemptAt = (Get-Date).ToUniversalTime().ToString("o")
                $entry.retryCount++
                $entry.errors += @{
                    timestamp = (Get-Date).ToUniversalTime().ToString("o")
                    errorCode = $permissionResult.ErrorCode
                    errorMessage = $permissionResult.ErrorMessage
                }

                Write-Verbose "Permission assignment failed (retry $($entry.retryCount)/$MaximumRetries): $($permissionResult.ErrorMessage)"
                Write-Log -Message "Permission assignment failed (retry $($entry.retryCount)/$MaximumRetries): $($entry.mailboxName) - $($permissionResult.ErrorMessage)" `
                    -Level WARN -Operation "Invoke-MailboxPermissionQueue" -Status "RETRY"

                $stats.retrying++
            }
        }

        # ================================================================
        # STEP 4: Update metadata
        # ================================================================
        $backlog.metadata.lastUpdated = (Get-Date).ToUniversalTime().ToString("o")
        $backlog.metadata.pendingEntries = ($backlog.entries | Where-Object { $_.status -eq "MAILBOX_CREATED_AWAITING_PERMISSIONS" }).Count
        $backlog.metadata.completedEntries = ($backlog.entries | Where-Object { $_.status -eq "PERMISSIONS_SET" }).Count
        $backlog.metadata.failedEntries = ($backlog.entries | Where-Object { $_.status -eq "FAILED_PERMISSIONS" }).Count

        # ================================================================
        # STEP 5: Cleanup old entries
        # ================================================================
        Write-Verbose "Cleaning up entries older than $CleanupDaysOld days"

        $cutoffDate = (Get-Date).AddDays(-$CleanupDaysOld)
        $entriesToDelete = @()

        foreach ($entry in $backlog.entries) {
            if ($entry.status -eq "PERMISSIONS_SET" -and $entry.completedAt) {
                $completedDate = [DateTime]::Parse($entry.completedAt)
                if ($completedDate -lt $cutoffDate) {
                    $entriesToDelete += $entry.id
                }
            }
        }

        if ($entriesToDelete.Count -gt 0) {
            Write-Verbose "Deleting $($entriesToDelete.Count) old entries"
            $backlog.entries = @($backlog.entries | Where-Object { $_.id -notin $entriesToDelete })
            Write-Log -Message "Deleted $($entriesToDelete.Count) completed entries older than $CleanupDaysOld days" `
                -Level INFO -Operation "Invoke-MailboxPermissionQueue" -Status "CLEANUP"
        }

        # ================================================================
        # STEP 6: Save backlog and export CSV
        # ================================================================
        Write-Verbose "Saving updated backlog to JSON"
        $backlog | ConvertTo-Json -Depth 10 | Set-Content -Path $BacklogPath -Force

        Write-Verbose "Exporting backlog to CSV"
        _ExportBacklogToCSV -Backlog $backlog -BacklogPath $BacklogPath

        # ================================================================
        # STEP 7: Return summary
        # ================================================================
        $summary = "Processed: $($stats.processed) | Success: $($stats.successful) | Failed: $($stats.failed) | Retrying: $($stats.retrying)"

        Write-Verbose "Queue processing complete: $summary"
        Write-Log -Message "Permission queue processing complete: $summary" `
            -Level INFO -Operation "Invoke-MailboxPermissionQueue" -Status "COMPLETE"

        return [PSCustomObject]@{
            ProcessedCount = $stats.processed
            SuccessCount = $stats.successful
            FailedCount = $stats.failed
            RetryingCount = $stats.retrying
            Summary = $summary
            BacklogPath = $BacklogPath
            CSVPath = $BacklogPath -replace '\.json$', '.csv'
        }

    }
    catch {
        $errorMessage = $_.Exception.Message
        Write-Error "Failed to process permission queue: $errorMessage"
        Write-Log -Message "Permission queue processing failed: $errorMessage" `
            -Level ERROR -Operation "Invoke-MailboxPermissionQueue" -Status "ERROR"
        return $null
    }
}

function _AssignMailboxPermissions {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        $Entry
    )

    Write-Verbose "Assigning permissions to: $($entry.mailboxName)"

    try {
        # Try to connect to Exchange Online if not already connected
        $exoSession = Get-PSSession -Name "*ExchangeOnline*" -ErrorAction SilentlyContinue

        if (-not $exoSession) {
            Write-Verbose "No EXO session found, attempting connection"
            Connect-ExchangeOnline -ErrorAction Stop | Out-Null
        }

        # ================================================================
        # Assign FullAccess + SendAs to ACL Group
        # ================================================================
        Write-Verbose "Assigning FullAccess to ACL group: $($entry.aclGroup)"

        Add-MailboxPermission -Identity $entry.mailboxName `
            -User $entry.aclGroup `
            -AccessRights FullAccess `
            -InheritanceType All `
            -AutoMapping $false `
            -ErrorAction Stop | Out-Null

        Write-Verbose "Assigning SendAs to ACL group: $($entry.aclGroup)"

        Add-RecipientPermission -Identity $entry.mailboxName `
            -Trustee $entry.aclGroup `
            -AccessRights SendAs `
            -ErrorAction Stop | Out-Null

        # ================================================================
        # Assign FullAccess ONLY to Admin Group (if provided)
        # ================================================================
        if (-not [string]::IsNullOrWhiteSpace($entry.adminGroup)) {
            Write-Verbose "Assigning FullAccess (no SendAs) to Admin group: $($entry.adminGroup)"

            Add-MailboxPermission -Identity $entry.mailboxName `
                -User $entry.adminGroup `
                -AccessRights FullAccess `
                -InheritanceType All `
                -AutoMapping $false `
                -ErrorAction Stop | Out-Null
        }

        Write-Verbose "Permissions assigned successfully"

        return [PSCustomObject]@{
            Success = $true
            ErrorCode = $null
            ErrorMessage = $null
        }

    }
    catch {
        # Handle specific error scenarios
        if ($_.Exception.Message -match "object must exist before it can be modified" -or
            $_.Exception.Message -match "not found" -or
            $_.Exception.Message -match "ObjectNotFound") {

            # Mailbox not yet visible in EXO (sync lag)
            Write-Verbose "Mailbox not yet visible in Exchange Online (sync lag)"

            return [PSCustomObject]@{
                Success = $false
                ErrorCode = "MailboxNotFound"
                ErrorMessage = "Mailbox not found in Exchange Online (Azure AD Connect sync lag)"
            }
        }

        # Other errors
        Write-Verbose "Permission assignment error: $($_.Exception.Message)"

        return [PSCustomObject]@{
            Success = $false
            ErrorCode = "PermissionError"
            ErrorMessage = $_.Exception.Message
        }
    }
}

function _UpdateADMailboxStatus {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$SamAccountName,

        [Parameter(Mandatory = $true)]
        [ValidateSet("SUCCESS", "FAIL")]
        [string]$Status
    )

    try {
        $adUser = Get-ADObject -Filter "sAMAccountName -eq '$SamAccountName' -and objectClass -eq 'user'" `
            -ErrorAction SilentlyContinue

        if ($adUser) {
            Set-ADUser -Identity $adUser -Replace @{ extensionAttribute1 = $Status } -ErrorAction Stop
            Write-Verbose "AD attribute updated: $SamAccountName = $Status"
        }
    }
    catch {
        Write-Warning "Failed to update AD attribute for $SamAccountName : $_"
    }
}

function _ExportBacklogToCSV {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        $Backlog,

        [Parameter(Mandatory = $true)]
        [string]$BacklogPath
    )

    $csvPath = $BacklogPath -replace '\.json$', '.csv'

    $exportData = $backlog.entries | Select-Object -Property @(
        "samAccountName"
        "aclGroup"
        "adminGroup"
        "mailboxName"
        "primarySmtpAddress"
        "status"
        "createdAt"
        "lastAttemptAt"
        "retryCount"
        "maxRetries"
        "completedAt"
        @{Name = "ErrorCount"; Expression = { $_.errors.Count } },
        @{
            Name = "LastError"
            Expression = {
                if ($_.errors.Count -gt 0) {
                    $_.errors[-1].errorMessage
                }
                else {
                    ""
                }
            }
        },
        @{Name = "Notes"; Expression = { $_.notes } }
    )

    $exportData | Export-Csv -Path $csvPath -NoTypeInformation -Force

    Write-Verbose "Backlog exported to CSV: $csvPath"
}

function _EnsureArray {
    param($InputObject)
    if ($InputObject -is [System.Collections.IEnumerable] -and $InputObject -isnot [string]) {
        return @($InputObject)
    }
    return @($InputObject)
}

Export-ModuleMember -Function Invoke-MailboxPermissionQueue
