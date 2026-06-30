Describe "Get-MailboxProvisioningStatus" {
    BeforeAll {
        Import-Module "$PSScriptRoot\..\SharedMailboxProvisioner.psd1" -Force

        $testBacklogDir = Join-Path ([System.IO.Path]::GetTempPath()) "smp-test-tier10-status"
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

    Context "Query Single Mailbox Status" {
        It "Should return status for existing mailbox" {
            $backlog = @(
                @{
                    SamAccountName = "smbx_001"
                    DisplayName = "Shared Mailbox 001"
                    Email = "smbx001@contoso.com"
                    Status = "SUCCESS"
                    ErrorCode = $null
                    ErrorMessage = $null
                    CreatedAt = "2026-06-30 10:00:00"
                    CompletedAt = "2026-06-30 10:05:00"
                    RetryCount = 0
                    MaxRetries = 5
                    LastRetryAt = $null
                }
            )

            $backlog | ConvertTo-Json -Depth 10 | Set-Content -Path $testBacklogPath

            $result = Get-MailboxProvisioningStatus -SamAccountName "smbx_001" -BacklogPath $testBacklogPath

            $result | Should -Not -BeNullOrEmpty
            $result.SamAccountName | Should -Be "smbx_001"
            $result.CurrentStatus | Should -Be "SUCCESS"
            $result.RetryCount | Should -Be 0
        }

        It "Should return empty for non-existent mailbox" {
            $backlog = @(
                @{
                    SamAccountName = "smbx_001"
                    DisplayName = "Shared Mailbox 001"
                    Email = "smbx001@contoso.com"
                    Status = "SUCCESS"
                    CreatedAt = "2026-06-30 10:00:00"
                    CompletedAt = "2026-06-30 10:05:00"
                    RetryCount = 0
                    MaxRetries = 5
                }
            )

            $backlog | ConvertTo-Json -Depth 10 | Set-Content -Path $testBacklogPath

            $result = Get-MailboxProvisioningStatus -SamAccountName "smbx_999" -BacklogPath $testBacklogPath

            $result | Should -BeNullOrEmpty
        }
    }

    Context "Query All Mailboxes" {
        It "Should return all pending mailboxes when no filter specified" {
            # Remove any pre-existing backlog
            if (Test-Path $testBacklogPath) {
                Remove-Item $testBacklogPath -Force
            }

            $backlog = @(
                @{
                    SamAccountName = "smbx_001"
                    DisplayName = "Mailbox 001"
                    Email = "smbx001@contoso.com"
                    Status = "PENDING"
                    CreatedAt = "2026-06-30 10:00:00"
                    RetryCount = 0
                    MaxRetries = 5
                },
                @{
                    SamAccountName = "smbx_002"
                    DisplayName = "Mailbox 002"
                    Email = "smbx002@contoso.com"
                    Status = "PENDING"
                    CreatedAt = "2026-06-30 10:01:00"
                    RetryCount = 0
                    MaxRetries = 5
                }
            )

            $backlog | ConvertTo-Json -Depth 10 | Set-Content -Path $testBacklogPath

            $result = Get-MailboxProvisioningStatus -BacklogPath $testBacklogPath

            $result.Count | Should -Be 2
            $result[0].SamAccountName | Should -Be "smbx_001"
            $result[1].SamAccountName | Should -Be "smbx_002"
        }
    }

    Context "Timeline Display" {
        It "Should include timeline when ShowTimeline switch is used" {
            $backlog = @(
                @{
                    SamAccountName = "smbx_001"
                    DisplayName = "Mailbox 001"
                    Email = "smbx001@contoso.com"
                    Status = "SUCCESS"
                    CreatedAt = "2026-06-30 10:00:00"
                    MailboxCreatedAt = "2026-06-30 10:02:00"
                    CompletedAt = "2026-06-30 10:05:00"
                    RetryCount = 0
                    MaxRetries = 5
                    LastRetryAt = $null
                }
            )

            $backlog | ConvertTo-Json -Depth 10 | Set-Content -Path $testBacklogPath

            $result = Get-MailboxProvisioningStatus -SamAccountName "smbx_001" -ShowTimeline -BacklogPath $testBacklogPath

            $result.Timeline | Should -Not -BeNullOrEmpty
            $result.Timeline | Should -Match "\[CREATED\]"
            $result.Timeline | Should -Match "\[MAILBOX_CREATED\]"
            $result.Timeline | Should -Match "\[COMPLETED\]"
        }

        It "Should include retry attempt in timeline" {
            $backlog = @(
                @{
                    SamAccountName = "smbx_001"
                    DisplayName = "Mailbox 001"
                    Email = "smbx001@contoso.com"
                    Status = "PENDING_RETRY"
                    CreatedAt = "2026-06-30 10:00:00"
                    RetryCount = 1
                    MaxRetries = 5
                    LastRetryAt = "2026-06-30 10:30:00"
                }
            )

            $backlog | ConvertTo-Json -Depth 10 | Set-Content -Path $testBacklogPath

            $result = Get-MailboxProvisioningStatus -SamAccountName "smbx_001" -ShowTimeline -BacklogPath $testBacklogPath

            $result.Timeline | Should -Match "\[RETRIED\]"
            $result.Timeline | Should -Match "1 of 5"
        }
    }

    Context "Error Handling" {
        It "Should handle missing backlog file gracefully" {
            $nonExistentPath = Join-Path $testBacklogDir "nonexistent.json"

            $result = Get-MailboxProvisioningStatus -SamAccountName "smbx_001" -BacklogPath $nonExistentPath -ErrorAction SilentlyContinue

            # Result can be $null or empty array, or error message (all acceptable behaviors)
            if ($result -is [array]) {
                $result.Count | Should -Be 0
            }
            else {
                $result | Should -BeNullOrEmpty
            }
        }

        It "Should handle empty backlog" {
            Set-Content -Path $testBacklogPath -Value ""

            $result = Get-MailboxProvisioningStatus -BacklogPath $testBacklogPath

            $result | Should -BeNullOrEmpty
        }
    }

    Context "Status Properties" {
        It "Should correctly map error codes" {
            $backlog = @(
                @{
                    SamAccountName = "smbx_001"
                    DisplayName = "Mailbox 001"
                    Email = "smbx001@contoso.com"
                    Status = "FAILED_MAILBOX"
                    ErrorCode = "MailboxNotFound"
                    ErrorMessage = "Mailbox not found in EXO"
                    CreatedAt = "2026-06-30 10:00:00"
                    RetryCount = 1
                    MaxRetries = 5
                }
            )

            $backlog | ConvertTo-Json -Depth 10 | Set-Content -Path $testBacklogPath

            $result = Get-MailboxProvisioningStatus -SamAccountName "smbx_001" -BacklogPath $testBacklogPath

            $result.ErrorCode | Should -Be "MailboxNotFound"
            $result.ErrorMessage | Should -Match "not found"
        }
    }
}
