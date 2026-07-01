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

**Success Criteria:** All 6 workflows pass validation with 10 candidates -> Proceed to v0.9.0 release.

**Connection setup note:** Steps 0.1-0.6 below were pre-validated live against the real ETHZ tenant/on-prem environment on 2026-07-01 (two days ahead of the main test day) to shake out connection-level issues before Workflow testing begins. Results are recorded inline per step.

---

## CONNECTION SETUP (8:00 AM - 9:00 AM)

**CRITICAL PREREQUISITE:** All connections must be established BEFORE starting tests.

**What you need before starting:**
- App Registration (Application/client ID) with `Exchange.ManageAsApp` API permission, admin consent granted
- Authentication certificate for that App Registration, already installed in the local certificate store (`Cert:\CurrentUser\My` or `Cert:\LocalMachine\My`) - get its thumbprint via `Get-ChildItem Cert:\CurrentUser\My`
- Tenant's `*.onmicrosoft.com` domain and TenantId
- Outbound proxy address, if your network requires one for reaching `outlook.office365.com`
- On-premises Exchange Service Account name and on-prem Exchange server FQDN (only if syncing on-prem mailboxes)
- AD OU path containing the 10 `smbx_*` test candidates

### Step 0.1: Import Module

```powershell
$modulePath = "S:\Scheduled Tasks\Exchange SE\SharedMailboxProvisioner\SharedMailboxProvisioner.psd1"
Import-Module $modulePath -Force -ErrorAction Stop

Get-Module SharedMailboxProvisioner | Format-Table Name, Version
Test-Path $modulePath          # Should be $true
$PSVersionTable.PSVersion      # Should be 5.1+
```

**Expected Output:**
```
Name                     Version
----                     -------
SharedMailboxProvisioner 0.9.0
```
Note: `Get-Module`'s `Version` column only ever shows the base version (`0.9.0`). The `-beta1`
pre-release tag lives in `PrivateData.PSData.Prerelease` and never appears here - that's normal
for any PowerShell module, not specific to this one.

**If FAIL:**
```powershell
Test-Path $modulePath           # Check module file exists
$PSVersionTable.PSVersion       # Check PowerShell version
```

**Validation Checklist:**
- [x] Module imports without error (2026-07-01: confirmed, `SharedMailboxProvisioner 0.9.0`)
- [x] PowerShell version is 5.1+ (2026-07-01: confirmed, `5.1.26100`)

**Time Check:** 5 minutes

---

### Step 0.2: One-Time Environment Setup

**Run this once per environment** (skip if already done for this environment). It creates the
on-premises Service Account credential file AND populates the EXO app connection config in a
single step, via `scripts\Initialize-ProvisioningConnections.ps1`.

**Must be run:**
- As the actual on-premises Service Account (identity check enforced by the script)
- Elevated (Administrator token). If you reach this account via "Run as different user" rather
  than an interactive Windows logon, that alone does NOT elevate - from the already-open session
  running as that account, use `Start-Process powershell -Verb RunAs` to open a second, elevated
  window under the same identity (triggers a UAC consent prompt, not a new credential prompt,
  provided the account is a local admin).

```powershell
cd "S:\Scheduled Tasks\Exchange SE\SharedMailboxProvisioner"

.\scripts\Initialize-ProvisioningConnections.ps1 -UserName "D\SvcExchangeAdmin" -Environment prod `
    -Organization "<tenant>.onmicrosoft.com" `
    -AppId "<app-registration-client-id>" `
    -CertificateThumbprint "<certificate-thumbprint>"
```

**Expected Output:**
```
[OK] User verification: PASS
[OK] Admin verification: PASS
[1/2] Creating local Service Account credential file...
[OK] Credential file created: ...\config\Credential_D_SvcExchangeAdmin.clixml
[2/2] Updating config.prod.json with EXO app connection...
[OK] Config updated: ...\config\config.prod.json
Setup Complete!
```

**Validation Checklist:**
- [ ] `[OK] User verification: PASS` (running as the correct on-prem Service Account)
- [ ] `[OK] Admin verification: PASS` (elevated)
- [ ] Credential file created at `config\Credential_{UserName}.clixml`
- [ ] `config\config.<Environment>.json` created/updated with `Organization`/`AppId`/`CertificateThumbprint`

**If FAIL:**
```powershell
# "You must run this script as the Service Account" - wrong identity, re-check -UserName
# and which account the session is actually running as ($env:USERNAME / whoami)

