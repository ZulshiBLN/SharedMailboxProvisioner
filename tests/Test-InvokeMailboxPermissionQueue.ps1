<#
.SYNOPSIS
Unit tests for Invoke-MailboxPermissionQueue function
#>

# Import function
$projectRoot = Split-Path -Parent $PSScriptRoot
$functionPath = Join-Path (Join-Path $projectRoot "functions") "Public\Invoke-MailboxPermissionQueue.ps1"
. $functionPath

Describe "InvokeMailboxPermissionQueue" {

    Context "Successful permission assignment" {
        It "Should process pending mailbox successfully" {
            $mockBacklog = @{
                version = "1.0"
                metadata = @{ lastUpdated = "2026-06-29T10:00:00Z"; totalEntries = 1; pendingEntries = 1; completedEntries = 0; failedEntries = 0 }
                entries = @(
                    @{
                        id = "smbx_123456"
                        samAccountName = "smbx_123456"
                        aclGroup = "smbx_acl_123456"
                        adminGroup = "ZO-Mail-Admins"
                        mailboxName = "Sales Team"
                        primarySmtpAddress = "sales@ethz.ch"
                        status = "MAILBOX_CREATED_AWAITING_PERMISSIONS"
                        createdAt = "2026-06-29T10:00:00Z"
                        lastAttemptAt = $null
                        retryCount = 0
                        maxRetries = 5
                        completedAt = $null
                        errors = @()
                        notes = "Test entry"
                    }
                )
            }

            Mock Get-Content { return ($mockBacklog | ConvertTo-Json -Depth 10) }
            Mock Test-Path { return $true }
            Mock Add-MailboxPermission { }
            Mock Add-RecipientPermission { }
            Mock Get-PSSession { return $null }
            Mock Connect-ExchangeOnline { }
            Mock Get-ADUser { }
            Mock Set-ADUser { }
            Mock Set-Content { }
            Mock Export-Csv { }

            $result = Invoke-MailboxPermissionQueue -BacklogPath "C:\test\backlog.json"

            $result | Should -Not -BeNullOrEmpty
            $result.ProcessedCount | Should -Be 1
            $result.SuccessCount | Should -Be 1
        }

        It "Should handle multiple pending mailboxes" {
            $mockBacklog = @{
                version = "1.0"
                metadata = @{ lastUpdated = "2026-06-29T10:00:00Z"; totalEntries = 2; pendingEntries = 2 }
                entries = @(
                    @{
                        id = "smbx_111111"
                        samAccountName = "smbx_111111"
                        aclGroup = "smbx_acl_111111"
                        adminGroup = "ZO-Mail-Admins"
                        mailboxName = "Group 1"
                        primarySmtpAddress = "group1@ethz.ch"
                        status = "MAILBOX_CREATED_AWAITING_PERMISSIONS"
                        createdAt = "2026-06-29T10:00:00Z"
                        lastAttemptAt = $null
                        retryCount = 0
                        maxRetries = 5
                        completedAt = $null
                        errors = @()
                        notes = ""
                    },
                    @{
                        id = "smbx_222222"
                        samAccountName = "smbx_222222"
                        aclGroup = "smbx_acl_222222"
                        adminGroup = "ZO-Mail-Admins"
                        mailboxName = "Group 2"
                        primarySmtpAddress = "group2@ethz.ch"
                        status = "MAILBOX_CREATED_AWAITING_PERMISSIONS"
                        createdAt = "2026-06-29T09:00:00Z"
                        lastAttemptAt = $null
                        retryCount = 0
                        maxRetries = 5
                        completedAt = $null
                        errors = @()
                        notes = ""
                    }
                )
            }

            Mock Get-Content { return ($mockBacklog | ConvertTo-Json -Depth 10) }
            Mock Test-Path { return $true }
            Mock Add-MailboxPermission { }
            Mock Add-RecipientPermission { }
            Mock Get-PSSession { return $null }
            Mock Connect-ExchangeOnline { }
            Mock Get-ADUser { }
            Mock Set-ADUser { }
            Mock Set-Content { }
            Mock Export-Csv { }

            $result = Invoke-MailboxPermissionQueue -BacklogPath "C:\test\backlog.json"

            $result.ProcessedCount | Should -Be 2
            $result.SuccessCount | Should -Be 2
        }
    }

    Context "Mailbox not found (sync lag)" {
        It "Should retry when mailbox not found" {
            $mockBacklog = @{
                version = "1.0"
                metadata = @{ lastUpdated = "2026-06-29T10:00:00Z"; totalEntries = 1; pendingEntries = 1 }
                entries = @(
                    @{
                        id = "smbx_123456"
                        samAccountName = "smbx_123456"
                        aclGroup = "smbx_acl_123456"
                        adminGroup = "ZO-Mail-Admins"
                        mailboxName = "Sales Team"
                        primarySmtpAddress = "sales@ethz.ch"
                        status = "MAILBOX_CREATED_AWAITING_PERMISSIONS"
                        createdAt = "2026-06-29T10:00:00Z"
                        lastAttemptAt = $null
                        retryCount = 0
                        maxRetries = 5
                        completedAt = $null
                        errors = @()
                        notes = ""
                    }
                )
            }

            Mock Get-Content { return ($mockBacklog | ConvertTo-Json -Depth 10) }
            Mock Test-Path { return $true }
            Mock Add-MailboxPermission { throw [System.Exception]"object must exist before it can be modified" }
            Mock Get-PSSession { return $null }
            Mock Connect-ExchangeOnline { }
            Mock Get-ADUser { }
            Mock Set-Content { }
            Mock Export-Csv { }

            $result = Invoke-MailboxPermissionQueue -BacklogPath "C:\test\backlog.json"

            $result.RetryingCount | Should -Be 1
            $result.SuccessCount | Should -Be 0
        }

        It "Should fail after max retries exceeded" {
            $mockBacklog = @{
                version = "1.0"
                metadata = @{ lastUpdated = "2026-06-29T10:00:00Z"; totalEntries = 1; pendingEntries = 1 }
                entries = @(
                    @{
                        id = "smbx_123456"
                        samAccountName = "smbx_123456"
                        aclGroup = "smbx_acl_123456"
                        adminGroup = "ZO-Mail-Admins"
                        mailboxName = "Sales Team"
                        primarySmtpAddress = "sales@ethz.ch"
                        status = "MAILBOX_CREATED_AWAITING_PERMISSIONS"
                        createdAt = "2026-06-29T10:00:00Z"
                        lastAttemptAt = "2026-06-29T10:45:00Z"
                        retryCount = 5
                        maxRetries = 5
                        completedAt = $null
                        errors = @(@{ timestamp = "2026-06-29T10:45:00Z"; errorCode = "MailboxNotFound"; errorMessage = "Not found" })
                        notes = ""
                    }
                )
            }

            Mock Get-Content { return ($mockBacklog | ConvertTo-Json -Depth 10) }
            Mock Test-Path { return $true }
            Mock Get-ADUser { }
            Mock Set-Content { }
            Mock Export-Csv { }

            $result = Invoke-MailboxPermissionQueue -BacklogPath "C:\test\backlog.json"

            $result.FailedCount | Should -Be 1
        }
    }

    Context "Permission assignment" {
        It "Should assign FullAccess + SendAs to ACL group" {
            Mock Get-Content {
                return @{
                    version = "1.0"
                    metadata = @{ lastUpdated = "2026-06-29T10:00:00Z" }
                    entries = @(@{ id = "smbx_123"; aclGroup = "smbx_acl_123"; adminGroup = "Admins"; mailboxName = "Test"; status = "MAILBOX_CREATED_AWAITING_PERMISSIONS"; retryCount = 0; errors = @() })
                } | ConvertTo-Json -Depth 10
            }
            Mock Test-Path { return $true }
            Mock Add-MailboxPermission { }
            Mock Add-RecipientPermission { }
            Mock Get-PSSession { return [PSCustomObject]@{ PSPath = "MockSession" } }
            Mock Get-ADUser { }
            Mock Set-ADUser { }
            Mock Set-Content { }
            Mock Export-Csv { }

            Invoke-MailboxPermissionQueue -BacklogPath "C:\test\backlog.json"

            Assert-MockCalled Add-MailboxPermission -Times 2
            Assert-MockCalled Add-RecipientPermission -Times 1
        }

        It "Should assign FullAccess only to Admin group" {
            Mock Get-Content {
                return @{
                    version = "1.0"
                    metadata = @{ lastUpdated = "2026-06-29T10:00:00Z" }
                    entries = @(@{ id = "smbx_123"; aclGroup = "smbx_acl_123"; adminGroup = "Admins"; mailboxName = "Test"; status = "MAILBOX_CREATED_AWAITING_PERMISSIONS"; retryCount = 0; errors = @() })
                } | ConvertTo-Json -Depth 10
            }
            Mock Test-Path { return $true }
            Mock Add-MailboxPermission { }
            Mock Add-RecipientPermission { }
            Mock Get-PSSession { return [PSCustomObject]@{ PSPath = "MockSession" } }
            Mock Get-ADUser { }
            Mock Set-ADUser { }
            Mock Set-Content { }
            Mock Export-Csv { }

            Invoke-MailboxPermissionQueue -BacklogPath "C:\test\backlog.json"

            Assert-MockCalled Add-MailboxPermission -Times 2
        }
    }

    Context "Backlog file handling" {
        It "Should handle missing backlog file" {
            Mock Test-Path { return $false }

            $result = Invoke-MailboxPermissionQueue -BacklogPath "C:\nonexistent\backlog.json"

            $result.ProcessedCount | Should -Be 0
            $result.Summary | Should -Match "No backlog"
        }

        It "Should handle backlog with no pending entries" {
            $mockBacklog = @{
                version = "1.0"
                metadata = @{ lastUpdated = "2026-06-29T10:00:00Z" }
                entries = @(@{ id = "smbx_123"; status = "PERMISSIONS_SET"; completedAt = "2026-06-29T11:00:00Z" })
            }

            Mock Get-Content { return ($mockBacklog | ConvertTo-Json -Depth 10) }
            Mock Test-Path { return $true }
            Mock Set-Content { }
            Mock Export-Csv { }

            $result = Invoke-MailboxPermissionQueue -BacklogPath "C:\test\backlog.json"

            $result.ProcessedCount | Should -Be 0
            $result.Summary | Should -Match "No pending"
        }
    }

    Context "Cleanup of old entries" {
        It "Should remove entries older than cleanup threshold" {
            $mockBacklog = @{
                version = "1.0"
                metadata = @{ lastUpdated = "2026-06-29T10:00:00Z" }
                entries = @(
                    @{ id = "smbx_old"; status = "PERMISSIONS_SET"; completedAt = "2026-05-01T10:00:00Z" },
                    @{ id = "smbx_new"; status = "PERMISSIONS_SET"; completedAt = "2026-06-29T10:00:00Z" }
                )
            }

            Mock Get-Content { return ($mockBacklog | ConvertTo-Json -Depth 10) }
            Mock Test-Path { return $true }
            Mock Set-Content { }
            Mock Export-Csv { }

            Invoke-MailboxPermissionQueue -BacklogPath "C:\test\backlog.json" -CleanupDaysOld 30

            Assert-MockCalled Set-Content -Times 1
        }
    }

    Context "CSV export" {
        It "Should export CSV alongside JSON" {
            $mockBacklog = @{
                version = "1.0"
                metadata = @{ lastUpdated = "2026-06-29T10:00:00Z" }
                entries = @(@{ id = "smbx_123"; samAccountName = "smbx_123"; aclGroup = "smbx_acl_123"; adminGroup = "Admins"; mailboxName = "Test"; primarySmtpAddress = "test@ethz.ch"; status = "PERMISSIONS_SET"; createdAt = "2026-06-29T10:00:00Z"; completedAt = "2026-06-29T11:00:00Z"; retryCount = 0; errors = @(); notes = "" })
            }

            Mock Get-Content { return ($mockBacklog | ConvertTo-Json -Depth 10) }
            Mock Test-Path { return $true }
            Mock Set-Content { }
            Mock Export-Csv { }

            Invoke-MailboxPermissionQueue -BacklogPath "C:\test\backlog.json"

            Assert-MockCalled Export-Csv -Times 1
        }
    }

    Context "Return object" {
        It "Should return summary statistics" {
            $mockBacklog = @{
                version = "1.0"
                metadata = @{ lastUpdated = "2026-06-29T10:00:00Z" }
                entries = @()
            }

            Mock Get-Content { return ($mockBacklog | ConvertTo-Json -Depth 10) }
            Mock Test-Path { return $true }

            $result = Invoke-MailboxPermissionQueue -BacklogPath "C:\test\backlog.json"

            $result | Should -HaveProperty "ProcessedCount"
            $result | Should -HaveProperty "SuccessCount"
            $result | Should -HaveProperty "FailedCount"
            $result | Should -HaveProperty "RetryingCount"
            $result | Should -HaveProperty "Summary"
        }
    }
}
