Describe "Get-MailboxProvisioningStatus" {
    BeforeAll {
        Import-Module "$PSScriptRoot\..\SharedMailboxProvisioner.psd1" -Force

        $testGuid = New-Guid
        $testBacklogDir = Join-Path ([System.IO.Path]::GetTempPath()) "smp-test-status-$testGuid"
        $testBacklogPath = Join-Path $testBacklogDir "mailbox-provisioning-queue.json"

        if (-not (Test-Path $testBacklogDir)) {
            New-Item -ItemType Directory -Path $testBacklogDir -Force | Out-Null
        }
    }

    AfterAll {
        if (Test-Path $testBacklogDir) {
            Remove-Item $testBacklogDir -Recurse -Force
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
            $localBacklogPath = Join-Path $testBacklogDir "backlog-all.json"

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

            $backlog | ConvertTo-Json -Depth 10 | Set-Content -Path $localBacklogPath

            $result = Get-MailboxProvisioningStatus -BacklogPath $localBacklogPath

            $result.Count | Should -Be 2
            $result[0].SamAccountName | Should -Be "smbx_001"
            $result[1].SamAccountName | Should -Be "smbx_002"
        }
    }

    Context "Timeline Display" {
        It "Should include timeline when ShowTimeline switch is used" {
            $localBacklogPath = Join-Path $testBacklogDir "backlog-timeline.json"

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

            $backlog | ConvertTo-Json -Depth 10 | Set-Content -Path $localBacklogPath

            $result = Get-MailboxProvisioningStatus -SamAccountName "smbx_001" -ShowTimeline -BacklogPath $localBacklogPath

            $result.Timeline | Should -Not -BeNullOrEmpty
            $result.Timeline | Should -Match "\[CREATED\]"
            $result.Timeline | Should -Match "\[MAILBOX_CREATED\]"
            $result.Timeline | Should -Match "\[COMPLETED\]"
        }

        It "Should include retry attempt in timeline" {
            $localBacklogPath = Join-Path $testBacklogDir "backlog-retry.json"

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

            $backlog | ConvertTo-Json -Depth 10 | Set-Content -Path $localBacklogPath

            $result = Get-MailboxProvisioningStatus -SamAccountName "smbx_001" -ShowTimeline -BacklogPath $localBacklogPath

            $result.Timeline | Should -Match "\[RETRIED\]"
            $result.Timeline | Should -Match "1 of 5"
        }
    }

    Context "Error Handling" {
        It "Should handle missing backlog file gracefully" {
            $nonExistentPath = Join-Path $testBacklogDir "nonexistent-$((New-Guid).Guid).json"

            $result = Get-MailboxProvisioningStatus -SamAccountName "smbx_001" -BacklogPath $nonExistentPath -ErrorAction SilentlyContinue

            if ($result -is [array]) {
                $result.Count | Should -Be 0
            }
            else {
                $result | Should -BeNullOrEmpty
            }
        }

        It "Should handle empty backlog" {
            $emptyBacklogPath = Join-Path $testBacklogDir "empty.json"
            Set-Content -Path $emptyBacklogPath -Value ""

            $result = Get-MailboxProvisioningStatus -BacklogPath $emptyBacklogPath

            $result | Should -BeNullOrEmpty
        }
    }

    Context "Status Properties" {
        It "Should correctly map error codes" {
            $localBacklogPath = Join-Path $testBacklogDir "backlog-errors.json"

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

            $backlog | ConvertTo-Json -Depth 10 | Set-Content -Path $localBacklogPath

            $result = Get-MailboxProvisioningStatus -SamAccountName "smbx_001" -BacklogPath $localBacklogPath

            $result.ErrorCode | Should -Be "MailboxNotFound"
            $result.ErrorMessage | Should -Match "not found"
        }

        It "Should handle missing optional fields" {
            $localBacklogPath = Join-Path $testBacklogDir "backlog-minimal.json"

            $backlog = @(
                @{
                    SamAccountName = "smbx_001"
                    DisplayName = "Mailbox 001"
                    Email = "smbx001@contoso.com"
                    Status = "PENDING"
                    CreatedAt = "2026-06-30 10:00:00"
                }
            )

            $backlog | ConvertTo-Json -Depth 10 | Set-Content -Path $localBacklogPath

            $result = Get-MailboxProvisioningStatus -SamAccountName "smbx_001" -BacklogPath $localBacklogPath

            $result | Should -Not -BeNullOrEmpty
            $result.ErrorCode | Should -Be "None"
            $result.CompletedAt | Should -Be "Pending"
        }
    }
}