# "This script must run with elevated privileges" - session isn't elevated; see the
# Start-Process powershell -Verb RunAs approach above
```

**Note on domains:** The on-premises AD domain (NetBIOS `D`, e.g. `D\SvcExchangeAdmin`) is
distinct from the cloud tenant name (`ETHZ` / `ethz.onmicrosoft.com`) used for EXO. Don't mix
them up in `-UserName` vs. `-Organization`.

**Time Check:** 10 minutes (one-time per environment)

---

### Step 0.3: Connect to Exchange Online (EXO)

**Required:** App Registration with certificate-based authentication - see Step 0.2 and
`Connect-ExchangeOnlineEnv` (`functions/Public/Connect-ExchangeOnlineEnv.ps1`). Interactive/
credential-based auth is not used.

```powershell
# Option A: Fully config-driven (recommended once Step 0.2 has been run for this environment) -
# Tenant/AppId/CertificateThumbprint are all resolved from config.prod.json automatically:
Connect-ExchangeOnlineEnv -Environment prod

# Option B: Explicit parameters (no config setup needed, e.g. for a throwaway test)
$tenant                = "<tenant>.onmicrosoft.com"
$appId                 = "<app-registration-client-id>"
$certificateThumbprint = "<certificate-thumbprint>"
Connect-ExchangeOnlineEnv -Tenant $tenant -AppId $appId -CertificateThumbprint $certificateThumbprint

# If staging requires an outbound proxy, add to either option: -ProxyUrl "http://proxyserver:8080"
# Default -Prefix "ETH" renames cloud cmdlets (Get-Mailbox -> Get-ETHMailbox, etc.) so this
# session can stay open alongside the on-premises session from Step 0.4 without name collisions.

# Verify connection
Get-ConnectionInformation
Get-ETHMailbox -ResultSize 1   # Quick test - prefixed cloud cmdlet
```

**Expected Output:**
```
[INFO] Connecting to Exchange Online (attempt 1/3)...
[OK] Connected to Exchange Online successfully (tenant: ethz.onmicrosoft.com, prefix: ETH)

State                     : Connected
CertificateAuthentication : True
Organization              : ethz.onmicrosoft.com
...

DisplayName      PrimarySmtpAddress
-----------      ------------------
<some mailbox>   <address>
```

**Validation Checklist:**
- [x] `Connect-ExchangeOnlineEnv` prints `[OK] Connected to Exchange Online successfully` (2026-07-01: confirmed, tenant `ethz.onmicrosoft.com`, prefix `ETH`)
- [x] `Get-ConnectionInformation` shows an active session for the correct tenant (2026-07-01: `State: Connected`, `CertificateAuthentication: True`)
- [x] `Get-ETHMailbox` (prefixed) can list mailboxes (at least 1) (2026-07-01: returned `phdhoersaal@ethz.ch`)

**If FAIL:**
```powershell
$error[0]
# - Certificate not found/expired: verify the thumbprint matches a valid, non-expired cert
#   in Cert:\CurrentUser\My (or LocalMachine\My)
# - Wrong AppId or tenant: double-check the App Registration's Application (client) ID and tenant
# - Missing consent: Azure AD > App Registration > API permissions > verify Exchange.ManageAsApp
#   has admin consent granted
# - Licensing: ensure the mailbox(es) the app manages have valid EXO licenses
```

**Time Check:** 10 minutes

---

### Step 0.4: Connect to Exchange On-Premises (Optional, if needed)

**Only if your environment has Exchange On-Premises and you need to sync mailboxes.** Requires
Step 0.2 to have been run at least once (for the credential file).

```powershell
# Mirrors the same current-context-first, credential-file-fallback pattern
# New-SharedMailboxRemote uses internally (functions/Public/New-SharedMailboxRemote.ps1
# -> _GetExchangePSSession).
$onPremUri      = "http://mailm120.d.ethz.ch/PowerShell/"        # Replace with your server
$credentialPath = "config\Credential_D_SvcExchangeAdmin.clixml"  # From Step 0.2

