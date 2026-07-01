<#
.SYNOPSIS
Unit tests for _Get-Configuration function

.DESCRIPTION
Tests configuration loading, validation, and defaults
#>

$functionPath = Join-Path (Join-Path (Split-Path -Parent $PSScriptRoot) "functions") "Private\_Get-Configuration.ps1"
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
                Organization = "ethz.onmicrosoft.com"
                AppId = "2b249afb-9e8c-4321-8808-6dce76a6160b"
                CertificateThumbprint = "A377E5106C48A92041314CB5A13369F827A2AC96"
                DefaultMailboxQuota = "100GB"
            }

            $configFile = Join-Path $testConfigDir "config.test.json"
            $validConfig | ConvertTo-Json | Set-Content -Path $configFile

            $config = _Get-Configuration -ConfigPath $configFile
            $config.Organization | Should -Be "ethz.onmicrosoft.com"
            $config.AppId | Should -Be "2b249afb-9e8c-4321-8808-6dce76a6160b"
            $config.CertificateThumbprint | Should -Be "A377E5106C48A92041314CB5A13369F827A2AC96"
            $config.DefaultMailboxQuota | Should -Be "100GB"
        }
    }

    Context "Default configuration fallback" {
        It "Should use defaults when config file missing" {
            $config = _Get-Configuration -ConfigPath (Join-Path $testConfigDir "nonexistent.json")
            $config.DefaultMailboxQuota | Should -Be "50GB"
            $config.MaxRetries | Should -Be 5
            $config.Organization | Should -BeNullOrEmpty
            $config.AppId | Should -BeNullOrEmpty
            $config.CertificateThumbprint | Should -BeNullOrEmpty
        }
    }
}
