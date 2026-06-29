<#
.SYNOPSIS
Validate DisplayName format for Exchange Online compatibility

.DESCRIPTION
Validates that DisplayName meets Exchange Online requirements.
Invalid characters: < > @ \ / : ; . , [ ] ( )
Also checks: not empty, no leading/trailing whitespace, max 256 chars.

Returns: bool ($true if valid, $false if invalid)
Does NOT modify the DisplayName - validation only.
Manual correction must be done in IAM system.

Per ADR-006: Active Directory Integration & Candidate Selection
#>

function _ValidateDisplayName {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$DisplayName
    )

    # Check: not empty or whitespace
    if ([string]::IsNullOrWhiteSpace($DisplayName)) {
        Write-Verbose "DisplayName validation failed: empty or whitespace"
        return $false
    }

    # Check: no leading/trailing whitespace
    if ($DisplayName -ne $DisplayName.Trim()) {
        Write-Verbose "DisplayName validation failed: has leading/trailing whitespace"
        return $false
    }

    # Check: length within limit
    if ($DisplayName.Length -gt 256) {
        Write-Verbose "DisplayName validation failed: exceeds 256 character limit (has $($DisplayName.Length))"
        return $false
    }

    # Characters invalid in Exchange Online DisplayName
    $invalidChars = @('<', '>', '@', '\', '/', ':', ';', '.', ',', '[', ']', '(', ')')

    # Check: no invalid characters
    foreach ($char in $invalidChars) {
        if ($DisplayName.Contains($char)) {
            Write-Verbose "DisplayName validation failed: contains invalid character '$char'"
            return $false
        }
    }

    Write-Verbose "DisplayName validation passed: '$DisplayName'"
    return $true
}
