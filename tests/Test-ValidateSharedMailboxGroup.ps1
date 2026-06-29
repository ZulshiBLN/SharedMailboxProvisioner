<#
.SYNOPSIS
Unit tests for _ValidateSharedMailboxGroup function
#>

# Import functions
$projectRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$functionPath1 = Join-Path $projectRoot "functions" "Private" "_ParseSharedMailboxGroupDescription.ps1"
$functionPath2 = Join-Path $projectRoot "functions" "Private" "_ValidateSharedMailboxGroup.ps1"
. $functionPath1
. $functionPath2

Describe "ValidateSharedMailboxGroup" {

    Context "Valid groups" {
        It "Should validate complete group with all attributes" {
            $group = [PSCustomObject]@{
                Name = "SG-SmbxGroup"
                ObjectClass = "group"
                mail = "group@ethz.ch"
                Description = "Permission group for shared mailbox user@ethz.ch; Owner; AdminGroup"
            }

            $result = _ValidateSharedMailboxGroup $group

            $result.IsValid | Should -Be $true
            $result.ValidationErrors.Count | Should -Be 0
            $result.ParsedMetadata | Should -Not -BeNullOrEmpty
            $result.ParsedMetadata.Email | Should -Be "user@ethz.ch"
        }

        It "Should validate group with M365 domain" {
            $group = [PSCustomObject]@{
                Name = "SG-Smbx-M365"
                ObjectClass = "group"
                mail = "smbx-group@ethz.onmicrosoft.com"
                Description = "Permission group for shared mailbox smbx@ethz.onmicrosoft.com; Member; AdminGrp"
            }

            $result = _ValidateSharedMailboxGroup $group
            $result.IsValid | Should -Be $true
            $result.ParsedMetadata.AdminGroup | Should -Be "AdminGrp"
        }

        It "Should validate group with whitespace in description" {
            $group = [PSCustomObject]@{
                Name = "SG-Test"
                ObjectClass = "group"
                mail = "group@ethz.ch"
                Description = "Permission group for shared mailbox user@ethz.ch;   Owner   ;   AdminGroup   "
            }

            $result = _ValidateSharedMailboxGroup $group
            $result.IsValid | Should -Be $true
            $result.ParsedMetadata.Role | Should -Be "Owner"
        }
    }

    Context "Invalid groups - Missing attributes" {
        It "Should reject group without ObjectClass group" {
            $group = [PSCustomObject]@{
                Name = "NotAGroup"
                ObjectClass = "user"
                mail = "group@ethz.ch"
                Description = "Permission group for shared mailbox user@ethz.ch; Owner; AdminGroup"
            }

            $result = _ValidateSharedMailboxGroup $group
            $result.IsValid | Should -Be $false
            $result.ValidationErrors | Should -Contain "Object is not a group"
        }

        It "Should reject group without mail attribute" {
            $group = [PSCustomObject]@{
                Name = "SG-NoMail"
                ObjectClass = "group"
                mail = ""
                Description = "Permission group for shared mailbox user@ethz.ch; Owner; AdminGroup"
            }

            $result = _ValidateSharedMailboxGroup $group
            $result.IsValid | Should -Be $false
            $result.ValidationErrors | Should -Contain "Group has no mail attribute"
        }

        It "Should reject group without description" {
            $group = [PSCustomObject]@{
                Name = "SG-NoDesc"
                ObjectClass = "group"
                mail = "group@ethz.ch"
                Description = ""
            }

            $result = _ValidateSharedMailboxGroup $group
            $result.IsValid | Should -Be $false
            $result.ValidationErrors | Should -Contain "Group has no description"
        }

        It "Should reject null group" {
            $result = _ValidateSharedMailboxGroup $null
            $result.IsValid | Should -Be $false
            $result.ValidationErrors | Should -Contain "Group object is null"
        }
    }

    Context "Invalid groups - Bad description format" {
        It "Should reject group with malformed description" {
            $group = [PSCustomObject]@{
                Name = "SG-BadDesc"
                ObjectClass = "group"
                mail = "group@ethz.ch"
                Description = "This is not a valid shared mailbox group description"
            }

            $result = _ValidateSharedMailboxGroup $group
            $result.IsValid | Should -Be $false
            $result.ValidationErrors | Should -Contain "Group description format invalid*"
        }

        It "Should reject group with missing parts in description" {
            $group = [PSCustomObject]@{
                Name = "SG-MissingParts"
                ObjectClass = "group"
                mail = "group@ethz.ch"
                Description = "Permission group for shared mailbox user@ethz.ch; Owner"
            }

            $result = _ValidateSharedMailboxGroup $group
            $result.IsValid | Should -Be $false
            $result.ValidationErrors.Count | Should -Be 1
        }

        It "Should reject group with empty email in description" {
            $group = [PSCustomObject]@{
                Name = "SG-EmptyEmail"
                ObjectClass = "group"
                mail = "group@ethz.ch"
                Description = "Permission group for shared mailbox ; Owner; AdminGroup"
            }

            $result = _ValidateSharedMailboxGroup $group
            $result.IsValid | Should -Be $false
        }
    }

    Context "Multiple validation errors" {
        It "Should collect all validation errors" {
            $group = [PSCustomObject]@{
                Name = "SG-AllBad"
                ObjectClass = "user"
                mail = ""
                Description = "Invalid format"
            }

            $result = _ValidateSharedMailboxGroup $group
            $result.IsValid | Should -Be $false
            $result.ValidationErrors.Count | Should -BeGreaterThan 2
        }

        It "Should report correct error count for each issue" {
            $group = [PSCustomObject]@{
                Name = "SG-NoMailNoDesc"
                ObjectClass = "group"
                mail = ""
                Description = ""
            }

            $result = _ValidateSharedMailboxGroup $group
            $result.IsValid | Should -Be $false
            $result.ValidationErrors.Count | Should -Be 2
        }
    }

    Context "Edge cases" {
        It "Should handle group with null properties" {
            $group = [PSCustomObject]@{
                Name = "SG-NullProps"
                ObjectClass = "group"
                mail = $null
                Description = $null
            }

            $result = _ValidateSharedMailboxGroup $group
            $result.IsValid | Should -Be $false
            $result.ValidationErrors.Count | Should -Be 2
        }

        It "Should handle group with whitespace-only values" {
            $group = [PSCustomObject]@{
                Name = "SG-Spaces"
                ObjectClass = "group"
                mail = "   "
                Description = "   "
            }

            $result = _ValidateSharedMailboxGroup $group
            $result.IsValid | Should -Be $false
        }

        It "Should validate group with special characters in name" {
            $group = [PSCustomObject]@{
                Name = "SG-Smbx_2024-Main"
                ObjectClass = "group"
                mail = "group@ethz.ch"
                Description = "Permission group for shared mailbox user@ethz.ch; Owner; Admin_Group_123"
            }

            $result = _ValidateSharedMailboxGroup $group
            $result.IsValid | Should -Be $true
        }

        It "Should return parsed metadata when valid" {
            $group = [PSCustomObject]@{
                Name = "SG-WithMeta"
                ObjectClass = "group"
                mail = "group@ethz.ch"
                Description = "Permission group for shared mailbox smbx@ethz.ch; Member; AdminTeam"
            }

            $result = _ValidateSharedMailboxGroup $group
            $result.ParsedMetadata | Should -Not -BeNullOrEmpty
            $result.ParsedMetadata.Email | Should -Be "smbx@ethz.ch"
            $result.ParsedMetadata.Role | Should -Be "Member"
            $result.ParsedMetadata.AdminGroup | Should -Be "AdminTeam"
        }

        It "Should return null metadata when invalid" {
            $group = [PSCustomObject]@{
                Name = "SG-Invalid"
                ObjectClass = "group"
                mail = "group@ethz.ch"
                Description = "Invalid format"
            }

            $result = _ValidateSharedMailboxGroup $group
            $result.ParsedMetadata | Should -BeNullOrEmpty
        }
    }
}
