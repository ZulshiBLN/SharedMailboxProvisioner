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
Organization name (e.g., 'contoso.onmicrosoft.com') or TenantId (GUID)

.PARAMETER AppId
Optional App ID for app-based authentication (interactive auth by default)

.PARAMETER SkipConnectIfAlready
If connection already exists, skip reconnect (default: false, always reconnect)

.EXAMPLE
Connect-ExchangeOnlineEnv -Tenant "contoso.onmicrosoft.com"
Connects to Exchange Online for contoso tenant (interactive auth)

.EXAMPLE
Connect-ExchangeOnlineEnv -Tenant "12345678-1234-1234-1234-123456789012" -AppId "app-guid"
Connects using app-based authentication

.NOTES
Requires: ExchangeOnlineManagement >= 3.1.0
Connection timeout: 30 seconds
Retry logic: Max 3 attempts with exponential backoff
#>

function Connect-ExchangeOnlineEnv {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Tenant,

        [Parameter(Mandatory = $false)]
        [string]$AppId = "",

        [Parameter(Mandatory = $false)]
        [switch]$SkipConnectIfAlready
    )

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

    if ($AppId) {
        $connectParams['AppId'] = $AppId
        $connectParams['CertificateFilePath'] = $env:EXO_CERT_PATH
        $connectParams['CertificatePassword'] = $env:EXO_CERT_PASSWORD
    }

    # Connect with retry logic
    $maxRetries = 3
    $attempt = 0
    $lastError = $null

    while ($attempt -lt $maxRetries) {
        $attempt++
        try {
            Write-Output "[INFO] Connecting to Exchange Online (attempt $attempt/$maxRetries)..."
            Connect-ExchangeOnline @connectParams | Out-Null

            Write-Output "[OK] Connected to Exchange Online successfully (tenant: $Tenant)"
            Write-Log -Message "Connected to Exchange Online" -Level INFO -Operation "Connect-ExchangeOnlineEnv" -Status "SUCCESS"
            return $true
        }
        catch {
            $lastError = $_
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

Export-ModuleMember -Function Connect-ExchangeOnlineEnv
