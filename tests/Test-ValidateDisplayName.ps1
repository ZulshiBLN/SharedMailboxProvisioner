<#
.SYNOPSIS
Unit tests for _ValidateDisplayName function
#>

# Import function
$projectRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$functionPath = Join-Path $projectRoot "functions" "Private" "_ValidateDisplayName.ps1"
. $functionPath

Describe "ValidateDisplayName" {

    Context "Valid DisplayNames" {
        It "Should validate clean name" {
            _ValidateDisplayName "Shared Mailbox" | Should -Be $true
        }

        It "Should validate name with hyphens" {
            _ValidateDisplayName "Shared-Mailbox" | Should -Be $true
        }

        It "Should validate name with numbers" {
            _ValidateDisplayName "Mailbox 12345678" | Should -Be $true
        }

        It "Should validate name with apostrophe" {
            _ValidateDisplayName "O'Brien Mailbox" | Should -Be $true
        }

        It "Should validate name with ampersand" {
            _ValidateDisplayName "Sales & Marketing" | Should -Be $true
        }

        It "Should validate name at max length (256 chars)" {
            $maxName = "a" * 256
            _ValidateDisplayName $maxName | Should -Be $true
        }
    }

    Context "Invalid DisplayNames - Empty/Whitespace" {
        It "Should reject empty DisplayName" {
            _ValidateDisplayName "" | Should -Be $false
        }

        It "Should reject whitespace-only DisplayName" {
            _ValidateDisplayName "   " | Should -Be $false
        }

        It "Should reject DisplayName with leading whitespace" {
            _ValidateDisplayName "  Shared Mailbox" | Should -Be $false
        }

        It "Should reject DisplayName with trailing whitespace" {
            _ValidateDisplayName "Shared Mailbox  " | Should -Be $false
        }
    }

    Context "Invalid DisplayNames - Invalid Characters" {
        It "Should reject DisplayName with angle brackets" {
            _ValidateDisplayName "Shared <Mailbox>" | Should -Be $false
        }

        It "Should reject DisplayName with @ symbol" {
            _ValidateDisplayName "Shared@Mailbox" | Should -Be $false
        }

        It "Should reject DisplayName with backslash" {
            _ValidateDisplayName "Shared\Mailbox" | Should -Be $false
        }

        It "Should reject DisplayName with forward slash" {
            _ValidateDisplayName "Shared/Mailbox" | Should -Be $false
        }

        It "Should reject DisplayName with colon" {
            _ValidateDisplayName "Shared:Mailbox" | Should -Be $false
        }

        It "Should reject DisplayName with semicolon" {
            _ValidateDisplayName "Shared;Mailbox" | Should -Be $false
        }

        It "Should reject DisplayName with dot" {
            _ValidateDisplayName "Shared.Mailbox" | Should -Be $false
        }

        It "Should reject DisplayName with comma" {
            _ValidateDisplayName "Shared,Mailbox" | Should -Be $false
        }

        It "Should reject DisplayName with square brackets" {
            _ValidateDisplayName "Shared[Mailbox]" | Should -Be $false
        }

        It "Should reject DisplayName with parentheses" {
            _ValidateDisplayName "Shared(Mailbox)" | Should -Be $false
        }
    }

    Context "Invalid DisplayNames - Length" {
        It "Should reject DisplayName exceeding 256 chars" {
            $longName = "a" * 257
            _ValidateDisplayName $longName | Should -Be $false
        }
    }
}
