BeforeAll {
    Import-Module "$PSScriptRoot\..\SharedMailboxProvisioner.psd1" -Force
}

Describe "Get-MailboxProvisioningMetrics" {
    Context "Metrics Calculation from Backlog" {
        BeforeEach {
            $script:testDir = Join-Path $env:TEMP "smp-metrics-$(Get-Random)"
            New-Item -ItemType Directory -Path $script:testDir -Force | Out-Null

            $script:backlogPath = Join-Path $script:testDir "test-backlog.json"
        }

        AfterEach {
            Remove-Item -Path $script:testDir -Recurse -Force -ErrorAction SilentlyContinue
        }

        It "Should calculate success rate KPI" {
            $now = Get-Date
            $backlog = @(
                @{ SamAccountName = "smbx_001"; Status = "PERMISSIONS_SET"; RetryCount = 0; CreatedAt = $now.ToString("yyyy-MM-dd HH:mm:ss"); CompletedAt = $now.ToString("yyyy-MM-dd HH:mm:ss"); ErrorCode = "None" }
                @{ SamAccountName = "smbx_002"; Status = "PERMISSIONS_SET"; RetryCount = 0; CreatedAt = $now.ToString("yyyy-MM-dd HH:mm:ss"); CompletedAt = $now.ToString("yyyy-MM-dd HH:mm:ss"); ErrorCode = "None" }
                @{ SamAccountName = "smbx_003"; Status = "FAILED_PERMISSIONS"; RetryCount = 3; CreatedAt = $now.ToString("yyyy-MM-dd HH:mm:ss"); CompletedAt = $now.ToString("yyyy-MM-dd HH:mm:ss"); ErrorCode = "MailboxNotFound" }
            )
            $backlog | ConvertTo-Json | Set-Content -Path $script:backlogPath

            $metrics = Get-MailboxProvisioningMetrics -BacklogPath $script:backlogPath

            $metrics.KPIs.SuccessRate | Should -Match "66"
        }

        It "Should calculate average time to completion" {
            $now = Get-Date
            $backlog = @(
                @{ SamAccountName = "smbx_001"; Status = "PERMISSIONS_SET"; RetryCount = 0; CreatedAt = $now.AddMinutes(-10).ToString("yyyy-MM-dd HH:mm:ss"); CompletedAt = $now.ToString("yyyy-MM-dd HH:mm:ss"); ErrorCode = "None" }
                @{ SamAccountName = "smbx_002"; Status = "PERMISSIONS_SET"; RetryCount = 0; CreatedAt = $now.AddMinutes(-20).ToString("yyyy-MM-dd HH:mm:ss"); CompletedAt = $now.ToString("yyyy-MM-dd HH:mm:ss"); ErrorCode = "None" }
            )
            $backlog | ConvertTo-Json | Set-Content -Path $script:backlogPath

            $metrics = Get-MailboxProvisioningMetrics -BacklogPath $script:backlogPath

            $metrics.KPIs.AvgTimeToCompletion | Should -Match "^\d{2}:\d{2}:\d{2}$"
        }

        It "Should calculate median time to completion" {
            $now = Get-Date
            $backlog = @(
                @{ SamAccountName = "smbx_001"; Status = "PERMISSIONS_SET"; RetryCount = 0; CreatedAt = $now.AddMinutes(-5).ToString("yyyy-MM-dd HH:mm:ss"); CompletedAt = $now.ToString("yyyy-MM-dd HH:mm:ss"); ErrorCode = "None" }
                @{ SamAccountName = "smbx_002"; Status = "PERMISSIONS_SET"; RetryCount = 0; CreatedAt = $now.AddMinutes(-15).ToString("yyyy-MM-dd HH:mm:ss"); CompletedAt = $now.ToString("yyyy-MM-dd HH:mm:ss"); ErrorCode = "None" }
                @{ SamAccountName = "smbx_003"; Status = "PERMISSIONS_SET"; RetryCount = 0; CreatedAt = $now.AddMinutes(-25).ToString("yyyy-MM-dd HH:mm:ss"); CompletedAt = $now.ToString("yyyy-MM-dd HH:mm:ss"); ErrorCode = "None" }
            )
            $backlog | ConvertTo-Json | Set-Content -Path $script:backlogPath

            $metrics = Get-MailboxProvisioningMetrics -BacklogPath $script:backlogPath

            $metrics.KPIs.MedianTimeToCompletion | Should -Match "^\d{2}:\d{2}:\d{2}$"
        }

        It "Should calculate retry ratio" {
            $now = Get-Date
            $backlog = @(
                @{ SamAccountName = "smbx_001"; Status = "PERMISSIONS_SET"; RetryCount = 0; CreatedAt = $now.ToString("yyyy-MM-dd HH:mm:ss"); CompletedAt = $now.ToString("yyyy-MM-dd HH:mm:ss"); ErrorCode = "None" }
                @{ SamAccountName = "smbx_002"; Status = "PERMISSIONS_SET"; RetryCount = 2; CreatedAt = $now.ToString("yyyy-MM-dd HH:mm:ss"); CompletedAt = $now.ToString("yyyy-MM-dd HH:mm:ss"); ErrorCode = "None" }
                @{ SamAccountName = "smbx_003"; Status = "PERMISSIONS_SET"; RetryCount = 1; CreatedAt = $now.ToString("yyyy-MM-dd HH:mm:ss"); CompletedAt = $now.ToString("yyyy-MM-dd HH:mm:ss"); ErrorCode = "None" }
            )
            $backlog | ConvertTo-Json | Set-Content -Path $script:backlogPath

            $metrics = Get-MailboxProvisioningMetrics -BacklogPath $script:backlogPath

            $metrics.KPIs.RetryRatio | Should -Be "0.67"
        }

        It "Should calculate mean time to recovery" {
            $now = Get-Date
            $backlog = @(
                @{ SamAccountName = "smbx_001"; Status = "PERMISSIONS_SET"; RetryCount = 2; CreatedAt = $now.AddMinutes(-30).ToString("yyyy-MM-dd HH:mm:ss"); CompletedAt = $now.ToString("yyyy-MM-dd HH:mm:ss"); ErrorCode = "None" }
                @{ SamAccountName = "smbx_002"; Status = "PERMISSIONS_SET"; RetryCount = 3; CreatedAt = $now.AddMinutes(-60).ToString("yyyy-MM-dd HH:mm:ss"); CompletedAt = $now.ToString("yyyy-MM-dd HH:mm:ss"); ErrorCode = "None" }
            )
            $backlog | ConvertTo-Json | Set-Content -Path $script:backlogPath

            $metrics = Get-MailboxProvisioningMetrics -BacklogPath $script:backlogPath

            $metrics.KPIs.MeanTimeToRecovery | Should -Match "^\d{2}:\d{2}:\d{2}$"
        }

        It "Should identify bottlenecks" {
            $now = Get-Date
            $backlog = @(
                @{ SamAccountName = "smbx_001"; Status = "FAILED_PERMISSIONS"; RetryCount = 3; CreatedAt = $now.ToString("yyyy-MM-dd HH:mm:ss"); CompletedAt = $now.ToString("yyyy-MM-dd HH:mm:ss"); ErrorCode = "MailboxNotFound" }
                @{ SamAccountName = "smbx_002"; Status = "FAILED_PERMISSIONS"; RetryCount = 3; CreatedAt = $now.ToString("yyyy-MM-dd HH:mm:ss"); CompletedAt = $now.ToString("yyyy-MM-dd HH:mm:ss"); ErrorCode = "MailboxNotFound" }
                @{ SamAccountName = "smbx_003"; Status = "FAILED_PERMISSIONS"; RetryCount = 3; CreatedAt = $now.ToString("yyyy-MM-dd HH:mm:ss"); CompletedAt = $now.ToString("yyyy-MM-dd HH:mm:ss"); ErrorCode = "PermissionError" }
            )
            $backlog | ConvertTo-Json | Set-Content -Path $script:backlogPath

            $metrics = Get-MailboxProvisioningMetrics -BacklogPath $script:backlogPath

            $metrics.Bottlenecks[0].Issue | Should -Be "MailboxNotFound"
            $metrics.Bottlenecks[0].Impact | Should -Be "HIGH"
        }

        It "Should rank bottleneck impact" {
            $now = Get-Date
            $backlog = @(
                @{ SamAccountName = "smbx_001"; Status = "FAILED_PERMISSIONS"; RetryCount = 3; CreatedAt = $now.ToString("yyyy-MM-dd HH:mm:ss"); CompletedAt = $now.ToString("yyyy-MM-dd HH:mm:ss"); ErrorCode = "Error1" }
                @{ SamAccountName = "smbx_002"; Status = "FAILED_PERMISSIONS"; RetryCount = 3; CreatedAt = $now.ToString("yyyy-MM-dd HH:mm:ss"); CompletedAt = $now.ToString("yyyy-MM-dd HH:mm:ss"); ErrorCode = "Error1" }
                @{ SamAccountName = "smbx_003"; Status = "FAILED_PERMISSIONS"; RetryCount = 3; CreatedAt = $now.ToString("yyyy-MM-dd HH:mm:ss"); CompletedAt = $now.ToString("yyyy-MM-dd HH:mm:ss"); ErrorCode = "Error2" }
            )
            $backlog | ConvertTo-Json | Set-Content -Path $script:backlogPath

            $metrics = Get-MailboxProvisioningMetrics -BacklogPath $script:backlogPath

            # Top error should be first
            $metrics.Bottlenecks | Should -Not -BeNullOrEmpty
            $metrics.Bottlenecks[0].Count | Should -Be 2
        }

        It "Should calculate 7-day trend" {
            $now = Get-Date
            $oneWeekAgo = $now.AddDays(-7)
            $backlog = @(
                @{ SamAccountName = "smbx_001"; Status = "PERMISSIONS_SET"; RetryCount = 0; CreatedAt = $oneWeekAgo.ToString("yyyy-MM-dd HH:mm:ss"); CompletedAt = $oneWeekAgo.ToString("yyyy-MM-dd HH:mm:ss"); ErrorCode = "None" }
                @{ SamAccountName = "smbx_002"; Status = "PERMISSIONS_SET"; RetryCount = 0; CreatedAt = $now.ToString("yyyy-MM-dd HH:mm:ss"); CompletedAt = $now.ToString("yyyy-MM-dd HH:mm:ss"); ErrorCode = "None" }
            )
            $backlog | ConvertTo-Json | Set-Content -Path $script:backlogPath

            $metrics = Get-MailboxProvisioningMetrics -BacklogPath $script:backlogPath

            $metrics.Trends.Last7Days.Rate | Should -Not -BeNullOrEmpty
            $metrics.Trends.Last7Days.Trend | Should -Match "UP|DOWN|STABLE"
        }

        It "Should calculate peak hours" {
            $now = Get-Date
            $backlog = @(
                @{ SamAccountName = "smbx_001"; Status = "PERMISSIONS_SET"; RetryCount = 0; CreatedAt = $now.ToString("yyyy-MM-dd HH:mm:ss"); CompletedAt = $now.ToString("yyyy-MM-dd HH:mm:ss"); ErrorCode = "None" }
                @{ SamAccountName = "smbx_002"; Status = "PERMISSIONS_SET"; RetryCount = 0; CreatedAt = $now.ToString("yyyy-MM-dd HH:mm:ss"); CompletedAt = $now.ToString("yyyy-MM-dd HH:mm:ss"); ErrorCode = "None" }
            )
            $backlog | ConvertTo-Json | Set-Content -Path $script:backlogPath

            $metrics = Get-MailboxProvisioningMetrics -BacklogPath $script:backlogPath

            $metrics.PeakHours | Should -Not -BeNullOrEmpty
            $metrics.PeakHours[0].Hour | Should -Match "^\d{2}:00$"
        }

        It "Should return correct structure" {
            $backlog = @()
            $backlog | ConvertTo-Json | Set-Content -Path $script:backlogPath

            $metrics = Get-MailboxProvisioningMetrics -BacklogPath $script:backlogPath

            $metrics.KPIs | Should -Not -BeNullOrEmpty
            $metrics.Bottlenecks | Should -Not -BeNullOrEmpty
            $metrics.Trends | Should -Not -BeNullOrEmpty
            $metrics.PeakHours | Should -Not -BeNullOrEmpty
        }
    }
}