try {
    $session = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri $onPremUri -ErrorAction Stop
    Write-Output "[OK] Connected with current user context"
}
catch {
    Write-Output "[INFO] Current user context failed: $($_.Exception.Message)"
    Write-Output "[INFO] Falling back to credential file..."
    $credential = Import-Clixml -Path $credentialPath -ErrorAction Stop
    $session = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri $onPremUri -Credential $credential -ErrorAction Stop
}

Import-PSSession $session -ErrorAction Stop -DisableNameChecking

# Verify connection (unprefixed on-prem cmdlets, e.g. Get-Mailbox - distinct from
# Get-ETHMailbox in Step 0.3 thanks to the "ETH" prefix on the cloud session)
Get-ExchangeServer
Get-Mailbox -ResultSize 1
```

**Expected Output:**
```
[OK] Connected with current user context   (or the credential-file fallback message)

Name           Site             ServerRole
----           ----             ----------
EX01           Default-Site-1   Mailbox, CAServer
EX02           Default-Site-1   Mailbox, CAServer
```

**Validation Checklist:**
- [x] Connected to on-prem Exchange, current user context or credential file fallback (2026-07-01: current user context succeeded directly against `mailm120`, no fallback needed)
- [x] Can list on-prem Exchange servers (2026-07-01: `Get-ExchangeServer` returned `mailm220`, `mailm120`)
- [x] `Get-Mailbox` (unprefixed) returns a result without colliding with `Get-ETHMailbox` from Step 0.3 (2026-07-01: returned a result - happened to be a disabled `SystemMailbox{...}` object with a pre-existing "Database is mandatory on UserMailbox" warning, unrelated to this module; re-run with a higher `-ResultSize` or a specific `-Identity` to avoid hitting system objects)
- [x] Session active and imported (2026-07-01: `Import-PSSession` succeeded, on-prem cmdlets like `Add-ADPermission` available)

**If FAIL or NOT APPLICABLE:**
```powershell
# If on-prem not needed, skip this step
$error[0]
# - Credential file missing: run scripts\Initialize-ProvisioningConnections.ps1 first (Step 0.2)
# - Server name wrong: verify FQDN
# - Current user context failing: expected if not running as the Service Account - the
#   credential-file fallback should still succeed
# - Network: check connectivity to the server
```

**Time Check:** 10 minutes (skip if not needed)

---

### Step 0.5: Connect to Active Directory (AD)

```powershell
Get-ADDomain   # Basic test
Get-ADForest   # Get forest info

# Find the OU containing the 10 prepared test candidates
$testOU = "OU=SharedMailboxTest,DC=d,DC=ethz,DC=ch"   # Replace with your actual OU
Get-ADUser -SearchBase $testOU -Filter "Name -like 'smbx_*'" -ResultSetSize 5
```

**Expected Output:**
```
DNSRoot      : d.ethz.ch
DomainMode   : Windows2016Domain
NetBIOSName  : D

