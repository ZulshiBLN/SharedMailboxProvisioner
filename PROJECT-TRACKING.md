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
| 5 | Exchange Provisioning | `New-SharedMailboxRemote`, `Invoke-MailboxPermissionQueue` | Hybrid JSON/CSV backlog, 60-min EXO sync handling. Credential setup moved to `scripts/Initialize-ProvisioningConnections.ps1` (2026-07-01, see Known Issues/Changelog below). |
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

### 2026-07-01 Smoke Test Day 1 - EXO connectivity changes
Live smoke testing against the real ETHZ tenant surfaced that the environment authenticates
via App Registration + certificate (already in the local cert store, not a `.pfx`/password
pair) and needs an outbound proxy. `Connect-ExchangeOnlineEnv` was extended accordingly:
- `-CertificateThumbprint` (cert-store based, replaces the earlier file+password design)
- `-ProxyUrl` (configures `HTTP_PROXY`/`HTTPS_PROXY` + `.NET` `DefaultWebProxy` for the session)
- `-Prefix` (default `"ETH"`) so cloud cmdlets (`Get-ETHMailbox`, etc.) don't collide with an
  unprefixed on-premises `Import-PSSession` open in the same window
- `-Tenant`/`-AppId` are now optional, falling back to `Organization`/`AppId` in
  `config.<Environment>.json` (new `-Environment`/`-ConfigPath` params)

New admin script `scripts/Initialize-ProvisioningConnections.ps1` (replaces the private
`_Initialize-ScheduledTaskCredential`) creates the on-prem Service Account credential file
at `config/Credential_{UserName}.clixml` and writes `Organization`/`AppId`/`CertificateThumbprint` into
`config/config.<Environment>.json` in one step. `.gitignore` was extended with `*.clixml`
since neither `config/` nor `data/` previously excluded credential files.

Confirmed working live: `Connect-ExchangeOnlineEnv -Tenant ethz.onmicrosoft.com -AppId ... -CertificateThumbprint ... -ProxyUrl proxy.ethz.ch:3128` connected successfully (`ModulePrefix: ETH`, `CertificateAuthentication: True`), and `Get-ETHMailbox -ResultSize 1` returned a real mailbox.

Config schema also simplified same day: `OrganizationName`, `PrimarySmtpDomain`, `ComplianceLabels`, `DelegatedAdministration`, `InitialBackoffMs` removed from `config.template.json`/`_Get-Configuration.ps1` defaults - none had any downstream consumer (grepped the whole codebase to confirm). `PrimarySmtpDomain`'s mandatory validation (and the now-unused `_ValidateDomain` helper) removed accordingly. `MaxRetries` default raised 3 -> 5; still not wired to any actual retry logic (`_RetryExchangeOperation` has its own separate, hardcoded defaults) - kept in schema for future use only.

Same-day follow-up: script renamed `Initialize-OnPremCredential.ps1` -> `Initialize-ProvisioningConnections.ps1` since `-Organization`/`-AppId`/`-CertificateThumbprint` are EXO-only concerns, not on-prem, despite the old name implying otherwise. `-UserName` (on-prem credential) stays independent; the three EXO params are now all `Mandatory = $true` (previously individually optional) since EXO app auth needs all three together or none.

