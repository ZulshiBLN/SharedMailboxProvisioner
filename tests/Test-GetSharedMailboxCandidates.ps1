<#
.SYNOPSIS
Unit tests for Get-SharedMailboxCandidates function
#>

# Import function
$projectRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$functionPath = Join-Path $projectRoot "functions" "Public" "Get-SharedMailboxCandidates.ps1"
. $functionPath

Describe "GetSharedMailboxCandidates" {

    Context "Finding candidates" {
        It "Should return candidates matching criteria" {
            Mock Get-ADUser {
                return @(
                    [PSCustomObject]@{
                        sAMAccountName = "smbx_user1"
                        DisplayName = "Shared Mailbox 1"
                        mail = "smbx1@ethz.ch"
                        Description = "Shared Mailbox Persona - Test"
                        DistinguishedName = "CN=smbx_user1,OU=Users,DC=ethz,DC=ch"
                        userAccountControl = 514
                    },
                    [PSCustomObject]@{
                        sAMAccountName = "smbx_user2"
                        DisplayName = "Shared Mailbox 2"
                        mail = "smbx2@ethz.ch"
                        Description = "Shared Mailbox Persona - Accounting"
                        DistinguishedName = "CN=smbx_user2,OU=Users,DC=ethz,DC=ch"
                        userAccountControl = 514
                    }
                )
            }

            $result = Get-SharedMailboxCandidates
            $result.Count | Should -Be 2
            $result[0].SamAccountName | Should -Be "smbx_user1"
        }

        It "Should return empty array when no candidates found" {
            Mock Get-ADUser {
                return $null
            }

            $result = Get-SharedMailboxCandidates
            $result | Should -Be @()
        }

        It "Should handle single candidate result" {
            Mock Get-ADUser {
                return [PSCustomObject]@{
                    sAMAccountName = "smbx_only"
                    DisplayName = "Single Mailbox"
                    mail = "single@ethz.ch"
                    Description = "Shared Mailbox Persona"
                    DistinguishedName = "CN=smbx_only,OU=Users,DC=ethz,DC=ch"
                    userAccountControl = 514
                }
            }

            $result = Get-SharedMailboxCandidates
            $result | Should -Not -BeNullOrEmpty
            $result.SamAccountName | Should -Be "smbx_only"
        }
    }

    Context "Candidate properties" {
        It "Should include all candidate properties" {
            Mock Get-ADUser {
                return [PSCustomObject]@{
                    sAMAccountName = "smbx_test"
                    DisplayName = "Test Mailbox"
                    mail = "test@ethz.ch"
                    Description = "Shared Mailbox Persona"
                    DistinguishedName = "CN=smbx_test,OU=Users,DC=ethz,DC=ch"
                    userAccountControl = 514
                }
            }

            $result = Get-SharedMailboxCandidates
            $result | Should -HaveProperty "SamAccountName"
            $result | Should -HaveProperty "DisplayName"
            $result | Should -HaveProperty "Mail"
            $result | Should -HaveProperty "Description"
            $result | Should -HaveProperty "DistinguishedName"
            $result | Should -HaveProperty "Enabled"
            $result | Should -HaveProperty "ADUser"
        }

        It "Should correctly identify disabled accounts" {
            Mock Get-ADUser {
                return [PSCustomObject]@{
                    sAMAccountName = "smbx_disabled"
                    DisplayName = "Disabled Mailbox"
                    mail = "disabled@ethz.ch"
                    Description = "Shared Mailbox Persona"
                    DistinguishedName = "CN=smbx_disabled,OU=Users,DC=ethz,DC=ch"
                    userAccountControl = 514
                }
            }

            $result = Get-SharedMailboxCandidates
            $result.Enabled | Should -Be $false
        }

        It "Should correctly identify enabled accounts" {
            Mock Get-ADUser {
                return [PSCustomObject]@{
                    sAMAccountName = "smbx_enabled"
                    DisplayName = "Enabled Mailbox"
                    mail = "enabled@ethz.ch"
                    Description = "Shared Mailbox Persona"
                    DistinguishedName = "CN=smbx_enabled,OU=Users,DC=ethz,DC=ch"
                    userAccountControl = 512
                }
            }

            $result = Get-SharedMailboxCandidates
            $result.Enabled | Should -Be $true
        }
    }

    Context "Filter parameters" {
        It "Should use default prefix when not specified" {
            Mock Get-ADUser {
                return @()
            }

            Get-SharedMailboxCandidates

            Assert-MockCalled Get-ADUser -Times 1 -ParameterFilter {
                $Filter -like "*(sAMAccountName=smbx_*)*"
            }
        }

        It "Should use custom prefix when specified" {
            Mock Get-ADUser {
                return @()
            }

            Get-SharedMailboxCandidates -SamAccountNamePrefix "custom_"

            Assert-MockCalled Get-ADUser -Times 1 -ParameterFilter {
                $Filter -like "*(sAMAccountName=custom_*)*"
            }
        }

        It "Should filter by description pattern" {
            Mock Get-ADUser {
                return @()
            }

            Get-SharedMailboxCandidates

            Assert-MockCalled Get-ADUser -Times 1 -ParameterFilter {
                $Filter -like "*(description=Shared Mailbox Persona*)*"
            }
        }

        It "Should apply disabled account filter" {
            Mock Get-ADUser {
                return @()
            }

            Get-SharedMailboxCandidates -AccountStatus "Disabled"

            Assert-MockCalled Get-ADUser -Times 1 -ParameterFilter {
                $Filter -like "*(userAccountControl:1.2.840.113556.1.4.803:=2)*"
            }
        }

        It "Should apply enabled account filter" {
            Mock Get-ADUser {
                return @()
            }

            Get-SharedMailboxCandidates -AccountStatus "Enabled"

            Assert-MockCalled Get-ADUser -Times 1 -ParameterFilter {
                $Filter -like "*(!(userAccountControl:1.2.840.113556.1.4.803:=2))*"
            }
        }

        It "Should include custom attribute filter" {
            Mock Get-ADUser {
                return @()
            }

            Get-SharedMailboxCandidates

            Assert-MockCalled Get-ADUser -Times 1 -ParameterFilter {
                $Filter -like "*(extensionAttribute1=Create RemoteMailbox)*"
            }
        }

        It "Should pass SearchBase parameter" {
            Mock Get-ADUser {
                return @()
            }

            $searchBase = "OU=Shared,DC=ethz,DC=ch"
            Get-SharedMailboxCandidates -SearchBase $searchBase

            Assert-MockCalled Get-ADUser -Times 1 -ParameterFilter {
                $SearchBase -eq "OU=Shared,DC=ethz,DC=ch"
            }
        }
    }

    Context "Custom attribute mapping" {
        It "Should map nethzTask to extensionAttribute1" {
            Mock Get-ADUser {
                return @()
            }

            Get-SharedMailboxCandidates -CustomAttribute "nethzTask" -CustomAttributeValue "Test"

            Assert-MockCalled Get-ADUser -Times 1 -ParameterFilter {
                $Filter -like "*(extensionAttribute1=Test)*"
            }
        }

        It "Should map nethzRemark to extensionAttribute2" {
            Mock Get-ADUser {
                return @()
            }

            Get-SharedMailboxCandidates -CustomAttribute "nethzRemark" -CustomAttributeValue "Test"

            Assert-MockCalled Get-ADUser -Times 1 -ParameterFilter {
                $Filter -like "*(extensionAttribute2=Test)*"
            }
        }

        It "Should use extensionAttribute* as-is if already mapped name" {
            Mock Get-ADUser {
                return @()
            }

            Get-SharedMailboxCandidates -CustomAttribute "extensionAttribute5" -CustomAttributeValue "Value"

            Assert-MockCalled Get-ADUser -Times 1 -ParameterFilter {
                $Filter -like "*(extensionAttribute5=Value)*"
            }
        }
    }

    Context "Error handling" {
        It "Should return empty array on AD query failure" {
            Mock Get-ADUser {
                throw [System.Exception]"AD connection failed"
            }

            $result = Get-SharedMailboxCandidates
            $result | Should -Be @()
        }

        It "Should return empty array on permission denied" {
            Mock Get-ADUser {
                throw [System.UnauthorizedAccessException]"Access denied"
            }

            $result = Get-SharedMailboxCandidates
            $result | Should -Be @()
        }
    }

    Context "Account status variations" {
        It "Should handle 'Any' account status" {
            Mock Get-ADUser {
                return @()
            }

            Get-SharedMailboxCandidates -AccountStatus "Any"

            Assert-MockCalled Get-ADUser -Times 1 -ParameterFilter {
                $Filter -notlike "*(userAccountControl:*"
            }
        }
    }

    Context "Multiple candidates" {
        It "Should return multiple candidates in correct order" {
            Mock Get-ADUser {
                return @(
                    [PSCustomObject]@{ sAMAccountName = "smbx_a"; DisplayName = "A"; mail = "a@ethz.ch"; Description = "Shared Mailbox Persona"; DistinguishedName = "CN=smbx_a,OU=Users,DC=ethz,DC=ch"; userAccountControl = 514 },
                    [PSCustomObject]@{ sAMAccountName = "smbx_b"; DisplayName = "B"; mail = "b@ethz.ch"; Description = "Shared Mailbox Persona"; DistinguishedName = "CN=smbx_b,OU=Users,DC=ethz,DC=ch"; userAccountControl = 514 },
                    [PSCustomObject]@{ sAMAccountName = "smbx_c"; DisplayName = "C"; mail = "c@ethz.ch"; Description = "Shared Mailbox Persona"; DistinguishedName = "CN=smbx_c,OU=Users,DC=ethz,DC=ch"; userAccountControl = 514 }
                )
            }

            $result = Get-SharedMailboxCandidates
            $result.Count | Should -Be 3
            $result[0].SamAccountName | Should -Be "smbx_a"
            $result[1].SamAccountName | Should -Be "smbx_b"
            $result[2].SamAccountName | Should -Be "smbx_c"
        }
    }
}
