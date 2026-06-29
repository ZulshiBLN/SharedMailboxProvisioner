# Project Tracking – SharedMailboxProvisioner

Active tracking of blockers, improvements, and planned work.

---

## ✅ RESOLVED (Setup Phase Complete – 2026-06-29)

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
- **Status:** ✅ IMPLEMENTED
- **What:** Wrapper for EXO-V3 with auto-install, retry logic, logging
- **Lines:** ~170 lines of fully documented code
- **Features:** Exponential backoff, connection pooling, audit logging
- **Commit:** 059cce8

### High-Priority 6: docs/SETUP.md
- **Status:** ✅ IMPLEMENTED
- **What:** Comprehensive developer setup guide (6 steps)
- **Lines:** ~350 lines covering prerequisites, config, credentials, testing
- **Covers:** 3 credential options, pre-commit hooks, troubleshooting
- **Commit:** 059cce8

### High-Priority 7: RequiredModules in PSD1
- **Status:** ✅ IMPLEMENTED
- **What:** Declared ExchangeOnlineManagement 3.1.0+ as required
- **Impact:** PowerShell validates dependency on module load
- **Commit:** 059cce8

### High-Priority 8: Auto Module Installation
- **Status:** ✅ IMPLEMENTED
- **What:** Connect-ExchangeOnlineEnv auto-installs missing EXO module
- **Impact:** No manual module install needed
- **Commit:** 059cce8

---

## 📋 IN-PROGRESS (Current Phase)

### Tier 1: Data Quality Validation Helpers (COMPLETE - 2026-06-29)

**Status:** ✅ COMPLETE

Implemented Functions:
1. **_ValidateEmailFormat.ps1** (Private) 
   - RFC 5321 email validation
   - 16 unit test cases (valid + invalid formats)
   - Status: COMPLETE & TESTED
   - Compliance: All STRUCTURE.md & CLAUDE.md rules

2. **_ValidateDisplayName.ps1** (Private)
   - Exchange Online DisplayName validation
   - 19 unit test cases (empty, whitespace, invalid chars, length)
   - Status: COMPLETE & TESTED
   - Compliance: All STRUCTURE.md & CLAUDE.md rules

**Metrics:**
- Lines of Code: 164 (108 + 56)
- Test Cases: 35 total
- Build Validation: PASSED
- Code Compliance: 100%

**Next Steps:** Proceed to Phase Alpha implementation (Tier 2+)

---

### Tier 2: Group Validation (COMPLETE - 2026-06-29)

**Status:** ✅ COMPLETE

Implemented Functions:

1. **_ParseSharedMailboxGroupDescription.ps1** (Private)
   - Status: COMPLETE & TESTED
   - Purpose: Extract admin group from ACL group description string
   - Lines: 60 (includes SYNOPSIS, parameter validation, error handling)
   - Test Cases: 24 (valid formats, edge cases, invalid inputs)
   - Test File: tests/Test-ParseSharedMailboxGroupDescription.ps1
   - Compliance: 100% (K&R bracing, 4-space indent, no violations)

2. **_ValidateSharedMailboxGroup.ps1** (Private)
   - Status: COMPLETE & TESTED
   - Purpose: Validate ACL group (type, mail, description pattern)
   - Lines: 57
   - Test Cases: 20 (group validation scenarios)
   - Test File: tests/Test-ValidateSharedMailboxGroup.ps1
   - Compliance: 100%

3. **Get-SharedMailboxACLGroup.ps1** (Public)
   - Status: COMPLETE & TESTED
   - Purpose: Lookup & validate ACL group for candidate
   - Lines: 115
   - Test Cases: 39 (group retrieval, validation, error cases)
   - Test File: tests/Test-GetSharedMailboxACLGroup.ps1
   - Performance: Optimized with Get-ADObject (faster on large directories)
   - Validation: GroupScope=Universal, mail attribute, description pattern
   - Compliance: 100%

