<#
.SYNOPSIS
Create remote shared mailbox on on-premises Exchange Server

.DESCRIPTION
Creates a new remote shared mailbox in on-premises Exchange Server.
The mailbox is linked to the smbx_* disabled user account in Active Directory.
Automatically adds entry to provisioning backlog for permission assignment.

Remote shared mailboxes are used in hybrid Exchange environments where:
- User account exists in on-premises AD (smbx_* disabled)
- Mailbox lives in Exchange Online
- Link created via New-RemoteMailbox cmdlet

Per ADR-006: Active Directory Integration & Candidate Selection

.PARAMETER SamAccountName
The smbx_* SAM account name (disabled user)
Used as mailbox identity in on-premises AD

.PARAMETER DisplayName
User-friendly mailbox display name
Example: "Sales Team", "Accounting", "Support"

.PARAMETER PrimarySmtpAddress
Primary SMTP email address for the mailbox
Example: sales@ethz.ch

.PARAMETER RemoteRoutingAddress
Exchange Online routing address
Format: alias@ethz.mail.onmicrosoft.com

.PARAMETER ACLGroupName
Name of the smbx_acl_* security group for permissions
Will be assigned FullAccess + SendAs

.PARAMETER AdminGroupName
Optional: Admin group name for FullAccess only (no SendAs)

.PARAMETER BacklogPath
Path to JSON provisioning backlog file
Default: C:\Repos\SharedMailboxProvisioner\data\mailbox-provisioning-queue.json

.PARAMETER ExchangeURI
On-premises Exchange Server URI for PSSession
Default: constructed from configuration

.PARAMETER CredentialPath
Path to clixml credential file (fallback if no PSSession)
Default: C:\Repos\SharedMailboxProvisioner\data\serviceaccount.clixml

.EXAMPLE
$mailbox = New-SharedMailboxRemote -SamAccountName "smbx_123456" `
    -DisplayName "Sales Team" `
    -PrimarySmtpAddress "sales@ethz.ch" `
    -RemoteRoutingAddress "sales@ethz.mail.onmicrosoft.com" `
    -ACLGroupName "smbx_acl_123456"

Creates remote mailbox and adds entry to provisioning backlog

.NOTES
- Service Account must have Exchange Admin permissions
- Remote mailbox creation is immediate (no EXO sync wait)
- Permission assignment happens asynchronously via Invoke-MailboxPermissionQueue
- Requires on-premises Exchange Server (not Cloud-only)
#>

