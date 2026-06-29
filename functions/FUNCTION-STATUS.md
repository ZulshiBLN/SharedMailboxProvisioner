# Function Status – SharedMailboxProvisioner

Tracking of all functions: implementation status, test coverage, usage.

---

## Private Functions (Helpers) – Core Infrastructure

| Function | Status | Tests | ADR | Notes |
|----------|--------|-------|-----|-------|
| `_RetryExchangeOperation` | [COMPLETE] | [YES] | ADR-003 | Retry logic with exponential backoff. Core for all EXO calls. |
| `Write-Log` | [COMPLETE] | [YES] | ADR-004 | Centralized audit & error logging. Used by all operations. |
| `Get-Configuration` | [COMPLETE] | [YES] | ADR-005 | Config loading & validation. Supports JSON + Azure KV. |
| `_ValidateGuid` | [COMPLETE] | [IMPLIED] | ADR-005 | Helper for GUID validation. |
| `_ValidateDomain` | [COMPLETE] | [IMPLIED] | ADR-005 | Helper for domain validation. |
| `Get-ServiceAccountCredential` | [COMPLETE] | [PARTIAL] | ADR-005 | Load creds from KV/Credential Manager/Env. |
| `Remove-OldLogs` | [COMPLETE] | [YES] | ADR-004 | Log rotation (90-day audit, 30-day errors). |

---

## Private Functions (Helpers) – AD Candidate Discovery & Validation

### Group Validation
| Function | Status | Tests | ADR | Notes |
|----------|--------|-------|-----|-------|
| `_ParseSharedMailboxGroupDescription` | [PLANNED] | [NONE] | ADR-006 | Parse ACL group description, extract admin group. |
| `_ValidateSharedMailboxGroup` | [PLANNED] | [NONE] | ADR-006 | Validate group structure (type, mail, description pattern). |
| `Get-SharedMailboxACLGroup` | [PLANNED] | [NONE] | ADR-006 | Lookup & validate ACL group for candidate user. |

### Data Quality Validation (NEW)
| Function | Status | Tests | ADR | Notes |
|----------|--------|-------|-----|-------|
| `_ValidateEmailFormat` | [COMPLETE] | [YES] | ADR-006 | RFC 5321 email format validation. Tier 1 - Text Parsing |
| `_ValidateDisplayName` | [COMPLETE] | [YES] | ADR-006 | DisplayName character validation. Tier 1 - Text Parsing |
| `_ValidateProxyAddresses` | [PLANNED] | [NONE] | ADR-006 | Validate SMTP addresses, check primary, allowed domains. |
| `_ValidateDomainInExchangeOnline` | [PLANNED] | [NONE] | ADR-006 | Check domain against AcceptedDomains list. |
| `_CheckForDuplicateEmails` | [PLANNED] | [NONE] | ADR-006 | Detect duplicate emails in AD ProxyAddresses. |

---

## Public Functions (Cmdlets) – Account Validation

| Function | Status | Tests | ADR | Usage | Notes |
|----------|--------|-------|-----|-------|-------|
| `Validate-SharedMailboxCandidate` | [PLANNED] | [NONE] | ADR-006 | Validate user for provisioning readiness | Uses: All validation helpers, Write-Log |

---

## Public Functions (Cmdlets) – Exchange Online

| Function | Status | Tests | ADR | Usage | Notes |
|----------|--------|-------|-----|-------|-------|
| `New-SharedMailbox` | [PLANNED] | [NONE] | ADR-001 | Create a new shared mailbox | Uses: _RetryExchangeOperation, Write-Log, Get-Configuration |
| `Add-SharedMailboxMember` | [PLANNED] | [NONE] | ADR-001 | Add members to shared mailbox | Uses: _RetryExchangeOperation, Write-Log |
| `Remove-SharedMailboxMember` | [PLANNED] | [NONE] | ADR-001 | Remove members from shared mailbox | Uses: _RetryExchangeOperation, Write-Log |
| `Get-SharedMailbox` | [PLANNED] | [NONE] | ADR-001 | Retrieve shared mailbox(es) | Uses: _RetryExchangeOperation, Connect-ExchangeOnlineEnv |
| `Remove-SharedMailbox` | [PLANNED] | [NONE] | ADR-001 | Delete a shared mailbox | Uses: _RetryExchangeOperation, Write-Log |
| `Grant-SharedMailboxAccess` | [PLANNED] | [NONE] | ADR-001 | Grant delegated access | Uses: _RetryExchangeOperation, Write-Log |

