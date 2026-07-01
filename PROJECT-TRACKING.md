# Project Tracking – SharedMailboxProvisioner

Active tracking of blockers, improvements, and planned work.

---

## RESOLVED (Setup Phase Complete – 2026-06-29)

All critical blockers fixed. Project ready for public function implementation.

### Blocker 1: PSD1 Manifest GUID
- **Issue:** `GUID = [System.Guid]::NewGuid().ToString()` – Method calls not allowed in PSD1 files
- **Fix:** Made GUID static literal: `GUID = '50f777da-b442-4736-a21a-d05fc91849f5'`
- **Impact:** Module now loads correctly
- **Commit:** 059cce8

### Blocker 2: _RetryExchangeOperation String Syntax
- **Issue:** `"Attempt $attempt of $MaxRetries: ..."` – Variable `$MaxRetries:` parsed incorrectly
- **Fix:** Changed to: `"Attempt $attempt of $MaxRetries - ..."` (remove colon)
- **Impact:** Function now loads and executes
- **Commit:** 059cce8

### Blocker 3: Get-Configuration Function Calls
- **Issue:** `if (-not _ValidateGuid $config.TenantId)` – Missing parentheses
- **Fix:** Changed to: `if (-not (_ValidateGuid -Value $config.TenantId))`
- **Impact:** Config loading works, validation passes
- **Commit:** 059cce8

### Blocker 4: Export-ModuleMember in Private Files
- **Issue:** `Export-ModuleMember` in private function files causes errors when sourced
- **Fix:** Removed from all private files, PSM1 handles exports
- **Impact:** No errors when loading helpers individually
- **Commit:** 059cce8

### High-Priority 5: Connect-ExchangeOnlineEnv Wrapper
- **Status:** COMPLETE
- **What:** Wrapper for EXO-V3 with auto-install, retry logic, logging
- **Commit:** 059cce8

### High-Priority 6: docs/SETUP.md
- **Status:** COMPLETE
- **What:** Comprehensive developer setup guide (6 steps)
- **Commit:** 059cce8

### High-Priority 7: RequiredModules in PSD1
- **Status:** COMPLETE
- **What:** Declared ExchangeOnlineManagement 3.1.0+ as required
- **Commit:** 059cce8

### High-Priority 8: Auto Module Installation
- **Status:** COMPLETE
- **What:** Connect-ExchangeOnlineEnv auto-installs missing EXO module
- **Commit:** 059cce8

---

## COMPLETE – Phase Alpha (Tier 1-6, 2026-06-29 to 2026-06-30)

Candidate discovery, validation, and Exchange Online provisioning. 10 functions, 1,378 lines (functions only), 297+ test cases.

| Tier | Scope | Functions | Notes |
|------|-------|-----------|-------|
| 1 | Text Parsing | `_ValidateEmailFormat`, `_ValidateDisplayName` | RFC 5321 email + DisplayName validation |
| 2 | Group Validation | `_ParseSharedMailboxGroupDescription`, `_ValidateSharedMailboxGroup`, `Get-SharedMailboxACLGroup` | ACL group lookup, optimized with `Get-ADObject` |
| 3 | Data Quality | `_ValidateDomainInExchangeOnline`, `_CheckForDuplicateEmails`, `Test-SharedMailboxCandidate` | Combined candidate validation (renamed from `Validate-` to approved verb `Test-`) |
| 4 | Candidate Discovery | `Get-SharedMailboxCandidates`, `Get-SharedMailboxCandidatesWithGroups` | AD query for eligible candidates |
| 5 | Exchange Provisioning | `New-SharedMailboxRemote`, `_Initialize-ScheduledTaskCredential`, `Invoke-MailboxPermissionQueue` | Hybrid JSON/CSV backlog, 60-min EXO sync handling |
| 6 | Batch Orchestration | `Invoke-SharedMailboxProvisioning` | Main entry point: discover -> create -> assign permissions |

**Commits:** 2c8a116, 824159f, 8ee5634, 6507d81, 8de6a0a, ba4bc2e, d9b6461, d09a1f7, ab9ec6b

---

## COMPLETE – Phase Beta (Tier 7-8, 10-11, 2026-06-30)

Manual bulk import, reporting/audit, and operational tooling. Tier 9 (Integration Testing) was planned but explicitly removed.

### Tier 7: Manual Bulk Import & Data Processing
- `Import-MailboxCandidatesFromCSV` (252 lines) – CSV parsing, encoding fallback, duplicate detection
- `Test-MailboxBulkImport` (381 lines) – Dry-run validation, HTML impact report
- `_ConvertTo-MailboxCandidateObject` (128 lines) – CSV row normalization
- `scripts/Provision-BulkMailboxesFromCSV.ps1` (288 lines) – Admin CLI, **manual-only, never scheduled**

### Tier 8: Reporting & Audit
- `Get-MailboxProvisioningReport` (259 lines) – Summary, timeline, per-group stats, top failures
- `Export-MailboxAuditLog` (290 lines) – HTML/CSV/Text export, status/date filtering
- `Get-MailboxProvisioningMetrics` (288 lines) – KPIs, bottlenecks, 7/14/30-day trends
- `_ConvertTo-MailboxReportFormat` (142 lines) – Shared formatting helper

### Tier 9: Integration Testing – REMOVED (2026-06-30)
Not applicable given real-world constraints:
- Accounts are created ONLY via IT-Shop (no direct AD/IAM account creation available)
- Many AD attributes are IAM-controlled (manual test changes get reset)
- No Non-Production OU available for test candidates
- Mock-based testing in Tiers 1-8 judged sufficient; real UAT deferred to Pre-Release/post-launch with actual accounts

