<#
.SYNOPSIS
Get and validate shared mailbox ACL group from Active Directory

.DESCRIPTION
Searches Active Directory for a group matching the shared mailbox naming convention.
Expected naming pattern: SG-Smbx-{email-part} (e.g., SG-Smbx-User12345678)

Validates the group using _ValidateSharedMailboxGroup before returning.
Returns group object or $null if not found/invalid.

.PARAMETER SearchBase
LDAP search base (e.g., "OU=Groups,DC=ethz,DC=ch")
If not provided, searches entire domain.

.PARAMETER NamingPattern
Shared mailbox group naming pattern (default: "SG-Smbx-*")
Used for LDAP filter construction.

.PARAMETER ValidationAttribute
AD attribute for validation results (default: "nethzTask")
Results written here if group found.

.EXAMPLE
$group = Get-SharedMailboxACLGroup -SamAccountName "User12345678"
Returns the SG-Smbx-User12345678 group if found and valid

.EXAMPLE
$group = Get-SharedMailboxACLGroup -SamAccountName "Test" -SearchBase "OU=Groups,DC=ethz,DC=ch"
Searches only in specific OU

.NOTES
Per ADR-006: Active Directory Integration & Candidate Selection
Requires ActiveDirectory PowerShell module

.PARAMETER SamAccountName
User SAM account name (without "SG-Smbx-" prefix)
Full group name searched: SG-Smbx-{SamAccountName}
#>

function Get-SharedMailboxACLGroup {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$SamAccountName,

        [Parameter(Mandatory = $false)]
        [string]$SearchBase = "",

        [Parameter(Mandatory = $false)]
        [string]$NamingPattern = "SG-Smbx-*",

        [Parameter(Mandatory = $false)]
        [string]$ValidationAttribute = "nethzTask"
    )

    # Construct expected group name
    $expectedGroupName = "SG-Smbx-$SamAccountName"

    Write-Verbose "Searching for ACL group: $expectedGroupName"

    try {
        # Build LDAP filter
        $ldapFilter = "(name=$expectedGroupName)"
        Write-Verbose "LDAP filter: $ldapFilter"

        # Prepare Get-ADGroup parameters
        $getAdParams = @{
            Filter = $ldapFilter
            ErrorAction = 'Stop'
        }

        if (-not [string]::IsNullOrWhiteSpace($SearchBase)) {
            $getAdParams['SearchBase'] = $SearchBase
        }

        # Search for group
        $adGroup = Get-ADGroup @getAdParams -Properties mail, Description

        if (-not $adGroup) {
            Write-Verbose "ACL group not found: $expectedGroupName"
            Write-Log -Message "ACL group not found for user $SamAccountName (expected: $expectedGroupName)" `
                -Level WARN -Operation "Get-SharedMailboxACLGroup" -Status "NOT_FOUND"
            return $null
        }

        Write-Verbose "ACL group found: $($adGroup.Name)"

        # Validate the group
        $validation = _ValidateSharedMailboxGroup -ADGroup $adGroup

        if (-not $validation.IsValid) {
            Write-Verbose "ACL group validation failed: $($validation.ValidationErrors -join '; ')"
            Write-Log -Message "ACL group validation failed for $($adGroup.Name): $($validation.ValidationErrors -join '; ')" `
                -Level WARN -Operation "Get-SharedMailboxACLGroup" -Status "VALIDATION_FAILED"
            return $null
        }

        Write-Verbose "ACL group validation passed: $($adGroup.Name)"
        Write-Log -Message "ACL group found and validated: $($adGroup.Name)" `
            -Level INFO -Operation "Get-SharedMailboxACLGroup" -Status "SUCCESS"

        # Return group with validation metadata
        return [PSCustomObject]@{
            ADGroup = $adGroup
            Name = $adGroup.Name
            Mail = $adGroup.mail
            IsValid = $validation.IsValid
            ParsedMetadata = $validation.ParsedMetadata
            ValidationErrors = $validation.ValidationErrors
        }

    }
    catch {
        $errorMessage = $_.Exception.Message
        Write-Error "Failed to retrieve ACL group $expectedGroupName : $errorMessage"
        Write-Log -Message "Failed to retrieve ACL group: $errorMessage" `
            -Level ERROR -Operation "Get-SharedMailboxACLGroup" -Status "ERROR"
        return $null
    }
}

Export-ModuleMember -Function Get-SharedMailboxACLGroup
