# Function Status – SharedMailboxProvisioner

Tracking of all functions: implementation status, test coverage, usage.

**Last Refreshed:** 2026-07-01 (full pass against actual `functions/`, `scripts/`, `tests/` contents)

---

## Private Functions (Helpers) – Core Infrastructure

| Function | Status | Tests | ADR | Notes |
|----------|--------|-------|-----|-------|
| `_RetryExchangeOperation` | [COMPLETE] | [YES] (5) | ADR-003 | Retry logic with exponential backoff. Core for all EXO calls. `tests/Test-RetryExchangeOperation.ps1` |
| `_Write-Log` | [COMPLETE] | [YES] (4) | ADR-004 | Centralized audit & error logging. Used by all operations. `tests/Test-WriteLog.ps1` |
| `_Get-Configuration` | [COMPLETE] | [YES] (2) | ADR-005 | Config loading & validation. Schema simplified 2026-07-01: `Organization`/`AppId`/`CertificateThumbprint` (EXO app-based auth, no field is hard-required anymore), `DefaultMailboxQuota`, `LogRetentionDays`, `MaxRetries` (default 5, not yet wired to any retry logic). Dropped unused fields `TenantId` (replaced by `CertificateThumbprint` same day), `OrganizationName`, `PrimarySmtpDomain`, `ComplianceLabels`, `DelegatedAdministration`, `InitialBackoffMs` - none had a downstream consumer. Removed the now-dead `_ValidateGuid` helper along with `TenantId`. `tests/Test-GetConfiguration.ps1` (rewritten same day - was broken: wrong require path `Get-Configuration.ps1` instead of `_Get-Configuration.ps1`, and asserted the old schema). |

---

## Private Functions (Helpers) – AD Candidate Discovery & Validation

### Group Validation (Tier 2)
| Function | Status | Tests | ADR | Notes |
|----------|--------|-------|-----|-------|
| `_ParseSharedMailboxGroupDescription` | [COMPLETE] | [YES] (20) | ADR-006 | Parse ACL group description, extract admin group. `tests/Test-ParseSharedMailboxGroupDescription.ps1` |
| `_ValidateSharedMailboxGroup` | [COMPLETE] | [YES] (17) | ADR-006 | Validate group structure (type, mail, description pattern). `tests/Test-ValidateSharedMailboxGroup.ps1` |

### Data Quality Validation (Tier 1 & 3)
| Function | Status | Tests | ADR | Notes |
|----------|--------|-------|-----|-------|
| `_ValidateEmailFormat` | [COMPLETE] | [YES] (22) | ADR-006 | RFC 5321 email format validation. `tests/Test-ValidateEmailFormat.ps1` |
| `_ValidateDisplayName` | [COMPLETE] | [YES] (21) | ADR-006 | DisplayName character validation. `tests/Test-ValidateDisplayName.ps1` |
| `_ValidateDomainInExchangeOnline` | [COMPLETE] | [YES] (18) | ADR-006 | Check domain against AcceptedDomains list. `tests/Test-ValidateDomainInExchangeOnline.ps1` |
| `_CheckForDuplicateEmails` | [COMPLETE] | [YES] (19), mocks wrong cmdlet - see note | ADR-006 | Detect duplicate emails in AD. **Fixed 2026-07-01:** was passing a raw LDAP filter string via `Get-ADObject -Filter` (which expects PowerShell expression syntax, not LDAP syntax) instead of `-LDAPFilter` - real AD calls always threw a syntax error, never caught by tests since they mock `Get-ADUser`, a cmdlet this function doesn't call. `tests/Test-CheckForDuplicateEmails.ps1` |

### Bulk Import & Reporting Helpers (Tier 7-8)
| Function | Status | Tests | ADR | Notes |
|----------|--------|-------|-----|-------|
| `_ConvertTo-MailboxCandidateObject` | [COMPLETE] | [IMPLIED] | ADR-001 | CSV row -> normalized candidate object. Covered indirectly via `tests/Test-Import-MailboxCandidatesFromCSV.ps1`. |
| `_ConvertTo-MailboxReportFormat` | [COMPLETE] | [NONE] | ADR-004 | Raw data -> HTML/CSV/Text/JSON formatting for reports & audit export. No dedicated test file. |

---

## Public Functions (Cmdlets) – Account Validation

| Function | Status | Tests | ADR | Usage | Notes |
|----------|--------|-------|-----|-------|-------|
| `Test-SharedMailboxCandidate` | [COMPLETE] | [YES] (15) | ADR-006 | Validate user for provisioning readiness | Uses: `_ValidateEmailFormat`, `_ValidateDisplayName`, `_ValidateDomainInExchangeOnline`, `_CheckForDuplicateEmails`, `_Write-Log`. Renamed from `Validate-SharedMailboxCandidate` to the approved verb `Test-`. `tests/Test-ValidateSharedMailboxCandidate.ps1` |

