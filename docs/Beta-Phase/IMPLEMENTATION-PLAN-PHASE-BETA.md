# Implementation Plan: Phase Beta – Extended Features & Production Hardening

**Project:** SharedMailboxProvisioner Phase Beta  
**Date:** 2026-06-30  
**Duration:** 6-8 weeks (estimated)  
**Target Release:** Q3 2026  
**Status:** [PENDING] Ready for planning session  

---

## Executive Summary

Phase Beta adds bulk operations, reporting, integration testing, and operational tooling on top of Phase Alpha's core provisioning engine. Goal: transition from MVP to production-grade system with day-to-day operational capabilities.

**Phase Alpha:** 14 functions, 233+ tests, 6,269+ lines  
**Phase Beta:** +15 functions, +1 script (manual admin tool), +100+ tests, +2,200+ lines  
**Total Post-Beta:** 29 functions, 1 script, 330+ tests, 8,200+ lines

---

## Automation Architecture Overview

### Two Provisioning Paths

| Path | Type | Trigger | Used For |
|------|------|---------|----------|
| **Path A: Auto-Provisioning** | Scheduled Task | ScheduledTask (daily/4h) | Production automation, discover & provision candidates automatically |
| **Path B: Manual Bulk Import** | Manual Script | Admin runs manually | Testing, one-off migrations, bulk corrections, special cases |

### Path A: Automatic Discovery & Provisioning (Phase Alpha)
```
ScheduledTask (e.g., daily at 2am)
  └─ Invoke-SharedMailboxProvisioning.ps1
     ├─ Discover candidates (Get-SharedMailboxCandidatesWithGroups)
     ├─ Create mailboxes (New-SharedMailboxRemote)
     └─ Process queue (Invoke-MailboxPermissionQueue)
```
**Status:** Phase Alpha ready, awaiting ScheduledTask deployment

### Path B: Manual Bulk Import (Phase Beta Tier 7)
```
Admin manually invokes:
  └─ Provision-BulkMailboxesFromCSV.ps1
     ├─ Read CSV (Import-MailboxCandidatesFromCSV)
     ├─ Dry-run preview (Test-MailboxBulkImport)
     ├─ Confirm with admin
     └─ Provision each (calls same functions as Path A)
```
**Status:** Phase Beta Tier 7 implementation

---

## Tier 7: Manual Bulk Import & Data Processing (ADMIN TOOL ONLY)

**Timeline:** Week 1-3 (3 weeks)  
**Effort:** 3 functions + 1 script, ~500 lines code, 30+ tests  
**Risk Level:** MEDIUM (CSV parsing, data validation)  
**Automation:** ❌ NONE – This is a manual admin tool, never runs as scheduled task or automation

**Purpose:** Enable administrators to bulk import & provision shared mailboxes from CSV files.  
Ideal for: Testing, one-off migrations, special cases, bulk corrections.  
NOT for: Production automation (use `Invoke-SharedMailboxProvisioning` via ScheduledTask instead)

### Tier 7.0: Import-MailboxCandidatesFromCSV.ps1 (PUBLIC)

**Purpose:** Read and validate CSV file with bulk candidate data  
**Called By:** Manual script `Provision-BulkMailboxesFromCSV.ps1` (admin invokes manually)  
**Automation:** ❌ NOT scheduled, manual only

**Function Signature:**
```powershell
function Import-MailboxCandidatesFromCSV {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateScript({Test-Path $_})]
        [string]$CSVPath,
        
        [Parameter(Mandatory = $false)]
        [ValidateSet("UTF8", "UTF8BOM", "ASCII")]
        [string]$Encoding = "UTF8BOM",
        
        [Parameter(Mandatory = $false)]
        [bool]$ValidateADLookup = $true,
        
        [Parameter(Mandatory = $false)]
        [string]$SearchBase = ""
    )
}
```

**Key Steps:**
1. Read CSV file with error handling
2. Validate column headers (required: SamAccountName, DisplayName, Email, ACLGroup)
3. Optional columns: AdminGroup, Description, CustomAttribute
4. For each row:
   - Parse data using ConvertTo-MailboxCandidateObject
   - Validate using Test-SharedMailboxCandidate (Tier 3 helper)
   - Optional: Cross-reference with AD
