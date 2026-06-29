<#
.SYNOPSIS
Unit tests for _ValidateDomainInExchangeOnline function
#>

# Import function
$projectRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$functionPath = Join-Path $projectRoot "functions" "Private" "_ValidateDomainInExchangeOnline.ps1"
. $functionPath

Describe "ValidateDomainInExchangeOnline" {

    Context "Accepted domains validation" {
        It "Should return true for accepted domain" {
            $acceptedDomains = @("ethz.ch", "ethz.onmicrosoft.com", "ethz.com")
            $result = _ValidateDomainInExchangeOnline -Domain "ethz.ch" -AcceptedDomains $acceptedDomains
            $result | Should -Be $true
        }

        It "Should return true for M365 domain" {
            $acceptedDomains = @("ethz.ch", "ethz.onmicrosoft.com", "ethz.com")
            $result = _ValidateDomainInExchangeOnline -Domain "ethz.onmicrosoft.com" -AcceptedDomains $acceptedDomains
            $result | Should -Be $true
        }

        It "Should return false for non-accepted domain" {
            $acceptedDomains = @("ethz.ch", "ethz.onmicrosoft.com")
            $result = _ValidateDomainInExchangeOnline -Domain "invalid.ch" -AcceptedDomains $acceptedDomains
            $result | Should -Be $false
        }

        It "Should handle single domain in array" {
            $acceptedDomains = @("ethz.ch")
            $result = _ValidateDomainInExchangeOnline -Domain "ethz.ch" -AcceptedDomains $acceptedDomains
            $result | Should -Be $true
        }

        It "Should handle multiple domains" {
            $acceptedDomains = @("ethz.ch", "ethz.onmicrosoft.com", "ethz.com", "mail.ethz.ch")
            $result = _ValidateDomainInExchangeOnline -Domain "mail.ethz.ch" -AcceptedDomains $acceptedDomains
            $result | Should -Be $true
        }
    }

    Context "Input validation" {
        It "Should return false for empty domain" {
            $acceptedDomains = @("ethz.ch")
            $result = _ValidateDomainInExchangeOnline -Domain "" -AcceptedDomains $acceptedDomains
            $result | Should -Be $false
        }

        It "Should return false for whitespace-only domain" {
            $acceptedDomains = @("ethz.ch")
            $result = _ValidateDomainInExchangeOnline -Domain "   " -AcceptedDomains $acceptedDomains
            $result | Should -Be $false
        }

        It "Should return false for null domain" {
            $acceptedDomains = @("ethz.ch")
            $result = _ValidateDomainInExchangeOnline -Domain $null -AcceptedDomains $acceptedDomains
            $result | Should -Be $false
        }
    }

    Context "Exchange Online query" {
        It "Should query Exchange Online when AcceptedDomains not provided" {
            Mock Get-AcceptedDomain {
                return @(
                    [PSCustomObject]@{ DomainName = "ethz.ch" },
                    [PSCustomObject]@{ DomainName = "ethz.onmicrosoft.com" }
                )
            }

            $result = _ValidateDomainInExchangeOnline -Domain "ethz.ch"
            $result | Should -Be $true
            Assert-MockCalled Get-AcceptedDomain -Times 1
        }

        It "Should handle empty AcceptedDomains from EXO query" {
            Mock Get-AcceptedDomain {
                return @()
            }

            $result = _ValidateDomainInExchangeOnline -Domain "ethz.ch"
            $result | Should -Be $false
        }

        It "Should return false when EXO query fails" {
            Mock Get-AcceptedDomain {
                throw [System.Exception]"Connection failed"
            }

            $result = _ValidateDomainInExchangeOnline -Domain "ethz.ch"
            $result | Should -Be $false
        }
    }

    Context "Case sensitivity" {
        It "Should match domain case-insensitively" {
            $acceptedDomains = @("ethz.ch", "ETHZ.ONMICROSOFT.COM")

            $result1 = _ValidateDomainInExchangeOnline -Domain "ETHZ.CH" -AcceptedDomains $acceptedDomains
            $result2 = _ValidateDomainInExchangeOnline -Domain "ethz.onmicrosoft.com" -AcceptedDomains $acceptedDomains

            $result1 | Should -Be $true
            $result2 | Should -Be $true
        }
    }

    Context "Domain format validation" {
        It "Should accept standard domain format" {
            $acceptedDomains = @("ethz.ch")
            $result = _ValidateDomainInExchangeOnline -Domain "ethz.ch" -AcceptedDomains $acceptedDomains
            $result | Should -Be $true
        }

        It "Should accept subdomain format" {
            $acceptedDomains = @("mail.ethz.ch")
            $result = _ValidateDomainInExchangeOnline -Domain "mail.ethz.ch" -AcceptedDomains $acceptedDomains
            $result | Should -Be $true
        }

        It "Should accept M365 domain format" {
            $acceptedDomains = @("ethz.onmicrosoft.com")
            $result = _ValidateDomainInExchangeOnline -Domain "ethz.onmicrosoft.com" -AcceptedDomains $acceptedDomains
            $result | Should -Be $true
        }
    }

    Context "Error handling" {
        It "Should return false on generic error" {
            Mock Get-AcceptedDomain {
                throw [System.Exception]"Unexpected error"
            }

            $result = _ValidateDomainInExchangeOnline -Domain "ethz.ch"
            $result | Should -Be $false
        }

        It "Should handle null AcceptedDomains parameter" {
            $result = _ValidateDomainInExchangeOnline -Domain "ethz.ch" -AcceptedDomains $null
            # Should attempt EXO query or return false
            $result | Should -Be $false
        }

        It "Should handle empty AcceptedDomains array" {
            $result = _ValidateDomainInExchangeOnline -Domain "ethz.ch" -AcceptedDomains @()
            # Should attempt EXO query
            $result | Should -Be $false
        }
    }
}