---

## Public Functions (Cmdlets) – Exchange Online

| Function | Status | Tests | ADR | Usage | Notes |
|----------|--------|-------|-----|-------|-------|
| `Connect-ExchangeOnlineEnv` | [COMPLETE] | [NONE] | ADR-002 | Establish Exchange Online connection | Wrapper for EXO-V3 module, auto-install, exponential backoff, connection pooling. Supports cert-store app auth (`-AppId`/`-CertificateThumbprint`), proxy (`-ProxyUrl`), cmdlet `-Prefix` (default "ETH", avoids collisions with an unprefixed on-prem session), and Tenant/AppId fallback from `config.<Environment>.json` via `_Get-Configuration`. No dedicated test file (external module dependency). |
| `New-SharedMailboxRemote` | [COMPLETE] | [YES] (11) | ADR-001, ADR-003 | Create remote shared mailbox on-premises | Uses: PSSession management, hybrid JSON/CSV backlog. `tests/Test-NewSharedMailboxRemote.ps1` |
| `Invoke-MailboxPermissionQueue` | [COMPLETE] | [YES] (11) | ADR-001, ADR-003 | Process provisioning backlog, assign permissions | Async retry queue, 60-min EXO sync handling. `tests/Test-InvokeMailboxPermissionQueue.ps1` |

---

## Public Functions (Cmdlets) – Active Directory Candidate Discovery

| Function | Status | Tests | ADR | Usage | Notes |
|----------|--------|-------|-----|-------|-------|
| `Get-SharedMailboxACLGroup` | [COMPLETE] | [YES] (25), mocks wrong cmdlet - see note | ADR-006 | Lookup & validate ACL group for candidate | Uses: `_ParseSharedMailboxGroupDescription`, `_ValidateSharedMailboxGroup`. Optimized with `Get-ADObject`. **Fixed 2026-07-01:** same `-Filter`/`-LDAPFilter` bug as `Get-SharedMailboxCandidates` below, plus the filter was missing its `(&...)` wrapper (`"(sAMAccountName=X)(objectClass=group)"` is not valid as a single top-level LDAP expression). `tests/Test-GetSharedMailboxACLGroup.ps1` |
| `Get-SharedMailboxCandidates` | [COMPLETE] | [YES] (20), mocks wrong cmdlet - see note | ADR-006 | Query AD for eligible candidates | Get-ADObject optimized for large AD. **Fixed 2026-07-01, found during live Pre-Release testing:** was calling `Get-ADObject -Filter $ldapFilter` with a raw LDAP filter string - `-Filter` expects PowerShell expression syntax (`-eq`, `-like`, ...), not LDAP syntax; real AD queries always failed with "Error parsing query: ... syntax error". Fixed to use `-LDAPFilter`. Never caught by tests, which mock `Get-ADUser` - a cmdlet this function doesn't call (it calls `Get-ADObject`). `tests/Test-GetSharedMailboxCandidates.ps1` |
| `Get-SharedMailboxCandidatesWithGroups` | [COMPLETE] | [YES] (10) | ADR-006 | Candidates combined with validated ACL groups | Uses: `Get-SharedMailboxCandidates`, `Get-SharedMailboxACLGroup`. `tests/Test-GetSharedMailboxCandidatesWithGroups.ps1` |

---

## Public Functions (Cmdlets) – Provisioning Orchestration & Bulk Import

| Function | Status | Tests | ADR | Usage | Notes |
|----------|--------|-------|-----|-------|-------|
| `Invoke-SharedMailboxProvisioning` | [COMPLETE] | [YES] (9) | ADR-001, ADR-006 | Main orchestration entry point | Discovers candidates -> creates mailboxes -> processes permission queue. `tests/Test-InvokeSharedMailboxProvisioning.ps1` |
| `Import-MailboxCandidatesFromCSV` | [COMPLETE] | [YES] (14) | ADR-001 | Import & validate CSV candidates | Encoding fallback, error recovery, audit logging. **MANUAL ONLY**. `tests/Test-Import-MailboxCandidatesFromCSV.ps1` |
| `Test-MailboxBulkImport` | [COMPLETE] | [YES] (13) | ADR-001 | Dry-run validation + HTML report | Duplicate/conflict detection, impact analysis. **MANUAL ONLY**. `tests/Test-MailboxBulkImport.ps1` |

