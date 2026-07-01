<#
.SYNOPSIS
Calculate KPIs, identify bottlenecks, and analyze trends.

.DESCRIPTION
Analyzes provisioning operations to extract key performance indicators (KPIs),
identify system bottlenecks, and track success rate trends over time.

Per ADR-004: Logging & Audit Trail

.PARAMETER TrendDays
Number of days to analyze for trends. Default: 30

.PARAMETER BacklogPath
Path to JSON provisioning backlog file.

.EXAMPLE
$metrics = Get-MailboxProvisioningMetrics
$metrics.KPIs

Show KPI summary.

.EXAMPLE
$metrics = Get-MailboxProvisioningMetrics -TrendDays 7
$metrics.Bottlenecks

Show top bottlenecks from last 7 days.

.NOTES
- Pure data analysis (no EXO/AD calls)
- Identifies performance trends and anomalies
- Calculates recovery time for failed operations
#>

function Get-MailboxProvisioningMetrics {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [int]$TrendDays = 30,

        [Parameter(Mandatory = $false)]
        [string]$BacklogPath = ""
    )

    Write-Verbose "Calculating provisioning metrics (last $TrendDays days)"

    if ([string]::IsNullOrWhiteSpace($BacklogPath)) {
        $BacklogPath = Join-Path (Split-Path $PSScriptRoot -Parent) "data\mailbox-provisioning-queue.json"
    }

    $result = @{
        KPIs = @{
            SuccessRate = "0%"
            AvgTimeToCompletion = "00:00:00"
            MedianTimeToCompletion = "00:00:00"
            RetryRatio = "0.0"
            MeanTimeToRecovery = "00:00:00"
        }
        Bottlenecks = @()
        Trends = @{
            Last7Days = @{ Rate = "0%"; Trend = "UNKNOWN" }
            Last14Days = @{ Rate = "0%"; Trend = "UNKNOWN" }
            Last30Days = @{ Rate = "0%"; Trend = "UNKNOWN" }
        }
        PeakHours = @()
    }

    try {
        # ================================================================
        # STEP 1: Load backlog
        # ================================================================
        if (-not (Test-Path $BacklogPath)) {
            Write-Verbose "Backlog file not found"
            return $result
        }

        $backlogContent = Get-Content -Path $BacklogPath -Raw
        $backlogData = $backlogContent | ConvertFrom-Json

        if (-not $backlogData) {
            return $result
        }

        if ($backlogData -isnot [System.Collections.IEnumerable] -or $backlogData -is [string]) {
            $backlogData = @($backlogData)
        }

        # ================================================================
        # STEP 2: Calculate KPIs
        # ================================================================
        $successCount = @($backlogData | Where-Object { $_.Status -eq "PERMISSIONS_SET" }).Count
        $totalCount = $backlogData.Count

        if ($totalCount -gt 0) {
            $successRate = [math]::Round(($successCount / $totalCount) * 100, 1)
            $result.KPIs.SuccessRate = "$successRate%"
        }

        # Average and median time to completion
        $durations = @()
        foreach ($entry in $backlogData) {
            if (-not [string]::IsNullOrWhiteSpace($entry.CompletedAt)) {
                try {
                    $createdDate = [DateTime]::Parse($entry.CreatedAt)
                    $completedDate = [DateTime]::Parse($entry.CompletedAt)
                    $duration = ($completedDate - $createdDate).TotalSeconds
                    $durations += $duration
                }
                catch {
                    Write-Verbose "Failed to parse date in duration calculation: $_"
                }
            }
        }

        if ($durations.Count -gt 0) {
            $avgDuration = [math]::Round(($durations | Measure-Object -Average).Average)
            $medianDuration = [math]::Round((($durations | Sort-Object)[($durations.Count / 2)]))

            $result.KPIs.AvgTimeToCompletion = [TimeSpan]::FromSeconds($avgDuration).ToString("hh\:mm\:ss")
            $result.KPIs.MedianTimeToCompletion = [TimeSpan]::FromSeconds($medianDuration).ToString("hh\:mm\:ss")
        }

        # Retry ratio
        $totalAttempts = $backlogData.Count
        $retryCount = @($backlogData | Where-Object { $_.RetryCount -gt 0 }).Count
        if ($totalAttempts -gt 0) {
            $retryRatio = [math]::Round($retryCount / $totalAttempts, 2)
            $result.KPIs.RetryRatio = $retryRatio.ToString("0.00")
        }

        # Mean time to recovery (for failed entries that eventually succeeded)
        $recoveredEntries = @($backlogData | Where-Object { $_.Status -eq "PERMISSIONS_SET" -and $_.RetryCount -gt 0 })
        if ($recoveredEntries.Count -gt 0) {
            $recoveryTimes = @()
            foreach ($entry in $recoveredEntries) {
                try {
                    $createdDate = [DateTime]::Parse($entry.CreatedAt)
                    $completedDate = [DateTime]::Parse($entry.CompletedAt)
                    $recoveryTime = ($completedDate - $createdDate).TotalSeconds
                    $recoveryTimes += $recoveryTime
                }
                catch {
                    Write-Verbose "Failed to parse date in recovery time calculation: $_"
                }
            }

            if ($recoveryTimes.Count -gt 0) {
                $avgRecoveryTime = [math]::Round(($recoveryTimes | Measure-Object -Average).Average)
                $result.KPIs.MeanTimeToRecovery = [TimeSpan]::FromSeconds($avgRecoveryTime).ToString("hh\:mm\:ss")
            }
        }

        # ================================================================
        # STEP 3: Identify bottlenecks (top error codes)
        # ================================================================
        $failedEntries = @($backlogData | Where-Object { $_.Status -eq "FAILED_PERMISSIONS" })
        if ($failedEntries.Count -gt 0) {
            $errorGroups = $failedEntries | Group-Object -Property ErrorCode | Sort-Object -Property Count -Descending
            foreach ($errorGroup in $errorGroups | Select-Object -First 5) {
                $errorCount = $errorGroup.Count
                $errorPercentage = [math]::Round(($errorCount / $failedEntries.Count) * 100, 1)

                if ($errorPercentage -gt 50) {
                    $impact = "HIGH"
                }
                elseif ($errorPercentage -gt 20) {
                    $impact = "MEDIUM"
                }
                else {
                    $impact = "LOW"
                }

                $result.Bottlenecks += @{
                    Issue = $errorGroup.Name
                    Count = $errorCount
                    Percentage = "$errorPercentage%"
                    Impact = $impact
                }
            }
        }

        # ================================================================
        # STEP 4: Trend analysis
        # ================================================================
        $trendPeriods = @(
            @{ Days = 7; Key = "Last7Days" }
            @{ Days = 14; Key = "Last14Days" }
            @{ Days = 30; Key = "Last30Days" }
        )

        foreach ($period in $trendPeriods) {
            $cutoffDate = (Get-Date).AddDays(-$period.Days)
            $periodEntries = @()

            foreach ($entry in $backlogData) {
                try {
                    $entryDate = [DateTime]::Parse($entry.CreatedAt)
                    if ($entryDate -ge $cutoffDate) {
                        $periodEntries += $entry
                    }
                }
                catch {
                    Write-Verbose "Failed to parse date in trend analysis: $_"
                }
            }

            if ($periodEntries.Count -gt 0) {
                $periodSuccess = @($periodEntries | Where-Object { $_.Status -eq "PERMISSIONS_SET" }).Count
                $periodRate = [math]::Round(($periodSuccess / $periodEntries.Count) * 100, 1)
                $result.Trends[$period.Key].Rate = "$periodRate%"
            }
        }

        # Calculate trend direction
        $last7 = [float]($result.Trends["Last7Days"].Rate -replace "%")
        $last30 = [float]($result.Trends["Last30Days"].Rate -replace "%")

        if ($last7 -gt $last30 + 2) {
            $result.Trends["Last7Days"].Trend = "UP"
            $result.Trends["Last14Days"].Trend = "UP"
            $result.Trends["Last30Days"].Trend = "STABLE"
        }
        elseif ($last7 -lt $last30 - 2) {
            $result.Trends["Last7Days"].Trend = "DOWN"
            $result.Trends["Last14Days"].Trend = "DOWN"
            $result.Trends["Last30Days"].Trend = "STABLE"
        }
        else {
            $result.Trends["Last7Days"].Trend = "STABLE"
            $result.Trends["Last14Days"].Trend = "STABLE"
            $result.Trends["Last30Days"].Trend = "STABLE"
        }

        # ================================================================
        # STEP 5: Peak hours analysis
        # ================================================================
        $hourlyStats = @{}
        foreach ($entry in $backlogData) {
            try {
                $entryDate = [DateTime]::Parse($entry.CreatedAt)
                $hour = $entryDate.Hour
                if (-not $hourlyStats.ContainsKey($hour)) {
                    $hourlyStats[$hour] = @{ Count = 0; Success = 0 }
                }
                $hourlyStats[$hour].Count++
                if ($entry.Status -eq "PERMISSIONS_SET") {
                    $hourlyStats[$hour].Success++
                }
            }
            catch {
                Write-Verbose "Failed to parse date in hourly stats calculation: $_"
            }
        }

        foreach ($hour in ($hourlyStats.Keys | Sort-Object)) {
            $stats = $hourlyStats[$hour]
            $avgTime = "00:00:00"
            $hourFormatted = "{0:00}" -f $hour

            if ($stats.Count -gt 0) {
                $successRate = [math]::Round(($stats.Success / $stats.Count) * 100, 0)
            }
            else {
                $successRate = 0
            }

            $result.PeakHours += @{
                Hour = "$hourFormatted`:00"
                Throughput = $stats.Count
                SuccessRate = "$successRate%"
                AvgTime = $avgTime
            }
        }

        Write-Log -Message "Metrics calculated: $($result.KPIs.SuccessRate) success rate, $($result.Bottlenecks.Count) bottlenecks identified" `
            -Level INFO -Operation "Get-MailboxProvisioningMetrics" -Status "COMPLETE"

        return $result
    }
    catch {
        $msg = "Failed to calculate metrics: $_"
        Write-Error $msg
        Write-Log -Message $msg -Level ERROR -Operation "Get-MailboxProvisioningMetrics" -Status "FAILED"
        return $result
    }
}
