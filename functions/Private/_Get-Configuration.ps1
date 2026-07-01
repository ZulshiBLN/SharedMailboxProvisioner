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
    # Join-Path in Windows PowerShell 5.1 only accepts a single -Path/-ChildPath pair,
    # so multi-segment paths must be built via chained calls.
    if (-not $ConfigPath) {
        if (-not (Test-Path $PSScriptRoot)) {
            $configDir = Join-Path (Get-Location) "config"
        }
        else {
            $moduleRoot = Join-Path $PSScriptRoot ".."
            $moduleRoot = Join-Path $moduleRoot ".."
            $configDir = Join-Path $moduleRoot "config"
        }

        $ConfigPath = Join-Path $configDir "config.$Environment.json"
    }

    # Default configuration (fallback)
    $defaultConfig = @{
        TenantId = ""
        Organization = ""
        AppId = ""
        DefaultMailboxQuota = "50GB"
        LogRetentionDays = 90
        MaxRetries = 5
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
        }
        catch {
            Write-Error "Failed to load configuration from $ConfigPath : $_"
            return $null
        }
    }
    else {
        Write-Verbose "Configuration file not found: $ConfigPath (using defaults)"
    }

    # Validate required fields
    if (-not $config.TenantId -or $config.TenantId -eq "") {
        Write-Error "Configuration error: TenantId is required"
        return $null
    }

    # Validate format of required fields
    if (-not (_ValidateGuid -Value $config.TenantId)) {
        Write-Error "Configuration error: TenantId must be a valid GUID (got: $($config.TenantId))"
        return $null
    }

    Write-Verbose "Configuration validated successfully"
    return [PSCustomObject]$config
}

function _ValidateGuid {
    param([string]$Value)

    try {
        $guid = [guid]::Parse($Value)
        return $true
    }
    catch {
        return $false
    }
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
    }
    catch {
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
    }
    catch {
        Write-Verbose "Windows Credential Manager not available"
    }

    # Last resort: Environment variable (not recommended for production)
    $envVarName = "SHARED_MAILBOX_CRED_$EnvironmentName"
    $envCred = [System.Environment]::GetEnvironmentVariable($envVarName)
    if ($envCred) {
        Write-Verbose "Loaded credential from environment variable (not recommended)"
        return $envCred
    }

    Write-Error "No service account credential found for environment: $EnvironmentName"
    Write-Error "  Tried: Azure Key Vault, Windows Credential Manager, Environment Variables"
    return $null
}

