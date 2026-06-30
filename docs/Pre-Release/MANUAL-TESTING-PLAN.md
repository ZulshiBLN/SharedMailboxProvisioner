# SharedMailboxProvisioner – Manual Testing Plan (Day 3)

**Date:** July 3, 2026 (Thursday)  
**Duration:** 1 Full Day (9:00 AM - 5:00 PM)  
**Test Environment:** Staging (Real EXO/AD)  
**Test Candidates:** 10 Pre-Prepared Accounts  
**QA Owner:** [Assign Name]  

---

## Overview

This document provides a **step-by-step guide** for manual testing of all critical workflows in a staging environment. Each test is designed to validate functionality without affecting production systems.

**Test Candidates:** 10 accounts prepared via IT-Shop, ready in AD by July 2.

**Success Criteria:** All 6 workflows pass validation with 10 candidates → Proceed to v0.9.0 release.

---

## Pre-Test Checklist (Before 9:00 AM)

**15 minutes before testing starts:**

- [ ] Staging environment accessible (EXO + AD)
- [ ] Module loaded: `Import-Module "C:\Repos\SharedMailboxProvisioner\SharedMailboxProvisioner.psd1"`
- [ ] 10 test candidates visible in AD
- [ ] Provisioning queue empty (`$backlog = @()`)
- [ ] Logging directory accessible
- [ ] Report templates ready
- [ ] Laptop connected (no VPN issues)

**If any item fails → STOP → Report to DevOps → Reschedule testing**

---

## WORKFLOW 1: Find & Validate Candidates

**Time:** 9:00 AM - 10:00 AM (1 hour)  
**Candidates:** All 10  
**Expected Result:** All 10 found and validated  

### Step 1.1: Run Get-SharedMailboxCandidates

```powershell
$candidates = Get-SharedMailboxCandidates
$candidates.Count  # Should be >= 10
$candidates | Select-Object SamAccountName, Email, ACLGroup | Format-Table
```

**Expected Output:**
- ✅ All 10 candidates listed
- ✅ Each has SamAccountName (smbx_*)
- ✅ Each has Email
- ✅ Each has ACLGroup

**If FAIL:** 
- Check if accounts in AD: `Get-ADUser -Filter "SamAccountName -like 'smbx_*'"`
- Check ACL group exists: `Get-ADGroup -Identity "GroupName"`
- Document error and continue with available candidates

**Time Check:** ⏱️ Should take 5 minutes

---

### Step 1.2: Validate All Candidates with Groups

```powershell
$candidatesWithGroups = Get-SharedMailboxCandidatesWithGroups
$candidatesWithGroups.Count
$candidatesWithGroups | Format-Table
```

**Validation Checklist:**
- [ ] All candidates show status = "Valid"
- [ ] All candidates have ACL group
- [ ] All candidates have Admin group (if configured)
- [ ] No validation errors

**If FAIL:**
- Check ACL group configuration: `Get-ADGroup -Identity $aclGroup -Properties Members`
- Verify account is member: `Get-ADGroupMember -Identity $aclGroup`
- Document which candidates failed and why

**Time Check:** ⏱️ Should take 10 minutes

---

### Step 1.3: Spot-Check 3 Random Candidates

Pick candidates #2, #5, #8 (random selection)

```powershell
$candidate = $candidatesWithGroups[1]  # Index 1 = candidate #2
Write-Host "Checking: $($candidate.SamAccountName)"
Write-Host "Email: $($candidate.Email)"
Write-Host "ACL Group: $($candidate.ACLGroup)"
Write-Host "Status: $($candidate.Status)"
```

**Validation:**
- [ ] SamAccountName format correct (smbx_*)
- [ ] Email valid format
- [ ] ACL Group resolvable in AD
- [ ] Status = Valid

**Time Check:** ⏱️ Should take 5 minutes

---

### Workflow 1 Summary

| Item | Status | Notes |
|------|--------|-------|
| Candidates Found | ✅ / ❌ | ___ |
| Groups Resolved | ✅ / ❌ | ___ |
| Validation Passed | ✅ / ❌ | ___ |

