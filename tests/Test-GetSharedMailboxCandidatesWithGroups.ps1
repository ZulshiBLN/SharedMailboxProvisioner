<#
.SYNOPSIS
Unit tests for Get-SharedMailboxCandidatesWithGroups function
#>

# Import function
$projectRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$functionPath = Join-Path $projectRoot "functions" "Public" "Get-SharedMailboxCandidatesWithGroups.ps1"
. $functionPath

Describe "GetSharedMailboxCandidatesWithGroups" {

    Context "Retrieving candidates with groups" {
        It "Should return candidates with valid ACL groups" {
            Mock Get-SharedMailboxCandidates {
                return @(
                    [PSCustomObject]@{
                        SamAccountName = "smbx_user1"
                        DisplayName = "Mailbox 1"
                        Mail = "smbx1@ethz.ch"
                        Description = "Shared Mailbox Persona"
                        DistinguishedName = "CN=smbx_user1,OU=Users,DC=ethz,DC=ch"
                        Enabled = $false
                        ADUser = [PSCustomObject]@{ sAMAccountName = "smbx_user1" }
                    }
                )
            }

            Mock Get-SharedMailboxACLGroup {
                return [PSCustomObject]@{
                    Name = "smbx_acl_user1"
                    SamAccountName = "smbx_acl_user1"
                    Mail = "smbx_acl_user1@ethz.ch"
                    GroupScope = "Universal"
                    Description = "Permission group for shared mailbox smbx@ethz.ch; Owner; AdminGroup"
                    IsValid = $true
                }
            }

            $result = Get-SharedMailboxCandidatesWithGroups
            $result | Should -Not -BeNullOrEmpty
            $result.HasValidGroup | Should -Be $true
            $result.ACLGroupName | Should -Be "smbx_acl_user1"
        }

        It "Should return multiple candidates with groups" {
            Mock Get-SharedMailboxCandidates {
                return @(
                    [PSCustomObject]@{
                        SamAccountName = "smbx_user1"
                        DisplayName = "Mailbox 1"
                        Mail = "smbx1@ethz.ch"
                        Description = "Shared Mailbox Persona"
                        DistinguishedName = "CN=smbx_user1,OU=Users,DC=ethz,DC=ch"
                        Enabled = $false
                        ADUser = [PSCustomObject]@{ sAMAccountName = "smbx_user1" }
                    },
                    [PSCustomObject]@{
                        SamAccountName = "smbx_user2"
                        DisplayName = "Mailbox 2"
                        Mail = "smbx2@ethz.ch"
                        Description = "Shared Mailbox Persona"
                        DistinguishedName = "CN=smbx_user2,OU=Users,DC=ethz,DC=ch"
                        Enabled = $false
                        ADUser = [PSCustomObject]@{ sAMAccountName = "smbx_user2" }
                    }
                )
            }

            Mock Get-SharedMailboxACLGroup {
                return [PSCustomObject]@{
                    Name = "smbx_acl_user1"
                    SamAccountName = "smbx_acl_user1"
                    Mail = "smbx_acl_user1@ethz.ch"
                    IsValid = $true
                }
            }

            $result = Get-SharedMailboxCandidatesWithGroups
            $result.Count | Should -Be 2
        }

        It "Should return empty array when no candidates found" {
            Mock Get-SharedMailboxCandidates {
                return @()
            }

            $result = Get-SharedMailboxCandidatesWithGroups
            $result | Should -Be @()
        }
    }

    Context "Group validation filtering" {
        It "Should exclude candidates without valid groups when ValidateAll=true" {
            Mock Get-SharedMailboxCandidates {
                return @(
                    [PSCustomObject]@{
                        SamAccountName = "smbx_user1"
                        DisplayName = "Mailbox 1"
                        Mail = "smbx1@ethz.ch"
                        Description = "Shared Mailbox Persona"
                        DistinguishedName = "CN=smbx_user1,OU=Users,DC=ethz,DC=ch"
                        Enabled = $false
                        ADUser = [PSCustomObject]@{ sAMAccountName = "smbx_user1" }
                    },
                    [PSCustomObject]@{
                        SamAccountName = "smbx_user2"
                        DisplayName = "Mailbox 2"
                        Mail = "smbx2@ethz.ch"
                        Description = "Shared Mailbox Persona"
                        DistinguishedName = "CN=smbx_user2,OU=Users,DC=ethz,DC=ch"
                        Enabled = $false
                        ADUser = [PSCustomObject]@{ sAMAccountName = "smbx_user2" }
                    }
                )
            }

            Mock Get-SharedMailboxACLGroup {
                param($SamAccountName)
                if ($SamAccountName -eq "smbx_user1") {
                    return [PSCustomObject]@{
                        Name = "smbx_acl_user1"
                        IsValid = $true
                    }
                }
                return $null
            }

            $result = Get-SharedMailboxCandidatesWithGroups -ValidateAll $true
            $result.Count | Should -Be 1
            $result.SamAccountName | Should -Be "smbx_user1"
        }

        It "Should include candidates without valid groups when ValidateAll=false" {
            Mock Get-SharedMailboxCandidates {
                return @(
                    [PSCustomObject]@{
                        SamAccountName = "smbx_user1"
                        DisplayName = "Mailbox 1"
                        Mail = "smbx1@ethz.ch"
                        Description = "Shared Mailbox Persona"
                        DistinguishedName = "CN=smbx_user1,OU=Users,DC=ethz,DC=ch"
                        Enabled = $false
                        ADUser = [PSCustomObject]@{ sAMAccountName = "smbx_user1" }
                    },
                    [PSCustomObject]@{
                        SamAccountName = "smbx_user2"
                        DisplayName = "Mailbox 2"
                        Mail = "smbx2@ethz.ch"
                        Description = "Shared Mailbox Persona"
                        DistinguishedName = "CN=smbx_user2,OU=Users,DC=ethz,DC=ch"
                        Enabled = $false
                        ADUser = [PSCustomObject]@{ sAMAccountName = "smbx_user2" }
                    }
                )
            }

            Mock Get-SharedMailboxACLGroup {
                param($SamAccountName)
                if ($SamAccountName -eq "smbx_user1") {
                    return [PSCustomObject]@{
                        Name = "smbx_acl_user1"
                        IsValid = $true
                    }
                }
                return $null
            }

            $result = Get-SharedMailboxCandidatesWithGroups -ValidateAll $false
            $result.Count | Should -Be 2
            $result[0].HasValidGroup | Should -Be $true
            $result[1].HasValidGroup | Should -Be $false
        }
    }

    Context "Return object structure" {
        It "Should include all candidate and group properties" {
            Mock Get-SharedMailboxCandidates {
                return @(
                    [PSCustomObject]@{
                        SamAccountName = "smbx_user1"
                        DisplayName = "Mailbox 1"
                        Mail = "smbx1@ethz.ch"
                        Description = "Shared Mailbox Persona"
                        DistinguishedName = "CN=smbx_user1,OU=Users,DC=ethz,DC=ch"
                        Enabled = $false
                        ADUser = [PSCustomObject]@{ sAMAccountName = "smbx_user1" }
                    }
                )
            }

            Mock Get-SharedMailboxACLGroup {
                return [PSCustomObject]@{
                    Name = "smbx_acl_user1"
                    SamAccountName = "smbx_acl_user1"
                    Mail = "smbx_acl_user1@ethz.ch"
                    IsValid = $true
                }
            }

            $result = Get-SharedMailboxCandidatesWithGroups
            $result | Should -HaveProperty "SamAccountName"
            $result | Should -HaveProperty "DisplayName"
            $result | Should -HaveProperty "Mail"
            $result | Should -HaveProperty "ACLGroup"
            $result | Should -HaveProperty "ACLGroupName"
            $result | Should -HaveProperty "ACLGroupMail"
            $result | Should -HaveProperty "HasValidGroup"
        }
    }

    Context "Parameter passing" {
        It "Should pass SamAccountNamePrefix to Get-SharedMailboxCandidates" {
            Mock Get-SharedMailboxCandidates {
                return @()
            }

            Get-SharedMailboxCandidatesWithGroups -SamAccountNamePrefix "custom_"

            Assert-MockCalled Get-SharedMailboxCandidates -Times 1 -ParameterFilter {
                $SamAccountNamePrefix -eq "custom_"
            }
        }

        It "Should pass DescriptionStartsWith to Get-SharedMailboxCandidates" {
            Mock Get-SharedMailboxCandidates {
                return @()
            }

            Get-SharedMailboxCandidatesWithGroups -DescriptionStartsWith "Custom Description"

            Assert-MockCalled Get-SharedMailboxCandidates -Times 1 -ParameterFilter {
                $DescriptionStartsWith -eq "Custom Description"
            }
        }

        It "Should pass SearchBase to Get-SharedMailboxACLGroup" {
            Mock Get-SharedMailboxCandidates {
                return @(
                    [PSCustomObject]@{
                        SamAccountName = "smbx_user1"
                        DisplayName = "Mailbox 1"
                        Mail = "smbx1@ethz.ch"
                        Description = "Shared Mailbox Persona"
                        DistinguishedName = "CN=smbx_user1,OU=Users,DC=ethz,DC=ch"
                        Enabled = $false
                        ADUser = [PSCustomObject]@{ sAMAccountName = "smbx_user1" }
                    }
                )
            }

            Mock Get-SharedMailboxACLGroup {
                return [PSCustomObject]@{
                    Name = "smbx_acl_user1"
                    IsValid = $true
                }
            }

            $searchBase = "OU=Users,DC=ethz,DC=ch"
            Get-SharedMailboxCandidatesWithGroups -SearchBase $searchBase

            Assert-MockCalled Get-SharedMailboxACLGroup -Times 1 -ParameterFilter {
                $SearchBase -eq "OU=Users,DC=ethz,DC=ch"
            }
        }
    }

    Context "Error handling" {
        It "Should return empty array on error" {
            Mock Get-SharedMailboxCandidates {
                throw [System.Exception]"Query failed"
            }

            $result = Get-SharedMailboxCandidatesWithGroups
            $result | Should -Be @()
        }
    }
}
