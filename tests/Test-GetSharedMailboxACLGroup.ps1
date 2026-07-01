<#
.SYNOPSIS
Unit tests for Get-SharedMailboxACLGroup function
#>

# Import functions
$projectRoot = Split-Path -Parent $PSScriptRoot
$functionPath3 = Join-Path (Join-Path $projectRoot "functions") "Public\Get-SharedMailboxACLGroup.ps1"

. $functionPath3

Describe "GetSharedMailboxACLGroup" {

    Context "Successful group retrieval" {
        It "Should find and return valid group for smbx user" {
            Mock Get-ADObject {
                return [PSCustomObject]@{
                    Name = "smbx_acl_12345678"
                    SamAccountName = "smbx_acl_12345678"
                    mail = "group@ethz.ch"
                    GroupScope = "Universal"
                    Description = "Permission group for shared mailbox smbx@ethz.ch; Owner; AdminGroup"
                }
            }

            $result = Get-SharedMailboxACLGroup -SamAccountName "smbx_12345678"

            $result | Should -Not -BeNullOrEmpty
            $result.Name | Should -Be "smbx_acl_12345678"
            $result.IsValid | Should -Be $true

            Assert-MockCalled Get-ADObject -Times 1
        }

        It "Should construct correct group name from smbx user" {
            Mock Get-ADObject {
                return [PSCustomObject]@{
                    Name = "smbx_acl_test99"
                    SamAccountName = "smbx_acl_test99"
                    mail = "group@ethz.ch"
                    GroupScope = "Universal"
                    Description = "Permission group for shared mailbox smbx@ethz.ch; Owner; AdminGroup"
                }
            }

            $result = Get-SharedMailboxACLGroup -SamAccountName "smbx_test99"
            $result.Name | Should -Be "smbx_acl_test99"
            $result.IsValid | Should -Be $true
        }

        It "Should handle different suffix formats" {
            Mock Get-ADObject {
                return [PSCustomObject]@{
                    Name = "smbx_acl_user_2024_001"
                    SamAccountName = "smbx_acl_user_2024_001"
                    mail = "group@ethz.ch"
                    GroupScope = "Universal"
                    Description = "Permission group for shared mailbox smbx@ethz.ch; Owner; AdminGroup"
                }
            }

            $result = Get-SharedMailboxACLGroup -SamAccountName "smbx_user_2024_001"
            $result | Should -Not -BeNullOrEmpty
            $result.IsValid | Should -Be $true
        }
    }

    Context "Group not found" {
        It "Should return null when group doesn't exist" {
            Mock Get-ADObject {
                return $null
            }

            $result = Get-SharedMailboxACLGroup -SamAccountName "smbx_nonexistent"
            $result | Should -BeNullOrEmpty
        }

        It "Should handle empty AD search results" {
            Mock Get-ADObject {
                return @()
            }

            $result = Get-SharedMailboxACLGroup -SamAccountName "smbx_empty"
            $result | Should -BeNullOrEmpty
        }
    }

    Context "Group validation failures - GroupScope" {
        It "Should reject group if not Universal scope" {
            Mock Get-ADObject {
                return [PSCustomObject]@{
                    Name = "smbx_acl_12345678"
                    SamAccountName = "smbx_acl_12345678"
                    mail = "group@ethz.ch"
                    GroupScope = "Global"
                    Description = "Permission group for shared mailbox smbx@ethz.ch; Owner; AdminGroup"
                }
            }

            $result = Get-SharedMailboxACLGroup -SamAccountName "smbx_12345678"
            $result | Should -BeNullOrEmpty
        }

        It "Should reject group if DomainLocal scope" {
            Mock Get-ADObject {
                return [PSCustomObject]@{
                    Name = "smbx_acl_12345678"
                    SamAccountName = "smbx_acl_12345678"
                    mail = "group@ethz.ch"
                    GroupScope = "DomainLocal"
                    Description = "Permission group for shared mailbox smbx@ethz.ch; Owner; AdminGroup"
                }
            }

            $result = Get-SharedMailboxACLGroup -SamAccountName "smbx_12345678"
            $result | Should -BeNullOrEmpty
        }
    }

    Context "Group validation failures - Mail attribute" {
        It "Should reject group without mail attribute" {
            Mock Get-ADObject {
                return [PSCustomObject]@{
                    Name = "smbx_acl_12345678"
                    SamAccountName = "smbx_acl_12345678"
                    mail = ""
                    GroupScope = "Universal"
                    Description = "Permission group for shared mailbox smbx@ethz.ch; Owner; AdminGroup"
                }
            }

            $result = Get-SharedMailboxACLGroup -SamAccountName "smbx_12345678"
            $result | Should -BeNullOrEmpty
        }

        It "Should reject group with null mail" {
            Mock Get-ADObject {
                return [PSCustomObject]@{
                    Name = "smbx_acl_12345678"
                    SamAccountName = "smbx_acl_12345678"
                    mail = $null
                    GroupScope = "Universal"
                    Description = "Permission group for shared mailbox smbx@ethz.ch; Owner; AdminGroup"
                }
            }

            $result = Get-SharedMailboxACLGroup -SamAccountName "smbx_12345678"
            $result | Should -BeNullOrEmpty
        }
    }

    Context "Group validation failures - Description" {
        It "Should reject group without description" {
            Mock Get-ADObject {
                return [PSCustomObject]@{
                    Name = "smbx_acl_12345678"
                    SamAccountName = "smbx_acl_12345678"
                    mail = "group@ethz.ch"
                    GroupScope = "Universal"
                    Description = ""
                }
            }

            $result = Get-SharedMailboxACLGroup -SamAccountName "smbx_12345678"
            $result | Should -BeNullOrEmpty
        }

        It "Should reject group with wrong description prefix" {
            Mock Get-ADObject {
                return [PSCustomObject]@{
                    Name = "smbx_acl_12345678"
                    SamAccountName = "smbx_acl_12345678"
                    mail = "group@ethz.ch"
                    GroupScope = "Universal"
                    Description = "This is some other group description"
                }
            }

            $result = Get-SharedMailboxACLGroup -SamAccountName "smbx_12345678"
            $result | Should -BeNullOrEmpty
        }

        It "Should accept description starting with 'Permission group for shared mailbox'" {
            Mock Get-ADObject {
                return [PSCustomObject]@{
                    Name = "smbx_acl_12345678"
                    SamAccountName = "smbx_acl_12345678"
                    mail = "group@ethz.ch"
                    GroupScope = "Universal"
                    Description = "Permission group for shared mailbox anything after this"
                }
            }

            $result = Get-SharedMailboxACLGroup -SamAccountName "smbx_12345678"
            $result | Should -Not -BeNullOrEmpty
            $result.IsValid | Should -Be $true
        }
    }

    Context "Invalid input format" {
        It "Should reject SamAccountName not starting with smbx_" {
            $result = Get-SharedMailboxACLGroup -SamAccountName "user_12345678"
            $result | Should -BeNullOrEmpty
        }

        It "Should reject SamAccountName without prefix" {
            $result = Get-SharedMailboxACLGroup -SamAccountName "12345678"
            $result | Should -BeNullOrEmpty
        }

        It "Should reject completely wrong format" {
            $result = Get-SharedMailboxACLGroup -SamAccountName "testuser"
            $result | Should -BeNullOrEmpty
        }
    }

    Context "AD search parameters" {
        It "Should pass SearchBase parameter when provided" {
            Mock Get-ADObject {
                return [PSCustomObject]@{
                    Name = "smbx_acl_12345678"
                    SamAccountName = "smbx_acl_12345678"
                    mail = "group@ethz.ch"
                    GroupScope = "Universal"
                    Description = "Permission group for shared mailbox smbx@ethz.ch; Owner; AdminGroup"
                }
            }

            $searchBase = "OU=Groups,DC=ethz,DC=ch"
            $null = Get-SharedMailboxACLGroup -SamAccountName "smbx_12345678" -SearchBase $searchBase

            Assert-MockCalled Get-ADObject -Times 1 -ParameterFilter {
                $SearchBase -eq "OU=Groups,DC=ethz,DC=ch"
            }
        }

        It "Should work without SearchBase parameter" {
            Mock Get-ADObject {
                return [PSCustomObject]@{
                    Name = "smbx_acl_12345678"
                    SamAccountName = "smbx_acl_12345678"
                    mail = "group@ethz.ch"
                    GroupScope = "Universal"
                    Description = "Permission group for shared mailbox smbx@ethz.ch; Owner; AdminGroup"
                }
            }

            $result = Get-SharedMailboxACLGroup -SamAccountName "smbx_12345678"
            $result | Should -Not -BeNullOrEmpty
        }
    }

    Context "Error handling" {
        It "Should handle AD connection failures" {
            Mock Get-ADObject {
                throw [System.Exception]"AD connection failed"
            }

            $result = Get-SharedMailboxACLGroup -SamAccountName "smbx_error"
            $result | Should -BeNullOrEmpty
        }

        It "Should handle permission denied errors" {
            Mock Get-ADObject {
                throw [System.UnauthorizedAccessException]"Access denied"
            }

            $result = Get-SharedMailboxACLGroup -SamAccountName "smbx_noaccess"
            $result | Should -BeNullOrEmpty
        }
    }

    Context "Return object structure" {
        It "Should return object with all expected properties" {
            Mock Get-ADObject {
                return [PSCustomObject]@{
                    Name = "smbx_acl_12345678"
                    SamAccountName = "smbx_acl_12345678"
                    mail = "group@ethz.ch"
                    GroupScope = "Universal"
                    Description = "Permission group for shared mailbox smbx@ethz.ch; Owner; AdminGroup"
                }
            }

            $result = Get-SharedMailboxACLGroup -SamAccountName "smbx_12345678"

            $result | Should -HaveProperty "ADGroup"
            $result | Should -HaveProperty "Name"
            $result | Should -HaveProperty "SamAccountName"
            $result | Should -HaveProperty "Mail"
            $result | Should -HaveProperty "GroupScope"
            $result | Should -HaveProperty "Description"
            $result | Should -HaveProperty "IsValid"
        }

        It "Should include AD group object in result" {
            Mock Get-ADObject {
                return [PSCustomObject]@{
                    Name = "smbx_acl_12345678"
                    SamAccountName = "smbx_acl_12345678"
                    mail = "group@ethz.ch"
                    GroupScope = "Universal"
                    Description = "Permission group for shared mailbox smbx@ethz.ch; Owner; AdminGroup"
                }
            }

            $result = Get-SharedMailboxACLGroup -SamAccountName "smbx_12345678"
            $result.ADGroup | Should -Not -BeNullOrEmpty
            $result.ADGroup.SamAccountName | Should -Be "smbx_acl_12345678"
            $result.IsValid | Should -Be $true
        }

        It "Should include all group properties in result" {
            Mock Get-ADObject {
                return [PSCustomObject]@{
                    Name = "smbx_acl_12345678"
                    SamAccountName = "smbx_acl_12345678"
                    mail = "group@ethz.ch"
                    GroupScope = "Universal"
                    Description = "Permission group for shared mailbox smbx@ethz.ch; Owner; AdminGroup"
                }
            }

            $result = Get-SharedMailboxACLGroup -SamAccountName "smbx_12345678"
            $result.Mail | Should -Be "group@ethz.ch"
            $result.GroupScope | Should -Be "Universal"
            $result.Description | Should -Match "Permission group for shared mailbox"
        }
    }

    Context "Suffix extraction" {
        It "Should correctly extract suffix from smbx_ prefix" {
            Mock Get-ADObject {
                return [PSCustomObject]@{
                    Name = "smbx_acl_abc123"
                    SamAccountName = "smbx_acl_abc123"
                    mail = "group@ethz.ch"
                    GroupScope = "Universal"
                    Description = "Permission group for shared mailbox smbx@ethz.ch; Owner; AdminGroup"
                }
            }

            $result = Get-SharedMailboxACLGroup -SamAccountName "smbx_abc123"
            $result.Name | Should -Be "smbx_acl_abc123"
        }

        It "Should handle numeric suffixes" {
            Mock Get-ADObject {
                return [PSCustomObject]@{
                    Name = "smbx_acl_99999"
                    SamAccountName = "smbx_acl_99999"
                    mail = "group@ethz.ch"
                    GroupScope = "Universal"
                    Description = "Permission group for shared mailbox smbx@ethz.ch; Owner; AdminGroup"
                }
            }

            $result = Get-SharedMailboxACLGroup -SamAccountName "smbx_99999"
            $result | Should -Not -BeNullOrEmpty
        }

        It "Should handle underscore in suffix" {
            Mock Get-ADObject {
                return [PSCustomObject]@{
                    Name = "smbx_acl_user_test_123"
                    SamAccountName = "smbx_acl_user_test_123"
                    mail = "group@ethz.ch"
                    GroupScope = "Universal"
                    Description = "Permission group for shared mailbox smbx@ethz.ch; Owner; AdminGroup"
                }
            }

            $result = Get-SharedMailboxACLGroup -SamAccountName "smbx_user_test_123"
            $result.Name | Should -Be "smbx_acl_user_test_123"
        }
    }
}
