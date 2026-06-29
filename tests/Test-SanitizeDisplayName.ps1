<#
.SYNOPSIS
Unit tests for _SanitizeDisplayName function
#>

# Import function
$projectRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$functionPath = Join-Path $projectRoot "functions" "Private" "_SanitizeDisplayName.ps1"
. $functionPath

Describe "SanitizeDisplayName" {

    Context "Valid DisplayNames (no cleaning needed)" {
        It "Should pass through clean name" {
            _SanitizeDisplayName "Shared Mailbox" | Should -Be "Shared Mailbox"
        }

        It "Should pass through name with hyphens" {
            _SanitizeDisplayName "Shared-Mailbox" | Should -Be "Shared-Mailbox"
        }

        It "Should pass through name with numbers" {
            _SanitizeDisplayName "Mailbox 12345678" | Should -Be "Mailbox 12345678"
        }

        It "Should trim leading/trailing whitespace" {
            _SanitizeDisplayName "  Shared Mailbox  " | Should -Be "Shared Mailbox"
        }

        It "Should collapse multiple spaces to single" {
            _SanitizeDisplayName "Shared    Mailbox" | Should -Be "Shared Mailbox"
        }
    }

    Context "Invalid characters (should be removed)" {
        It "Should remove angle brackets" {
            _SanitizeDisplayName "Shared <Mailbox>" | Should -Be "SharedMailbox"
        }

        It "Should remove @ symbol" {
            _SanitizeDisplayName "Shared@Mailbox" | Should -Be "SharedMailbox"
        }

        It "Should remove backslash" {
            _SanitizeDisplayName "Shared\Mailbox" | Should -Be "SharedMailbox"
        }

        It "Should remove forward slash" {
            _SanitizeDisplayName "Shared/Mailbox" | Should -Be "SharedMailbox"
        }

        It "Should remove colon" {
            _SanitizeDisplayName "Shared:Mailbox" | Should -Be "SharedMailbox"
        }

        It "Should remove semicolon" {
            _SanitizeDisplayName "Shared;Mailbox" | Should -Be "SharedMailbox"
        }

        It "Should remove dot" {
            _SanitizeDisplayName "Shared.Mailbox" | Should -Be "SharedMailbox"
        }

        It "Should remove comma" {
            _SanitizeDisplayName "Shared,Mailbox" | Should -Be "SharedMailbox"
        }

        It "Should remove square brackets" {
            _SanitizeDisplayName "Shared[Mailbox]" | Should -Be "SharedMailbox"
        }

        It "Should remove parentheses" {
            _SanitizeDisplayName "Shared(Mailbox)" | Should -Be "SharedMailbox"
        }

        It "Should remove multiple invalid characters" {
            _SanitizeDisplayName "Shared<Mail:box>" | Should -Be "SharedMailbox"
        }
    }

    Context "Edge cases" {
        It "Should return empty string for null input" {
            _SanitizeDisplayName "" | Should -Be ""
        }

        It "Should return empty string for whitespace-only input" {
            _SanitizeDisplayName "   " | Should -Be ""
        }

        It "Should return empty if all chars invalid" {
            _SanitizeDisplayName "<<>>" | Should -Be ""
        }

        It "Should truncate to 256 chars" {
            $longName = "a" * 300
            $result = _SanitizeDisplayName $longName
            $result.Length | Should -Be 256
        }

        It "Should handle mixed spaces and invalid chars" {
            _SanitizeDisplayName "Shared  <Mail box>" | Should -Be "Shared Mail box"
        }
    }
}
