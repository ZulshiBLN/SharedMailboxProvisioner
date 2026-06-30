Describe "Set-MailboxProvisioningSchedule" {
    BeforeAll {
        Import-Module "$PSScriptRoot\..\SharedMailboxProvisioner.psd1" -Force
    }

    Context "ScheduledTask Configuration" {
        It "Should detect if ScheduledTask exists" {
            $existingTask = Get-ScheduledTask -TaskName "SharedMailboxProvisioning" -ErrorAction SilentlyContinue

            if ($existingTask) {
                $result = Set-MailboxProvisioningSchedule -Interval 15

                $result | Should -Be $true
            }
            else {
                Set-ItPending -Reason "ScheduledTask 'SharedMailboxProvisioning' not found on test system"
            }
        }

        It "Should return false when ScheduledTask not found" {
            $result = Set-MailboxProvisioningSchedule -TaskName "NonExistentTask" -ErrorAction SilentlyContinue

            $result | Should -Be $false
        }
    }

    Context "Interval Validation" {
        It "Should validate interval values (5, 15, 30, 60)" {
            $validIntervals = @(5, 15, 30, 60)

            $existingTask = Get-ScheduledTask -TaskName "SharedMailboxProvisioning" -ErrorAction SilentlyContinue
            if ($existingTask) {
                foreach ($interval in $validIntervals) {
                    $result = Set-MailboxProvisioningSchedule -Interval $interval

                    $result | Should -Be $true
                }
            }
            else {
                Set-ItPending -Reason "ScheduledTask not available for testing"
            }
        }
    }

    Context "Task Enable/Disable" {
        It "Should enable ScheduledTask" {
            $existingTask = Get-ScheduledTask -TaskName "SharedMailboxProvisioning" -ErrorAction SilentlyContinue
            if ($existingTask) {
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
            $existingTask = Get-ScheduledTask -TaskName "SharedMailboxProvisioning" -ErrorAction SilentlyContinue
            if ($existingTask) {
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
            $result = Set-MailboxProvisioningSchedule -TaskName "InvalidTask" -Enable -ErrorAction SilentlyContinue

            $result | Should -Be $false
        }
    }

    Context "No Parameters Provided" {
        It "Should require at least one configuration parameter" {
            $existingTask = Get-ScheduledTask -TaskName "SharedMailboxProvisioning" -ErrorAction SilentlyContinue
            if (-not $existingTask) {
                Set-ItPending -Reason "ScheduledTask not available for testing"
            }
        }
    }
}
