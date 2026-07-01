<#
.SYNOPSIS
Establish connection to Exchange Online with retry & logging

.DESCRIPTION
Wrapper for ExchangeOnlineManagement v3.x that handles:
- Automatic module installation if missing
- Connection pooling (reconnect if session expired)
- Error handling and retry logic
- Audit logging of connection events

Uses modern EXO-V3 cmdlets (Get-Mailbox, New-Mailbox, etc.).

Per ADR-002: PowerShell-Version & Exchange Online Compatibility
Per ADR-004: Logging & Audit Trail

.PARAMETER Tenant
Organization name (e.g., 'contoso.onmicrosoft.com') or TenantId (GUID). Optional - falls back
to the 'Organization' value from config.<Environment>.json if not supplied.

.PARAMETER AppId
Application (client) ID for app-based authentication. Optional - falls back to the 'AppId'
value from config.<Environment>.json if not supplied. Omit both to use interactive auth.

.PARAMETER Environment
Config environment name used to resolve config.<Environment>.json (see _Get-Configuration).
Default: "dev"

.PARAMETER ConfigPath
Optional explicit path to a config JSON file, overriding the Environment-based lookup.

.PARAMETER CertificateThumbprint
Thumbprint of the authentication certificate, already installed in the local certificate store.
Required together with -AppId for app-based (certificate) authentication. Optional - falls
back to the 'CertificateThumbprint' value from config.<Environment>.json if not supplied.

.PARAMETER SkipConnectIfAlready
If connection already exists, skip reconnect (default: false, always reconnect)

