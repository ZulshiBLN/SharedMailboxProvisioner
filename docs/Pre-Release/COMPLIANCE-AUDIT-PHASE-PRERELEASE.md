# SharedMailboxProvisioner - Pre-Release Phase Compliance Audit

**Date:** 2026-07-01 (Part 1 findings fixed and re-verified same day, see Addendum)
**Project:** SharedMailboxProvisioner
**Phase:** Pre-Release (v0.9.0-beta.1), Week 1 Day 1
**Scope:** Full repository audit against CLAUDE.md, STRUCTURE.md, DECISIONS.md (ADR-001 to ADR-007)
**Method:** Static analysis (PSScriptAnalyzer + build.ps1), manual rule-by-rule verification, git/secrets audit, live reproduction of the pre-commit gate

> **Addendum note:** Fixing Finding 1.2 (the `$Error` crash) exposed a second, more severe defect in `build.ps1` itself - see the Addendum at the end of this document. That defect means the "0 PSScriptAnalyzer violations" / "OK" figures quoted below in Part 2 (captured from `build.ps1 -Validate` output) were **false positives**: the validation gate was structurally incapable of ever reporting failure, and was silently swallowing all of its own diagnostic output. The real, previously-hidden numbers are in the Addendum.

---

## Executive Summary

Code-level compliance (help blocks, ASCII output, naming, secrets handling) is high. However, this audit found that **the enforcement mechanism itself is broken and not currently installed**, which means the "0 PSScriptAnalyzer violations" and "100% compliant" claims in prior audits (Alpha/Beta) were never actually gated by a working pre-commit check. This is the headline finding and should be fixed before Pre-Release sign-off.

| Area | Result | Severity |
|---|---|---|
| Pre-commit hook installed | **NO** - `.git/hooks/pre-commit` does not exist | CRITICAL |
| `build.ps1 -Validate` crashes under real invocation | **YES**, reproducible | CRITICAL |
| `build.ps1`'s Bracing/BOM checks can ever fail the build | **NO** - always return `$true` | HIGH |
| PSScriptAnalyzer (as currently run) | 0 violations | OK |
| ASCII-only output (ADR-007) | 0 violations in `functions/`, `scripts/`, `tests/` | OK |
| `Write-Host` / `Invoke-Expression` usage | 0 violations | OK |
| Secrets in Git (credentials, prod config) | 0 violations, correctly `.gitignore`d | OK |
| Public function comment-based help (Regel 3.1) | 17/18 compliant, 1 violation | MEDIUM |
| Private function `_` naming convention (Regel 1.5) | 5 function names violate it | LOW |
| Redundant per-file `Export-ModuleMember` (ADR-001/Regel 12) | 17/18 Public files | LOW |
| Test coverage / mock accuracy | Known gaps, already tracked | (see Part 4) |

---

## Part 1: Build & Pre-Commit Gate Integrity (CRITICAL)

This is the mechanism CLAUDE.md Regel 5.1 and STRUCTURE.md Regel 10.1/10.2 rely on ("Hook blockiert Commits mit Linting-Fehlern"). It does not currently work.

### Finding 1.1 - No pre-commit hook is installed

```
$ cat .git/hooks/pre-commit
NO PRE-COMMIT HOOK INSTALLED
```

`setup-hooks.ps1` exists and would install one, but it has evidently never been run in this working copy (or was removed). Right now, **any commit can be made with linting errors, non-ASCII output, or missing help blocks with zero automated resistance.** All prior "0 violations" audits (Alpha/Beta compliance docs) reflect manual `build.ps1 -Validate` runs by the author, not an enforced gate.

**Action:** Run `.\setup-hooks.ps1` - but not before Finding 1.2 and 1.3 are fixed, or the installed hook will simply block every commit (or silently no-op, see 1.2).

### Finding 1.2 - `build.ps1` crashes when invoked the way the hook actually invokes it

`build.ps1` line 47 (and identically `setup-hooks.ps1` line 29) does:

```powershell
$Error = '[ERROR]'
```

`$Error` is PowerShell's built-in automatic variable and its `Options` are `Constant` at the top scope:

```
$ Get-Variable -Name Error | Select Name, Options
Name  Options
----  -------
Error Constant
```

Reassigning it throws a **terminating** error: `Cannot overwrite variable Error because it is read-only or constant.` Reproduced directly:

```
$ powershell -NoProfile -File .\build.ps1 -Validate
powershell : Cannot overwrite variable Error because it is read-only or constant.
At S:\...\build.ps1:47 char:1
+ $Error = '[ERROR]'
EXITCODE:1
```

