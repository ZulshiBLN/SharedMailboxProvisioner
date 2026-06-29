<#
.SYNOPSIS
Orchestrate complete shared mailbox provisioning pipeline

.DESCRIPTION
Main entry point for batch shared mailbox provisioning.
Orchestrates the complete pipeline from candidate discovery through mailbox creation
and permission assignment.

Pipeline workflow:
1. Discover shared mailbox candidates in Active Directory
2. Validate candidates with associated ACL groups
3. Create remote shared mailboxes on on-premises Exchange
4. Add mailboxes to provisioning queue for permission assignment
5. Process permission queue (async retry logic)
6. Generate audit trail and summary report

This function serves as the orchestration layer that coordinates all
provisioning components (Tier 4, Tier 5.0, Tier 5.2).

Per ADR-006: Active Directory Integration & Candidate Selection

.PARAMETER SamAccountNamePrefix
Candidate user SAM account name prefix (default: "smbx_")

.PARAMETER DescriptionStartsWith
Candidate description pattern (default: "Shared Mailbox Persona")

.PARAMETER SearchBase
Active Directory search base (default: entire domain)

.PARAMETER SkipPermissionQueue
If true, skip permission queue processing (default: false)
Useful for testing mailbox creation in isolation

.PARAMETER BacklogPath
Path to JSON provisioning backlog
Default: C:\Repos\SharedMailboxProvisioner\data\mailbox-provisioning-queue.json

.PARAMETER GenerateReport
If true, create HTML audit report (default: true)

.EXAMPLE
Invoke-SharedMailboxProvisioning

Execute complete provisioning pipeline with default parameters

.EXAMPLE
Invoke-SharedMailboxProvisioning -SkipPermissionQueue $true

Create mailboxes only (skip permission assignment for testing)

.NOTES
- Idempotent: safe to run multiple times
- Logging: All operations logged via Write-Log
- Error handling: Continues processing on errors (non-blocking)
- Report: Generates summary report on completion
#>

