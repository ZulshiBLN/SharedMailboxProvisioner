Describe "Get-MailboxProvisioningHealth" {
    BeforeAll {
        Import-Module "$PSScriptRoot\..\SharedMailboxProvisioner.psd1" -Force
    }

    Context "Health Check Structure" {
        It "Should return health object with required properties" {
            $result = Get-MailboxProvisioningHealth -CheckAll

            $result | Should -Not -BeNullOrEmpty
            $result | Get-Member -Name "CheckTime" | Should -Not -BeNullOrEmpty
            $result | Get-Member -Name "OverallStatus" | Should -Not -BeNullOrEmpty
            $result | Get-Member -Name "Issues" | Should -Not -BeNullOrEmpty
            $result | Get-Member -Name "Details" | Should -Not -BeNullOrEmpty
        }

        It "Should include timestamp for health check" {
            $result = Get-MailboxProvisioningHealth -CheckAll

            $result.CheckTime | Should -Match "^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}$"
        }
    }

    Context "Check All Health Indicators" {
        It "Should perform checks and return consistent status" {
            $result = Get-MailboxProvisioningHealth -CheckAll

            $result.OverallStatus | Should -Match "HEALTHY|DEGRADED|UNKNOWN"
        }

        It "Should default to CheckAll when no parameters specified" {
            $result = Get-MailboxProvisioningHealth

            $result.OverallStatus | Should -Match "HEALTHY|DEGRADED|UNKNOWN"
        }
    }

    Context "Individual Health Checks" {
        It "Should check Active Directory connectivity status" {
            $result = Get-MailboxProvisioningHealth -CheckAD

            $result.Details | Should -Not -BeNullOrEmpty
            $adDetail = $result.Details | Where-Object { $_.Component -eq "Active Directory" }
            $adDetail | Should -Not -BeNullOrEmpty
            $adDetail.Status | Should -Match "CONNECTED|DISCONNECTED|ERROR"
        }

        It "Should check ScheduledTask status" {
            $result = Get-MailboxProvisioningHealth -CheckScheduledTask

            $result.Details | Should -Not -BeNullOrEmpty
            $taskDetail = $result.Details | Where-Object { $_.Component -eq "ScheduledTask" }
            $taskDetail | Should -Not -BeNullOrEmpty
            $taskDetail.Status | Should -Match "RUNNING|DISABLED|NOT_FOUND|ERROR"
        }

        It "Should check Exchange Online connectivity status" {
            $result = Get-MailboxProvisioningHealth -CheckEXO

            $result.Details | Should -Not -BeNullOrEmpty
            $exoDetail = $result.Details | Where-Object { $_.Component -eq "Exchange Online" }
            $exoDetail | Should -Not -BeNullOrEmpty
            $exoDetail.Status | Should -Match "CONNECTED|DISCONNECTED|ERROR"
        }
    }

    Context "Health Status Reporting" {
        It "Should report valid status values" {
            $result = Get-MailboxProvisioningHealth -CheckAll

            $result.OverallStatus | Should -Match "HEALTHY|DEGRADED|UNKNOWN"
        }

        It "Should include component details in response" {
            $result = Get-MailboxProvisioningHealth -CheckAll

            $result.Details | Should -Not -BeNullOrEmpty
            $result.Details.Count | Should -BeGreaterThan 0

            foreach ($detail in $result.Details) {
                $detail.Component | Should -Not -BeNullOrEmpty
                $detail.Status | Should -Not -BeNullOrEmpty
            }
        }
    }

    Context "Degraded Status" {
        It "Should report DEGRADED when issues are detected" {
            $result = Get-MailboxProvisioningHealth -CheckAll

            if ($result.Issues.Count -gt 0) {
                $result.OverallStatus | Should -Be "DEGRADED"
            }
        }

        It "Should populate Issues array when problems found" {
            $result = Get-MailboxProvisioningHealth -CheckAll

            $result.Issues | Should -BeOfType [System.Collections.ArrayList]
        }
    }

    Context "Error Handling" {
        It "Should handle exceptions gracefully" {
            { Get-MailboxProvisioningHealth -CheckAll } | Should -Not -Throw
        }

        It "Should return valid status on error" {
            $result = Get-MailboxProvisioningHealth -CheckAll -ErrorAction SilentlyContinue

            $result.OverallStatus | Should -Match "HEALTHY|DEGRADED|UNKNOWN"
        }
    }

    Context "Output Consistency" {
        It "Should return consistent output structure across multiple calls" {
            $result1 = Get-MailboxProvisioningHealth
            $result2 = Get-MailboxProvisioningHealth

            $result1.CheckTime | Should -Not -BeNullOrEmpty
            $result2.CheckTime | Should -Not -BeNullOrEmpty
            $result1.OverallStatus | Should -Not -BeNullOrEmpty
            $result2.OverallStatus | Should -Not -BeNullOrEmpty
            $result1.Details | Should -Not -BeNullOrEmpty
            $result2.Details | Should -Not -BeNullOrEmpty
        }
    }
}
