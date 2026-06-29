<#
.SYNOPSIS
Get shared mailbox candidates with associated ACL groups

.DESCRIPTION
Retrieves shared mailbox candidates and enriches them with their associated ACL groups.
For each candidate, looks up the corresponding smbx_acl_* group and validates it.

Combines candidate data with group information for provisioning pipeline.

Per ADR-006: Active Directory Integration & Candidate Selection

.PARAMETER SamAccountNamePrefix
Candidate user SAM account name prefix (default: "smbx_")
ACL group name derived: smbx_acl_{suffix}

.PARAMETER DescriptionStartsWith
Candidate user description pattern (default: "Shared Mailbox Persona")

.PARAMETER CustomAttribute
Custom AD attribute for candidate flag (default: "nethzTask")

.PARAMETER CustomAttributeValue
Value to match in custom attribute (default: "Create RemoteMailbox")

.PARAMETER AccountStatus
Candidate account status filter: Enabled, Disabled, Any (default: Disabled)

.PARAMETER SearchBase
LDAP search base for candidate search (default: entire domain)

.PARAMETER ValidateAll
If true, only return candidates with valid ACL groups (default: $true)
If false, return all candidates and mark validation status

.EXAMPLE
$candidatesWithGroups = Get-SharedMailboxCandidatesWithGroups
Get all disabled smbx_* users with their associated ACL groups

.EXAMPLE
$readyToProvision = Get-SharedMailboxCandidatesWithGroups -ValidateAll $true
Only return candidates where ACL group is valid and ready for provisioning

.NOTES
Calls Get-SharedMailboxCandidates for candidate discovery
Calls Get-SharedMailboxACLGroup for each candidate
Validates ACL groups before including in results
#>

function Get-SharedMailboxCandidatesWithGroups {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$SamAccountNamePrefix = "smbx_",

        [Parameter(Mandatory = $false)]
        [string]$DescriptionStartsWith = "Shared Mailbox Persona",

        [Parameter(Mandatory = $false)]
        [string]$CustomAttribute = "nethzTask",

        [Parameter(Mandatory = $false)]
        [string]$CustomAttributeValue = "Create RemoteMailbox",

        [Parameter(Mandatory = $false)]
        [ValidateSet("Enabled", "Disabled", "Any")]
        [string]$AccountStatus = "Disabled",

        [Parameter(Mandatory = $false)]
        [string]$SearchBase = "",

        [Parameter(Mandatory = $false)]
        [bool]$ValidateAll = $true
    )

    Write-Verbose "Getting shared mailbox candidates with ACL groups"

    try {
        # Step 1: Get all candidates
        Write-Verbose "Step 1: Querying for candidates"
        $getCandidatesParams = @{
            SamAccountNamePrefix = $SamAccountNamePrefix
            DescriptionStartsWith = $DescriptionStartsWith
            CustomAttribute = $CustomAttribute
            CustomAttributeValue = $CustomAttributeValue
            AccountStatus = $AccountStatus
        }

        if (-not [string]::IsNullOrWhiteSpace($SearchBase)) {
            $getCandidatesParams['SearchBase'] = $SearchBase
        }

        $candidates = Get-SharedMailboxCandidates @getCandidatesParams

        if (-not $candidates -or $candidates.Count -eq 0) {
            Write-Verbose "No candidates found"
            Write-Log -Message "No candidates found for group association" `
                -Level INFO -Operation "Get-SharedMailboxCandidatesWithGroups" -Status "NO_CANDIDATES"
            return @()
        }

        Write-Verbose "Found $($candidates.Count) candidate(s)"

        # Step 2: For each candidate, retrieve and validate ACL group
        $resultsWithGroups = @()

        foreach ($candidate in $candidates) {
            Write-Verbose "Processing candidate: $($candidate.SamAccountName)"

            # Get ACL group for this candidate
            $aclGroup = Get-SharedMailboxACLGroup -SamAccountName $candidate.SamAccountName -SearchBase $SearchBase

            # Create result object
            if ($aclGroup) {
                $result = [PSCustomObject]@{
                    SamAccountName = $candidate.SamAccountName
                    DisplayName = $candidate.DisplayName
                    Mail = $candidate.Mail
                    Description = $candidate.Description
                    DistinguishedName = $candidate.DistinguishedName
                    Enabled = $candidate.Enabled
                    ACLGroup = $aclGroup
                    ACLGroupName = $aclGroup.Name
                    ACLGroupMail = $aclGroup.Mail
                    HasValidGroup = $aclGroup.IsValid
                    ADUser = $candidate.ADUser
                }

                $resultsWithGroups += $result

                Write-Verbose "Candidate $($candidate.SamAccountName) has valid ACL group: $($aclGroup.Name)"
            }
            else {
                if (-not $ValidateAll) {
                    # Include candidate even without valid group
                    $result = [PSCustomObject]@{
                        SamAccountName = $candidate.SamAccountName
                        DisplayName = $candidate.DisplayName
                        Mail = $candidate.Mail
                        Description = $candidate.Description
                        DistinguishedName = $candidate.DistinguishedName
                        Enabled = $candidate.Enabled
                        ACLGroup = $null
                        ACLGroupName = $null
                        ACLGroupMail = $null
                        HasValidGroup = $false
                        ADUser = $candidate.ADUser
                    }

                    $resultsWithGroups += $result
                    Write-Verbose "Candidate $($candidate.SamAccountName) has NO valid ACL group (included due to ValidateAll=false)"
                }
                else {
                    Write-Verbose "Candidate $($candidate.SamAccountName) has NO valid ACL group (excluded)"
                }
            }
        }

        if ($resultsWithGroups.Count -eq 0) {
            Write-Verbose "No candidates with valid ACL groups"
            Write-Log -Message "No candidates with valid ACL groups found" `
                -Level WARN -Operation "Get-SharedMailboxCandidatesWithGroups" -Status "NO_VALID_GROUPS"
            return @()
        }

        Write-Verbose "Returning $($resultsWithGroups.Count) candidate(s) with groups"
        Write-Log -Message "Found $($resultsWithGroups.Count) candidate(s) with valid ACL groups" `
            -Level INFO -Operation "Get-SharedMailboxCandidatesWithGroups" -Status "SUCCESS"

        return $resultsWithGroups

    }
    catch {
        $errorMessage = $_.Exception.Message
        Write-Error "Failed to get candidates with groups: $errorMessage"
        Write-Log -Message "Candidate+group retrieval failed: $errorMessage" `
            -Level ERROR -Operation "Get-SharedMailboxCandidatesWithGroups" -Status "ERROR"
        return @()
    }
}

Export-ModuleMember -Function Get-SharedMailboxCandidatesWithGroups
