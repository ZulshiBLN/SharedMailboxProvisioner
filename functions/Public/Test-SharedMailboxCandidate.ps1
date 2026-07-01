<#
.SYNOPSIS
Comprehensive validation of user account for shared mailbox provisioning

.DESCRIPTION
Performs all validation checks to determine if an AD user can be provisioned as a shared mailbox.
Combines Tier 1, 2, and 3 validation checks into a single comprehensive validation.

Validation includes:
- Email format (RFC 5321)
- DisplayName and SamAccountName validity
- Email duplication detection
- Domain acceptance in Exchange Online
- ProxyAddresses structure
- TargetAddress check

Returns a PSCustomObject with SamAccountName, IsValid, ValidationErrors, and
ValidationChecks (per-check breakdown).

.PARAMETER ADUser
AD user object to validate. Must expose mail, DisplayName, sAMAccountName,
TargetAddress, and proxyAddresses properties (as returned by Get-ADUser -Properties).

.PARAMETER AcceptedDomains
Domains to accept for the user's mail address. If not provided, domain
acceptance is checked against Exchange Online's AcceptedDomains list instead.

.PARAMETER ValidationAttribute
Reserved for a not-yet-implemented feature (writing the validation result back
to this AD attribute name). Currently accepted but has no effect - see
docs/Pre-Release/COMPLIANCE-AUDIT-PHASE-PRERELEASE.md Known Gaps.

.EXAMPLE
Test-SharedMailboxCandidate -ADUser $aduser
Validates a single AD user object using Exchange Online's AcceptedDomains list.

.EXAMPLE
Test-SharedMailboxCandidate -ADUser $aduser -AcceptedDomains @("ethz.ch", "ethz.onmicrosoft.com")
Validates using an explicit accepted-domains list instead of querying Exchange Online.

.NOTES
Per ADR-006: Active Directory Integration & Candidate Selection
Combines Tier 1 (_ValidateEmailFormat, _ValidateDisplayName), Tier 2 (group
validation is separate, see Get-SharedMailboxACLGroup), and Tier 3
(_ValidateDomainInExchangeOnline, _CheckForDuplicateEmails) checks.
#>

