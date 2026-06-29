<#
.SYNOPSIS
Load and validate configuration from JSON file

.DESCRIPTION
Loads environment-specific configuration from JSON file with validation.
Merges defaults with loaded config. Never returns sensitive data.

Per ADR-005: Configuration Management

Configuration hierarchy (precedence):
  1. Environment variable (if set)
  2. Command-line parameter
  3. config.{env}.json file
  4. Hardcoded defaults
#>

function Get-Configuration {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$ConfigPath = "",

        [Parameter(Mandatory = $false)]
        [string]$Environment = "dev"
    )

    # Determine config file path
    if (-not $ConfigPath) {
        if (-not (Test-Path $PSScriptRoot)) {
            $ConfigPath = Join-Path (Get-Location) "config" "config.$Environment.json"
        } else {
            $ConfigPath = Join-Path $PSScriptRoot ".." ".." "config" "config.$Environment.json"
        }
    }

    # Default configuration (fallback)
    $defaultConfig = @{
        TenantId = ""
        OrganizationName = "Organization"
        PrimarySmtpDomain = ""
        DefaultMailboxQuota = "50GB"
        ComplianceLabels = @("Internal")
        DelegatedAdministration = $false
        LogRetentionDays = 90
        MaxRetries = 3
        InitialBackoffMs = 100
    }

    # Load from JSON if exists
    $config = $defaultConfig.Clone()

    if (Test-Path $ConfigPath) {
        try {
            $loadedConfig = Get-Content -Path $ConfigPath -Raw | ConvertFrom-Json
            if ($loadedConfig) {
                foreach ($key in $loadedConfig.PSObject.Properties.Name) {
                    $config[$key] = $loadedConfig.$key
                }
                Write-Verbose "Loaded configuration from: $ConfigPath"
            }
        } catch {
            Write-Error "Failed to load configuration from $ConfigPath : $_"
            return $null
        }
    } else {
        Write-Verbose "Configuration file not found: $ConfigPath (using defaults)"
    }

    # Validate required fields
    if (-not $config.TenantId -or $config.TenantId -eq "") {
        Write-Error "Configuration error: TenantId is required"
        return $null
    }

    if (-not $config.PrimarySmtpDomain -or $config.PrimarySmtpDomain -eq "") {
        Write-Error "Configuration error: PrimarySmtpDomain is required"
        return $null
    }

    # Validate format of required fields
    if (-not _ValidateGuid $config.TenantId) {
        Write-Error "Configuration error: TenantId must be a valid GUID (got: $($config.TenantId))"
        return $null
    }

    if (-not _ValidateDomain $config.PrimarySmtpDomain) {
        Write-Error "Configuration error: PrimarySmtpDomain must be a valid domain (got: $($config.PrimarySmtpDomain))"
        return $null
    }

    # Convert compliance labels array (JSON might load as single string)
    if ($config.ComplianceLabels -is [string]) {
        $config.ComplianceLabels = @($config.ComplianceLabels)
    }

    Write-Verbose "Configuration validated successfully"
    return [PSCustomObject]$config
}

function _ValidateGuid {
    param([string]$Value)

    try {
        $guid = [guid]::Parse($Value)
        return $true
    } catch {
        return $false
    }
}

function _ValidateDomain {
    param([string]$Value)

    # Basic domain validation (not comprehensive, but sufficient for SMTP domains)
    if ($Value -match '^([a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?\.)+[a-zA-Z]{2,}$') {
        return $true
    }
    return $false
}

function Get-ServiceAccountCredential {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$EnvironmentName = "dev",

        [Parameter(Mandatory = $false)]
        [string]$CredentialName = "SharedMailboxProvisioner-ServiceAccount"
    )

    # Try Azure Key Vault first (if in cloud environment)
    $azkvSecret = $null
    try {
        if (Get-Command Get-AzKeyVaultSecret -ErrorAction SilentlyContinue) {
            $kvName = "kv-$EnvironmentName"
            $azkvSecret = Get-AzKeyVaultSecret -VaultName $kvName -Name $CredentialName -ErrorAction SilentlyContinue
            if ($azkvSecret) {
                Write-Verbose "Loaded credential from Azure Key Vault: $kvName"
                return $azkvSecret.SecretValue
            }
        }
    } catch {
        Write-Verbose "Azure Key Vault not available or no secret found"
    }

    # Fallback: Credential Manager (Windows only)
    try {
        if (Get-Command Get-StoredCredential -ErrorAction SilentlyContinue) {
            $stored = Get-StoredCredential -Target $CredentialName -ErrorAction SilentlyContinue
            if ($stored) {
                Write-Verbose "Loaded credential from Windows Credential Manager"
                return $stored
            }
        }
    } catch {
        Write-Verbose "Windows Credential Manager not available"
    }

    # Last resort: Environment variable (not recommended for production)
    $envCred = $env:$("SHARED_MAILBOX_CRED_$EnvironmentName")
    if ($envCred) {
        Write-Verbose "Loaded credential from environment variable (not recommended)"
        return $envCred
    }

    Write-Error "No service account credential found for environment: $EnvironmentName"
    Write-Error "  Tried: Azure Key Vault, Windows Credential Manager, Environment Variables"
    return $null
}

Export-ModuleMember -Function Get-Configuration, Get-ServiceAccountCredential
