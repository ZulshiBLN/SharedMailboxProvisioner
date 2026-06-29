<#
.SYNOPSIS
Validate domain exists in Exchange Online AcceptedDomains

.DESCRIPTION
Checks if an email domain is registered as an accepted domain in Exchange Online.
Used to verify that email addresses can be assigned to mailboxes.

Returns $true if domain is accepted, $false if not found or invalid.

Per ADR-006: Active Directory Integration & Candidate Selection
#>

function _ValidateDomainInExchangeOnline {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Domain,

        [Parameter(Mandatory = $false)]
        [object[]]$AcceptedDomains = $null
    )

    if ([string]::IsNullOrWhiteSpace($Domain)) {
        Write-Verbose "Domain validation failed: domain is empty or whitespace"
        return $false
    }

    Write-Verbose "Validating domain in Exchange Online: $Domain"

    try {
        # If AcceptedDomains not provided, query Exchange Online
        if ($null -eq $AcceptedDomains -or $AcceptedDomains.Count -eq 0) {
            Write-Verbose "Querying Exchange Online for AcceptedDomains"

            try {
                $AcceptedDomains = Get-AcceptedDomain -ErrorAction Stop | Select-Object -ExpandProperty DomainName
            }
            catch {
                Write-Verbose "Failed to query AcceptedDomains from Exchange Online: $($_.Exception.Message)"
                Write-Log -Message "Failed to query Exchange Online AcceptedDomains: $($_.Exception.Message)" `
                    -Level WARN -Operation "_ValidateDomainInExchangeOnline" -Status "EXO_QUERY_FAILED"
                return $false
            }

            if ($null -eq $AcceptedDomains -or $AcceptedDomains.Count -eq 0) {
                Write-Verbose "No AcceptedDomains found in Exchange Online"
                return $false
            }
        }

        # Check if domain exists in AcceptedDomains (case-insensitive)
        $found = $AcceptedDomains | Where-Object { $_ -eq $Domain } -ErrorAction SilentlyContinue

        if ($found) {
            Write-Verbose "Domain is accepted in Exchange Online: $Domain"
            return $true
        }

        Write-Verbose "Domain is NOT accepted in Exchange Online: $Domain"
        Write-Log -Message "Domain not in Exchange Online AcceptedDomains: $Domain" `
            -Level WARN -Operation "_ValidateDomainInExchangeOnline" -Status "DOMAIN_NOT_ACCEPTED"
        return $false

    }
    catch {
        $errorMessage = $_.Exception.Message
        Write-Error "Failed to validate domain: $errorMessage"
        Write-Log -Message "Domain validation error: $errorMessage" `
            -Level ERROR -Operation "_ValidateDomainInExchangeOnline" -Status "ERROR"
        return $false
    }
}
