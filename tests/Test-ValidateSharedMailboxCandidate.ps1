<#
.SYNOPSIS
Unit tests for Test-SharedMailboxCandidate function
#>

# Import functions
$projectRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$functionPath1 = Join-Path $projectRoot "functions" "Private" "_ValidateEmailFormat.ps1"
$functionPath2 = Join-Path $projectRoot "functions" "Private" "_ValidateDisplayName.ps1"
$functionPath3 = Join-Path $projectRoot "functions" "Private" "_CheckForDuplicateEmails.ps1"
$functionPath4 = Join-Path $projectRoot "functions" "Private" "_ValidateDomainInExchangeOnline.ps1"
$functionPath5 = Join-Path $projectRoot "functions" "Private" "Test-SharedMailboxCandidate.ps1"

. $functionPath1
. $functionPath2
. $functionPath3
. $functionPath4
. $functionPath5

Describe "ValidateSharedMailboxCandidate" {

    Context "Valid candidate" {
        It "Should return IsValid=true for valid user" {
            $mockUser = [PSCustomObject]@{
                sAMAccountName = "user123"
                mail = "user@ethz.ch"
                DisplayName = "Test User"
                proxyAddresses = @("user@ethz.ch", "SMTP:user@ethz.onmicrosoft.com")
                TargetAddress = ""
            }

            Mock _ValidateEmailFormat { return $true }
            Mock _ValidateDisplayName { return $true }
            Mock _CheckForDuplicateEmails { return $false }
            Mock _ValidateDomainInExchangeOnline { return $true }

            $result = Test-SharedMailboxCandidate -ADUser $mockUser
            $result.IsValid | Should -Be $true
            $result.ValidationErrors.Count | Should -Be 0
        }

        It "Should return all validation checks passing" {
            $mockUser = [PSCustomObject]@{
                sAMAccountName = "user123"
                mail = "user@ethz.ch"
                DisplayName = "Test User"
                proxyAddresses = @("user@ethz.ch", "SMTP:user@ethz.onmicrosoft.com")
                TargetAddress = ""
            }

            Mock _ValidateEmailFormat { return $true }
            Mock _ValidateDisplayName { return $true }
            Mock _CheckForDuplicateEmails { return $false }
            Mock _ValidateDomainInExchangeOnline { return $true }

            $result = Test-SharedMailboxCandidate -ADUser $mockUser
            $result.ValidationChecks["MailAttributeExists"] | Should -Be $true
            $result.ValidationChecks["MailFormatValid"] | Should -Be $true
            $result.ValidationChecks["MailNotDuplicated"] | Should -Be $true
            $result.ValidationChecks["DisplayNameValid"] | Should -Be $true
            $result.ValidationChecks["SamAccountNameValid"] | Should -Be $true
            $result.ValidationChecks["TargetAddressEmpty"] | Should -Be $true
            $result.ValidationChecks["ProxyAddressesExist"] | Should -Be $true
            $result.ValidationChecks["M365AddressPresent"] | Should -Be $true
            $result.ValidationChecks["DomainAccepted"] | Should -Be $true
        }
    }

    Context "Mail attribute validation" {
        It "Should fail when mail is missing" {
            $mockUser = [PSCustomObject]@{
                sAMAccountName = "user123"
                mail = ""
                DisplayName = "Test User"
                proxyAddresses = @()
                TargetAddress = ""
            }

            Mock _ValidateDisplayName { return $true }

            $result = Test-SharedMailboxCandidate -ADUser $mockUser
            $result.IsValid | Should -Be $false
            $result.ValidationErrors | Should -Contain "Mail attribute is missing or empty"
        }

        It "Should fail when email format invalid" {
            $mockUser = [PSCustomObject]@{
                sAMAccountName = "user123"
                mail = "invalid-email"
                DisplayName = "Test User"
                proxyAddresses = @()
                TargetAddress = ""
            }

            Mock _ValidateEmailFormat { return $false }
            Mock _ValidateDisplayName { return $true }

            $result = Test-SharedMailboxCandidate -ADUser $mockUser
            $result.IsValid | Should -Be $false
            $result.ValidationErrors | Should -Contain "Mail address format invalid: invalid-email"
        }

        It "Should fail when email is duplicated" {
            $mockUser = [PSCustomObject]@{
                sAMAccountName = "user123"
                mail = "user@ethz.ch"
                DisplayName = "Test User"
                proxyAddresses = @("user@ethz.ch")
                TargetAddress = ""
            }

            Mock _ValidateEmailFormat { return $true }
            Mock _ValidateDisplayName { return $true }
            Mock _CheckForDuplicateEmails { return $true }

            $result = Test-SharedMailboxCandidate -ADUser $mockUser
            $result.IsValid | Should -Be $false
            $result.ValidationErrors | Should -Contain "Email already exists in other user account(s)"
        }
    }

    Context "DisplayName validation" {
        It "Should fail when DisplayName invalid" {
            $mockUser = [PSCustomObject]@{
                sAMAccountName = "user123"
                mail = "user@ethz.ch"
                DisplayName = "Test<User>"
                proxyAddresses = @("user@ethz.ch", "SMTP:user@ethz.onmicrosoft.com")
                TargetAddress = ""
            }

            Mock _ValidateEmailFormat { return $true }
            Mock _ValidateDisplayName { return $false }
            Mock _CheckForDuplicateEmails { return $false }
            Mock _ValidateDomainInExchangeOnline { return $true }

            $result = Test-SharedMailboxCandidate -ADUser $mockUser
            $result.IsValid | Should -Be $false
            $result.ValidationErrors | Should -Contain "DisplayName contains invalid characters or is empty"
        }
    }

    Context "SamAccountName validation" {
        It "Should fail when SamAccountName contains invalid characters" {
            $mockUser = [PSCustomObject]@{
                sAMAccountName = "user@#$%"
                mail = "user@ethz.ch"
                DisplayName = "Test User"
                proxyAddresses = @("user@ethz.ch")
                TargetAddress = ""
            }

            Mock _ValidateEmailFormat { return $true }
            Mock _ValidateDisplayName { return $true }
            Mock _CheckForDuplicateEmails { return $false }
            Mock _ValidateDomainInExchangeOnline { return $true }

            $result = Test-SharedMailboxCandidate -ADUser $mockUser
            $result.IsValid | Should -Be $false
            $result.ValidationErrors | Should -Contain "SamAccountName contains invalid characters"
        }

        It "Should fail when SamAccountName is empty" {
            $mockUser = [PSCustomObject]@{
                sAMAccountName = ""
                mail = "user@ethz.ch"
                DisplayName = "Test User"
                proxyAddresses = @("user@ethz.ch")
                TargetAddress = ""
            }

            Mock _ValidateEmailFormat { return $true }
            Mock _ValidateDisplayName { return $true }

            $result = Test-SharedMailboxCandidate -ADUser $mockUser
            $result.IsValid | Should -Be $false
            $result.ValidationErrors | Should -Contain "SamAccountName is missing or empty"
        }
    }

    Context "TargetAddress validation" {
        It "Should fail when TargetAddress is not empty" {
            $mockUser = [PSCustomObject]@{
                sAMAccountName = "user123"
                mail = "user@ethz.ch"
                DisplayName = "Test User"
                proxyAddresses = @("user@ethz.ch")
                TargetAddress = "user@ethz.mail.onmicrosoft.com"
            }

            Mock _ValidateEmailFormat { return $true }
            Mock _ValidateDisplayName { return $true }
            Mock _CheckForDuplicateEmails { return $false }
            Mock _ValidateDomainInExchangeOnline { return $true }

            $result = Test-SharedMailboxCandidate -ADUser $mockUser
            $result.IsValid | Should -Be $false
            $result.ValidationErrors | Should -Contain "TargetAddress must be empty (reserved for Remote Mailbox)"
        }
    }

    Context "ProxyAddresses validation" {
        It "Should fail when ProxyAddresses missing" {
            $mockUser = [PSCustomObject]@{
                sAMAccountName = "user123"
                mail = "user@ethz.ch"
                DisplayName = "Test User"
                proxyAddresses = @()
                TargetAddress = ""
            }

            Mock _ValidateEmailFormat { return $true }
            Mock _ValidateDisplayName { return $true }
            Mock _CheckForDuplicateEmails { return $false }
            Mock _ValidateDomainInExchangeOnline { return $true }

            $result = Test-SharedMailboxCandidate -ADUser $mockUser
            $result.IsValid | Should -Be $false
            $result.ValidationErrors | Should -Contain "ProxyAddresses is empty or missing"
        }

        It "Should fail when M365 address missing" {
            $mockUser = [PSCustomObject]@{
                sAMAccountName = "user123"
                mail = "user@ethz.ch"
                DisplayName = "Test User"
                proxyAddresses = @("user@ethz.ch")
                TargetAddress = ""
            }

            Mock _ValidateEmailFormat { return $true }
            Mock _ValidateDisplayName { return $true }
            Mock _CheckForDuplicateEmails { return $false }
            Mock _ValidateDomainInExchangeOnline { return $true }

            $result = Test-SharedMailboxCandidate -ADUser $mockUser
            $result.IsValid | Should -Be $false
            $result.ValidationErrors | Should -Contain "ProxyAddresses missing M365 address (@ethz.onmicrosoft.com)"
        }
    }

    Context "Domain validation" {
        It "Should fail when domain not accepted" {
            $mockUser = [PSCustomObject]@{
                sAMAccountName = "user123"
                mail = "user@invalid.ch"
                DisplayName = "Test User"
                proxyAddresses = @("user@invalid.ch", "SMTP:user@ethz.onmicrosoft.com")
                TargetAddress = ""
            }

            Mock _ValidateEmailFormat { return $true }
            Mock _ValidateDisplayName { return $true }
            Mock _CheckForDuplicateEmails { return $false }
            Mock _ValidateDomainInExchangeOnline { return $false }

            $result = Test-SharedMailboxCandidate -ADUser $mockUser
            $result.IsValid | Should -Be $false
            $result.ValidationErrors | Should -Contain "Email domain not in Exchange Online AcceptedDomains: invalid.ch"
        }
    }

    Context "Return object" {
        It "Should return all required properties" {
            $mockUser = [PSCustomObject]@{
                sAMAccountName = "user123"
                mail = "user@ethz.ch"
                DisplayName = "Test User"
                proxyAddresses = @("user@ethz.ch", "SMTP:user@ethz.onmicrosoft.com")
                TargetAddress = ""
            }

            Mock _ValidateEmailFormat { return $true }
            Mock _ValidateDisplayName { return $true }
            Mock _CheckForDuplicateEmails { return $false }
            Mock _ValidateDomainInExchangeOnline { return $true }

            $result = Test-SharedMailboxCandidate -ADUser $mockUser
            $result | Should -HaveProperty "SamAccountName"
            $result | Should -HaveProperty "IsValid"
            $result | Should -HaveProperty "ValidationErrors"
            $result | Should -HaveProperty "ValidationChecks"
        }
    }

    Context "Null user handling" {
        It "Should return false for null user" {
            $result = Test-SharedMailboxCandidate -ADUser $null
            $result | Should -Be $false
        }
    }

    Context "Multiple errors" {
        It "Should report all validation errors" {
            $mockUser = [PSCustomObject]@{
                sAMAccountName = "user@#$%"
                mail = ""
                DisplayName = "Invalid<>Name"
                proxyAddresses = @()
                TargetAddress = "user@ethz.mail.onmicrosoft.com"
            }

            Mock _ValidateDisplayName { return $false }

            $result = Test-SharedMailboxCandidate -ADUser $mockUser
            $result.IsValid | Should -Be $false
            $result.ValidationErrors.Count | Should -BeGreaterThan 1
        }
    }
}