**Next:** Proceed to Workflow 2

---

## WORKFLOW 2: Test Provisioning

**Time:** 10:00 AM - 12:00 PM (2 hours)  
**Candidates:** All 10  
**Expected Result:** All 10 mailboxes created in EXO  

### Step 2.1: Prepare CSV for Bulk Import

```powershell
# Export candidates to CSV
$csvPath = "C:\temp\bulk-import-test.csv"
$candidates | Export-Csv -Path $csvPath -NoTypeInformation

# Verify CSV created
Test-Path $csvPath  # Should be $true
Get-Content $csvPath -TotalCount 5  # Show first 5 lines
```

**Validation:**
- [ ] CSV file exists
- [ ] CSV contains all 10 rows + header
- [ ] CSV columns: SamAccountName, DisplayName, Email, ACLGroup, AdminGroup

**Time Check:** ⏱️ Should take 5 minutes

---

### Step 2.2: Import Candidates from CSV

```powershell
$import = Import-MailboxCandidatesFromCSV -CSVPath $csvPath
$import.Candidates.Count  # Should be 10
$import.Candidates | Select-Object SamAccountName, Email | Format-Table
```

**Validation Checklist:**
- [ ] All 10 candidates imported
- [ ] No import errors
- [ ] Each candidate has required fields
- [ ] Duplicates detected (if any) → handled correctly

**If FAIL:**
- Check CSV format: `Import-Csv $csvPath | Get-Member`
- Look for encoding issues (UTF-8 vs ASCII)
- Check for duplicate SAM accounts in CSV
- Document error

**Time Check:** ⏱️ Should take 10 minutes

---

### Step 2.3: Dry-Run Validation (No Provisioning Yet)

```powershell
$dryRun = Test-MailboxBulkImport -Candidates $import.Candidates -GenerateReport $true
$dryRun.CanProceed  # Should be $true
$dryRun.ValidCandidates.Count  # Should be 10
$dryRun.ConflictingCandidates  # Should be 0
$dryRun.EstimatedDuration  # Shows expected time
```

**Validation Checklist:**
- [ ] CanProceed = $true
- [ ] All 10 candidates valid
- [ ] 0 conflicting candidates
- [ ] No issues detected
- [ ] Report generated (check `$dryRun.ReportPath`)

**If FAIL:**
- Review `$dryRun.Issues` array
- Document each issue
- Fix issues (if possible) or note as known issue
- Do NOT proceed to provisioning if critical issues

**Time Check:** ⏱️ Should take 15 minutes

---

### Step 2.4: Actually Provision All 10 Mailboxes

```powershell
# Confirm ready to provision
Write-Host "About to provision 10 mailboxes. Press ENTER to continue..."
Read-Host

# Provision
$provisionResult = Provision-BulkMailboxesFromCSV -CSVPath $csvPath -DryRun $false

# Check result
$provisionResult.Count  # Should be 10
$provisionResult | Select-Object SamAccountName, Status | Format-Table
```

**Expected Output:**
- ✅ All 10 mailboxes status = "MAILBOX_CREATED" or "PERMISSIONS_SET"
- ✅ No "FAILED_*" statuses

**Validation in EXO (Parallel Check):**

```powershell
# Wait 60 seconds for sync, then check EXO
Start-Sleep -Seconds 60

# Check each mailbox exists in EXO
$createdMailboxes = Get-Mailbox -Filter "DisplayName -like 'smbx_*'" -ResultSize Unlimited
$createdMailboxes.Count  # Should be >= 10
$createdMailboxes | Select-Object DisplayName, PrimarySmtpAddress | Format-Table
```

**Validation Checklist:**
- [ ] All 10 mailboxes provisioned successfully
- [ ] Each mailbox visible in EXO (after 60s sync)
- [ ] No failed provisioning attempts
- [ ] Audit logs show creation timestamps

**If FAIL:**
- Check `$provisionResult` for error codes
- Review audit logs: `Get-MailboxProvisioningStatus | Format-Table`
- Note specific failures (throttling, permissions, etc.)
- Continue with successfully-provisioned mailboxes

