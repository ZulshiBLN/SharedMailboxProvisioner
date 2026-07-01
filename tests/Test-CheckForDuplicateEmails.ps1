<#
.SYNOPSIS
Unit tests for _CheckForDuplicateEmails function
#>

# Import function
$projectRoot = Split-Path -Parent $PSScriptRoot
$functionPath = Join-Path (Join-Path $projectRoot "functions") "Private\_CheckForDuplicateEmails.ps1"
. $functionPath

Describe "CheckForDuplicateEmails" {

    Context "Unique emails (no duplicates)" {
        It "Should return false for unique email" {
            Mock Get-ADObject {
                return $null
            }

            $result = _CheckForDuplicateEmails -EmailAddress "unique@ethz.ch"
            $result | Should -Be $false
        }

        It "Should return false when no users found" {
            Mock Get-ADObject {
                return @()
            }

            $result = _CheckForDuplicateEmails -EmailAddress "unique@ethz.ch"
            $result | Should -Be $false
        }

        It "Should exclude current user from check" {
            Mock Get-ADObject {
                return [PSCustomObject]@{
                    sAMAccountName = "user123"
                    mail = "user123@ethz.ch"
                    proxyAddresses = @("user123@ethz.ch")
                }
            }

            $result = _CheckForDuplicateEmails -EmailAddress "user123@ethz.ch" -ExcludeUser "user123"
            $result | Should -Be $false
        }
    }

    Context "Duplicate emails found" {
        It "Should return true when email found in other user" {
            Mock Get-ADObject {
                return [PSCustomObject]@{
                    sAMAccountName = "otheruser"
                    mail = "duplicate@ethz.ch"
                    proxyAddresses = @("duplicate@ethz.ch")
                }
            }

            $result = _CheckForDuplicateEmails -EmailAddress "duplicate@ethz.ch"
            $result | Should -Be $true
        }

        It "Should return true for multiple duplicates" {
            Mock Get-ADObject {
                return @(
                    [PSCustomObject]@{
                        sAMAccountName = "user1"
                        mail = "dup@ethz.ch"
                        proxyAddresses = @("dup@ethz.ch")
                    },
                    [PSCustomObject]@{
                        sAMAccountName = "user2"
                        mail = "other@ethz.ch"
                        proxyAddresses = @("dup@ethz.ch")
                    }
                )
            }

            $result = _CheckForDuplicateEmails -EmailAddress "dup@ethz.ch"
            $result | Should -Be $true
        }

        It "Should find email in ProxyAddresses" {
            Mock Get-ADObject {
                return [PSCustomObject]@{
                    sAMAccountName = "user1"
                    mail = "user1@ethz.ch"
                    proxyAddresses = @("user1@ethz.ch", "dup@ethz.ch")
                }
            }

            $result = _CheckForDuplicateEmails -EmailAddress "dup@ethz.ch"
            $result | Should -Be $true
        }

        It "Should return true after excluding one user but finding others" {
            Mock Get-ADObject {
                return @(
                    [PSCustomObject]@{
                        sAMAccountName = "user123"
                        mail = "dup@ethz.ch"
                        proxyAddresses = @("dup@ethz.ch")
                    },
                    [PSCustomObject]@{
                        sAMAccountName = "other_user"
                        mail = "other@ethz.ch"
                        proxyAddresses = @("dup@ethz.ch")
                    }
                )
            }

            $result = _CheckForDuplicateEmails -EmailAddress "dup@ethz.ch" -ExcludeUser "user123"
            $result | Should -Be $true
        }
    }

    Context "Input validation" {
        It "Should return false for empty email" {
            $result = _CheckForDuplicateEmails -EmailAddress ""
            $result | Should -Be $false
        }

        It "Should return false for whitespace-only email" {
            $result = _CheckForDuplicateEmails -EmailAddress "   "
            $result | Should -Be $false
        }
    }

    Context "AD search parameters" {
        It "Should pass SearchBase parameter to Get-ADObject" {
            Mock Get-ADObject {
                return $null
            }

            $searchBase = "OU=Users,DC=ethz,DC=ch"
            _CheckForDuplicateEmails -EmailAddress "test@ethz.ch" -SearchBase $searchBase

            Assert-MockCalled Get-ADObject -Times 1 -ParameterFilter {
                $SearchBase -eq "OU=Users,DC=ethz,DC=ch"
            }
        }

        It "Should use correct LDAP filter" {
            Mock Get-ADObject {
                return $null
            }

            _CheckForDuplicateEmails -EmailAddress "test@ethz.ch"

            Assert-MockCalled Get-ADObject -Times 1 -ParameterFilter {
                $LDAPFilter -like "*(|*test@ethz.ch*)*"
            }
        }
    }

    Context "Error handling" {
        It "Should return false on AD connection error" {
            Mock Get-ADObject {
                throw [System.Exception]"AD connection failed"
            }

            $result = _CheckForDuplicateEmails -EmailAddress "test@ethz.ch"
            $result | Should -Be $false
        }

        It "Should return false on permission denied" {
            Mock Get-ADObject {
                throw [System.UnauthorizedAccessException]"Access denied"
            }

            $result = _CheckForDuplicateEmails -EmailAddress "test@ethz.ch"
            $result | Should -Be $false
        }
    }

    Context "Email format variations" {
        It "Should find duplicates with different case" {
            Mock Get-ADObject {
                return [PSCustomObject]@{
                    sAMAccountName = "user1"
                    mail = "TEST@ETHZ.CH"
                    proxyAddresses = @("TEST@ETHZ.CH")
                }
            }

            $result = _CheckForDuplicateEmails -EmailAddress "test@ethz.ch"
            $result | Should -Be $true
        }

        It "Should find email with plus addressing" {
            Mock Get-ADObject {
                return [PSCustomObject]@{
                    sAMAccountName = "user1"
                    mail = "test+tag@ethz.ch"
                    proxyAddresses = @("test+tag@ethz.ch")
                }
            }

            $result = _CheckForDuplicateEmails -EmailAddress "test+tag@ethz.ch"
            $result | Should -Be $true
        }

        It "Should find M365 domain email" {
            Mock Get-ADObject {
                return [PSCustomObject]@{
                    sAMAccountName = "user1"
                    mail = "user@ethz.onmicrosoft.com"
                    proxyAddresses = @("user@ethz.onmicrosoft.com")
                }
            }

            $result = _CheckForDuplicateEmails -EmailAddress "user@ethz.onmicrosoft.com"
            $result | Should -Be $true
        }
    }

    Context "Edge cases" {
        It "Should handle single result (not array)" {
            Mock Get-ADObject {
                return [PSCustomObject]@{
                    sAMAccountName = "user1"
                    mail = "dup@ethz.ch"
                    proxyAddresses = @("dup@ethz.ch")
                }
            }

            $result = _CheckForDuplicateEmails -EmailAddress "dup@ethz.ch"
            $result | Should -Be $true
        }

        It "Should handle multiple results as array" {
            Mock Get-ADObject {
                return @(
                    [PSCustomObject]@{ sAMAccountName = "u1"; mail = "dup@ethz.ch"; proxyAddresses = @("dup@ethz.ch") },
                    [PSCustomObject]@{ sAMAccountName = "u2"; mail = "other@ethz.ch"; proxyAddresses = @("dup@ethz.ch") }
                )
            }

            $result = _CheckForDuplicateEmails -EmailAddress "dup@ethz.ch"
            $result | Should -Be $true
        }

        It "Should return false when only excluded user has email" {
            Mock Get-ADObject {
                return [PSCustomObject]@{
                    sAMAccountName = "exclude_me"
                    mail = "test@ethz.ch"
                    proxyAddresses = @("test@ethz.ch")
                }
            }

            $result = _CheckForDuplicateEmails -EmailAddress "test@ethz.ch" -ExcludeUser "exclude_me"
            $result | Should -Be $false
        }
    }
}