Whether this actually fires depends on the calling scope: invoking `.\build.ps1` directly from an interactive session happened to create a shadowing script-scoped variable and silently "succeeded" (this is what produced the misleadingly clean `[OK] Build validation PASSED` output earlier in this session - notably *without* printing any of the intermediate `=== PSScriptAnalyzer Linting ===` section headers the script is supposed to print, itself a sign something was already swallowed). But the **hook's own invocation pattern** (`pwsh -NoProfile -Command { & '.\build.ps1' -Validate; exit $LASTEXITCODE }`, from `setup-hooks.ps1` line 80-83) is exactly the fresh-scope pattern that reproducibly crashes.

**Impact:** If the hook is installed as-is, every commit attempt would either hard-fail on this bug (blocking all commits, including compliant ones) or - depending on shell nuances - silently report success without having run any of the four validation stages.

**Action:** Rename the local variable (e.g. `$ErrorPrefix`) in both `build.ps1` and `setup-hooks.ps1`.

### Finding 1.3 - The installed hook would use `pwsh`, which is not present on this machine

```
$ command -v pwsh
pwsh NOT FOUND on this machine
```

`setup-hooks.ps1` generates a hook that calls `pwsh` (PowerShell 7+). Per ADR-002, PowerShell 5.1 is the mandated minimum/primary target, and this dev machine - consistent with the Pester 3.4.0-only note already in `PROJECT-TRACKING.md` - only has Windows PowerShell 5.1. As written, the hook cannot run here at all (`pwsh: command not found`), independent of Finding 1.2.

**Action:** Generate the hook with `powershell.exe -NoProfile` (or detect and fall back), matching ADR-002's compatibility matrix.

### Finding 1.4 - Two of the four `build.ps1` validation stages can never fail the build

`Test-Bracing` and `Test-BOM` both count `$issues` and print `[ERROR]`/`[WARN]` status lines, but **both unconditionally `return $true`** regardless of the count (`build.ps1:220`, `build.ps1:258`). Only `Test-PSScriptAnalyzer` and `Test-Indentation` can flip `$allPassed` to `$false`. This means K&R bracing violations and missing UTF-8 BOM are cosmetically reported but structurally incapable of blocking a commit, contradicting STRUCTURE.md Regel 10.1 which lists "Bracing Check" and "BOM Check" alongside the others as build-blocking validations.

