<#
.SYNOPSIS
Unit tests for Get-Configuration function

.DESCRIPTION
Tests configuration loading, validation, and defaults
#>

$functionPath = Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) "functions" "Private" "Get-Configuration.ps1"
. $functionPath

Describe "GetConfiguration" {

    BeforeEach {
        $testConfigDir = Join-Path $env:TEMP "SharedMailboxProvisioner-Config-$(Get-Random)"
        New-Item -ItemType Directory -Path $testConfigDir -Force | Out-Null
    }

    AfterEach {
        if (Test-Path $testConfigDir) {
            Remove-Item -Path $testConfigDir -Recurse -Force
        }
    }

    Context "Load valid configuration" {
        It "Should load config from JSON file" {
            $validConfig = @{
                TenantId = "12345678-1234-1234-1234-123456789012"
                OrganizationName = "TestOrg"
                PrimarySmtpDomain = "test.com"
                DefaultMailboxQuota = "100GB"
            }

            $configFile = Join-Path $testConfigDir "config.test.json"
            $validConfig | ConvertTo-Json | Set-Content -Path $configFile

            $config = Get-Configuration -ConfigPath $configFile
            $config.TenantId | Should -Be "12345678-1234-1234-1234-123456789012"
            $config.PrimarySmtpDomain | Should -Be "test.com"
        }
    }

    Context "Configuration validation" {
        It "Should fail on missing TenantId" {
            $invalidConfig = @{
                PrimarySmtpDomain = "test.com"
            }

            $configFile = Join-Path $testConfigDir "config.invalid.json"
            $invalidConfig | ConvertTo-Json | Set-Content -Path $configFile

            $config = Get-Configuration -ConfigPath $configFile
            $config | Should -BeNullOrEmpty
        }

        It "Should fail on invalid GUID TenantId" {
            $invalidConfig = @{
                TenantId = "not-a-guid"
                PrimarySmtpDomain = "test.com"
            }

            $configFile = Join-Path $testConfigDir "config.badguid.json"
            $invalidConfig | ConvertTo-Json | Set-Content -Path $configFile

            $config = Get-Configuration -ConfigPath $configFile
            $config | Should -BeNullOrEmpty
        }

        It "Should fail on invalid domain PrimarySmtpDomain" {
            $invalidConfig = @{
                TenantId = "12345678-1234-1234-1234-123456789012"
                PrimarySmtpDomain = "invalid..domain"
            }

            $configFile = Join-Path $testConfigDir "config.baddomain.json"
            $invalidConfig | ConvertTo-Json | Set-Content -Path $configFile

            $config = Get-Configuration -ConfigPath $configFile
            $config | Should -BeNullOrEmpty
        }
    }

    Context "Default configuration fallback" {
        It "Should use defaults when config file missing" {
            $config = Get-Configuration -ConfigPath (Join-Path $testConfigDir "nonexistent.json")
            $config.DefaultMailboxQuota | Should -Be "50GB"
            $config.MaxRetries | Should -Be 3
        }
    }
}
