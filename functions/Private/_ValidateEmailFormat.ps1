<#
.SYNOPSIS
Validate email address format against RFC 5321 standard

.DESCRIPTION
Checks if an email address matches RFC 5321 format requirements.
Used as part of SharedMailbox candidate validation process.

Per ADR-006: Active Directory Integration & Candidate Selection
#>

function _ValidateEmailFormat {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$EmailAddress
    )

    # RFC 5321 email validation pattern
    # Basic pattern: local@domain
    # Local part: alphanumeric, dots, hyphens, underscores
    # Domain: alphanumeric, dots, hyphens with valid TLD
    $pattern = '^[a-zA-Z0-9._-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$'

    # Check for obvious issues first (faster than regex)
    if ([string]::IsNullOrWhiteSpace($EmailAddress)) {
        Write-Verbose "Email validation failed: empty or whitespace"
        return $false
    }

    if ($EmailAddress.Length -gt 254) {
        Write-Verbose "Email validation failed: exceeds 254 character limit"
        return $false
    }

    if ($EmailAddress -notmatch '@') {
        Write-Verbose "Email validation failed: missing @ symbol"
        return $false
    }

    # Split and validate local and domain parts
    try {
        $parts = $EmailAddress -split '@'
        if ($parts.Count -ne 2) {
            Write-Verbose "Email validation failed: multiple @ symbols"
            return $false
        }

        $localPart = $parts[0]
        $domainPart = $parts[1]

        # Validate local part (before @)
        if ([string]::IsNullOrWhiteSpace($localPart)) {
            Write-Verbose "Email validation failed: empty local part"
            return $false
        }

        if ($localPart.Length -gt 64) {
            Write-Verbose "Email validation failed: local part exceeds 64 characters"
            return $false
        }

        if ($localPart -match '^\.') {
            Write-Verbose "Email validation failed: local part starts with dot"
            return $false
        }

        if ($localPart -match '\.$') {
            Write-Verbose "Email validation failed: local part ends with dot"
            return $false
        }

        if ($localPart -match '\.\.') {
            Write-Verbose "Email validation failed: local part contains consecutive dots"
            return $false
        }

        # Validate domain part (after @)
        if ([string]::IsNullOrWhiteSpace($domainPart)) {
            Write-Verbose "Email validation failed: empty domain part"
            return $false
        }

        if ($domainPart.Length -gt 255) {
            Write-Verbose "Email validation failed: domain part exceeds 255 characters"
            return $false
        }

        if ($domainPart -notmatch '\.' -and $domainPart -ne 'localhost') {
            Write-Verbose "Email validation failed: domain has no TLD"
            return $false
        }

        # Full pattern match
        if ($EmailAddress -notmatch $pattern) {
            Write-Verbose "Email validation failed: pattern mismatch"
            return $false
        }

        Write-Verbose "Email validation passed: $EmailAddress"
        return $true
    }
    catch {
        Write-Verbose "Email validation failed with exception: $_"
        return $false
    }
}