.PARAMETER ProxyUrl
Optional proxy server URL (e.g. "http://proxyserver:8080"). When set, configures
HTTP_PROXY/HTTPS_PROXY environment variables and .NET's DefaultWebProxy for this
session (using the current user's default network credentials) before connecting.

.PARAMETER Prefix
Prefix applied to all EXO cmdlet nouns (e.g. "ETH" -> Get-ETHMailbox instead of
Get-Mailbox). Lets an on-premises Exchange session (Import-PSSession, unprefixed
cmdlets) and this cloud EXO session stay open in parallel without cmdlet name
collisions. Default: "ETH". Pass an empty string to use unprefixed cloud cmdlets.

.EXAMPLE
Connect-ExchangeOnlineEnv -Tenant "contoso.onmicrosoft.com"
Connects to Exchange Online for contoso tenant (interactive auth)

.EXAMPLE
Connect-ExchangeOnlineEnv
Connects using Tenant/AppId/CertificateThumbprint all resolved from config.dev.json
(set up via scripts/Initialize-ProvisioningConnections.ps1)

.EXAMPLE
Connect-ExchangeOnlineEnv -Tenant "12345678-1234-1234-1234-123456789012" -AppId "app-guid" -CertificateThumbprint "AB12CD34..."
Connects using app-based (certificate) authentication, certificate read from the local cert store

.EXAMPLE
Connect-ExchangeOnlineEnv -Tenant "contoso.onmicrosoft.com" -AppId "app-guid" -CertificateThumbprint "AB12CD34..." -ProxyUrl "http://proxyserver:8080"
Connects through a corporate proxy

.EXAMPLE
Connect-ExchangeOnlineEnv -Tenant "contoso.onmicrosoft.com" -AppId "app-guid" -CertificateThumbprint "AB12CD34..." -Prefix "ETH"
Connects with prefixed cmdlets (Get-ETHMailbox, etc.), so an on-premises Import-PSSession
with unprefixed cmdlets (Get-Mailbox) can stay open at the same time

.NOTES
Requires: ExchangeOnlineManagement >= 3.1.0
Connection timeout: 30 seconds
Retry logic: Max 3 attempts with exponential backoff
#>

function Connect-ExchangeOnlineEnv {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$Tenant = "",

        [Parameter(Mandatory = $false)]
        [string]$AppId = "",

        [Parameter(Mandatory = $false)]
        [string]$CertificateThumbprint = "",

        [Parameter(Mandatory = $false)]
        [string]$Environment = "dev",

        [Parameter(Mandatory = $false)]
        [string]$ConfigPath = "",

        [Parameter(Mandatory = $false)]
        [switch]$SkipConnectIfAlready,

        [Parameter(Mandatory = $false)]
        [string]$ProxyUrl = "",

        [Parameter(Mandatory = $false)]
        [string]$Prefix = "ETH"
    )

    # Resolve Tenant/AppId/CertificateThumbprint from config if not explicitly supplied
    if (-not $Tenant -or -not $AppId -or -not $CertificateThumbprint) {
        $config = _Get-Configuration -ConfigPath $ConfigPath -Environment $Environment

        if ($config) {
            if (-not $Tenant) {
                $Tenant = $config.Organization
            }
            if (-not $AppId) {
                $AppId = $config.AppId
            }
            if (-not $CertificateThumbprint) {
                $CertificateThumbprint = $config.CertificateThumbprint
            }
        }
    }

    if (-not $Tenant) {
        Write-Error "Tenant not specified and no 'Organization' found in config.$Environment.json"
        return $false
    }

    # Configure proxy before any outbound call (module install, PSGallery, EXO auth)
    if ($ProxyUrl) {
        Write-Verbose "Configuring proxy: $ProxyUrl"
        $env:HTTP_PROXY = $ProxyUrl
        $env:HTTPS_PROXY = $ProxyUrl

        $proxy = New-Object System.Net.WebProxy($ProxyUrl, $true)
        $proxy.Credentials = [System.Net.CredentialCache]::DefaultNetworkCredentials
        [System.Net.WebRequest]::DefaultWebProxy = $proxy
    }

    # Ensure ExchangeOnlineManagement module is available
    $eoxModule = Get-Module -Name ExchangeOnlineManagement -ListAvailable | Sort-Object Version -Descending | Select-Object -First 1

    if (-not $eoxModule) {
        Write-Output "[INFO] ExchangeOnlineManagement module not found. Installing..."
        try {
            Install-Module -Name ExchangeOnlineManagement -Force -Scope CurrentUser -ErrorAction Stop
            Write-Output "[OK] ExchangeOnlineManagement installed"
            $eoxModule = Get-Module -Name ExchangeOnlineManagement -ListAvailable | Sort-Object Version -Descending | Select-Object -First 1
        }
        catch {
            Write-Error "Failed to install ExchangeOnlineManagement: $_"
            return $false
        }
    }

    $moduleVersion = $eoxModule.Version
    if ($moduleVersion -lt [version]"3.1.0") {
        Write-Error "ExchangeOnlineManagement version $moduleVersion found. Minimum required: 3.1.0"
        return $false
    }

    Write-Verbose "Using ExchangeOnlineManagement version $moduleVersion"

    # Check if already connected
    if ($SkipConnectIfAlready) {
        try {
            $currentConnection = Get-ConnectionInformation -ErrorAction SilentlyContinue
            if ($currentConnection) {
                Write-Output "[OK] Already connected to Exchange Online (tenant: $($currentConnection.Organization))"
                return $true
            }
        }
        catch {
            Write-Verbose "No existing connection found"
        }
    }

    # Disconnect any existing sessions (clean reconnect)
    try {
        Disconnect-ExchangeOnline -Confirm:$false -ErrorAction SilentlyContinue | Out-Null
        Start-Sleep -Milliseconds 500
    }
    catch {
        Write-Verbose "No previous connection to disconnect"
    }

    # Build connection parameters
    $connectParams = @{
        Organization = $Tenant
        ErrorAction = 'Stop'
        ShowBanner = $false
    }

    if ($AppId -and $CertificateThumbprint) {
        $connectParams['AppId'] = $AppId
        $connectParams['CertificateThumbprint'] = $CertificateThumbprint
    }

    if ($Prefix) {
        $connectParams['Prefix'] = $Prefix
    }

    # Connect with retry logic
    $maxRetries = 3
    $attempt = 0

    while ($attempt -lt $maxRetries) {
        $attempt++
        try {
            Write-Output "[INFO] Connecting to Exchange Online (attempt $attempt/$maxRetries)..."
            Connect-ExchangeOnline @connectParams | Out-Null

            Write-Output "[OK] Connected to Exchange Online successfully (tenant: $Tenant, prefix: $Prefix)"
            Write-Log -Message "Connected to Exchange Online" -Level INFO -Operation "Connect-ExchangeOnlineEnv" -Status "SUCCESS"
            return $true
        }
        catch {
            $errorMessage = $_.Exception.Message

            if ($attempt -lt $maxRetries) {
                $waitMs = [Math]::Pow(2, $attempt - 1) * 1000
                Write-Output "[WARN] Connection failed: $errorMessage. Retrying in ${waitMs}ms..."
                Start-Sleep -Milliseconds $waitMs
            }
            else {
                Write-Error "Failed to connect to Exchange Online after $maxRetries attempts: $errorMessage"
                Write-Log -Message "Failed to connect to Exchange Online: $errorMessage" -Level ERROR -Operation "Connect-ExchangeOnlineEnv" -Status "FAILED"
                return $false
            }
        }
    }

    return $false
}
