<#
.SYNOPSIS
Check if email address exists in other AD user objects

.DESCRIPTION
Searches Active Directory for duplicate email addresses across all user accounts.
Checks both the primary mail attribute and ProxyAddresses for collisions.

Returns $true if email is duplicated, $false if unique (safe to use).
Excludes the current user object from search.

Per ADR-006: Active Directory Integration & Candidate Selection
#>

function _CheckForDuplicateEmails {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$EmailAddress,

        [Parameter(Mandatory = $false)]
        [string]$ExcludeUser = "",

        [Parameter(Mandatory = $false)]
        [string]$SearchBase = ""
    )

    if ([string]::IsNullOrWhiteSpace($EmailAddress)) {
        Write-Verbose "Duplicate check failed: email is empty or whitespace"
        return $false
    }

    Write-Verbose "Checking for duplicate email: $EmailAddress"

    try {
        # Prepare Get-ADObject parameters for efficient search
        # LDAPFilter (not Filter) is required here - Filter expects PowerShell expression
        # syntax (-eq, -like, ...), not a raw LDAP filter string.
        $getAdParams = @{
            LDAPFilter = "(|(mail=$EmailAddress)(proxyAddresses=*$EmailAddress*))"
            ErrorAction = 'Stop'
            Properties = @('mail', 'proxyAddresses', 'sAMAccountName')
        }

        if (-not [string]::IsNullOrWhiteSpace($SearchBase)) {
            $getAdParams['SearchBase'] = $SearchBase
        }

        # Search for users with this email
        $results = Get-ADObject @getAdParams

        if (-not $results) {
            Write-Verbose "No duplicates found for email: $EmailAddress"
            return $false
        }

        # Convert single result to array for consistent handling
        if ($results -isnot [System.Collections.ArrayList] -and $results -isnot [System.Array]) {
            $results = @($results)
        }

        # Filter out the current user (if specified)
        if (-not [string]::IsNullOrWhiteSpace($ExcludeUser)) {
            $results = $results | Where-Object { $_.sAMAccountName -ne $ExcludeUser }
        }

        # Check if duplicates remain after exclusion
        if ($results.Count -gt 0) {
            Write-Verbose "Duplicate found: email '$EmailAddress' exists in $($results.Count) other user(s)"
            Write-Log -Message "Duplicate email detected: $EmailAddress (found in $($results.Count) user(s))" `
                -Level WARN -Operation "_CheckForDuplicateEmails" -Status "DUPLICATE_FOUND"
            return $true
        }

        Write-Verbose "No duplicates found for email: $EmailAddress (after exclusion)"
        return $false

    }
    catch {
        $errorMessage = $_.Exception.Message
        Write-Error "Failed to check for duplicate emails: $errorMessage"
        Write-Log -Message "Duplicate email check failed: $errorMessage" `
            -Level ERROR -Operation "_CheckForDuplicateEmails" -Status "ERROR"
        return $false
    }
}