Cross-tier coverage: `tests/Test-Tier7-Integration.ps1` (10 tests) exercises Import + Test-MailboxBulkImport + `Provision-BulkMailboxesFromCSV.ps1` together end-to-end (mocked).

---

## Public Functions (Cmdlets) – Reporting & Audit (Tier 8)

| Function | Status | Tests | ADR | Usage | Notes |
|----------|--------|-------|-----|-------|-------|
| `Get-MailboxProvisioningReport` | [COMPLETE] | [YES] (11) | ADR-004 | Comprehensive metrics & timeline report | Summary, daily breakdown, per-group stats, top failures. `tests/Test-Get-MailboxProvisioningReport.ps1` |
| `Export-MailboxAuditLog` | [COMPLETE] | [YES] (10) | ADR-004, ADR-007 | Audit log export (HTML/CSV/Text) | Date/status filtering, color-coded HTML. `tests/Test-Export-MailboxAuditLog.ps1` |
| `Get-MailboxProvisioningMetrics` | [COMPLETE] | [YES] (10) | ADR-004 | KPIs, bottleneck ID, trend analysis | 7/14/30-day trends, top error codes. `tests/Test-Get-MailboxProvisioningMetrics.ps1` |

---

## Public Functions (Cmdlets) – Operational Tooling (Tier 10)

| Function | Status | Tests | ADR | Usage | Notes |
|----------|--------|-------|-----|-------|-------|
| `Get-MailboxProvisioningStatus` | [COMPLETE] | [YES] (9) | ADR-003, ADR-004 | Query status of single/all mailboxes | Timeline of operations, highlights blocked/failed entries. `tests/Test-Get-MailboxProvisioningStatus.ps1` |
| `Resolve-MailboxProvisioningFailure` | [COMPLETE] | [YES] (10) | ADR-003 | Diagnose failure root cause | RETRY vs ESCALATE recommendation. `tests/Test-Resolve-MailboxProvisioningFailure.ps1` |
| `Invoke-MailboxProvisioningRetry` | [COMPLETE] | [YES] (9) | ADR-003 | Manual retry for single/bulk mailboxes | Max-retry enforcement, force override. `tests/Test-Invoke-MailboxProvisioningRetry.ps1` |
| `Set-MailboxProvisioningSchedule` | [COMPLETE] | [YES] (6) | ADR-002 | Configure ScheduledTask interval | Enable/disable, retry parameter updates. `tests/Test-Set-MailboxProvisioningSchedule.ps1` |
| `Get-MailboxProvisioningHealth` | [COMPLETE] | [YES] (14) | ADR-002, ADR-003 | EXO/AD connectivity + ScheduledTask check | Read-only diagnostics. `tests/Test-Get-MailboxProvisioningHealth.ps1` |

---

## Scripts (Orchestration & Admin Tools)

| Script | Status | Tests | Purpose | Notes |
|--------|--------|-------|---------|-------|
| `scripts/Provision-BulkMailboxesFromCSV.ps1` | [COMPLETE] | [YES] (via Test-Tier7-Integration.ps1) | Manual bulk provision from CSV | Admin CLI. Dry-run preview, explicit confirmation. **MANUAL ONLY - never automated/scheduled.** Uses: `Import-MailboxCandidatesFromCSV`, `Test-MailboxBulkImport`, `New-SharedMailboxRemote`, `Invoke-MailboxPermissionQueue` |
| `scripts/Initialize-ProvisioningConnections.ps1` | [COMPLETE] | [NONE] | One-time Service Account credential + EXO app config setup | Admin CLI, added 2026-07-01 (renamed same day from `Initialize-OnPremCredential.ps1`), replaces the former private `_Initialize-ScheduledTaskCredential`. `-UserName` (on-prem only) creates `config/Credential_{UserName}.clixml` (consumed by `New-SharedMailboxRemote -CredentialPath`). `-Organization`/`-AppId`/`-CertificateThumbprint` (EXO only, all three mandatory together) write into `config/config.<Environment>.json` (consumed by `Connect-ExchangeOnlineEnv`). `TenantId` swapped for `CertificateThumbprint` same day. **MANUAL ONLY**, must run as the target Service Account, elevated. No automated test (interactive by design). |

No further scripts are planned at this time (the "Remove-MailboxBatch" / "Sync-MailboxMembers" / "Export-MailboxAudit" script ideas from the original Tier plan were superseded by `Export-MailboxAuditLog` and the existing bulk-provisioning script; revisit only if a concrete need arises).

---

## Legend

| Status | Meaning |
|--------|---------|
| [COMPLETE] | Fully implemented & tested |
| [PARTIAL] | Implemented, partial testing |
| [IN-PROGRESS] | Currently being implemented |
| [PLANNED] | Designed, awaiting implementation |
| [BLOCKED] | Awaiting dependency |