Second same-day follow-up: `TenantId` swapped for `CertificateThumbprint` in `config.template.json`/`_Get-Configuration.ps1`/`Initialize-ProvisioningConnections.ps1`/`Connect-ExchangeOnlineEnv.ps1`. `Connect-ExchangeOnlineEnv` now also resolves `-CertificateThumbprint` from config (not just `-Tenant`/`-AppId`), so a fully config-driven call needs zero explicit parameters. `_ValidateGuid` helper removed (no caller left once `TenantId`'s validation was dropped). Also fixed `tests/Test-GetConfiguration.ps1`, found broken independent of this change: wrong require path (`Get-Configuration.ps1` instead of `_Get-Configuration.ps1`) and assertions against the pre-simplification schema - test count 5 -> 2, total suite 348 -> 345.

### 2026-07-01 Documentation Audit and fix pass
A full documentation audit (`docs/Pre-Release/DOCUMENTATION-AUDIT-PHASE-PRERELEASE.md`) found `README.md`, `docs/USER-GUIDE.md`, and `docs/API-REFERENCE.md` badly out of date against the actual function signatures (roughly 10 of 18 public functions had wrong/nonexistent parameters or wrong return types documented, including a `Test-SharedMailboxCandidate` example that would always evaluate truthy regardless of validation result), and `docs/ADMIN-GUIDE.md`/`docs/OPERATIONS-RUNBOOK.md` documented an entirely fictional config schema and scheduled-task wrapper script, plus a P0 incident procedure that relied on the already-tracked EXO-V3 health-check gap (see Known Issues below) with no caveat. All 15 findings were fixed the same day: function signatures/return types/examples regenerated from source across `README.md`/`docs/API-REFERENCE.md`/`docs/USER-GUIDE.md`; the fictional config section and scheduled-task setup in `docs/ADMIN-GUIDE.md`/`docs/OPERATIONS-RUNBOOK.md` replaced with the real schema and an honest description of the manual setup process; a live-cmdlet cross-check (`Get-ETHMailbox -ResultSize 1`) wired into the P0 runbook's EXO health-check step; a newly-found 4th no-op parameter (`Set-MailboxProvisioningSchedule -MaxRetries`) disclosed alongside the 3 already-tracked ones; a dead link in `DECISIONS.md` and stale ADR numbering/unlinked caveats in the Alpha/Beta compliance docs corrected; and hardcoded absolute paths in `README.md` and `docs/Pre-Release/MANUAL-TESTING-PLAN.md` generalized for portability. See the audit doc's Resolution Addendum for the full breakdown. Note: this was a documentation-only fix pass - the underlying code defects (EXO-V3 health-check gap, hardcoded `C:\Repos\...` path defaults, dead on-prem PSSession auto-detect, the 4 no-op parameters themselves) remain open, tracked below in Known Issues.

---

## KNOWN ISSUES

### RESOLVED 2026-07-01: Get-ADObject called with -Filter instead of -LDAPFilter (candidate discovery pipeline broken against real AD)
- Found live during Pre-Release Workflow 1 testing: `Get-SharedMailboxCandidates` failed every real AD query with `Error parsing query: '(&(objectClass=user)...)' ... 'syntax error'`. Root cause: `Get-ADObject`'s `-Filter` parameter expects PowerShell expression syntax (`-eq`, `-like`, ...), not raw LDAP filter strings - that's what `-LDAPFilter` is for. All three affected functions (`Get-SharedMailboxCandidates`, `Get-SharedMailboxACLGroup`, `_CheckForDuplicateEmails`) built raw LDAP strings and passed them via `-Filter`. `Get-SharedMailboxACLGroup` additionally had a malformed filter missing its `(&...)` wrapper. Fixed all three to use `-LDAPFilter`.
- **Why this was never caught:** the corresponding Pester tests (`Test-GetSharedMailboxCandidates.ps1`, `Test-GetSharedMailboxACLGroup.ps1`, `Test-CheckForDuplicateEmails.ps1`) all `Mock Get-ADUser`, but the production code calls `Get-ADObject` (switched at some point for large-AD performance, per existing code comments) - the mocks never actually intercepted the real call path, so the tests could never have exercised the actual LDAP filter string against anything that would validate its syntax.
- **NOT FIXED:** the test files themselves still mock the wrong cmdlet. They weren't rewritten in this pass (would need to mock `Get-ADObject` and assert on `-LDAPFilter` instead of `-Filter`) - re-running `New-SharedMailboxRemote.ps1`'s and `Invoke-MailboxPermissionQueue.ps1`'s own `Get-ADObject -Filter "sAMAccountName -eq '...' -and ..."` calls were checked too and are correct (real PowerShell expression syntax, not LDAP), so those two were not touched.

### RESOLVED 2026-07-01: Module version mismatch
- `SharedMailboxProvisioner.psd1` declared `ModuleVersion = '0.8.2'` while docs treated `v0.9.0-beta.1` as current. Fixed: `ModuleVersion = '0.9.0'` + `PrivateData.PSData.Prerelease = 'beta1'` (PSGallery convention; `ModuleVersion` itself can't hold a `-beta.1` suffix).

### RESOLVED 2026-07-01: _Get-Configuration.ps1 Join-Path bug
- Default config path resolution used `Join-Path $PSScriptRoot ".." ".." "config" "config.$Environment.json"` - Windows PowerShell 5.1's `Join-Path` only accepts one `-Path`/`-ChildPath` pair, not 4 positional segments. This silently broke `Get-Configuration` any time `-ConfigPath` wasn't explicitly passed. Fixed via chained `Join-Path` calls. Found while wiring `Connect-ExchangeOnlineEnv`'s new config-based Tenant/AppId fallback (see below).

### RESOLVED 2026-07-01: FUNCTION-STATUS.md drift / Private function naming inconsistency
- `functions/FUNCTION-STATUS.md` predates several Tier implementations and Beta-Phase renames; an earlier pass thought `_ValidateGuid`/`Get-ServiceAccountCredential` were missing - they existed as nested helper functions inside `_Get-Configuration.ps1`, not as their own files. `_ValidateGuid` was since removed entirely (see `TenantId` removal note above). `Get-ServiceAccountCredential` was renamed to `_Get-ServiceAccountCredential` (along with `Get-Configuration` -> `_Get-Configuration` and `ConvertTo-MailboxReportFormat` -> `_ConvertTo-MailboxReportFormat`) to actually match the underscore-prefix convention their file names already implied - see `docs/Pre-Release/COMPLIANCE-AUDIT-PHASE-PRERELEASE.md` Finding 2.2.

### RESOLVED 2026-07-01: Test runner version (Pester 5.x now installed) - revealed the suite has never actually passed
- Installed Pester 5.8.0 (previously only 3.4.0, built into PS 5.1, was available - incompatible with this suite's modern `Should -Be`/`Mock`/`-ParameterFilter` syntax). This let the suite run for the first time in the project's history.
- Fixing two path bugs was required just to get files loading: a `Join-Path` call with 3-4 positional arguments (PS-5.1-incompatible, same bug class as the already-fixed `_Get-Configuration.ps1`/`setup-hooks.ps1` issues) in 13 files, and a `$projectRoot` calculation that resolved one directory level too high (`Split-Path -Parent (Split-Path -Parent $PSScriptRoot)` instead of a single call) in 16 files. Both fixed; see `docs/Pre-Release/COMPLIANCE-AUDIT-PHASE-PRERELEASE.md` Addendum 3 for the full file list and root cause.
- **With both fixed, the real result is 345 tests, 72 passing, 273 failing.** Spot-checked failure causes include real (non-mocked) `Write-Log` calls hitting actual `C:\ProgramData\...` paths and failing with Access Denied, at least one real mock/assertion shape mismatch, and likely broader Pester 3-vs-5 behavioral differences never previously exercised.
- **Action:** NOT triaged further - getting this suite green is a substantial, separate effort and should be tracked as its own initiative, not folded into other work. Filed here as the honest current baseline now that it's measurable for the first time.

### NOT FIXED: Hardcoded `C:\Repos\SharedMailboxProvisioner\...` default paths
- `New-SharedMailboxRemote.ps1` defaults `-BacklogPath` and `-CredentialPath` to `C:\Repos\SharedMailboxProvisioner\data\...`, which doesn't match this repo's actual location (`S:\Scheduled Tasks\Exchange SE\SharedMailboxProvisioner`). Any caller relying on the defaults instead of passing explicit paths would silently write to/read from the wrong (nonexistent) location.
- **Action:** Not fixed yet (found 2026-07-01 while building the credential/config init script); needs an explicit decision on whether defaults should be `$PSScriptRoot`-relative or dropped entirely in favor of mandatory parameters.

### NOT FIXED: `_GetExchangePSSession` reads a config shape `_Get-Configuration` never produces
- `New-SharedMailboxRemote.ps1`'s internal `_GetExchangePSSession` reads `$config.exchange.onPremises.uri` for the on-prem `-ExchangeURI` default, but `_Get-Configuration.ps1`'s schema is flat (no nested `exchange.onPremises.uri` object). This means the "current user context" PSSession attempt likely always fails silently (no URI) and falls through to the credential-file path.
- **Action:** Not fixed yet; needs either a schema addition to config or an explicit `-ExchangeURI` requirement.

### NOT FIXED: EXO connectivity checks may not detect modern (REST) sessions
- Both `Get-MailboxProvisioningHealth`'s `_CheckEXOHealth` and `Invoke-MailboxPermissionQueue`'s pre-connect check use `Get-PSSession -Name/-ConfigurationName "*ExchangeOnline*"`/`"Microsoft.Exchange"`, which likely doesn't match modern EXO-V3 REST-based connections (no classic named PSSession unless `-UseRPSSession` is used). Found during Pre-Release smoke testing 2026-07-01.
- **Action:** Not fixed yet; would need `Get-ConnectionInformation`-based detection instead.

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
Phase Alpha (Tier 1-6):      COMPLETE, CODE-REVIEWED (10 functions, ~1,378 lines) - test pass rate below
Phase Beta (Tier 7-8,10-11): COMPLETE, CODE-REVIEWED (12 functions + 1 script, ~2,743 lines) - test pass rate below
  Tier 9 (Integration Tests): REMOVED (not applicable, see rationale above)
Pre-Release Phase:           ACTIVE (Week 1 of 3, staging deployment underway)

Total Public Functions:      18
Total Private Functions:     11 (was 12; _Initialize-ScheduledTaskCredential removed 2026-07-01, superseded by scripts/Initialize-ProvisioningConnections.ps1)
Total Admin Scripts:         2 (Provision-BulkMailboxesFromCSV.ps1, Initialize-ProvisioningConnections.ps1)
Total Test Files:            27
Total Test Cases:            345 (counted from `It` blocks in tests/; was 348 before Test-GetConfiguration.ps1 rewrite, 2026-07-01)
Test Pass Rate:              72/345 (21%) - Pester 5.x run for the first time 2026-07-01, see "Test runner version" above. Previously unmeasured (Pester 3.4.0 could not run this suite at all).
Build Validation:            PASSED (0 PSScriptAnalyzer violations, 2026-07-01)
Module Loading:              VERIFIED
```

"COMPLETE" above refers to implementation and manual/PSScriptAnalyzer review per the Alpha/Beta compliance audits, not to a passing automated test suite - see the Test Pass Rate line and `docs/Pre-Release/COMPLIANCE-AUDIT-PHASE-PRERELEASE.md` Addendum 3.

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
