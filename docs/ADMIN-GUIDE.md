# SharedMailboxProvisioner - Administrator Guide

**Version:** 1.12.0 | **Status:** Production Ready  
**Last Updated:** 2026-06-30

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
│  ├─ Domain verification (AcceptedDomains)                    │
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

**Location:** `$env:ProgramData\SharedMailboxProvisioner\config\settings.json`

**Structure:**
```json
{
  "ScheduledTaskInterval": 15,
  "MaxRetries": 5,
  "RetryDelaySeconds": 300,
  "BatchSize": 10,
  "LogRetentionDays": 90,
  "AcceptedDomains": ["contoso.com", "contoso.onmicrosoft.com"]
}
```

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
$basePath = "$env:ProgramData\SharedMailboxProvisioner"
New-Item -ItemType Directory -Path "$basePath\data" -Force
New-Item -ItemType Directory -Path "$basePath\Audit" -Force
New-Item -ItemType Directory -Path "$basePath\config" -Force
New-Item -ItemType Directory -Path "$basePath\Logs" -Force

# Set permissions (restrict to service account + admins)
icacls "$basePath" /grant "$(whoami):(OI)(CI)F" /inheritance:e
icacls "$basePath" /grant "ServiceAccount$:(OI)(CI)M" /inheritance:e
```

#### Step 4: Create ScheduledTask

```powershell
# Register automatic provisioning task
$taskName = "SharedMailboxProvisioning"
$scriptPath = "C:\Scripts\Invoke-MailboxProvisioning.ps1"

# Create task action
$action = New-ScheduledTaskAction -Execute "powershell.exe" `
  -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`""

# Create trigger (every 15 minutes)
$trigger = New-ScheduledTaskTrigger -RepetitionInterval (New-TimeSpan -Minutes 15) `
  -RepetitionDuration (New-TimeSpan -Days 365) -At "08:00" -Daily

# Register task
Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger `
  -RunLevel Highest -User "DOMAIN\$accountName" -Password $password
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
$candidates = Get-SharedMailboxCandidates -Filter "SamAccountName -like 'smbx_*'"
Write-Output "Found $($candidates.Count) candidates"

# Verify ScheduledTask
Get-ScheduledTask -TaskName "SharedMailboxProvisioning" | 
  Select-Object TaskName, State, LastTaskResult, LastRunTime
```

---

## Configuration

### Global Settings

**File:** `$env:ProgramData\SharedMailboxProvisioner\config\settings.json`

```json
{
  "ScheduledTaskInterval": 15,           // Minutes between runs
  "MaxRetries": 5,                       // Max retry attempts per mailbox
  "RetryDelaySeconds": 300,              // Delay between retries (5 min)
  "BatchSize": 10,                       // Mailboxes per batch
  "LogRetentionDays": 90,                // Keep logs for 90 days
  "AcceptedDomains": [
    "contoso.com",
    "contoso.onmicrosoft.com"
  ],
  "DefaultACLGroup": "IT_SharedMailbox_Admins",
  "ServiceAccount": "DOMAIN\\svc-mailbox-provisioner",
  "AzureADConnectSyncWaitMinutes": 60
}
```

### Candidate Criteria

Modify discovery criteria in Get-SharedMailboxCandidates:

```powershell
# Default: SamAccountName starts with "smbx_"
$candidates = Get-SharedMailboxCandidates -Filter "SamAccountName -like 'smbx_*'"

# Custom criteria
$candidates = Get-SharedMailboxCandidates -Filter @{
    SamAccountName = "smbx_*"
    Department = "Finance"
    Country = "US"
}
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

# Change via PowerShell
$task = Get-ScheduledTask -TaskName "SharedMailboxProvisioning"
$trigger = $task.Triggers[0]
$trigger.Repetition.Interval = "PT30M"  # 30 minutes
Set-ScheduledTask -TaskName $task.TaskName -Trigger $trigger
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

```powershell
# Reconnect
Connect-ExchangeOnlineEnv

# Test connection
Get-Mailbox -ResultSize 1

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

# Include:
# - data/mailbox-provisioning-queue.json (state)
# - config/settings.json (configuration)
# - Audit/audit-*.log (audit trail)
```

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

**Document Version:** 1.0 | **Last Updated:** 2026-06-30