5. Return: @(PSCustomObject[]) with validated candidates + metadata
6. **Audit:** Log import source file + hash for compliance

**Return Object:**
```powershell
@{
    SuccessCount = 10
    FailureCount = 1
    Candidates = @(
        @{
            SamAccountName = "smbx_001"
            DisplayName = "Department A"
            Email = "dept-a@ethz.ch"
            ACLGroup = "smbx_acl_001"
            AdminGroup = "ZO-Mail-Admins"
            SourceRow = 2
            ValidationStatus = "VALID"
            ValidationErrors = @()
        },
        ...
    )
    ImportMetadata = @{
        SourceFile = "bulk-import.csv"
        SourceHash = "abc123..."
        ImportedAt = DateTime
        ImportedBy = "admin@ethz.ch"
    }
}
```

**Error Handling:**
- Row parsing errors: Skip row, add to failure list, continue
- Validation errors: List all errors for row, include in output
- AD lookup errors: Warn but continue (non-blocking)
- Encoding errors: Try fallback encodings

**Tests:** 14
- CSV read success
- Invalid column headers
- Missing required columns
- Invalid data types
- Duplicate SAM accounts
- Special characters in names
- Empty rows
- Large files (1000+ rows)
- Encoding variations
- AD lookup integration
- Validation pipeline
- Error reporting format

**Usage Example (Manual Only):**
```powershell
# Admin manually invokes script (NOT scheduled, not automated)
.\Provision-BulkMailboxesFromCSV.ps1 -CsvPath "C:\imports\bulk-mailboxes.csv" -DryRun $true
```

---

### Tier 7.1: ConvertTo-MailboxCandidateObject.ps1 (PRIVATE)

**Purpose:** Transform CSV row → Candidate PSCustomObject

**Function Signature:**
```powershell
function ConvertTo-MailboxCandidateObject {
    param(
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$CSVRow,
        
        [Parameter(Mandatory = $false)]
        [int]$RowNumber = 0
    )
}
```

**Key Steps:**
1. Validate row is not null
2. Extract properties: SamAccountName, DisplayName, Email, ACLGroup, AdminGroup (optional)
3. Normalize:
   - Trim whitespace
   - Convert to lowercase (where applicable)
   - Validate format (email format, SAM naming rules)
4. Return PSCustomObject with normalized data

**Normalization Rules:**
- SamAccountName: Must start with "smbx_", lowercase, no spaces
- DisplayName: Trim, allow mixed case
- Email: Lowercase, validate format
- ACLGroup: Must exist in AD (optional check)
- AdminGroup: Trim, allow empty

**Tests:** 10
- Valid row transformation
- Whitespace trimming
- Case normalization
- Special character handling
- Empty optional fields
- Invalid email format
- Invalid SAM format
- Null row handling
- Row number tracking

---

### Tier 7.2: Test-MailboxBulkImport.ps1 (PUBLIC)

**Purpose:** Dry-run validation before bulk provisioning (MANUAL admin tool)  
**When Used:** Admin runs preview before executing bulk import  
**Automation:** ❌ NOT scheduled – manual admin decision point

**Function Signature:**
```powershell
function Test-MailboxBulkImport {
    param(
        [Parameter(Mandatory = $true)]
        [PSCustomObject[]]$Candidates,
        
        [Parameter(Mandatory = $false)]
        [bool]$GenerateReport = $true,
        
        [Parameter(Mandatory = $false)]
        [string]$ReportPath = "",
        
        [Parameter(Mandatory = $false)]
        [bool]$CheckDuplicates = $true
    )
}
```

**Key Steps:**
1. Validate each candidate (reuse Test-SharedMailboxCandidate)
2. Check for duplicates in batch (SAM, Email)
3. Check for duplicates in existing system
4. Identify conflicts with existing mailboxes
5. Generate impact analysis:
   - How many will succeed
   - How many will fail (reasons)
   - Estimated time to completion
6. Optional: Generate preview report (HTML or text)
7. Return: Impact analysis object