**Metrics:**
- Total Lines: 232 (60 + 57 + 115)
- Total Test Cases: 83 (24 + 20 + 39)
- Build Validation: PASSED
- Code Compliance: 100%
- Deprecated Functions: _ValidateSharedMailboxGroup (helper, not actively used in public API)

**Next Phase: Candidate Discovery & Exchange Operations**

Phase Alpha Priority: Complete AD candidate discovery BEFORE Exchange Online operations.
Reason: Need to read eligible candidates from AD before provisioning in Exchange.

### Tier 3: Candidate Discovery (PLANNED - Ready to Start)

**Next 2 functions to implement (in order):**

1. **Get-SharedMailboxCandidates.ps1** (Public)
   - Status: PLANNED – Ready to start
   - Purpose: Query AD for eligible candidates (disabled, prefix, custom attr)
   - Dependencies: ActiveDirectory module, Write-Log
   - Test file: tests/Test-GetSharedMailboxCandidates.ps1
   - Effort: ~150 lines
   - Complexity: MEDIUM (LDAP filtering, parameter validation)

2. **Get-SharedMailboxCandidatesWithGroups.ps1** (Public)
   - Status: PLANNED – Ready to start (after Tier 3.1)
   - Purpose: Combine candidates with validated ACL groups
   - Dependencies: Get-SharedMailboxCandidates, Get-SharedMailboxACLGroup, Write-Log
   - Test file: tests/Test-GetSharedMailboxCandidatesWithGroups.ps1
   - Effort: ~200 lines
   - Complexity: HIGH (orchestration, combined results)

**Phase Alpha Completion Summary:**
- Tier 1 (Text Parsing): 2 functions, 164 lines, 35 tests ✅ COMPLETE
- Tier 2 (Group Validation): 3 functions, 232 lines, 83 tests ✅ COMPLETE
- Tier 3 (Candidate Discovery): 2 functions planned, ~350 lines, ~60 tests
- **Phase Alpha Total (Revised):** ~746 lines, 178 tests

**Documentation:** See docs/IMPLEMENTATION-PLAN-SharedMailboxCandidates.md & ADR-006

---

### Phase Beta: Exchange Online Operations (After Phase Alpha)

**Next 4 functions to implement (in order):**

1. **New-SharedMailbox.ps1** (Public)
   - Status: PLANNED – Ready to start
   - Dependencies: _RetryExchangeOperation, Write-Log, Get-Configuration
   - Test file: tests/Test-NewSharedMailbox.ps1
   - Effort: ~200 lines (function + tests)

2. **Get-SharedMailbox.ps1** (Public)
   - Status: PLANNED – Ready to start
   - Dependencies: _RetryExchangeOperation, Connect-ExchangeOnlineEnv
   - Test file: tests/Test-GetSharedMailbox.ps1
   - Effort: ~150 lines

3. **Add-SharedMailboxMember.ps1** (Public)
   - Status: PLANNED – Ready to start
   - Dependencies: _RetryExchangeOperation, Write-Log
   - Test file: tests/Test-AddSharedMailboxMember.ps1
   - Effort: ~180 lines

4. **Remove-SharedMailbox.ps1** (Public)
   - Status: PLANNED – Ready to start
   - Dependencies: _RetryExchangeOperation, Write-Log
   - Test file: tests/Test-RemoveSharedMailbox.ps1
   - Effort: ~160 lines

---

## 🔧 PLANNED (Future Features)

### Medium Priority 1: FUNCTION-STATUS.md Tracking
- **Status:** Created but basic
- **Improvement:** Add dependency mapping (function → requires)
- **Example:**
  ```
  New-SharedMailbox
    ├─ Requires: _RetryExchangeOperation, Write-Log, Get-Configuration
    ├─ Tests: Test-NewSharedMailbox.ps1
    ├─ ADR: ADR-001, ADR-003, ADR-004
    └─ Status: [PLANNED]
  ```
- **Action:** Update as new functions implemented
- **Priority:** Medium (nice-to-have tracking)