function New-SharedMailboxRemote {
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Deferred: SupportsShouldProcess is a behavioral change to a function confirmed working against the live tenant this Pre-Release week. See COMPLIANCE-AUDIT-PHASE-PRERELEASE.md Known Gaps')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingPlainTextForPassword', 'CredentialPath', Justification = 'File path to a .clixml credential file, not a literal secret value. See COMPLIANCE-AUDIT-PHASE-PRERELEASE.md Known Gaps')]
    param(
        [Parameter(Mandatory = $true)]
        [string]$SamAccountName,

        [Parameter(Mandatory = $true)]
        [string]$DisplayName,

        [Parameter(Mandatory = $true)]
        [string]$PrimarySmtpAddress,

        [Parameter(Mandatory = $true)]
        [string]$RemoteRoutingAddress,

        [Parameter(Mandatory = $true)]
        [string]$ACLGroupName,

        [Parameter(Mandatory = $false)]
        [string]$AdminGroupName = "",

        [Parameter(Mandatory = $false)]
        [string]$BacklogPath = "C:\Repos\SharedMailboxProvisioner\data\mailbox-provisioning-queue.json",

        [Parameter(Mandatory = $false)]
        [string]$ExchangeURI = "",

        [Parameter(Mandatory = $false)]
        [string]$CredentialPath = "C:\Repos\SharedMailboxProvisioner\data\serviceaccount.clixml"
    )

    Write-Verbose "Creating remote shared mailbox: $DisplayName"
    Write-Verbose "  SamAccountName: $SamAccountName"
    Write-Verbose "  PrimarySmtp: $PrimarySmtpAddress"
    Write-Verbose "  RemoteRouting: $RemoteRoutingAddress"

    try {
        # ================================================================
        # STEP 1: Establish PSSession to On-Premises Exchange
        # ================================================================
        Write-Verbose "Connecting to on-premises Exchange..."

        $PSSession = _GetExchangePSSession -ExchangeURI $ExchangeURI -CredentialPath $CredentialPath

        if (-not $PSSession) {
            throw "Failed to establish PSSession to on-premises Exchange Server"
        }

        Write-Verbose "PSSession established successfully"

        # ================================================================
        # STEP 2: Validate prerequisites
        # ================================================================
        Write-Verbose "Validating prerequisites..."

        # Check if user account exists in AD (using Get-ADObject for efficiency)
        $adUser = Get-ADObject -Filter "sAMAccountName -eq '$SamAccountName' -and objectClass -eq 'user'" `
            -Properties UserPrincipalName, userAccountControl `
            -ErrorAction SilentlyContinue

        if (-not $adUser) {
            throw "User account not found in AD: $SamAccountName"
        }

        # Check if account is disabled (userAccountControl bit 2)
        if ($adUser.userAccountControl -and -not ($adUser.userAccountControl -band 2)) {
            Write-Warning "User account is ENABLED: $SamAccountName (should be disabled)"
        }

        Write-Verbose "AD user validation passed: $SamAccountName"

        # ================================================================
        # STEP 3: Create Remote Mailbox on On-Premises Exchange
        # ================================================================
        Write-Verbose "Creating remote mailbox on on-premises Exchange..."

        $createMailboxParams = @{
            Name = $DisplayName
            Alias = $SamAccountName
            UserPrincipalName = $adUser.UserPrincipalName
            RemoteRoutingAddress = $RemoteRoutingAddress
            PrimarySmtpAddress = $PrimarySmtpAddress
            Shared = $true
            ErrorAction = 'Stop'
        }

        $remoteMailbox = Invoke-Command -Session $PSSession -ScriptBlock {
            param($params)
            New-RemoteMailbox @params
        } -ArgumentList $createMailboxParams

        if (-not $remoteMailbox) {
            throw "Failed to create remote mailbox"
        }

        Write-Verbose "Remote mailbox created successfully: $($remoteMailbox.Identity)"
        Write-Log -Message "Remote mailbox created: $DisplayName ($SamAccountName)" `
            -Level INFO -Operation "New-SharedMailboxRemote" -Status "MAILBOX_CREATED"

        # ================================================================
        # STEP 4: Add entry to provisioning backlog
        # ================================================================
        Write-Verbose "Adding entry to provisioning backlog..."

        _AddToMailboxProvisioningBacklog -BacklogPath $BacklogPath `
            -SamAccountName $SamAccountName `
            -ACLGroupName $ACLGroupName `
            -AdminGroupName $AdminGroupName `
            -MailboxName $DisplayName `
            -PrimarySmtpAddress $PrimarySmtpAddress

        Write-Verbose "Entry added to provisioning backlog"
        Write-Log -Message "Added to provisioning backlog: $SamAccountName (awaiting permission assignment)" `
            -Level INFO -Operation "New-SharedMailboxRemote" -Status "BACKLOG_ADDED"

        # ================================================================
        # STEP 5: Return result
        # ================================================================
        $result = [PSCustomObject]@{
            SamAccountName = $SamAccountName
            DisplayName = $DisplayName
            PrimarySmtpAddress = $PrimarySmtpAddress
            RemoteRoutingAddress = $RemoteRoutingAddress
            ACLGroupName = $ACLGroupName
            AdminGroupName = $AdminGroupName
            Status = "MAILBOX_CREATED_AWAITING_PERMISSIONS"
            CreatedAt = (Get-Date).ToUniversalTime()
            Identity = $remoteMailbox.Identity
            RemoteMailbox = $remoteMailbox
        }

        Write-Verbose "Remote mailbox creation completed successfully"
        return $result

    }
    catch {
        $errorMessage = $_.Exception.Message
        Write-Error "Failed to create remote mailbox: $errorMessage"
        Write-Log -Message "Remote mailbox creation failed: $errorMessage" `
            -Level ERROR -Operation "New-SharedMailboxRemote" -Status "ERROR"
        return $null
    }
}

