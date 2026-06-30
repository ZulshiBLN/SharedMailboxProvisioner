Describe "Resolve-MailboxProvisioningFailure" {
    BeforeAll {
        Import-Module "$PSScriptRoot\..\SharedMailboxProvisioner.psd1" -Force

        $testBacklogDir = Join-Path ([System.IO.Path]::GetTempPath()) "smp-test-tier10-resolve"
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

    Context "Diagnose Single Failure" {
        It "Should diagnose MailboxNotFound error" {
            $backlog = @(
                @{
                    SamAccountName = "smbx_001"
                    DisplayName = "Mailbox 001"
                    Email = "smbx001@contoso.com"
                    Status = "FAILED_MAILBOX"
                    ErrorCode = "MailboxNotFound"
                    ErrorMessage = "Mailbox not visible in EXO"
                    RetryCount = 1
                    MaxRetries = 5
                }
            )

            $backlog | ConvertTo-Json -Depth 10 | Set-Content -Path $testBacklogPath

            $result = Resolve-MailboxProvisioningFailure -SamAccountName "smbx_001" -BacklogPath $testBacklogPath

            $result | Should -Not -BeNullOrEmpty
            $result.CanRetry | Should -Be $true
            $result.RecommendedAction | Should -Match "RETRY"
            $result.RecommendedAction | Should -Match "60 minutes"
        }

        It "Should diagnose GroupNotFound error as non-retryable" {
            $backlog = @(
                @{
                    SamAccountName = "smbx_001"
                    DisplayName = "Mailbox 001"
                    Email = "smbx001@contoso.com"
                    Status = "FAILED_PERMISSIONS"
                    ErrorCode = "GroupNotFound"
                    ErrorMessage = "ACL group not found"
                    RetryCount = 0
                    MaxRetries = 5
                }
            )

            $backlog | ConvertTo-Json -Depth 10 | Set-Content -Path $testBacklogPath

            $result = Resolve-MailboxProvisioningFailure -SamAccountName "smbx_001" -BacklogPath $testBacklogPath

            $result.CanRetry | Should -Be $false
            $result.RecommendedAction | Should -Match "ESCALATE"
            $result.RecommendedAction | Should -Match "ACL group"
        }

        It "Should diagnose PermissionError as retryable" {
            $backlog = @(
                @{
                    SamAccountName = "smbx_001"
                    DisplayName = "Mailbox 001"
                    Email = "smbx001@contoso.com"
                    Status = "FAILED_PERMISSIONS"
                    ErrorCode = "PermissionError"
                    ErrorMessage = "Service account lacks permissions"
                    RetryCount = 0
                    MaxRetries = 5
                }
            )

            $backlog | ConvertTo-Json -Depth 10 | Set-Content -Path $testBacklogPath

            $result = Resolve-MailboxProvisioningFailure -SamAccountName "smbx_001" -BacklogPath $testBacklogPath

            $result.CanRetry | Should -Be $true
            $result.RecommendedAction | Should -Match "Check service account"
        }
    }

    Context "Diagnose All Failures" {
        It "Should analyze multiple failed mailboxes" {
            $backlog = @(
                @{
                    SamAccountName = "smbx_001"
                    DisplayName = "Mailbox 001"
                    Email = "smbx001@contoso.com"
                    Status = "FAILED_MAILBOX"
                    ErrorCode = "MailboxNotFound"
                    RetryCount = 0
                    MaxRetries = 5
                },
                @{
                    SamAccountName = "smbx_002"
                    DisplayName = "Mailbox 002"
                    Email = "smbx002@contoso.com"
                    Status = "FAILED_PERMISSIONS"
                    ErrorCode = "GroupNotFound"
                    RetryCount = 0
                    MaxRetries = 5
                },
                @{
                    SamAccountName = "smbx_003"
                    DisplayName = "Mailbox 003"
                    Email = "smbx003@contoso.com"
                    Status = "SUCCESS"
                    ErrorCode = $null
                    RetryCount = 0
                    MaxRetries = 5
                }
            )

            $backlog | ConvertTo-Json -Depth 10 | Set-Content -Path $testBacklogPath

            $result = Resolve-MailboxProvisioningFailure -DiagnoseAll -BacklogPath $testBacklogPath

            $result.Count | Should -Be 2
            $result[0].CanRetry | Should -Be $true
            $result[1].CanRetry | Should -Be $false
        }
    }

    Context "Max Retry Reached" {
        It "Should recommend escalation when max retries exceeded" {
            $backlog = @(
                @{
                    SamAccountName = "smbx_001"
                    DisplayName = "Mailbox 001"
                    Email = "smbx001@contoso.com"
                    Status = "FAILED_MAILBOX"
                    ErrorCode = "MailboxNotFound"
                    RetryCount = 5
                    MaxRetries = 5
                }
            )

            $backlog | ConvertTo-Json -Depth 10 | Set-Content -Path $testBacklogPath

            $result = Resolve-MailboxProvisioningFailure -SamAccountName "smbx_001" -BacklogPath $testBacklogPath

            $result.CanRetry | Should -Be $false
            $result.RecommendedAction | Should -Match "Max retries"
            $result.RecommendedAction | Should -Match "ESCALATE"
        }
    }

    Context "Error Codes" {
        It "Should handle InvalidMailbox error" {
            $backlog = @(
                @{
                    SamAccountName = "invalid"
                    DisplayName = "Bad Mailbox"
                    Email = "invalid-email"
                    Status = "FAILED_MAILBOX"
                    ErrorCode = "InvalidMailbox"
                    RetryCount = 0
                    MaxRetries = 5
                }
            )

            $backlog | ConvertTo-Json -Depth 10 | Set-Content -Path $testBacklogPath

            $result = Resolve-MailboxProvisioningFailure -SamAccountName "invalid" -BacklogPath $testBacklogPath

            $result.CanRetry | Should -Be $false
            $result.RecommendedAction | Should -Match "SAM prefix"
        }

        It "Should handle ADConnectDelay error" {
            $backlog = @(
                @{
                    SamAccountName = "smbx_001"
                    DisplayName = "Mailbox 001"
                    Email = "smbx001@contoso.com"
                    Status = "FAILED_MAILBOX"
                    ErrorCode = "ADConnectDelay"
                    RetryCount = 0
                    MaxRetries = 5
                }
            )

            $backlog | ConvertTo-Json -Depth 10 | Set-Content -Path $testBacklogPath

            $result = Resolve-MailboxProvisioningFailure -SamAccountName "smbx_001" -BacklogPath $testBacklogPath

            $result.CanRetry | Should -Be $true
            $result.RecommendedAction | Should -Match "60 min"
        }

        It "Should handle unknown error code with default diagnosis" {
            $backlog = @(
                @{
                    SamAccountName = "smbx_001"
                    DisplayName = "Mailbox 001"
                    Email = "smbx001@contoso.com"
                    Status = "FAILED_MAILBOX"
                    ErrorCode = "UnknownError"
                    RetryCount = 2
                    MaxRetries = 5
                }
            )

            $backlog | ConvertTo-Json -Depth 10 | Set-Content -Path $testBacklogPath

            $result = Resolve-MailboxProvisioningFailure -SamAccountName "smbx_001" -BacklogPath $testBacklogPath

            $result.CanRetry | Should -Be $true
            $result.Details | Should -Match "Unknown error"
        }
    }

    Context "Error Handling" {
        It "Should handle missing backlog file" {
            $result = Resolve-MailboxProvisioningFailure -SamAccountName "smbx_001" -BacklogPath "nonexistent.json" -ErrorAction SilentlyContinue

            $result | Should -BeNullOrEmpty
        }

        It "Should return empty when no failures exist" {
            $backlog = @(
                @{
                    SamAccountName = "smbx_001"
                    Status = "SUCCESS"
                    RetryCount = 0
                    MaxRetries = 5
                }
            )

            $backlog | ConvertTo-Json -Depth 10 | Set-Content -Path $testBacklogPath

            $result = Resolve-MailboxProvisioningFailure -DiagnoseAll -BacklogPath $testBacklogPath

            $result | Should -BeNullOrEmpty
        }
    }
}
