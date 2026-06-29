<#
.SYNOPSIS
Remove invalid characters from DisplayName for Exchange Online compatibility

.DESCRIPTION
Removes characters that are invalid in Exchange Online DisplayName.
Invalid characters: < > @ \ / : ; . , [ ] ( )
Also trims leading/trailing whitespace.

Returns cleaned DisplayName. Returns empty string if result would be empty.

Per ADR-006: Active Directory Integration & Candidate Selection
#>

function _SanitizeDisplayName {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$DisplayName
    )

    if ([string]::IsNullOrWhiteSpace($DisplayName)) {
        Write-Verbose "DisplayName sanitization: input empty or whitespace"
        return ''
    }

    # Characters invalid in Exchange Online DisplayName
    $invalidChars = @('<', '>', '@', '\', '/', ':', ';', '.', ',', '[', ']', '(', ')')

    $cleaned = $DisplayName

    # Remove each invalid character
    foreach ($char in $invalidChars) {
        $cleaned = $cleaned.Replace($char, '')
    }

    # Trim leading/trailing whitespace
    $cleaned = $cleaned.Trim()

    # Replace multiple consecutive spaces with single space
    $cleaned = $cleaned -replace '\s+', ' '

    if ([string]::IsNullOrWhiteSpace($cleaned)) {
        Write-Verbose "DisplayName sanitization: result empty after removing invalid chars"
        return ''
    }

    # Check final length (Exchange Online limit is 256 chars)
    if ($cleaned.Length -gt 256) {
        Write-Verbose "DisplayName sanitization: truncating to 256 chars (was $($cleaned.Length))"
        $cleaned = $cleaned.Substring(0, 256)
    }

    Write-Verbose "DisplayName sanitization: '$DisplayName' → '$cleaned'"
    return $cleaned
}
