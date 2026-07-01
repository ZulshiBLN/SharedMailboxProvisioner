# SharedMailboxProvisioner - Pre-Release Phase Documentation Audit

**Date:** 2026-07-01 (all findings fixed and re-verified same day, see Resolution Addendum)
**Project:** SharedMailboxProvisioner
**Phase:** Pre-Release (v0.9.0-beta.1), Week 1 Day 1
**Scope:** Full documentation set (`README.md`, `docs/**/*.md`, `STRUCTURE.md`, `DECISIONS.md`, `CLAUDE.md`, `RELEASE-PROCESS.md`, `PROJECT-TRACKING.md`, `functions/FUNCTION-STATUS.md`) audited for accuracy against the current codebase, internal consistency, and staleness relative to the 2026-07-01 EXO/on-prem connection rework. Not a security or build-gate audit - see `SECURITY-AUDIT-PHASE-PRERELEASE.md` and `COMPLIANCE-AUDIT-PHASE-PRERELEASE.md` for those.
**Method:** Four parallel agent-assisted reviews, one per doc cluster (setup/connection docs, user-facing API docs, admin/ops docs, meta docs & cross-references), each comparing every concrete claim (parameter names, config keys, return types, example commands, file paths, cross-references) against the actual current source. The highest-severity claims from each review were independently re-verified against the real files before inclusion below.

---

## Executive Summary

**`docs/USER-GUIDE.md` and `docs/API-REFERENCE.md` are severely out of date and will actively mislead anyone who follows them.** Roughly half of the 18 public functions' documented parameter lists, mandatory/optional status, return types, or example commands no longer match the real code - most of this predates even the 2026-07-01 rework (the docs are stamped "v0.8.2, Last Updated 2026-06-30"). `docs/ADMIN-GUIDE.md` and `docs/OPERATIONS-RUNBOOK.md` are worse: they document an entire config schema and scheduled-task infrastructure that doesn't exist in code, and the P0 incident runbook tells on-call staff to trust an EXO health check that is already known (and tracked) to be unreliable against modern EXO-V3 connections - the single most operationally dangerous finding in this audit.

| # | Area | Result | Severity | Status |
|---|---|---|---|---|
| 1 | `README.md` Quick Start examples | 2 of 3 example commands call functions that don't exist (`New-SharedMailbox`, `Add-SharedMailboxMember`) | HIGH | **RESOLVED** |
| 2 | `docs/API-REFERENCE.md` parameter/return-type accuracy | 10 of 18 functions have wrong/nonexistent parameters, wrong mandatory status, or wrong return type documented | HIGH | **RESOLVED** |
| 3 | `docs/USER-GUIDE.md` example commands | Multiple Quick Start / FAQ examples call functions with parameters that don't exist and would fail immediately | HIGH | **RESOLVED** |
| 4 | `docs/ADMIN-GUIDE.md` / `docs/OPERATIONS-RUNBOOK.md` config schema | Entire documented config file (`settings.json`, `ScheduledTaskInterval`, etc.) does not exist; real config is `config.<Environment>.json` with a different schema | HIGH | **RESOLVED** |
| 5 | `docs/OPERATIONS-RUNBOOK.md` P0 procedure | Tells on-call staff to trust `Get-MailboxProvisioningHealth -CheckEXO` as an incident-response signal; that check is confirmed unreliable against EXO-V3 REST sessions (tracked, unfixed) | HIGH | **RESOLVED** (caveat + live cross-check added, underlying code gap still open) |
| 6 | 3 known, tracked defects (hardcoded paths, dead PSSession fallback, EXO health-check gap) | Undocumented in ADMIN-GUIDE.md/OPERATIONS-RUNBOOK.md - operators have no way to know about them | MEDIUM | **RESOLVED** (documented; code defects remain open, tracked in PROJECT-TRACKING.md) |
| 7 | Version banners across `docs/*.md` | `USER-GUIDE.md`, `API-REFERENCE.md`, `ADMIN-GUIDE.md`, `OPERATIONS-RUNBOOK.md`, `docs/README.md` all still say "v0.8.2", dated 2026-06-30 - one day before the connection rework and stale relative to CLAUDE.md's current v0.9.0-beta.1 | MEDIUM | **RESOLVED** |
| 8 | `docs/SETUP.md` credential setup (Step 3) | Doesn't mention the newer `Initialize-ProvisioningConnections.ps1` clixml-based credential mechanism that `New-SharedMailboxRemote` actually uses | MEDIUM | **RESOLVED** |
| 9 | 4th undisclosed no-op parameter found | `Set-MailboxProvisioningSchedule -MaxRetries` is accepted but never used in the function body - same class of bug as 3 already-tracked no-ops, not previously caught | MEDIUM | **RESOLVED** (disclosed in docs; code no-op itself not fixed) |
| 10 | `DECISIONS.md:472` broken link | Points to `docs/IMPLEMENTATION-PLAN-SharedMailboxCandidates.md`, which does not exist anywhere in the repo | LOW | **RESOLVED** |
| 11 | Historical phase docs (Alpha/Beta compliance audits) | "0 violations"/"100% compliant" claims presented with no caveat; Pre-Release compliance audit found the enforcement gate was broken the whole time, but neither historical doc links forward to that caveat | LOW | **RESOLVED** |
| 12 | Stale ADR numbering in Alpha/Beta docs | Both cite "ADR-010" for ASCII-only output; current `DECISIONS.md` caps at ADR-007 (ASCII-only is ADR-007) - leftover from an earlier renumbering, never corrected | LOW | **RESOLVED** |
| 13 | `functions/FUNCTION-STATUS.md` vs actual files | Clean - all 18 Public + 11 Private functions match exactly | OK | n/a |

