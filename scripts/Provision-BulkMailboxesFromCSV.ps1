<#
.SYNOPSIS
Manual bulk provisioning of shared mailboxes from CSV file.

.DESCRIPTION
CLI entry point for administrators to bulk provision shared mailboxes from CSV.
This is a MANUAL ADMIN TOOL - NOT automated by ScheduledTask.

Workflow:
1. Import candidates from CSV file
2. Validate candidates and check for conflicts (dry-run)
3. Display impact analysis to admin
4. Request explicit confirmation before provisioning
5. Provision each candidate via standard functions
6. Log all operations for audit trail

Use for: Testing, migrations, special cases, bulk corrections
NOT for: Production automation (use Invoke-SharedMailboxProvisioning via ScheduledTask)

Per CLAUDE.md: Manual process, never scheduled

.PARAMETER CsvPath
Full path to CSV file with candidate data.

.PARAMETER DryRun
If $true, show preview only (no provisioning). Default: $true
Recommended: Always run with -DryRun $true first to review impact.

.PARAMETER SearchBase
LDAP search base for AD validation (optional).

.PARAMETER SkipPermissionQueue
If $true, create mailboxes only (skip permission assignment). Default: $false

.PARAMETER BacklogPath
Path to provisioning queue JSON file. Default: data/mailbox-provisioning-queue.json

.PARAMETER Confirm
If $true, require explicit yes/no before provisioning. Default: $true

.EXAMPLE
# Preview mode - show what would happen (recommended first step)
.\Provision-BulkMailboxesFromCSV.ps1 -CsvPath "bulk-mailboxes.csv" -DryRun $true

# Actual provisioning (requires confirmation)
.\Provision-BulkMailboxesFromCSV.ps1 -CsvPath "bulk-mailboxes.csv" -DryRun $false -Confirm $true

# Testing: create mailboxes only (skip permissions for now)
.\Provision-BulkMailboxesFromCSV.ps1 -CsvPath "test.csv" -DryRun $false -SkipPermissionQueue $true

.NOTES
- This script requires the SharedMailboxProvisioner module
- CSV format: SamAccountName,DisplayName,Email,ACLGroup,[AdminGroup]
- Always preview with -DryRun $true before actual provisioning
- Requires admin privileges and Exchange/AD permissions
- All operations logged to audit trail
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateScript({ Test-Path $_ })]
    [string]$CsvPath,

    [Parameter(Mandatory = $false)]
    [bool]$DryRun = $true,

    [Parameter(Mandatory = $false)]
    [string]$SearchBase = "",

    [Parameter(Mandatory = $false)]
    [bool]$SkipPermissionQueue = $false,

    [Parameter(Mandatory = $false)]
    [string]$BacklogPath = "",

    [Parameter(Mandatory = $false)]
    [bool]$Confirm = $true
)

Write-Output ""
Write-Output "========================================="
Write-Output "Shared Mailbox Bulk Import Tool"
Write-Output "========================================="
Write-Output ""

# Determine backlog path
if ([string]::IsNullOrWhiteSpace($BacklogPath)) {
    $BacklogPath = Join-Path (Split-Path $PSScriptRoot) "data\mailbox-provisioning-queue.json"
}

Write-Output "CSV File: $CsvPath"
Write-Output "Dry Run: $DryRun"
Write-Output "Backlog: $BacklogPath"
Write-Output ""