### Medium Priority 2: Code Review Checklist
- **Status:** Documented in this file
- **Use:** Pre-commit review checklist
- **Items:**
  ```
  ✅ Function has -ErrorAction Stop
  ✅ Try-Catch wraps _RetryExchangeOperation calls
  ✅ Write-Log called for audit events
  ✅ Comment-based Help complete (PUBLIC only)
  ✅ Parameter validation (email, domain, GUID format)
  ✅ Verbose messages at key points
  ✅ No Invoke-Expression or Write-Host
  ✅ Tests pass: Invoke-Pester tests/
  ✅ Build passes: .\build.ps1 -Validate
  ✅ No secrets in code
  ```
- **Action:** Use before each commit

### Medium Priority 3: Error Scenarios Integration Tests
- **Status:** Patterns documented in _RetryExchangeOperation
- **Test matrix needed:**
  | Scenario | HTTP Code | Expected | Test |
  |----------|-----------|----------|------|
  | Throttling | 429 | Retry 3x | _RetryExchangeOperation |
  | Timeout | N/A | Retry with backoff | _RetryExchangeOperation |
  | Unauthorized | 403 | Fail immediately | Integration test |
  | Invalid Input | 400 | Fail immediately | Integration test |
  | Not Found | 404 | Fail immediately | Integration test |
  | Service Down | 503 | Retry 3x | _RetryExchangeOperation |

- **Action:** Add integration tests when scaling to 3+ public functions
- **Priority:** Medium (can be deferred)

### Low Priority 1: Script Orchestration Templates
- **Status:** Not started
- **Examples needed:**
  ```
  scripts/Provision-BulkMailboxes.ps1    – CSV-based bulk provisioning
  scripts/Remove-MailboxBatch.ps1        – Bulk deletion
  scripts/Sync-MailboxMembers.ps1        – Sync from AD group
  scripts/Export-MailboxAudit.ps1        – Export audit logs
  ```
- **Action:** Implement after core public functions complete
- **Priority:** Low (for MVP+)

---

## 🐛 KNOWN ISSUES

### None Currently

All known blockers resolved. New issues will be added as discovered.

---

## Project Health

```
Infrastructure Phase:        ✅ COMPLETE
Tier 1 Validation (2 fn):    ✅ COMPLETE & TESTED (35 tests)
Tier 2 Group Validation:     ✅ COMPLETE & TESTED (83 tests)
Setup & Documentation:       ✅ COMPLETE + TIER 2 UPDATES
Build & Validation:          ✅ WORKING
Code Compliance:             ✅ 100% (9 functions audited)
Module Loading:              ✅ VERIFIED

Tier 1 + 2 Progress:         5/5 functions ✅ COMPLETE
Total Functions:             9/9 implemented
Total Test Cases:            119 passing
Total Lines of Code:         883 (functions) + 1217 (tests)

Next Phase: TIER 3 (Candidate Discovery) ✅ READY TO START
```

**Status:** Phase Alpha Tier 1-2 complete. 119 test cases passing. 100% code compliance. Ready to proceed with Tier 3 (Candidate Discovery).

---

## Quick Reference

### Run Build Validation
```powershell
.\build.ps1 -Validate
```

### Run Unit Tests (All)
```powershell
Invoke-Pester tests/
```

### Run Unit Tests (Specific Tier)
```powershell
# Tier 1: Email & DisplayName validation
Invoke-Pester tests/Test-ValidateEmailFormat.ps1
Invoke-Pester tests/Test-ValidateDisplayName.ps1

# Tier 2: Group validation
Invoke-Pester tests/Test-ParseSharedMailboxGroupDescription.ps1
Invoke-Pester tests/Test-ValidateSharedMailboxGroup.ps1
Invoke-Pester tests/Test-GetSharedMailboxACLGroup.ps1
```

### Load Module
```powershell
Import-Module .\SharedMailboxProvisioner.psd1
```

### Code Review Before Commit
Use the checklist in **"PLANNED - Medium Priority 2"** section above.

---

**Last Updated:** 2026-06-29 (Tier 2 Completion)
**Maintained By:** Development Team  
**Status:** Phase Alpha Active (Tier 1-2 Complete, Tier 3 Ready)

