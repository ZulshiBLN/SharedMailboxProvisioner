<#
.SYNOPSIS
Unit tests for _ValidateEmailFormat function
#>

# Import function
$projectRoot = Split-Path -Parent $PSScriptRoot
$functionPath = Join-Path (Join-Path $projectRoot "functions") "Private\_ValidateEmailFormat.ps1"
. $functionPath

Describe "ValidateEmailFormat" {

    Context "Valid email formats" {
        It "Should validate standard email" {
            _ValidateEmailFormat "user@ethz.ch" | Should -Be $true
        }

        It "Should validate email with dots in local part" {
            _ValidateEmailFormat "john.doe@ethz.ch" | Should -Be $true
        }

        It "Should validate email with hyphens in local part" {
            _ValidateEmailFormat "john-doe@ethz.ch" | Should -Be $true
        }

        It "Should validate email with underscores in local part" {
            _ValidateEmailFormat "john_doe@ethz.ch" | Should -Be $true
        }

        It "Should validate email with numbers" {
            _ValidateEmailFormat "user123@ethz.ch" | Should -Be $true
        }

        It "Should validate email with subdomain" {
            _ValidateEmailFormat "user@mail.ethz.ch" | Should -Be $true
        }

        It "Should validate email with M365 domain" {
            _ValidateEmailFormat "user@ethz.onmicrosoft.com" | Should -Be $true
        }

        It "Should validate email with plus addressing" {
            _ValidateEmailFormat "user+tag@ethz.ch" | Should -Be $true
        }
    }

    Context "Invalid email formats" {
        It "Should reject empty email" {
            _ValidateEmailFormat "" | Should -Be $false
        }

        It "Should reject whitespace-only email" {
            _ValidateEmailFormat "   " | Should -Be $false
        }

        It "Should reject email without @" {
            _ValidateEmailFormat "user.ethz.ch" | Should -Be $false
        }

        It "Should reject email with multiple @" {
            _ValidateEmailFormat "user@@ethz.ch" | Should -Be $false
        }

        It "Should reject email without domain" {
            _ValidateEmailFormat "user@" | Should -Be $false
        }

        It "Should reject email without local part" {
            _ValidateEmailFormat "@ethz.ch" | Should -Be $false
        }

        It "Should reject email with space in domain" {
            _ValidateEmailFormat "user@eth z.ch" | Should -Be $false
        }

        It "Should reject email with space in local part" {
            _ValidateEmailFormat "john doe@ethz.ch" | Should -Be $false
        }

        It "Should reject email without TLD" {
            _ValidateEmailFormat "user@ethz" | Should -Be $false
        }

        It "Should reject email starting with dot" {
            _ValidateEmailFormat ".user@ethz.ch" | Should -Be $false
        }

        It "Should reject email ending with dot" {
            _ValidateEmailFormat "user.@ethz.ch" | Should -Be $false
        }

        It "Should reject email with consecutive dots" {
            _ValidateEmailFormat "user..name@ethz.ch" | Should -Be $false
        }

        It "Should reject email exceeding 254 chars" {
            $longEmail = "a" * 250 + "@ethz.ch"
            _ValidateEmailFormat $longEmail | Should -Be $false
        }

        It "Should reject email with invalid characters" {
            _ValidateEmailFormat "user<>@ethz.ch" | Should -Be $false
        }
    }
}
