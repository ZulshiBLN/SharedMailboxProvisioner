<#
.SYNOPSIS
Unit tests for Get-SharedMailboxACLGroup function
#>

# Import functions
$projectRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$functionPath3 = Join-Path $projectRoot "functions" "Public" "Get-SharedMailboxACLGroup.ps1"

. $functionPath3

Describe "GetSharedMailboxACLGroup" {

    Context "Successful group retrieval" {
        It "Should find and return group for smbx user" {
            Mock Get-ADGroup {
                return [PSCustomObject]@{
                    Name = "smbx_acl_12345678"
                    SamAccountName = "smbx_acl_12345678"
                }
            }

            $result = Get-SharedMailboxACLGroup -SamAccountName "smbx_12345678"

            $result | Should -Not -BeNullOrEmpty
            $result.Name | Should -Be "smbx_acl_12345678"
            $result.Found | Should -Be $true

            Assert-MockCalled Get-ADGroup -Times 1
        }

        It "Should construct correct group name from smbx user" {
            Mock Get-ADGroup {
                return [PSCustomObject]@{
                    Name = "smbx_acl_test99"
                    SamAccountName = "smbx_acl_test99"
                }
            }

            $result = Get-SharedMailboxACLGroup -SamAccountName "smbx_test99"
            $result.Name | Should -Be "smbx_acl_test99"
        }

        It "Should handle different suffix formats" {
            Mock Get-ADGroup {
                return [PSCustomObject]@{
                    Name = "smbx_acl_user_2024_001"
                    SamAccountName = "smbx_acl_user_2024_001"
                }
            }

            $result = Get-SharedMailboxACLGroup -SamAccountName "smbx_user_2024_001"
            $result | Should -Not -BeNullOrEmpty
        }
    }

    Context "Group not found" {
        It "Should return null when group doesn't exist" {
            Mock Get-ADGroup {
                return $null
            }

            $result = Get-SharedMailboxACLGroup -SamAccountName "smbx_nonexistent"
            $result | Should -BeNullOrEmpty
        }

        It "Should handle empty AD search results" {
            Mock Get-ADGroup {
                return @()
            }

            $result = Get-SharedMailboxACLGroup -SamAccountName "smbx_empty"
            $result | Should -BeNullOrEmpty
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
            Mock Get-ADGroup {
                return [PSCustomObject]@{
                    Name = "smbx_acl_12345678"
                    SamAccountName = "smbx_acl_12345678"
                }
            }

            $searchBase = "OU=Groups,DC=ethz,DC=ch"
            $result = Get-SharedMailboxACLGroup -SamAccountName "smbx_12345678" -SearchBase $searchBase

            Assert-MockCalled Get-ADGroup -Times 1 -ParameterFilter {
                $SearchBase -eq "OU=Groups,DC=ethz,DC=ch"
            }
        }

        It "Should work without SearchBase parameter" {
            Mock Get-ADGroup {
                return [PSCustomObject]@{
                    Name = "smbx_acl_12345678"
                    SamAccountName = "smbx_acl_12345678"
                }
            }

            $result = Get-SharedMailboxACLGroup -SamAccountName "smbx_12345678"
            $result | Should -Not -BeNullOrEmpty
        }
    }

    Context "Error handling" {
        It "Should handle AD connection failures" {
            Mock Get-ADGroup {
                throw [System.Exception]"AD connection failed"
            }

            $result = Get-SharedMailboxACLGroup -SamAccountName "smbx_error"
            $result | Should -BeNullOrEmpty
        }

        It "Should handle permission denied errors" {
            Mock Get-ADGroup {
                throw [System.UnauthorizedAccessException]"Access denied"
            }

            $result = Get-SharedMailboxACLGroup -SamAccountName "smbx_noaccess"
            $result | Should -BeNullOrEmpty
        }
    }

    Context "Return object structure" {
        It "Should return object with expected properties" {
            Mock Get-ADGroup {
                return [PSCustomObject]@{
                    Name = "smbx_acl_12345678"
                    SamAccountName = "smbx_acl_12345678"
                }
            }

            $result = Get-SharedMailboxACLGroup -SamAccountName "smbx_12345678"

            $result | Should -HaveProperty "ADGroup"
            $result | Should -HaveProperty "Name"
            $result | Should -HaveProperty "SamAccountName"
            $result | Should -HaveProperty "Found"
        }

        It "Should include AD group object in result" {
            Mock Get-ADGroup {
                return [PSCustomObject]@{
                    Name = "smbx_acl_12345678"
                    SamAccountName = "smbx_acl_12345678"
                }
            }

            $result = Get-SharedMailboxACLGroup -SamAccountName "smbx_12345678"
            $result.ADGroup | Should -Not -BeNullOrEmpty
            $result.ADGroup.SamAccountName | Should -Be "smbx_acl_12345678"
        }
    }

    Context "Suffix extraction" {
        It "Should correctly extract suffix from smbx_ prefix" {
            Mock Get-ADGroup {
                param($Filter)
                # Verify correct LDAP filter was used
                if ($Filter -match "smbx_acl_abc123") {
                    return [PSCustomObject]@{
                        Name = "smbx_acl_abc123"
                        SamAccountName = "smbx_acl_abc123"
                    }
                }
                return $null
            }

            $result = Get-SharedMailboxACLGroup -SamAccountName "smbx_abc123"
            $result.Name | Should -Be "smbx_acl_abc123"
        }

        It "Should handle numeric suffixes" {
            Mock Get-ADGroup {
                return [PSCustomObject]@{
                    Name = "smbx_acl_99999"
                    SamAccountName = "smbx_acl_99999"
                }
            }

            $result = Get-SharedMailboxACLGroup -SamAccountName "smbx_99999"
            $result | Should -Not -BeNullOrEmpty
        }

        It "Should handle underscore in suffix" {
            Mock Get-ADGroup {
                return [PSCustomObject]@{
                    Name = "smbx_acl_user_test_123"
                    SamAccountName = "smbx_acl_user_test_123"
                }
            }

            $result = Get-SharedMailboxACLGroup -SamAccountName "smbx_user_test_123"
            $result.Name | Should -Be "smbx_acl_user_test_123"
        }
    }
}