**Return Object:**
```powershell
@{
    IsValid = $true
    CandidatesToProcess = 10
    ConflictingCandidates = 1
    EstimatedDuration = "00:05:00"
    Issues = @(
        @{
            RowNumber = 5
            SamAccountName = "smbx_005"
            Issue = "Duplicate email address"
            Severity = "ERROR"
        }
    )
    CanProceed = $true
    ReportPath = "C:\reports\bulk-import-preview.html"
}
```

**Tests:** 12
- Valid candidate batch
- Single conflict detection
- Multiple conflicts
- Duplicate SAM detection
- Duplicate email detection
- Valid but empty batch
- All candidates invalid
- Report generation (HTML, text)
- Large batch performance
- Conflict severity ranking

### Tier 7.3: Provision-BulkMailboxesFromCSV.ps1 (SCRIPT – MANUAL ADMIN TOOL)

**Purpose:** CLI entry point for manual bulk mailbox provisioning  
**Location:** `scripts/Provision-BulkMailboxesFromCSV.ps1`  
**Invocation:** Manual (admin runs from PowerShell)  
**Frequency:** On-demand, never scheduled  

**Script Workflow:**
1. Parse command-line parameters
2. Import candidates from CSV via `Import-MailboxCandidatesFromCSV`
3. Run dry-run preview via `Test-MailboxBulkImport` (if `-DryRun $true`)
4. Display impact analysis to admin
5. Ask for confirmation before proceeding
6. Provision each candidate via `Invoke-SharedMailboxProvisioning` parameters
7. Log all imports with audit trail

**Usage Examples:**
```powershell
# Dry-run: show what would happen (no provisioning)
.\Provision-BulkMailboxesFromCSV.ps1 -CsvPath "bulk-mailboxes.csv" -DryRun $true

# Actual provisioning: requires confirmation
.\Provision-BulkMailboxesFromCSV.ps1 -CsvPath "bulk-mailboxes.csv" -DryRun $false

# Verbose: show detailed output
.\Provision-BulkMailboxesFromCSV.ps1 -CsvPath "bulk-mailboxes.csv" -Verbose
```