DistinguishedName : CN=smbx_001,OU=SharedMailboxTest,DC=d,DC=ethz,DC=ch
Name              : smbx_001
SamAccountName    : smbx_001
```

**Validation Checklist:**
- [x] Can query AD domain info (2026-07-01: `Get-ADDomain`/`Get-ADForest` confirmed, domain `d.ethz.ch`, NetBIOSName `D` - matches the on-prem Service Account domain from Step 0.2/0.4)
- [x] Can list users in an AD OU (2026-07-01: confirmed against a general OU, `OU=EthUsers,DC=d,DC=ethz,DC=ch`, 5 real users returned)
- [ ] Test candidates visible (`smbx_*` accounts in the actual test-candidate OU) - not yet checked; the OU used above (`EthUsers`) was a general OU, not the dedicated shared-mailbox test-candidate OU. Re-run the `-Filter "Name -like 'smbx_*'"` query above against the real test OU once it's confirmed.

**If FAIL:**
```powershell
Get-ADDomain -ErrorAction Stop                          # Verify domain access
Get-ADOrganizationalUnit -Filter "Name -eq 'SharedMailboxTest'"   # Check if test OU exists
# - Not domain-joined: verify machine is a domain member
# - OU path wrong: ask infrastructure team for the correct path
# - User lacks AD permission: request elevated access
```

**Time Check:** 10 minutes

---

### Step 0.6: Verify All Connections

```powershell
function Test-SharedMailboxProvisionerConnections {
    Write-Output "Testing all connections..."

    # Test EXO (prefixed cmdlet - avoids hitting the unprefixed on-premises session)
    try {
        Get-ETHMailbox -ResultSize 1 -ErrorAction Stop | Out-Null
        Write-Output "[EXO] Connected"
    } catch {
        Write-Output "[EXO] Failed: $_"
        return $false
    }

    # Test AD
    try {
        Get-ADDomain -ErrorAction Stop | Out-Null
        Write-Output "[AD] Connected"
    } catch {
        Write-Output "[AD] Failed: $_"
        return $false
    }

    # Test Module
    try {
        Get-Module SharedMailboxProvisioner -ErrorAction Stop | Out-Null
        Write-Output "[Module] Loaded"
    } catch {
        Write-Output "[Module] Failed: $_"
        return $false
    }

    Write-Output "All connections verified!"
    return $true
}

$allConnected = Test-SharedMailboxProvisionerConnections
if (-not $allConnected) { exit 1 }
```

**Expected Output:**
```
Testing all connections...
[EXO] Connected
[AD] Connected
[Module] Loaded
All connections verified!
```

**Validation Checklist:**
- [ ] EXO connection working
- [ ] AD connection working
- [ ] Module loaded and accessible

**If ANY FAIL:**
- **STOP** - do not proceed with testing
- Contact DevOps team
- Reschedule testing once connections are restored

**Time Check:** 5 minutes

---

### Connection Setup Summary

| Connection | Status | Details |
|-----------|--------|---------|
| Module Import | Pass | 2026-07-01: `SharedMailboxProvisioner 0.9.0`, PS `5.1.26100` |
| One-Time Setup (0.2) | Pass | 2026-07-01: credential file + `config.prod.json` created via `Initialize-ProvisioningConnections.ps1` |
| EXO Connected | Pass | 2026-07-01: cert-store app auth via `Connect-ExchangeOnlineEnv`, tenant `ethz.onmicrosoft.com`, prefix `ETH` |
| EXO On-Prem (if needed) | Pass | 2026-07-01: current user context against `mailm120`, `Get-ExchangeServer`/`Get-Mailbox` both returned data |
| AD Connected | Pass | 2026-07-01: `Get-ADDomain`/`Get-ADForest` confirmed against `d.ethz.ch`; `smbx_*` test-candidate OU still to be checked separately |
| All Verified (0.6) | Pending | Output not yet confirmed |

**If all marked Pass:** Proceed to Pre-Test Checklist
**If any marked Fail:** STOP and fix connections

---

## Pre-Test Checklist (Before 9:00 AM)

**15 minutes before testing starts:**

- [ ] Staging environment accessible (EXO + AD)
- [ ] Module loaded: `Import-Module "S:\Scheduled Tasks\Exchange SE\SharedMailboxProvisioner\SharedMailboxProvisioner.psd1"`
- [ ] 10 test candidates visible in AD (real test-candidate OU, not a placeholder)
- [ ] Provisioning queue empty (`$backlog = @()`)
- [ ] Logging directory accessible
- [ ] Report templates ready
- [ ] Laptop connected (no VPN issues)

**If any item fails -> STOP -> Report to DevOps -> Reschedule testing**

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
- All 10 candidates listed
- Each has SamAccountName (smbx_*)
- Each has Email
- Each has ACLGroup

**If FAIL:**
- Check if accounts in AD: `Get-ADUser -Filter "SamAccountName -like 'smbx_*'"`
- Check ACL group exists: `Get-ADGroup -Identity "GroupName"`
- Document error and continue with available candidates

**Time Check:** Should take 5 minutes

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

**Time Check:** Should take 10 minutes

---

### Step 1.3: Spot-Check 3 Random Candidates

Pick candidates #2, #5, #8 (random selection)

```powershell
$candidate = $candidatesWithGroups[1]  # Index 1 = candidate #2
Write-Output "Checking: $($candidate.SamAccountName)"
Write-Output "Email: $($candidate.Email)"
Write-Output "ACL Group: $($candidate.ACLGroup)"
Write-Output "Status: $($candidate.Status)"
```

**Validation:**
- [ ] SamAccountName format correct (smbx_*)
- [ ] Email valid format
- [ ] ACL Group resolvable in AD
- [ ] Status = Valid

**Time Check:** Should take 5 minutes

---

### Workflow 1 Summary

| Item | Status | Notes |
|------|--------|-------|
| Candidates Found | Pass / Fail | ___ |
| Groups Resolved | Pass / Fail | ___ |
| Validation Passed | Pass / Fail | ___ |

**Next:** Proceed to Workflow 2

---

## WORKFLOW 2: Test Provisioning

**Time:** 10:00 AM - 12:00 PM (2 hours)
**Candidates:** All 10
**Expected Result:** All 10 mailboxes created in EXO

### Step 2.1: Prepare CSV for Bulk Import

```powershell
$csvPath = "C:\temp\bulk-import-test.csv"
$candidates | Export-Csv -Path $csvPath -NoTypeInformation

