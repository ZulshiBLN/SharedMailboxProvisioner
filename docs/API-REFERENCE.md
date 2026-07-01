# SharedMailboxProvisioner - API Reference

**Version:** v0.9.0-beta.1 | **Status:** Pre-Release Phase - Real-World Testing & Validation
**Last Updated:** 2026-07-01

Complete reference for all public functions in SharedMailboxProvisioner module.

---

## Table of Contents

- [Connection Functions](#connection-functions)
- [Discovery & Validation](#discovery--validation)
- [Provisioning Functions](#provisioning-functions)
- [Bulk Import Functions](#bulk-import-functions)
- [Reporting Functions](#reporting-functions)
- [Operational Functions](#operational-functions)
- [Known No-Op Parameters](#known-no-op-parameters)

---

## Connection Functions

### Connect-ExchangeOnlineEnv

Establish connection to Exchange Online with retry and logging.

**Syntax:**
```powershell
Connect-ExchangeOnlineEnv [-Tenant <String>] [-AppId <String>] [-CertificateThumbprint <String>] `
  [-Environment <String>] [-ConfigPath <String>] [-SkipConnectIfAlready] [-ProxyUrl <String>] `
  [-Prefix <String>] [-Verbose]
```

**Parameters:**

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| Tenant | String | No | "" | Organization name or TenantId. Falls back to `Organization` in config.\<Environment\>.json |
| AppId | String | No | "" | Application (client) ID for app-based auth. Falls back to config. Omit both for interactive auth |
| CertificateThumbprint | String | No | "" | Thumbprint of auth certificate in local cert store. Falls back to config |
| Environment | String | No | "dev" | Config environment name used to resolve config.\<Environment\>.json |
| ConfigPath | String | No | "" | Explicit path to a config JSON file, overrides Environment-based lookup |
| SkipConnectIfAlready | Switch | No | $false | Skip reconnect if a connection already exists |
| ProxyUrl | String | No | "" | Proxy server URL (e.g. "http://proxyserver:8080") |
| Prefix | String | No | "ETH" | Prefix applied to EXO cmdlet nouns (e.g. "ETH" -> Get-ETHMailbox) so an on-prem PSSession can coexist. Pass "" for unprefixed cloud cmdlets |

**Return:** Boolean (`$true` on successful connection, `$false` on failure)

**Example:**
```powershell
# Connect using Tenant/AppId/CertificateThumbprint resolved from config.dev.json
Connect-ExchangeOnlineEnv

# Explicit tenant, interactive auth
Connect-ExchangeOnlineEnv -Tenant "contoso.onmicrosoft.com"

# App-based (certificate) authentication
Connect-ExchangeOnlineEnv -Tenant "contoso.onmicrosoft.com" -AppId "app-guid" -CertificateThumbprint "AB12CD34..."

# Verify result
if (Connect-ExchangeOnlineEnv) {
    Write-Output "Connected"
}
```

**Notes:**
- Auto-installs ExchangeOnlineManagement module if missing (minimum version 3.1.0)
- Retries up to 3 times with exponential backoff
- Returns a boolean, not a PSSession object

---

## Discovery & Validation

### Get-SharedMailboxCandidates

Query Active Directory for eligible shared mailbox candidates.

**Syntax:**
```powershell
Get-SharedMailboxCandidates [-SamAccountNamePrefix <String>] [-DescriptionStartsWith <String>] `
  [-CustomAttribute <String>] [-CustomAttributeValue <String>] [-AccountStatus <String>] `
  [-SearchBase <String>] [-Verbose]
```

**Parameters:**

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| SamAccountNamePrefix | String | No | "smbx_" | User SAM account name prefix |
| DescriptionStartsWith | String | No | "Shared Mailbox Persona" | User description must start with this text |
| CustomAttribute | String | No | "nethzTask" | AD attribute name to check for flag (maps to extensionAttribute*) |
| CustomAttributeValue | String | No | "Create RemoteMailbox" | Value to match in custom attribute |
| AccountStatus | String | No | "Disabled" | ValidateSet: Enabled, Disabled, Any |
| SearchBase | String | No | "" | LDAP search base; empty = entire domain root |

**Return:** Array of `[PSCustomObject]` with properties: `SamAccountName`, `DisplayName`, `Mail`, `Description`, `DistinguishedName`, `Enabled`, `ADUser`

**Example:**
```powershell
# All default smbx_ candidates
$candidates = Get-SharedMailboxCandidates

# Custom prefix
$candidates = Get-SharedMailboxCandidates -SamAccountNamePrefix "smbx_finance_"

# Specific search base
$candidates = Get-SharedMailboxCandidates -SearchBase "OU=Users,DC=ethz,DC=ch"

# Get count
$candidates | Measure-Object
```

**Notes:**
- Uses `Get-ADObject -LDAPFilter` internally for large-directory performance
- Requires AD read permissions

---

### Get-SharedMailboxCandidatesWithGroups

Get candidates with validated ACL group membership.

**Syntax:**
```powershell
Get-SharedMailboxCandidatesWithGroups [-SamAccountNamePrefix <String>] [-DescriptionStartsWith <String>] `
  [-CustomAttribute <String>] [-CustomAttributeValue <String>] [-AccountStatus <String>] `
  [-SearchBase <String>] [-ValidateAll <Boolean>] [-Verbose]
```

**Parameters:**

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| SamAccountNamePrefix | String | No | "smbx_" | Candidate user SAM account name prefix |
| DescriptionStartsWith | String | No | "Shared Mailbox Persona" | Candidate description pattern |
| CustomAttribute | String | No | "nethzTask" | Custom AD attribute for candidate flag |
| CustomAttributeValue | String | No | "Create RemoteMailbox" | Value to match in custom attribute |
| AccountStatus | String | No | "Disabled" | ValidateSet: Enabled, Disabled, Any |
| SearchBase | String | No | "" | LDAP search base for candidate search |
| ValidateAll | Boolean | No | $true | If `$true`, only return candidates with a valid ACL group. If `$false`, include candidates without a valid group too (marked via `HasValidGroup`) |

**Return:** Array of `[PSCustomObject]` with properties: `SamAccountName`, `DisplayName`, `Mail`, `Description`, `DistinguishedName`, `Enabled`, `ACLGroup`, `ACLGroupName`, `ACLGroupMail`, `HasValidGroup`, `ADUser`

**Example:**
```powershell
$candidatesWithGroups = Get-SharedMailboxCandidatesWithGroups

# View groups
$candidatesWithGroups | Select-Object SamAccountName, ACLGroupName, HasValidGroup

# Include candidates even without a valid ACL group
$all = Get-SharedMailboxCandidatesWithGroups -ValidateAll $false
```

---

### Get-SharedMailboxACLGroup

Retrieve and validate an ACL group for permission assignment.

**Syntax:**
```powershell
Get-SharedMailboxACLGroup [-SamAccountName] <String> [-SearchBase <String>] [-Verbose]
```

**Parameters:**

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| SamAccountName | String | Yes | - | Shared mailbox user SAM account name (e.g. "smbx_12345678"). Group name is derived: `smbx_acl_{suffix}` |
| SearchBase | String | No | "" | LDAP search base (e.g. "OU=Groups,DC=ethz,DC=ch"); empty = entire domain |

**Return:** `[PSCustomObject]` with `ADGroup`, `Name`, `SamAccountName`, `Mail`, `GroupScope`, `Description`, `IsValid` - or `$null` if not found/invalid

**Example:**
```powershell
# Get ACL group derived from a smbx_ user account
$group = Get-SharedMailboxACLGroup -SamAccountName "smbx_12345678"

# Check result
if ($group) {
    $group | Select-Object Name, Mail, IsValid
}
```

**Notes:**
- Requires `SamAccountName` to start with "smbx_"
- Validates the group is a Universal Security Group, has a `mail` attribute, and its description starts with "Permission group for shared mailbox"

---

### Test-SharedMailboxCandidate

Comprehensive validation of a user account for shared mailbox provisioning.

**Syntax:**
```powershell
Test-SharedMailboxCandidate [-ADUser] <Object> [-AcceptedDomains <String[]>] [-ValidationAttribute <String>] [-Verbose]
```

**Parameters:**

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| ADUser | Object | Yes | - | AD user object to validate. Must expose `mail`, `DisplayName`, `sAMAccountName`, `TargetAddress`, `proxyAddresses` (as returned by `Get-ADUser -Properties`) |
| AcceptedDomains | String[] | No | @() | Domains to accept for the user's mail address. If not provided, checked against Exchange Online's AcceptedDomains list instead |
| ValidationAttribute | String | No | "nethzTask" | **Currently a no-op** - see [Known No-Op Parameters](#known-no-op-parameters) |

**Return:** `[PSCustomObject]` with `SamAccountName`, `IsValid`, `ValidationErrors`, `ValidationChecks` (per-check breakdown)

**Important:** The return value is a `PSCustomObject`, which is always truthy in PowerShell. Do **not** use `if (Test-SharedMailboxCandidate -ADUser $user) { ... }` directly - that branch will always be taken regardless of validation result. Check the `.IsValid` property instead.

**Example:**
```powershell
# Get user
$user = Get-ADUser "smbx_001" -Properties mail, DisplayName, TargetAddress, proxyAddresses

# Validate - check .IsValid, not the object itself
$validation = Test-SharedMailboxCandidate -ADUser $user
if ($validation.IsValid) {
    Write-Output "Ready to provision"
} else {
    Write-Output "Validation failed: $($validation.ValidationErrors -join '; ')"
}
```

**Validation Checks:**
- Mail attribute exists and format valid (RFC 5321)
- No duplicate email across other user accounts
- DisplayName not empty / valid
- SamAccountName format valid
- TargetAddress empty (reserved for Remote Mailbox)
- ProxyAddresses present, including required M365 address
- Email domain accepted (via `-AcceptedDomains` or Exchange Online AcceptedDomains list)

---

## Provisioning Functions

### New-SharedMailboxRemote

Create a remote shared mailbox on on-premises Exchange Server.

**Syntax:**
```powershell
New-SharedMailboxRemote [-SamAccountName] <String> [-DisplayName] <String> [-PrimarySmtpAddress] <String> `
  [-RemoteRoutingAddress] <String> [-ACLGroupName] <String> [-AdminGroupName <String>] `
  [-BacklogPath <String>] [-ExchangeURI <String>] [-CredentialPath <String>] [-Verbose]
```

**Parameters:**

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| SamAccountName | String | Yes | - | The smbx_* SAM account name (disabled user) |
| DisplayName | String | Yes | - | User-friendly mailbox display name |
| PrimarySmtpAddress | String | Yes | - | Primary SMTP email address for the mailbox |
| RemoteRoutingAddress | String | Yes | - | Exchange Online routing address (format: alias@ethz.mail.onmicrosoft.com) |
| ACLGroupName | String | Yes | - | Name of the smbx_acl_* security group; assigned FullAccess + SendAs |
| AdminGroupName | String | No | "" | Optional admin group name; assigned FullAccess only (no SendAs) |
| BacklogPath | String | No | "C:\Repos\SharedMailboxProvisioner\data\mailbox-provisioning-queue.json" | Path to JSON provisioning backlog file |
| ExchangeURI | String | No | "" | On-premises Exchange Server URI for PSSession; if empty, resolved from config |
| CredentialPath | String | No | "C:\Repos\SharedMailboxProvisioner\data\serviceaccount.clixml" | Path to clixml credential file, used as a fallback if the current-user PSSession attempt fails |

**Return:** `[PSCustomObject]` with `SamAccountName`, `DisplayName`, `PrimarySmtpAddress`, `RemoteRoutingAddress`, `ACLGroupName`, `AdminGroupName`, `Status`, `CreatedAt`, `Identity`, `RemoteMailbox` - or `$null` on failure

**Example:**
```powershell
$result = New-SharedMailboxRemote -SamAccountName "smbx_123456" `
    -DisplayName "Sales Team" `
    -PrimarySmtpAddress "sales@ethz.ch" `
    -RemoteRoutingAddress "sales@ethz.mail.onmicrosoft.com" `
    -ACLGroupName "smbx_acl_123456"

# Verify
$result.Status
```

**Notes:**
- Creates an **on-premises** remote mailbox via PSSession (`New-RemoteMailbox`) - not an Exchange Online mailbox directly
- Requires the caller's Service Account to have on-premises Exchange Admin permissions
- Automatically adds an entry to the provisioning backlog for later permission assignment via `Invoke-MailboxPermissionQueue`
- `BacklogPath`/`CredentialPath` default to a hardcoded `C:\Repos\SharedMailboxProvisioner\...` path - override explicitly if your deployment lives elsewhere

---

### Invoke-MailboxPermissionQueue

Process the entire provisioning backlog queue and assign mailbox permissions.

**Syntax:**
```powershell
Invoke-MailboxPermissionQueue [-BacklogPath <String>] [-MaximumRetries <Int32>] [-CleanupDaysOld <Int32>] [-Verbose]
```

**Parameters:**

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| BacklogPath | String | No | "C:\Repos\SharedMailboxProvisioner\data\mailbox-provisioning-queue.json" | Path to JSON provisioning backlog file |
| MaximumRetries | Int32 | No | 5 | Maximum number of permission assignment attempts per entry |
| CleanupDaysOld | Int32 | No | 30 | Delete completed entries older than this many days |

**Return:** `[PSCustomObject]` with `ProcessedCount`, `SuccessCount`, `FailedCount`, `RetryingCount`, `Summary`, `BacklogPath`, `CSVPath`

**Example:**
```powershell
# Process the entire backlog in one call (not a single mailbox/group pair)
$result = Invoke-MailboxPermissionQueue

Write-Output "Processed: $($result.ProcessedCount), Success: $($result.SuccessCount), Failed: $($result.FailedCount)"

# Custom backlog file and retry limit
Invoke-MailboxPermissionQueue -BacklogPath "C:\custom\backlog.json" -MaximumRetries 8
```

**Notes:**
- No parameters are mandatory - it processes every `MAILBOX_CREATED_AWAITING_PERMISSIONS` entry in the backlog file, not a single mailbox
- Designed to run on a schedule (e.g. every 15 minutes) to absorb the Azure AD Connect sync delay
- Idempotent: safe to run multiple times

---

### Invoke-SharedMailboxProvisioning

Main orchestration function. Discovers and provisions eligible mailboxes.

**Syntax:**
```powershell
Invoke-SharedMailboxProvisioning [-SamAccountNamePrefix <String>] [-DescriptionStartsWith <String>] `
  [-SearchBase <String>] [-SkipPermissionQueue <Boolean>] [-BacklogPath <String>] `
  [-GenerateReport <Boolean>] [-Verbose]
```

**Parameters:**

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| SamAccountNamePrefix | String | No | "smbx_" | Candidate user SAM account name prefix |
| DescriptionStartsWith | String | No | "Shared Mailbox Persona" | Candidate description pattern |
| SearchBase | String | No | "" | Active Directory search base; empty = entire domain |
| SkipPermissionQueue | Boolean | No | $false | If `$true`, skip permission queue processing (useful for testing mailbox creation in isolation) |
| BacklogPath | String | No | "C:\Repos\SharedMailboxProvisioner\data\mailbox-provisioning-queue.json" | Path to JSON provisioning backlog |
| GenerateReport | Boolean | No | $true | **Currently a no-op** - see [Known No-Op Parameters](#known-no-op-parameters) |

**Return:** `[PSCustomObject]` with `Status`, `StartTime`, `EndTime`, `Duration`, `CandidatesFound`, `MailboxesCreated`, `MailboxesFailed`, `PermissionsAssigned`, `PermissionsRetrying`, `PermissionsFailed`, `Errors`, `Summary`

**Example:**
```powershell
# Production run (no -DryRun / -Filter / -TargetOU params exist)
$result = Invoke-SharedMailboxProvisioning

Write-Output "Created: $($result.MailboxesCreated) / Found: $($result.CandidatesFound)"
Write-Output "Failed: $($result.MailboxesFailed)"
Write-Output "Duration: $($result.Duration)"

# Skip permission assignment (mailbox creation only)
$result = Invoke-SharedMailboxProvisioning -SkipPermissionQueue $true
```

**Workflow:**
1. Discover candidates with valid ACL groups (`Get-SharedMailboxCandidatesWithGroups`)
2. Create remote mailboxes (`New-SharedMailboxRemote`) for each candidate
3. Process permission queue (`Invoke-MailboxPermissionQueue`), unless `-SkipPermissionQueue $true`
4. Print summary report to output (see Notes - this step always runs)
5. Return summary object

**Notes:**
- `-GenerateReport` is accepted but Step 4's summary output always prints unconditionally regardless of its value - it does not currently gate anything
- No `-Filter`, `-TargetOU`, or `-DryRun` parameters exist

---

## Bulk Import Functions

### Import-MailboxCandidatesFromCSV

Import and validate shared mailbox candidates from a CSV file.

**Syntax:**
```powershell
Import-MailboxCandidatesFromCSV [-CSVPath] <String> [-Encoding <String>] [-ValidateADLookup <Boolean>] `
  [-SearchBase <String>] [-Verbose]
```

**Parameters:**

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| CSVPath | String | Yes | - | Full path to CSV file containing candidate data (validated to exist) |
| Encoding | String | No | "UTF8BOM" | ValidateSet: UTF8, UTF8BOM, ASCII. Falls back to UTF8, then ASCII on read failure |
| ValidateADLookup | Boolean | No | $true | If `$true`, cross-reference candidates with Active Directory (slower but safer) |
| SearchBase | String | No | "" | LDAP search base for AD validation; empty = entire domain |

**Return:** Hashtable-backed object with `SuccessCount`, `FailureCount`, `Candidates`, `FailedRows`, `ImportMetadata` (SourceFile/SourceHash/ImportedAt/ImportedBy/TotalRows)

**CSV Format:**
```csv
SamAccountName,DisplayName,Email,ACLGroup,AdminGroup,Description
smbx_001,Finance,finance@contoso.com,FINANCE_ADMINS,,Department Finance
```

**Example:**
```powershell
# No -DryRun switch exists; this always imports/validates
$result = Import-MailboxCandidatesFromCSV -CSVPath "C:\candidates.csv"

Write-Output "Valid: $($result.SuccessCount)"
Write-Output "Invalid: $($result.FailureCount)"

# Skip AD lookup for faster processing
$result = Import-MailboxCandidatesFromCSV -CSVPath "C:\candidates.csv" -ValidateADLookup $false
```

**Notes:**
- Required CSV columns: `SamAccountName`, `DisplayName`, `Email`. Optional: `ACLGroup`, `AdminGroup`, `Description`
- Failed rows are skipped but recorded in `FailedRows`; import continues on row-level errors
- This is a manual admin tool, not run via the scheduled task

---

### Test-MailboxBulkImport

Validate a batch of already-imported candidates and generate an impact/preview report (dry-run, no provisioning).

**Syntax:**
```powershell
Test-MailboxBulkImport [-Candidates] <PSCustomObject[]> [-GenerateReport <Boolean>] [-ReportPath <String>] `
  [-CheckDuplicates <Boolean>] [-Verbose]
```

**Parameters:**

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| Candidates | PSCustomObject[] | Yes | - | Array of already-imported candidate objects (e.g. `$import.Candidates` from `Import-MailboxCandidatesFromCSV`) - **not** a CSV path |
| GenerateReport | Boolean | No | $true | If `$true`, generate an HTML preview report |
| ReportPath | String | No | "" | Path to save HTML report. If empty, defaults to `$env:TEMP\bulk-import-preview-<timestamp>.html` |
| CheckDuplicates | Boolean | No | $true | If `$true`, check for duplicate SamAccountName/Email within the batch |

**Return:** Hashtable-backed object with `IsValid`, `CandidatesToProcess`, `ConflictingCandidates`, `ValidCandidates`, `ConflictingCandidates_List`, `Issues`, `EstimatedDuration`, `CanProceed`, `ReportPath`

**Example:**
```powershell
$import = Import-MailboxCandidatesFromCSV -CSVPath "C:\candidates.csv"
$impact = Test-MailboxBulkImport -Candidates $import.Candidates

Write-Output "Can proceed: $($impact.CanProceed)"
Write-Output "Valid: $($impact.ValidCandidates.Count), Conflicts: $($impact.ConflictingCandidates)"

# Custom report path
$impact = Test-MailboxBulkImport -Candidates $import.Candidates -ReportPath "C:\reports\preview.html"
```

**Checks:**
- Duplicate SAM/email within the batch (if `-CheckDuplicates $true`)
- Per-candidate validation via `Test-SharedMailboxCandidate`
- Estimated provisioning duration (~15 seconds/mailbox)

---

## Reporting Functions

### Get-MailboxProvisioningReport

Generate comprehensive provisioning metrics and timeline report from the backlog file.

**Syntax:**
```powershell
Get-MailboxProvisioningReport [-StartDate <DateTime>] [-EndDate <DateTime>] [-GroupBy <String>] `
  [-BacklogPath <String>] [-Verbose]
```

**Parameters:**

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| StartDate | DateTime | No | 30 days ago | Report start date |
| EndDate | DateTime | No | Today | Report end date |
| GroupBy | String | No | "Daily" | ValidateSet: Daily, Weekly, Monthly (timeline aggregation) |
| BacklogPath | String | No | "\<module root\>\data\mailbox-provisioning-queue.json" | Path to JSON provisioning backlog file |

**Return:** Hashtable-backed object with `Period` (Start/End), `Summary` (TotalProvisioned/TotalFailed/SuccessRate/AverageTimeToCompletion), `ByStatus`, `ByGroup`, `Timeline`, `TopFailures`

**Example:**
```powershell
# Last 7 days
$report = Get-MailboxProvisioningReport -StartDate (Get-Date).AddDays(-7)

$report.Summary
$report.Timeline
$report.TopFailures
```

---

### Export-MailboxAuditLog

Export audit log in HTML, CSV, or text format.

**Syntax:**
```powershell
Export-MailboxAuditLog [-StartDate <DateTime>] [-EndDate <DateTime>] `
  [-Format <String>] [-OutputPath <String>] [-FilterStatus <String>] [-Verbose]
```

**Parameters:**

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| StartDate | DateTime | No | 7 days ago | Log start date |
| EndDate | DateTime | No | Today | Log end date |
| Format | String | No | "HTML" | ValidateSet: HTML, CSV, Text |
| OutputPath | String | No | "" | File output path. If empty, the function returns the formatted content as a string instead of writing a file |
| FilterStatus | String | No | "All" | ValidateSet: All, INFO, ERROR, WARN |

**Example:**
```powershell
# HTML report written to file
Export-MailboxAuditLog -Format HTML -OutputPath "C:\report.html"

# CSV with errors only
Export-MailboxAuditLog -FilterStatus ERROR -Format CSV -OutputPath "C:\errors.csv"

# Omit -OutputPath to get the formatted string back instead of writing a file
$text = Export-MailboxAuditLog -Format Text
```

**Output Formats:**
- **HTML:** Formatted table, color-coded by level
- **CSV:** Spreadsheet format, sortable/filterable
- **Text:** Plain text, line-by-line

---

### Get-MailboxProvisioningMetrics

Calculate KPIs, identify bottlenecks, and analyze trends.

**Syntax:**
```powershell
Get-MailboxProvisioningMetrics [-TrendDays <Int32>] [-BacklogPath <String>] [-Verbose]
```

**Parameters:**

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| TrendDays | Int32 | No | 30 | Number of days to analyze for trends |
| BacklogPath | String | No | "\<module root\>\data\mailbox-provisioning-queue.json" | Path to JSON provisioning backlog file |

**Return:** Hashtable-backed object with `KPIs` (SuccessRate/AvgTimeToCompletion/MedianTimeToCompletion/RetryRatio/MeanTimeToRecovery), `Bottlenecks`, `Trends` (Last7Days/Last14Days/Last30Days), `PeakHours`

**Example:**
```powershell
# Get metrics for last 30 days (default)
$metrics = Get-MailboxProvisioningMetrics

$metrics.KPIs
$metrics.Bottlenecks

# Last 7 days only
$metrics = Get-MailboxProvisioningMetrics -TrendDays 7
```

**Notes:**
- Pure data analysis - no EXO/AD calls, reads only from the local backlog file

---

## Operational Functions

### Get-MailboxProvisioningStatus

Query provisioning status of specific mailbox(es) or the entire backlog.

**Syntax:**
```powershell
Get-MailboxProvisioningStatus [-SamAccountName <String>] [-ShowTimeline] [-BacklogPath <String>] [-Verbose]
```

**Parameters:**

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| SamAccountName | String | No | "" | Mailbox to query. If empty, returns all backlog entries |
| ShowTimeline | Switch | No | - | Include a timeline of operations (created, retried, completed) |
| BacklogPath | String | No | "\<module root\>\data\mailbox-provisioning-queue.json" | Path to backlog file |

**Return:** Array of `[PSCustomObject]` with `SamAccountName`, `DisplayName`, `Email`, `CurrentStatus`, `ErrorCode`, `ErrorMessage`, `CreatedAt`, `CompletedAt`, `RetryCount`, `MaxRetries`, `LastRetryAt`, and `Timeline` (only if `-ShowTimeline` is used)

**Example:**
```powershell
# Single mailbox
$status = Get-MailboxProvisioningStatus -SamAccountName "smbx_001" -ShowTimeline
$status.Timeline

# All mailboxes
Get-MailboxProvisioningStatus | Format-Table SamAccountName, CurrentStatus
```

---

### Resolve-MailboxProvisioningFailure

Diagnose failures and suggest remediation.

**Syntax:**
```powershell
Resolve-MailboxProvisioningFailure [-SamAccountName <String>] [-DiagnoseAll] [-BacklogPath <String>] [-Verbose]
```

**Parameters:**

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| SamAccountName | String | No | "" | Specific failed mailbox to diagnose |
| DiagnoseAll | Switch | No | - | Documented as "analyze all failures", but **currently a no-op** - see [Known No-Op Parameters](#known-no-op-parameters) |
| BacklogPath | String | No | "\<module root\>\data\mailbox-provisioning-queue.json" | Path to backlog file |

**Return:** Array of `[PSCustomObject]` with `SamAccountName`, `DisplayName`, `ErrorCode`, `ErrorMessage`, `RetryCount`, `MaxRetries`, `CanRetry`, `RecommendedAction`, `Details`

**Example:**
```powershell
# Single failure diagnosis
$diagnosis = Resolve-MailboxProvisioningFailure -SamAccountName "smbx_001"
$diagnosis | Format-List

# All failures - simply omit -SamAccountName (this is the default behavior; -DiagnoseAll adds nothing extra)
Resolve-MailboxProvisioningFailure | Format-Table SamAccountName, ErrorCode, RecommendedAction
```

**Notes:**
- Reads from the JSON backlog only - no EXO/AD calls

---

### Invoke-MailboxProvisioningRetry

Manually trigger retry for failed mailbox(es).

**Syntax:**
```powershell
Invoke-MailboxProvisioningRetry [-SamAccountName <String>] [-RetryAll] [-Force] [-BacklogPath <String>] [-Verbose]
```

**Parameters:**

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| SamAccountName | String | No | "" | Single mailbox to retry. Required unless `-RetryAll` is used |
| RetryAll | Switch | No | - | Retry all failed mailboxes (respecting max retry limit) |
| Force | Switch | No | - | Override max retry limit |
| BacklogPath | String | No | "\<module root\>\data\mailbox-provisioning-queue.json" | Path to backlog file |

**Return:** Boolean (`$true` if at least one entry was retried, `$false` otherwise)

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
- You must specify either `-SamAccountName` or `-RetryAll`; the function errors otherwise
- Increments `RetryCount`, updates `LastRetryAt`, sets status to `PENDING_RETRY`

---

### Set-MailboxProvisioningSchedule

Configure ScheduledTask timing and retry parameters (reconfigures an already-existing task; does not create one).

**Syntax:**
```powershell
Set-MailboxProvisioningSchedule [-TaskName <String>] [-Interval <Int32>] [-MaxRetries <Int32>] `
  [-Enable] [-Disable] [-Verbose]
```

**Parameters:**

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| TaskName | String | No | "SharedMailboxProvisioning" | Name of the existing ScheduledTask |
| Interval | Int32 | No | - | Minutes between task executions. ValidateSet: 5, 15, 30, 60 |
| MaxRetries | Int32 | No | - | Documented as "maximum retry attempts per mailbox", but **currently a no-op** - see [Known No-Op Parameters](#known-no-op-parameters) |
| Enable | Switch | No | - | Enable the ScheduledTask |
| Disable | Switch | No | - | Disable the ScheduledTask |

**Return:** Boolean (`$true` on success, `$false` if the task was not found or an error occurred)

**Example:**
```powershell
# Change interval to 30 minutes
Set-MailboxProvisioningSchedule -Interval 30

# Disable for maintenance
Set-MailboxProvisioningSchedule -Disable

# Re-enable
Set-MailboxProvisioningSchedule -Enable
```

**Notes:**
- The ScheduledTask named `-TaskName` must already exist; this function only updates its trigger interval / enabled state, it does not create the task
- `-MaxRetries` is accepted as a parameter but never referenced anywhere in the function body

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
| CheckAll | Switch | No | Perform all checks (this is also the default if no specific switch is passed) |

**Return:** `[PSCustomObject]` with `CheckTime`, `OverallStatus` (HEALTHY/DEGRADED/UNKNOWN), `Issues`, `Details`

**Example:**
```powershell
# Full health check (default when no switch is specified)
$health = Get-MailboxProvisioningHealth

# Check specific component
Get-MailboxProvisioningHealth -CheckAD
```

**Caution:** The EXO check (`-CheckEXO`) looks for `Get-PSSession | Where-Object { $_.ConfigurationName -eq "Microsoft.Exchange" }` - a classic remoting session marker. Modern EXO-V3 REST-based `Connect-ExchangeOnline`/`Connect-ExchangeOnlineEnv` sessions do not reliably set this, so this check can report `DISCONNECTED` even when a working EXO connection exists. This is a known, tracked gap - do not treat this check alone as authoritative during incident response.

---

## Known No-Op Parameters

The following four parameters are currently accepted by their functions but have **no effect** on behavior. They are documented here for transparency; each is tracked in `PROJECT-TRACKING.md`/`docs/Pre-Release/COMPLIANCE-AUDIT-PHASE-PRERELEASE.md`.

| Function | Parameter | What it claims | What it actually does |
|----------|-----------|-----------------|------------------------|
| `Test-SharedMailboxCandidate` | `-ValidationAttribute` | Write validation result back to this AD attribute | Nothing - accepted but never used to write to AD |
| `Resolve-MailboxProvisioningFailure` | `-DiagnoseAll` | Analyze all failed mailboxes | Nothing extra - omitting `-SamAccountName` already analyzes all entries by default |
| `Invoke-SharedMailboxProvisioning` | `-GenerateReport` | Gate whether a summary report is generated | Nothing - Step 4's summary output always prints unconditionally |
| `Set-MailboxProvisioningSchedule` | `-MaxRetries` | Set maximum retry attempts per mailbox | Nothing - accepted but never referenced in the function body |

---

## Common Patterns

### Discovery -> Provision -> Report

```powershell
# Step 1: Discover
$candidates = Get-SharedMailboxCandidates

# Step 2: Provision
Invoke-SharedMailboxProvisioning

# Step 3: Report
$report = Get-MailboxProvisioningReport
$report.Summary
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

    Write-Output "All systems operational"
} else {
    Write-Warning "System degraded: $($health.Issues -join ', ')"
}
```

---

## Return Value Reference

### Status Object (Get-MailboxProvisioningStatus)

```powershell
[PSCustomObject]@{
    SamAccountName = "smbx_001"
    DisplayName = "Finance"
    Email = $null                # populated only if present in the backlog entry
    CurrentStatus = "SUCCESS" | "PENDING" | "PENDING_RETRY" | "MAILBOX_CREATED_AWAITING_PERMISSIONS" | "FAILED_MAILBOX" | "FAILED_PERMISSIONS" | "PERMISSIONS_SET"
    ErrorCode = "MailboxNotFound" | "None"
    ErrorMessage = "Description..." | "None"
    CreatedAt = "2026-07-01 10:00:00"
    CompletedAt = "2026-07-01 10:05:00" | "Pending"
    RetryCount = 0..5
    MaxRetries = 5
    LastRetryAt = "2026-07-01 10:30:00" | "Never"
    Timeline = "[CREATED]... > [RETRIED]... > [COMPLETED]..." # only present with -ShowTimeline
}
```

### Metrics Object (Get-MailboxProvisioningMetrics)

```powershell
@{
    KPIs = @{
        SuccessRate = "95.0%"
        AvgTimeToCompletion = "00:05:00"
        MedianTimeToCompletion = "00:04:30"
        RetryRatio = "0.02"
        MeanTimeToRecovery = "00:30:00"
    }
    Bottlenecks = @(
        @{ Issue = "MailboxNotFound"; Count = 2; Percentage = "40%"; Impact = "MEDIUM" }
    )
    Trends = @{
        Last7Days = @{ Rate = "93%"; Trend = "STABLE" }
        Last14Days = @{ Rate = "93%"; Trend = "STABLE" }
        Last30Days = @{ Rate = "93%"; Trend = "STABLE" }
    }
    PeakHours = @(
        @{ Hour = "14:00"; Throughput = 5; SuccessRate = "100%"; AvgTime = "00:00:00" }
    )
}
```

---

**Document Version:** 1.0 | **Last Updated:** 2026-07-01
