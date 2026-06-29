<#
.SYNOPSIS
Unit tests for Invoke-SharedMailboxProvisioning function
#>

# Import function
$projectRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$functionPath = Join-Path $projectRoot "functions" "Public" "Invoke-SharedMailboxProvisioning.ps1"
. $functionPath

Describe "InvokeSharedMailboxProvisioning" {

    Context "Complete provisioning pipeline" {
        It "Should execute full provisioning pipeline" {
            Mock Get-SharedMailboxCandidatesWithGroups {
                return @(
                    [PSCustomObject]@{
                        SamAccountName = "smbx_123456"
                        DisplayName = "Sales Team"
                        Mail = "sales@ethz.ch"
                        ACLGroupName = "smbx_acl_123456"
                        AdminGroupName = "ZO-Mail-Admins"
                    }
                )
            }

            Mock New-SharedMailboxRemote {
                return [PSCustomObject]@{
                    SamAccountName = "smbx_123456"
                    Status = "MAILBOX_CREATED_AWAITING_PERMISSIONS"
                }
            }

            Mock Invoke-MailboxPermissionQueue {
                return [PSCustomObject]@{
                    ProcessedCount = 1
                    SuccessCount = 1
                    FailedCount = 0
                    RetryingCount = 0
                    Summary = "1 successful"
                }
            }

            $result = Invoke-SharedMailboxProvisioning

            $result | Should -Not -BeNullOrEmpty
            $result.Status | Should -Be "COMPLETE"
            $result.CandidatesFound | Should -Be 1
            $result.MailboxesCreated | Should -Be 1
            $result.PermissionsAssigned | Should -Be 1
        }

        It "Should handle multiple candidates" {
            Mock Get-SharedMailboxCandidatesWithGroups {
                return @(
                    [PSCustomObject]@{
                        SamAccountName = "smbx_111"
                        DisplayName = "Group 1"
                        Mail = "group1@ethz.ch"
                        ACLGroupName = "smbx_acl_111"
                        AdminGroupName = "Admins"
                    },
                    [PSCustomObject]@{
                        SamAccountName = "smbx_222"
                        DisplayName = "Group 2"
                        Mail = "group2@ethz.ch"
                        ACLGroupName = "smbx_acl_222"
                        AdminGroupName = "Admins"
                    }
                )
            }

            Mock New-SharedMailboxRemote {
                return [PSCustomObject]@{ Status = "MAILBOX_CREATED_AWAITING_PERMISSIONS" }
            }

            Mock Invoke-MailboxPermissionQueue {
                return [PSCustomObject]@{
                    ProcessedCount = 2
                    SuccessCount = 2
                    FailedCount = 0
                    RetryingCount = 0
                    Summary = "2 successful"
                }
            }

            $result = Invoke-SharedMailboxProvisioning

            $result.CandidatesFound | Should -Be 2
            $result.MailboxesCreated | Should -Be 2
        }
    }

    Context "No candidates" {
        It "Should handle no candidates gracefully" {
            Mock Get-SharedMailboxCandidatesWithGroups {
                return $null
            }

            $result = Invoke-SharedMailboxProvisioning

            $result.Status | Should -Be "COMPLETE"
            $result.CandidatesFound | Should -Be 0
            $result.MailboxesCreated | Should -Be 0
        }
    }

    Context "Mailbox creation failures" {
        It "Should continue on mailbox creation failure" {
            Mock Get-SharedMailboxCandidatesWithGroups {
                return @(
                    [PSCustomObject]@{
                        SamAccountName = "smbx_123"
                        DisplayName = "Test"
                        Mail = "test@ethz.ch"
                        ACLGroupName = "acl"
                        AdminGroupName = "admin"
                    }
                )
            }

            Mock New-SharedMailboxRemote {
                return $null
            }

            Mock Invoke-MailboxPermissionQueue {
                return [PSCustomObject]@{
                    ProcessedCount = 0
                    SuccessCount = 0
                    FailedCount = 0
                    RetryingCount = 0
                }
            }

            $result = Invoke-SharedMailboxProvisioning

            $result.Status | Should -Be "COMPLETE"
            $result.MailboxesCreated | Should -Be 0
            $result.MailboxesFailed | Should -Be 1
        }
    }

    Context "Skip permission queue" {
        It "Should skip permission queue when flag set" {
            Mock Get-SharedMailboxCandidatesWithGroups {
                return [PSCustomObject]@{
                    SamAccountName = "smbx_123"
                    DisplayName = "Test"
                    Mail = "test@ethz.ch"
                    ACLGroupName = "acl"
                    AdminGroupName = "admin"
                }
            }

            Mock New-SharedMailboxRemote {
                return [PSCustomObject]@{ Status = "MAILBOX_CREATED_AWAITING_PERMISSIONS" }
            }

            Mock Invoke-MailboxPermissionQueue {
                throw "Should not be called"
            }

            $result = Invoke-SharedMailboxProvisioning -SkipPermissionQueue $true

            $result.Status | Should -Be "COMPLETE"
            $result.MailboxesCreated | Should -Be 1
            $result.PermissionsAssigned | Should -Be 0
        }
    }

    Context "Return object" {
        It "Should return complete summary object" {
            Mock Get-SharedMailboxCandidatesWithGroups {
                return [PSCustomObject]@{
                    SamAccountName = "smbx_123"
                    DisplayName = "Test"
                    Mail = "test@ethz.ch"
                    ACLGroupName = "acl"
                    AdminGroupName = "admin"
                }
            }

            Mock New-SharedMailboxRemote {
                return [PSCustomObject]@{ Status = "CREATED" }
            }

            Mock Invoke-MailboxPermissionQueue {
                return [PSCustomObject]@{
                    ProcessedCount = 1
                    SuccessCount = 1
                    FailedCount = 0
                    RetryingCount = 0
                    Summary = "1 successful"
                }
            }

            $result = Invoke-SharedMailboxProvisioning

            $result | Should -HaveProperty "Status"
            $result | Should -HaveProperty "StartTime"
            $result | Should -HaveProperty "EndTime"
            $result | Should -HaveProperty "Duration"
            $result | Should -HaveProperty "CandidatesFound"
            $result | Should -HaveProperty "MailboxesCreated"
            $result | Should -HaveProperty "Summary"
        }
    }

    Context "Error handling" {
        It "Should catch and report pipeline errors" {
            Mock Get-SharedMailboxCandidatesWithGroups {
                throw [System.Exception]"Candidate discovery failed"
            }

            $result = Invoke-SharedMailboxProvisioning

            $result.Status | Should -Be "FAILED"
            $result | Should -HaveProperty "Error"
        }
    }

    Context "Parameters" {
        It "Should pass parameters to Get-SharedMailboxCandidatesWithGroups" {
            Mock Get-SharedMailboxCandidatesWithGroups {
                return $null
            }

            Invoke-SharedMailboxProvisioning -SamAccountNamePrefix "custom_" -DescriptionStartsWith "Custom Desc"

            Assert-MockCalled Get-SharedMailboxCandidatesWithGroups -Times 1
        }

        It "Should pass BacklogPath to provisioning functions" {
            Mock Get-SharedMailboxCandidatesWithGroups {
                return [PSCustomObject]@{
                    SamAccountName = "smbx_123"
                    DisplayName = "Test"
                    Mail = "test@ethz.ch"
                    ACLGroupName = "acl"
                    AdminGroupName = "admin"
                }
            }

            Mock New-SharedMailboxRemote {
                return [PSCustomObject]@{ Status = "CREATED" }
            }

            Mock Invoke-MailboxPermissionQueue {
                return [PSCustomObject]@{
                    ProcessedCount = 0
                    SuccessCount = 0
                    FailedCount = 0
                    RetryingCount = 0
                }
            }

            $backlogPath = "C:\custom\backlog.json"
            Invoke-SharedMailboxProvisioning -BacklogPath $backlogPath

            Assert-MockCalled New-SharedMailboxRemote -Times 1 -ParameterFilter {
                $BacklogPath -eq "C:\custom\backlog.json"
            }
        }
    }
}