try {
    # ================================================================
    # STEP 1: Import candidates from CSV
    # ================================================================
    Write-Output "[1/4] Importing candidates from CSV..."
    Write-Verbose "Importing from: $CsvPath"

    $importParams = @{
        CSVPath = $CsvPath
        ValidateADLookup = $true
    }

    if (-not [string]::IsNullOrWhiteSpace($SearchBase)) {
        $importParams['SearchBase'] = $SearchBase
    }

    $import = Import-MailboxCandidatesFromCSV @importParams

    if (-not $import.Candidates) {
        Write-Error "No candidates imported from CSV"
        exit 1
    }

    Write-Output "Imported: $($import.SuccessCount) valid, $($import.FailureCount) invalid"
    Write-Output "Total rows: $($import.ImportMetadata.TotalRows)"
    Write-Output ""

    # ================================================================
    # STEP 2: Dry-run validation (always run, even in non-DryRun mode)
    # ================================================================
    Write-Output "[2/4] Validating candidates (dry-run)..."
    Write-Verbose "Running bulk import validation"

    $testParams = @{
        Candidates = $import.Candidates
        GenerateReport = $true
        CheckDuplicates = $true
    }

    $validation = Test-MailboxBulkImport @testParams

    Write-Output "Valid: $($validation.ValidCandidates.Count)"
    Write-Output "Conflicts: $($validation.ConflictingCandidates)"
    Write-Output "Estimated Duration: $($validation.EstimatedDuration)"
    Write-Output "Can Proceed: $($validation.CanProceed)"
    Write-Output ""

    if ($validation.ReportPath -and (Test-Path $validation.ReportPath)) {
        Write-Output "Preview Report: $($validation.ReportPath)"
        Write-Output "  -> Open in browser to review before provisioning"
    }

    # ================================================================
    # STEP 3: If DryRun = true, stop here
    # ================================================================
    if ($DryRun) {
        Write-Output ""
        Write-Output "[DRY-RUN MODE] Preview complete - no provisioning occurred"
        Write-Output ""
        Write-Output "Next steps:"
        Write-Output "1. Review the preview report (open in browser)"
        Write-Output "2. If conflicts exist, fix the CSV file"
        Write-Output "3. Run again with -DryRun `$false to provision"
        Write-Output ""
        exit 0
    }

    # ================================================================
    # STEP 4: Confirm before provisioning (if not DryRun)
    # ================================================================
    Write-Output ""
    Write-Output "[3/4] Ready to provision"
    Write-Output ""

    if (-not $validation.CanProceed) {
        Write-Error "Validation failed - cannot proceed with provisioning. Fix issues above and try again."
        exit 1
    }

    if ($Confirm) {
        Write-Output "This will provision $($validation.ValidCandidates.Count) shared mailbox(es)."
        Write-Output "Estimated time: $($validation.EstimatedDuration)"
        Write-Output ""

        $response = Read-Host "Type 'yes' to proceed, or anything else to cancel"

        if ($response -ne "yes") {
            Write-Output "Provisioning cancelled by user"
            exit 0
        }
    }

    # ================================================================
    # STEP 5: Provision candidates
    # ================================================================
    Write-Output ""
    Write-Output "[4/4] Provisioning mailboxes..."
    Write-Verbose "Starting provisioning loop"

    $provisioningStats = @{
        created = 0
        failed = 0
        errors = @()
    }

    foreach ($candidate in $validation.ValidCandidates) {
        Write-Output "  Provisioning: $($candidate.DisplayName)..."
        Write-Verbose "Creating mailbox for: $($candidate.SamAccountName)"

        try {
            $mailboxResult = New-SharedMailboxRemote `
                -SamAccountName $candidate.SamAccountName `
                -DisplayName $candidate.DisplayName `
                -PrimarySmtpAddress $candidate.Email `
                -RemoteRoutingAddress "$($candidate.SamAccountName)@ethz.mail.onmicrosoft.com" `
                -ACLGroupName $candidate.ACLGroup `
                -AdminGroupName $candidate.AdminGroup `
                -BacklogPath $BacklogPath

            if ($mailboxResult) {
                $provisioningStats.created++
                Write-Output "    [OK] Mailbox created"
            }
            else {
                $provisioningStats.failed++
                $provisioningStats.errors += "Failed to create mailbox: $($candidate.SamAccountName)"
                Write-Output "    [ERROR] Mailbox creation failed"
            }
        }
        catch {
            $provisioningStats.failed++
            $provisioningStats.errors += "Exception: $($_.Exception.Message)"
            Write-Output "    [ERROR] Exception: $($_.Exception.Message)"
            Write-Log -Message "Bulk provisioning exception for $($candidate.SamAccountName): $_" `
                -Level ERROR -Operation "Provision-BulkMailboxesFromCSV" -Status "PROVISION_ERROR"
        }
    }

    # ================================================================
    # STEP 6: Process permission queue (if not skipped)
    # ================================================================
    if (-not $SkipPermissionQueue) {
        Write-Output ""
        Write-Output "Processing permission queue..."

        try {
            $queueResult = Invoke-MailboxPermissionQueue -BacklogPath $BacklogPath

            if ($queueResult) {
                Write-Output "  Queue processed: $($queueResult.Summary)"
            }
            else {
                Write-Output "  [WARNING] Queue processing returned no result"
            }
        }
        catch {
            Write-Output "  [WARNING] Queue processing failed: $_"
        }
    }

    # ================================================================
    # Summary
    # ================================================================
    Write-Output ""
    Write-Output "========================================="
    Write-Output "Provisioning Complete"
    Write-Output "========================================="
    Write-Output ""
    Write-Output "Created: $($provisioningStats.created)"
    Write-Output "Failed: $($provisioningStats.failed)"

    if ($provisioningStats.errors.Count -gt 0) {
        Write-Output ""
        Write-Output "Errors:"
        foreach ($error in $provisioningStats.errors) {
            Write-Output "  - $error"
        }
    }

    Write-Output ""
    Write-Log -Message "Bulk provisioning complete: $($provisioningStats.created) created, $($provisioningStats.failed) failed" `
        -Level INFO -Operation "Provision-BulkMailboxesFromCSV" -Status "COMPLETE"
}
catch {
    $msg = "Bulk provisioning script failed: $_"
    Write-Error $msg
    Write-Log -Message $msg -Level ERROR -Operation "Provision-BulkMailboxesFromCSV" -Status "FAILED"
    exit 1
}

Write-Output ""
Write-Output "Done."
