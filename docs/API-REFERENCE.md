# SharedMailboxProvisioner - API Reference

**Version:** 1.12.0 | **Status:** Production Ready  
**Last Updated:** 2026-06-30

Complete reference for all public functions in SharedMailboxProvisioner module.

---

## Table of Contents

- [Connection Functions](#connection-functions)
- [Discovery & Validation](#discovery--validation)
- [Provisioning Functions](#provisioning-functions)
- [Bulk Import Functions](#bulk-import-functions)
- [Reporting Functions](#reporting-functions)
- [Operational Functions](#operational-functions)

---

## Connection Functions

### Connect-ExchangeOnlineEnv

Establish connection to Exchange Online with proper error handling.

**Syntax:**
```powershell
Connect-ExchangeOnlineEnv [[-ExchangeEnvironmentName] <String>] [-Verbose]
```

**Parameters:**

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| ExchangeEnvironmentName | String | No | "O365Default" | Exchange environment (O365Default, O365GermanyCloud, etc.) |

**Return:** PSSession object

**Example:**
```powershell
# Standard connection
Connect-ExchangeOnlineEnv

# Verify connection
Get-PSSession | Where-Object { $_.ConfigurationName -eq "Microsoft.Exchange" }
```

**Notes:**
- Prompts for MFA if required
- Auto-installs ExchangeOnlineManagement module if missing
- Typically takes 10-15 seconds

---

## Discovery & Validation

### Get-SharedMailboxCandidates

Query Active Directory for eligible shared mailbox candidates.

**Syntax:**
```powershell
Get-SharedMailboxCandidates [-Filter] <String> [-OrganizationalUnit] <String> [-Verbose]
```

**Parameters:**

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| Filter | String | No | "SamAccountName -like 'smbx_*'" | AD filter expression |
| OrganizationalUnit | String | No | Entire domain | OU path to search |

**Return:** Array of candidate objects with properties: SamAccountName, DisplayName, Email, Department, Manager

**Example:**
```powershell
# All smbx_ candidates
$candidates = Get-SharedMailboxCandidates

# Finance department only
$candidates = Get-SharedMailboxCandidates -Filter "SamAccountName -like 'smbx_*' -and Department -eq 'Finance'"

# Specific OU
$candidates = Get-SharedMailboxCandidates -OrganizationalUnit "OU=Finance,DC=contoso,DC=com"

# Get count
$candidates | Measure-Object
```

**Notes:**
- Returns only non-disabled users
- Filters by email validation (RFC 5321)
- Requires AD read permissions

---

### Get-SharedMailboxCandidatesWithGroups

Get candidates with validated ACL group membership.

**Syntax:**
```powershell
Get-SharedMailboxCandidatesWithGroups [-Filter] <String> [-Verbose]
```

**Return:** Array with additional group information

**Example:**
```powershell
$candidates = Get-SharedMailboxCandidatesWithGroups

# View groups
$candidates | Select-Object SamAccountName, ACLGroup, AdminGroup
```

---

### Get-SharedMailboxACLGroup

Retrieve and validate an ACL group for permission assignment.

**Syntax:**
```powershell
Get-SharedMailboxACLGroup [-GroupName] <String> [-Verbose]
```

**Parameters:**

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| GroupName | String | Yes | AD group name |

**Return:** Group object with members

**Example:**
```powershell
# Get group
$group = Get-SharedMailboxACLGroup -GroupName "IT_SharedMailbox_Admins"

# Check members
$group | Select-Object Name, Members
```

---

### Test-SharedMailboxCandidate

Comprehensive validation of user account for provisioning.

**Syntax:**
```powershell
Test-SharedMailboxCandidate [-ADUser] <ADUser> [-AcceptedDomains] <String[]> [-Verbose]
```

**Parameters:**

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| ADUser | ADUser | Yes | Active Directory user object |
| AcceptedDomains | String[] | No | List of allowed email domains |

**Return:** $true if valid, $false if validation fails

**Example:**
```powershell
# Get user
$user = Get-ADUser "smbx_001"

# Validate
if (Test-SharedMailboxCandidate -ADUser $user) {
    Write-Host "Ready to provision"
} else {
    Write-Host "Validation failed"
}
```

**Validation Checks:**
- Email format (RFC 5321)
- DisplayName not empty
- Email domain in AcceptedDomains
- No duplicate email
- TargetAddress not set

---

## Provisioning Functions

### New-SharedMailboxRemote

Create a shared mailbox in Exchange Online.

**Syntax:**
```powershell
New-SharedMailboxRemote [-SamAccountName] <String> [-DisplayName] <String> [-Email] <String> [-Verbose]
```

**Parameters:**

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| SamAccountName | String | Yes | AD account name (smbx_*) |
| DisplayName | String | Yes | User-friendly mailbox name |
| Email | String | Yes | Email address |

**Return:** Remote mailbox object

**Example:**
```powershell
# Create mailbox
$mailbox = New-SharedMailboxRemote -SamAccountName "smbx_001" `
  -DisplayName "Finance Shared Mailbox" `
  -Email "finance@contoso.com"

# Verify
Get-RemoteMailbox -Identity $mailbox.Guid
```

**Notes:**
- Creates on-premises remote mailbox
- Syncs to EXO via Azure AD Connect (~60 min)
- Requires EXO admin rights

---

### Invoke-MailboxPermissionQueue

Assign permissions to mailbox (add to ACL group).

**Syntax:**
```powershell
Invoke-MailboxPermissionQueue [-MailboxEmail] <String> [-ACLGroupName] <String> [-Verbose]
```

**Parameters:**

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| MailboxEmail | String | Yes | Mailbox email address |
| ACLGroupName | String | Yes | AD group to add as owner |

**Return:** $true if successful, $false if failed

**Example:**
```powershell
# Add permissions
Invoke-MailboxPermissionQueue -MailboxEmail "finance@contoso.com" `
  -ACLGroupName "FINANCE_ADMINS"

# Verify
Get-RemoteMailbox finance@contoso.com | Select-Object ManagedBy
```

**Notes:**
- Queues permission request for async processing
- Retries on failure (up to 5 times)
- Requires group modification rights

---

### Invoke-SharedMailboxProvisioning

Main orchestration function. Discovers and provisions eligible mailboxes.

**Syntax:**
```powershell
Invoke-SharedMailboxProvisioning [-Filter] <String> [-TargetOU] <String> [-DryRun] [-Verbose]
```

**Parameters:**

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| Filter | String | No | "SamAccountName -like 'smbx_*'" | AD discovery filter |
| TargetOU | String | No | Entire domain | Organizational Unit to search |
| DryRun | Switch | No | $false | Show what would happen (no changes) |

**Return:** Summary object with Success/Failure counts

**Example:**
```powershell
# Production run
$result = Invoke-SharedMailboxProvisioning

# Output:
# Discovered: 5
# Created: 4
# Failed: 1
# Duration: 2m 15s

# Dry-run
$result = Invoke-SharedMailboxProvisioning -DryRun
Write-Host "Would create: $($result.ToCreate.Count) mailboxes"
```

**Workflow:**
1. Discover candidates in AD
2. Validate each candidate
3. Check if already provisioned
4. Create new mailboxes
5. Process permission queue
6. Log results to audit trail

---

## Bulk Import Functions

### Import-MailboxCandidatesFromCSV

Import candidates from CSV file for bulk provisioning.

**Syntax:**
```powershell
Import-MailboxCandidatesFromCSV [-CsvPath] <String> [-DryRun] [-Verbose]
```

**Parameters:**

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| CsvPath | String | Yes | Path to CSV file |
| DryRun | Switch | No | Preview without executing |

**Return:** Summary with Success/Failure counts

**CSV Format:**
```csv
SamAccountName,DisplayName,Email,ACLGroup,AdminGroup,Description
smbx_001,Finance,finance@contoso.com,FINANCE_ADMINS,,Department Finance
```

**Example:**
```powershell
# Import candidates
$result = Import-MailboxCandidatesFromCSV -CsvPath "C:\candidates.csv"

# Check results
Write-Host "Created: $($result.SuccessCount)"
Write-Host "Failed: $($result.FailureCount)"
```

**Notes:**
- Validates CSV structure first
- Requires: SamAccountName, DisplayName, Email
- Optional: ACLGroup, AdminGroup, Description
- Creates entries in provisioning backlog

---

### Test-MailboxBulkImport

Validate CSV file before provisioning. Generate preview report.

**Syntax:**
```powershell
Test-MailboxBulkImport [-CsvPath] <String> [-GenerateReport] [-OutputPath] <String> [-Verbose]
```

**Parameters:**

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| CsvPath | String | Yes | Path to CSV file |
| GenerateReport | Switch | No | Create HTML report |
| OutputPath | String | No | Report output path |

**Return:** Validation result with warnings/errors

**Example:**
```powershell
# Validate and generate report
Test-MailboxBulkImport -CsvPath "C:\candidates.csv" `
  -GenerateReport -OutputPath "C:\validation-report.html"

# View report in browser
& "C:\validation-report.html"
```

**Checks:**
- CSV format validity
- Required columns present
- Email format validation
- Duplicate detection
- AD user existence
- Group validity
- Conflicts with existing mailboxes

---

## Reporting Functions

### Get-MailboxProvisioningReport

Generate comprehensive metrics and timeline report.

**Syntax:**
```powershell
Get-MailboxProvisioningReport [-StartDate] <DateTime> [-EndDate] <DateTime> [-Verbose]
```

**Parameters:**

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| StartDate | DateTime | No | 30 days ago | Report start date |
| EndDate | DateTime | No | Today | Report end date |

**Return:** Report object with metrics

**Example:**
```powershell
# Last 7 days
$report = Get-MailboxProvisioningReport -StartDate (Get-Date).AddDays(-7)

# Properties:
# - Period: Date range
# - Summary: Total, Success, Failed counts
# - ByStatus: Distribution of statuses
# - ByGroup: Grouped by ACL group
# - Timeline: Day-by-day breakdown
# - TopFailures: Most common errors
```

---

### Export-MailboxAuditLog

Export audit log in multiple formats.

**Syntax:**
```powershell
Export-MailboxAuditLog [-StartDate] <DateTime> [-EndDate] <DateTime> `
  [-FilterStatus] <String> [-Format] <String> [-OutputPath] <String> [-Verbose]
```

**Parameters:**

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| StartDate | DateTime | No | 30 days ago | Start date |
| EndDate | DateTime | No | Today | End date |
| FilterStatus | String | No | "All" | Filter by INFO/ERROR/WARN |
| Format | String | Yes | HTML\|CSV\|Text | Output format |
| OutputPath | String | Yes | - | File output path |

**Example:**
```powershell
# HTML report
Export-MailboxAuditLog -StartDate (Get-Date).AddDays(-7) `
  -Format HTML -OutputPath "C:\report.html"

# CSV with errors only
Export-MailboxAuditLog -FilterStatus ERROR -Format CSV `
  -OutputPath "C:\errors.csv"

# Text summary
Export-MailboxAuditLog -Format Text -OutputPath "C:\audit.txt"
```

**Output Formats:**
- **HTML:** Formatted table, color-coded by status
- **CSV:** Spreadsheet format, sortable/filterable
- **Text:** Plain text, line-by-line

---

### Get-MailboxProvisioningMetrics

Calculate KPIs and identify bottlenecks.

**Syntax:**
```powershell
Get-MailboxProvisioningMetrics [-Days] <Int32> [-Verbose]
```

**Parameters:**

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| Days | Int32 | No | 30 | Number of days to analyze |

**Return:** Metrics object

**Example:**
```powershell
# Get metrics for last 30 days
$metrics = Get-MailboxProvisioningMetrics -Days 30

# Key metrics:
# - SuccessRate: Percentage of successful provisions
# - AvgTimeToCompletion: Minutes per mailbox
# - RetryRatio: Failed/Total
# - RecoveryTime: Time to successful retry
# - TrendAnalysis: 7/14/30 day trends
# - TopErrors: Most common error codes
# - PeakHours: Hours with highest provisioning
```

---

## Operational Functions

### Get-MailboxProvisioningStatus

Query provisioning status of specific mailbox(es).

**Syntax:**
```powershell
Get-MailboxProvisioningStatus [-SamAccountName] <String> [-ShowTimeline] [-BacklogPath] <String> [-Verbose]
```

**Parameters:**

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| SamAccountName | String | No | Mailbox to query (empty = all) |
| ShowTimeline | Switch | No | Include operation timeline |
| BacklogPath | String | No | Path to backlog file |

**Return:** Status object(s)

**Example:**
```powershell
# Single mailbox
$status = Get-MailboxProvisioningStatus -SamAccountName "smbx_001" -ShowTimeline

# Output:
# SamAccountName: smbx_001
# CurrentStatus: SUCCESS
# CreatedAt: 2026-06-30 10:00:00
# CompletedAt: 2026-06-30 10:05:00
# Timeline: [CREATED] 10:00:00 > [MAILBOX_CREATED] 10:02:00 > [COMPLETED] 10:05:00

# All mailboxes
Get-MailboxProvisioningStatus | Format-Table SamAccountName, CurrentStatus
```

---

### Resolve-MailboxProvisioningFailure

Diagnose failures and suggest remediation.

**Syntax:**
```powershell
Resolve-MailboxProvisioningFailure [-SamAccountName] <String> [-DiagnoseAll] [-BacklogPath] <String> [-Verbose]
```

**Parameters:**

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| SamAccountName | String | No | Specific mailbox or empty for all |
| DiagnoseAll | Switch | No | Analyze all failures |
| BacklogPath | String | No | Path to backlog file |

**Return:** Diagnosis object(s)

**Example:**
```powershell
# Single failure diagnosis
$diagnosis = Resolve-MailboxProvisioningFailure -SamAccountName "smbx_001"

# Output:
# ErrorCode: MailboxNotFound
# CanRetry: $true
# RecommendedAction: "RETRY: Wait 60 minutes for EXO sync, then retry provisioning"
# Details: "Mailbox created on-prem but not visible in EXO yet"

# All failures
Resolve-MailboxProvisioningFailure -DiagnoseAll | 
  Format-Table SamAccountName, ErrorCode, RecommendedAction
```

---

### Invoke-MailboxProvisioningRetry

Manually trigger retry for failed mailbox(es).

**Syntax:**
```powershell
Invoke-MailboxProvisioningRetry [-SamAccountName] <String> [-RetryAll] [-Force] [-BacklogPath] <String> [-Verbose]
```

**Parameters:**

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| SamAccountName | String | No | Single mailbox or empty with -RetryAll |
| RetryAll | Switch | No | Retry all failed mailboxes |
| Force | Switch | No | Override max retry limit |
| BacklogPath | String | No | Path to backlog file |

**Return:** $true if successful, $false otherwise

**Example:**
```powershell
# Retry single mailbox
Invoke-MailboxProvisioningRetry -SamAccountName "smbx_001"

# Retry all within limit
Invoke-MailboxProvisioningRetry -RetryAll

# Force retry (override limit)
Invoke-MailboxProvisioningRetry -SamAccountName "smbx_001" -Force
```

**Notes:**
- Increments retry count
- Updates LastRetryAt timestamp
- Respects MaxRetries limit (unless -Force)

---

### Set-MailboxProvisioningSchedule

Configure ScheduledTask timing and parameters.

**Syntax:**
```powershell
Set-MailboxProvisioningSchedule [-TaskName] <String> [-Interval] <Int32> [-MaxRetries] <Int32> `
  [-Enable] [-Disable] [-Verbose]
```

**Parameters:**

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| TaskName | String | No | "SharedMailboxProvisioning" | Task name |
| Interval | Int32 | No | - | Minutes between runs (5, 15, 30, 60) |
| MaxRetries | Int32 | No | - | Maximum retry attempts |
| Enable | Switch | No | - | Enable the task |
| Disable | Switch | No | - | Disable the task |

**Example:**
```powershell
# Change interval to 30 minutes
Set-MailboxProvisioningSchedule -Interval 30

# Disable for maintenance
Set-MailboxProvisioningSchedule -Disable

# Re-enable
Set-MailboxProvisioningSchedule -Enable
```

---

### Get-MailboxProvisioningHealth

Check system health (EXO, AD, ScheduledTask).

**Syntax:**
```powershell
Get-MailboxProvisioningHealth [-CheckEXO] [-CheckAD] [-CheckScheduledTask] [-CheckAll] [-Verbose]
```

**Parameters:**

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| CheckEXO | Switch | No | Check Exchange Online connectivity |
| CheckAD | Switch | No | Check Active Directory connectivity |
| CheckScheduledTask | Switch | No | Check ScheduledTask status |
| CheckAll | Switch | No | Perform all checks (default) |

**Return:** Health object

**Example:**
```powershell
# Full health check
$health = Get-MailboxProvisioningHealth -CheckAll

# Output:
# OverallStatus: HEALTHY
# CheckTime: 2026-06-30 14:30:00
# Issues: {} (empty = healthy)
# Details:
#   - Component: "Exchange Online", Status: "CONNECTED"
#   - Component: "Active Directory", Status: "CONNECTED"
#   - Component: "ScheduledTask", Status: "RUNNING"

# Check specific component
Get-MailboxProvisioningHealth -CheckAD
```

---

## Common Patterns

### Discovery → Provision → Report

```powershell
# Step 1: Discover
$candidates = Get-SharedMailboxCandidates

# Step 2: Provision
Invoke-SharedMailboxProvisioning

# Step 3: Report
Get-MailboxProvisioningReport | Select-Object Period, Summary
```

### Error Handling Pattern

```powershell
# Get failures
$failures = Get-MailboxProvisioningStatus | 
  Where-Object { $_.CurrentStatus -like "FAILED*" }

# Diagnose
foreach ($failure in $failures) {
    $diagnosis = Resolve-MailboxProvisioningFailure -SamAccountName $failure.SamAccountName
    
    if ($diagnosis.CanRetry) {
        Invoke-MailboxProvisioningRetry -SamAccountName $failure.SamAccountName
    } else {
        Write-Warning "Manual intervention needed: $($diagnosis.RecommendedAction)"
    }
}
```

### Monitoring Pattern

```powershell
# Health
$health = Get-MailboxProvisioningHealth -CheckAll
if ($health.OverallStatus -eq "HEALTHY") {
    # Metrics
    $metrics = Get-MailboxProvisioningMetrics
    
    # Report
    $report = Get-MailboxProvisioningReport
    
    # Log success
    Write-Output "All systems operational"
} else {
    # Alert
    Write-Warning "System degraded: $($health.Issues -join ', ')"
}
```

---

## Return Value Reference

### Status Object

```powershell
@{
    SamAccountName = "smbx_001"
    DisplayName = "Finance"
    Email = "finance@contoso.com"
    CurrentStatus = "SUCCESS" | "PENDING" | "PENDING_RETRY" | "FAILED_MAILBOX" | "FAILED_PERMISSIONS"
    ErrorCode = "MailboxNotFound" | $null
    ErrorMessage = "Description..." | "None"
    CreatedAt = "2026-06-30 10:00:00"
    CompletedAt = "2026-06-30 10:05:00" | "Pending"
    RetryCount = 0..5
    MaxRetries = 5
    LastRetryAt = "2026-06-30 10:30:00" | "Never"
    Timeline = "[CREATED]... > [MAILBOX_CREATED]... > [COMPLETED]..." (optional)
}
```

### Metrics Object

```powershell
@{
    SuccessRate = 0.95          # 0-1 range
    AvgTimeToCompletion = 5     # minutes
    RetryRatio = 0.02           # 0-1 range
    RecoveryTime = 30           # minutes
    TrendAnalysis7Day = 0.93    # success rate trend
    TopErrors = @{
        "MailboxNotFound" = 2
        "PermissionError" = 1
    }
    PeakProcessingHour = 14
}
```

---

**Document Version:** 1.0 | **Last Updated:** 2026-06-30