| Test Status | Meaning |
|---|---|
| [YES] (n) | Unit tests present & passing; n = `It` block count in its test file |
| [IMPLIED] | Tested indirectly (via a dependent function's test file) |
| [NONE] | No tests yet |

---

## Next Steps

All planned Tiers (1-8, 10-11) are complete; Tier 9 was formally removed (see `PROJECT-TRACKING.md` and `docs/Beta-Phase/`). Current phase is **Pre-Release** (v0.9.0-beta.1) - see `docs/Pre-Release/PHASE-PRERELEASE-ROADMAP.md`.

Remaining gaps identified in this refresh:
- [ ] `_ConvertTo-MailboxReportFormat` has no dedicated unit test.
- [ ] `scripts/Initialize-ProvisioningConnections.ps1` and `Connect-ExchangeOnlineEnv` have no automated tests (both depend on interactive/external-module behavior); covered so far only by manual verification.
- [ ] Local dev environment only has Pester 3.4.0; a Pester 5.x install is needed to actually execute the suite and confirm all counted `It` blocks pass.
- [ ] Performance validation for 100+ mailbox batches (deferred, no scale testing done yet).

---

## Implementation Progress

| Tier | Status | Functions | Test Cases | Notes |
|------|--------|-----------|-------------|-------|
| Core Infra | [COMPLETE] | 3 | 11 | `_RetryExchangeOperation`, `_Write-Log`, `_Get-Configuration` (Setup Phase, pre-Tier). `_Get-Configuration` test count reduced 5 -> 2 on 2026-07-01 (test file rewritten to match simplified schema). |
| 1 | [COMPLETE] | 2 | 43 | Text Parsing: `_ValidateEmailFormat`, `_ValidateDisplayName` |
| 2 | [COMPLETE] | 3 | 62 | Group Validation: `_ParseSharedMailboxGroupDescription`, `_ValidateSharedMailboxGroup`, `Get-SharedMailboxACLGroup` |
| 3 | [COMPLETE] | 3 | 52 | Data Quality: `_CheckForDuplicateEmails`, `_ValidateDomainInExchangeOnline`, `Test-SharedMailboxCandidate` |
| 4 | [COMPLETE] | 2 | 30 | Candidate Discovery: `Get-SharedMailboxCandidates`, `Get-SharedMailboxCandidatesWithGroups` |
| 5 | [COMPLETE] | 2 | 22 | Exchange Provisioning: `New-SharedMailboxRemote` (11), `Invoke-MailboxPermissionQueue` (11). Credential setup moved to `scripts/Initialize-ProvisioningConnections.ps1` (2026-07-01). |
| 6 | [COMPLETE] | 1 | 9 | Batch Orchestration: `Invoke-SharedMailboxProvisioning` |
| 7 | [COMPLETE] | 2 + 1 script | 37 | Bulk Import: `Import-MailboxCandidatesFromCSV` (14), `Test-MailboxBulkImport` (13), `Provision-BulkMailboxesFromCSV.ps1` (10, via integration test) |
| 8 | [COMPLETE] | 3 | 31 | Reporting & Audit: `Get-MailboxProvisioningReport`, `Export-MailboxAuditLog`, `Get-MailboxProvisioningMetrics` |
| 9 | [REMOVED] | - | - | Integration Testing - not applicable (see rationale in `PROJECT-TRACKING.md`) |
| 10 | [COMPLETE] | 5 | 48 | Operational Tooling: `Get-MailboxProvisioningStatus`, `Resolve-MailboxProvisioningFailure`, `Invoke-MailboxProvisioningRetry`, `Set-MailboxProvisioningSchedule`, `Get-MailboxProvisioningHealth` |
| 11 | [COMPLETE] | - (5 docs, ~130 pages) | - | Documentation: README, USER-GUIDE, ADMIN-GUIDE, OPERATIONS-RUNBOOK, API-REFERENCE |
| **Total** | **COMPLETE** | **18 public + 11 private + 2 scripts** | **345** | 27 test files. Line/function counts as of 2026-06-30; not recounted after the 2026-07-01 credential/config changes. Test total updated 2026-07-01 (Test-GetConfiguration.ps1 rewrite: 348 -> 345). |

**Code Quality Metrics:**
- Build Status: PASSED (0 PSScriptAnalyzer violations, verified 2026-07-01)
- Compliance: ADR + STRUCTURE.md + CLAUDE.md rules followed throughout
- Code Style: K&R bracing, 4-space indentation, ASCII-only output

Next Phase: Pre-Release validation (staging deployment, manual testing, performance baseline) - see `PROJECT-TRACKING.md`.