**Time Check:** ⏱️ Should take 45 minutes (including EXO sync wait)

---

### Workflow 2 Summary

| Item | Status | Count | Notes |
|------|--------|-------|-------|
| CSV Created | ✅ / ❌ | 10 | ___ |
| Imported | ✅ / ❌ | 10 | ___ |
| Dry-Run Passed | ✅ / ❌ | — | ___ |
| Provisioned | ✅ / ❌ | 10 | ___ |
| In EXO | ✅ / ❌ | 10 | ___ |

**Next:** Proceed to Workflow 3

---

## WORKFLOW 3: Test Permission Assignment

**Time:** 12:00 PM - 1:00 PM (1 hour)  
**Candidates:** All 10 (provisioned)  
**Expected Result:** All groups correctly assigned as Full Access  

### Step 3.1: Check Permissions in Each Mailbox

```powershell
# Pick 3 random mailboxes (e.g., #2, #5, #8)
$mailboxes = $createdMailboxes | Select-Object -First 1
$mailbox = $mailboxes[0]

# Check Full Access
Get-MailboxPermission -Identity $mailbox.Identity | 
  Where-Object { $_.AccessRights -contains "FullAccess" } | 
  Format-Table User, AccessRights
```

**Expected Output:**
- ✅ ACL group has "FullAccess" right
- ✅ Service account has "FullAccess" right (if applicable)

**Validation Checklist (for each of 3 mailboxes):**
- [ ] ACL group listed with FullAccess
- [ ] No unexpected users
- [ ] Group distinguishedName is correct

**If FAIL:**
- Check group assignment: `Get-ADGroupMember -Identity $aclGroup`
- Check EXO sync status
- Note permission errors

**Time Check:** ⏱️ Should take 20 minutes

---

### Step 3.2: Verify Send-As Permissions (If Applicable)

```powershell
# Check Send-As for same 3 mailboxes
$mailbox = $createdMailboxes[0]
Get-RecipientPermission -Identity $mailbox.Identity | 
  Format-Table Trustee, AccessRights
```

**Validation:**
- [ ] Group has "SendAs" permission (if configured)
- [ ] Service account has "SendAs" (if applicable)

**Time Check:** ⏱️ Should take 10 minutes

---

### Workflow 3 Summary

| Item | Status | Notes |
|------|--------|-------|
| Full Access Set | ✅ / ❌ | ___ |
| Send-As Set | ✅ / ❌ | ___ |
| Group Sync OK | ✅ / ❌ | ___ |

**Next:** Proceed to Workflow 4

---

## WORKFLOW 4: Test Reporting

**Time:** 1:00 PM - 2:00 PM (1 hour)  
**Data Source:** 10 provisioned mailboxes  
**Expected Result:** All reports generated with correct data  

### Step 4.1: Generate Provisioning Report

```powershell
$report = Get-MailboxProvisioningReport -StartDate (Get-Date).AddDays(-1)
$report.Summary | Format-Table
$report.ByStatus | Format-Table -AutoSize
```

**Validation Checklist:**
- [ ] Report includes all 10 provisioned mailboxes
- [ ] Summary shows: TotalProvisioned=10, TotalFailed=0 (or acceptable count)
- [ ] SuccessRate >= 90%
- [ ] AverageTimeToCompletion calculated

**Expected Output:**
```
TotalProvisioned   : 10
TotalFailed        : 0
SuccessRate        : 100%
AverageTimeToCompletion : 00:02:30
```

**Time Check:** ⏱️ Should take 15 minutes

---

### Step 4.2: Export Audit Log (Multiple Formats)

```powershell
# Export as HTML
$htmlPath = "C:\temp\audit-report.html"
$auditHtml = Export-MailboxAuditLog -Format HTML -OutputPath $htmlPath
Write-Host "HTML report: $htmlPath"

# Export as CSV
$csvPath = "C:\temp\audit-report.csv"
$auditCsv = Export-MailboxAuditLog -Format CSV -OutputPath $csvPath
Write-Host "CSV report: $csvPath"

# View first few entries
Get-Content $htmlPath -TotalCount 50  # Check HTML format
Get-Content $csvPath -TotalCount 5    # Check CSV format
```

