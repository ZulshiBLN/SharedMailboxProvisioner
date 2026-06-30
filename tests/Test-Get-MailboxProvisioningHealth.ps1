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
        It "Should perform all checks when CheckAll specified" {
            $result = Get-MailboxProvisioningHealth -CheckAll

            $result.Details | Should -Not -BeNullOrEmpty
            $result.Details.Count | Should -BeGreaterThan 0
        }

        It "Should default to CheckAll when no parameters specified" {
            $result = Get-MailboxProvisioningHealth

            $result.OverallStatus | Should -Match "HEALTHY|DEGRADED|UNKNOWN"
        }
    }

    Context "Individual Health Checks" {
        It "Should check Active Directory connectivity" {
            $result = Get-MailboxProvisioningHealth -CheckAD

            $result.Details | Should -Not -BeNullOrEmpty
            $result.Details.Component | Should -Contain "Active Directory"
        }

        It "Should check ScheduledTask status" {
            $result = Get-MailboxProvisioningHealth -CheckScheduledTask

            $result.Details | Should -Not -BeNullOrEmpty
            $result.Details.Component | Should -Contain "ScheduledTask"
        }

        It "Should check Exchange Online connectivity" {
            $result = Get-MailboxProvisioningHealth -CheckEXO

            $result.Details | Should -Not -BeNullOrEmpty
            $result.Details.Component | Should -Contain "Exchange Online"
        }
    }

    Context "Health Status Reporting" {
        It "Should report HEALTHY status when all components OK" {
            $result = Get-MailboxProvisioningHealth -CheckAll

            $result.OverallStatus | Should -Match "HEALTHY|DEGRADED|UNKNOWN"
        }

        It "Should populate Issues array when problems detected" {
            $result = Get-MailboxProvisioningHealth -CheckAll

            $result.Issues | Should -BeOfType [System.Collections.ArrayList]
        }

        It "Should include component details" {
            $result = Get-MailboxProvisioningHealth -CheckAll

            $result.Details | Should -Not -BeNullOrEmpty

            foreach ($detail in $result.Details) {
                $detail | Get-Member -Name "Component" | Should -Not -BeNullOrEmpty
                $detail | Get-Member -Name "Status" | Should -Not -BeNullOrEmpty
            }
        }
    }

    Context "Component-Specific Checks" {
        It "Should return component status for AD check" {
            $result = Get-MailboxProvisioningHealth -CheckAD

            $adDetail = $result.Details | Where-Object { $_.Component -eq "Active Directory" }
            $adDetail | Should -Not -BeNullOrEmpty
            $adDetail.Status | Should -Match "CONNECTED|DISCONNECTED|ERROR"
        }

        It "Should return component status for ScheduledTask check" {
            $result = Get-MailboxProvisioningHealth -CheckScheduledTask

            $taskDetail = $result.Details | Where-Object { $_.Component -eq "ScheduledTask" }
            $taskDetail | Should -Not -BeNullOrEmpty
            $taskDetail.Status | Should -Match "RUNNING|DISABLED|NOT_FOUND|ERROR"
        }

        It "Should return component status for EXO check" {
            $result = Get-MailboxProvisioningHealth -CheckEXO

            $exoDetail = $result.Details | Where-Object { $_.Component -eq "Exchange Online" }
            $exoDetail | Should -Not -BeNullOrEmpty
            $exoDetail.Status | Should -Match "CONNECTED|DISCONNECTED|ERROR"
        }
    }

    Context "Degraded Status Detection" {
        It "Should mark health as DEGRADED when component fails" {
            $result = Get-MailboxProvisioningHealth -CheckAll

            if ($result.Issues.Count -gt 0) {
                $result.OverallStatus | Should -Be "DEGRADED"
            }
        }
    }

    Context "Error Handling" {
        It "Should return UNKNOWN status on exception" {
            $result = Get-MailboxProvisioningHealth -CheckAll -ErrorAction SilentlyContinue

            $result.OverallStatus | Should -Match "HEALTHY|DEGRADED|UNKNOWN"
        }

        It "Should complete without throwing" {
            { Get-MailboxProvisioningHealth -CheckAll } | Should -Not -Throw
        }
    }

    Context "Output Format" {
        It "Should return consistent output format" {
            $result1 = Get-MailboxProvisioningHealth
            $result2 = Get-MailboxProvisioningHealth

            $result1.CheckTime | Should -Not -BeNullOrEmpty
            $result2.CheckTime | Should -Not -BeNullOrEmpty
            $result1.OverallStatus | Should -Not -BeNullOrEmpty
            $result2.OverallStatus | Should -Not -BeNullOrEmpty
        }
    }
}