---

## Part 1: `docs/API-REFERENCE.md` and `docs/USER-GUIDE.md` - Function Signatures

All 18 public functions were checked against their actual `param()` blocks and return values. Spot-verified directly: `Connect-ExchangeOnlineEnv`, `New-SharedMailboxRemote`, `Invoke-MailboxPermissionQueue`, `Get-MailboxProvisioningMetrics`.

### Finding 1.1 - `Connect-ExchangeOnlineEnv` (API-REFERENCE.md ~L29-38)

Doc shows a `-ExchangeEnvironmentName` parameter (default `"O365Default"`) and claims the function **returns a PSSession object**. Neither exists. The real parameters (confirmed in source) are `-Tenant`, `-AppId`, `-CertificateThumbprint`, `-Environment` (default `"dev"`), `-ConfigPath`, `-SkipConnectIfAlready`, `-ProxyUrl`, `-Prefix` (default `"ETH"`); the function returns a **boolean**. This is the function most affected by the 2026-07-01 rework and the doc reflects neither the old nor the new design accurately.

### Finding 1.2 - `New-SharedMailboxRemote` (API-REFERENCE.md ~L195-222, USER-GUIDE.md ~L117-119)

Doc's mandatory parameters are `-SamAccountName`, `-DisplayName`, `-Email`. Real mandatory parameters (verified): `-SamAccountName`, `-DisplayName`, `-PrimarySmtpAddress`, `-RemoteRoutingAddress`, `-ACLGroupName` - there is no `-Email` parameter at all. Both documented example commands would fail immediately with "parameter cannot be found" plus missing-mandatory-parameter errors. Doc also claims "Requires EXO admin rights" and returns a "Remote mailbox object" - the function actually creates an **on-premises** remote mailbox via PSSession (`_GetExchangePSSession`) and returns a custom summary `PSCustomObject`, not an EXO object.

### Finding 1.3 - `Invoke-MailboxPermissionQueue` (API-REFERENCE.md ~L232-248, USER-GUIDE.md ~L122-123)

Doc shows mandatory `-MailboxEmail`/`-ACLGroupName` parameters, processing one mailbox/group pair, returning `$true`/`$false`. Reality (verified): the function takes only `-BacklogPath`, `-MaximumRetries` (default 5), `-CleanupDaysOld` (default 30) - none mandatory - and processes the **entire backlog file** in one call, returning a `PSCustomObject` (`ProcessedCount`/`SuccessCount`/`FailedCount`/`RetryingCount`/...). This is a fundamentally different calling convention than documented, not just a parameter rename.

### Finding 1.4 - `Get-SharedMailboxCandidates` / `Get-SharedMailboxCandidatesWithGroups` (API-REFERENCE.md ~L64-111, USER-GUIDE.md ~L110, ~L436)

Doc shows a `-Filter` and `-OrganizationalUnit` parameter on both functions. Neither exists on either function. Real parameters are `-SamAccountNamePrefix`, `-DescriptionStartsWith`, `-CustomAttribute`/`-CustomAttributeValue`, `-AccountStatus`, `-SearchBase` (plus `-ValidateAll` on the `...WithGroups` variant). The USER-GUIDE.md FAQ entry telling users to "modify the `-Filter` parameter" to customize candidate discovery is actively wrong advice - the correct parameter is `-SamAccountNamePrefix`.

### Finding 1.5 - `Get-SharedMailboxACLGroup` (API-REFERENCE.md ~L125-139)

Doc's parameter is `-GroupName`; real parameter is `-SamAccountName` (a user's `smbx_...` account, not a literal AD group name - a semantic difference, not just a rename). Example command would fail.

