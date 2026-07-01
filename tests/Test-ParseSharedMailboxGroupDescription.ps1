<#
.SYNOPSIS
Unit tests for _ParseSharedMailboxGroupDescription function
#>

# Import function
$projectRoot = Split-Path -Parent $PSScriptRoot
$functionPath = Join-Path (Join-Path $projectRoot "functions") "Private\_ParseSharedMailboxGroupDescription.ps1"
. $functionPath

Describe "ParseSharedMailboxGroupDescription" {

    Context "Valid descriptions" {
        It "Should parse standard description format" {
            $desc = "Permission group for shared mailbox user@ethz.ch; Owner; AdminGroup"
            $result = _ParseSharedMailboxGroupDescription $desc

            $result | Should -Not -BeNullOrEmpty
            $result.Email | Should -Be "user@ethz.ch"
            $result.Role | Should -Be "Owner"
            $result.AdminGroup | Should -Be "AdminGroup"
            $result.IsValid | Should -Be $true
        }

        It "Should handle email with subdomain" {
            $desc = "Permission group for shared mailbox mail.user@ethz.ch; Owner; AdminGrp"
            $result = _ParseSharedMailboxGroupDescription $desc

            $result | Should -Not -BeNullOrEmpty
            $result.Email | Should -Be "mail.user@ethz.ch"
            $result.IsValid | Should -Be $true
        }

        It "Should handle M365 domain email" {
            $desc = "Permission group for shared mailbox smbx@ethz.onmicrosoft.com; Member; AdminGroup123"
            $result = _ParseSharedMailboxGroupDescription $desc

            $result | Should -Not -BeNullOrEmpty
            $result.Email | Should -Be "smbx@ethz.onmicrosoft.com"
            $result.Role | Should -Be "Member"
            $result.IsValid | Should -Be $true
        }

        It "Should handle role with spaces trimmed" {
            $desc = "Permission group for shared mailbox user@ethz.ch;  Owner  ; AdminGroup"
            $result = _ParseSharedMailboxGroupDescription $desc

            $result | Should -Not -BeNullOrEmpty
            $result.Role | Should -Be "Owner"
        }

        It "Should handle admin group with spaces trimmed" {
            $desc = "Permission group for shared mailbox user@ethz.ch; Owner;  AdminGroup123  "
            $result = _ParseSharedMailboxGroupDescription $desc

            $result | Should -Not -BeNullOrEmpty
            $result.AdminGroup | Should -Be "AdminGroup123"
        }

        It "Should handle different roles" {
            $roles = @("Owner", "Member", "Contributor", "Reader")
            foreach ($role in $roles) {
                $desc = "Permission group for shared mailbox user@ethz.ch; $role; AdminGroup"
                $result = _ParseSharedMailboxGroupDescription $desc
                $result.Role | Should -Be $role
            }
        }

        It "Should handle numeric admin group names" {
            $desc = "Permission group for shared mailbox user@ethz.ch; Owner; 12345"
            $result = _ParseSharedMailboxGroupDescription $desc

            $result | Should -Not -BeNullOrEmpty
            $result.AdminGroup | Should -Be "12345"
            $result.IsValid | Should -Be $true
        }
    }

    Context "Invalid descriptions - Format" {
        It "Should reject empty description" {
            $result = _ParseSharedMailboxGroupDescription ""
            $result | Should -BeNullOrEmpty
        }

        It "Should reject whitespace-only description" {
            $result = _ParseSharedMailboxGroupDescription "   "
            $result | Should -BeNullOrEmpty
        }

        It "Should reject description without email" {
            $desc = "Permission group; Owner; AdminGroup"
            $result = _ParseSharedMailboxGroupDescription $desc
            $result | Should -BeNullOrEmpty
        }

        It "Should reject description with missing role" {
            $desc = "Permission group for shared mailbox user@ethz.ch; AdminGroup"
            $result = _ParseSharedMailboxGroupDescription $desc
            $result | Should -BeNullOrEmpty
        }

        It "Should reject description with missing admin group" {
            $desc = "Permission group for shared mailbox user@ethz.ch; Owner"
            $result = _ParseSharedMailboxGroupDescription $desc
            $result | Should -BeNullOrEmpty
        }

        It "Should reject description with wrong prefix" {
            $desc = "Shared mailbox group for user@ethz.ch; Owner; AdminGroup"
            $result = _ParseSharedMailboxGroupDescription $desc
            $result | Should -BeNullOrEmpty
        }

        It "Should reject description with empty email" {
            $desc = "Permission group for shared mailbox ; Owner; AdminGroup"
            $result = _ParseSharedMailboxGroupDescription $desc
            $result | Should -BeNullOrEmpty
        }

        It "Should reject description with empty role" {
            $desc = "Permission group for shared mailbox user@ethz.ch; ; AdminGroup"
            $result = _ParseSharedMailboxGroupDescription $desc
            $result | Should -BeNullOrEmpty
        }

        It "Should reject description with empty admin group" {
            $desc = "Permission group for shared mailbox user@ethz.ch; Owner; "
            $result = _ParseSharedMailboxGroupDescription $desc
            $result | Should -BeNullOrEmpty
        }
    }

    Context "Edge cases" {
        It "Should handle description with extra semicolons" {
            $desc = "Permission group for shared mailbox user@ethz.ch; Owner; AdminGroup; Extra"
            $result = _ParseSharedMailboxGroupDescription $desc

            $result | Should -Not -BeNullOrEmpty
            $result.Email | Should -Be "user@ethz.ch"
            # Takes only first 3 parts
        }

        It "Should handle email with plus addressing" {
            $desc = "Permission group for shared mailbox user+tag@ethz.ch; Owner; AdminGroup"
            $result = _ParseSharedMailboxGroupDescription $desc

            $result | Should -Not -BeNullOrEmpty
            $result.Email | Should -Be "user+tag@ethz.ch"
        }

        It "Should handle very long admin group name" {
            $longAdmin = "A" * 100
            $desc = "Permission group for shared mailbox user@ethz.ch; Owner; $longAdmin"
            $result = _ParseSharedMailboxGroupDescription $desc

            $result | Should -Not -BeNullOrEmpty
            $result.AdminGroup | Should -Be $longAdmin
        }

        It "Should handle role with special characters" {
            $desc = "Permission group for shared mailbox user@ethz.ch; Owner-Admin; AdminGroup"
            $result = _ParseSharedMailboxGroupDescription $desc

            $result | Should -Not -BeNullOrEmpty
            $result.Role | Should -Be "Owner-Admin"
        }
    }
}
