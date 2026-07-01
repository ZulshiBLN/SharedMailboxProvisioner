# SharedMailboxProvisioner - User Guide

**Version:** v0.9.0-beta.1 | **Status:** Pre-Release Phase - Real-World Testing & Validation
**Last Updated:** 2026-07-01

---

## Table of Contents

1. [Introduction](#introduction)
2. [Installation & Setup](#installation--setup)
3. [Getting Started](#getting-started)
4. [Core Workflows](#core-workflows)
5. [Manual Bulk Import](#manual-bulk-import)
6. [Monitoring & Status](#monitoring--status)
7. [Troubleshooting](#troubleshooting)
8. [FAQ](#faq)

---

## Introduction

SharedMailboxProvisioner is an automated tool for discovering and provisioning shared mailboxes in Exchange Online based on Active Directory criteria. It supports both automatic discovery (via ScheduledTask) and manual bulk import workflows.

### What It Does

- **Discovers** eligible user accounts in AD matching shared mailbox criteria
- **Provisions** mailboxes in Exchange Online
- **Assigns** permissions to ACL groups
- **Tracks** all operations in audit logs
- **Reports** on provisioning metrics and health

### Supported Environments

- **Windows Server:** 2019, 2022, 2025
- **PowerShell:** 5.1 (built-in), 7.x (optional)
- **Exchange Online:** Modern (EXO v3 module)
- **Active Directory:** Windows Server 2019+

### Key Features

✓ Automatic candidate discovery via AD queries  
✓ Manual bulk import from CSV  
✓ Comprehensive audit logging  
✓ Detailed reporting & metrics  
✓ Operational monitoring & health checks  
✓ Failure diagnostics & retry logic  

---

## Installation & Setup

### Prerequisites

1. **Exchange Online access** with admin rights
2. **Active Directory** read access
3. **PowerShell 5.1+** installed
4. **ExchangeOnlineManagement module** (auto-installed)

### Step 1: Download & Install

```powershell
# From PowerShell Gallery
Install-Module -Name SharedMailboxProvisioner -Repository PSGallery

# Or from GitHub (pre-release versions)
git clone https://github.com/yourusername/SharedMailboxProvisioner.git
cd SharedMailboxProvisioner
Import-Module .\SharedMailboxProvisioner.psd1
```

### Step 2: Connect to Exchange Online

```powershell
# Connects using Tenant/AppId/CertificateThumbprint resolved from config.dev.json
# (set up via scripts/Initialize-ProvisioningConnections.ps1)
$connected = Connect-ExchangeOnlineEnv

# Or specify the tenant explicitly (interactive auth)
$connected = Connect-ExchangeOnlineEnv -Tenant "contoso.onmicrosoft.com"

# Connect-ExchangeOnlineEnv returns a boolean, not a PSSession object
if ($connected) {
    Write-Output "Connected"
}
```

### Step 3: Configure AD Criteria

Define which users should be provisioned. By default, the tool looks for:
- **SamAccountName prefix:** `smbx_` (e.g., `smbx_001`) - override via `-SamAccountNamePrefix`
- **Search base (OU):** Specify via `-SearchBase`; defaults to the entire domain
- **Custom attributes:** Via `-CustomAttribute` / `-CustomAttributeValue` parameters

### Step 4: Test Connection

```powershell
# Test system health
Get-MailboxProvisioningHealth -CheckAll

# Expected output:
# CheckTime       : 2026-07-01 14:30:45
# OverallStatus   : HEALTHY
# Issues          : {}
# Details         : {Active Directory: CONNECTED, Exchange Online: CONNECTED, ScheduledTask: RUNNING}
```

**Caution:** The `-CheckEXO` check looks for a classic remoting `Get-PSSession` marker that modern EXO-V3 REST-based connections do not reliably set. It can report `DISCONNECTED` even when `Connect-ExchangeOnlineEnv` succeeded. Do not treat it as authoritative on its own.

---

## Getting Started

### Quick Start: Single Mailbox

```powershell
# 1. Discover candidates matching default criteria (SamAccountNamePrefix "smbx_")
$candidates = Get-SharedMailboxCandidatesWithGroups

# 2. View candidate details
$candidates | Format-Table SamAccountName, Mail, ACLGroupName -AutoSize

# 3. Provision a single mailbox (real mandatory params: SamAccountName, DisplayName,
#    PrimarySmtpAddress, RemoteRoutingAddress, ACLGroupName - there is no -Email param)
$candidate = $candidates[0]
New-SharedMailboxRemote -SamAccountName $candidate.SamAccountName `
                        -DisplayName $candidate.DisplayName `
                        -PrimarySmtpAddress $candidate.Mail `
                        -RemoteRoutingAddress "$($candidate.SamAccountName)@ethz.mail.onmicrosoft.com" `
                        -ACLGroupName $candidate.ACLGroupName

# 4. Assign permissions - processes the ENTIRE backlog queue in one call,
#    not a single mailbox/group pair (no -MailboxEmail / -ACLGroupName params exist)
Invoke-MailboxPermissionQueue

# 5. Check status
Get-MailboxProvisioningStatus -SamAccountName $candidate.SamAccountName
```

### Quick Start: Automatic Provisioning

```powershell
# Trigger automatic discovery & provisioning (no -Filter, -TargetOU, or -DryRun params exist)
$result = Invoke-SharedMailboxProvisioning

# Expected workflow:
# 1. Discovers candidates in AD (with valid ACL groups)
# 2. Creates remote mailboxes on-premises
# 3. Assigns permissions from groups (unless -SkipPermissionQueue $true)
# 4. Prints a summary to output
# 5. Returns a summary object
```

### Output Example

Fields shown are the actual return object properties from `Invoke-SharedMailboxProvisioning`:

```
CandidatesFound      : 5
MailboxesCreated     : 4
MailboxesFailed      : 1
PermissionsAssigned  : 4
PermissionsRetrying  : 0
PermissionsFailed    : 0
Duration             : 00:02:15
Summary              : Created 4/5 mailboxes, assigned 4 permissions
```

---

## Core Workflows

### Workflow 1: Automatic Discovery (Scheduled)

**Trigger:** ScheduledTask every 15 minutes (configurable)

```powershell
# Workflow steps:
1. Connect to Exchange Online
2. Query Active Directory for candidates (SamAccountName = smbx_*)
3. Check if mailbox already exists
4. Create mailbox if new
5. Process permission queue
6. Log results to audit trail
7. Send report (optional)
```

**Monitoring:**

```powershell
# Check last run
Get-ScheduledTask -TaskName "SharedMailboxProvisioning" | 
  Select-Object -ExpandProperty LastTaskResult

# View audit log
Get-Content -Path "$env:ProgramData\SharedMailboxProvisioner\Audit\audit-*.log" -Tail 100
```

### Workflow 2: Manual Bulk Import (CSV)

**Trigger:** Admin runs script manually  
**Use Case:** One-time migration, testing, special cases

```powershell
# 1. Prepare CSV file (see CSV Format below)
# 2. Run bulk import script
& ".\scripts\Provision-BulkMailboxesFromCSV.ps1" -CsvPath "C:\candidates.csv" -DryRun

# 3. Review dry-run report
# 4. Confirm provisioning
& ".\scripts\Provision-BulkMailboxesFromCSV.ps1" -CsvPath "C:\candidates.csv" -Confirm

# 5. Monitor provisioning progress
Get-MailboxProvisioningStatus -BacklogPath "data\mailbox-provisioning-queue.json"
```

### CSV Format

```csv
SamAccountName,DisplayName,Email,ACLGroup,AdminGroup,Description
smbx_001,Shared Mailbox 001,smbx001@contoso.com,IT_SharedMailbox_Admins,,Department Finance
smbx_002,Shared Mailbox 002,smbx002@contoso.com,IT_SharedMailbox_Admins,ADMINS_002,Department HR
smbx_003,Shared Mailbox 003,smbx003@contoso.com,SEC_SharedMailbox_Admins,,Department Security
```

**Column Details:**

| Column | Required | Description |
|--------|----------|-------------|
| SamAccountName | YES | AD account name (must have smbx_ prefix) |
| DisplayName | YES | User-friendly name for mailbox |
| Email | YES | Email address (must be valid format) |
| ACLGroup | NO | AD group for permissions |
| AdminGroup | NO | Additional admin group |
| Description | NO | Purpose/notes |

---

## Manual Bulk Import

### When to Use

- **One-time migrations:** Moving existing mailboxes
- **Testing:** Before full rollout
- **Special cases:** Different ACL groups, custom configs
- **Batch operations:** 10-100 mailboxes at once

### Step-by-Step

#### Step 1: Prepare CSV

```powershell
# Create candidates.csv with required columns
@(
    @{ SamAccountName = "smbx_001"; DisplayName = "Finance"; Email = "finance@contoso.com"; ACLGroup = "FINANCE_ADMINS" },
    @{ SamAccountName = "smbx_002"; DisplayName = "HR"; Email = "hr@contoso.com"; ACLGroup = "HR_ADMINS" }
) | Export-Csv "C:\candidates.csv" -NoTypeInformation
```

#### Step 2: Import and Validate CSV

```powershell
# Import-MailboxCandidatesFromCSV always validates each row - there is no -DryRun switch.
# Note the capital "S" in -CSVPath.
$import = Import-MailboxCandidatesFromCSV -CSVPath "C:\candidates.csv"

Write-Output "Valid: $($import.SuccessCount), Invalid: $($import.FailureCount)"
```

#### Step 3: Preview Impact (dry-run, no provisioning)

```powershell
# Test-MailboxBulkImport takes an array of already-imported candidate objects via
# -Candidates (not a CSV path). This step performs no provisioning.
$impact = Test-MailboxBulkImport -Candidates $import.Candidates

Write-Output "Can proceed: $($impact.CanProceed)"
Write-Output "Valid: $($impact.ValidCandidates.Count), Conflicts: $($impact.ConflictingCandidates)"

# Output: HTML preview report saved to $env:TEMP\bulk-import-preview-<timestamp>.html by default
# (or wherever -ReportPath points)
```

#### Step 4: Execute

```powershell
# Provisioning itself happens per-candidate via New-SharedMailboxRemote, then permissions
# via Invoke-MailboxPermissionQueue. There is no single "execute the CSV" function -
# Import-MailboxCandidatesFromCSV only imports/validates, it does not provision.
foreach ($candidate in $impact.ValidCandidates) {
    New-SharedMailboxRemote -SamAccountName $candidate.SamAccountName `
        -DisplayName $candidate.DisplayName `
        -PrimarySmtpAddress $candidate.Email `
        -RemoteRoutingAddress "$($candidate.SamAccountName)@ethz.mail.onmicrosoft.com" `
        -ACLGroupName $candidate.ACLGroup
}

Invoke-MailboxPermissionQueue
```

### Monitoring Progress

```powershell
# Check provisioning status
Get-MailboxProvisioningStatus

# Get detailed status for specific mailbox
Get-MailboxProvisioningStatus -SamAccountName "smbx_001" -ShowTimeline

# Output:
# SamAccountName   : smbx_001
# DisplayName      : Finance Shared Mailbox
# Email            : finance@contoso.com
# CurrentStatus    : SUCCESS
# RetryCount       : 0
# CreatedAt        : 2026-07-01 10:00:00
# CompletedAt      : 2026-07-01 10:05:00
# Timeline         : [CREATED] 10:00:00 > [RETRIED] ... > [COMPLETED] 10:05:00
```

### Error Recovery

```powershell
# Diagnose all failures - simply omit -SamAccountName (the default behavior already
# analyzes every failed entry; -DiagnoseAll is accepted but currently adds nothing extra)
Resolve-MailboxProvisioningFailure

# Output shows:
# - Failed mailbox names
# - Reason for failure
# - Whether retryable (.CanRetry)
# - Recommended action (.RecommendedAction)

# Retry all failed mailboxes (respecting the max retry limit)
Invoke-MailboxProvisioningRetry -RetryAll

# Or retry a specific mailbox
Invoke-MailboxProvisioningRetry -SamAccountName "smbx_001"
```

---

## Monitoring & Status

### Real-Time Status

```powershell
# Check system health
Get-MailboxProvisioningHealth -CheckAll

# Output:
# OverallStatus: HEALTHY
# Details:
#   - Active Directory: CONNECTED
#   - Exchange Online: CONNECTED
#   - ScheduledTask: RUNNING
```

**Caution:** The Exchange Online check relies on a classic remoting `Get-PSSession` marker that modern EXO-V3 REST-based connections do not reliably set. It can report the connection as `DISCONNECTED` even when it is actually fine - do not treat this check alone as authoritative, especially during incident response.

### Provisioning Metrics

```powershell
# Get KPI metrics
Get-MailboxProvisioningMetrics

# Output shows:
# - Success Rate: 95.2%
# - Avg Time to Completion: 3m 45s
# - Retry Ratio: 2.1%
# - Common Errors: [Top 5]
# - Trend Analysis: [Last 7, 14, 30 days]
```

### Audit Reports

```powershell
# Generate HTML report (Format and OutputPath are both optional; Format defaults to HTML)
Export-MailboxAuditLog -Format HTML -OutputPath "C:\report.html"

# Generate CSV for analysis, errors only
Export-MailboxAuditLog -Format CSV -OutputPath "C:\audit.csv" -FilterStatus "ERROR"

# Filter by date range
Export-MailboxAuditLog -StartDate "2026-06-24" -EndDate "2026-07-01" -Format HTML -OutputPath "C:\report.html"

# Omit -OutputPath to get the formatted content back as a string instead of writing a file
$html = Export-MailboxAuditLog -Format HTML
```

---

## Troubleshooting

### Common Issues

#### Issue 1: "Mailbox not found in EXO"

**Symptom:** Mailbox created locally but not visible in Exchange Online

**Cause:** Azure AD Connect sync delay (up to 60 minutes)

**Solution:**
```powershell
# Wait for sync
Start-Sleep -Seconds 3600  # Wait 60 minutes

# Check Azure AD Connect health
Get-ADSyncScheduler

# Manually trigger sync (if available)
Start-ADSyncSyncCycle -PolicyType Delta

# Then retry
Invoke-MailboxProvisioningRetry -SamAccountName "smbx_001"
```

#### Issue 2: "Permission denied on ACL group"

**Symptom:** Mailbox created but permissions fail

**Cause:** Service account lacks group modification rights

**Solution:**
```powershell
# Verify service account permissions
Get-ADGroup "IT_SharedMailbox_Admins" | Add-ADGroupMember -Members "ServiceAccount$" -Confirm:$false

# Retry provisioning
Invoke-MailboxProvisioningRetry -SamAccountName "smbx_001"
```

#### Issue 3: "Invalid email format"

**Symptom:** CSV import fails for specific candidates

**Cause:** Email column has invalid format

**Solution:**
```powershell
# Validate email format
$email = "smbx001@contoso.com"
[Net.Mail.MailAddress]::new($email)  # Throws if invalid

# Fix CSV and retry
```

### Debug Mode

```powershell
# Enable verbose logging
$VerbosePreference = "Continue"

# Run with verbose output
Invoke-SharedMailboxProvisioning -Verbose

# Check detailed logs
Get-Content -Path "$env:ProgramData\SharedMailboxProvisioner\Logs\provisioning-*.log" -Tail 50
```

---

## FAQ

**Q: How often does automatic provisioning run?**  
A: Every 15 minutes (configurable via ScheduledTask)

**Q: Can I change the SamAccountName prefix from "smbx_"?**  
A: Yes, pass the `-SamAccountNamePrefix` parameter to `Get-SharedMailboxCandidates` (there is no `-Filter` parameter)

**Q: What if I have 1000 candidates to import?**  
A: Use bulk import with batch processing. Tool handles up to 100 at a time.

**Q: How long does provisioning take per mailbox?**  
A: 3-5 minutes on average (includes AD sync wait)

**Q: Can I rollback a provisioned mailbox?**  
A: Not automatically. Contact IT to manually remove from Exchange Online.

**Q: What permissions do I need to run this?**  
A: Exchange Online admin + AD reader + local admin on ScheduledTask server

**Q: Is there a trial/test mode?**  
A: Yes, `Test-MailboxBulkImport -Candidates $import.Candidates` validates a batch and reports impact without provisioning anything (`-GenerateReport` defaults to `$true` and produces an HTML preview)

**Q: How do I monitor provisioning remotely?**  
A: Use `Get-MailboxProvisioningStatus` and `Get-MailboxProvisioningHealth` from any admin PC

---

## Support & Contact

For issues, questions, or feedback:
- **GitHub Issues:** https://github.com/yourusername/SharedMailboxProvisioner/issues
- **Documentation:** See ADMIN-GUIDE.md for advanced topics
- **Operational Guide:** See OPERATIONS-RUNBOOK.md for daily operations

---

**Document Version:** 1.0 | **Last Updated:** 2026-07-01