function Invoke-SharedMailboxProvisioning {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$SamAccountNamePrefix = "smbx_",

        [Parameter(Mandatory = $false)]
        [string]$DescriptionStartsWith = "Shared Mailbox Persona",

        [Parameter(Mandatory = $false)]
        [string]$SearchBase = "",

        [Parameter(Mandatory = $false)]
        [bool]$SkipPermissionQueue = $false,

        [Parameter(Mandatory = $false)]
        [string]$BacklogPath = "C:\Repos\SharedMailboxProvisioner\data\mailbox-provisioning-queue.json",

        [Parameter(Mandatory = $false)]
        [bool]$GenerateReport = $true
    )

    Write-Verbose "Starting shared mailbox provisioning pipeline"
    $pipelineStartTime = Get-Date

    try {
        # ================================================================
        # STEP 1: Discover candidates with valid ACL groups
        # ================================================================
        Write-Verbose "Step 1: Discovering candidates"
        Write-Output ""
        Write-Output "========================================="
        Write-Output "Shared Mailbox Provisioning Pipeline"
        Write-Output "========================================="
        Write-Output ""
        Write-Output "Step 1: Discovering candidates..."

        $getCandidatesParams = @{
            SamAccountNamePrefix = $SamAccountNamePrefix
            DescriptionStartsWith = $DescriptionStartsWith
            ValidateAll = $true
        }

        if (-not [string]::IsNullOrWhiteSpace($SearchBase)) {
            $getCandidatesParams['SearchBase'] = $SearchBase
        }

        $candidates = Get-SharedMailboxCandidatesWithGroups @getCandidatesParams

        if (-not $candidates) {
            Write-Output "No candidates found matching criteria."
            Write-Log -Message "Provisioning pipeline: No candidates found" `
                -Level INFO -Operation "Invoke-SharedMailboxProvisioning" -Status "NO_CANDIDATES"

            return [PSCustomObject]@{
                Status = "COMPLETE"
                StartTime = $pipelineStartTime
                EndTime = (Get-Date)
                CandidatesFound = 0
                MailboxesCreated = 0
                PermissionsAssigned = 0
                Errors = @()
                Summary = "No candidates found"
            }
        }

        Convert-ToArray -InputObject $candidates -OutVariable candidateArray | Out-Null
        Write-Output "Found $($candidateArray.Count) candidate(s) with valid ACL groups"
        Write-Log -Message "Provisioning pipeline: Found $($candidateArray.Count) candidates" `
            -Level INFO -Operation "Invoke-SharedMailboxProvisioning" -Status "CANDIDATES_FOUND"

        # ================================================================
        # STEP 2: Create remote mailboxes
        # ================================================================
        Write-Output ""
        Write-Output "Step 2: Creating remote mailboxes..."

        $mailboxStats = @{
            created = 0
            failed = 0
            errors = @()
        }

        foreach ($candidate in $candidateArray) {
            Write-Verbose "Creating mailbox for: $($candidate.SamAccountName)"

            try {
                $mailboxResult = New-SharedMailboxRemote `
                    -SamAccountName $candidate.SamAccountName `
                    -DisplayName $candidate.DisplayName `
                    -PrimarySmtpAddress $candidate.Mail `
                    -RemoteRoutingAddress "$($candidate.SamAccountName)@ethz.mail.onmicrosoft.com" `
                    -ACLGroupName $candidate.ACLGroupName `
                    -AdminGroupName $candidate.AdminGroupName `
                    -BacklogPath $BacklogPath

                if ($mailboxResult) {
                    $mailboxStats.created++
                    Write-Output "  [OK] Mailbox created: $($candidate.DisplayName)"
                }
                else {
                    $mailboxStats.failed++
                    $mailboxStats.errors += "Failed to create mailbox: $($candidate.SamAccountName)"
                    Write-Output "  [ERROR] Failed to create mailbox: $($candidate.DisplayName)"
                }
            }
            catch {
                $mailboxStats.failed++
                $mailboxStats.errors += "Exception creating mailbox $($candidate.SamAccountName): $_"
                Write-Output "  [ERROR] Exception: $($_.Exception.Message)"
                Write-Log -Message "Exception creating mailbox $($candidate.SamAccountName): $_" `
                    -Level ERROR -Operation "Invoke-SharedMailboxProvisioning" -Status "MAILBOX_ERROR"
            }
        }

        Write-Output "Created $($mailboxStats.created) mailbox(es), $($mailboxStats.failed) failed"

        # ================================================================
        # STEP 3: Process permission queue
        # ================================================================
        if ($SkipPermissionQueue) {
            Write-Output ""
            Write-Output "Step 3: Skipping permission queue (test mode)"
            Write-Output "Note: Permissions will be assigned later when queue is processed"

            $permissionStats = @{
                processed = 0
                successful = 0
                failed = 0
                retrying = 0
            }
        }
        else {
            Write-Output ""
            Write-Output "Step 3: Processing permission queue..."

            $queueResult = Invoke-MailboxPermissionQueue -BacklogPath $BacklogPath

            if ($queueResult) {
                $permissionStats = @{
                    processed = $queueResult.ProcessedCount
                    successful = $queueResult.SuccessCount
                    failed = $queueResult.FailedCount
                    retrying = $queueResult.RetryingCount
                }

                Write-Output "Permission queue processed: $($queueResult.Summary)"
            }
            else {
                $permissionStats = @{
                    processed = 0
                    successful = 0
                    failed = 0
                    retrying = 0
                }
                Write-Output "Permission queue processing failed"
            }
        }

        # ================================================================
        # STEP 4: Generate summary report
        # ================================================================
        Write-Output ""
        Write-Output "========================================="
        Write-Output "Provisioning Summary"
        Write-Output "========================================="
        Write-Output ""
        Write-Output "Candidates Found: $($candidateArray.Count)"
        Write-Output "Mailboxes Created: $($mailboxStats.created)"
        Write-Output "Mailbox Failures: $($mailboxStats.failed)"
        Write-Output "Permissions Assigned: $($permissionStats.successful)"
        Write-Output "Permission Retries: $($permissionStats.retrying)"
        Write-Output "Permission Failures: $($permissionStats.failed)"

        if ($mailboxStats.errors.Count -gt 0) {
            Write-Output ""
            Write-Output "Errors:"
            foreach ($error in $mailboxStats.errors) {
                Write-Output "  - $error"
            }
        }

        $pipelineEndTime = Get-Date
        $duration = $pipelineEndTime - $pipelineStartTime

        Write-Output ""
        Write-Output "Pipeline Duration: $($duration.TotalSeconds) seconds"
        Write-Output ""

        # ================================================================
        # STEP 5: Return summary
        # ================================================================
        Write-Log -Message "Provisioning pipeline complete: $($mailboxStats.created) created, $($permissionStats.successful) permissions assigned" `
            -Level INFO -Operation "Invoke-SharedMailboxProvisioning" -Status "COMPLETE"

        return [PSCustomObject]@{
            Status = "COMPLETE"
            StartTime = $pipelineStartTime
            EndTime = $pipelineEndTime
            Duration = $duration
            CandidatesFound = $candidateArray.Count
            MailboxesCreated = $mailboxStats.created
            MailboxesFailed = $mailboxStats.failed
            PermissionsAssigned = $permissionStats.successful
            PermissionsRetrying = $permissionStats.retrying
            PermissionsFailed = $permissionStats.failed
            Errors = $mailboxStats.errors
            Summary = "Created $($mailboxStats.created)/$($candidateArray.Count) mailboxes, assigned $($permissionStats.successful) permissions"
        }

    }
    catch {
        $errorMessage = $_.Exception.Message
        Write-Error "Provisioning pipeline failed: $errorMessage"
        Write-Log -Message "Provisioning pipeline failed: $errorMessage" `
            -Level ERROR -Operation "Invoke-SharedMailboxProvisioning" -Status "PIPELINE_ERROR"

        return [PSCustomObject]@{
            Status = "FAILED"
            StartTime = $pipelineStartTime
            EndTime = (Get-Date)
            Error = $errorMessage
            Summary = "Pipeline failed with error: $errorMessage"
        }
    }
}

function Convert-ToArray {
    param($InputObject)
    if ($InputObject -is [System.Collections.IEnumerable] -and $InputObject -isnot [string]) {
        return @($InputObject)
    }
    return @($InputObject)
}

Export-ModuleMember -Function Invoke-SharedMailboxProvisioning
