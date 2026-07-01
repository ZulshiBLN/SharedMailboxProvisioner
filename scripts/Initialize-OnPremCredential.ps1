<#
.SYNOPSIS
One-time setup: create the on-premises Service Account credential file and populate EXO connection config.

.DESCRIPTION
CLI admin tool that:
1. Verifies it is running as the target Service Account, elevated.
2. Prompts for the Service Account password and saves it as an encrypted clixml
   credential file at config\Credential_{UserName}.clixml. New-SharedMailboxRemote
   uses this file as a fallback when the current user context cannot establish an
   on-premises Exchange PSSession.
3. Writes/updates TenantId, Organization and AppId into config\config.<Environment>.json,
   so Connect-ExchangeOnlineEnv can resolve them without explicit parameters.

This is a MANUAL ADMIN TOOL - run once per Service Account/environment, never scheduled.

Per ADR-005: Configuration Management

.PARAMETER UserName
Service Account username, e.g. "ETHZ\SvcExchangeAdmin". Must match the account this
script is currently running as (verified before prompting for credentials).

.PARAMETER Environment
Config environment to update (config.<Environment>.json). Default: "dev"

.PARAMETER TenantId
Optional TenantId (GUID) to store in config.<Environment>.json.

.PARAMETER Organization
Optional Organization domain (e.g. "ethz.onmicrosoft.com") to store in config.<Environment>.json.

.PARAMETER AppId
Optional Application (client) ID to store in config.<Environment>.json.

.EXAMPLE
.\Initialize-OnPremCredential.ps1 -UserName "ETHZ\SvcExchangeAdmin" -Environment prod `
    -TenantId "9634a6ec-a266-45a3-ab14-74c4211fc582" `
    -Organization "ethz.onmicrosoft.com" `
    -AppId "2b249afb-9e8c-4321-8808-6dce76a6160b"

Creates config\Credential_ETHZ_SvcExchangeAdmin.clixml and updates config\config.prod.json

.NOTES
- Must be run AS the Service Account, with elevated privileges (matches the original
  Initialize-ScheduledTaskCredential design this script replaces)
- Credential file is encrypted via Export-Clixml (DPAPI, tied to the running user/account)
- TenantId/Organization/AppId are not secrets, but config.<Environment>.json is excluded
  from Git via .gitignore regardless - keep tenant-specific values out of config.template.json
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$UserName,

    [Parameter(Mandatory = $false)]
    [string]$Environment = "dev",

    [Parameter(Mandatory = $false)]
    [string]$TenantId = "",

    [Parameter(Mandatory = $false)]
    [string]$Organization = "",

    [Parameter(Mandatory = $false)]
    [string]$AppId = ""
)

# Dot-source Write-Log directly (private module function, not exported by Import-Module)
$moduleRoot = Split-Path -Parent $PSScriptRoot
. (Join-Path (Join-Path $moduleRoot "functions") "Private\_Write-Log.ps1")

Write-Output ""
Write-Output "========================================="
Write-Output "On-Premises Credential + EXO Config Setup"
Write-Output "========================================="
Write-Output ""

# Verify running as correct user
$currentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
Write-Output "This script must be run as: $UserName"
Write-Output "Current user: $currentUser"

if ($currentUser -notlike "*$UserName*") {
    Write-Output ""
    Write-Output "ERROR: You must run this script as the Service Account!"
    Write-Output "Current user: $currentUser"
    Write-Output "Required user: $UserName"
    Write-Output ""
    Write-Output "To fix:"
    Write-Output "1. Open PowerShell as Administrator"
    Write-Output "2. Run: runas /user:$UserName powershell"
    Write-Output "3. Re-run this script"
    exit 1
}

Write-Output "[OK] User verification: PASS"
Write-Output ""

# Verify elevated privileges
$isAdmin = ([System.Security.Principal.WindowsPrincipal] `
        [System.Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Output "ERROR: This script must run with elevated privileges!"
    Write-Output "Please run PowerShell as Administrator"
    exit 1
}

Write-Output "[OK] Admin verification: PASS"
Write-Output ""

# Resolve config directory (module root, one level up from scripts\)
$configDir = Join-Path $moduleRoot "config"

if (-not (Test-Path -Path $configDir)) {
    New-Item -ItemType Directory -Path $configDir -Force | Out-Null
}

try {
    # ================================================================
    # STEP 1: Create encrypted credential file
    # ================================================================
    Write-Output "[1/2] Creating encrypted credential file..."
    Write-Output ""

    $sanitizedUserName = $UserName -replace '[\\/:*?"<>|]', '_'
    $credentialPath = Join-Path $configDir "Credential_$sanitizedUserName.clixml"

    Write-Output "Please provide Service Account credentials for on-premises Exchange access:"
    $credential = Get-Credential -UserName $UserName `
        -Message "Enter Service Account credentials for on-premises Exchange access"

    if (-not $credential) {
        Write-Error "No credential provided!"
        exit 1
    }

    $credential | Export-Clixml -Path $credentialPath -Force -ErrorAction Stop

    Write-Output ""
    Write-Output "[OK] Credential file created: $credentialPath"
    Write-Log -Message "On-premises credential file created: $credentialPath" `
        -Level INFO -Operation "Initialize-OnPremCredential" -Status "SUCCESS"
    Write-Output ""

    # ================================================================
    # STEP 2: Update config.<Environment>.json with EXO connection data
    # ================================================================
    Write-Output "[2/2] Updating config.$Environment.json..."

    $configPath = Join-Path $configDir "config.$Environment.json"
    $templatePath = Join-Path $configDir "config.template.json"

    if (Test-Path -Path $configPath) {
        $configData = Get-Content -Path $configPath -Raw | ConvertFrom-Json
    }
    elseif (Test-Path -Path $templatePath) {
        $configData = Get-Content -Path $templatePath -Raw | ConvertFrom-Json
    }
    else {
        $configData = [PSCustomObject]@{}
    }

    if ($TenantId) {
        $configData | Add-Member -NotePropertyName 'TenantId' -NotePropertyValue $TenantId -Force
    }
    if ($Organization) {
        $configData | Add-Member -NotePropertyName 'Organization' -NotePropertyValue $Organization -Force
    }
    if ($AppId) {
        $configData | Add-Member -NotePropertyName 'AppId' -NotePropertyValue $AppId -Force
    }

    $configData | ConvertTo-Json -Depth 10 | Set-Content -Path $configPath -Force -ErrorAction Stop

    Write-Output "[OK] Config updated: $configPath"
    Write-Log -Message "Config updated for environment '$Environment': $configPath" `
        -Level INFO -Operation "Initialize-OnPremCredential" -Status "SUCCESS"
    Write-Output ""

    Write-Output "Setup Complete!"
    Write-Output ""
    Write-Output "Credential file : $credentialPath"
    Write-Output "Config file     : $configPath"
    Write-Output ""
    Write-Output "Next steps:"
    Write-Output "1. New-SharedMailboxRemote -CredentialPath `"$credentialPath`""
    Write-Output "   uses this file as fallback if the current user context can't open a PSSession."
    Write-Output "2. Connect-ExchangeOnlineEnv -Environment $Environment"
    Write-Output "   resolves Tenant/AppId from config.$Environment.json automatically."
    Write-Output ""
}
catch {
    $msg = "On-premises credential/config setup failed: $($_.Exception.Message)"
    Write-Error $msg
    Write-Log -Message $msg -Level ERROR -Operation "Initialize-OnPremCredential" -Status "FAILED"
    exit 1
}
