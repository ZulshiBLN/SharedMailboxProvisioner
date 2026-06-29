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

    Write-Output ""
    Write-Output "========================================"
    Write-Output "Initialize Service Account Credential"
    Write-Output "========================================"
    Write-Output ""

    Write-Output "This script must be run as: $UserName"
    Write-Output "Current user: $env:USERNAME"

    # Verify running as correct user
    $currentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
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
        return
    }

    Write-Output "[OK] User verification: PASS"
    Write-Output ""

    # Verify elevated privileges
    $isAdmin = ([System.Security.Principal.WindowsPrincipal] `
            [System.Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)

    if (-not $isAdmin) {
        Write-Output "ERROR: This script must run with elevated privileges!"
        Write-Output "Please run PowerShell as Administrator"
        return
    }

    Write-Output "[OK] Admin verification: PASS"
    Write-Output ""

    # Ensure output directory exists
    $outputDir = Split-Path -Parent $OutputPath
    if (-not (Test-Path -Path $outputDir)) {
        Write-Output "Creating output directory: $outputDir"
        New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
    }

    Write-Output "Output directory: $outputDir"
    Write-Output ""

    # Prompt for credential
    Write-Output "Please provide Service Account credentials:"
    Write-Output "You will be prompted for password."
    Write-Output ""

    $credential = Get-Credential -UserName $UserName `
        -Message "Enter Service Account credentials for on-premises Exchange access"

    if (-not $credential) {
        Write-Output "ERROR: No credential provided!"
        return
    }

    Write-Output ""
    Write-Output "Credential received. Encrypting and saving..."

    try {
        # Export credential to encrypted clixml
        $credential | Export-Clixml -Path $OutputPath -Force -ErrorAction Stop

        Write-Output ""
        Write-Output "[OK] Credential file created successfully!"
        Write-Output "  Path: $OutputPath"
        Write-Output ""

        # Verify file was created
        if (Test-Path -Path $OutputPath) {
            $fileInfo = Get-Item -Path $OutputPath
            Write-Output "File Information:"
            Write-Output "  Size: $($fileInfo.Length) bytes"
            Write-Output "  Created: $($fileInfo.CreationTime)"
            Write-Output "  Owner: $(whoami)"
            Write-Output ""
        }

        Write-Output "Setup Complete!"
        Write-Output ""
        Write-Output "Next steps:"
        Write-Output "1. Create Windows ScheduledTask with this Service Account"
        Write-Output "2. Task will use credential from clixml file as fallback"
        Write-Output "3. Primary method: Current user context (no clixml needed)"
        Write-Output "4. Fallback: Use clixml if current context unavailable"
        Write-Output ""

        Write-Log -Message "Service Account credential file created: $OutputPath" `
            -Level INFO -Operation "Initialize-ScheduledTaskCredential" -Status "SUCCESS"

    }
    catch {
        Write-Output ""
        Write-Output "ERROR: Failed to create credential file!"
        Write-Output "Exception: $($_.Exception.Message)"
        Write-Output ""
        Write-Log -Message "Failed to create credential file: $($_.Exception.Message)" `
            -Level ERROR -Operation "Initialize-ScheduledTaskCredential" -Status "ERROR"
    }
}

Export-ModuleMember -Function Initialize-ScheduledTaskCredential