function Test-SharedMailboxCandidate {
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', 'ValidationAttribute', Justification = 'Accepted but not yet wired to an AD attribute write - see COMPLIANCE-AUDIT-PHASE-PRERELEASE.md Known Gaps')]
    param(
        [Parameter(Mandatory = $true)]
        $ADUser,

        [Parameter(Mandatory = $false)]
        [string[]]$AcceptedDomains = @(),

        [Parameter(Mandatory = $false)]
        [string]$ValidationAttribute = "nethzTask"
    )

    $validationErrors = @()
    $validationChecks = @{}

    # Check 1: User object exists and has required attributes
    if (-not $ADUser) {
        Write-Verbose "Validation failed: user object is null"
        return $false
    }

    if ([string]::IsNullOrWhiteSpace($ADUser.mail)) {
        $validationErrors += "Mail attribute is missing or empty"
        $validationChecks["MailAttributeExists"] = $false
    }
    else {
        $validationChecks["MailAttributeExists"] = $true
    }

    # Check 2: Email format validation (Tier 1)
    if ($validationChecks["MailAttributeExists"]) {
        $emailValid = _ValidateEmailFormat -EmailAddress $ADUser.mail
        $validationChecks["MailFormatValid"] = $emailValid

        if (-not $emailValid) {
            $validationErrors += "Mail address format invalid: $($ADUser.mail)"
        }
    }
    else {
        $validationChecks["MailFormatValid"] = $false
    }

    # Check 3: Duplicate email detection (Tier 3)
    if ($validationChecks["MailAttributeExists"] -and $validationChecks["MailFormatValid"]) {
        $hasDuplicate = _CheckForDuplicateEmails -EmailAddress $ADUser.mail -ExcludeUser $ADUser.sAMAccountName
        $validationChecks["MailNotDuplicated"] = -not $hasDuplicate

        if ($hasDuplicate) {
            $validationErrors += "Email already exists in other user account(s)"
        }
    }
    else {
        $validationChecks["MailNotDuplicated"] = $false
    }

    # Check 4: DisplayName validation (Tier 1)
    $displayNameValid = _ValidateDisplayName -DisplayName $ADUser.DisplayName
    $validationChecks["DisplayNameValid"] = $displayNameValid

    if (-not $displayNameValid) {
        $validationErrors += "DisplayName contains invalid characters or is empty"
    }

    # Check 5: SamAccountName validation
    if (-not [string]::IsNullOrWhiteSpace($ADUser.sAMAccountName)) {
        $samAccountValid = $ADUser.sAMAccountName -match '^[a-zA-Z0-9._-]+$'
        $validationChecks["SamAccountNameValid"] = $samAccountValid

        if (-not $samAccountValid) {
            $validationErrors += "SamAccountName contains invalid characters"
        }
    }
    else {
        $validationErrors += "SamAccountName is missing or empty"
        $validationChecks["SamAccountNameValid"] = $false
    }

    # Check 6: TargetAddress must be empty
    if (-not [string]::IsNullOrWhiteSpace($ADUser.TargetAddress)) {
        $validationErrors += "TargetAddress must be empty (reserved for Remote Mailbox)"
        $validationChecks["TargetAddressEmpty"] = $false
    }
    else {
        $validationChecks["TargetAddressEmpty"] = $true
    }

    # Check 7: ProxyAddresses validation
    if ($ADUser.proxyAddresses -and $ADUser.proxyAddresses.Count -gt 0) {
        $validationChecks["ProxyAddressesExist"] = $true

        # Check for required M365 address
        $hasM365 = $ADUser.proxyAddresses | Where-Object { $_ -like "*@ethz.onmicrosoft.com" }
        $validationChecks["M365AddressPresent"] = $null -ne $hasM365

        if ($null -eq $hasM365) {
            $validationErrors += "ProxyAddresses missing M365 address (@ethz.onmicrosoft.com)"
        }
    }
    else {
        $validationErrors += "ProxyAddresses is empty or missing"
        $validationChecks["ProxyAddressesExist"] = $false
        $validationChecks["M365AddressPresent"] = $false
    }

    # Check 8: Domain validation (Tier 3)
    if ($validationChecks["MailAttributeExists"] -and $validationChecks["MailFormatValid"]) {
        # Extract domain from email
        $emailParts = $ADUser.mail -split "@"
        if ($emailParts.Count -eq 2) {
            $domain = $emailParts[1]

            # If AcceptedDomains provided, use them; otherwise will query Exchange Online
            $domainValid = _ValidateDomainInExchangeOnline -Domain $domain -AcceptedDomains $AcceptedDomains
            $validationChecks["DomainAccepted"] = $domainValid

            if (-not $domainValid) {
                $validationErrors += "Email domain not in Exchange Online AcceptedDomains: $domain"
            }
        }
        else {
            $validationChecks["DomainAccepted"] = $false
        }
    }
    else {
        $validationChecks["DomainAccepted"] = $false
    }

    # Determine overall validation result
    $isValid = $validationErrors.Count -eq 0

    # Log result
    if ($isValid) {
        Write-Verbose "Validation passed: $($ADUser.sAMAccountName)"
        Write-Log -Message "Candidate validation passed: $($ADUser.sAMAccountName) - $($ADUser.mail)" `
            -Level INFO -Operation "_TestSharedMailboxCandidate" -Status "VALID"
    }
    else {
        Write-Verbose "Validation failed for $($ADUser.sAMAccountName): $($validationErrors -join '; ')"
        Write-Log -Message "Candidate validation failed for $($ADUser.sAMAccountName): $($validationErrors -join '; ')" `
            -Level WARN -Operation "_TestSharedMailboxCandidate" -Status "INVALID"
    }

    return [PSCustomObject]@{
        SamAccountName = $ADUser.sAMAccountName
        IsValid = $isValid
        ValidationErrors = $validationErrors
        ValidationChecks = $validationChecks
    }
}
