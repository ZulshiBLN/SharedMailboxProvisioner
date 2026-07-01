<#
.SYNOPSIS
Get shared mailbox ACL group from Active Directory

.DESCRIPTION
Searches Active Directory for a group matching the shared mailbox naming convention.
Expected naming pattern: smbx_acl_{suffix} (derived from user's smbx_{suffix})

For user with SamAccountName "smbx_12345678", searches for group "smbx_acl_12345678"
Returns group object or $null if not found.

.PARAMETER SamAccountName
Shared mailbox user SAM account name (e.g., "smbx_12345678")
Group name derived: smbx_acl_{suffix from smbx_account}

.PARAMETER SearchBase
LDAP search base (e.g., "OU=Groups,DC=ethz,DC=ch")
If not provided, searches entire domain.

.EXAMPLE
$group = Get-SharedMailboxACLGroup -SamAccountName "smbx_12345678"
Returns the smbx_acl_12345678 group if found

.EXAMPLE
$group = Get-SharedMailboxACLGroup -SamAccountName "smbx_12345678" -SearchBase "OU=Groups,DC=ethz,DC=ch"
Searches only in specific OU

.NOTES
Per ADR-006: Active Directory Integration & Candidate Selection
Requires ActiveDirectory PowerShell module
Group must exist; no additional validation performed.
#>

function Get-SharedMailboxACLGroup {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$SamAccountName,

        [Parameter(Mandatory = $false)]
        [string]$SearchBase = ""
    )

    # Extract suffix from smbx_{suffix} format
    # Input: "smbx_12345678" -> suffix: "12345678" -> search: "smbx_acl_12345678"
    if (-not $SamAccountName.StartsWith("smbx_")) {
        Write-Error "SamAccountName must start with 'smbx_' (got: $SamAccountName)"
        Write-Log -Message "Invalid SamAccountName format: $SamAccountName (must be smbx_*)" `
            -Level ERROR -Operation "Get-SharedMailboxACLGroup" -Status "INVALID_FORMAT"
        return $null
    }

    $suffix = $SamAccountName.Substring(5)  # Remove "smbx_" prefix
    $expectedGroupName = "smbx_acl_$suffix"

    Write-Verbose "Searching for ACL group: $expectedGroupName (from user: $SamAccountName)"

    try {
        # Build filter for efficient search in large AD
        # Using Get-ADObject with objectClass filter is faster than Get-ADGroup for large directories
        $ldapFilter = "(&(sAMAccountName=$expectedGroupName)(objectClass=group))"
        Write-Verbose "LDAP filter: $ldapFilter"

        # Prepare Get-ADObject parameters (more efficient for large ADs)
        # LDAPFilter (not Filter) is required here - Filter expects PowerShell expression
        # syntax (-eq, -like, ...), not a raw LDAP filter string.
        $getAdParams = @{
            LDAPFilter = $ldapFilter
            ErrorAction = 'Stop'
            Properties = @('mail', 'Description', 'GroupScope')
        }

        if (-not [string]::IsNullOrWhiteSpace($SearchBase)) {
            $getAdParams['SearchBase'] = $SearchBase
        }

        # Search for group (using Get-ADObject for better performance on large directories)
        $adGroup = Get-ADObject @getAdParams

        if (-not $adGroup) {
            Write-Verbose "ACL group not found: $expectedGroupName"
            Write-Log -Message "ACL group not found for user $SamAccountName (expected: $expectedGroupName)" `
                -Level WARN -Operation "Get-SharedMailboxACLGroup" -Status "NOT_FOUND"
            return $null
        }

        Write-Verbose "ACL group found: $($adGroup.Name)"

        # Validate group attributes
        $validationErrors = @()

        # Check 1: Group must be Universal Security Group
        if ($adGroup.GroupScope -ne "Universal") {
            $validationErrors += "Group scope is '$($adGroup.GroupScope)' (required: Universal)"
        }

        # Check 2: Group must have email attribute
        if ([string]::IsNullOrWhiteSpace($adGroup.mail)) {
            $validationErrors += "Group has no email (mail) attribute"
        }

        # Check 3: Description must start with "Permission group for shared mailbox"
        if ([string]::IsNullOrWhiteSpace($adGroup.Description)) {
            $validationErrors += "Group has no description"
        }
        elseif (-not $adGroup.Description.StartsWith("Permission group for shared mailbox")) {
            $validationErrors += "Group description does not start with 'Permission group for shared mailbox'"
        }

        # If validation failed
        if ($validationErrors.Count -gt 0) {
            $errorMessage = $validationErrors -join "; "
            Write-Verbose "ACL group validation failed: $errorMessage"
            Write-Log -Message "ACL group validation failed for $($adGroup.Name): $errorMessage" `
                -Level WARN -Operation "Get-SharedMailboxACLGroup" -Status "VALIDATION_FAILED"
            return $null
        }

        Write-Verbose "ACL group validation passed: $($adGroup.Name)"
        Write-Log -Message "ACL group found and validated: $($adGroup.Name)" `
            -Level INFO -Operation "Get-SharedMailboxACLGroup" -Status "SUCCESS"

        # Return group object
        return [PSCustomObject]@{
            ADGroup = $adGroup
            Name = $adGroup.Name
            SamAccountName = $adGroup.SamAccountName
            Mail = $adGroup.mail
            GroupScope = $adGroup.GroupScope
            Description = $adGroup.Description
            IsValid = $true
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
