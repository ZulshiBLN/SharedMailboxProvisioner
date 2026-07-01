# SharedMailboxProvisioner - Administrator Guide

**Version:** v0.9.0-beta.1 | **Status:** Pre-Release Phase Active  
**Last Updated:** 2026-07-01

---

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Installation & Deployment](#installation--deployment)
3. [Configuration](#configuration)
4. [Performance Tuning](#performance-tuning)
5. [Monitoring & Alerting](#monitoring--alerting)
6. [Troubleshooting](#troubleshooting)
7. [Disaster Recovery](#disaster-recovery)
8. [Security Considerations](#security-considerations)

---

## Architecture Overview

### System Design

```
┌─────────────────────────────────────────────────────────────┐
│                   SHAREDRAILBOXPROVISIONER                  │
├─────────────────────────────────────────────────────────────┤
│                                                               │
│  TIER 1-4: DISCOVERY & VALIDATION                            │
│  ├─ Active Directory query (Get-SharedMailboxCandidates)    │
│  ├─ Email validation (RFC 5321)                              │
│  ├─ Candidate validation (Test-SharedMailboxCandidate)       │
│  └─ Group membership checks                                  │
│                                                               │
│  TIER 5: EXCHANGE PROVISIONING                               │
│  ├─ New-SharedMailboxRemote (mailbox creation)              │
│  ├─ Permission queue (ACL assignment)                        │
│  └─ Backlog tracking (JSON-based state)                      │
│                                                               │
│  TIER 6: ORCHESTRATION                                       │
│  ├─ Invoke-SharedMailboxProvisioning (main entry point)     │
│  ├─ Batch processing                                         │
│  └─ Error handling & retry                                   │
│                                                               │
│  TIER 7: BULK IMPORT (MANUAL)                                │
│  ├─ CSV validation & import                                  │
│  ├─ Dry-run mode                                             │
│  └─ Bulk provisioning                                        │
│                                                               │
│  TIER 8: REPORTING & AUDIT                                   │
│  ├─ Metrics & KPIs                                           │
│  ├─ Audit logging                                            │
│  └─ Report generation (HTML/CSV/Text)                        │
│                                                               │
│  TIER 10: OPERATIONAL TOOLING                                │
│  ├─ Status queries                                           │
│  ├─ Failure diagnostics                                      │
│  ├─ Retry management                                         │
│  ├─ Health checks                                            │
│  └─ Schedule configuration                                   │
│                                                               │
└─────────────────────────────────────────────────────────────┘

DATA FLOW:

Active Directory ──> Candidate Discovery ──> Backlog Queue
                                                 │
                                                 ├──> Exchange Online (Mailbox Create)
                                                 │
                                                 └──> Permission Queue ──> ACL Groups
                                                 │
                                                 └──> Audit Log ──> Reports
```

### Tier 9: Integration Testing (Removed)

**Note:** Tier 9 (Integration Testing) was originally planned but **removed during Beta Phase** due to infrastructure constraints:
- **Constraint:** Accounts created only via IT-Shop (no direct AD creation)
- **Impact:** No non-production test environment available for isolated testing
- **Solution:** Mock-based testing in Tiers 1-8 validates core logic; Post-launch UAT with real infrastructure planned after deployment
- **Status:** Tier 9 testing replaced by production UAT phase (scheduled after v0.8.2 deployment)

This pragmatic decision maintains code quality while focusing on real-world validation post-launch.

### Data Storage

#### 1. Provisioning Queue (JSON)

**Location:** `$env:ProgramData\SharedMailboxProvisioner\data\mailbox-provisioning-queue.json`

**Structure:**
```json
[
  {
    "SamAccountName": "smbx_001",
    "DisplayName": "Finance Shared Mailbox",
    "Email": "finance@contoso.com",
    "Status": "SUCCESS",
    "CreatedAt": "2026-06-30 10:00:00",
    "CompletedAt": "2026-06-30 10:05:00",
    "RetryCount": 0,
    "MaxRetries": 5,
    "ErrorCode": null,
    "ErrorMessage": null
  }
]
```

#### 2. Audit Logs

**Location:** `$env:ProgramData\SharedMailboxProvisioner\Audit\audit-*.log`

**Format:**
```
[2026-06-30 10:00:00] [INFO] [smbx_001] [DISCOVERY] [SUCCESS] New candidate discovered
[2026-06-30 10:02:00] [INFO] [smbx_001] [MAILBOX_CREATE] [SUCCESS] Mailbox created in EXO
[2026-06-30 10:04:00] [INFO] [smbx_001] [PERMISSION] [SUCCESS] Permissions assigned
```

#### 3. Configuration

**Location:** `config/config.<Environment>.json` (e.g. `config/config.prod.json`), relative to the module root. Templated at `config/config.template.json`. Loaded via `_Get-Configuration -Environment <name>` (default environment: `dev`).

**Structure (real, flat schema - verified against `config/config.template.json` and `functions/Private/_Get-Configuration.ps1`):**
```json
{
  "Organization": "contoso.onmicrosoft.com",
  "AppId": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
  "CertificateThumbprint": "AB12CD34EF56AB12CD34EF56AB12CD34EF56AB12",
  "DefaultMailboxQuota": "50GB",
  "LogRetentionDays": 90,
  "MaxRetries": 5
}
```

**Note:** There is no `settings.json` file and no `$env:ProgramData\...\config\` directory in the current implementation. Keys such as `ScheduledTaskInterval`, `RetryDelaySeconds`, `BatchSize`, `AcceptedDomains`, `DefaultACLGroup`, `ServiceAccount`, and `AzureADConnectSyncWaitMinutes` are **not implemented** - they do not exist anywhere in the config schema or the code that reads it. If you need scheduled-task interval control, use `Set-MailboxProvisioningSchedule -Interval` (see [Installation & Deployment](#installation--deployment)) instead of editing a config file.

---

## Installation & Deployment

### Prerequisites

- Windows Server 2019+
- PowerShell 5.1+
- Active Directory access
- Exchange Online admin rights
- Local admin on ScheduledTask server

### Deployment Steps

#### Step 1: Install Module

```powershell
# From PowerShell Gallery (Stable)
Install-Module -Name SharedMailboxProvisioner -Repository PSGallery -Force

# Verify installation
Import-Module SharedMailboxProvisioner
Get-Command -Module SharedMailboxProvisioner | Measure-Object
# Should show 25+ functions
```

#### Step 2: Create Service Account

```powershell
# Create service account for ScheduledTask
$accountName = "svc-mailbox-provisioner"
$password = ConvertTo-SecureString "YourComplexPassword123!" -AsPlainText -Force

New-ADUser -Name $accountName -AccountPassword $password -Enabled $true `
           -PasswordNeverExpires $true -Description "SharedMailboxProvisioner Service Account"

# Grant required permissions
# - Exchange Online: Mail Administrator role
# - Active Directory: Group "Domain Admins" or custom read-only group
```

#### Step 3: Configure Directories

```powershell
# Create required directories
# NOTE: there is no "config" subdirectory here - the real config file
# (config/config.<Environment>.json) lives in the module's own repo tree,
# not under ProgramData. See "Configuration" below.
$basePath = "$env:ProgramData\SharedMailboxProvisioner"
New-Item -ItemType Directory -Path "$basePath\data" -Force
New-Item -ItemType Directory -Path "$basePath\Audit" -Force
New-Item -ItemType Directory -Path "$basePath\Errors" -Force
New-Item -ItemType Directory -Path "$basePath\Logs" -Force

# Set permissions (restrict to service account + admins)
icacls "$basePath" /grant "$(whoami):(OI)(CI)F" /inheritance:e
icacls "$basePath" /grant "ServiceAccount$:(OI)(CI)M" /inheritance:e
```

#### Step 4: Create ScheduledTask

**Important:** the module does not ship a ready-made wrapper script. `Invoke-SharedMailboxProvisioning` is a synchronous PowerShell function meant to be *the command a Scheduled Task runs*, but there is currently no `C:\Scripts\Invoke-MailboxProvisioning.ps1` (or equivalent) in the repository (confirmed - `scripts/` only contains `Provision-BulkMailboxesFromCSV.ps1` and `Initialize-ProvisioningConnections.ps1`). `Set-MailboxProvisioningSchedule` only **reconfigures the trigger interval of an already-existing task** - it does not create one. Until a wrapper ships, admins must create their own action script.

```powershell
# 1. Create a minimal action script that imports the module and calls the
#    real orchestrator. Save this as, e.g., C:\Scripts\Invoke-MailboxProvisioning.ps1
#    (path is your choice - just keep it consistent with the task action below).
#
#    Import-Module SharedMailboxProvisioner
#    Connect-ExchangeOnlineEnv -Tenant "contoso.onmicrosoft.com" -AppId "<app-id>" `
#      -CertificateThumbprint "<thumbprint>" -Environment "prod"
#    Invoke-SharedMailboxProvisioning

$taskName = "SharedMailboxProvisioning"
$scriptPath = "C:\Scripts\Invoke-MailboxProvisioning.ps1"   # your own script, see above

# 2. Create task action
$action = New-ScheduledTaskAction -Execute "powershell.exe" `
  -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`""

# 3. Create trigger (every 15 minutes)
$trigger = New-ScheduledTaskTrigger -RepetitionInterval (New-TimeSpan -Minutes 15) `
  -RepetitionDuration (New-TimeSpan -Days 365) -At "08:00" -Daily

# 4. Register task (this is the "already-existing task" that Set-MailboxProvisioningSchedule
#    expects to find later)
Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger `
  -RunLevel Highest -User "DOMAIN\$accountName" -Password $password

# 5. Once the task exists, use Set-MailboxProvisioningSchedule to adjust its
#    interval or enable/disable state going forward - it will NOT create the
#    task for you if it's missing.
Set-MailboxProvisioningSchedule -TaskName $taskName -Interval 30
```

#### Step 5: Configure Azure AD Connect Sync

```powershell
# Verify sync schedule (typically 30 minutes)
Get-ADSyncScheduler

# Manual sync trigger (if needed)
Start-ADSyncSyncCycle -PolicyType Delta
```

### Deployment Verification

```powershell
# Run all health checks
Get-MailboxProvisioningHealth -CheckAll

# Test candidate discovery
$candidates = Get-SharedMailboxCandidates -SamAccountNamePrefix "smbx_"
Write-Output "Found $($candidates.Count) candidates"

# Verify ScheduledTask
Get-ScheduledTask -TaskName "SharedMailboxProvisioning" | 
  Select-Object TaskName, State, LastTaskResult, LastRunTime
```

---

## Configuration

### Global Settings

**File:** `config/config.<Environment>.json` (e.g. `config/config.prod.json`), loaded via `_Get-Configuration -Environment <name>`. There is no `$env:ProgramData\...\config\settings.json` file - see [Data Storage - Configuration](#3-configuration) above for the real, verified schema.

```json
{
  "Organization": "contoso.onmicrosoft.com",   // Tenant / org name
  "AppId": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
  "CertificateThumbprint": "AB12CD34EF56AB12CD34EF56AB12CD34EF56AB12",
  "DefaultMailboxQuota": "50GB",
  "LogRetentionDays": 90,
  "MaxRetries": 5
}
```

The following keys appear in older/draft documentation but are **not implemented** anywhere in the current schema or code: `ScheduledTaskInterval`, `RetryDelaySeconds`, `BatchSize`, `AcceptedDomains`, `DefaultACLGroup`, `ServiceAccount`, `AzureADConnectSyncWaitMinutes`. Do not rely on them.

### Candidate Criteria

Modify discovery criteria in Get-SharedMailboxCandidates (real parameters - there is no `-Filter` parameter):

```powershell
# Default: SamAccountName starts with "smbx_"
$candidates = Get-SharedMailboxCandidates -SamAccountNamePrefix "smbx_"

# Custom criteria
$candidates = Get-SharedMailboxCandidates `
    -SamAccountNamePrefix "smbx_" `
    -DescriptionStartsWith "Shared Mailbox Persona" `
    -CustomAttribute "extensionAttribute1" -CustomAttributeValue "Finance" `
    -AccountStatus Enabled
```

### Logging Configuration

**Levels:** INFO, WARN, ERROR  
**Output:** File + Event Log (optional)

```powershell
# Set log level (via PowerShell)
$env:LOG_LEVEL = "DEBUG"  # or INFO, WARN, ERROR

# View logs
Get-Content "$env:ProgramData\SharedMailboxProvisioner\Logs\*.log" -Tail 100
```

---

## Performance Tuning

### Batch Processing

```powershell
# Adjust batch size based on server resources
# Default: 10 mailboxes per batch
# Recommended: 5-20 depending on network/storage

# Edit in code:
$batchSize = 10  # Modify in Invoke-SharedMailboxProvisioning
```

### ScheduledTask Timing

```powershell
# Adjust interval for different load requirements
# Every 15 min (default):  More responsive, higher CPU
# Every 30 min:           Balanced
# Every 60 min:           Minimal impact, less responsive

# Use the module's own cmdlet - it only reconfigures an EXISTING task's
# trigger, it does not create the task (see "Installation & Deployment" Step 4)
Set-MailboxProvisioningSchedule -TaskName "SharedMailboxProvisioning" -Interval 30
```

### Retry Strategy

```powershell
# Adjust retry behavior
$maxRetries = 5         # Increase for unreliable networks
$retryDelay = 300       # Seconds (5 min = 300 sec)
$maxRetryDelay = 3600   # Max delay 1 hour

# Exponential backoff
# Attempt 1: Immediate
# Attempt 2: 5 minutes
# Attempt 3: 10 minutes
# Attempt 4: 20 minutes
# Attempt 5: 40 minutes
```

### Resource Monitoring

```powershell
# Monitor performance metrics
$metrics = Get-MailboxProvisioningMetrics

# Check:
# - Success Rate (target: >95%)
# - Avg Time per Mailbox (target: <5 min)
# - Retry Ratio (target: <5%)
# - CPU/Memory usage during runs
```

---

## Monitoring & Alerting

### Health Checks

**Caveat - EXO check reliability:** the `CheckEXO` component of `Get-MailboxProvisioningHealth` relies on a `Get-PSSession`/`ConfigurationName -eq "Microsoft.Exchange"` marker that EXO-V3 REST-based sessions do not set (open, tracked defect - see [Troubleshooting - EXO Connection Failures](#exo-connection-failures)). A "DEGRADED" overall status driven purely by the EXO sub-check may be a false positive. For P0/incident use, cross-check with a live cmdlet call (e.g. `Get-ETHMailbox -ResultSize 1`) before paging anyone based on this alone.

```powershell
# Daily health check
$health = Get-MailboxProvisioningHealth -CheckAll

# Alert if degraded
if ($health.OverallStatus -eq "DEGRADED") {
    # Send alert to admins
    Send-MailMessage -To "admins@contoso.com" `
      -Subject "Mailbox Provisioner Health Alert" `
      -Body "Issues: $($health.Issues -join ', ')"
}
```

### Metrics Monitoring

```powershell
# Track KPIs
$metrics = Get-MailboxProvisioningMetrics

# Alert conditions:
if ($metrics.SuccessRate -lt 0.90) { Write-Warning "Success rate low" }
if ($metrics.AvgTimeToCompletion -gt 600) { Write-Warning "Provisioning slow" }
if ($metrics.RetryRatio -gt 0.10) { Write-Warning "High retry rate" }
```

### Event Log Integration

```powershell
# Create custom event log source
New-EventLog -LogName "SharedMailboxProvisioner" `
  -Source "Provisioning" -ErrorAction SilentlyContinue

# Log events
Write-EventLog -LogName "SharedMailboxProvisioner" `
  -Source "Provisioning" -EventId 1000 -Message "Provisioning started"
```

### Reporting Schedule

```powershell
# Generate daily reports
$reportPath = "$env:ProgramData\SharedMailboxProvisioner\Reports"
New-Item -ItemType Directory -Path $reportPath -Force

# Daily (8 AM)
Get-MailboxProvisioningReport | 
  Export-MailboxAuditLog -Format HTML -OutputPath "$reportPath\daily-report.html"

# Weekly (Sundays)
# Monthly (1st of month)
```

---

## Troubleshooting

### ScheduledTask Not Running

```powershell
# Check task state
Get-ScheduledTask -TaskName "SharedMailboxProvisioning" | Select-Object State

# Check last run result
Get-ScheduledTaskInfo -TaskName "SharedMailboxProvisioning" | Select-Object LastTaskResult

# Enable task if disabled
Enable-ScheduledTask -TaskName "SharedMailboxProvisioning"

# Manually run for testing
Start-ScheduledTask -TaskName "SharedMailboxProvisioning"
```

### EXO Connection Failures

**Caveat:** `Get-MailboxProvisioningHealth -CheckEXO` looks for an active `Get-PSSession` with `ConfigurationName -eq "Microsoft.Exchange"` - a classic remoting marker. Modern EXO-V3 REST-based `Connect-ExchangeOnline`/`Connect-ExchangeOnlineEnv` sessions do **not** set this marker, so this check can report "DISCONNECTED" even when the connection is healthy (open, unfixed, tracked issue - see PROJECT-TRACKING.md). Do not treat it as the sole signal; cross-check with a real EXO cmdlet call.

```powershell
# Reconnect
Connect-ExchangeOnlineEnv

# Test connection - more reliable than Get-MailboxProvisioningHealth -CheckEXO
# (adjust cmdlet noun to your configured -Prefix, default "ETH")
try {
    Get-ETHMailbox -ResultSize 1 -ErrorAction Stop | Out-Null
    Write-Output "[OK] EXO connection confirmed via live cmdlet call"
}
catch {
    Write-Warning "EXO connection failed: $_"
}

# Check service status
Test-NetConnection -ComputerName outlook.office365.com -Port 443
```

### Performance Issues

```powershell
# Check server resources
Get-Process powershell | Measure-Object -Property WorkingSet -Sum

# Reduce batch size
$batchSize = 5  # From default 10

# Increase ScheduledTask interval
# From 15 min to 30 min (reduces frequency)
```

### Audit Log Issues

```powershell
# Verify audit directory
Test-Path "$env:ProgramData\SharedMailboxProvisioner\Audit"

# Check disk space
Get-Volume C: | Select-Object DriveLetter, SizeRemaining

# Archive old logs
Get-ChildItem "$env:ProgramData\SharedMailboxProvisioner\Audit\*.log" -OlderThan (Get-Date).AddDays(-90) | 
  Remove-Item
```

---

## Disaster Recovery

### Backup Strategy

```powershell
# Backup critical files
$backupPath = "\\fileserver\backups\mailbox-provisioner"
Copy-Item -Path "$env:ProgramData\SharedMailboxProvisioner" `
  -Destination $backupPath -Recurse -Force

# Also back up the real config file separately - it lives in the module's
# repo tree, not under ProgramData:
Copy-Item -Path "config\config.prod.json" -Destination "$backupPath\config.prod.json" -Force

# Include:
# - data/mailbox-provisioning-queue.json (state)
# - config/config.<Environment>.json (configuration - NOT under ProgramData)
# - Audit/audit-*.log (audit trail)
```

**Important - hardcoded path defaults:** `New-SharedMailboxRemote -BacklogPath` and `-CredentialPath` default to `C:\Repos\SharedMailboxProvisioner\data\mailbox-provisioning-queue.json` and `C:\Repos\SharedMailboxProvisioner\data\serviceaccount.clixml` respectively - a source-checkout path that will not match most real deployments. Always pass explicit `-BacklogPath`/`-CredentialPath` values matching your actual deployment location (e.g. under `$env:ProgramData\SharedMailboxProvisioner\data\`) rather than relying on these defaults; otherwise backup/recovery paths documented here will silently diverge from what the code is actually reading and writing.

### Recovery Procedures

#### Scenario 1: Backlog Corruption

```powershell
# 1. Restore from backup
Copy-Item -Path "\\fileserver\backups\mailbox-provisioner\data\*" `
  -Destination "$env:ProgramData\SharedMailboxProvisioner\data" -Force

# 2. Verify integrity
$backlog = Get-Content "$env:ProgramData\SharedMailboxProvisioner\data\mailbox-provisioning-queue.json" | 
  ConvertFrom-Json
$backlog | Measure-Object  # Should show count

# 3. Resume provisioning
Invoke-SharedMailboxProvisioning
```

#### Scenario 2: ScheduledTask Removed

```powershell
# Recreate task from backup config
# See "Installation & Deployment - Step 4" above

# Verify restoration
Get-ScheduledTask -TaskName "SharedMailboxProvisioning"
```

#### Scenario 3: Service Account Compromised

```powershell
# 1. Disable compromised account
Disable-ADAccount -Identity "svc-mailbox-provisioner"

# 2. Create new service account
# See "Installation & Deployment - Step 2"

# 3. Update ScheduledTask with new account
# See "Installation & Deployment - Step 4"

# 4. Force password reset next logon
Set-ADUser -Identity "svc-mailbox-provisioner" -PasswordNotRequired $false
```

---

## Security Considerations

### Service Account Permissions

**Minimum required:**

```
Active Directory:
  - Read all user objects
  - Read all group objects
  - Member of: Group to modify (for permission assignment)

Exchange Online:
  - Mail Administrator role
  - Mailbox management rights
  - Permission management
```

### Network Security

- **SSL/TLS:** All connections encrypted
- **Authentication:** Azure AD, Multi-Factor Authentication
- **IP Whitelisting:** Optional for ScheduledTask server

### Credential Management

**Note:** `New-SharedMailboxRemote`'s on-premises PSSession helper (`_GetExchangePSSession`) has a "current user context" auto-detect path that reads `$config.exchange.onPremises.uri` - a nested shape the real flat config schema (`Organization`/`AppId`/`CertificateThumbprint`/...) never produces. In practice this path silently falls through, so **credential-file-based auth (`-CredentialPath`, a `.clixml` file created via `scripts/Initialize-ProvisioningConnections.ps1`) is effectively the only auth path that currently works reliably** - do not treat current-user-context auth as an equally-viable fallback.

```powershell
# Service account password storage
# Best practice: Use Credential Manager or Key Vault
# NOT hardcoded in scripts

# Azure Key Vault (recommended for Azure environments)
$credential = Get-AzKeyVaultSecret -VaultName "mailbox-provisioner" `
  -Name "service-account"
```

### Audit Trail

```powershell
# All operations logged to audit files
# Includes: Who, What, When, Why, Result

# Retention: 90 days default
# Archive older logs to comply with retention policies

# Tamper detection:
$originalHash = (Get-FileHash "audit-2026-06-30.log").Hash
$currentHash = (Get-FileHash "audit-2026-06-30.log").Hash
if ($originalHash -ne $currentHash) { Write-Warning "Audit log modified" }
```

### Encryption

- **In Transit:** TLS 1.2+ (all external connections)
- **At Rest:** Backlog stored unencrypted (JSON) - can be encrypted if needed
- **Credentials:** Never stored in plaintext

---

## Support & Maintenance

**Update Schedule:** Quarterly security updates  
**Monitoring:** Daily health checks recommended  
**Backup Frequency:** Daily  
**Log Retention:** 90 days

---

**Document Version:** 1.1 | **Last Updated:** 2026-07-01
