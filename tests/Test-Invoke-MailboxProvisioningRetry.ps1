Describe "Invoke-MailboxProvisioningRetry" {
    BeforeAll {
        Import-Module "$PSScriptRoot\..\SharedMailboxProvisioner.psd1" -Force

        $testGuid = New-Guid
        $testBacklogDir = Join-Path ([System.IO.Path]::GetTempPath()) "smp-test-retry-$testGuid"

        if (-not (Test-Path $testBacklogDir)) {
            New-Item -ItemType Directory -Path $testBacklogDir -Force | Out-Null
        }
    }

    AfterAll {
        if (Test-Path $testBacklogDir) {
            Remove-Item $testBacklogDir -Recurse -Force
        }
    }

    Context "Retry Single Mailbox" {
        It "Should increment retry count and update status" {
            $localBacklogPath = Join-Path $testBacklogDir "retry-single.json"

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

            $backlog | ConvertTo-Json -Depth 10 | Set-Content -Path $localBacklogPath

            $result = Invoke-MailboxProvisioningRetry -SamAccountName "smbx_001" -BacklogPath $localBacklogPath

            $result | Should -Be $true

            $updatedBacklog = Get-Content -Path $localBacklogPath | ConvertFrom-Json
            $updatedBacklog.RetryCount | Should -Be 1
            $updatedBacklog.Status | Should -Be "PENDING_RETRY"
            $updatedBacklog.LastRetryAt | Should -Not -BeNullOrEmpty
        }
    }

    Context "Retry All Failed Mailboxes" {
        It "Should retry all failed mailboxes within retry limit" {
            $localBacklogPath = Join-Path $testBacklogDir "retry-all.json"

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

            $backlog | ConvertTo-Json -Depth 10 | Set-Content -Path $localBacklogPath

            $result = Invoke-MailboxProvisioningRetry -RetryAll -BacklogPath $localBacklogPath

            $result | Should -Be $true

            $updatedBacklog = Get-Content -Path $localBacklogPath | ConvertFrom-Json
            $updatedBacklog[0].RetryCount | Should -Be 1
            $updatedBacklog[1].RetryCount | Should -Be 2
        }
    }

    Context "Respect Max Retry Limit" {
        It "Should skip mailbox when max retries reached" {
            $localBacklogPath = Join-Path $testBacklogDir "retry-maxlimit.json"

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

            $backlog | ConvertTo-Json -Depth 10 | Set-Content -Path $localBacklogPath

            $null = Invoke-MailboxProvisioningRetry -RetryAll -BacklogPath $localBacklogPath

            $updatedBacklog = Get-Content -Path $localBacklogPath | ConvertFrom-Json
            $updatedBacklog[0].RetryCount | Should -Be 5
            $updatedBacklog[1].RetryCount | Should -Be 3
        }

        It "Should override max retry limit with -Force flag" {
            $localBacklogPath = Join-Path $testBacklogDir "retry-force.json"

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

            $backlog | ConvertTo-Json -Depth 10 | Set-Content -Path $localBacklogPath

            $result = Invoke-MailboxProvisioningRetry -SamAccountName "smbx_001" -Force -BacklogPath $localBacklogPath

            $result | Should -Be $true

            $updatedBacklog = Get-Content -Path $localBacklogPath | ConvertFrom-Json
            $updatedBacklog.RetryCount | Should -Be 6
        }
    }

    Context "Error Handling" {
        It "Should return false when no SamAccountName and no RetryAll specified" {
            $localBacklogPath = Join-Path $testBacklogDir "retry-noparams.json"

            $result = Invoke-MailboxProvisioningRetry -BacklogPath $localBacklogPath -ErrorAction SilentlyContinue

            $result | Should -Be $false
        }

        It "Should handle missing backlog file" {
            $nonExistentPath = Join-Path $testBacklogDir "nonexistent-$((New-Guid).Guid).json"

            $result = Invoke-MailboxProvisioningRetry -SamAccountName "smbx_001" -BacklogPath $nonExistentPath -ErrorAction SilentlyContinue

            $result | Should -Be $false
        }

        It "Should return false when no entries match" {
            $localBacklogPath = Join-Path $testBacklogDir "retry-nomatch.json"

            $backlog = @(
                @{
                    SamAccountName = "smbx_001"
                    Status = "SUCCESS"
                    RetryCount = 0
                    MaxRetries = 5
                }
            )

            $backlog | ConvertTo-Json -Depth 10 | Set-Content -Path $localBacklogPath

            $result = Invoke-MailboxProvisioningRetry -SamAccountName "smbx_999" -BacklogPath $localBacklogPath

            $result | Should -Be $false
        }
    }

    Context "Retry Timestamp" {
        It "Should update LastRetryAt timestamp" {
            $localBacklogPath = Join-Path $testBacklogDir "retry-timestamp.json"

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

            $backlog | ConvertTo-Json -Depth 10 | Set-Content -Path $localBacklogPath

            $null = Invoke-MailboxProvisioningRetry -SamAccountName "smbx_001" -BacklogPath $localBacklogPath

            $updatedBacklog = Get-Content -Path $localBacklogPath | ConvertFrom-Json
            $updatedBacklog.LastRetryAt | Should -Not -BeNullOrEmpty
        }
    }

    Context "Backlog File Persistence" {
        It "Should persist changes to backlog file" {
            $localBacklogPath = Join-Path $testBacklogDir "retry-persist.json"

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

            $backlog | ConvertTo-Json -Depth 10 | Set-Content -Path $localBacklogPath

            Invoke-MailboxProvisioningRetry -SamAccountName "smbx_001" -BacklogPath $localBacklogPath | Out-Null

            $fileContent = Get-Content -Path $localBacklogPath -Raw
            $fileContent | Should -Not -BeNullOrEmpty
            $fileContent | Should -Match "PENDING_RETRY"
        }
    }
}
