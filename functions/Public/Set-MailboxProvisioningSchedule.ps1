<#
.SYNOPSIS
Configure ScheduledTask timing and retry parameters.

.DESCRIPTION
Manages provisioning ScheduledTask configuration including interval,
retry settings, and enable/disable state.

.PARAMETER TaskName
Name of ScheduledTask (default: "SharedMailboxProvisioning").

.PARAMETER Interval
Minutes between task executions (5, 15, 30, 60). Default: 15.

.PARAMETER MaxRetries
Maximum retry attempts per mailbox. Default: 5.

.PARAMETER Enable
Enable the ScheduledTask.

.PARAMETER Disable
Disable the ScheduledTask.

.EXAMPLE
Set-MailboxProvisioningSchedule -Interval 30

Change task interval to 30 minutes.

.EXAMPLE
Set-MailboxProvisioningSchedule -Disable

Pause provisioning (disable ScheduledTask).

.NOTES
Updates task trigger and action properties.
#>

function Set-MailboxProvisioningSchedule {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$TaskName = "SharedMailboxProvisioning",

        [Parameter(Mandatory = $false)]
        [ValidateSet(5, 15, 30, 60)]
        [int]$Interval,

        [Parameter(Mandatory = $false)]
        [int]$MaxRetries,

        [Parameter(Mandatory = $false)]
        [switch]$Enable,

        [Parameter(Mandatory = $false)]
        [switch]$Disable
    )

    Write-Verbose "Configuring provisioning schedule"

    try {
        $task = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue

        if (-not $task) {
            Write-Error "ScheduledTask '$TaskName' not found"
            Write-Log -Message "Schedule config: Task '$TaskName' not found" `
                -Level ERROR -Operation "Set-MailboxProvisioningSchedule" -Status "NOT_FOUND"
            return $false
        }

        # Update interval if specified
        if ($PSBoundParameters.ContainsKey("Interval")) {
            $trigger = $task.Triggers[0]
            if ($trigger -is [Microsoft.Management.Infrastructure.CimInstance]) {
                $trigger.Repetition.Interval = "PT$($Interval)M"
                Set-ScheduledTask -TaskName $TaskName -Trigger $trigger | Out-Null
                Write-Output "Schedule updated: Interval = $Interval minutes"
            }
        }

        # Update enabled state
        if ($Enable) {
            Enable-ScheduledTask -TaskName $TaskName | Out-Null
            Write-Output "ScheduledTask enabled"
            Write-Log -Message "Schedule config: Task enabled" `
                -Level INFO -Operation "Set-MailboxProvisioningSchedule" -Status "ENABLED"
        }
        elseif ($Disable) {
            Disable-ScheduledTask -TaskName $TaskName | Out-Null
            Write-Output "ScheduledTask disabled"
            Write-Log -Message "Schedule config: Task disabled" `
                -Level INFO -Operation "Set-MailboxProvisioningSchedule" -Status "DISABLED"
        }

        return $true
    }
    catch {
        $msg = "Failed to configure schedule: $_"
        Write-Error $msg
        Write-Log -Message $msg -Level ERROR -Operation "Set-MailboxProvisioningSchedule" -Status "FAILED"
        return $false
    }
}

Export-ModuleMember -Function Set-MailboxProvisioningSchedule