### Finding 1.6 - `Import-MailboxCandidatesFromCSV` / `Test-MailboxBulkImport` (API-REFERENCE.md ~L314-373, USER-GUIDE.md ~L251-260, ~L372, ~L451)

`Import-MailboxCandidatesFromCSV`: doc shows a `-DryRun` switch that does not exist in the real parameter set (`-CSVPath`, `-Encoding`, `-ValidateADLookup`, `-SearchBase`) - would fail with "parameter cannot be found."

`Test-MailboxBulkImport`: doc shows mandatory `-CsvPath` and an `-OutputPath` parameter. Reality: the mandatory parameter is `-Candidates` (an array of already-imported candidate objects, **not** a CSV path), and the report-path parameter is `-ReportPath`, not `-OutputPath`. Every documented example for this function would fail on a missing-mandatory-parameter error before even reaching the unknown-parameter error.

### Finding 1.7 - `Test-SharedMailboxCandidate` return type (API-REFERENCE.md ~L163, ~L171)

Doc claims the function "Returns `$true` if valid, `$false` if validation fails" and shows `if (Test-SharedMailboxCandidate -ADUser $user) { ... }` as the idiomatic usage. Reality: it returns a `[PSCustomObject]` with `SamAccountName`/`IsValid`/`ValidationErrors`/`ValidationChecks`. A `PSCustomObject` is always truthy in PowerShell - **the documented `if` pattern silently always takes the true branch**, regardless of the actual validation result. This is not a syntax error a user would notice; it's a logic bug baked into the documentation itself.

### Finding 1.8 - `Get-MailboxProvisioningMetrics` (API-REFERENCE.md ~L473-487)

Doc's parameter is `-Days` (default 30); real parameter (verified) is `-TrendDays` (default 30). Documented example `Get-MailboxProvisioningMetrics -Days 30` would fail.

### Finding 1.9 - `Invoke-SharedMailboxProvisioning` (API-REFERENCE.md ~L267-292)

Doc shows `-Filter`, `-TargetOU`, `-DryRun` and a return object with a `.ToCreate.Count` property. None of these exist. Real parameters are `-SamAccountNamePrefix`, `-DescriptionStartsWith`, `-SearchBase`, `-SkipPermissionQueue`, `-BacklogPath`, `-GenerateReport`; the return object's property names (`MailboxesCreated`/`MailboxesFailed`/etc.) also don't match the doc's `Discovered`/`Created`/`Failed`/`Duration`.

### Finding 1.10 - `Export-MailboxAuditLog` Required column (API-REFERENCE.md ~L432-444)

Minor but concrete: doc marks `-Format` and `-OutputPath` as **Mandatory = Yes**; both are actually optional (`-Format` defaults to `"HTML"`, `-OutputPath` defaults to `""` and the function returns a string when omitted).

### Finding 1.11 - Four undisclosed no-op parameters (not three)

`PROJECT-TRACKING.md`/`COMPLIANCE-AUDIT-PHASE-PRERELEASE.md` already document three confirmed no-op public parameters (`Test-SharedMailboxCandidate -ValidationAttribute`, `Resolve-MailboxProvisioningFailure -DiagnoseAll`, `Invoke-SharedMailboxProvisioning -GenerateReport`). This audit found a **fourth, not previously tracked**: `Set-MailboxProvisioningSchedule -MaxRetries` is accepted by the parameter block but never referenced anywhere else in the function body (confirmed by reading the full file). None of the four no-ops are disclosed as non-functional in USER-GUIDE.md or API-REFERENCE.md - they're either omitted entirely (silently incomplete) or listed as if they work (actively misleading), which is inconsistent between parameters.

**Recommendation (Part 1):** `docs/API-REFERENCE.md` and `docs/USER-GUIDE.md` need a full pass regenerating every function's signature block from the actual current `param()` blocks - the drift is too extensive for spot-fixes. Given ~10 of 18 functions have at least one broken example, treat this as a Pre-Release blocker, not a Week 2 cleanup item: a beta tester following either doc verbatim will hit failures on most workflows.

---

## Part 2: `README.md` Quick Start - Nonexistent Functions

### Finding 2.1 - Quick Start block calls functions that don't exist (README.md L35-41)

```
Connect-ExchangeOnline -Tenant "mytenant.onmicrosoft.com"
New-SharedMailbox -DisplayName "Sales Team" -PrimarySmtpAddress "sales@contoso.com"
Add-SharedMailboxMember -Identity "sales@contoso.com" -Members @("user1@contoso.com", "user2@contoso.com")
```

