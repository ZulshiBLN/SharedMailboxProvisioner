<#
.SYNOPSIS
Validate shared mailbox ACL group structure and metadata

.DESCRIPTION
Validates that an AD group is suitable for use as shared mailbox ACL group.
Checks: group type, mail attribute, description format, parsed metadata.

Returns PSCustomObject with validation results: IsValid, ValidationErrors, ParsedMetadata.

Per ADR-006: Active Directory Integration & Candidate Selection
#>

function _ValidateSharedMailboxGroup {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        $ADGroup
    )

    $validationErrors = @()
    $parsedMetadata = $null

    # Check: Group is not null
    if (-not $ADGroup) {
        Write-Verbose "Group validation failed: group is null"
        return [PSCustomObject]@{
            IsValid = $false
            ValidationErrors = @("Group object is null")
            ParsedMetadata = $null
        }
    }

    # Check: Group has ObjectClass "group"
    if ($ADGroup.ObjectClass -ne "group") {
        $validationErrors += "Object is not a group (ObjectClass: $($ADGroup.ObjectClass))"
    }

    # Check: Group has mail attribute
    if ([string]::IsNullOrWhiteSpace($ADGroup.mail)) {
        $validationErrors += "Group has no mail attribute"
    }

    # Check: Group has description
    if ([string]::IsNullOrWhiteSpace($ADGroup.Description)) {
        $validationErrors += "Group has no description"
    }
    else {
        # Try to parse description
        $parsed = _ParseSharedMailboxGroupDescription -Description $ADGroup.Description
        if (-not $parsed) {
            $validationErrors += "Group description format invalid (expected: 'Permission group for shared mailbox {email}; {role}; {admin-group}')"
        }
        else {
            $parsedMetadata = $parsed
        }
    }

    # Determine overall validity
    $isValid = $validationErrors.Count -eq 0

    Write-Verbose "Group validation result: IsValid=$isValid, Errors=$($validationErrors.Count), Group=$($ADGroup.Name)"

    return [PSCustomObject]@{
        IsValid = $isValid
        ValidationErrors = $validationErrors
        ParsedMetadata = $parsedMetadata
    }
}
