Describe "Set-MailboxProvisioningSchedule" {
    BeforeAll {
        Import-Module "$PSScriptRoot\..\SharedMailboxProvisioner.psd1" -Force

        $script:taskExists = $null -ne (Get-ScheduledTask -TaskName "SharedMailboxProvisioning" -ErrorAction SilentlyContinue)
    }

    Context "ScheduledTask Configuration" {
        It "Should detect if ScheduledTask exists" {
            if ($script:taskExists) {
                $result = Set-MailboxProvisioningSchedule -Interval 15

                $result | Should -Be $true
            }
            else {
                Set-ItPending -Reason "ScheduledTask 'SharedMailboxProvisioning' not found on test system"
            }
        }

        It "Should return false when ScheduledTask not found" {
            $result = Set-MailboxProvisioningSchedule -TaskName "NonExistentTask-$((New-Guid).Guid)" -ErrorAction SilentlyContinue

            $result | Should -Be $false
        }
    }

    Context "Interval Validation" {
        It "Should accept valid interval values" {
            if ($script:taskExists) {
                $validIntervals = @(5, 15, 30, 60)

                foreach ($interval in $validIntervals) {
                    { Set-MailboxProvisioningSchedule -Interval $interval -ErrorAction Stop } | Should -Not -Throw
                }
            }
            else {
                Set-ItPending -Reason "ScheduledTask not available for testing"
            }
        }
    }

    Context "Task Enable/Disable" {
        It "Should enable ScheduledTask" {
            if ($script:taskExists) {
                $result = Set-MailboxProvisioningSchedule -Enable

                $result | Should -Be $true

                $task = Get-ScheduledTask -TaskName "SharedMailboxProvisioning" -ErrorAction SilentlyContinue
                if ($task) {
                    $task.State | Should -Not -Be "Disabled"
                }
            }
            else {
                Set-ItPending -Reason "ScheduledTask not available for testing"
            }
        }

        It "Should disable ScheduledTask" {
            if ($script:taskExists) {
                $result = Set-MailboxProvisioningSchedule -Disable

                $result | Should -Be $true

                $task = Get-ScheduledTask -TaskName "SharedMailboxProvisioning" -ErrorAction SilentlyContinue
                if ($task) {
                    $task.State | Should -Be "Disabled"
                }
            }
            else {
                Set-ItPending -Reason "ScheduledTask not available for testing"
            }
        }
    }

    Context "Error Handling" {
        It "Should handle invalid task name gracefully" {
            $result = Set-MailboxProvisioningSchedule -TaskName "InvalidTask-$((New-Guid).Guid)" -Enable -ErrorAction SilentlyContinue

            $result | Should -Be $false
        }
    }
}