None of these three commands exist in this module. `Connect-ExchangeOnline` (no `Env` suffix, no `-Tenant`) is the underlying ExchangeOnlineManagement cmdlet, not this module's wrapper. `New-SharedMailbox` and `Add-SharedMailboxMember` don't exist anywhere in `functions/Public/` under any name - the closest real equivalents are `New-SharedMailboxRemote` (different, larger parameter set) and `Invoke-MailboxPermissionQueue` (backlog-based, not identity/member-list based). This is the very first thing a new user or evaluator would try and copy-paste; it fails on line 1. Confirmed this predates the 2026-07-01 rework - it appears to have never matched any version of the real API.

### Finding 2.2 - Version banner contradiction within the same file (README.md L5, L52, L77-79)

The file header states `v0.9.0-beta.1` / Pre-Release Phase Active, but the "Project Status" section further down the same file still states `v0.8.2 (Beta-Phase-Complete)` with Tier 7 test counts from that phase. Two different version claims in one document.

**Recommendation (Part 2):** Rewrite the Quick Start block against real function signatures (see Part 1 findings for the correct parameter names), and reconcile the two version banners in `README.md` to a single current value.

---

## Part 3: Setup & Connection Docs - Staleness vs. the 2026-07-01 Rework

### Finding 3.1 - `docs/README.md` never updated for the connection rework

Still stamped "v0.8.2 | Beta-Phase-Complete, Pre-Release-Ready | Last Updated 2026-06-30" - one day before the cert-based auth / `-ProxyUrl` / `-Prefix` / `Initialize-ProvisioningConnections.ps1` changes landed. Doesn't mention any of the new `Connect-ExchangeOnlineEnv` capabilities.

### Finding 3.2 - `docs/SETUP.md` Step 3 (credential setup) omits the mechanism actually in use

`docs/SETUP.md`'s Step 2 (config keys) was correctly updated on 2026-07-01 and matches current code (`Organization`/`AppId`/`CertificateThumbprint`, correct script name). However, Step 3 (Service Account credentials, ~L59-94) only describes the Windows Credential Manager / Azure Key Vault / env-var fallback chain (`_Get-ServiceAccountCredential`) as "Choose ONE method," with no mention of `scripts/Initialize-ProvisioningConnections.ps1`'s clixml-file mechanism, which is what `New-SharedMailboxRemote` actually reads today via `-CredentialPath`. A developer following only Step 3 would miss the credential path the code actually exercises.

### Finding 3.3 - `docs/SETUP.md` directory tree and timestamp are stale

Marks `scripts/` as "(future)"/"(placeholder)" (~L450-451); it now contains two real files (`Provision-BulkMailboxesFromCSV.ps1`, `Initialize-ProvisioningConnections.ps1`). Footer says "Last Updated: 2026-06-29," predating the rework by two days despite Step 2 having been partially updated since.

### Finding 3.4 - Confirmed clean: no dangling references to deleted files

Checked for leftover references to `scripts/Initialize-OnPremCredential.ps1` (renamed) and `_Initialize-ScheduledTaskCredential` (superseded) in `README.md`, `docs/README.md`, `docs/SETUP.md` - none found in current-phase docs. (Historical phase docs do still name them - see Finding 5.2, which is expected/correct as a historical record.)

**Recommendation (Part 3):** Update `docs/README.md`'s version/date banner and add a short section on the new auth model; add the clixml credential mechanism to `docs/SETUP.md` Step 3; refresh the directory tree and footer timestamp.

---

## Part 4: `docs/ADMIN-GUIDE.md` and `docs/OPERATIONS-RUNBOOK.md` - Fictional Infrastructure

This is the most severe cluster of findings in the audit.

### Finding 4.1 - Documented config file and schema do not exist

Both docs describe a config file at `$env:ProgramData\SharedMailboxProvisioner\config\settings.json` with keys `ScheduledTaskInterval`, `RetryDelaySeconds`, `BatchSize`, `LogRetentionDays`, `AcceptedDomains`, `DefaultACLGroup`, `ServiceAccount`, `AzureADConnectSyncWaitMinutes` (ADMIN-GUIDE.md ~L90-135, ~L244-261; referenced again in OPERATIONS-RUNBOOK.md). Verified against `config/config.template.json` and `_Get-Configuration.ps1`: the real config lives at `config/config.<Environment>.json` with a completely different flat schema (`Organization`, `AppId`, `CertificateThumbprint`, `DefaultMailboxQuota`, `LogRetentionDays`, `MaxRetries`). Only `LogRetentionDays` overlaps. **An operator editing the documented file would have zero effect on the system** - it's the wrong path and (mostly) the wrong keys.

### Finding 4.2 - Documented scheduled-task infrastructure doesn't exist

