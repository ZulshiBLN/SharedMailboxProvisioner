<#
.SYNOPSIS
Unit tests for Get-SharedMailboxACLGroup function
#>

# Import functions
$projectRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$functionPath1 = Join-Path $projectRoot "functions" "Private" "_ParseSharedMailboxGroupDescription.ps1"
$functionPath2 = Join-Path $projectRoot "functions" "Private" "_ValidateSharedMailboxGroup.ps1"
$functionPath3 = Join-Path $projectRoot "functions" "Public" "Get-SharedMailboxACLGroup.ps1"

. $functionPath1
. $functionPath2
. $functionPath3

Describe "GetSharedMailboxACLGroup" {

    Context "Successful group retrieval" {
        It "Should find and return valid group" {
            # Mock Get-ADGroup
            Mock Get-ADGroup {
                return [PSCustomObject]@{
                    Name = "SG-Smbx-User123"
                    mail = "group@ethz.ch"
                    Description = "Permission group for shared mailbox user@ethz.ch; Owner; AdminGroup"
                    ObjectClass = "group"
                }
            }

            $result = Get-SharedMailboxACLGroup -SamAccountName "User123"

            $result | Should -Not -BeNullOrEmpty
            $result.Name | Should -Be "SG-Smbx-User123"
            $result.IsValid | Should -Be $true
            $result.ParsedMetadata.Email | Should -Be "user@ethz.ch"

            Assert-MockCalled Get-ADGroup -Times 1
        }

        It "Should construct correct group name from SamAccountName" {
            Mock Get-ADGroup {
                param($Filter)
                if ($Filter -match "SG-Smbx-TestUser") {
                    return [PSCustomObject]@{
                        Name = "SG-Smbx-TestUser"
                        mail = "group@ethz.ch"
                        Description = "Permission group for shared mailbox test@ethz.ch; Member; AdminTeam"
                        ObjectClass = "group"
                    }
                }
                return $null
            }

            $result = Get-SharedMailboxACLGroup -SamAccountName "TestUser"
            $result.Name | Should -Be "SG-Smbx-TestUser"
        }

        It "Should handle M365 domain in description" {
            Mock Get-ADGroup {
                return [PSCustomObject]@{
                    Name = "SG-Smbx-M365User"
                    mail = "grp@ethz.onmicrosoft.com"
                    Description = "Permission group for shared mailbox smbx@ethz.onmicrosoft.com; Owner; AdminGrp"
                    ObjectClass = "group"
                }
            }

            $result = Get-SharedMailboxACLGroup -SamAccountName "M365User"
            $result.IsValid | Should -Be $true
            $result.ParsedMetadata.AdminGroup | Should -Be "AdminGrp"
        }
    }

    Context "Group not found" {
        It "Should return null when group doesn't exist" {
            Mock Get-ADGroup {
                return $null
            }

            $result = Get-SharedMailboxACLGroup -SamAccountName "NonExistent"
            $result | Should -BeNullOrEmpty
        }

        It "Should handle AD search returning no results" {
            Mock Get-ADGroup {
                return @()
            }

            $result = Get-SharedMailboxACLGroup -SamAccountName "Empty"
            $result | Should -BeNullOrEmpty
        }
    }

    Context "Group validation failures" {
        It "Should return null when group missing mail attribute" {
            Mock Get-ADGroup {
                return [PSCustomObject]@{
                    Name = "SG-Smbx-NoMail"
                    mail = ""
                    Description = "Permission group for shared mailbox user@ethz.ch; Owner; AdminGroup"
                    ObjectClass = "group"
                }
            }

            $result = Get-SharedMailboxACLGroup -SamAccountName "NoMail"
            $result | Should -BeNullOrEmpty
        }

        It "Should return null when group description invalid" {
            Mock Get-ADGroup {
                return [PSCustomObject]@{
                    Name = "SG-Smbx-BadDesc"
                    mail = "group@ethz.ch"
                    Description = "This is not a valid description"
                    ObjectClass = "group"
                }
            }

            $result = Get-SharedMailboxACLGroup -SamAccountName "BadDesc"
            $result | Should -BeNullOrEmpty
        }

        It "Should return null when object is not a group" {
            Mock Get-ADGroup {
                return [PSCustomObject]@{
                    Name = "NotAGroup"
                    mail = "user@ethz.ch"
                    Description = "Permission group for shared mailbox user@ethz.ch; Owner; AdminGroup"
                    ObjectClass = "user"
                }
            }

            $result = Get-SharedMailboxACLGroup -SamAccountName "NotGroup"
            $result | Should -BeNullOrEmpty
        }
    }

    Context "AD search parameters" {
        It "Should pass SearchBase parameter to Get-ADGroup" {
            Mock Get-ADGroup {
                return [PSCustomObject]@{
                    Name = "SG-Smbx-Test"
                    mail = "group@ethz.ch"
                    Description = "Permission group for shared mailbox user@ethz.ch; Owner; AdminGroup"
                    ObjectClass = "group"
                }
            }

            $searchBase = "OU=Groups,DC=ethz,DC=ch"
            $result = Get-SharedMailboxACLGroup -SamAccountName "Test" -SearchBase $searchBase

            Assert-MockCalled Get-ADGroup -Times 1 -ParameterFilter {
                $SearchBase -eq "OU=Groups,DC=ethz,DC=ch"
            }
        }

        It "Should not pass SearchBase when not provided" {
            Mock Get-ADGroup {
                return [PSCustomObject]@{
                    Name = "SG-Smbx-Test"
                    mail = "group@ethz.ch"
                    Description = "Permission group for shared mailbox user@ethz.ch; Owner; AdminGroup"
                    ObjectClass = "group"
                }
            }

            Get-SharedMailboxACLGroup -SamAccountName "Test"

            Assert-MockCalled Get-ADGroup -Times 1
        }
    }

    Context "Error handling" {
        It "Should handle Get-ADGroup exceptions" {
            Mock Get-ADGroup {
                throw [System.Exception]"AD connection failed"
            }

            $result = Get-SharedMailboxACLGroup -SamAccountName "Error"
            $result | Should -BeNullOrEmpty
        }

        It "Should handle permission denied errors" {
            Mock Get-ADGroup {
                throw [System.UnauthorizedAccessException]"Access denied"
            }

            $result = Get-SharedMailboxACLGroup -SamAccountName "NoAccess"
            $result | Should -BeNullOrEmpty
        }
    }

    Context "Return object structure" {
        It "Should return object with all expected properties" {
            Mock Get-ADGroup {
                return [PSCustomObject]@{
                    Name = "SG-Smbx-Complete"
                    mail = "group@ethz.ch"
                    Description = "Permission group for shared mailbox user@ethz.ch; Owner; AdminGroup"
                    ObjectClass = "group"
                }
            }

            $result = Get-SharedMailboxACLGroup -SamAccountName "Complete"

            $result | Should -HaveProperty "ADGroup"
            $result | Should -HaveProperty "Name"
            $result | Should -HaveProperty "Mail"
            $result | Should -HaveProperty "IsValid"
            $result | Should -HaveProperty "ParsedMetadata"
            $result | Should -HaveProperty "ValidationErrors"
        }

        It "Should include parsed metadata in result" {
            Mock Get-ADGroup {
                return [PSCustomObject]@{
                    Name = "SG-Smbx-WithMeta"
                    mail = "group@ethz.ch"
                    Description = "Permission group for shared mailbox smbx@ethz.ch; Member; AdminTeam"
                    ObjectClass = "group"
                }
            }

            $result = Get-SharedMailboxACLGroup -SamAccountName "WithMeta"

            $result.ParsedMetadata.Email | Should -Be "smbx@ethz.ch"
            $result.ParsedMetadata.Role | Should -Be "Member"
            $result.ParsedMetadata.AdminGroup | Should -Be "AdminTeam"
        }
    }

    Context "Edge cases" {
        It "Should handle SamAccountName with special characters" {
            Mock Get-ADGroup {
                return [PSCustomObject]@{
                    Name = "SG-Smbx-User_2024-Test"
                    mail = "group@ethz.ch"
                    Description = "Permission group for shared mailbox user@ethz.ch; Owner; AdminGroup"
                    ObjectClass = "group"
                }
            }

            $result = Get-SharedMailboxACLGroup -SamAccountName "User_2024-Test"
            $result.Name | Should -Be "SG-Smbx-User_2024-Test"
        }

        It "Should handle very long SamAccountName" {
            $longName = "A" * 50
            Mock Get-ADGroup {
                return [PSCustomObject]@{
                    Name = "SG-Smbx-$longName"
                    mail = "group@ethz.ch"
                    Description = "Permission group for shared mailbox user@ethz.ch; Owner; AdminGroup"
                    ObjectClass = "group"
                }
            }

            $result = Get-SharedMailboxACLGroup -SamAccountName $longName
            $result | Should -Not -BeNullOrEmpty
        }
    }
}
