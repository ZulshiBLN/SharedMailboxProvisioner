<#
.SYNOPSIS
Get shared mailbox user candidates from Active Directory

.DESCRIPTION
Queries Active Directory for users matching shared mailbox criteria.
Searches for disabled users with specific naming convention and description pattern.

Default criteria:
- SamAccountName starts with "smbx_"
- Description starts with "Shared Mailbox Persona"
- Account status: Disabled
- Custom attribute (nethzTask) = "Create RemoteMailbox"

Returns array of candidate user objects for provisioning.

Per ADR-006: Active Directory Integration & Candidate Selection

.PARAMETER SamAccountNamePrefix
User SAM account name prefix (default: "smbx_")

.PARAMETER DescriptionStartsWith
User description must start with this text (default: "Shared Mailbox Persona")

.PARAMETER CustomAttribute
AD attribute name to check for flag (default: "nethzTask")
Maps to extensionAttribute* in Active Directory

.PARAMETER CustomAttributeValue
Value to match in custom attribute (default: "Create RemoteMailbox")
Required if CustomAttribute differs from default

.PARAMETER AccountStatus
Account status filter: Enabled, Disabled, or Any (default: Disabled)

.PARAMETER SearchBase
LDAP search base (default: entire domain root)

.EXAMPLE
$candidates = Get-SharedMailboxCandidates
Get all disabled smbx_* users with description and attribute match

.EXAMPLE
$candidates = Get-SharedMailboxCandidates -SearchBase "OU=Users,DC=ethz,DC=ch"
Search only in specific OU

.NOTES
Uses efficient LDAP filter for large directories
Returns detailed candidate information for validation pipeline
#>

function Get-SharedMailboxCandidates {
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
        [string]$SearchBase = ""
    )

    Write-Verbose "Querying AD for shared mailbox candidates"
    Write-Verbose "  Prefix: $SamAccountNamePrefix"
    Write-Verbose "  Description: $DescriptionStartsWith*"
    Write-Verbose "  Status: $AccountStatus"
    Write-Verbose "  Custom attribute: $CustomAttribute = $CustomAttributeValue"

    try {
        # Build LDAP filter for efficient search
        $filterParts = @(
            "(sAMAccountName=$SamAccountNamePrefix*)",
            "(description=$DescriptionStartsWith*)"
        )

        # Add custom attribute filter if specified
        if (-not [string]::IsNullOrWhiteSpace($CustomAttribute) -and
            -not [string]::IsNullOrWhiteSpace($CustomAttributeValue)) {
            # Map custom attribute to extensionAttribute*
            $extAttr = _MapCustomAttributeToExtension -AttributeName $CustomAttribute
            $filterParts += "($extAttr=$CustomAttributeValue)"
        }

        # Add account status filter
        if ($AccountStatus -ne "Any") {
            if ($AccountStatus -eq "Disabled") {
                # Disabled: userAccountControl bit 2 set
                $filterParts += "(userAccountControl:1.2.840.113556.1.4.803:=2)"
            }
            elseif ($AccountStatus -eq "Enabled") {
                # Enabled: userAccountControl bit 2 NOT set
                $filterParts += "(!(userAccountControl:1.2.840.113556.1.4.803:=2))"
            }
        }

        # Combine all filters with AND, add objectClass=user for efficiency
        $ldapFilter = "(&(objectClass=user)" + ($filterParts -join "") + ")"
        Write-Verbose "LDAP filter: $ldapFilter"

        # Prepare Get-ADObject parameters (more efficient than Get-ADUser for large directories)
        # LDAPFilter (not Filter) is required here - Filter expects PowerShell expression
        # syntax (-eq, -like, ...), not raw LDAP filter strings like $ldapFilter.
        $getAdParams = @{
            LDAPFilter = $ldapFilter
            ErrorAction = 'Stop'
            Properties = @('mail', 'DisplayName', 'Description', 'DistinguishedName', 'userAccountControl')
        }

        if (-not [string]::IsNullOrWhiteSpace($SearchBase)) {
            $getAdParams['SearchBase'] = $SearchBase
        }

        # Query Active Directory (using Get-ADObject for better performance on large directories)
        Write-Verbose "Executing AD query with Get-ADObject..."
        $results = Get-ADObject @getAdParams

        if (-not $results) {
            Write-Verbose "No candidates found matching criteria"
            Write-Log -Message "No shared mailbox candidates found" `
                -Level INFO -Operation "Get-SharedMailboxCandidates" -Status "NO_RESULTS"
            return @()
        }

        # Convert single result to array for consistent handling
        if ($results -isnot [System.Collections.ArrayList] -and $results -isnot [System.Array]) {
            $results = @($results)
        }

        # Build return objects with candidate metadata
        $candidates = $results | ForEach-Object {
            [PSCustomObject]@{
                SamAccountName = $_.sAMAccountName
                DisplayName = $_.DisplayName
                Mail = $_.mail
                Description = $_.Description
                DistinguishedName = $_.DistinguishedName
                Enabled = -not ($_.userAccountControl -band 2)
                ADUser = $_
            }
        }

        Write-Verbose "Found $($candidates.Count) candidate(s)"
        Write-Log -Message "Found $($candidates.Count) shared mailbox candidate(s)" `
            -Level INFO -Operation "Get-SharedMailboxCandidates" -Status "SUCCESS"

        return $candidates

    }
    catch {
        $errorMessage = $_.Exception.Message
        Write-Error "Failed to query candidates: $errorMessage"
        Write-Log -Message "Candidate query failed: $errorMessage" `
            -Level ERROR -Operation "Get-SharedMailboxCandidates" -Status "ERROR"
        return @()
    }
}

function _MapCustomAttributeToExtension {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$AttributeName
    )

    # Common mapping for custom attributes
    $mapping = @{
        "nethzTask" = "extensionAttribute1"
        "nethzRemark" = "extensionAttribute2"
        "nethzStatus" = "extensionAttribute3"
    }

    if ($mapping.ContainsKey($AttributeName)) {
        return $mapping[$AttributeName]
    }

    # If not in mapping, assume it's already an extensionAttribute name
    if ($AttributeName -like "extensionAttribute*") {
        return $AttributeName
    }

    Write-Warning "Unknown custom attribute '$AttributeName', using as-is"
    return $AttributeName
}