**Validation Checklist:**
- [ ] HTML file created and readable
- [ ] CSV file created with valid format
- [ ] Both contain provisioning events
- [ ] Timestamps correct
- [ ] Column headers present

**If FAIL:**
- Check audit log directory: `Test-Path "C:\ProgramData\SharedMailboxProvisioner\Audit\"`
- Check write permissions
- Review Export-MailboxAuditLog errors

**Time Check:** ⏱️ Should take 20 minutes

---

### Step 4.3: Generate Metrics Report

```powershell
$metrics = Get-MailboxProvisioningMetrics -TrendDays 30
$metrics.KPIs | Format-Table
$metrics.Bottlenecks | Format-Table
$metrics.Trends | Format-Table
```

**Validation Checklist:**
- [ ] KPIs calculated (SuccessRate, AvgTime, RetryRatio)
- [ ] Bottlenecks identified (if any)
- [ ] Trend data present (Last7Days, Last14Days, Last30Days)
- [ ] Peak hours analysis complete

**Time Check:** ⏱️ Should take 15 minutes

---

### Workflow 4 Summary

| Item | Status | Notes |
|------|--------|-------|
| Report Generated | ✅ / ❌ | ___ |
| HTML Export | ✅ / ❌ | ___ |
| CSV Export | ✅ / ❌ | ___ |
| Metrics Calculated | ✅ / ❌ | ___ |

**Next:** Proceed to Workflow 5

---

## WORKFLOW 5: Test Recovery & Retry

**Time:** 2:00 PM - 3:30 PM (1.5 hours)  
**Candidates:** 1-2 mailboxes (to simulate failure)  
**Expected Result:** Recovery mechanisms work correctly  

### Step 5.1: Simulate a Failed Provisioning (Optional)

**Choice A: Intentionally Cause Failure** (Not recommended in production)
```powershell
# Manually mark 1 mailbox as failed
$backlog = @()  # Load current backlog
$failMailbox = $backlog[0]
$failMailbox.Status = "FAILED_PERMISSIONS"
$failMailbox.ErrorCode = "PermissionError"
$failMailbox.ErrorMessage = "Service account lacks permissions"
$backlog | ConvertTo-Json | Set-Content -Path "C:\Repos\SharedMailboxProvisioner\data\mailbox-provisioning-queue.json"
```

**Choice B: Use Existing Failures** (If any from Workflow 2)
```powershell
# Find existing failures
$failures = $provisionResult | Where-Object { $_.Status -like "FAILED_*" }
$failures | Format-Table SamAccountName, Status, ErrorCode
```

**Validation:**
- [ ] At least 1 failed mailbox in queue
- [ ] Error code and message populated

**Time Check:** ⏱️ Should take 10 minutes

---

### Step 5.2: Diagnose Failure

```powershell
# Get failure details
$diagnosis = Resolve-MailboxProvisioningFailure -SamAccountName "smbx_002"
$diagnosis | Format-Table SamAccountName, ErrorCode, RecommendedAction, CanRetry
```

**Validation Checklist:**
- [ ] Failure identified correctly
- [ ] RecommendedAction suggests "RETRY" or "ESCALATE"
- [ ] CanRetry = $true (if retries not exhausted)
- [ ] Details explain root cause

**Expected Output:**
```
SamAccountName    : smbx_002
ErrorCode         : PermissionError
RecommendedAction : RETRY: Check service account has permissions...
CanRetry          : True
```

**Time Check:** ⏱️ Should take 10 minutes

---

### Step 5.3: Manually Retry Failed Mailbox

```powershell
# Trigger retry for 1 failed mailbox
$retryResult = Invoke-MailboxProvisioningRetry -SamAccountName "smbx_002"
$retryResult  # Should be $true

# Check status after retry
Start-Sleep -Seconds 30  # Wait for retry to process
$status = Get-MailboxProvisioningStatus -SamAccountName "smbx_002"
$status | Format-Table SamAccountName, CurrentStatus, RetryCount
```

