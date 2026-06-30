Describe "Resolve-MailboxProvisioningFailure" {
    BeforeAll {
        Import-Module "$PSScriptRoot\..\SharedMailboxProvisioner.psd1" -Force

        $testGuid = New-Guid
        $testBacklogDir = Join-Path ([System.IO.Path]::GetTempPath()) "smp-test-resolve-$testGuid"

        if (-not (Test-Path $testBacklogDir)) {
            New-Item -ItemType Directory -Path $testBacklogDir -Force | Out-Null
        }
    }

    AfterAll {
        if (Test-Path $testBacklogDir) {
            Remove-Item $testBacklogDir -Recurse -Force
        }
    }

    Context "Diagnose Single Failure" {
        It "Should diagnose MailboxNotFound error as retryable" {
            $localBacklogPath = Join-Path $testBacklogDir "diagnose-mailbox.json"

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

            $backlog | ConvertTo-Json -Depth 10 | Set-Content -Path $localBacklogPath

            $result = Resolve-MailboxProvisioningFailure -SamAccountName "smbx_001" -BacklogPath $localBacklogPath

            $result | Should -Not -BeNullOrEmpty
            $result.CanRetry | Should -Be $true
            $result.RecommendedAction | Should -Match "RETRY"
            $result.RecommendedAction | Should -Match "60 minutes"
        }

        It "Should diagnose GroupNotFound error as non-retryable" {
            $localBacklogPath = Join-Path $testBacklogDir "diagnose-group.json"

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

            $backlog | ConvertTo-Json -Depth 10 | Set-Content -Path $localBacklogPath

            $result = Resolve-MailboxProvisioningFailure -SamAccountName "smbx_001" -BacklogPath $localBacklogPath

            $result.CanRetry | Should -Be $false
            $result.RecommendedAction | Should -Match "ESCALATE"
            $result.RecommendedAction | Should -Match "ACL group"
        }

        It "Should diagnose PermissionError as retryable" {
            $localBacklogPath = Join-Path $testBacklogDir "diagnose-permission.json"

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

            $backlog | ConvertTo-Json -Depth 10 | Set-Content -Path $localBacklogPath

            $result = Resolve-MailboxProvisioningFailure -SamAccountName "smbx_001" -BacklogPath $localBacklogPath

            $result.CanRetry | Should -Be $true
            $result.RecommendedAction | Should -Match "Check service account"
        }
    }

    Context "Diagnose All Failures" {
        It "Should analyze multiple failed mailboxes" {
            $localBacklogPath = Join-Path $testBacklogDir "diagnose-all.json"

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

            $backlog | ConvertTo-Json -Depth 10 | Set-Content -Path $localBacklogPath

            $result = Resolve-MailboxProvisioningFailure -DiagnoseAll -BacklogPath $localBacklogPath

            $result.Count | Should -Be 2
            $result[0].CanRetry | Should -Be $true
            $result[1].CanRetry | Should -Be $false
        }
    }

    Context "Max Retry Exceeded" {
        It "Should recommend escalation when max retries exceeded" {
            $localBacklogPath = Join-Path $testBacklogDir "diagnose-maxretry.json"

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

            $backlog | ConvertTo-Json -Depth 10 | Set-Content -Path $localBacklogPath

            $result = Resolve-MailboxProvisioningFailure -SamAccountName "smbx_001" -BacklogPath $localBacklogPath

            $result.CanRetry | Should -Be $false
            $result.RecommendedAction | Should -Match "Max retries"
            $result.RecommendedAction | Should -Match "ESCALATE"
        }
    }

    Context "Error Code Handling" {
        It "Should handle InvalidMailbox error code" {
            $localBacklogPath = Join-Path $testBacklogDir "diagnose-invalid.json"

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

            $backlog | ConvertTo-Json -Depth 10 | Set-Content -Path $localBacklogPath

            $result = Resolve-MailboxProvisioningFailure -SamAccountName "invalid" -BacklogPath $localBacklogPath

            $result.CanRetry | Should -Be $false
            $result.RecommendedAction | Should -Match "SAM prefix"
        }

        It "Should handle ADConnectDelay error code" {
            $localBacklogPath = Join-Path $testBacklogDir "diagnose-addelay.json"

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

            $backlog | ConvertTo-Json -Depth 10 | Set-Content -Path $localBacklogPath

            $result = Resolve-MailboxProvisioningFailure -SamAccountName "smbx_001" -BacklogPath $localBacklogPath

            $result.CanRetry | Should -Be $true
            $result.RecommendedAction | Should -Match "60 min"
        }

        It "Should handle unknown error codes with default diagnosis" {
            $localBacklogPath = Join-Path $testBacklogDir "diagnose-unknown.json"

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

            $backlog | ConvertTo-Json -Depth 10 | Set-Content -Path $localBacklogPath

            $result = Resolve-MailboxProvisioningFailure -SamAccountName "smbx_001" -BacklogPath $localBacklogPath

            $result.CanRetry | Should -Be $true
            $result.Details | Should -Match "Unknown error"
        }
    }

    Context "Error Handling" {
        It "Should handle missing backlog file gracefully" {
            $nonExistentPath = Join-Path $testBacklogDir "nonexistent-$((New-Guid).Guid).json"

            $result = Resolve-MailboxProvisioningFailure -SamAccountName "smbx_001" -BacklogPath $nonExistentPath -ErrorAction SilentlyContinue

            $result | Should -BeNullOrEmpty
        }

        It "Should return empty when no failures exist" {
            $localBacklogPath = Join-Path $testBacklogDir "diagnose-nofailures.json"

            $backlog = @(
                @{
                    SamAccountName = "smbx_001"
                    Status = "SUCCESS"
                    RetryCount = 0
                    MaxRetries = 5
                }
            )

            $backlog | ConvertTo-Json -Depth 10 | Set-Content -Path $localBacklogPath

            $result = Resolve-MailboxProvisioningFailure -DiagnoseAll -BacklogPath $localBacklogPath

            $result | Should -BeNullOrEmpty
        }
    }
}