**Action:** Either make these stages return `$false` when `$issues -gt 0` (if they're meant to gate), or explicitly document them as advisory-only in STRUCTURE.md.

### Finding 1.5 - `PSProvideCommentHelp` doesn't enforce STRUCTURE.md's required sections

STRUCTURE.md Regel 3.1 requires PUBLIC functions to have `.SYNOPSIS`, `.DESCRIPTION`, `.PARAMETER` (per parameter), `.EXAMPLE`, and `.NOTES`, and states enforcement is "PSScriptAnalyzer Regel `PSProvideCommentHelp` (Fehler)". In practice, this rule only checks that *a* comment-help block with a `.SYNOPSIS` exists before the function - it does not check for the other four sections. This is why Finding 2.1 below passed a clean `build.ps1 -Validate` run undetected.

**Action:** Either add a custom check to `build.ps1` for section completeness, or correct the STRUCTURE.md enforcement claim to reflect its actual (partial) coverage.

---

## Part 2: Code Quality & Documentation Compliance

### Finding 2.1 - `Test-SharedMailboxCandidate.ps1` is missing 3 of 5 required help sections (MEDIUM)

Per STRUCTURE.md Regel 3.1, this PUBLIC function (3 parameters: `ADUser`, `AcceptedDomains`, `ValidationAttribute`) has only `.SYNOPSIS` and `.DESCRIPTION`:

```
functions/Public/Test-SharedMailboxCandidate.ps1 | SYNOPSIS=1 DESCRIPTION=1 PARAMETER=0 EXAMPLE=0 NOTES=0
```

All other 17 Public functions have complete `.SYNOPSIS`/`.DESCRIPTION`/`.PARAMETER`/`.EXAMPLE`/`.NOTES` blocks. This is a genuine, isolated gap - likely from the `Validate-SharedMailboxCandidate` -> `Test-SharedMailboxCandidate` rename (per PROJECT-TRACKING.md) not carrying the help block along.

**Action:** Add `.PARAMETER` (x3), `.EXAMPLE`, `.NOTES` to close the gap.

**RESOLVED 2026-07-01:** Help block completed. `tests/Test-ValidateSharedMailboxCandidate.ps1` also renamed to `tests/Test-SharedMailboxCandidate.ps1` to match the Regel 9.1 `Test-<FunctionName>.ps1` convention (was the same leftover-from-rename issue, tracked separately in Part 4).

### Finding 2.2 - 5 Private function names don't carry the `_` prefix (LOW)

CLAUDE.md Regel 1.5 / STRUCTURE.md Regel 3.1 define PRIVATE functions by their `_` prefix. Three files in `functions/Private/` are named with the prefix but the function(s) *inside* are not:

| File | Function(s) defined | Prefix present? |
|---|---|---|
| `_Write-Log.ps1` | `Write-Log`, `Remove-OldLogs` | No |
| `_Get-Configuration.ps1` | `Get-Configuration`, `Get-ServiceAccountCredential` | No |
| `_ConvertTo-MailboxReportFormat.ps1` | `ConvertTo-MailboxReportFormat` | No |

No functional/security impact - `SharedMailboxProvisioner.psm1:16` (`Export-ModuleMember -Function $Public.BaseName`) only exports functions whose names match a `functions/Public/*.ps1` file's base name, so none of these 5 are accidentally exported. This is a pure naming-convention inconsistency versus the other 8 Private files (`_ValidateEmailFormat`, `_RetryExchangeOperation`, etc.), which do carry the prefix on the function name itself.

**Action:** Low priority, cosmetic per FUNCTION-STATUS.md's own existing "drift" note - rename for consistency at a convenient point, or explicitly amend Regel 1.5 to say the prefix applies to the *file*, not necessarily the function name.

**RESOLVED 2026-07-01 (partial):** `Get-Configuration` -> `_Get-Configuration`, `Get-ServiceAccountCredential` -> `_Get-ServiceAccountCredential`, `ConvertTo-MailboxReportFormat` -> `_ConvertTo-MailboxReportFormat`, `Remove-OldLogs` -> `_Remove-OldLogs` - all callers updated (functions, tests, DECISIONS.md, docs/SETUP.md). `Write-Log` deliberately left unprefixed: 99 occurrences across 33 files (every Public function, plus it's the literal example name in ADR-004/STRUCTURE.md) made it too large a blast radius for this cleanup pass - tracked as an accepted, documented exception rather than fixed.

**Side effect discovered while fixing:** renaming these 4 to their approved-verb-plus-underscore form (`_Get-Configuration`, `_Get-ServiceAccountCredential`, `_ConvertTo-MailboxReportFormat`, `_Remove-OldLogs`) newly triggered `PSUseApprovedVerbs` on all four, even though `Get`/`ConvertTo`/`Remove` are all approved verbs. Same root cause as `PSProvideCommentHelp`'s `ExportedOnly` limitation noted earlier: when `Invoke-ScriptAnalyzer` analyzes a standalone `.ps1` file (as `build.ps1` does) rather than a loaded module, it cannot determine export status and its verb-noun parser does not recognize a verb once it's preceded by an underscore - so it reports the whole `_Get` token as an "unapproved verb". This never surfaced on the pre-existing underscore-prefixed Private functions (`_ValidateEmailFormat`, `_RetryExchangeOperation`, etc.) purely because none of them happened to start with an approved verb after the underscore in the first place. Suppressed with `SuppressMessageAttribute('PSUseApprovedVerbs', ...)` on all four, each with an inline justification.

### Finding 2.3 - Redundant per-file `Export-ModuleMember` calls (LOW)

17 of 18 `functions/Public/*.ps1` files end with their own `Export-ModuleMember -Function <Name>` line, in addition to the centralized `Export-ModuleMember -Function $Public.BaseName` in `SharedMailboxProvisioner.psm1:16`. STRUCTURE.md Regel 12.1/12.2 describes export control as centralized (PSM1 imports, PSD1/PSM1 exports) - the scattered per-file calls are redundant, not harmful (net export set is identical), but drift from the documented single-source-of-truth design. `Test-SharedMailboxCandidate.ps1` is the one file *without* this line, i.e. inconsistent either way.

**Action:** Low priority cleanup - remove the per-file calls, or standardize on having them everywhere; pick one.

**RESOLVED 2026-07-01:** Removed all 17 redundant per-file `Export-ModuleMember` calls. Export control is now solely centralized in `SharedMailboxProvisioner.psm1:16`, matching STRUCTURE.md Regel 12.1/12.2.

### Finding 2.4 - Everything else checked clean

- **ASCII-only output (ADR-007):** 0 non-ASCII characters found in any `.ps1` under `functions/`, `scripts/`, `tests/` (only match was a doc file, `FUNCTION-STATUS.md`, which isn't in scope for ADR-007).
- **`Write-Host`:** 0 occurrences anywhere in `functions/` or `scripts/`.
- **`Invoke-Expression`:** 0 occurrences anywhere in the repo's `.ps1` files.
- **Approved verbs / K&R bracing / 4-space indentation:** No violations reported by PSScriptAnalyzer's `PSUseApprovedVerbs`, `PSUseConsistentIndentation`, `PSUseConsistentWhitespace` rules (Finding 1.1-1.4 notwithstanding, a manual `Invoke-ScriptAnalyzer` pass produced 0 results).
- **PSD1 `FunctionsToExport`:** All 18 entries match exactly the 18 files in `functions/Public/`; no orphans in either direction.

---

## Part 3: Secrets & Configuration Handling (ADR-005, Regel 1.1, Regel 6.1)

- `config/Credential_D_Netbex.clixml` (currently open in the editor) is correctly excluded: `.gitignore:15 *.clixml` matches it, and `git ls-files config/` confirms it was never tracked.
- `config/config.prod.json` is correctly excluded (`.gitignore:9`), also never tracked.
- `git status` is clean - no untracked secrets staged.
- `config/config.template.json` (the only tracked file in `config/`) contains placeholder values only (`contoso.onmicrosoft.com`, `xxxxxxxx-...`, a dummy cert thumbprint) - no real tenant data.
- No hardcoded passwords, API keys, connection strings, or private key material found via pattern grep across `.ps1`/`.psd1`/`.json` files.
- No `data/` directory currently exists in the repo (referenced by the already-tracked "hardcoded `C:\Repos\...` default paths" known issue) - nothing to audit for accidental PII/log commits yet, but worth revisiting once that path is exercised for real.

**Result: PASS.** No secrets-handling violations found.

---

## Part 4: Test Coverage Cross-Check

Cross-referenced all 18 Public + 11 Private functions against `tests/`. Findings match what `FUNCTION-STATUS.md` already documents (i.e., no new gaps found), but are worth restating as compliance-relevant in this audit:

- **3 test files mock the wrong cmdlet** (`Test-GetSharedMailboxCandidates.ps1`, `Test-GetSharedMailboxACLGroup.ps1`, `Test-CheckForDuplicateEmails.ps1` all `Mock Get-ADUser`, but production code calls `Get-ADObject`). The production `-LDAPFilter` bug was fixed 2026-07-01; these tests were not, so they currently provide **false confidence** - they pass without ever exercising the real code path. This is a STRUCTURE.md Regel 9.2 (Arrange/Act/Assert must validate real behavior) gap that pre-dates this audit but is still open.
- `_ConvertTo-MailboxReportFormat` has no dedicated test file (`[NONE]` in FUNCTION-STATUS.md).
- `Connect-ExchangeOnlineEnv` and `scripts/Initialize-ProvisioningConnections.ps1` have no automated tests (both depend on interactive/external-module behavior - documented as intentional).
- `tests/Test-ValidateSharedMailboxCandidate.ps1` doesn't follow the `Test-<FunctionName>.ps1` convention (STRUCTURE.md Regel 9.1) for the now-renamed `Test-SharedMailboxCandidate` function - leftover from the `Validate-` -> `Test-` rename, same root cause as Finding 2.1.
- Local environment has Pester 3.4.0 only; the 345 counted `It` blocks have not been executed end-to-end with Pester 5.x to confirm they actually pass (pre-existing, tracked issue).

---

## Part 5: Carried-Forward Known Issues (from PROJECT-TRACKING.md)

Not re-verified in depth here (already documented with root cause and fix status), but flagged as still-open compliance/correctness gaps relevant to a Pre-Release go/no-go decision:

1. Hardcoded `C:\Repos\SharedMailboxProvisioner\...` default paths in `New-SharedMailboxRemote.ps1` don't match this repo's actual location.
2. `_GetExchangePSSession` reads a config shape (`$config.exchange.onPremises.uri`) that `_Get-Configuration.ps1`'s flat schema never produces - the "current user context" PSSession path likely always silently falls through.
3. EXO connectivity health checks (`Get-MailboxProvisioningHealth`, `Invoke-MailboxPermissionQueue`) look for classic named PSSessions and may not detect modern EXO-V3 REST-based connections.

---

## Prioritized Action List

**Before Pre-Release sign-off / before installing the hook:**
1. Fix the `$Error` constant-variable crash in `build.ps1` and `setup-hooks.ps1` (Finding 1.2).
2. Fix `setup-hooks.ps1` to invoke `powershell.exe`, not `pwsh` (Finding 1.3).
3. Make `Test-Bracing`/`Test-BOM` actually gate on `$issues`, or document them as advisory (Finding 1.4).
4. Run `.\setup-hooks.ps1` to actually install the pre-commit hook (Finding 1.1).

**Should fix soon (low risk, quick):**
5. Complete `Test-SharedMailboxCandidate.ps1`'s comment-based help (Finding 2.1).
6. Rewrite the 3 test files to mock `Get-ADObject`/`-LDAPFilter` instead of `Get-ADUser` (Part 4).

**Cosmetic / low priority:**
7. Underscore-prefix the 5 Private function names, or amend Regel 1.5 (Finding 2.2).
8. Remove or standardize redundant per-file `Export-ModuleMember` calls (Finding 2.3).
9. Rename `Test-ValidateSharedMailboxCandidate.ps1` to `Test-SharedMailboxCandidate.ps1` (Part 4).

**All 9 items above: RESOLVED 2026-07-01.** See Addendum 3 for what closing them out actually surfaced.

---

## Addendum 3 (same day, 2026-07-01): Items 5-9 done; closing them exposed the test suite has never actually run

Items 5, 7, 8, 9 were mechanical and completed as scoped: help block completed on `Test-SharedMailboxCandidate.ps1`; `Get-Configuration`/`Get-ServiceAccountCredential`/`ConvertTo-MailboxReportFormat`/`Remove-OldLogs` renamed with the `_` prefix and all callers updated (`Write-Log` itself deliberately excluded - 99 call sites, too large a blast radius, tracked as an accepted exception); all 17 redundant per-file `Export-ModuleMember` calls removed; test file renamed. Renaming the 4 functions to an approved-verb-plus-underscore form incidentally triggered new `PSUseApprovedVerbs` findings (PSScriptAnalyzer can't parse the verb past a leading underscore when linting a standalone file) - suppressed with justification, same pattern as Addendum 2.

Item 6 (rewrite the 3 AD-mock test files) is where this stopped being a quick pass:

### The 3 files, done as scoped
`Test-GetSharedMailboxCandidates.ps1`, `Test-GetSharedMailboxACLGroup.ps1` now mock `Get-ADObject`/`-LDAPFilter` instead of `Get-ADUser`/`Get-ADGroup`/`-Filter`, matching the production code fixed earlier today (see main Finding, "RESOLVED 2026-07-01: Get-ADObject called with -Filter instead of -LDAPFilter" in PROJECT-TRACKING.md). `Test-CheckForDuplicateEmails.ps1` already mocked the right cmdlet from that earlier fix; only its `-ParameterFilter`'s `$Filter` reference needed changing to `$LDAPFilter`.

### What actually trying to run them uncovered

Installing Pester 5.8 (this environment previously only had the built-in 3.4.0, which cannot parse this suite's syntax at all) let these tests execute for the first time in the project's history. That immediately surfaced three more, progressively larger problems, each confirmed with the user before proceeding past it:

1. **`build.ps1`'s `$Error` fix (Addendum 1) reproducibly crashed on the exact hook invocation pattern** - already covered.
2. **A `Join-Path` call with 3-4 positional arguments** (`Join-Path $projectRoot "functions" "Public" "File.ps1"`), the same PS-5.1-incompatible pattern already fixed once today in `_Get-Configuration.ps1` and `setup-hooks.ps1`, existed in **13 of 27 test files**' function-import lines. Fixed by chaining `Join-Path` calls, consistent with the existing fix pattern. One file (`Test-SharedMailboxCandidate.ps1`) also pointed at the wrong folder entirely (`functions/Private/Test-SharedMailboxCandidate.ps1` - the function is actually `functions/Public/...`).
3. **`$projectRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)` resolves one directory level too high** (to the parent of the whole repo, not the repo root) in **16 of 27 test files** (the 13 above, plus `Test-WriteLog.ps1`, `Test-GetConfiguration.ps1`, `Test-RetryExchangeOperation.ps1`, which had both bugs at once). Fixed to a single `Split-Path -Parent $PSScriptRoot` call. `Test-WriteLog.ps1` also referenced the pre-rename filename `Write-Log.ps1` instead of `_Write-Log.ps1`.

None of this was previously visible because no compatible Pester version had ever been installed in this environment - `build.ps1 -Validate` only runs PSScriptAnalyzer/formatting checks, never executes the tests themselves.

### Running the full suite for real: 345 tests, 72 passing, 273 failing

With both bugs fixed across all 16 affected files, the whole suite (27 files, 345 `It` blocks) was run for the first time. Result: **72 passed, 273 failed.** Spot-checking the failures shows at least three distinct, unrelated root causes beyond the two already fixed:

- Several production functions call the real `Write-Log` during tests (not mocked in those test files), which attempts to write to `C:\ProgramData\SharedMailboxProvisioner\Audit\...` and fails with Access Denied in this environment - a test-isolation gap, not a path-resolution bug.
- At least one real assertion/mock-shape mismatch (`Get-SharedMailboxACLGroup: ... Parameter name: GroupScope` - "One or more properties are invalid").
- Likely genuine Pester 3-to-5 behavioral differences (this suite's `Should`/`Mock`/`Assert-MockCalled` syntax was written years before anyone could verify it against a working Pester 5 install).

**This was not further triaged or fixed.** Diagnosing and fixing 273 individual test failures across a suite that has never successfully run is a substantial, separate body of work - not a continuation of today's cleanup pass. Recommend treating "get the Pester suite green" as its own tracked initiative (see `PROJECT-TRACKING.md`), now that it's possible to measure progress on it at all for the first time.

---

**Audit conclusion:** Code that *is* checked is largely clean (ASCII output, secrets handling, `Write-Host`/`Invoke-Expression` avoidance, naming/export consistency at the module level). The critical issue is that the checking mechanism itself - the pre-commit gate - is both **not installed** and **would crash if it were**, meaning the project's compliance claims to date have relied entirely on manual discipline rather than the automated enforcement CLAUDE.md and STRUCTURE.md describe. Recommend treating Part 1 as a blocker for the Week 1 "Go" milestone.

---

## Addendum (same day, 2026-07-01): Fixing the crash exposed a deeper gate defect

While fixing Finding 1.2, reproducing the hook's exact invocation pattern (`powershell.exe -NoProfile -Command "& '.\build.ps1' -Validate"`) after the `$Error` rename still produced a suspiciously clean `[OK] Build validation PASSED` with **none** of the expected `=== ... ===` section headers in the output. Investigating this surfaced the real root cause, which pre-dates today's other fixes and was present in every historical "0 violations" run (including the Alpha/Beta compliance audits and this document's own Part 2 figures, which were sourced from a `build.ps1 -Validate` run).

### Root cause: captured function output is always truthy in PowerShell

`build.ps1`'s main execution block called each check as `if (-not (Test-PSScriptAnalyzer)) { $allPassed = $false }` (same pattern for `Test-Indentation`, `Test-Bracing`, `Test-BOM`). Each of those functions calls `Write-Status`/`Write-Output` several times for diagnostics *before* its final `return $true`/`return $false`.

In PowerShell, wrapping a function call in `(...)` (or assigning it to a variable) captures **every** object it wrote to the success stream, not just the final `return` value - the "return value" people usually mean is really just the last element of that captured collection. Two consequences followed from this, both invisibly:

1. All the diagnostic `Write-Output` lines (`=== PSScriptAnalyzer Linting ===`, per-issue detail lines, etc.) were captured into the `(Test-PSScriptAnalyzer)` expression's value and discarded there instead of reaching the console - explaining the "missing" section headers.
2. `-not` on a **non-empty array** is always `$false` in PowerShell, regardless of what the array contains. Since every one of these functions always writes at least one diagnostic line before returning, the captured array was never empty - so `-not (Test-PSScriptAnalyzer)` (and the other three checks) evaluated to `$false` **unconditionally**, and `$allPassed` could never be set to `$false` by any of the four checks. The build validation gate could not fail, no matter what PSScriptAnalyzer, indentation, bracing, or BOM checks actually found.

### Fix applied

Refactored all four `Test-*` functions to report pass/fail via a `$script:LastCheckPassed` variable instead of a `return` value mixed into the diagnostic output stream, and changed the call sites to invoke them as bare statements (so `Write-Output` reaches the console normally) followed by reading `$script:LastCheckPassed`.

### What the gate actually finds, now that it works

Re-running `powershell.exe -NoProfile -Command "& '.\build.ps1' -Validate"` (the hook's exact invocation) after the fix:

- **PSScriptAnalyzer: 20 real issues**, all `Warning` severity, spread across 15 files - mostly `PSReviewUnusedParameter` / `PSUseDeclaredVarsMoreThanAssignments` (unused parameters/variables), plus 3x `PSUseShouldProcessForStateChangingFunctions` (`New-SharedMailboxRemote`, `Set-MailboxProvisioningSchedule`, and one more state-changing function missing `SupportsShouldProcess`), and 3x `PSAvoidUsingPlainTextForPassword` (`-CredentialName`/`-CredentialPath` parameters typed as `String]` - these are file paths, not literal secrets, so likely a rule false-positive rather than a real exposure, but not yet triaged either way).
- **Indentation:** 16 non-blocking WARN-level lines (non-multiple-of-4 spacing) across 6 files; 0 blocking tab-character errors. Check correctly reports `[OK]`, since only tabs are wired to fail it.
- **K&R Bracing:** 0 issues.
- **BOM:** 59/59 files missing UTF-8 BOM (unchanged, still intentionally advisory-only per Finding 1.4's resolution - the whole repo has never carried a BOM, so gating this would block everything unrelated to today's changes).
- **Net result: `build.ps1 -Validate` now correctly exits 1 (FAILED)**, because of the 20 real PSScriptAnalyzer warnings - a state that has apparently existed, undetected, for a while.

### Consequence for hook installation

Installing the pre-commit hook now (Finding 1.1's remaining action item) will immediately and correctly block every commit - including unrelated ones - until those 20 pre-existing PSScriptAnalyzer warnings are resolved or explicitly excluded. This is expected, correct behavior of a now-working gate, but is a **go/no-go decision for the maintainer**, not something to resolve unilaterally: the `ShouldProcess` and plain-text-password findings touch `New-SharedMailboxRemote`/`Set-MailboxProvisioningSchedule`, functions already confirmed working against the live tenant this same day (per `PROJECT-TRACKING.md`) - so fixes there carry real behavioral risk during an active Pre-Release smoke-test week and should not be made casually alongside a tooling fix.

**Decision (2026-07-01, same day):** fix the low-risk findings outright; suppress the risky ones with a documented, targeted exception rather than changing behavior. See Addendum 2.

---

## Addendum 2 (same day, 2026-07-01): Triage of the 20 findings, two more `setup-hooks.ps1` bugs, and hook installation

### Triage of the 20 PSScriptAnalyzer findings

**10 fixed outright (dead code, zero behavior/API change):**
- `_RetryExchangeOperation.ps1`: unused local `$errorType`; unused `-ErrorMessage` param on the private (not externally called) `_IsRetryableError`, plus the caller argument.
- `Connect-ExchangeOnlineEnv.ps1`: unused local `$lastError` (set in catch, never read - the actual error message flows through a separate `$errorMessage` variable).
- `Import-MailboxCandidatesFromCSV.ps1`: unused local `$optionalColumns` (declared, never referenced; optional-column handling happens elsewhere).
- `build.ps1`: removed the `-Fix` switch entirely (declared, referenced only in its own help/usage text, never implemented anywhere - a stub, not shippable per "no half-finished implementations").
- 5x test-file unused local variables (`Test-GetSharedMailboxACLGroup.ps1:230`, `Test-Invoke-MailboxProvisioningRetry.ps1:109,196`, `Test-RetryExchangeOperation.ps1:61`, `Test-Export-MailboxAuditLog.ps1:97`) - changed to `$null =` or removed; all confirmed via grep to be genuinely unused elsewhere in their file (unlike similarly-named variables in the same files that *are* used and were left untouched).

**1 left as a confirmed PSScriptAnalyzer/Pester false positive, suppressed:**
- `Test-Get-MailboxProvisioningStatus.ps1`: `$testBacklogPath` is set in `BeforeAll { }` and consumed in sibling `It { }` blocks (lines 38, 40, 62, 64, confirmed via grep) - a standard Pester idiom that `PSUseDeclaredVarsMoreThanAssignments` cannot see across scriptblock boundaries. Suppressed with `SuppressMessageAttribute` rather than modified, since the variable genuinely is used.

**3 suppressed as real, pre-existing "documented but never implemented" gaps in PUBLIC function behavior** (not touched - implementing them changes behavior, removing them breaks the public API; either needs a deliberate follow-up decision, not a lint-cleanup drive-by):
- `Test-SharedMailboxCandidate -ValidationAttribute`: the function's own `.SYNOPSIS` says it "writes validation result to specified AD attribute" - it never does; no `Set-ADUser`/attribute-write call exists anywhere in the function.
- `Resolve-MailboxProvisioningFailure -DiagnoseAll`: documented switch, never checked in the function body - omitting `-SamAccountName` already analyzes all entries by default, so the switch is currently a permanent no-op regardless of whether it's passed.
- `Invoke-SharedMailboxProvisioning -GenerateReport`: Step 4 ("Generate summary report") runs unconditionally; the flag is never read.

**6 left as-is and suppressed, matching the user's approved "leave separate, use a targeted exception" plan** (all touch production-adjacent logic in functions confirmed working against the live tenant this same day):
- `PSAvoidUsingPlainTextForPassword` x3: `_Get-ServiceAccountCredential -CredentialName` (renamed 2026-07-01, see Finding 2.2), `New-SharedMailboxRemote -CredentialPath`, `_GetExchangePSSession -CredentialPath`. All three are lookup keys/file paths to a `.clixml` file, not literal secret values - likely a rule name-heuristic false positive, but not formally triaged as such, so suppressed with a justification rather than asserted as safe.
- `PSUseShouldProcessForStateChangingFunctions` x3: `_Remove-OldLogs` (renamed 2026-07-01, see Finding 2.2), `New-SharedMailboxRemote`, `Set-MailboxProvisioningSchedule`. Adding `SupportsShouldProcess` is a real, if usually small, behavioral change to call sites - deferred.

All 9 suppressions use `[Diagnostics.CodeAnalysis.SuppressMessageAttribute(...)]` with an inline `Justification` pointing back to this document, so they're greppable (`SuppressMessageAttribute` across `functions/` and `tests/`) and visibly flagged as deliberate, not accidental.

### Two more bugs found while installing the hook

Re-running `.\setup-hooks.ps1` (the last remaining action item) surfaced two further PowerShell-5.1-specific bugs in that script, neither previously listed:

1. **`$PSVersionTable.Platform` doesn't exist before PowerShell 6.** `setup-hooks.ps1` used it unconditionally to decide whether to `chmod +x` the hook file; under `Set-StrictMode -Version Latest` this throws `PropertyNotFoundStrict` and aborts the whole script before the hook is installed. Fixed by short-circuiting on `$PSVersionTable.PSVersion.Major -ge 6` first (verified `-and` does short-circuit in Windows PowerShell, so this is safe).
2. **The generated hook's here-string mis-rendered `$(git rev-parse --show-toplevel)`.** The template used an expandable here-string (`@"..."@`) with `` `$(...) `` intended to produce literal text for bash to evaluate later. In practice PowerShell evaluates `$(...)` subexpressions in an expandable here-string *regardless* of a preceding backtick (confirmed by direct reproduction) - so the hook shipped with the toplevel path already baked in at generation time (as `\S:/Scheduled Tasks/...`, with a stray leading backslash) instead of a live `$(...)` bash substitution. Separately, the multi-line `powershell.exe -NoProfile -Command { ... }` block was emitted unquoted, so bash split it into several unrelated one-line commands instead of passing it as a single argument (reproduced: `=: command not found`, then a PowerShell parser error, then bash trying to interpret `.\build.ps1`'s own `<# ... #>` comment block as bash syntax). Both fixed together by switching to a single-quoted here-string (`@'...'@`, no PowerShell interpolation of any kind) and collapsing the validation call to a single-line, single-quoted `powershell.exe -NoProfile -Command '& ".\build.ps1" -Validate; exit $LASTEXITCODE'`.

### Final verification

- `build.ps1 -Validate` (exact hook invocation pattern): `[OK] Build validation PASSED`, exit 0 - 0 PSScriptAnalyzer issues, 0 blocking indentation/bracing issues, BOM warnings present but correctly advisory-only.
- Pre-commit hook installed at `.git/hooks/pre-commit`, content verified byte-for-byte correct (no stray escaping).
- **Positive test:** ran the installed hook directly on the clean tree - exit 0.
- **Negative test:** added a throwaway test file containing `Write-Host` (a real, intentional violation), ran the hook - correctly caught it (`[ERROR] Found 1 issue(s)`, `PSAvoidUsingWriteHost`), printed `Pre-commit validation failed. Commit blocked.`, exited 1. Throwaway file removed immediately after.

**Status: Part 1's four action items (Findings 1.1-1.4) are now complete and verified working in both directions.** The 6 deliberately-deferred PSScriptAnalyzer findings and 3 deliberately-deferred "documented but unimplemented" parameters remain open, tracked via the `SuppressMessageAttribute` justifications above, pending a maintainer decision on whether to implement, remove, or permanently except each one.