Test-Path $csvPath                  # Should be $true
Get-Content $csvPath -TotalCount 5  # Show first 5 lines
```

**Validation:**
- [ ] CSV file exists
- [ ] CSV contains all 10 rows + header
- [ ] CSV columns: SamAccountName, DisplayName, Email, ACLGroup, AdminGroup

**Time Check:** Should take 5 minutes

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
- [ ] Duplicates detected (if any) -> handled correctly

**If FAIL:**
- Check CSV format: `Import-Csv $csvPath | Get-Member`
- Look for encoding issues (UTF-8 vs ASCII)
- Check for duplicate SAM accounts in CSV
- Document error

**Time Check:** Should take 10 minutes

---

### Step 2.3: Dry-Run Validation (No Provisioning Yet)

```powershell
$dryRun = Test-MailboxBulkImport -Candidates $import.Candidates -GenerateReport $true
$dryRun.CanProceed              # Should be $true
$dryRun.ValidCandidates.Count   # Should be 10
$dryRun.ConflictingCandidates   # Should be 0
$dryRun.EstimatedDuration       # Shows expected time
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

**Time Check:** Should take 15 minutes

---

### Step 2.4: Actually Provision All 10 Mailboxes

```powershell
Write-Output "About to provision 10 mailboxes. Press ENTER to continue..."
Read-Host

# Provision-BulkMailboxesFromCSV.ps1 is a standalone script under scripts/, not an
# exported module function - invoke it via its path, not by name.
$provisionResult = & "S:\Scheduled Tasks\Exchange SE\SharedMailboxProvisioner\scripts\Provision-BulkMailboxesFromCSV.ps1" `
    -CsvPath $csvPath -DryRun $false

$provisionResult.Count  # Should be 10
$provisionResult | Select-Object SamAccountName, Status | Format-Table
```

**Expected Output:**
- All 10 mailboxes status = "MAILBOX_CREATED" or "PERMISSIONS_SET"
- No "FAILED_*" statuses

**Validation in EXO (Parallel Check):**

```powershell
# Wait 60 seconds for sync, then check EXO
Start-Sleep -Seconds 60

# Prefixed cloud cmdlet (ETH) - see Step 0.3
$createdMailboxes = Get-ETHMailbox -Filter "DisplayName -like 'smbx_*'" -ResultSize Unlimited
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

**Time Check:** Should take 45 minutes (including EXO sync wait)

---

### Workflow 2 Summary

| Item | Status | Count | Notes |
|------|--------|-------|-------|
| CSV Created | Pass / Fail | 10 | ___ |
| Imported | Pass / Fail | 10 | ___ |
| Dry-Run Passed | Pass / Fail | -- | ___ |
| Provisioned | Pass / Fail | 10 | ___ |
| In EXO | Pass / Fail | 10 | ___ |

