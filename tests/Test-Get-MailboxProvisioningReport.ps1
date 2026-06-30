BeforeAll {
    Import-Module "$PSScriptRoot\..\SharedMailboxProvisioner.psd1" -Force
}

Describe "Get-MailboxProvisioningReport" {
    Context "Report Generation from Backlog" {
        BeforeEach {
            $script:testDir = Join-Path $env:TEMP "smp-report-$(Get-Random)"
            New-Item -ItemType Directory -Path $script:testDir -Force | Out-Null

            $script:backlogPath = Join-Path $script:testDir "test-backlog.json"
        }

        AfterEach {
            Remove-Item -Path $script:testDir -Recurse -Force -ErrorAction SilentlyContinue
        }

        It "Should generate report with no backlog file" {
            $result = Get-MailboxProvisioningReport -BacklogPath (Join-Path $script:testDir "nonexistent.json")

            $result | Should -Not -BeNullOrEmpty
            $result.Summary.TotalProvisioned | Should -Be 0
            $result.Summary.SuccessRate | Should -Be "0%"
        }

        It "Should calculate success rate correctly" {
            $backlog = @(
                @{ SamAccountName = "smbx_001"; Status = "PERMISSIONS_SET"; CreatedAt = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss") }
                @{ SamAccountName = "smbx_002"; Status = "PERMISSIONS_SET"; CreatedAt = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss") }
                @{ SamAccountName = "smbx_003"; Status = "FAILED_PERMISSIONS"; CreatedAt = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss") }
            )
            $backlog | ConvertTo-Json | Set-Content -Path $script:backlogPath

            $result = Get-MailboxProvisioningReport -BacklogPath $script:backlogPath

            $result.Summary.TotalProvisioned | Should -Be 2
            $result.Summary.TotalFailed | Should -Be 1
            $result.Summary.SuccessRate | Should -Match "66"
        }

        It "Should calculate average time to completion" {
            $now = Get-Date
            $backlog = @(
                @{
                    SamAccountName = "smbx_001"
                    Status = "PERMISSIONS_SET"
                    CreatedAt = $now.AddMinutes(-15).ToString("yyyy-MM-dd HH:mm:ss")
                    CompletedAt = $now.ToString("yyyy-MM-dd HH:mm:ss")
                }
                @{
                    SamAccountName = "smbx_002"
                    Status = "PERMISSIONS_SET"
                    CreatedAt = $now.AddMinutes(-25).ToString("yyyy-MM-dd HH:mm:ss")
                    CompletedAt = $now.ToString("yyyy-MM-dd HH:mm:ss")
                }
            )
            $backlog | ConvertTo-Json | Set-Content -Path $script:backlogPath

            $result = Get-MailboxProvisioningReport -BacklogPath $script:backlogPath

            $result.Summary.AverageTimeToCompletion | Should -Not -BeNullOrEmpty
            $result.Summary.AverageTimeToCompletion | Should -Match "^\d{2}:\d{2}:\d{2}$"
        }

        It "Should group by status" {
            $backlog = @(
                @{ SamAccountName = "smbx_001"; Status = "PERMISSIONS_SET"; CreatedAt = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss") }
                @{ SamAccountName = "smbx_002"; Status = "PERMISSIONS_SET"; CreatedAt = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss") }
                @{ SamAccountName = "smbx_003"; Status = "FAILED_PERMISSIONS"; CreatedAt = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss") }
                @{ SamAccountName = "smbx_004"; Status = "MAILBOX_CREATED_AWAITING_PERMISSIONS"; CreatedAt = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss") }
            )
            $backlog | ConvertTo-Json | Set-Content -Path $script:backlogPath

            $result = Get-MailboxProvisioningReport -BacklogPath $script:backlogPath

            $result.ByStatus.Count | Should -Be 3
            $result.ByStatus["PERMISSIONS_SET"] | Should -Be 2
            $result.ByStatus["FAILED_PERMISSIONS"] | Should -Be 1
        }

        It "Should group by ACL group" {
            $backlog = @(
                @{ SamAccountName = "smbx_001"; Status = "PERMISSIONS_SET"; ACLGroup = "smbx_acl_001"; CreatedAt = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss") }
                @{ SamAccountName = "smbx_002"; Status = "PERMISSIONS_SET"; ACLGroup = "smbx_acl_001"; CreatedAt = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss") }
                @{ SamAccountName = "smbx_003"; Status = "PERMISSIONS_SET"; ACLGroup = "smbx_acl_002"; CreatedAt = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss") }
            )
            $backlog | ConvertTo-Json | Set-Content -Path $script:backlogPath

            $result = Get-MailboxProvisioningReport -BacklogPath $script:backlogPath

            $result.ByGroup["smbx_acl_001"].Count | Should -Be 2
            $result.ByGroup["smbx_acl_002"].Count | Should -Be 1
        }

        It "Should generate timeline by date" {
            $today = Get-Date
            $yesterday = $today.AddDays(-1)

            $backlog = @(
                @{ SamAccountName = "smbx_001"; Status = "PERMISSIONS_SET"; CreatedAt = $yesterday.ToString("yyyy-MM-dd HH:mm:ss") }
                @{ SamAccountName = "smbx_002"; Status = "PERMISSIONS_SET"; CreatedAt = $today.ToString("yyyy-MM-dd HH:mm:ss") }
                @{ SamAccountName = "smbx_003"; Status = "FAILED_PERMISSIONS"; CreatedAt = $today.ToString("yyyy-MM-dd HH:mm:ss") }
            )
            $backlog | ConvertTo-Json | Set-Content -Path $script:backlogPath

            $result = Get-MailboxProvisioningReport -BacklogPath $script:backlogPath -StartDate $yesterday.AddDays(-1)

            $result.Timeline.Count | Should -Be 2
        }

        It "Should identify top failures" {
            $backlog = @(
                @{ SamAccountName = "smbx_001"; Status = "FAILED_PERMISSIONS"; ErrorCode = "MailboxNotFound"; CreatedAt = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss") }
                @{ SamAccountName = "smbx_002"; Status = "FAILED_PERMISSIONS"; ErrorCode = "MailboxNotFound"; CreatedAt = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss") }
                @{ SamAccountName = "smbx_003"; Status = "FAILED_PERMISSIONS"; ErrorCode = "PermissionError"; CreatedAt = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss") }
            )
            $backlog | ConvertTo-Json | Set-Content -Path $script:backlogPath

            $result = Get-MailboxProvisioningReport -BacklogPath $script:backlogPath

            $result.TopFailures[0].ErrorCode | Should -Be "MailboxNotFound"
            $result.TopFailures[0].Count | Should -Be 2
        }

        It "Should filter by date range" {
            $now = Get-Date
            $oneWeekAgo = $now.AddDays(-7)
            $twoMonthsAgo = $now.AddDays(-60)

            $backlog = @(
                @{ SamAccountName = "smbx_001"; Status = "PERMISSIONS_SET"; CreatedAt = $twoMonthsAgo.ToString("yyyy-MM-dd HH:mm:ss") }
                @{ SamAccountName = "smbx_002"; Status = "PERMISSIONS_SET"; CreatedAt = $oneWeekAgo.ToString("yyyy-MM-dd HH:mm:ss") }
            )
            $backlog | ConvertTo-Json | Set-Content -Path $script:backlogPath

            $result = Get-MailboxProvisioningReport -BacklogPath $script:backlogPath -StartDate $oneWeekAgo

            $result.Summary.TotalProvisioned | Should -Be 1
        }

        It "Should handle empty backlog" {
            @() | ConvertTo-Json | Set-Content -Path $script:backlogPath

            $result = Get-MailboxProvisioningReport -BacklogPath $script:backlogPath

            $result.Summary.TotalProvisioned | Should -Be 0
            $result.Timeline.Count | Should -Be 0
        }

        It "Should return correct structure" {
            $backlog = @(
                @{ SamAccountName = "smbx_001"; Status = "PERMISSIONS_SET"; ACLGroup = "smbx_acl_001"; ErrorCode = "None"; CreatedAt = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss"); CompletedAt = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss") }
            )
            $backlog | ConvertTo-Json | Set-Content -Path $script:backlogPath

            $result = Get-MailboxProvisioningReport -BacklogPath $script:backlogPath

            $result.Period | Should -Not -BeNullOrEmpty
            $result.Summary | Should -Not -BeNullOrEmpty
            $result.ByStatus | Should -Not -BeNullOrEmpty
            $result.ByGroup | Should -Not -BeNullOrEmpty
            $result.Timeline | Should -Not -BeNullOrEmpty
            $result.TopFailures | Should -Not -BeNullOrEmpty
        }

        It "Should handle malformed dates gracefully" {
            $backlog = @(
                @{ SamAccountName = "smbx_001"; Status = "PERMISSIONS_SET"; CreatedAt = "invalid-date" }
                @{ SamAccountName = "smbx_002"; Status = "PERMISSIONS_SET"; CreatedAt = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss") }
            )
            $backlog | ConvertTo-Json | Set-Content -Path $script:backlogPath

            $result = Get-MailboxProvisioningReport -BacklogPath $script:backlogPath

            $result.Summary.TotalProvisioned | Should -Be 1
        }
    }
}