Both docs assume a self-managing ScheduledTask running `C:\Scripts\Invoke-MailboxProvisioning.ps1` with interval/retry behavior driven by the (fictional) config file. Reality: no such wrapper script exists anywhere in the repo; `Set-MailboxProvisioningSchedule.ps1` only reconfigures an *already-existing* task's trigger interval (it does not create one), and `Invoke-SharedMailboxProvisioning.ps1` is a synchronous orchestrator with no built-in scheduling awareness. The Installation & Deployment steps and most P0/maintenance procedures in both docs assume infrastructure that the documented setup steps never actually create.

### Finding 4.3 - P0 incident procedure relies on a known-unreliable health check (highest-severity finding)

`OPERATIONS-RUNBOOK.md` (~L112-117, ~L357-358) and `ADMIN-GUIDE.md` (~L355-368) both present `Get-MailboxProvisioningHealth -CheckEXO` as an authoritative "Step 2" signal in critical-incident triage. Verified in source: the check looks for `Get-PSSession | Where-Object { $_.ConfigurationName -eq "Microsoft.Exchange" }` (`Get-MailboxProvisioningHealth.ps1:117`) - a classic remoting marker that EXO-V3's REST-based `Connect-ExchangeOnline` sessions do not set. This exact gap is already tracked as an open, unfixed defect in `PROJECT-TRACKING.md` and `COMPLIANCE-AUDIT-PHASE-PRERELEASE.md` Part 5 item 3 - but neither operational doc mentions the caveat. **An on-call operator following the P0 runbook today could be told EXO is disconnected when it isn't, or vice versa, at the exact moment they need an accurate signal.**

### Finding 4.4 - Two more tracked known issues, also undocumented for operators

- Known Issue #1 (hardcoded `C:\Repos\SharedMailboxProvisioner\...` defaults for `New-SharedMailboxRemote -BacklogPath`/`-CredentialPath`, confirmed in Finding 1.2's source read - doesn't match this repo's actual deployment location): both docs' backup/recovery sections reference `$env:ProgramData\...\data\...` paths as if that's authoritative, with no caveat about the mismatched code default.
- Known Issue #2 (`_GetExchangePSSession`'s "current user context" auto-detect reads a config shape `$config.exchange.onPremises.uri` that `_Get-Configuration.ps1`'s real flat schema never produces, so that path likely always silently falls through to credential-based auth): not mentioned at all in either doc's credential-handling section, which presents credential auth as the only deliberate design rather than a silent fallback from a dead code path.

### Finding 4.5 - Version banner

Both docs' headers still say "v0.8.2 | Beta-Phase-Complete, Pre-Release-Ready," consistent with the same staleness found in Part 1/3.

**Recommendation (Part 4):** Treat this as a Pre-Release blocker alongside Part 1. At minimum, before Week 1's live smoke testing continues: (a) correct or remove the fictional config-file section, (b) add an explicit caveat to the P0 runbook's EXO health-check step noting it may be unreliable against EXO-V3 sessions until Known Issue #3 is fixed, (c) add the other two known issues to the relevant sections so an operator isn't caught by surprise mid-incident.

---

## Part 5: Cross-References & Meta-Doc Consistency

### Finding 5.1 - Broken link in `DECISIONS.md`

`DECISIONS.md:472` links to `docs/IMPLEMENTATION-PLAN-SharedMailboxCandidates.md`, which does not exist anywhere in the repository (confirmed via directory search). Dead link.

### Finding 5.2 - Stale function names in historical Alpha-phase audit (expected/low-impact)

`docs/Alpha-Phase/COMPLIANCE-AUDIT-PHASE-ALPHA-COMPLETE.md` still names `Validate-SharedMailboxCandidate.ps1` (line ~46, though self-annotated with "renamed to Test-SharedMailboxCandidate") and `Initialize-ScheduledTaskCredential.ps1` (lines ~58, ~255, **not** annotated as superseded by `scripts/Initialize-ProvisioningConnections.ps1`). These are historical/frozen documents by nature, so this is low-severity, but the second reference has no annotation pointing a reader to the current replacement the way the first one does.

### Finding 5.3 - Hook-enforcement claim gap between `STRUCTURE.md`/`CLAUDE.md` and the Compliance Audit

`STRUCTURE.md` Regel 10.2 and `CLAUDE.md` Regel 5.1 both state, in the present tense, that the pre-commit hook blocks non-compliant commits. As `COMPLIANCE-AUDIT-PHASE-PRERELEASE.md` documents in detail, this was **false** for most of 2026-07-01 (no hook installed, `build.ps1` crashed under real invocation, the validation gate could structurally never fail) until fixed and verified later the same day. The claim in `STRUCTURE.md`/`CLAUDE.md` is technically true again as of end-of-day, but neither file mentions that the mechanism was broken earlier, or links to the audit that fixed it - a reader has no way to know the enforcement story has a same-day history worth knowing about.

### Finding 5.4 - Unlinked "0 violations" claims in historical compliance docs