**Next:** Proceed to Workflow 3

---

## WORKFLOW 3: Test Permission Assignment

**Time:** 12:00 PM - 1:00 PM (1 hour)
**Candidates:** All 10 (provisioned)
**Expected Result:** All groups correctly assigned as Full Access

### Step 3.1: Check Permissions in Each Mailbox

```powershell
# Pick 3 random mailboxes (e.g., #2, #5, #8)
$mailbox = $createdMailboxes[0]

# Prefixed cloud cmdlet (ETH) - see Step 0.3
Get-ETHMailboxPermission -Identity $mailbox.Identity |
  Where-Object { $_.AccessRights -contains "FullAccess" } |
  Format-Table User, AccessRights
```

**Expected Output:**
- ACL group has "FullAccess" right
- Service account has "FullAccess" right (if applicable)

**Validation Checklist (for each of 3 mailboxes):**
- [ ] ACL group listed with FullAccess
- [ ] No unexpected users
- [ ] Group distinguishedName is correct

**If FAIL:**
- Check group assignment: `Get-ADGroupMember -Identity $aclGroup`
- Check EXO sync status
- Note permission errors

**Time Check:** Should take 20 minutes

---

### Step 3.2: Verify Send-As Permissions (If Applicable)

```powershell
$mailbox = $createdMailboxes[0]

# Prefixed cloud cmdlet (ETH) - see Step 0.3
Get-ETHRecipientPermission -Identity $mailbox.Identity |
  Format-Table Trustee, AccessRights
```

**Validation:**
- [ ] Group has "SendAs" permission (if configured)
- [ ] Service account has "SendAs" (if applicable)

**Time Check:** Should take 10 minutes

---

### Workflow 3 Summary

| Item | Status | Notes |
|------|--------|-------|
| Full Access Set | Pass / Fail | ___ |
| Send-As Set | Pass / Fail | ___ |
| Group Sync OK | Pass / Fail | ___ |

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
TotalProvisioned        : 10
TotalFailed             : 0
SuccessRate             : 100%
AverageTimeToCompletion : 00:02:30
```

**Time Check:** Should take 15 minutes

---

### Step 4.2: Export Audit Log (Multiple Formats)

```powershell
$htmlPath = "C:\temp\audit-report.html"
Export-MailboxAuditLog -Format HTML -OutputPath $htmlPath
Write-Output "HTML report: $htmlPath"

$csvPath = "C:\temp\audit-report.csv"
Export-MailboxAuditLog -Format CSV -OutputPath $csvPath
Write-Output "CSV report: $csvPath"

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
- Check audit log directory exists and is writable
- Review Export-MailboxAuditLog errors

**Time Check:** Should take 20 minutes

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

**Time Check:** Should take 15 minutes

---

### Workflow 4 Summary

| Item | Status | Notes |
|------|--------|-------|
| Report Generated | Pass / Fail | ___ |
| HTML Export | Pass / Fail | ___ |
| CSV Export | Pass / Fail | ___ |
| Metrics Calculated | Pass / Fail | ___ |

**Next:** Proceed to Workflow 5

---

## WORKFLOW 5: Test Recovery & Retry

**Time:** 2:00 PM - 3:30 PM (1.5 hours)
**Candidates:** 1-2 mailboxes (to simulate failure)
**Expected Result:** Recovery mechanisms work correctly

### Step 5.1: Identify a Failed Provisioning

**Choice A: Use Existing Failures** (preferred, if any occurred in Workflow 2)
```powershell
$failures = $provisionResult | Where-Object { $_.Status -like "FAILED_*" }
$failures | Format-Table SamAccountName, Status, ErrorCode
```

**Choice B: Intentionally Cause Failure** (only if no real failures occurred, not recommended in production)
```powershell
$backlogPath = "S:\Scheduled Tasks\Exchange SE\SharedMailboxProvisioner\data\mailbox-provisioning-queue.json"
$backlog = Get-Content -Path $backlogPath -Raw | ConvertFrom-Json
$failMailbox = $backlog[0]
$failMailbox.Status = "FAILED_PERMISSIONS"
$failMailbox.ErrorCode = "PermissionError"
$failMailbox.ErrorMessage = "Service account lacks permissions"
$backlog | ConvertTo-Json | Set-Content -Path $backlogPath
```

