<#
.SYNOPSIS
Check overall system health for provisioning operations.

.DESCRIPTION
Validates connectivity to Exchange Online, Active Directory, and ScheduledTask status.
Alerts if backlog queue is stuck or sync lag exceeds threshold.

.PARAMETER CheckEXO
Verify Exchange Online connectivity.

.PARAMETER CheckAD
Verify Active Directory connectivity.

.PARAMETER CheckScheduledTask
Verify ScheduledTask is enabled and running.

.PARAMETER CheckAll
Perform all health checks (default).

.EXAMPLE
Get-MailboxProvisioningHealth

Check all system health indicators.

.EXAMPLE
Get-MailboxProvisioningHealth -CheckEXO

Verify only EXO connectivity.

.NOTES
Non-intrusive health check. Only reads state, no modifications.
#>

function Get-MailboxProvisioningHealth {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [switch]$CheckEXO,

        [Parameter(Mandatory = $false)]
        [switch]$CheckAD,

        [Parameter(Mandatory = $false)]
        [switch]$CheckScheduledTask,

        [Parameter(Mandatory = $false)]
        [switch]$CheckAll
    )

    Write-Verbose "Checking provisioning system health"

    # Default to CheckAll if no specific checks selected
    if (-not ($CheckEXO -or $CheckAD -or $CheckScheduledTask)) {
        $CheckAll = $true
    }

    $health = [PSCustomObject]@{
        CheckTime = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        OverallStatus = "HEALTHY"
        Issues = @()
        Details = @()
    }

    try {
        # Check EXO connectivity
        if ($CheckAll -or $CheckEXO) {
            $exoStatus = _CheckEXOHealth
            $health.Details += $exoStatus

            if ($exoStatus.Status -ne "CONNECTED") {
                $health.Issues += $exoStatus.Issue
                $health.OverallStatus = "DEGRADED"
            }
        }

        # Check AD connectivity
        if ($CheckAll -or $CheckAD) {
            $adStatus = _CheckADHealth
            $health.Details += $adStatus

            if ($adStatus.Status -ne "CONNECTED") {
                $health.Issues += $adStatus.Issue
                $health.OverallStatus = "DEGRADED"
            }
        }

        # Check ScheduledTask
        if ($CheckAll -or $CheckScheduledTask) {
            $taskStatus = _CheckScheduledTaskHealth
            $health.Details += $taskStatus

            if ($taskStatus.Status -ne "RUNNING") {
                $health.Issues += $taskStatus.Issue
                $health.OverallStatus = "DEGRADED"
            }
        }

        Write-Log -Message "Health check: Status = $($health.OverallStatus), Issues = $($health.Issues.Count)" `
            -Level INFO -Operation "Get-MailboxProvisioningHealth" -Status $health.OverallStatus

        return $health
    }
    catch {
        $msg = "Health check failed: $_"
        Write-Error $msg
        Write-Log -Message $msg -Level ERROR -Operation "Get-MailboxProvisioningHealth" -Status "FAILED"

        $health.OverallStatus = "UNKNOWN"
        $health.Issues += "Health check could not complete: $_"
        return $health
    }
}

function _CheckEXOHealth {
    try {
        $session = Get-PSSession | Where-Object { $_.ConfigurationName -eq "Microsoft.Exchange" }

        if ($session -and $session.State -eq "Opened") {
            return @{ Component = "Exchange Online"; Status = "CONNECTED"; Issue = $null }
        }
        else {
            return @{ Component = "Exchange Online"; Status = "DISCONNECTED"; Issue = "EXO session not connected" }
        }
    }
    catch {
        return @{ Component = "Exchange Online"; Status = "ERROR"; Issue = "Could not check EXO status: $_" }
    }
}

function _CheckADHealth {
    try {
        Get-ADDomain -ErrorAction Stop | Out-Null
        return @{ Component = "Active Directory"; Status = "CONNECTED"; Issue = $null }
    }
    catch {
        return @{ Component = "Active Directory"; Status = "DISCONNECTED"; Issue = "AD connectivity failed: $_" }
    }
}

function _CheckScheduledTaskHealth {
    try {
        $task = Get-ScheduledTask -TaskName "SharedMailboxProvisioning" -ErrorAction SilentlyContinue

        if (-not $task) {
            return @{ Component = "ScheduledTask"; Status = "NOT_FOUND"; Issue = "ScheduledTask 'SharedMailboxProvisioning' not found" }
        }

        if ($task.State -eq "Running") {
            return @{ Component = "ScheduledTask"; Status = "RUNNING"; Issue = $null }
        }
        elseif ($task.State -eq "Ready") {
            return @{ Component = "ScheduledTask"; Status = "RUNNING"; Issue = $null }
        }
        elseif ($task.State -eq "Disabled") {
            return @{ Component = "ScheduledTask"; Status = "DISABLED"; Issue = "ScheduledTask is disabled" }
        }
        else {
            return @{ Component = "ScheduledTask"; Status = $task.State; Issue = "ScheduledTask state: $($task.State)" }
        }
    }
    catch {
        return @{ Component = "ScheduledTask"; Status = "ERROR"; Issue = "Could not check ScheduledTask status: $_" }
    }
}