`docs/Alpha-Phase/COMPLIANCE-AUDIT-PHASE-ALPHA-COMPLETE.md` and `docs/Beta-Phase/COMPLIANCE-AUDIT-PHASE-BETA-COMPLETE.md` both assert "PSScriptAnalyzer: 0 violations" / "100% compliant" with no caveat. `COMPLIANCE-AUDIT-PHASE-PRERELEASE.md`'s own executive summary explicitly states these historical claims "were never actually gated by a working pre-commit check" - but neither historical doc links forward to that caveat (the link only exists in the other direction, Pre-Release's README pointing back to the Beta doc with no warning text attached).

### Finding 5.5 - Stale ADR numbering

Both `docs/Alpha-Phase/COMPLIANCE-AUDIT-PHASE-ALPHA-COMPLETE.md` and `docs/Beta-Phase/COMPLIANCE-AUDIT-PHASE-BETA-COMPLETE.md` cite "ADR-010" for ASCII-only output handling. Current `DECISIONS.md` caps at ADR-007, and ADR-007 is titled "Output Handling - ASCII-only Strings" - i.e. what these older docs call ADR-010 is today's ADR-007, a leftover from an earlier ADR-numbering scheme that was consolidated but never back-corrected in the historical audits. Harmless unless someone cross-checks "ADR-010" against the current `DECISIONS.md` and concludes it's missing.

### Finding 5.6 - Confirmed clean

`RELEASE-PROCESS.md` uses `v1.0.0` throughout its worked examples as a generic template (dated 2026-06-29, predates the more specific Pre-Release version scheme) - not a contradiction, just a template document that reads oddly next to the current `v0.9.0-beta.1 -> v0.9.0 -> v1.0.0` train. `functions/FUNCTION-STATUS.md` matches the actual 18 Public + 11 Private files exactly, no orphans either direction. Version numbers in `CLAUDE.md`, `PROJECT-TRACKING.md`, and the Pre-Release roadmap/implementation-plan docs are internally consistent with each other.

**Recommendation (Part 5):** Fix the `DECISIONS.md:472` dead link (remove it or point at the correct current doc, if one exists under a different name). Low-priority cosmetic pass on the ADR-010/ADR-007 numbering and the unlinked historical "0 violations" caveats - worth a one-line pointer each, not urgent.

---

## Conclusion

The picture splits cleanly by audience. Documents actively touched during today's connection rework (`docs/SETUP.md`'s config section, `PROJECT-TRACKING.md`, the meta docs) are largely accurate and internally consistent. Documents that describe the module's public API and day-2 operations (`README.md`'s Quick Start, `docs/USER-GUIDE.md`, `docs/API-REFERENCE.md`, `docs/ADMIN-GUIDE.md`, `docs/OPERATIONS-RUNBOOK.md`) were last touched at the end of Phase Beta (2026-06-30) and have not been reconciled with the actual code since - independent of the 2026-07-01 rework, most of the API-doc drift found here (wrong parameter names, wrong return types, the `Test-SharedMailboxCandidate` truthy-object bug) predates that day entirely.

Given Week 1's manual testing plan (`MANUAL-TESTING-PLAN.md`) has testers exercising these exact workflows on 2026-07-03, and given that following the current `README.md`/`USER-GUIDE.md`/`API-REFERENCE.md` verbatim would fail on the majority of documented example commands, **Part 1, 2, and 4 should be treated as Pre-Release blockers**, not deferred to Week 2 - a tester hitting a wall on the published Quick Start example within the first five minutes undermines the whole point of this week's real-world validation.

### Prioritized Action List

**Before Week 1 manual testing (2026-07-03) / Pre-Release blockers:**
1. Rewrite `docs/API-REFERENCE.md`'s parameter tables and return-type descriptions from the actual current `param()` blocks for all 18 public functions (Part 1).
2. Fix `docs/USER-GUIDE.md`'s Quick Start and FAQ example commands to use real parameter names (Part 1).
3. Fix `README.md`'s Quick Start block - remove/replace `New-SharedMailbox` and `Add-SharedMailboxMember`, which don't exist (Part 2).
4. Correct or remove `docs/ADMIN-GUIDE.md`/`docs/OPERATIONS-RUNBOOK.md`'s fictional `settings.json` config section (Finding 4.1).
5. Add an explicit reliability caveat to the P0 runbook's EXO health-check step (Finding 4.3) - this is the one finding with real incident-response consequences if left as-is.

