<#
.SYNOPSIS
Unit tests for New-SharedMailboxRemote function
#>

# Import function
$projectRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$functionPath = Join-Path $projectRoot "functions" "Public" "New-SharedMailboxRemote.ps1"
. $functionPath

Describe "NewSharedMailboxRemote" {

    Context "Successful mailbox creation" {
        It "Should create remote mailbox successfully" {
            Mock Get-ADUser {
                return [PSCustomObject]@{
                    sAMAccountName = "smbx_123456"
                    UserPrincipalName = "smbx_123456@ethz.ch"
                    userAccountControl = 514
                }
            }

            Mock _GetExchangePSSession {
                return [PSCustomObject]@{ PSPath = "MockSession" }
            }

            Mock Invoke-Command {
                return [PSCustomObject]@{
                    Identity = "CN=smbx_123456,OU=Mailboxes,DC=ethz,DC=ch"
                }
            }

            Mock -CommandName _AddToMailboxProvisioningBacklog { }

            $result = New-SharedMailboxRemote -SamAccountName "smbx_123456" `
                -DisplayName "Sales Team" `
                -PrimarySmtpAddress "sales@ethz.ch" `
                -RemoteRoutingAddress "sales@ethz.mail.onmicrosoft.com" `
                -ACLGroupName "smbx_acl_123456"

            $result | Should -Not -BeNullOrEmpty
            $result.Status | Should -Be "MAILBOX_CREATED_AWAITING_PERMISSIONS"
            $result.DisplayName | Should -Be "Sales Team"
        }

        It "Should add entry to provisioning backlog" {
            Mock Get-ADUser {
                return [PSCustomObject]@{
                    sAMAccountName = "smbx_123456"
                    UserPrincipalName = "smbx_123456@ethz.ch"
                    userAccountControl = 514
                }
            }

            Mock _GetExchangePSSession {
                return [PSCustomObject]@{ PSPath = "MockSession" }
            }

            Mock Invoke-Command {
                return [PSCustomObject]@{ Identity = "CN=smbx_123456,OU=Mailboxes,DC=ethz,DC=ch" }
            }

            Mock -CommandName _AddToMailboxProvisioningBacklog { }

            New-SharedMailboxRemote -SamAccountName "smbx_123456" `
                -DisplayName "Sales Team" `
                -PrimarySmtpAddress "sales@ethz.ch" `
                -RemoteRoutingAddress "sales@ethz.mail.onmicrosoft.com" `
                -ACLGroupName "smbx_acl_123456"

            Assert-MockCalled _AddToMailboxProvisioningBacklog -Times 1
        }
    }

    Context "Return object structure" {
        It "Should return object with all required properties" {
            Mock Get-ADUser {
                return [PSCustomObject]@{
                    sAMAccountName = "smbx_123456"
                    UserPrincipalName = "smbx_123456@ethz.ch"
                    userAccountControl = 514
                }
            }

            Mock _GetExchangePSSession {
                return [PSCustomObject]@{ PSPath = "MockSession" }
            }

            Mock Invoke-Command {
                return [PSCustomObject]@{ Identity = "CN=smbx_123456,OU=Mailboxes,DC=ethz,DC=ch" }
            }

            Mock -CommandName _AddToMailboxProvisioningBacklog { }

            $result = New-SharedMailboxRemote -SamAccountName "smbx_123456" `
                -DisplayName "Sales Team" `
                -PrimarySmtpAddress "sales@ethz.ch" `
                -RemoteRoutingAddress "sales@ethz.mail.onmicrosoft.com" `
                -ACLGroupName "smbx_acl_123456"

            $result | Should -HaveProperty "SamAccountName"
            $result | Should -HaveProperty "DisplayName"
            $result | Should -HaveProperty "PrimarySmtpAddress"
            $result | Should -HaveProperty "RemoteRoutingAddress"
            $result | Should -HaveProperty "ACLGroupName"
            $result | Should -HaveProperty "Status"
            $result | Should -HaveProperty "CreatedAt"
            $result | Should -HaveProperty "Identity"
        }
    }

    Context "AD user validation" {
        It "Should fail if user account not found" {
            Mock Get-ADUser {
                return $null
            }

            Mock _GetExchangePSSession {
                return [PSCustomObject]@{ PSPath = "MockSession" }
            }

            $result = New-SharedMailboxRemote -SamAccountName "nonexistent" `
                -DisplayName "Test" `
                -PrimarySmtpAddress "test@ethz.ch" `
                -RemoteRoutingAddress "test@ethz.mail.onmicrosoft.com" `
                -ACLGroupName "smbx_acl_test"

            $result | Should -BeNullOrEmpty
        }

        It "Should warn if user account is enabled" {
            Mock Get-ADUser {
                return [PSCustomObject]@{
                    sAMAccountName = "smbx_123456"
                    UserPrincipalName = "smbx_123456@ethz.ch"
                    userAccountControl = 512
                }
            }

            Mock _GetExchangePSSession {
                return [PSCustomObject]@{ PSPath = "MockSession" }
            }

            Mock Invoke-Command {
                return [PSCustomObject]@{ Identity = "CN=smbx_123456,OU=Mailboxes,DC=ethz,DC=ch" }
            }

            Mock -CommandName _AddToMailboxProvisioningBacklog { }

            $result = New-SharedMailboxRemote -SamAccountName "smbx_123456" `
                -DisplayName "Enabled User" `
                -PrimarySmtpAddress "test@ethz.ch" `
                -RemoteRoutingAddress "test@ethz.mail.onmicrosoft.com" `
                -ACLGroupName "smbx_acl_123456" `
                -WarningAction SilentlyContinue

            $result | Should -Not -BeNullOrEmpty
        }
    }

    Context "PSSession handling" {
        It "Should call _GetExchangePSSession" {
            Mock Get-ADUser {
                return [PSCustomObject]@{
                    sAMAccountName = "smbx_123456"
                    UserPrincipalName = "smbx_123456@ethz.ch"
                    userAccountControl = 514
                }
            }

            Mock _GetExchangePSSession {
                return [PSCustomObject]@{ PSPath = "MockSession" }
            }

            Mock Invoke-Command {
                return [PSCustomObject]@{ Identity = "CN=smbx_123456,OU=Mailboxes,DC=ethz,DC=ch" }
            }

            Mock -CommandName _AddToMailboxProvisioningBacklog { }

            New-SharedMailboxRemote -SamAccountName "smbx_123456" `
                -DisplayName "Test" `
                -PrimarySmtpAddress "test@ethz.ch" `
                -RemoteRoutingAddress "test@ethz.mail.onmicrosoft.com" `
                -ACLGroupName "smbx_acl_123456"

            Assert-MockCalled _GetExchangePSSession -Times 1
        }

        It "Should fail if PSSession cannot be established" {
            Mock Get-ADUser {
                return [PSCustomObject]@{
                    sAMAccountName = "smbx_123456"
                    UserPrincipalName = "smbx_123456@ethz.ch"
                    userAccountControl = 514
                }
            }

            Mock _GetExchangePSSession {
                return $null
            }

            $result = New-SharedMailboxRemote -SamAccountName "smbx_123456" `
                -DisplayName "Test" `
                -PrimarySmtpAddress "test@ethz.ch" `
                -RemoteRoutingAddress "test@ethz.mail.onmicrosoft.com" `
                -ACLGroupName "smbx_acl_123456"

            $result | Should -BeNullOrEmpty
        }
    }

    Context "Parameters" {
        It "Should accept optional AdminGroupName" {
            Mock Get-ADUser {
                return [PSCustomObject]@{
                    sAMAccountName = "smbx_123456"
                    UserPrincipalName = "smbx_123456@ethz.ch"
                    userAccountControl = 514
                }
            }

            Mock _GetExchangePSSession {
                return [PSCustomObject]@{ PSPath = "MockSession" }
            }

            Mock Invoke-Command {
                return [PSCustomObject]@{ Identity = "CN=smbx_123456,OU=Mailboxes,DC=ethz,DC=ch" }
            }

            Mock -CommandName _AddToMailboxProvisioningBacklog { }

            $result = New-SharedMailboxRemote -SamAccountName "smbx_123456" `
                -DisplayName "Test" `
                -PrimarySmtpAddress "test@ethz.ch" `
                -RemoteRoutingAddress "test@ethz.mail.onmicrosoft.com" `
                -ACLGroupName "smbx_acl_123456" `
                -AdminGroupName "ZO-Mail-Admins"

            $result.AdminGroupName | Should -Be "ZO-Mail-Admins"
        }

        It "Should use default BacklogPath when not specified" {
            Mock Get-ADUser {
                return [PSCustomObject]@{
                    sAMAccountName = "smbx_123456"
                    UserPrincipalName = "smbx_123456@ethz.ch"
                    userAccountControl = 514
                }
            }

            Mock _GetExchangePSSession {
                return [PSCustomObject]@{ PSPath = "MockSession" }
            }

            Mock Invoke-Command {
                return [PSCustomObject]@{ Identity = "CN=smbx_123456,OU=Mailboxes,DC=ethz,DC=ch" }
            }

            Mock -CommandName _AddToMailboxProvisioningBacklog { }

            $result = New-SharedMailboxRemote -SamAccountName "smbx_123456" `
                -DisplayName "Test" `
                -PrimarySmtpAddress "test@ethz.ch" `
                -RemoteRoutingAddress "test@ethz.mail.onmicrosoft.com" `
                -ACLGroupName "smbx_acl_123456"

            $result | Should -Not -BeNullOrEmpty
        }
    }

    Context "Error handling" {
        It "Should handle Invoke-Command failure" {
            Mock Get-ADUser {
                return [PSCustomObject]@{
                    sAMAccountName = "smbx_123456"
                    UserPrincipalName = "smbx_123456@ethz.ch"
                    userAccountControl = 514
                }
            }

            Mock _GetExchangePSSession {
                return [PSCustomObject]@{ PSPath = "MockSession" }
            }

            Mock Invoke-Command {
                throw [System.Exception]"Mailbox creation failed"
            }

            $result = New-SharedMailboxRemote -SamAccountName "smbx_123456" `
                -DisplayName "Test" `
                -PrimarySmtpAddress "test@ethz.ch" `
                -RemoteRoutingAddress "test@ethz.mail.onmicrosoft.com" `
                -ACLGroupName "smbx_acl_123456"

            $result | Should -BeNullOrEmpty
        }

        It "Should handle empty mailbox creation result" {
            Mock Get-ADUser {
                return [PSCustomObject]@{
                    sAMAccountName = "smbx_123456"
                    UserPrincipalName = "smbx_123456@ethz.ch"
                    userAccountControl = 514
                }
            }

            Mock _GetExchangePSSession {
                return [PSCustomObject]@{ PSPath = "MockSession" }
            }

            Mock Invoke-Command {
                return $null
            }

            $result = New-SharedMailboxRemote -SamAccountName "smbx_123456" `
                -DisplayName "Test" `
                -PrimarySmtpAddress "test@ethz.ch" `
                -RemoteRoutingAddress "test@ethz.mail.onmicrosoft.com" `
                -ACLGroupName "smbx_acl_123456"

            $result | Should -BeNullOrEmpty
        }
    }
}
