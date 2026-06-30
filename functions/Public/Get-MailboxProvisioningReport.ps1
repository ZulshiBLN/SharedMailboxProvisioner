<#
.SYNOPSIS
Generate comprehensive provisioning metrics and timeline report.

.DESCRIPTION
Analyzes provisioning backlog data and generates a detailed report with metrics,
timeline breakdown, group statistics, and failure analysis.

Per ADR-004: Logging & Audit Trail

.PARAMETER StartDate
Report start date. Default: 30 days ago.

.PARAMETER EndDate
Report end date. Default: today.

.PARAMETER GroupBy
Timeline aggregation: Daily, Weekly, Monthly. Default: Daily

.PARAMETER BacklogPath
Path to JSON provisioning backlog file.

.EXAMPLE
Get-MailboxProvisioningReport -StartDate (Get-Date).AddDays(-7)

Generate report for last 7 days.

.EXAMPLE
$report = Get-MailboxProvisioningReport
$report.Summary | Format-Table

Show metrics summary.

.NOTES
- Reads from JSON backlog file (created by New-SharedMailboxRemote)
- No external dependencies (EXO, AD)
- Pure data aggregation and analysis
#>

function Get-MailboxProvisioningReport {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [DateTime]$StartDate = (Get-Date).AddDays(-30),

        [Parameter(Mandatory = $false)]
        [DateTime]$EndDate = (Get-Date),

        [Parameter(Mandatory = $false)]
        [ValidateSet("Daily", "Weekly", "Monthly")]
        [string]$GroupBy = "Daily",

        [Parameter(Mandatory = $false)]
        [string]$BacklogPath = ""
    )

    Write-Verbose "Generating provisioning report ($StartDate to $EndDate, grouped by $GroupBy)"

    if ([string]::IsNullOrWhiteSpace($BacklogPath)) {
        $BacklogPath = Join-Path (Split-Path $PSScriptRoot -Parent) "data\mailbox-provisioning-queue.json"
    }

    $result = @{
        Period = @{
            Start = $StartDate
            End = $EndDate
        }
        Summary = @{
            TotalProvisioned = 0
            TotalFailed = 0
            SuccessRate = "0%"
            AverageTimeToCompletion = "00:00:00"
        }
        ByStatus = @{}
        ByGroup = @{}
        Timeline = @()
        TopFailures = @()
    }

    try {
        # ================================================================
        # STEP 1: Load backlog data
        # ================================================================
        if (-not (Test-Path $BacklogPath)) {
            Write-Verbose "Backlog file not found: $BacklogPath"
            Write-Log -Message "Provisioning report: No backlog file found" `
                -Level WARN -Operation "Get-MailboxProvisioningReport" -Status "NO_DATA"
            return $result
        }

        $backlogContent = Get-Content -Path $BacklogPath -Raw
        $backlogData = $backlogContent | ConvertFrom-Json

        if (-not $backlogData) {
            Write-Verbose "Backlog is empty"
            return $result
        }

        # Convert to array if single object
        if ($backlogData -isnot [System.Collections.IEnumerable] -or $backlogData -is [string]) {
            $backlogData = @($backlogData)
        }

        Write-Verbose "Loaded $($backlogData.Count) entries from backlog"

        # ================================================================
        # STEP 2: Filter by date range
        # ================================================================
        $entries = @()
        foreach ($entry in $backlogData) {
            if ([string]::IsNullOrWhiteSpace($entry.CreatedAt)) {
                continue
            }

            try {
                $entryDate = [DateTime]::Parse($entry.CreatedAt)
                if ($entryDate -ge $StartDate -and $entryDate -le $EndDate) {
                    $entries += $entry
                }
            }
            catch {
                Write-Verbose "Failed to parse date: $($entry.CreatedAt)"
            }
        }

        Write-Verbose "Filtered to $($entries.Count) entries in date range"

        if ($entries.Count -eq 0) {
            return $result
        }

        # ================================================================
        # STEP 3: Calculate summary metrics
        # ================================================================
        $successCount = @($entries | Where-Object { $_.Status -eq "PERMISSIONS_SET" }).Count
        $failedCount = @($entries | Where-Object { $_.Status -eq "FAILED_PERMISSIONS" }).Count
        $totalCount = $entries.Count

        $result.Summary.TotalProvisioned = $successCount
        $result.Summary.TotalFailed = $failedCount

        if ($totalCount -gt 0) {
            $successRate = [math]::Round(($successCount / $totalCount) * 100, 1)
            $result.Summary.SuccessRate = "$successRate%"
        }

        # Calculate average time to completion
        $completedEntries = @($entries | Where-Object { -not [string]::IsNullOrWhiteSpace($_.CompletedAt) })
        if ($completedEntries.Count -gt 0) {
            $durations = @()
            foreach ($entry in $completedEntries) {
                try {
                    $createdDate = [DateTime]::Parse($entry.CreatedAt)
                    $completedDate = [DateTime]::Parse($entry.CompletedAt)
                    $duration = ($completedDate - $createdDate).TotalSeconds
                    $durations += $duration
                }
                catch {
                    # Skip entries with date parsing errors
                }
            }

            if ($durations.Count -gt 0) {
                $avgDuration = [math]::Round(($durations | Measure-Object -Average).Average)
                $timespan = [TimeSpan]::FromSeconds($avgDuration)
                $result.Summary.AverageTimeToCompletion = $timespan.ToString("hh\:mm\:ss")
            }
        }

        # ================================================================
        # STEP 4: Group by status
        # ================================================================
        $statusGroups = $entries | Group-Object -Property Status -NoElement
        foreach ($group in $statusGroups) {
            $result.ByStatus[$group.Name] = $group.Count
        }

        # ================================================================
        # STEP 5: Group by ACL group
        # ================================================================
        $groupGroups = $entries | Group-Object -Property ACLGroup
        foreach ($group in $groupGroups) {
            $groupSuccessCount = @($group.Group | Where-Object { $_.Status -eq "PERMISSIONS_SET" }).Count
            $groupTotal = $group.Group.Count
            $groupSuccessRate = if ($groupTotal -gt 0) { [math]::Round(($groupSuccessCount / $groupTotal) * 100, 1) } else { 0 }

            $result.ByGroup[$group.Name] = @{
                Count = $groupTotal
                SuccessCount = $groupSuccessCount
                SuccessRate = "$groupSuccessRate%"
            }
        }

        # ================================================================
        # STEP 6: Generate timeline by date
        # ================================================================
        $timelineEntries = $entries | Group-Object -Property { ([DateTime]::Parse($_.CreatedAt)).Date }
        foreach ($dayGroup in ($timelineEntries | Sort-Object -Property Name)) {
            $daySuccessCount = @($dayGroup.Group | Where-Object { $_.Status -eq "PERMISSIONS_SET" }).Count
            $dayFailedCount = @($dayGroup.Group | Where-Object { $_.Status -eq "FAILED_PERMISSIONS" }).Count
            $dayTotal = $dayGroup.Group.Count
            $dayRate = if ($dayTotal -gt 0) { [math]::Round(($daySuccessCount / $dayTotal) * 100, 1) } else { 0 }

            $result.Timeline += @{
                Date = $dayGroup.Name.ToString("yyyy-MM-dd")
                Provisioned = $daySuccessCount
                Failed = $dayFailedCount
                Total = $dayTotal
                SuccessRate = "$dayRate%"
            }
        }

        # ================================================================
        # STEP 7: Identify top failures
        # ================================================================
        $failedEntries = @($entries | Where-Object { $_.Status -eq "FAILED_PERMISSIONS" -or $_.Status -eq "FAILED_MAILBOX" })
        if ($failedEntries.Count -gt 0) {
            $errorGroups = $failedEntries | Group-Object -Property ErrorCode
            $topErrors = $errorGroups | Sort-Object -Property Count -Descending | Select-Object -First 5

            foreach ($errorGroup in $topErrors) {
                $errorCount = $errorGroup.Count
                $errorPercentage = [math]::Round(($errorCount / $failedEntries.Count) * 100, 1)

                $result.TopFailures += @{
                    ErrorCode = $errorGroup.Name
                    Count = $errorCount
                    Percentage = "$errorPercentage%"
                }
            }
        }

        Write-Log -Message "Provisioning report: $successCount successful, $failedCount failed ($($result.Summary.SuccessRate) success rate)" `
            -Level INFO -Operation "Get-MailboxProvisioningReport" -Status "COMPLETE"

        return $result
    }
    catch {
        $msg = "Failed to generate provisioning report: $_"
        Write-Error $msg
        Write-Log -Message $msg -Level ERROR -Operation "Get-MailboxProvisioningReport" -Status "FAILED"
        return $result
    }
}

Export-ModuleMember -Function Get-MailboxProvisioningReport