**Should fix soon (Week 1-2):**
6. Reconcile `README.md`'s two conflicting version banners (Finding 2.2).
7. Add the clixml credential mechanism to `docs/SETUP.md` Step 3 (Finding 3.2); refresh its directory tree/timestamp (Finding 3.3).
8. Update `docs/README.md`'s version/date banner and add a section on the new auth model (Finding 3.1).
9. Disclose the 4 no-op parameters consistently across USER-GUIDE.md/API-REFERENCE.md, including the newly found `Set-MailboxProvisioningSchedule -MaxRetries` (Finding 1.11).
10. Document the other 2 known issues (hardcoded paths, dead PSSession fallback) in ADMIN-GUIDE.md/OPERATIONS-RUNBOOK.md (Finding 4.4).

**Cosmetic / low priority:**
11. Fix the dead link at `DECISIONS.md:472` (Finding 5.1).
12. Annotate the stale `Initialize-ScheduledTaskCredential.ps1` reference in the Alpha compliance doc (Finding 5.2).
13. Add a same-day-history pointer from `STRUCTURE.md` Regel 10.2 / `CLAUDE.md` Regel 5.1 to the Compliance Audit's hook-fix findings (Finding 5.3).
14. Add a forward-pointing caveat from Alpha/Beta compliance docs' "0 violations" claims to the Pre-Release audit (Finding 5.4).
15. Correct "ADR-010" references to "ADR-007" in the Alpha/Beta compliance docs, or add a translation note (Finding 5.5).

**All 15 items above: RESOLVED 2026-07-01.** See Resolution Addendum below for what each fix actually touched and what remains open as a code-level (not documentation-level) gap.

---

## Resolution Addendum (same day, 2026-07-01): All findings fixed and re-verified

All 15 action-list items were completed the same day this audit was written, via six parallel documentation-only edit passes plus direct fixes to the governance docs (`DECISIONS.md`, `STRUCTURE.md`, `CLAUDE.md`). Each pass re-verified every claim against the actual current source (`functions/Public/*.ps1`, `config/config.template.json`, `functions/Private/_Get-Configuration.ps1`, `functions/Private/_Write-Log.ps1`, `functions/Public/Get-MailboxProvisioningHealth.ps1`) before writing, rather than trusting this audit's own paraphrase - a handful of the highest-severity rewrites (the fictional config schema in `docs/ADMIN-GUIDE.md`, the P0 health-check caveat in `docs/OPERATIONS-RUNBOOK.md`, the `Test-SharedMailboxCandidate` no-op table in `docs/API-REFERENCE.md`) were additionally spot-checked directly against source by re-reading the diffs after the fact.

### Part 1+2+3 (Pre-Release blockers 1-5, items 6-8): `README.md`, `docs/API-REFERENCE.md`, `docs/USER-GUIDE.md`, `docs/SETUP.md`, `docs/README.md`

All 18 public functions' syntax blocks, parameter tables, and examples in `docs/API-REFERENCE.md`/`docs/USER-GUIDE.md` were regenerated from the real `param()` blocks (Findings 1.1-1.11 all fixed, including the `Test-SharedMailboxCandidate` truthy-`PSCustomObject` bug, which now carries an explicit "do not use `if (Test-SharedMailboxCandidate ...)` directly" warning, and a consolidated "Known No-Op Parameters" table covering all 4 confirmed no-ops). `README.md`'s Quick Start now uses `Connect-ExchangeOnlineEnv` / `Get-SharedMailboxCandidates` / `Invoke-SharedMailboxProvisioning` with real parameters instead of the three nonexistent commands, its two conflicting version banners were reconciled to v0.9.0-beta.1, and its hardcoded `C:\Repos\...` import path was generalized to a relative `.\SharedMailboxProvisioner.psd1` form. `docs/SETUP.md` Step 3 now documents the `Initialize-ProvisioningConnections.ps1` clixml mechanism as the primary path (with the KeyVault/CredMgr/EnvVar chain reframed as the fallback), its directory tree and footer date were refreshed, and Step 7's `Connect-ExchangeOnlineEnv` example was expanded to cover the new auth params. `docs/README.md`'s version banner and Connect-ExchangeOnlineEnv summary were brought current. All six files' version banners now read v0.9.0-beta.1 / 2026-07-01.

### Part 4 (Pre-Release blockers 4-5, item 10): `docs/ADMIN-GUIDE.md`, `docs/OPERATIONS-RUNBOOK.md`

