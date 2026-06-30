Describe "Invoke-MailboxProvisioningRetry" {
    BeforeAll {
        Import-Module "$PSScriptRoot\..\SharedMailboxProvisioner.psd1" -Force

        $testBacklogDir = Join-Path ([System.IO.Path]::GetTempPath()) "smp-test-tier10-retry"
        $testBacklogPath = Join-Path $testBacklogDir "mailbox-provisioning-queue.json"

        if (-not (Test-Path $testBacklogDir)) {
            New-Item -ItemType Directory -Path $testBacklogDir -Force | Out-Null
        }
    }

    AfterEach {
        if (Test-Path $testBacklogPath) {
            Remove-Item $testBacklogPath -Force
        }
    }

    Context "Retry Single Mailbox" {
        It "Should increment retry count and update status" {
            $backlog = @(
                @{
                    SamAccountName = "smbx_001"
                    DisplayName = "Mailbox 001"
                    Email = "smbx001@contoso.com"
                    Status = "FAILED_MAILBOX"
                    ErrorCode = "MailboxNotFound"
                    RetryCount = 0
                    MaxRetries = 5
                    LastRetryAt = $null
                }
            )

            $backlog | ConvertTo-Json -Depth 10 | Set-Content -Path $testBacklogPath

            $result = Invoke-MailboxProvisioningRetry -SamAccountName "smbx_001" -BacklogPath $testBacklogPath

            $result | Should -Be $true

            $updatedBacklog = Get-Content -Path $testBacklogPath | ConvertFrom-Json
            $updatedBacklog.RetryCount | Should -Be 1
            $updatedBacklog.Status | Should -Be "PENDING_RETRY"
            $updatedBacklog.LastRetryAt | Should -Not -BeNullOrEmpty
        }
    }

    Context "Retry All Failed Mailboxes" {
        It "Should retry all failed mailboxes within retry limit" {
            $backlog = @(
                @{
                    SamAccountName = "smbx_001"
                    DisplayName = "Mailbox 001"
                    Email = "smbx001@contoso.com"
                    Status = "FAILED_MAILBOX"
                    RetryCount = 0
                    MaxRetries = 5
                },
                @{
                    SamAccountName = "smbx_002"
                    DisplayName = "Mailbox 002"
                    Email = "smbx002@contoso.com"
                    Status = "FAILED_PERMISSIONS"
                    RetryCount = 1
                    MaxRetries = 5
                }
            )

            $backlog | ConvertTo-Json -Depth 10 | Set-Content -Path $testBacklogPath

            $result = Invoke-MailboxProvisioningRetry -RetryAll -BacklogPath $testBacklogPath

            $result | Should -Be $true

            $updatedBacklog = Get-Content -Path $testBacklogPath | ConvertFrom-Json
            $updatedBacklog[0].RetryCount | Should -Be 1
            $updatedBacklog[1].RetryCount | Should -Be 2
        }
    }

    Context "Respect Max Retry Limit" {
        It "Should skip mailbox when max retries reached" {
            $backlog = @(
                @{
                    SamAccountName = "smbx_001"
                    DisplayName = "Mailbox 001"
                    Email = "smbx001@contoso.com"
                    Status = "FAILED_MAILBOX"
                    RetryCount = 5
                    MaxRetries = 5
                },
                @{
                    SamAccountName = "smbx_002"
                    DisplayName = "Mailbox 002"
                    Email = "smbx002@contoso.com"
                    Status = "FAILED_MAILBOX"
                    RetryCount = 2
                    MaxRetries = 5
                }
            )

            $backlog | ConvertTo-Json -Depth 10 | Set-Content -Path $testBacklogPath

            $result = Invoke-MailboxProvisioningRetry -RetryAll -BacklogPath $testBacklogPath

            $updatedBacklog = Get-Content -Path $testBacklogPath | ConvertFrom-Json
            $updatedBacklog[0].RetryCount | Should -Be 5
            $updatedBacklog[1].RetryCount | Should -Be 3
        }

        It "Should override max retry limit with -Force flag" {
            $backlog = @(
                @{
                    SamAccountName = "smbx_001"
                    DisplayName = "Mailbox 001"
                    Email = "smbx001@contoso.com"
                    Status = "FAILED_MAILBOX"
                    RetryCount = 5
                    MaxRetries = 5
                }
            )

            $backlog | ConvertTo-Json -Depth 10 | Set-Content -Path $testBacklogPath

            $result = Invoke-MailboxProvisioningRetry -SamAccountName "smbx_001" -Force -BacklogPath $testBacklogPath

            $result | Should -Be $true

            $updatedBacklog = Get-Content -Path $testBacklogPath | ConvertFrom-Json
            $updatedBacklog.RetryCount | Should -Be 6
        }
    }

    Context "Error Handling" {
        It "Should return false when no SamAccountName and no RetryAll specified" {
            $result = Invoke-MailboxProvisioningRetry -BacklogPath $testBacklogPath -ErrorAction SilentlyContinue

            $result | Should -Be $false
        }

        It "Should handle missing backlog file" {
            $result = Invoke-MailboxProvisioningRetry -SamAccountName "smbx_001" -BacklogPath "nonexistent.json" -ErrorAction SilentlyContinue

            $result | Should -Be $false
        }

        It "Should return false when no entries match" {
            $backlog = @(
                @{
                    SamAccountName = "smbx_001"
                    Status = "SUCCESS"
                    RetryCount = 0
                    MaxRetries = 5
                }
            )

            $backlog | ConvertTo-Json -Depth 10 | Set-Content -Path $testBacklogPath

            $result = Invoke-MailboxProvisioningRetry -SamAccountName "smbx_999" -BacklogPath $testBacklogPath

            $result | Should -Be $false
        }
    }

    Context "Retry Timestamp" {
        It "Should update LastRetryAt timestamp" {
            $backlog = @(
                @{
                    SamAccountName = "smbx_001"
                    DisplayName = "Mailbox 001"
                    Email = "smbx001@contoso.com"
                    Status = "FAILED_MAILBOX"
                    RetryCount = 0
                    MaxRetries = 5
                    LastRetryAt = $null
                }
            )

            $backlog | ConvertTo-Json -Depth 10 | Set-Content -Path $testBacklogPath
            $beforeTime = Get-Date

            $result = Invoke-MailboxProvisioningRetry -SamAccountName "smbx_001" -BacklogPath $testBacklogPath

            $updatedBacklog = Get-Content -Path $testBacklogPath | ConvertFrom-Json
            $updatedBacklog.LastRetryAt | Should -Not -BeNullOrEmpty
        }
    }

    Context "Backlog File Update" {
        It "Should persist changes to backlog file" {
            $backlog = @(
                @{
                    SamAccountName = "smbx_001"
                    DisplayName = "Mailbox 001"
                    Email = "smbx001@contoso.com"
                    Status = "FAILED_MAILBOX"
                    RetryCount = 0
                    MaxRetries = 5
                }
            )

            $backlog | ConvertTo-Json -Depth 10 | Set-Content -Path $testBacklogPath

            Invoke-MailboxProvisioningRetry -SamAccountName "smbx_001" -BacklogPath $testBacklogPath | Out-Null

            $fileContent = Get-Content -Path $testBacklogPath -Raw
            $fileContent | Should -Not -BeNullOrEmpty
            $fileContent | Should -Match "PENDING_RETRY"
        }
    }
}