---

## Public Functions (Cmdlets) – Active Directory Candidate Discovery

| Function | Status | Tests | ADR | Usage | Notes |
|----------|--------|-------|-----|-------|-------|
| `Get-SharedMailboxCandidates` | [PLANNED] | [NONE] | ADR-006 | Query AD for eligible candidates | Uses: ActiveDirectory module, Write-Log |
| `Get-SharedMailboxCandidatesWithGroups` | [PLANNED] | [NONE] | ADR-006 | Candidates with validated ACL groups | Uses: Get-SharedMailboxCandidates, Get-SharedMailboxACLGroup |
| `Connect-ExchangeOnlineEnv` | [COMPLETE] | [PARTIAL] | ADR-002 | Establish Exchange Online connection | Wrapper for EXO-V3 module, auto-install |

---

## Scripts (Orchestration)

| Script | Status | Tests | Purpose | Notes |
|--------|--------|-------|---------|-------|
| `Provision-BulkMailboxes.ps1` | [PLANNED] | [NONE] | Bulk provision from CSV | Uses: New-SharedMailbox, Write-Log |
| `Remove-MailboxBatch.ps1` | [PLANNED] | [NONE] | Bulk delete from CSV | Uses: Remove-SharedMailbox, Write-Log |
| `Sync-MailboxMembers.ps1` | [PLANNED] | [NONE] | Sync members from AD group | Uses: Add-SharedMailboxMember, Remove-SharedMailboxMember |
| `Export-MailboxAudit.ps1` | [PLANNED] | [NONE] | Export audit logs | Uses: Write-Log functions |

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
| [YES] | Unit tests present & passing |
| [PARTIAL] | Some tests present |
| [IMPLIED] | Tested indirectly (via dependent functions) |
| [NONE] | No tests yet |

---

## Next Steps (Priority Order)

1. **Implement Public Functions (Core):**
   - [ ] `New-SharedMailbox` – Primary provisioning cmdlet
   - [ ] `Get-SharedMailbox` – Query existing mailboxes
   - [ ] `Add-SharedMailboxMember` – Add access
   - [ ] `Remove-SharedMailbox` – Cleanup

2. **Implement Support Functions:**
   - [ ] `Connect-ExchangeOnline` – Connection wrapper
   - [ ] `Grant-SharedMailboxAccess` – Delegated access
   - [ ] `Remove-SharedMailboxMember` – Revoke access

3. **Implement Scripts (Orchestration):**
   - [ ] `Provision-BulkMailboxes.ps1` – CSV-based bulk provisioning
   - [ ] Export audit logs functionality

4. **Testing & Integration:**
   - [ ] Integration tests (against test tenant)
   - [ ] Error scenario testing (throttling, timeouts)
   - [ ] Bulk operation testing

---

## Test Coverage Summary

```
COMPLETE (with tests):    5/5  (100%) [Helper functions + Tier 1 Validation]
PLANNED (need tests):     7/7  (0%)   [Public functions]
SCRIPTS (need tests):     4/4  (0%)   [Orchestration scripts]
```

Tier 1 (Text Parsing) Complete:
- _ValidateEmailFormat: RFC 5321 validation (16 test cases)
- _ValidateDisplayName: Character validation (19 test cases)

Next Phase: Tier 2+ functions (AD queries, Exchange operations)