**Parameters:**
- `-CsvPath` (Required): Path to CSV file
- `-DryRun` (Optional, default: $true): Preview mode (don't provision)
- `-Confirm` (Optional): Require explicit yes/no before provisioning
- `-Verbose` (Optional): Show detailed output
- `-SearchBase` (Optional): AD search base for validation

**Key Characteristics (MANUAL TOOL):**
- ❌ **NOT** part of automation
- ❌ **NOT** triggered by ScheduledTask
- ✅ **ONLY** invoked manually by administrator
- ✅ **Requires** explicit confirmation
- ✅ **Supports** dry-run preview before real action
- ✅ **Logs** all actions for audit trail

---

## Tier 8: Reporting & Audit

**Timeline:** Week 3-5 (2-3 weeks)  
**Effort:** 4 functions, ~500 lines code, 40+ tests  
**Risk Level:** LOW (data aggregation, formatting)

### Tier 8.0: Get-MailboxProvisioningReport.ps1 (PUBLIC)

**Purpose:** Generate comprehensive provisioning metrics and timeline

**Signature:**
```powershell
function Get-MailboxProvisioningReport {
    param(
        [Parameter(Mandatory = $false)]
        [DateTime]$StartDate = (Get-Date).AddDays(-30),
        
        [Parameter(Mandatory = $false)]
        [DateTime]$EndDate = (Get-Date),
        
        [Parameter(Mandatory = $false)]
        [ValidateSet("Daily", "Weekly", "Monthly")]
        [string]$GroupBy = "Daily",
        
        [Parameter(Mandatory = $false)]
        [string]$BacklogPath = "C:\Repos\SharedMailboxProvisioner\data\mailbox-provisioning-queue.json"
    )
}
```

**Return Object:**
```powershell
@{
    Period = @{ Start = DateTime; End = DateTime }
    Summary = @{
        TotalProvisioned = 42
        TotalFailed = 3
        SuccessRate = "93.3%"
        AverageTimeToCompletion = "00:15:30"
    }
    ByStatus = @{
        PERMISSIONS_SET = 40
        FAILED_PERMISSIONS = 2
        MAILBOX_CREATED_AWAITING_PERMISSIONS = 1
    }
    ByGroup = @{
        "smbx_acl_001" = @{ Count = 5; SuccessRate = "100%"; AvgTime = "..." }
        "smbx_acl_002" = @{ Count = 8; SuccessRate = "87.5%"; AvgTime = "..." }
    }
    Timeline = @(
        @{ Date = "2026-06-25"; Provisioned = 5; Failed = 0; Rate = "100%" }
        @{ Date = "2026-06-26"; Provisioned = 7; Failed = 1; Rate = "87.5%" }
    )
    TopFailures = @(
        @{ ErrorCode = "MailboxNotFound"; Count = 2; Percentage = "66.7%" }
        @{ ErrorCode = "PermissionError"; Count = 1; Percentage = "33.3%" }
    )
}
```

**Tests:** 12
- Empty backlog
- Single entry
- Multiple entries, full report
- Date range filtering
- Group-by daily/weekly/monthly
- Success rate calculation
- Failure analysis
- Timeline generation
- Large datasets (1000+ entries)
- Timezone handling

---

### Tier 8.1: Export-MailboxAuditLog.ps1 (PUBLIC)

**Purpose:** Generate detailed audit log in HTML/CSV format

**Signature:**
```powershell
function Export-MailboxAuditLog {
    param(
        [Parameter(Mandatory = $false)]
        [DateTime]$StartDate = (Get-Date).AddDays(-7),
        
        [Parameter(Mandatory = $false)]
        [ValidateSet("HTML", "CSV", "Text")]
        [string]$Format = "HTML",
        
        [Parameter(Mandatory = $false)]
        [string]$OutputPath = ""
    )
}
```

**Key Features:**
- Detailed entry-by-entry log
- Include: timestamp, action, status, user, error details
- HTML: formatted table with colors (green=success, red=fail)
- CSV: machine-readable
- Text: human-readable plaintext
- Filtering: by date, status, user, error code

**Tests:** 10
- HTML export format
- CSV export format
- Text export format
- Empty log handling
- Large log performance
- Date filtering
- Status filtering
- Special character encoding
- File permissions validation

---

### Tier 8.2: Get-MailboxProvisioningMetrics.ps1 (PUBLIC)

**Purpose:** Calculate KPIs, bottlenecks, trend analysis

**Signature:**
```powershell
function Get-MailboxProvisioningMetrics {
    param(
        [Parameter(Mandatory = $false)]
        [int]$TrendDays = 30
    )
}
```

**Metrics to Calculate:**
```powershell
@{
    KPIs = @{
        SuccessRate = "93.3%"
        AvgTimeToCompletion = "00:15:30"
        MedianTimeToCompletion = "00:14:00"
        RetryRatio = "0.15"  # retries / total attempts
        MeanTimeToRecovery = "00:45:00"  # for failed entries
    }
    Bottlenecks = @(
        @{ Issue = "MailboxNotFound"; Count = 8; Percentage = "53.3%"; Impact = "HIGH" }
        @{ Issue = "PermissionError"; Count = 5; Percentage = "33.3%"; Impact = "MEDIUM" }
    )
    Trends = @{
        Last7Days = @{ Rate = "94%"; Trend = "UP" }
        Last14Days = @{ Rate = "92%"; Trend = "STABLE" }
        Last30Days = @{ Rate = "91%"; Trend = "DOWN" }
    }
    PeakHours = @(
        @{ Hour = "09:00"; Throughput = 5; AvgTime = "00:12:00" }
        @{ Hour = "10:00"; Throughput = 8; AvgTime = "00:18:00" }
    )
}
```

**Tests:** 10
- Success rate calculation
- Average/median time computation
- Bottleneck identification
- Trend analysis
- Peak hour detection
- Timezone handling
- Incomplete entries handling
- Large datasets
- Anomaly detection

---

### Tier 8.3: ConvertTo-MailboxReportFormat.ps1 (PRIVATE)

**Purpose:** Format data for human-readable output

**Signature:**
```powershell
function ConvertTo-MailboxReportFormat {
    param(
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$ReportData,
        
        [Parameter(Mandatory = $false)]
        [ValidateSet("HTML", "CSV", "Text", "JSON")]
        [string]$Format = "Text"
    )
}
```

**Key Features:**
- Convert metrics → formatted strings
- Handle percentages, durations, dates
- ASCII-only output (per ADR-010)
- Color coding for HTML (green/yellow/red)
- Proper CSV escaping

**Tests:** 8
- Percentage formatting
- Duration formatting
- Date formatting
- CSV escaping
- HTML tag safety
- ASCII-only compliance
- Null value handling

---

## Tier 9: Integration Testing

**Timeline:** Week 5-7 (2 weeks)  
**Effort:** 3 test suites, ~600 lines tests, 19+ test cases  
**Risk Level:** HIGH (requires real Exchange/AD)

### Prerequisites
- Staging Exchange Server
- Test OU in AD with test candidates
- Service Account with full permissions
- Non-production environment

### Tier 9.0: Integration-Exchange-ADConnect.ps1

**Test Suite Purpose:** Verify Exchange/AD sync cycle

**Test Cases:** 8
1. Create test mailbox on on-prem Exchange
2. Verify visibility in EXO after sync (40-60 min wait)
3. Verify AD Connect sync completed
4. Check mailbox properties in both systems
5. Delete test mailbox cleanly
6. Verify removal from both systems
7. Test concurrent mailbox creation (2-3 simultaneous)
8. Performance: create + wait for sync + cleanup time

**Expected Results:**
```
✅ Mailbox created on on-prem
✅ Mailbox visible in EXO after sync
✅ Properties match in both systems
✅ Clean deletion possible
✅ Concurrent creation is safe
⏱️ Average time to EXO visibility: 52 minutes
```

### Tier 9.1: Integration-FullPipeline.ps1

**Test Suite Purpose:** End-to-end provisioning workflow

**Test Cases:** 6
1. Candidate discovery (Get-SharedMailboxCandidatesWithGroups)
2. Mailbox creation (New-SharedMailboxRemote)
3. Permission assignment (Invoke-MailboxPermissionQueue)
4. Verify all steps completed
5. Audit trail verification (backlog entries)
6. Full cleanup/rollback

**Expected Results:**
```
✅ 5 candidates discovered
✅ 5 mailboxes created on on-prem
✅ 5 entries in provisioning queue
✅ Permissions assigned after sync (wait 40+ min)
✅ 5 backlog entries marked PERMISSIONS_SET
✅ Cleanup successful (remove test mailboxes)
```

### Tier 9.2: Integration-BulkOperations.ps1

**Test Suite Purpose:** Bulk import + provisioning performance

**Test Cases:** 5
1. Bulk CSV import (10 candidates)
2. Dry-run validation (Test-MailboxBulkImport)
3. Concurrent provisioning (10 in parallel)
4. Performance: <2 min for 10 mailboxes
5. Verify all backlog entries created

**Expected Results:**
```
✅ Bulk import: 10/10 valid
✅ Dry-run: no conflicts
✅ Provisioning: 10 mailboxes in 90 seconds
✅ All backlog entries created
⏱️ Average: 9 seconds per mailbox
```

**Tests:** 19 total (8+6+5)

---

## Tier 10: Operational Tooling

**Timeline:** Week 7-8 (1-2 weeks)  
**Effort:** 5 functions, ~600 lines code, 40+ tests  
**Risk Level:** LOW (read-only + targeted writes)

### Tier 10.0: Get-MailboxProvisioningStatus.ps1 (PUBLIC)

**Purpose:** Query status of specific mailbox(es)

**Signature:**
```powershell
function Get-MailboxProvisioningStatus {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$SamAccountName,
        
        [Parameter(Mandatory = $false)]
        [string]$BacklogPath = ""
    )
}
```

**Return:** Array of status objects with timeline

**Tests:** 8

### Tier 10.1: Resolve-MailboxProvisioningFailure.ps1 (PUBLIC)

**Purpose:** Diagnose failures and suggest remediation

**Signature:**
```powershell
function Resolve-MailboxProvisioningFailure {
    param(
        [Parameter(Mandatory = $true)]
        [string]$SamAccountName
    )
}
```

**Return:** Diagnosis object with remediation steps

**Tests:** 10

### Tier 10.2: Invoke-MailboxProvisioningRetry.ps1 (PUBLIC)

**Purpose:** Manually retry failed mailbox(es)

**Signature:**
```powershell
function Invoke-MailboxProvisioningRetry {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$SamAccountName,
        
        [Parameter(Mandatory = $false)]
        [bool]$SkipRetryLimitCheck = $false
    )
}
```

**Return:** Retry result per mailbox

**Tests:** 10

### Tier 10.3: Set-MailboxProvisioningSchedule.ps1 (PUBLIC)

**Purpose:** Configure ScheduledTask timing

**Signature:**
```powershell
function Set-MailboxProvisioningSchedule {
    param(
        [Parameter(Mandatory = $false)]
        [ValidateSet("5min", "15min", "30min", "1hour")]
        [string]$Interval = "15min",
        
        [Parameter(Mandatory = $false)]
        [bool]$Enable = $true
    )
}
```

**Return:** Confirmation of new schedule

**Tests:** 8

### Tier 10.4: Get-MailboxProvisioningHealth.ps1 (PUBLIC)

**Purpose:** System health check and alerts

**Signature:**
```powershell
function Get-MailboxProvisioningHealth {
    param()
}
```

**Return:** Health status object with alerts

**Health Checks:**
- EXO connectivity
- On-prem Exchange connectivity
- AD connectivity
- ScheduledTask status
- Backlog queue status
- Last successful run
- Pending entries age
- Retry count trends

**Tests:** 8

---

## Tier 11: Documentation

**Timeline:** Week 7-8 (concurrent with Tier 10)  
**Effort:** 4 documents, ~130 pages  
**Risk Level:** NONE (documentation)

### Tier 11.0: USER-GUIDE.md (40 pages)

**Sections:**
1. Getting Started (5 pages)
2. Single Mailbox Provisioning (8 pages)
3. Bulk Import Workflow (10 pages)
4. Monitoring & Reporting (8 pages)
5. Troubleshooting (9 pages)

### Tier 11.1: ADMIN-GUIDE.md (40 pages)

**Sections:**
1. Architecture Overview (8 pages)
2. Installation & Setup (10 pages)
3. Configuration Options (8 pages)
4. Monitoring & Alerting (8 pages)
5. Performance Tuning (6 pages)

### Tier 11.2: OPERATIONS-RUNBOOK.md (30 pages)

**Sections:**
1. Daily Operations (8 pages)
2. Failure Handling (10 pages)
3. Escalation Procedures (6 pages)
4. Reporting & Audits (6 pages)

### Tier 11.3: API-REFERENCE.md (20 pages)

**Sections:**
1. Tier 7 Functions (5 pages)
2. Tier 8 Functions (5 pages)
3. Tier 10 Functions (5 pages)
4. Complete parameter reference (5 pages)

---

## Implementation Timeline & Milestones

### Week 1-3: Tier 7 (Manual Bulk Import Tool)

**Milestone 1.1:** Import-MailboxCandidatesFromCSV complete (Day 5)
- Function complete + tests
- CSV parsing + validation working
- Error handling solid
- Audit logging for source file

**Milestone 1.2:** ConvertTo-MailboxCandidateObject complete (Day 8)
- Data normalization
- Integration with Tier 3 validators

**Milestone 1.3:** Test-MailboxBulkImport complete (Day 12)
- Dry-run validation (NO PROVISIONING in preview mode)
- Impact analysis (conflicts, duplicates)
- Preview reporting

**Milestone 1.4:** Provision-BulkMailboxesFromCSV.ps1 (CLI Script) complete (Day 15)
- Manual admin script (NOT scheduled)
- Dry-run support (admin preview before actual provisioning)
- Confirmation workflow (require explicit yes/no)
- CSV format finalized

**Milestone 1.5:** Tier 7 testing & documentation (Day 16-21)
- Unit tests: 30+
- Manual bulk import workflow proven
- CSV format documented
- Usage examples created
- ⚠️ **CRITICAL:** Document that this is MANUAL ONLY, never automated

### Week 3-5: Tier 8 (Reporting)

**Milestone 2.1:** Get-MailboxProvisioningReport complete (Day 22)
- Metrics calculation
- Timeline generation
- Group-by aggregation

**Milestone 2.2:** Export-MailboxAuditLog complete (Day 26)
- HTML/CSV/Text export
- Detailed audit trails

**Milestone 2.3:** Get-MailboxProvisioningMetrics complete (Day 29)
- KPI calculation
- Bottleneck identification
- Trend analysis

**Milestone 2.4:** Tier 8 testing (Day 31-35)
- Unit tests: 40+
- Report quality verification

### Week 5-7: Tier 9 (Integration Testing) + Tier 10 (Ops Tools)

**Milestone 3.1:** Integration tests set up (Day 36)
- Test environment ready
- Integration test suites created

**Milestone 3.2:** Tier 10 functions implemented (Day 40)
- Status query complete
- Retry management complete
- Health checks complete

**Milestone 3.3:** Integration testing execution (Day 42-49)
- Exchange/AD sync verification
- Full pipeline end-to-end test
- Bulk operations performance test

**Milestone 3.4:** Performance benchmarking (Day 50-52)
- Single mailbox: target <30 sec
- Bulk 10: target <2 min
- Bulk 100: measure for Tier 12

### Week 7-8: Tier 11 (Documentation)

**Milestone 4.1:** User Guide complete (Day 54)
- Getting started + single mailbox
- Bulk import walkthrough
- Troubleshooting guide

**Milestone 4.2:** Admin Guide complete (Day 56)
- Architecture documentation
- Configuration options
- Monitoring setup

**Milestone 4.3:** Operations Runbook complete (Day 58)
- Daily operations procedures
- Failure handling guide
- Escalation procedures

**Milestone 4.4:** API Reference complete (Day 60)
- All functions documented
- Parameter reference

---

## Success Criteria

| Category | Target | Verification |
|----------|--------|--------------|
| **Functionality** | All 15 functions implemented | Code review + unit tests |
| **Testing** | 100+ unit tests | All tests passing |
| **Integration** | 19 integration test cases | Real Exchange/AD testing |
| **Code Coverage** | 90%+ | Code coverage report |
| **Performance** | <30sec single, <2min bulk-10 | Benchmarking results |
| **Documentation** | 130+ pages | 4 guides complete |
| **Security** | Security review passed | Third-party review |
| **Compliance** | 100% compliance with STRUCTURE.md | PSScriptAnalyzer + manual |

---

## Deliverables Checklist

**Phase Beta Completion:**
- [ ] 15 new functions implemented
- [ ] 100+ unit tests passing
- [ ] 19 integration tests passing
- [ ] 130+ pages documentation
- [ ] Performance benchmarks documented
- [ ] Security review completed
- [ ] Code merged to main branch
- [ ] Release tag created (v2.0.0-beta.1)
- [ ] Release notes published
- [ ] Team sign-off obtained

---

## Risk Mitigation

### High Risk: CSV Parsing Errors
**Mitigation:** Strict validation, preview mode, error logging

### High Risk: Integration Test Flakiness
**Mitigation:** Use staging environment, longer timeouts, automatic retry

### Medium Risk: Performance Under Load
**Mitigation:** Early performance testing, optimization iterations

### Medium Risk: Documentation Lag
**Mitigation:** Write docs before implementation, include in definition of done

---

## Resource Allocation

```
Timeline: 6-8 weeks (42-56 days)
Team Size: 5-6 people
Effort: ~15 person-weeks

Distribution:
- Developer 1 (Tiers 7, 8): 6 weeks
- Developer 2 (Tiers 9, 10): 4 weeks
- QA (Testing, Integration): 4 weeks
- Tech Writer (Tier 11): 3 weeks
- Architect/Lead (Review, Planning): 2 weeks
- Security (Review, Audit): 1 week
```

---

**Document:** IMPLEMENTATION-PLAN-PHASE-BETA.md  
**Created:** 2026-06-30  
**Status:** Draft (awaiting planning session)  
**Next Step:** Team planning session to confirm schedule & resource allocation