**Validation:**
- [ ] At least 1 failed mailbox in queue
- [ ] Error code and message populated

**Time Check:** Should take 10 minutes

---

### Step 5.2: Diagnose Failure

```powershell
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

**Time Check:** Should take 10 minutes

---

### Step 5.3: Manually Retry Failed Mailbox

```powershell
$retryResult = Invoke-MailboxProvisioningRetry -SamAccountName "smbx_002"
$retryResult  # Should be $true

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

**Time Check:** Should take 20 minutes

---

### Step 5.4: Verify Retry Succeeded

```powershell
$maxWait = 60
$startTime = Get-Date
while ((Get-Date) - $startTime -lt [TimeSpan]::FromSeconds($maxWait)) {
    $status = Get-MailboxProvisioningStatus -SamAccountName "smbx_002"
    if ($status.CurrentStatus -eq "PERMISSIONS_SET") {
        Write-Output "Retry succeeded!"
        break
    }
    Start-Sleep -Seconds 5
}

$status | Format-Table SamAccountName, CurrentStatus, RetryCount
```

**Validation Checklist:**
- [ ] Status = "PERMISSIONS_SET" (successful)
- [ ] RetryCount = 1
- [ ] Mailbox now in EXO (check: `Get-ETHMailbox -Identity smbx_002`)

**If FAIL:**
- Check error code: `$status.ErrorCode`
- Check error message: `$status.ErrorMessage`
- Note as known limitation (if applicable)

**Time Check:** Should take 20 minutes

---

### Workflow 5 Summary

| Item | Status | Notes |
|------|--------|-------|
| Failed Mailbox Identified | Pass / Fail | ___ |
| Diagnosed Correctly | Pass / Fail | ___ |
| Retry Triggered | Pass / Fail | ___ |
| Retry Succeeded | Pass / Fail | ___ |

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
OverallStatus : HEALTHY
Issues        : {}
```

**Validation Checklist:**
- [ ] EXO connectivity check passes
- [ ] AD connectivity check passes
- [ ] ScheduledTask status check passes
- [ ] No critical errors

**Known issue (tracked in PROJECT-TRACKING.md, not yet fixed):** `Get-MailboxProvisioningHealth`'s
EXO check (`_CheckEXOHealth`) looks for a classic `Get-PSSession -ConfigurationName
"Microsoft.Exchange"`, which modern EXO-V3 REST connections (like Step 0.3's) don't create. It
may report the cloud connection as degraded even when Step 0.3/0.6 above confirm it's fine -
don't treat that specific sub-check as authoritative until it's fixed.

**If FAIL:**
- Document failed check
- Verify connectivity manually
- Note as blocker (if critical) or warning (if non-critical, see known issue above)

**Time Check:** Should take 15 minutes

---

### Step 6.2: Check Final Status of All Provisioned Mailboxes

```powershell
$allStatus = Get-MailboxProvisioningStatus
$allStatus | Select-Object SamAccountName, CurrentStatus, RetryCount | Format-Table
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

**Time Check:** Should take 15 minutes

---

### Step 6.3: Final Sanity Check (Verify in EXO)

```powershell
# Prefixed cloud cmdlet (ETH) - see Step 0.3
$eoxMailboxes = Get-ETHMailbox -Filter "DisplayName -like 'smbx_*'" -ResultSize Unlimited
$eoxMailboxes.Count  # Should be 10
$eoxMailboxes | Select-Object DisplayName, PrimarySmtpAddress | Format-Table
```

**Validation:**
- [ ] All 10 mailboxes visible in EXO
- [ ] Email addresses correct
- [ ] No duplicates

**Time Check:** Should take 15 minutes

---

### Workflow 6 Summary

| Item | Status | Notes |
|------|--------|-------|
| Health Check Pass | Pass / Fail | ___ |
| All Mailboxes PERMISSIONS_SET | Pass / Fail | ___ |
| All in EXO | Pass / Fail | ___ |