**Validation Checklist:**
- [ ] Retry triggered successfully
- [ ] Status shows "PENDING_RETRY"
- [ ] RetryCount incremented
- [ ] No errors during retry

**Expected Output:**
```
SamAccountName : smbx_002
CurrentStatus  : PENDING_RETRY
RetryCount     : 1
```

**Time Check:** ⏱️ Should take 20 minutes

---

### Step 5.4: Verify Retry Succeeded

```powershell
# Wait for retry to complete (up to 60 seconds)
$maxWait = 60
$startTime = Get-Date
while ((Get-Date) - $startTime -lt [TimeSpan]::FromSeconds($maxWait)) {
    $status = Get-MailboxProvisioningStatus -SamAccountName "smbx_002"
    if ($status.CurrentStatus -eq "PERMISSIONS_SET") {
        Write-Host "Retry succeeded!"
        break
    }
    Start-Sleep -Seconds 5
}

# Final status check
$status | Format-Table SamAccountName, CurrentStatus, RetryCount
```

**Validation Checklist:**
- [ ] Status = "PERMISSIONS_SET" (successful)
- [ ] RetryCount = 1
- [ ] Mailbox now in EXO (check: `Get-Mailbox -Identity smbx_002`)

**If FAIL:**
- Check error code: `$status.ErrorCode`
- Check error message: `$status.ErrorMessage`
- Note as known limitation (if applicable)

**Time Check:** ⏱️ Should take 20 minutes

---

### Workflow 5 Summary

| Item | Status | Notes |
|------|--------|-------|
| Failed Mailbox Identified | ✅ / ❌ | ___ |
| Diagnosed Correctly | ✅ / ❌ | ___ |
| Retry Triggered | ✅ / ❌ | ___ |
| Retry Succeeded | ✅ / ❌ | ___ |

**Next:** Proceed to Workflow 6

---

## WORKFLOW 6: Test Health & Status Checks

**Time:** 3:30 PM - 4:30 PM (1 hour)  
**Expected Result:** All health checks pass  

### Step 6.1: Run Health Check

```powershell
$health = Get-MailboxProvisioningHealth
$health | Format-Table -AutoSize
```

**Expected Output:**
```
CheckName                Status      Message
ExchangeOnlineConnected  PASS        Connected to EXO
ADConnected              PASS        Connected to AD
ScheduledTaskRunning     PASS        Task is scheduled and ready
```

**Validation Checklist:**
- [ ] EXO connectivity = PASS
- [ ] AD connectivity = PASS
- [ ] ScheduledTask status = PASS
- [ ] No critical errors

**If FAIL:**
- Document failed check
- Verify connectivity manually
- Note as blocker (if critical) or warning (if non-critical)

**Time Check:** ⏱️ Should take 15 minutes

---

### Step 6.2: Check Final Status of All Provisioned Mailboxes

```powershell
# Get status of all 10 provisioned mailboxes
$allStatus = Get-MailboxProvisioningStatus
$allStatus | Select-Object SamAccountName, CurrentStatus, RetryCount | Format-Table

# Count by status
$allStatus | Group-Object CurrentStatus | Select-Object Name, Count | Format-Table
```

**Expected Output:**
```
SamAccountName  CurrentStatus      RetryCount
smbx_001        PERMISSIONS_SET     0
smbx_002        PERMISSIONS_SET     1
smbx_003        PERMISSIONS_SET     0
...
(All 10 should be PERMISSIONS_SET)
```

**Validation Checklist:**
- [ ] All 10 = "PERMISSIONS_SET"
- [ ] No "FAILED_*" statuses remaining
- [ ] Retry counts reasonable (0-2)
- [ ] No stuck/pending states

**Time Check:** ⏱️ Should take 15 minutes

---

### Step 6.3: Final Sanity Check (Verify in EXO)