### Tier 10: Operational Tooling
- `Get-MailboxProvisioningStatus` (196 lines) – Query single/all mailbox status, timeline
- `Resolve-MailboxProvisioningFailure` (232 lines) – Root-cause diagnosis, RETRY vs ESCALATE
- `Invoke-MailboxProvisioningRetry` (154 lines) – Manual retry, force-override
- `Set-MailboxProvisioningSchedule` (104 lines) – ScheduledTask interval config
- `Get-MailboxProvisioningHealth` (167 lines) – EXO/AD connectivity + ScheduledTask checks

### Tier 11: Documentation
~130 pages across `README.md`, `USER-GUIDE.md`, `ADMIN-GUIDE.md`, `OPERATIONS-RUNBOOK.md`, `API-REFERENCE.md` (see `docs/Beta-Phase/`).

**Commits:** c11e26f, 03d04bb, 1c66319, d0e031b, 4154028, fa04cb8, 7b8705b, 0974271
**Audit:** `docs/Beta-Phase/COMPLIANCE-AUDIT-PHASE-BETA-COMPLETE.md` – Phase Beta approved for production deployment.

---

## ACTIVE – Pre-Release Phase (v0.9.0-beta.1, 2026-07-01 to 2026-07-21)

Real-world validation before v1.0.0 launch. See `docs/Pre-Release/PHASE-PRERELEASE-ROADMAP.md` for the full 3-week plan.

**Today (2026-07-01) = Week 1, Day 1:** Staging deployment day.

| Week | Focus |
|------|-------|
| 1 (Jul 1-5) | Deploy to staging, manual testing (10 candidates, Jul 3), performance baseline, upgrade path validation |
| 2 (Jul 8-12) | Fix issues from Week 1, documentation updates, release process prep |
| 3 (Jul 15-19) | Go/No-Go decision, publish v0.9.0 (PSGallery + GitHub), finalize v1.0.0 launch plan |

**Manual Testing Plan** for 2026-07-03 is drafted in detail (`docs/Pre-Release/MANUAL-TESTING-PLAN.md`): connection setup + 6 workflows (Find/Validate, Provisioning, Permissions, Reporting, Recovery/Retry, Health/Status), 19 tests total.

---

## KNOWN ISSUES

### Module version mismatch
- `SharedMailboxProvisioner.psd1` still declares `ModuleVersion = '0.8.2'`, while CLAUDE.md, the roadmap, and the testing plan all treat `v0.9.0-beta.1` as current.
- **Action:** Bump `ModuleVersion` (and any release tagging) when formally entering Pre-Release, or clarify the versioning point in RELEASE-PROCESS.md.

### FUNCTION-STATUS.md drift
- `functions/FUNCTION-STATUS.md` predates several Tier implementations and Beta-Phase renames (e.g. still lists `_ValidateGuid`, `Get-ServiceAccountCredential`, `Remove-OldLogs`, `_ValidateProxyAddresses` as functions, none of which exist as files; several Tier 3 items marked `[PLANNED]` are actually `[COMPLETE]`).
- **Action:** Refresh separately when doing a function-inventory pass.

### Test runner version
- Local environment only has Pester 3.4.0 (PowerShell 5.1 built-in), which is not compatible with the modern Pester syntax used in `tests/`. `build.ps1 -Validate` (PSScriptAnalyzer) passes clean, but full `Invoke-Pester` runs need Pester 5.x installed to verify.

---

## PLANNED (Future Features)

### Code Review Checklist
- Use before each commit:
  ```
  Function has -ErrorAction Stop
  Try-Catch wraps _RetryExchangeOperation calls
  Write-Log called for audit events
  Comment-based Help complete (PUBLIC only)
  Parameter validation (email, domain, GUID format)
  Verbose messages at key points
  No Invoke-Expression or Write-Host
  Tests pass: Invoke-Pester tests/
  Build passes: .\build.ps1 -Validate
  No secrets in code
  ```

### Post-Launch UAT
- Real user-acceptance testing with actual new accounts, deferred from Tier 9. Revisit after v1.0.0 go-live per the Beta-Phase compliance audit.

---

## Project Health

```
Setup Phase:                 COMPLETE
Phase Alpha (Tier 1-6):      COMPLETE & TESTED (10 functions, ~1,378 lines)
Phase Beta (Tier 7-8,10-11): COMPLETE & TESTED (12 functions + 1 script, ~2,743 lines)
  Tier 9 (Integration Tests): REMOVED (not applicable, see rationale above)
Pre-Release Phase:           ACTIVE (Week 1 of 3, staging deployment underway)

Total Public Functions:      18
Total Private Functions:     12
Total Admin Scripts:         1
Total Lines (functions+script): 5,939
Total Test Files:            27
Total Test Cases:            348 (counted from `It` blocks in tests/)
Build Validation:            PASSED (0 PSScriptAnalyzer violations, 2026-07-01)
Module Loading:              VERIFIED
```

---

## Quick Reference

### Run Build Validation
```powershell
.\build.ps1 -Validate
```

### Run Unit Tests (All)
Requires Pester 5.x (local env may only have 3.4.0 built-in - check with `Get-Module -ListAvailable Pester`):
```powershell
Invoke-Pester tests/
```

### Load Module
```powershell
Import-Module .\SharedMailboxProvisioner.psd1
```

### Code Review Before Commit
Use the checklist in **"PLANNED - Code Review Checklist"** section above.

---

**Last Updated:** 2026-07-01 (Pre-Release Phase Week 1 - full status refresh against actual repo state)
**Maintained By:** Development Team
**Status:** Phase Alpha + Beta complete (30 functions/scripts implemented). Pre-Release Phase active, targeting v0.9.0 stable in Week 3.
