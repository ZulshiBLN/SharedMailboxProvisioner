<#
.SYNOPSIS
Initialize encrypted credential file for ScheduledTask execution

.DESCRIPTION
Creates an encrypted credential file (clixml) for Service Account use in ScheduledTask.
This is a ONE-TIME manual setup procedure.

Steps:
1. Run this script manually as the Service Account (elevated PowerShell)
2. When prompted, enter Service Account password
3. Credential is encrypted and saved to clixml file
4. ScheduledTask uses this file if current user context fails

The credential file is encrypted using the running user's credentials,
so only that user can decrypt it (security best practice).

Per ADR-005: Credential Management & Security

.PARAMETER OutputPath
Path where encrypted credential file will be saved
Default: C:\Repos\SharedMailboxProvisioner\data\serviceaccount.clixml

.PARAMETER UserName
Service Account username
Example: DOMAIN\ServiceAccountName

.EXAMPLE
Initialize-ScheduledTaskCredential -UserName "ETHZ\SvcExchangeAdmin"

Prompts for password, creates encrypted clixml file

.NOTES
IMPORTANT: Run as Service Account with elevated privileges
- Opens credential prompt
- Credential is encrypted with Service Account's credentials
- Only Service Account can decrypt and use this file
- Stored in secure clixml format (PowerShell native encryption)

File Permissions:
- Owner: Service Account
- Permissions: Read-only (no modifications after creation)
- Location: Protected folder (C:\Repos\... with restricted access)
#>

function Initialize-ScheduledTaskCredential {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$UserName,

        [Parameter(Mandatory = $false)]
        [string]$OutputPath = "C:\Repos\SharedMailboxProvisioner\data\serviceaccount.clixml"
    )

    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "Initialize Service Account Credential" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""

    Write-Host "This script must be run as: $UserName" -ForegroundColor Yellow
    Write-Host "Current user: $env:USERNAME" -ForegroundColor Yellow

    # Verify running as correct user
    $currentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
    if ($currentUser -notlike "*$UserName*") {
        Write-Host ""
        Write-Host "ERROR: You must run this script as the Service Account!" -ForegroundColor Red
        Write-Host "Current user: $currentUser" -ForegroundColor Red
        Write-Host "Required user: $UserName" -ForegroundColor Red
        Write-Host ""
        Write-Host "To fix:" -ForegroundColor Yellow
        Write-Host "1. Open PowerShell as Administrator" -ForegroundColor Yellow
        Write-Host "2. Run: runas /user:$UserName powershell" -ForegroundColor Yellow
        Write-Host "3. Re-run this script" -ForegroundColor Yellow
        return
    }

    Write-Host "✓ User verification: PASS" -ForegroundColor Green
    Write-Host ""

    # Verify elevated privileges
    $isAdmin = ([System.Security.Principal.WindowsPrincipal] `
        [System.Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)

    if (-not $isAdmin) {
        Write-Host "ERROR: This script must run with elevated privileges!" -ForegroundColor Red
        Write-Host "Please run PowerShell as Administrator" -ForegroundColor Red
        return
    }

    Write-Host "✓ Admin verification: PASS" -ForegroundColor Green
    Write-Host ""

    # Ensure output directory exists
    $outputDir = Split-Path -Parent $OutputPath
    if (-not (Test-Path -Path $outputDir)) {
        Write-Host "Creating output directory: $outputDir" -ForegroundColor Cyan
        New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
    }

    Write-Host "Output directory: $outputDir" -ForegroundColor Cyan
    Write-Host ""

    # Prompt for credential
    Write-Host "Please provide Service Account credentials:" -ForegroundColor Yellow
    Write-Host "You will be prompted for password." -ForegroundColor Yellow
    Write-Host ""

    $credential = Get-Credential -UserName $UserName `
        -Message "Enter Service Account credentials for on-premises Exchange access"

    if (-not $credential) {
        Write-Host "ERROR: No credential provided!" -ForegroundColor Red
        return
    }

    Write-Host ""
    Write-Host "Credential received. Encrypting and saving..." -ForegroundColor Cyan

    try {
        # Export credential to encrypted clixml
        $credential | Export-Clixml -Path $OutputPath -Force -ErrorAction Stop

        Write-Host ""
        Write-Host "✓ Credential file created successfully!" -ForegroundColor Green
        Write-Host "  Path: $OutputPath" -ForegroundColor Green
        Write-Host ""

        # Verify file was created
        if (Test-Path -Path $OutputPath) {
            $fileInfo = Get-Item -Path $OutputPath
            Write-Host "File Information:" -ForegroundColor Cyan
            Write-Host "  Size: $($fileInfo.Length) bytes" -ForegroundColor Cyan
            Write-Host "  Created: $($fileInfo.CreationTime)" -ForegroundColor Cyan
            Write-Host "  Owner: $(whoami)" -ForegroundColor Cyan
            Write-Host ""
        }

        Write-Host "Setup Complete!" -ForegroundColor Green
        Write-Host ""
        Write-Host "Next steps:" -ForegroundColor Yellow
        Write-Host "1. Create Windows ScheduledTask with this Service Account" -ForegroundColor Yellow
        Write-Host "2. Task will use credential from clixml file as fallback" -ForegroundColor Yellow
        Write-Host "3. Primary method: Current user context (no clixml needed)" -ForegroundColor Yellow
        Write-Host "4. Fallback: Use clixml if current context unavailable" -ForegroundColor Yellow
        Write-Host ""

        Write-Log -Message "Service Account credential file created: $OutputPath" `
            -Level INFO -Operation "Initialize-ScheduledTaskCredential" -Status "SUCCESS"

    }
    catch {
        Write-Host ""
        Write-Host "ERROR: Failed to create credential file!" -ForegroundColor Red
        Write-Host "Exception: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host ""
        Write-Log -Message "Failed to create credential file: $($_.Exception.Message)" `
            -Level ERROR -Operation "Initialize-ScheduledTaskCredential" -Status "ERROR"
    }
}

Export-ModuleMember -Function Initialize-ScheduledTaskCredential