```powershell
# Confirm all 10 mailboxes exist in EXO
$eoxMailboxes = Get-Mailbox -Filter "DisplayName -like 'smbx_*'" -ResultSize Unlimited
$eoxMailboxes.Count  # Should be 10

# List all
$eoxMailboxes | Select-Object DisplayName, PrimarySmtpAddress | Format-Table
```

**Validation:**
- [ ] All 10 mailboxes visible in EXO
- [ ] Email addresses correct
- [ ] No duplicates

**Time Check:** ⏱️ Should take 15 minutes

---

### Workflow 6 Summary

| Item | Status | Notes |
|------|--------|-------|
| Health Check Pass | ✅ / ❌ | ___ |
| All Mailboxes PERMISSIONS_SET | ✅ / ❌ | ___ |
| All in EXO | ✅ / ❌ | ___ |

---

## END-OF-DAY SUMMARY (4:30 PM - 5:00 PM)

### Final Validation

Complete this checklist:

| Workflow | Tests | Passed | Failed | Status |
|----------|-------|--------|--------|--------|
| 1. Find & Validate | 3 | __ | __ | ✅ / ❌ |
| 2. Provisioning | 4 | __ | __ | ✅ / ❌ |
| 3. Permissions | 2 | __ | __ | ✅ / ❌ |
| 4. Reporting | 3 | __ | __ | ✅ / ❌ |
| 5. Recovery/Retry | 4 | __ | __ | ✅ / ❌ |
| 6. Health/Status | 3 | __ | __ | ✅ / ❌ |
| **TOTAL** | **19** | **__** | **__** | **✅ / ❌** |

### Document Findings

Create a summary document:

```
MANUAL TESTING REPORT – July 3, 2026

Total Tests Run: 19
Tests Passed: ___
Tests Failed: ___
Success Rate: ___%

Critical Issues:
- [List any blocking issues]

Known Limitations:
- [List non-blocking limitations]

Recommendations:
- [What to do next]

OVERALL RESULT: ✅ PASS / ❌ FAIL
```

### Sign-Off

```
Tested By: _________________
Date: July 3, 2026
Time: 4:30 PM
Approved: ✅ / ⏸️ (with notes)
```

---

## TROUBLESHOOTING GUIDE

### Issue: Candidates not found in AD

**Root Cause:** Accounts not yet created or not synced  
**Solution:**
```powershell
# Check if accounts exist
Get-ADUser -Filter "SamAccountName -like 'smbx_*'" -ErrorAction Stop
# If not found, contact IT-Shop to verify order status
```

---

### Issue: Provisioning fails with "PermissionError"

**Root Cause:** Service account lacks rights to ACL group  
**Solution:**
```powershell
# Check group membership
Get-ADGroupMember -Identity $aclGroup -Recursive

# Verify service account has owner rights
$serviceAccount = "sa_provisioning@contoso.com"
# Contact AD admin to add permissions
```

---

### Issue: Mailbox not visible in EXO after 60 seconds

**Root Cause:** Sync delay (can take up to 5 minutes)  
**Solution:**
```powershell
# Wait longer
Start-Sleep -Seconds 300  # 5 minutes

# Verify connection
Test-ExoConnection
Get-Mailbox -Identity smbx_001 -ErrorAction Stop
```

---

### Issue: Retry fails with "Max retries exceeded"

**Root Cause:** Mailbox already retried too many times  
**Solution:**
```powershell
# Check retry count
$status = Get-MailboxProvisioningStatus -SamAccountName "smbx_001"
$status.RetryCount  # If >= 5, use -Force flag

# Retry with override
Invoke-MailboxProvisioningRetry -SamAccountName "smbx_001" -Force
```

---

## Success Criteria

**All workflows pass if:**

✅ 10 candidates found and validated  
✅ 10 mailboxes provisioned successfully  
✅ Permissions assigned correctly to all  
✅ Reports generated with correct data  
✅ Recovery/retry mechanisms work  
✅ Health checks all pass  

**Decision:** 
- **If ALL pass:** Approve v0.9.0 release ✅
- **If ANY fail:** Document issues, assess severity, determine if blocking

---

**Manual Testing Complete!**  
**Next Step:** Week 2 – Document Updates & Release Preparation
