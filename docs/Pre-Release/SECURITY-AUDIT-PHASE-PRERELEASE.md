# SharedMailboxProvisioner - Pre-Release Phase Security Audit

**Date:** 2026-07-01
**Project:** SharedMailboxProvisioner
**Phase:** Pre-Release (v0.9.0-beta.1), Week 1 Day 1
**Scope:** Pending changes on `develop` (14 local commits ahead of `origin/develop`) - the 2026-07-01 EXO/on-prem connection rework (cert-store auth, `-ProxyUrl`, `-Prefix`, config-driven `Organization`/`AppId`/`CertificateThumbprint`), `scripts/Initialize-ProvisioningConnections.ps1`, and the `Get-ADObject -Filter` -> `-LDAPFilter` fix in `Get-SharedMailboxCandidates.ps1` / `Get-SharedMailboxACLGroup.ps1` / `_CheckForDuplicateEmails.ps1`. Not a full-repo security audit - see `COMPLIANCE-AUDIT-PHASE-PRERELEASE.md` for the general compliance/build-gate audit.
**Method:** Two-phase agent-assisted review - (1) broad vulnerability identification against the diff and full source of the touched functions, (2) independent per-finding re-verification against actual call chains and reachability, each scored 1-10 confidence. Findings below 8/10 were filtered as not exploitable in practice.

---

## Executive Summary

**No HIGH or MEDIUM confidence vulnerabilities found.** 9 candidate issues were identified in the first pass - primarily around the `-LDAPFilter` fix reactivating previously-dormant raw-string LDAP filter construction, plus an identity-check bypass and some config/error-handling concerns. Every candidate was independently re-verified by reading the actual call chains; all scored 1-3 out of 10 after verification, because in every case the only realistic path to the affected code carries trusted operator/admin/scheduled-task input or values already constrained by AD's own attribute syntax - never lower-trust external input (CSV/web/ticket-system data does not reach any of these sinks, and one candidate path is dead code today).

| # | Area | Category | Verified confidence | Verdict |
|---|---|---|---|---|
| 1 | `Get-SharedMailboxCandidates.ps1` (`SamAccountNamePrefix`, `DescriptionStartsWith`, `CustomAttributeValue`) | LDAP injection | 2/10 | Not exploitable - only trusted operator/scheduled-task CLI input reaches it |
| 2 | `Get-SharedMailboxACLGroup.ps1` (`SamAccountName` suffix) | LDAP injection | 2/10 | Not exploitable - AD-sourced or admin-typed only |
| 3 | `_CheckForDuplicateEmails.ps1` (`EmailAddress`) | LDAP injection | 3/10 | Not exploitable - AD-sourced `mail` attribute; CSV path is dead code (function-name/signature mismatch) |
| 4 | `scripts/Initialize-ProvisioningConnections.ps1` identity check | Auth bypass | 2/10 | Substring check bypassable, but gates nothing beyond what local Admin already has |
| 5 | `Connect-ExchangeOnlineEnv.ps1` cert-thumbprint handling | Crypto/cert validation | 2/10 | Inherent to `Connect-ExchangeOnline`'s supported auth model; not weakened by this PR |
| 6 | `Connect-ExchangeOnlineEnv.ps1` / `_Get-Configuration.ps1` `-ConfigPath`/`-Environment` | Path traversal | 2/10 | Technically unsanitized, but only ever trusted operator-typed CLI input in this codebase |
| 7 | `New-SharedMailboxRemote.ps1` PSSession fallback error surfacing | Data exposure | 2/10 | WinRM/topology text only, no secret material; matches `_Write-Log`'s no-sensitive-data contract |
| 8 | `Initialize-ProvisioningConnections.ps1` credential file ACLs | Crypto/secrets | 1/10 | DPAPI (`Export-Clixml`) protects confidentiality independent of file ACLs |
| 9 | `Initialize-ProvisioningConnections.ps1` config overwrite (`Set-Content -Force`) | Data integrity | 1/10 | Self-inflicted operational risk by an already-trusted admin; not a privilege/access issue |

---

## Part 1: LDAP Injection - the `-Filter` -> `-LDAPFilter` fix

**Context:** Commit `eb7627f` (2026-07-01) fixed `Get-SharedMailboxCandidates`, `Get-SharedMailboxACLGroup`, and `_CheckForDuplicateEmails`, all of which build a raw LDAP filter string and previously passed it to `Get-ADObject -Filter` (which expects PowerShell expression syntax, not raw LDAP - so the calls errored or silently no-opped against real AD). The fix switches all three to `-LDAPFilter`, which does accept the raw string as written - meaning any unsanitized value concatenated into that string is now live against real AD, where it previously was not.

### Finding 1.1 - `Get-SharedMailboxCandidates.ps1` (lines ~83-127)

