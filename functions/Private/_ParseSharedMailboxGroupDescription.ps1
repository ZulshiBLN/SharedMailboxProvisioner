<#
.SYNOPSIS
Parse shared mailbox group description to extract metadata

.DESCRIPTION
Extracts email, role, and admin group information from ACL group description.
Expected format: "Permission group for shared mailbox {email}; {role}; {admin-group}"

Returns PSCustomObject with parsed values or $null if format invalid.

Per ADR-006: Active Directory Integration & Candidate Selection
#>

function _ParseSharedMailboxGroupDescription {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Description
    )

    if ([string]::IsNullOrWhiteSpace($Description)) {
        Write-Verbose "Group description parse failed: empty or whitespace"
        return $null
    }

    # Expected format:
    # "Permission group for shared mailbox user@ethz.ch; Owner; AdminGroup"
    # Pattern: ... for shared mailbox {email}; {role}; {admingroup}

    try {
        # Extract email (between "mailbox " and ";")
        $emailPattern = 'for shared mailbox\s+([^\s;]+)'
        $emailMatch = [regex]::Match($Description, $emailPattern)

        if (-not $emailMatch.Success) {
            Write-Verbose "Group description parse failed: no email found"
            return $null
        }

        $email = $emailMatch.Groups[1].Value.Trim()

        # Split by semicolon to get role and admin group
        $parts = $Description -split ';'

        if ($parts.Count -lt 3) {
            Write-Verbose "Group description parse failed: insufficient parts (need 3, got $($parts.Count))"
            return $null
        }

        $role = $parts[1].Trim()
        $adminGroup = $parts[2].Trim()

        # Validate extracted values
        if ([string]::IsNullOrWhiteSpace($email) -or
            [string]::IsNullOrWhiteSpace($role) -or
            [string]::IsNullOrWhiteSpace($adminGroup)) {
            Write-Verbose "Group description parse failed: empty values after extraction"
            return $null
        }

        Write-Verbose "Group description parsed: email=$email, role=$role, adminGroup=$adminGroup"

        return [PSCustomObject]@{
            Email = $email
            Role = $role
            AdminGroup = $adminGroup
            IsValid = $true
        }

    }
    catch {
        Write-Verbose "Group description parse failed with exception: $_"
        return $null
    }
}