The entire fictional `settings.json`/`ScheduledTaskInterval` config section was replaced with the real `config/config.<Environment>.json` schema, with an explicit "not implemented" note for every key that doesn't exist in code (Finding 4.1). The fictional `C:\Scripts\Invoke-MailboxProvisioning.ps1` wrapper was replaced with an honest description of the real (more manual) setup process: no wrapper ships, `Set-MailboxProvisioningSchedule` only retunes an already-existing task, so admins must write their own action script calling `Invoke-SharedMailboxProvisioning` and register the task themselves before that function is useful (Finding 4.2). The P0 EXO health-check caveat (Finding 4.3, the single highest-priority fix in this audit) was added at all three call sites in both docs, including a working `Get-ETHMailbox -ResultSize 1` live cross-check wired directly into the P0 script logic (not just prose), so the incident-response script itself now distinguishes "health check says disconnected but live call succeeds" (likely the known gap, trust the live call) from a genuine outage. The two other known-but-undocumented issues (hardcoded `-BacklogPath`/`-CredentialPath` defaults, dead on-prem PSSession auto-detect) were added to the Disaster Recovery and Credential Management sections respectively (Finding 4.4). **Note:** these fixes correct the *documentation* - the underlying code defects (the EXO-V3 health-check gap itself, the hardcoded path defaults, the dead PSSession auto-detect path) remain open and are tracked separately in `PROJECT-TRACKING.md` and `COMPLIANCE-AUDIT-PHASE-PRERELEASE.md` Part 5; fixing those is a code change, out of scope for a documentation audit.

### Part 5 (items 11-15): `DECISIONS.md`, `STRUCTURE.md`, `CLAUDE.md`, Alpha/Beta compliance docs

`DECISIONS.md:472`'s dead link now points to `docs/Alpha-Phase/IMPLEMENTATION-PLAN-PHASE-ALPHA.md`, where the candidate-discovery functions' delivery specs actually live (the originally-linked standalone doc was never created). `STRUCTURE.md` Regel 10.2 and `CLAUDE.md` Regel 5.1 each gained a one-line pointer to `COMPLIANCE-AUDIT-PHASE-PRERELEASE.md`'s account of the same-day hook-enforcement outage, without changing the rules themselves. In both `docs/Alpha-Phase/COMPLIANCE-AUDIT-PHASE-ALPHA-COMPLETE.md` and `docs/Beta-Phase/COMPLIANCE-AUDIT-PHASE-BETA-COMPLETE.md`: the `Initialize-ScheduledTaskCredential.ps1` references gained a "(Superseded 2026-07-01 by scripts/Initialize-ProvisioningConnections.ps1)" annotation matching the existing rename-annotation style already used for `Test-SharedMailboxCandidate`; every "ADR-010" reference to ASCII-only output was corrected to "ADR-007" after confirming each occurrence was specifically about that topic; and each "0 violations"/"100% compliant" claim gained a forward-pointing "Note (added 2026-07-01)" addendum citing `COMPLIANCE-AUDIT-PHASE-PRERELEASE.md`'s finding that the enforcement gate was non-functional at the time those figures were recorded. These are frozen historical documents - only additive annotations were made, no existing findings or numbers were altered.

### Separately: path portability

Per a follow-up request (not a finding in this audit), `docs/Pre-Release/MANUAL-TESTING-PLAN.md`'s 7 hardcoded occurrences of the current developer's absolute path (`S:\Scheduled Tasks\Exchange SE\SharedMailboxProvisioner`) were generalized to a `$repoRoot` variable convention introduced once near the start of the runbook, so the test plan is portable to any tester's checkout location.

### Verification

`.\build.ps1 -Validate` was re-run after all edits (this pass only touched `.md` files, so it primarily serves as a regression check that nothing else was disturbed): **`[OK] Build validation PASSED`**, 0 PSScriptAnalyzer issues, 0 blocking indentation/bracing issues, pre-existing BOM warnings unchanged and unrelated to this pass. A targeted grep for the specific broken strings this audit found (`New-SharedMailbox`, `Add-SharedMailboxMember`, `-ExchangeEnvironmentName`, `settings.json`) across all `.md` files confirmed no remaining occurrences outside of: (a) `docs/ADMIN-GUIDE.md`'s new corrective note explaining that `settings.json` does *not* exist (intentional), (b) this audit doc and `COMPLIANCE-AUDIT-PHASE-PRERELEASE.md` themselves quoting the original findings as a historical record (intentional, frozen), and (c) generic illustrative naming-convention examples in `STRUCTURE.md`/`DECISIONS.md` (pre-existing, not documentation-accuracy claims about this module's actual API, out of scope for this audit).

**Status: All 15 findings closed.** The 3 known code-level defects underlying Findings 4.3/4.4 (EXO-V3 health-check gap, hardcoded path defaults, dead PSSession auto-detect) remain open as tracked code issues, not documentation issues - the documentation now accurately discloses all three instead of silently presenting them as working.

This audit covers documentation accuracy and consistency only. It does not replace `SECURITY-AUDIT-PHASE-PRERELEASE.md` (vulnerability review) or `COMPLIANCE-AUDIT-PHASE-PRERELEASE.md` (build-gate integrity, code-level compliance) from the same day.