---

## END-OF-DAY SUMMARY (4:30 PM - 5:00 PM)

### Final Validation

Complete this checklist:

| Workflow | Tests | Passed | Failed | Status |
|----------|-------|--------|--------|--------|
| 1. Find & Validate | 3 | __ | __ | Pass / Fail |
| 2. Provisioning | 4 | __ | __ | Pass / Fail |
| 3. Permissions | 2 | __ | __ | Pass / Fail |
| 4. Reporting | 3 | __ | __ | Pass / Fail |
| 5. Recovery/Retry | 4 | __ | __ | Pass / Fail |
| 6. Health/Status | 3 | __ | __ | Pass / Fail |
| **TOTAL** | **19** | **__** | **__** | **Pass / Fail** |

### Document Findings

Create a summary document:

```
MANUAL TESTING REPORT - July 3, 2026

Total Tests Run: 19
Tests Passed: ___
Tests Failed: ___
Success Rate: ___%

Critical Issues:
- [List any blocking issues]

Known Limitations:
- [List non-blocking limitations, e.g. Get-MailboxProvisioningHealth's EXO check - see Workflow 6]

Recommendations:
- [What to do next]

OVERALL RESULT: PASS / FAIL
```

### Sign-Off

```
Tested By: _________________
Date: July 3, 2026
Time: 4:30 PM
Approved: Yes / With notes
```

---

## TROUBLESHOOTING GUIDE

### Issue: Candidates not found in AD

**Root Cause:** Accounts not yet created or not synced
**Solution:**
```powershell
Get-ADUser -Filter "SamAccountName -like 'smbx_*'" -ErrorAction Stop
# If not found, contact IT-Shop to verify order status
```

---

### Issue: Provisioning fails with "PermissionError"

**Root Cause:** Service account lacks rights to ACL group
**Solution:**
```powershell
Get-ADGroupMember -Identity $aclGroup -Recursive
# Verify service account has owner rights, contact AD admin to add permissions if not
```

---

### Issue: Mailbox not visible in EXO after 60 seconds

**Root Cause:** Sync delay (can take up to 5 minutes)
**Solution:**
```powershell
Start-Sleep -Seconds 300  # 5 minutes
Get-ConnectionInformation                    # Verify EXO session still active
Get-ETHMailbox -Identity smbx_001 -ErrorAction Stop
```

---

### Issue: Retry fails with "Max retries exceeded"

**Root Cause:** Mailbox already retried too many times
**Solution:**
```powershell
$status = Get-MailboxProvisioningStatus -SamAccountName "smbx_001"
$status.RetryCount  # If >= 5, use -Force flag
Invoke-MailboxProvisioningRetry -SamAccountName "smbx_001" -Force
```

---

### Issue: "command not found" for a script under scripts\

**Root Cause:** Scripts (`Initialize-ProvisioningConnections.ps1`, `Provision-BulkMailboxesFromCSV.ps1`)
are standalone files, not exported module functions - they must be invoked by path, and that
path is relative to your current working directory, not the module's location.
**Solution:**
```powershell
cd "S:\Scheduled Tasks\Exchange SE\SharedMailboxProvisioner"
.\scripts\Initialize-ProvisioningConnections.ps1 -UserName "D\SvcExchangeAdmin" ...
# or, from any directory:
& "S:\Scheduled Tasks\Exchange SE\SharedMailboxProvisioner\scripts\Initialize-ProvisioningConnections.ps1" -UserName "D\SvcExchangeAdmin" ...
```

---

## Success Criteria

**All workflows pass if:**

- 10 candidates found and validated
- 10 mailboxes provisioned successfully
- Permissions assigned correctly to all
- Reports generated with correct data
- Recovery/retry mechanisms work
- Health checks all pass (or only the known `Get-MailboxProvisioningHealth` EXO-detection issue, see Workflow 6)

**Decision:**
- **If ALL pass:** Approve v0.9.0 release
- **If ANY fail:** Document issues, assess severity, determine if blocking

---

**Manual Testing Complete!**
**Next Step:** Week 2 - Document Updates & Release Preparation