`$SamAccountNamePrefix`, `$DescriptionStartsWith`, `$CustomAttributeValue`, and the custom-attribute-mapped `$CustomAttribute` are concatenated into the LDAP filter with no escaping of LDAP metacharacters (`( ) * \`), then passed to `Get-ADObject -LDAPFilter`. These are genuine public cmdlet parameters (not hardcoded), and pass through unmodified via `Get-SharedMailboxCandidatesWithGroups` -> `Invoke-SharedMailboxProvisioning` (the module's scheduled-task entry point), with no sanitization anywhere in the chain.

**Why not exploitable in practice:** Every real invocation of this cmdlet found in the repo (`docs/SETUP.md`, `docs/Pre-Release/MANUAL-TESTING-PLAN.md`) uses hardcoded literal values (e.g. `-SamAccountNamePrefix "smbx_"`, `-CustomAttribute "nethzTask" -CustomAttributeValue "Create RemoteMailbox"`) typed by a trusted operator or baked into a scheduled task. No web form, ticket system, or CSV import feeds these specific parameters - the separate CSV bulk-import tool (`Import-MailboxCandidatesFromCSV.ps1`) validates already-resolved `Get-ADUser` objects and never calls `Get-SharedMailboxCandidates` or builds an LDAP filter from CSV data. Per the trusted-CLI-input precedent, the only "attacker" able to supply a malicious value is the same trusted actor who invokes or schedules the command - no privilege boundary is crossed.

**Confidence: 2/10.**

### Finding 1.2 - `Get-SharedMailboxACLGroup.ps1` (lines ~46-78)

`$SamAccountName` is checked only for a `"smbx_"` prefix; the suffix is interpolated unescaped into `"(&(sAMAccountName=$expectedGroupName)(objectClass=group))"`.

**Why not exploitable in practice:** The sole production caller (`Get-SharedMailboxCandidatesWithGroups`) supplies `$candidate.SamAccountName`, itself sourced from a live `Get-ADObject` query result - i.e. a real, already-existing AD attribute value, which AD's own `sAMAccountName` syntax rules prevent from containing LDAP metacharacters. The only other way to reach this parameter with a hand-crafted string is direct invocation by a trusted operator typing PowerShell parameters - same trust tier as a CLI flag.

**Confidence: 2/10.**

### Finding 1.3 - `_CheckForDuplicateEmails.ps1` (line ~40)

`$EmailAddress` is interpolated unescaped into `"(|(mail=$EmailAddress)(proxyAddresses=*$EmailAddress*))"`, with only an empty/whitespace guard beforehand.

**Why not exploitable in practice:** The AD-sourced call path (`Test-SharedMailboxCandidate.ps1` passing `$ADUser.mail`) relies on the AD `mail` attribute being populated by an authoritative sync process, not directly by external/anonymous input. The only path where genuinely lower-trust free-text (CSV row data) could reach this filter is doubly broken today: `Import-MailboxCandidatesFromCSV.ps1` calls a private function name (`_ConvertTo-MailboxCandidateObject`) that does not exist anywhere in the codebase (the real function is `_BuildMailboxCandidateObject`), and even past that, its subsequent call to `Test-SharedMailboxCandidate` uses parameter names that don't match that function's actual signature. Both mismatches are caught by a per-row try/catch and silently recorded as row failures - this path cannot currently execute successfully for any CSV row. Tracked separately as a functional defect (not a security fix) in `PROJECT-TRACKING.md`.

**Confidence: 3/10.**

**Recommendation (all of Part 1, defense-in-depth, not blocking):** Escape LDAP special characters (`( ) * \ NUL`) in any value interpolated into a raw `-LDAPFilter` string before use, regardless of current reachability - this hardens the code against future callers (e.g. if these functions are ever exposed via a less-trusted entry point such as a web form or ticket-system integration) at negligible cost.

---

## Part 2: Authorization - `Initialize-ProvisioningConnections.ps1` identity check

### Finding 2.1 - Username check is a bypassable substring match (lines ~87-101)

The "must run as the on-prem Service Account" check uses `$currentUser -notlike "*$UserName*"` - a substring match, not an exact comparison - against a `-UserName` value the caller supplies with no allow-listing. A caller can pass `-UserName "$env:USERDOMAIN\$env:USERNAME"` to trivially satisfy the check regardless of actual identity.

**Why not exploitable in practice:** A separate, correctly-implemented `IsAdmin`/elevation check unconditionally gates the same code path - so reaching the credential-file/config write in the first place already requires local Administrator rights. The credential file itself is `Export-Clixml`-protected via DPAPI, decryptable only by the same Windows user/machine context at the time it's later read - so the real "was this really the Service Account" enforcement happens at decrypt-time via DPAPI, not at creation-time via this string check. No downstream code trusts "created by a verified Service Account" as an authorization signal. Bypassing this check grants an already-local-Administrator caller nothing they didn't already have (they could write to `config\` directly without running this script at all).

**Confidence: 2/10.**

**Recommendation (non-blocking):** Replace the substring match with an exact comparison (`$currentUser -ne $UserName`, case-insensitive) as a correctness/clarity improvement, even though it's not a live privilege-escalation path today.

---

## Part 3: Certificate Auth & Config Path Handling

### Finding 3.1 - No certificate pinning/expiry check on `CertificateThumbprint`

`CertificateThumbprint` (parameter or config-resolved) is passed straight to `Connect-ExchangeOnline -CertificateThumbprint` with no pinning against an expected value and no expiry check.

**Why not exploitable in practice:** This is exactly how `Connect-ExchangeOnline`'s own supported certificate-auth model works (thumbprint-based selection against the local cert store) - this PR did not weaken any prior integrity check (there is no evidence the earlier file+password design had pinning either). Exploiting this would require an attacker to already have write access to `config\config.<Environment>.json` or the ability to install a rogue cert into the machine's cert store - at which point they already hold local, high-trust access.

**Confidence: 2/10.**

### Finding 3.2 - `-ConfigPath`/`-Environment` interpolated unsanitized into a file path

`_Get-Configuration.ps1` builds `"config.$Environment.json"` via string interpolation with no character restriction; `-ConfigPath` is accepted as-is. A value like `-Environment "../../../../temp/evil"` would technically traverse outside `config\`.

**Why not exploitable in practice:** Per `docs/Pre-Release/MANUAL-TESTING-PLAN.md` and the scripts' own documentation, `-Environment` is always an admin-typed literal (`prod`, `dev`, `staging`) entered by an elevated, identity-checked operator - no web input, unprivileged API, or queued/external message reaches this parameter anywhere in the codebase.

**Confidence: 2/10.**

**Recommendation (defense-in-depth, non-blocking):** Constrain `-Environment` to a small known set (e.g. `ValidateSet('dev','staging','prod')`) to eliminate the traversal shape entirely at near-zero cost, independent of current reachability.

---

## Part 4: Error Disclosure & Credential Handling

### Finding 4.1 - `New-SharedMailboxRemote.ps1` now surfaces the PSSession fallback error (commit `6cc999b`)

`_GetExchangePSSession`'s current-user-context connection attempt no longer silently swallows its error before falling back to the credential file; `$_.Exception.Message` is now written via `Write-Verbose` (off by default, not persisted) and `Write-Error` (console only in this path - the persisted `Write-Log` call in the outer function logs a separate, generic message).

**Why not a vulnerability:** WinRM/`New-PSSession` exception text reports connectivity/auth-negotiation failures (hostnames, "Access is denied"-style text), not credential material - PSRemoting does not echo secrets into exception messages by design. `_Write-Log`'s own contract is to never log sensitive data, and nothing in this change contradicts that. This is topology/error-text disclosure, which is explicitly out of scope (logging non-secret data is not a vulnerability).

**Confidence: 2/10.**

### Finding 4.2 - Credential file (`config/Credential_{UserName}.clixml`) has no explicit ACL hardening

`Initialize-ProvisioningConnections.ps1` writes the credential via `Export-Clixml` without additionally restricting NTFS ACLs on the resulting file, alongside the shareable `config.template.json` in the same directory.

**Why not a vulnerability:** `Export-Clixml`'s `SecureString` field is DPAPI-protected to the current user+machine; decrypting it requires an interactive logon as that specific account on that specific machine, regardless of file-read access. Weak file ACLs on an already-DPAPI-encrypted blob do not defeat its confidentiality.

**Confidence: 1/10.**

### Finding 4.3 - `Initialize-ProvisioningConnections.ps1` overwrites `config.<Environment>.json` without backup

`ConvertTo-Json | Set-Content -Force` silently replaces the existing config file.

**Why not a vulnerability:** This script is a manual, one-time admin tool (per its own `.NOTES`), reachable only after the identity+elevation checks in Finding 2.1 pass. No unauthorized party gains access; at worst an already-trusted admin clobbers their own config via a typo - an operational-safety concern, not a security one.

**Confidence: 1/10.**

---

## Conclusion

No findings met the reporting threshold (confidence >= 8/10; highest scored was 3/10). The recommendations under Parts 1 and 3 (LDAP-escaping and `-Environment` allow-listing) are optional defense-in-depth hardening, not required fixes - they cost little and would remove entire vulnerability classes if these functions are ever exposed to a lower-trust caller in the future (e.g. a web UI or ticket-system integration), but nothing in the current codebase makes them exploitable today.

This audit covers the 2026-07-01 connection-setup rework and the `-LDAPFilter` fix only. It does not replace a full-repo review - see `COMPLIANCE-AUDIT-PHASE-PRERELEASE.md` for build-gate integrity, documentation, and test-coverage compliance findings from the same day.