function _GetExchangePSSession {
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingPlainTextForPassword', 'CredentialPath', Justification = 'File path to a .clixml credential file, not a literal secret value. See COMPLIANCE-AUDIT-PHASE-PRERELEASE.md Known Gaps')]
    param(
        [Parameter(Mandatory = $false)]
        [string]$ExchangeURI,

        [Parameter(Mandatory = $false)]
        [string]$CredentialPath
    )

    Write-Verbose "Attempting to establish Exchange PSSession..."

    # Try current Service Account context first
    try {
        Write-Verbose "Attempting with current user context..."

        if ([string]::IsNullOrWhiteSpace($ExchangeURI)) {
            # Get from configuration if not provided
            $config = _Get-Configuration
            $ExchangeURI = $config.exchange.onPremises.uri
        }

        $PSSession = New-PSSession -ConfigurationName Microsoft.Exchange `
            -ConnectionUri $ExchangeURI `
            -ErrorAction Stop

        Write-Verbose "PSSession established with current user context"
        return $PSSession
    }
    catch {
        Write-Verbose "Current user context failed: $($_.Exception.Message)"
        Write-Verbose "Trying credential file fallback..."

        # Fallback to credential file
        if (-not (Test-Path -Path $CredentialPath)) {
            Write-Warning "Credential file not found: $CredentialPath"
            Write-Warning "Run scripts\Initialize-ProvisioningConnections.ps1 to create the credential file"
            return $null
        }

        try {
            $credential = Import-Clixml -Path $CredentialPath -ErrorAction Stop
            $PSSession = New-PSSession -ConfigurationName Microsoft.Exchange `
                -ConnectionUri $ExchangeURI `
                -Credential $credential `
                -ErrorAction Stop

            Write-Verbose "PSSession established with credential file"
            return $PSSession
        }
        catch {
            Write-Error "Failed to establish PSSession: $($_.Exception.Message)"
            return $null
        }
    }
}

function _AddToMailboxProvisioningBacklog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$BacklogPath,

        [Parameter(Mandatory = $true)]
        [string]$SamAccountName,

        [Parameter(Mandatory = $true)]
        [string]$ACLGroupName,

        [Parameter(Mandatory = $false)]
        [string]$AdminGroupName,

        [Parameter(Mandatory = $true)]
        [string]$MailboxName,

        [Parameter(Mandatory = $true)]
        [string]$PrimarySmtpAddress
    )

    # Create backlog directory if not exists
    $backlogDir = Split-Path -Parent $BacklogPath
    if (-not (Test-Path -Path $backlogDir)) {
        New-Item -ItemType Directory -Path $backlogDir -Force | Out-Null
        Write-Verbose "Created backlog directory: $backlogDir"
    }

    # Read existing backlog or create new
    $backlog = $null
    if (Test-Path -Path $BacklogPath) {
        try {
            $backlog = Get-Content -Path $BacklogPath -ErrorAction Stop | ConvertFrom-Json
        }
        catch {
            Write-Warning "Failed to read existing backlog, creating new: $_"
            $backlog = $null
        }
    }

    if (-not $backlog) {
        $backlog = [PSCustomObject]@{
            version = "1.0"
            metadata = [PSCustomObject]@{
                lastUpdated = (Get-Date).ToUniversalTime().ToString("o")
                totalEntries = 0
                pendingEntries = 0
                completedEntries = 0
                failedEntries = 0
            }
            entries = @()
        }
    }

    # Create new entry
    $newEntry = [PSCustomObject]@{
        id = $SamAccountName
        samAccountName = $SamAccountName
        aclGroup = $ACLGroupName
        adminGroup = if ([string]::IsNullOrWhiteSpace($AdminGroupName)) {
            $null
        }
        else {
            $AdminGroupName
        }
        mailboxName = $MailboxName
        primarySmtpAddress = $PrimarySmtpAddress
        status = "MAILBOX_CREATED_AWAITING_PERMISSIONS"
        createdAt = (Get-Date).ToUniversalTime().ToString("o")
        lastAttemptAt = $null
        retryCount = 0
        maxRetries = 5
        completedAt = $null
        errors = @()
        notes = "Awaiting EXO sync from on-prem AD (Azure AD Connect ~60 min)"
    }

    # Add to entries array
    $backlog.entries += $newEntry

    # Update metadata
    $backlog.metadata.lastUpdated = (Get-Date).ToUniversalTime().ToString("o")
    $backlog.metadata.totalEntries = $backlog.entries.Count
    $backlog.metadata.pendingEntries = ($backlog.entries | Where-Object { $_.status -eq "MAILBOX_CREATED_AWAITING_PERMISSIONS" }).Count
    $backlog.metadata.completedEntries = ($backlog.entries | Where-Object { $_.status -eq "PERMISSIONS_SET" }).Count
    $backlog.metadata.failedEntries = ($backlog.entries | Where-Object { $_.status -eq "FAILED_PERMISSIONS" }).Count

    # Save backlog (JSON)
    $backlog | ConvertTo-Json -Depth 10 | Set-Content -Path $BacklogPath -Force
    Write-Verbose "Backlog updated: $BacklogPath"

    # Export CSV (for manual debugging)
    _ExportBacklogToCSV -Backlog $backlog -BacklogPath $BacklogPath
}

function _ExportBacklogToCSV {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        $Backlog,

        [Parameter(Mandatory = $true)]
        [string]$BacklogPath
    )

    $csvPath = $BacklogPath -replace '\.json$', '.csv'

    $exportData = $backlog.entries | Select-Object -Property @(
        "samAccountName"
        "aclGroup"
        "adminGroup"
        "mailboxName"
        "primarySmtpAddress"
        "status"
        "createdAt"
        "lastAttemptAt"
        "retryCount"
        "maxRetries"
        "completedAt"
        @{Name = "ErrorCount"; Expression = { $_.errors.Count } },
        @{
            Name = "LastError"
            Expression = {
                if ($_.errors.Count -gt 0) {
                    $_.errors[-1].errorMessage
                }
                else {
                    ""
                }
            }
        },
        @{Name = "Notes"; Expression = { $_.notes } }
    )

    $exportData | Export-Csv -Path $csvPath -NoTypeInformation -Force

    Write-Verbose "Backlog exported to CSV: $csvPath"
}
