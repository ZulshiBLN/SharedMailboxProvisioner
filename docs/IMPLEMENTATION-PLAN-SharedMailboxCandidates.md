# Implementation Plan: Get-SharedMailboxCandidates & ACL Group Validation

Detailed plan for implementing AD candidate selection for SharedMailbox provisioning.

---

## Feature Overview

**Goal:** Read eligible SharedMailbox candidates from Active Directory with defined criteria, validate their associated ACL groups, and prepare for Exchange Online provisioning.

**Scope:** 
- Read AD users matching specific criteria (prefix, disabled, description, custom attribute)
- Validate associated ACL groups (naming, security level, mail, description)
- Extract admin group from ACL group description
- Return consolidated candidate + group info

**Effort Estimate:** 4-5 functions, ~800-1000 lines, 2-3 days implementation

---

## Progress Status

**Phase Alpha: Tier 1-4 Complete (2026-06-29)**
- [x] Tier 1 - Text Parsing (2 functions): _ValidateEmailFormat, _ValidateDisplayName - COMPLETE (43 tests)
- [x] Tier 2 - Group Validation (3 functions): _ParseSharedMailboxGroupDescription, _ValidateSharedMailboxGroup, Get-SharedMailboxACLGroup - COMPLETE (62 tests)
- [x] Tier 3 - Data Quality (3 functions): _ValidateDomainInExchangeOnline, _CheckForDuplicateEmails, Validate-SharedMailboxCandidate - COMPLETE (52 tests)
- [x] Tier 4 - Candidate Discovery (2 functions): Get-SharedMailboxCandidates, Get-SharedMailboxCandidatesWithGroups - COMPLETE (30 tests)
- [ ] Tier 5-6 functions (2 functions): PLANNED

**Timeline:** 10/12 Phase Alpha functions complete. Tier 1-4 represents 83% of planned work. 201 total tests passing.

**Actual Implementation Plan (Revised):**

Phase Alpha has 3 main tiers:
- **Tier 1:** Text parsing & validation (2 functions)
  * _ValidateEmailFormat
  * _ValidateDisplayName

- **Tier 2:** AD group discovery & validation (3 functions)
  * _ParseSharedMailboxGroupDescription
  * _ValidateSharedMailboxGroup
  * Get-SharedMailboxACLGroup (optimized with Get-ADObject)

- **Tier 3:** Data collision detection & candidate orchestration (3 functions)
  * _CheckForDuplicateEmails (detect email collisions)
  * _ValidateDomainInExchangeOnline (EXO domain check)
  * Validate-SharedMailboxCandidate (central validation - combines all checks)

- **Tier 4:** Candidate discovery & group association (2 functions)
  * Get-SharedMailboxCandidates (query AD for smbx_* users)
  * Get-SharedMailboxCandidatesWithGroups (attach ACL groups to candidates)

- **Tier 5:** Provisioning operations (2 functions)
  * New-SharedMailboxRemote (create remote mailbox in EXO)
  * Add-GroupToRemoteMailbox (wire ACL group to mailbox)

- **Tier 6:** Batch orchestration & final assembly (1 function)
  * Invoke-SharedMailboxProvisioning (batch orchestration)

---

## Phase 1: Architecture Decision (ADR-006)

### New ADR Needed: AD Integration & Candidate Selection

**Decision Points:**
1. How to query AD (ActiveDirectory module? Direct LDAP?)
2. Filter strategy (LDAP filter building vs PowerShell filtering)
3. Error handling (strict validation vs warnings)
4. Caching (refresh candidates on every call? or cache?)

**Recommendation:**
- Use `Get-ADUser` from ActiveDirectory module (Windows-native, reliable)
- Build LDAP filter server-side (efficient, scales)
- Strict validation (fail early, clear errors)
- No caching (always fresh data)

---

## Phase 2: Core Functions Architecture

### Function Hierarchy

```
Get-SharedMailboxCandidates (PUBLIC)
  ├─ Reads AD users matching criteria
  ├─ Validates user properties
  └─ Returns: PSCustomObject[] with candidate info

Get-SharedMailboxCandidatesWithGroups (PUBLIC)
  ├─ Calls: Get-SharedMailboxCandidates
  ├─ Calls: Get-SharedMailboxACLGroup (for each candidate)
  ├─ Combines candidate + group info
  └─ Returns: PSCustomObject[] with candidate + group + admin

_ValidateSharedMailboxGroup (PRIVATE)
  ├─ Checks: Universal Security Group type
  ├─ Checks: Mail attribute present
  ├─ Checks: Description pattern
  └─ Returns: $true/$false

_ParseSharedMailboxGroupDescription (PRIVATE)
  ├─ Input: "Permission group for shared mailbox {DN}; {Owner}; {AdminGroup}"
  ├─ Parses: Extracts admin group
  └─ Returns: PSCustomObject with parsed values

Get-SharedMailboxACLGroup (PRIVATE)
  ├─ Derives ACL group name from SamAccountName
  ├─ Retrieves group from AD
  ├─ Validates group structure
  └─ Returns: Group object + parsed metadata
```

---

## Phase 3: Detailed Function Specifications

### Function 1: Get-SharedMailboxCandidates (PUBLIC)

**Purpose:** Query AD for users matching SharedMailbox candidate criteria.

**Parameters:**

```powershell
[Parameter(Mandatory=$false)]
[string]$SamAccountNamePrefix = "smbx_"
  # Default: "smbx_"
  # User filter: SamAccountName -like "$Prefix*"

[Parameter(Mandatory=$false)]
[string]$DescriptionStartsWith = "Shared Mailbox Persona"
  # Default: "Shared Mailbox Persona"
  # User filter: Description -like "$Description*"

[Parameter(Mandatory=$false)]
[string]$CustomAttribute = "nethzTask"
  # Name of custom AD attribute
  # Default: "nethzTask"
  # Maps to: extensionAttribute* in AD

[Parameter(Mandatory=$false)]
[string]$CustomAttributeValue = "Create RemoteMailbox"
  # Value to match in custom attribute
  # CONSTRAINT: If $CustomAttribute is specified AND different from default,
  #             then $CustomAttributeValue MUST also be specified (no defaults allowed)

[Parameter(Mandatory=$false)]
[ValidateSet("Enabled", "Disabled", "Any")]
[string]$AccountStatus = "Disabled"
  # Default: "Disabled"
  # User filter: Enabled -eq $false (or $true, or both)

[Parameter(Mandatory=$false)]
[string]$SearchBase = (Get-ADRootDSE).defaultNamingContext
  # Where to search in AD
  # Default: Entire domain
```

**Validation Logic:**

```
IF $CustomAttribute -ne "nethzTask" THEN
  REQUIRE $CustomAttributeValue is explicitly specified
  IF $CustomAttributeValue not specified THEN
    THROW "When using custom attribute, value must be explicitly defined"
  END IF
END IF
```

**LDAP Filter Construction:**

```
(&
  (sAMAccountName=$SamAccountNamePrefix*)
  (description=$DescriptionStartsWith*)
  ($ExtensionAttribute=$CustomAttributeValue)
  (userAccountControl:1.2.840.113556.1.4.803:=2)  # Disabled flag
)
```

**Returns:**

```powershell
[PSCustomObject]@{
  SamAccountName        = "smbx_12345678"
  DisplayName          = "Shared Mailbox 12345678"
  UserPrincipalName    = "smbx_12345678@domain.com"
  DistinguishedName    = "CN=smbx_12345678,OU=SharedMailboxes,..."
  Description          = "Shared Mailbox Persona - Kerim"
  CustomAttributeValue = "Create RemoteMailbox"
  Enabled              = $false
  Mail                 = $null  # Usually null, will be created in Exchange
  ObjectGUID           = "..."
  Timestamp            = Get-Date
}
```

**Error Handling:**

```
✓ No candidates found          → Return empty array (not error)
✓ Custom attribute not found   → Warn, try all users
✗ Invalid SearchBase           → ERROR
✗ Custom attribute set, value missing → ERROR (parameter validation)
✗ AD connectivity issue        → ERROR with context
```

---

### Function 2: Get-SharedMailboxACLGroup (PRIVATE)

**Purpose:** Find and validate the ACL group for a candidate user.

**Logic:**

```
1. Extract suffix from SamAccountName
   Input:  "smbx_12345678"
   Extract: "12345678"

2. Construct ACL group name
   Pattern: "smbx_acl_{suffix}"
   Result: "smbx_acl_12345678"

3. Find group in AD
   Filter: (sAMAccountName=smbx_acl_12345678) AND (objectClass=group)

4. Validate group structure
   - Is Universal Security Group? (groupType = -2147483640)
   - Has mail attribute? (not empty)
   - Description matches pattern? (starts with "Permission group for shared mailbox")

5. Parse description to extract admin group
   Call: _ParseSharedMailboxGroupDescription

6. Return group object + metadata
```

**Parameters:**

```powershell
[Parameter(Mandatory=$true)]
[Microsoft.ActiveDirectory.Management.ADUser]$User
  # The candidate user object from Get-SharedMailboxCandidates

[Parameter(Mandatory=$false)]
[string]$ACLGroupPrefix = "smbx_acl_"
  # Prefix for ACL groups
  # Full pattern: "{Prefix}{UserSuffix}"
```

**Returns:**

```powershell
[PSCustomObject]@{
  SamAccountName           = "smbx_acl_12345678"
  DisplayName             = "SharedMailbox ACL 12345678"
  Mail                    = "smbx_acl_12345678@domain.com"
  DistinguishedName       = "CN=smbx_acl_12345678,OU=Groups,..."
  GroupType              = "Universal Security Group"
  Description            = "Permission group for shared mailbox shared_mb_user@domain.com; Owner; ZO-Mail-Admins"
  AdminGroup             = "ZO-Mail-Admins"  # Extracted from description
  IsValid                = $true/$false
  ValidationErrors       = @()  # List of validation failures
  ObjectGUID             = "..."
}
```

**Validation Details:**

```
Checks:
  ✓ Group exists?
  ✓ Is Universal Security Group?
  ✓ Has mail attribute?
  ✓ Description starts with "Permission group for shared mailbox"?
  ✓ Can parse admin group from description?

Return:
  IsValid=true   → All checks passed
  IsValid=false  → At least one check failed
  ValidationErrors → Array of failures for logging
```

---

### Function 3: _ParseSharedMailboxGroupDescription (PRIVATE)

**Purpose:** Extract structured info from ACL group description.

**Format:** 
```
"Permission group for shared mailbox {SharedMailboxEmail}; {Owner}; {AdminGroup}"
```

**Examples:**
```
"Permission group for shared mailbox shared_mb_user@ethz.ch; Kerim.Test01; ZO-Mail-Admins"
                                      └─────────────────────┘  └──────────┘  └──────────────┘
                                      SharedMailbox Email       Owner        Admin Group

"Permission group for shared mailbox shared_mb_37739889@ethz.ch; kjabbes; ZO-Mail-Admins"
```

**Parsing Logic:**

```
SPLIT description by "; "
  Part 1: "Permission group for shared mailbox {email}"
    EXTRACT: Email from "Permission group for shared mailbox " onwards
    Pattern: (?<=Permission group for shared mailbox\s)(\S+@\S+)

  Part 2: Owner (second element after split)
  Part 3: AdminGroup (third element after split)

RETURN:
  @{
    SharedMailboxEmail = "shared_mb_user@ethz.ch"
    Owner             = "Kerim.Test01"
    AdminGroup        = "ZO-Mail-Admins"
    IsValid           = $true/$false
    Errors            = @()
  }
```

**Error Handling:**

```
✗ Description doesn't start with pattern    → IsValid=$false
✗ Not enough parts (;) in description        → IsValid=$false
✗ Email extraction fails                     → IsValid=$false
✓ Parts present but may be empty             → Warn, but valid structure
```

---

### Function 4: _ValidateSharedMailboxGroup (PRIVATE)

**Purpose:** Centralized group validation logic.

**Checks:**

```powershell
$checks = @{
  "IsUniversalSecurityGroup" = {
    $_.GroupType -eq -2147483640  # ADS_GROUP_TYPE_UNIVERSAL_SECURITY_GROUP
  }
  
  "HasMailAttribute" = {
    -not [string]::IsNullOrEmpty($_.Mail)
  }
  
  "DescriptionPattern" = {
    $_.Description -like "Permission group for shared mailbox*"
  }
  
  "CanParseDescription" = {
    $parsed = _ParseSharedMailboxGroupDescription -Description $_.Description
    $parsed.IsValid -eq $true
  }
}
```

**Returns:**

```powershell
[PSCustomObject]@{
  IsValid            = $true/$false  # All checks passed?
  PassedChecks       = 3  # Number of passed checks
  FailedChecks       = 1  # Number of failed checks
  ValidationDetails  = @{
    "IsUniversalSecurityGroup" = $true
    "HasMailAttribute"         = $true
    "DescriptionPattern"       = $false
    "CanParseDescription"      = $false
  }
  Errors             = @(
    "Description does not match pattern"
    "Cannot parse admin group from description"
  )
}
```

---

### Function 5: Get-SharedMailboxCandidatesWithGroups (PUBLIC)

**Purpose:** Combine candidate users with their validated ACL groups.

**Logic:**

```
1. Get all candidates
   candidates = Get-SharedMailboxCandidates(...)

2. For each candidate:
   a. Get their ACL group
      group = Get-SharedMailboxACLGroup($candidate)
   
   b. Validate group
      validation = _ValidateSharedMailboxGroup($group)
   
   c. Create consolidated object
      result = Combine(candidate, group, validation)
   
   d. Log results
      Write-Log "Found candidate {name} with group {groupname} - status: {valid}"

3. Return results
   - Candidates with valid groups
   - Candidates with invalid groups (with error details)
   - Candidates with no group (with error)
```

**Returns:**

```powershell
[PSCustomObject]@{
  # From candidate
  SamAccountName        = "smbx_12345678"
  DisplayName          = "Shared Mailbox 12345678"
  UserPrincipalName    = "smbx_12345678@domain.com"
  
  # From ACL group
  ACLGroupName         = "smbx_acl_12345678"
  ACLGroupMail         = "smbx_acl_12345678@domain.com"
  ACLGroupValid        = $true/$false
  ACLGroupErrors       = @()
  
  # Parsed from group description
  AdminGroup           = "ZO-Mail-Admins"
  GroupOwner           = "Kerim.Test01"
  
  # Status
  IsReadyForProvisioning = $true/$false
  Status               = "Ready" | "GroupInvalid" | "GroupNotFound" | "ValidationFailed"
  ReadinessErrors      = @()
  
  Timestamp            = Get-Date
}
```

**Readiness Logic:**

```
IsReadyForProvisioning = true IF:
  ✓ Candidate account is disabled
  ✓ Candidate description matches pattern
  ✓ Candidate custom attribute has correct value
  ✓ ACL group exists
  ✓ ACL group is Universal Security Group
  ✓ ACL group has mail attribute
  ✓ ACL group description valid
  ✓ Can parse admin group from description

Otherwise: IsReadyForProvisioning = false, Status = reason, ReadinessErrors = list
```

---

## Phase 3b: Data Quality Validation Strategy

### New Functions for Account Validation

**Critical Discovery:** AD data quality is poor. Need strict validation before provisioning.

#### Function 6: Validate-SharedMailboxCandidate (REVISED - HIGH PRIORITY)

**Purpose:** Simple pass/fail validation of candidate user object. Write result to AD attribute.

**Validation Logic: ALL-OR-NOTHING**

```
IF ALL checks pass THEN
  Return: $true (Valid)
  Write-Attribute: [SUCCESS] Validation passed {timestamp}
ELSE
  Return: $false (Invalid)
  Write-Attribute: [FAIL] {Reason} {timestamp}
  Log: Error details for audit
END IF
```

**Checks Performed (Failure = Invalid):**

1. ✓ Mail attribute exists (not null/empty)
2. ✓ Mail format valid (RFC 5321)
3. ✓ Mail not duplicated in other users' ProxyAddresses
4. ✓ Mail in accepted Exchange Online domains
5. ✓ ProxyAddresses contains at least 1 SMTP
6. ✓ ProxyAddresses contains M365 address (@ethz.onmicrosoft.com)
7. ✓ ProxyAddresses format valid (RFC 5321)
8. ✓ ProxyAddresses domains in AcceptedDomains
9. ✓ TargetAddress is empty
10. ✓ DisplayName has no invalid chars, not empty
11. ✓ SamAccountName has no invalid chars, not empty

**Returns:**

```powershell
# Valid candidate
[PSCustomObject]@{
  SamAccountName        = "smbx_12345678"
  IsValid               = $true
  ValidationMessage     = "[SUCCESS] Validation passed 2026-06-29 14:23:15"
  AttributeWritten      = $true
}

# Invalid candidate
[PSCustomObject]@{
  SamAccountName        = "smbx_12345678"
  IsValid               = $false
  ValidationMessage     = "[FAIL] Mail attribute missing 2026-06-29 14:23:16"
  FailureReason         = "MailAttributeMissing"  # For categorization
  AttributeWritten      = $true
  LogDetails            = @{
    User                = "smbx_12345678"
    Timestamp           = "2026-06-29 14:23:16"
    FailedCheck         = "Mail attribute exists"
    Details             = "Mail attribute is null or empty"
  }
}
```

**Parameters:**

```powershell
[Parameter(Mandatory=$true)]
[Microsoft.ActiveDirectory.Management.ADUser]$User
  # The candidate user to validate

[Parameter(Mandatory=$false)]
[string]$ValidationAttribute = "nethzTask"
  # AD attribute to write result to
  # Default: "nethzTask"

[Parameter(Mandatory=$false)]
[string[]]$AcceptedDomains = @("ethz.ch", "ethz.onmicrosoft.com")
  # List of valid domains (load from Exchange Online if available)

[Parameter(Mandatory=$false)]
[string]$M365Domain = "@ethz.onmicrosoft.com"
  # Required M365 domain in ProxyAddresses
```

**Workflow Integration:**

```
Get-SharedMailboxCandidatesWithGroups
  │
  ├─→ For each candidate:
  │     ├─ Validate account (Validate-SharedMailboxCandidate)
  │     ├─ Write result to AD attribute (nethzTask)
  │     │   ├ [SUCCESS] → Ready for provisioning
  │     │   └ [FAIL] → Skip, log, continue
  │     ├ Validate group (Get-SharedMailboxACLGroup)
  │     └ Return: Candidate (Valid/Invalid + Reason)
  │
  └─→ Return: Array of candidates
      ├ Valid candidates → Ready for New-RemoteMailbox
      └ Invalid candidates → Logged, skipped
```

**Helper Functions (Private):**

```
_ValidateEmailFormat (Input: string, Output: bool)
  ├─ RFC 5321 validation
  ├─ Basic format: local@domain
  └─ No invalid special characters

_ValidateProxyAddresses (Input: string[], Output: object)
  ├─ Check format of each address
  ├─ Ensure at least 1 SMTP: (primary)
  ├─ Ensure at least 1 SMTP in allowed domains
  └─ Return: ValidationResult

_ValidateDomainInExchangeOnline (Input: string, Output: bool)
  ├─ Check if domain is in AcceptedDomains list
  └─ Return: bool

_CheckForDuplicateEmails (Input: ADUser, All AD Users, Output: bool)
  ├─ Query AD for this email in other user's ProxyAddresses
  ├─ Check own ProxyAddresses for duplicates
  └─ Return: bool (has duplicates?)

_SanitizeDisplayName (Input: string, Output: string)
  ├─ Remove invalid characters: < > @ \ / : ; . , [ ]
  ├─ Trim whitespace
  └─ Return: Cleaned string
```

---

#### Updated Function Hierarchy with Validation (REVISED)

```
Get-SharedMailboxCandidatesWithGroups (Orchestration)
  ├─ Get-SharedMailboxCandidates
  │   └─ Returns: Potential candidates
  │
  ├─ For each candidate:
  │   ├─ Validate-SharedMailboxCandidate
  │   │   ├─ _ValidateEmailFormat (Helper)
  │   │   ├─ _ValidateProxyAddresses (Helper)
  │   │   ├─ _ValidateDomainInExchangeOnline (Helper)
  │   │   ├─ _CheckForDuplicateEmails (Helper)
  │   │   └─ Returns: $true/$false (Valid/Invalid)
  │   │
  │   ├─ Write-SharedMailboxValidationResult (NEW)
  │   │   └─ Writes [SUCCESS]/[FAIL] to AD attribute
  │   │
  │   ├─ Get-SharedMailboxACLGroup (if account valid)
  │   │   └─ Returns: Group validation ($true/$false)
  │   │
  │   └─ Add to results:
  │       ├ Valid candidates (ready for provisioning)
  │       └ Invalid candidates (logged, skipped)
  │
  └─ Return: Array of candidates with status
      ├ ReadyForProvisioning = true (account + group valid)
      ├ ValidationStatus = "Valid" | "InvalidAccount" | "InvalidGroup"
      └ ValidationMessage = from AD attribute
```

**New Helper Function:**

```
_WriteSharedMailboxValidationResult.ps1 (PRIVATE)
  ├─ Input: User, IsValid (bool), FailureReason (string), Timestamp
  ├─ If Valid:
  │   └─ Write: "[SUCCESS] Validation passed {timestamp}"
  ├─ If Invalid:
  │   └─ Write: "[FAIL] {FailureReason} {timestamp}"
  └─ Returns: bool (write successful?)
```

---

## Phase 4: Implementation Order (REVISED)

### Step 1: Create ADR-006
File: `DECISIONS.md` → Add ADR-006
- AD Integration strategy
- Filter approach (server-side LDAP vs PowerShell)
- Error handling philosophy
- Custom attribute mapping

### Step 2: Implement Core Helpers – Group Validation (Private Functions)
1. `_ParseSharedMailboxGroupDescription.ps1`
   - Simplest, no AD calls
   - Regex-heavy, testable in isolation
   - ~80 lines

2. `_ValidateSharedMailboxGroup.ps1`
   - Validation logic
   - Calls _ParseSharedMailboxGroupDescription
   - ~100 lines

3. `Get-SharedMailboxACLGroup.ps1`
   - AD group lookup
   - Calls _ValidateSharedMailboxGroup
   - Error handling for missing groups
   - ~120 lines

### Step 2b: Implement Core Helpers – Account Data Quality Validation (Private Functions)

4. `_ValidateEmailFormat.ps1` (HELPER)
   - RFC 5321 email validation
   - Regex pattern matching
   - ~50 lines

5. `_ValidateProxyAddresses.ps1` (HELPER)
   - Check SMTP address format
   - Ensure primary address present
   - Check allowed domains
   - ~100 lines

6. `_ValidateDomainInExchangeOnline.ps1` (HELPER)
   - Check domain against AcceptedDomains list
   - ~30 lines

7. `_CheckForDuplicateEmails.ps1` (HELPER)
   - Query AD for duplicate emails
   - Check ProxyAddresses collision
   - ~80 lines

8. `_SanitizeDisplayName.ps1` (HELPER)
   - Remove invalid characters
   - Return clean DisplayName
   - ~40 lines

### Step 3: Implement Account Validation & Result Writing (Public/Private)

9. `Validate-SharedMailboxCandidate.ps1` (PUBLIC)
   - Central validation function (Pass/Fail only)
   - Calls all validation helpers
   - Returns: $true/$false + FailureReason
   - ~150 lines (simplified from original)

10. `_WriteSharedMailboxValidationResult.ps1` (PRIVATE)
    - Write validation result to AD attribute
    - Format: [SUCCESS]/[FAIL] {details} {timestamp}
    - Update nethzTask (or custom attribute)
    - ~80 lines

### Step 4: Implement Main Orchestration Functions (Public)

11. `Get-SharedMailboxCandidates.ps1` (PUBLIC)
    - Parameter validation (custom attr logic)
    - LDAP filter building
    - AD user queries
    - ~150 lines

12. `Get-SharedMailboxCandidatesWithGroups.ps1` (PUBLIC - REVISED)
    - Orchestrates: Get Candidates → Validate → Write Result → Get Group
    - For each candidate:
      ├─ Validate account (Validate-SharedMailboxCandidate)
      ├─ Write result to AD (only if validation called)
      ├─ If valid: Validate group (Get-SharedMailboxACLGroup)
      └─ Combine results
    - Continues on validation failure (not blocking)
    - Returns: Array with Valid/Invalid status
    - ~300 lines

### Step 4b: Downstream Provisioning (Phase Beta - New Phase)

13. `New-SharedMailboxRemote.ps1` (PUBLIC)
    - Takes: Validated candidates from Phase Alpha
    - Calls: New-RemoteMailbox in Exchange Online
    - Updates: ValidationAttribute with [SUCCESS] or [FAIL]
    - Logging: Full audit trail via Write-Log
    - Error handling: Log failures, continue to next
    - ~200 lines

14. `Provision-SharedMailboxBatch.ps1` (SCRIPT)
    - Orchestration script for full workflow
    - Step 1: Get-SharedMailboxCandidatesWithGroups
    - Step 2: Filter for valid candidates only
    - Step 3: New-SharedMailboxRemote (batch)
    - Generates: Provisioning report (success/fail counts)
    - ~150 lines

### Step 5: Testing
1. Unit tests for email validation
2. Unit tests for proxy address validation
3. Unit tests for duplicate detection
4. Unit tests for parsing & group validation
5. Integration tests with mock AD objects
6. Real AD environment testing (with real data quality issues)

### Step 6: Documentation
1. Update FUNCTION-STATUS.md
2. Add examples to functions
3. Document AD schema requirements
4. Document AcceptedDomains requirements for Exchange Online
5. Create troubleshooting guide for common validation failures

---

## Phase 3c: Data Quality Validation Testing

### Common DQ Issues to Test

```
# Test Case 1: Missing Mail Attribute
User: DisplayName="Test User", Mail=$null, ProxyAddresses=@()
Expected: IsValid=$false, Error="Mail attribute missing"

# Test Case 2: Duplicate Email
User1: Mail="test@ethz.ch"
User2: Mail=$null, ProxyAddresses=@("SMTP:test@ethz.ch")  # Duplicate!
Expected: IsValid=$false, Error="Email already used by other user"

# Test Case 3: Invalid Email Format
User: Mail="test@invalid domain.ch"  # Space in domain
Expected: IsValid=$false, Error="Mail format invalid: space in domain"

# Test Case 4: Missing M365 Address
User: ProxyAddresses=@("SMTP:test@ethz.ch")  # No @ethz.onmicrosoft.com
Expected: IsValid=$false, Error="Missing Exchange Online address (@ethz.onmicrosoft.com)"

# Test Case 5: TargetAddress Already Set
User: TargetAddress="test@domain.onmicrosoft.com"  # Should be empty!
Expected: IsValid=$false, Error="TargetAddress must be empty"

# Test Case 6: Invalid DisplayName
User: DisplayName="Test <User>"  # Contains < > 
Expected: Warning="DisplayName contains invalid chars", SuggestedFix="Test User"

# Test Case 7: Domain Not in Exchange Online AcceptedDomains
User: ProxyAddresses=@("SMTP:test@invalid-domain.ch")
Expected: IsValid=$false, Error="Domain invalid-domain.ch not in Exchange Online AcceptedDomains"

# Test Case 8: All Valid
User: Mail="test@ethz.ch", ProxyAddresses=@("SMTP:test@ethz.ch", "smtp:test@ethz.onmicrosoft.com")
Expected: IsValid=$true, Status="Valid", SuggestedFixes=$null
```

---

## Phase 5: Testing Strategy (REVISED)

### Unit Tests (No AD Required)

**Test 1: _ValidateEmailFormat**
```powershell
# Valid cases
_ValidateEmailFormat "user@ethz.ch"          # Expected: $true
_ValidateEmailFormat "test.user+tag@ethz.ch" # Expected: $true

# Invalid cases
_ValidateEmailFormat "user@invalid domain.ch" # Expected: $false (space)
_ValidateEmailFormat "invalid.email"          # Expected: $false (no @)
_ValidateEmailFormat "@ethz.ch"               # Expected: $false (no local part)
_ValidateEmailFormat "user@"                  # Expected: $false (no domain)
```

**Test 2: _ParseSharedMailboxGroupDescription**
```powershell
# Test case 1: Valid description
"Permission group for shared mailbox user@ethz.ch; Owner; AdminGroup"
# Expected: IsValid=$true, AdminGroup="AdminGroup"

# Test case 2: Missing parts
"Permission group for shared mailbox user@ethz.ch; Owner"
# Expected: IsValid=$false, Error="Missing admin group"

# Test case 3: Invalid pattern
"Not a valid description"
# Expected: IsValid=$false
```

**Test 2: _ValidateSharedMailboxGroup**
```powershell
# Test case 1: Valid group (all checks pass)
# Expected: IsValid=$true, FailedChecks=0

# Test case 2: Not Universal Security Group
# Expected: IsValid=$false, ValidationDetails.IsUniversalSecurityGroup=$false

# Test case 3: Missing mail
# Expected: IsValid=$false, ValidationDetails.HasMailAttribute=$false
```

### Integration Tests (AD Required, Can Use Mocks)

**Test 3: Get-SharedMailboxCandidates**
```powershell
# Mock: Create 3 AD users matching criteria
# Call: Get-SharedMailboxCandidates
# Expected: Returns 3 candidates

# Test: Wrong prefix
# Expected: Returns 0 candidates

# Test: Parameter validation (custom attr without value)
# Expected: Throws error
```

**Test 4: Get-SharedMailboxACLGroup**
```powershell
# Mock: User with matching ACL group
# Call: Get-SharedMailboxACLGroup
# Expected: Returns group with validation=true

# Mock: User with no matching group
# Call: Get-SharedMailboxACLGroup
# Expected: Returns object with IsValid=$false
```

**Test 5: Get-SharedMailboxCandidatesWithGroups**
```powershell
# Mock: 3 candidates, 2 valid groups, 1 missing
# Call: Get-SharedMailboxCandidatesWithGroups
# Expected:
#   - 2 results with IsReadyForProvisioning=$true
#   - 1 result with IsReadyForProvisioning=$false, Status="GroupNotFound"
```

---

## Phase 6: Error Handling & Edge Cases

### Edge Case 1: Custom Attribute Not Defined in AD
```
Issue: User doesn't have the custom attribute set
Impact: Filter returns no results
Solution: Log warning, suggest checking attribute name/schema
```

### Edge Case 2: Group Name Collision
```
Issue: Multiple groups match "smbx_acl_12345678" (shouldn't happen)
Impact: Ambiguous result
Solution: Return error, require manual investigation
```

### Edge Case 3: Description Parsing Fails
```
Issue: Description format doesn't match expected pattern
Impact: Can't extract admin group
Solution: Mark as invalid, include description in error for manual review
```

### Edge Case 4: Group Exists But Invalid
```
Issue: Group exists, but is not Universal Security Group (e.g., Distribution Group)
Impact: Can't use for FullAccess
Solution: Return error "ACL group type incorrect: {actual} vs expected Universal Security Group"
```

---

## Phase 7: Dependencies & Schema

### Required AD Module
```powershell
Get-Module ActiveDirectory  # Must be available
# Or: Import-Module ActiveDirectory
```

### Custom Attribute Mapping
```
nethzTask → extensionAttribute1 (or similar)
Need to determine which extensionAttribute* is used
Query: Get-ADUser -Filter * -Properties extensionAttribute* | Select -Expand extensionAttribute*
```

### Group Type Values
```
Regular Security Group:      -2147483646
Universal Security Group:    -2147483640
Global Distribution Group:   2
Universal Distribution Group: 8
```

---

## Phase 8: Performance Considerations

### Optimization
```
GET-ADUser Filter Efficiency:
  - Server-side LDAP filtering (best)
  - Not: Get all users then filter in PowerShell

Batch Operations:
  - If candidates > 100, consider pagination
  - Get-ADUser -ResultSetSize 1000 (chunked)

Caching:
  - No caching for MVP (always fresh)
  - Future: Add -CacheTTL parameter if performance issue

Parallelization:
  - Get-SharedMailboxCandidatesWithGroups could use ForEach-Object -Parallel
  - But: AD connection pooling complexity
  - Defer to v1.1 if needed
```

---

## Phase 9: Integration with Core Helpers

### LDAP Filter Building
```powershell
# Use string interpolation carefully
$filter = "(&(sAMAccountName=$SamAccountNamePrefix*))"

# OR use LDAP escaping if values contain special chars
# Call helper: Escape-LDAPString (create if needed)
```

### Error Logging Integration
```powershell
# All errors logged via Write-Log
Write-Log -Message "No candidates found for prefix: $SamAccountNamePrefix" -Level WARN -Operation "Get-SharedMailboxCandidates"

# All candidate info logged
Write-Log -Message "Found candidate: $($candidate.SamAccountName) with group $($group.SamAccountName)" -Level INFO
```

### Configuration Integration
```powershell
# Read AD search base from config?
# Read custom attribute name from config?
# Allow per-organization customization via Get-Configuration
```

---

## Summary Timeline (FINAL - Simplified Validation Model)

### Phase Alpha: Candidate Discovery & Validation

| Phase | Task | Functions | Effort | Days |
|-------|------|-----------|--------|------|
| 1 | ADR-006 | - | 30 min | 0.5 |
| 2 | Group validation helpers | 3x | 2.5 hrs | 0.5 |
| 2b | Data quality helpers | 5x | 3.5 hrs | 0.75 |
| 3 | Central validation (simplified) | 1x | 1.5 hrs | 0.25 |
| 3b | Result writing | 1x | 1 hr | 0.25 |
| 4 | Main orchestration | 2x | 3.5 hrs | 1 |
| 5 | Testing (unit + integration) | - | 4 hrs | 1 |
| 6 | Documentation | - | 1.5 hrs | 0.5 |
| 7 | Real environment testing | - | 2 hrs | 1 |
| **Phase Alpha Total** | **12 functions** | | **20 hours** | **5-6 days** |

### Phase Beta: Downstream Provisioning (Exchange Online)

| Phase | Task | Functions | Effort | Days |
|-------|------|-----------|--------|------|
| 1 | EXO provisioning function | 1x | 3 hrs | 1 |
| 2 | Batch orchestration script | 1x | 2 hrs | 0.5 |
| 3 | Testing (EXO integration) | - | 3 hrs | 1 |
| 4 | Real provisioning test | - | 2 hrs | 1 |
| **Phase Beta Total** | **2 functions** | | **10 hours** | **3-4 days** |

**Overall Project:** 22 functions, 30 hours / 8-10 days

---

## Success Criteria (FINAL - Simplified Model)

### Phase Alpha: Discovery & Validation
✅ Get-SharedMailboxCandidates returns eligible users from AD
✅ Validate-SharedMailboxCandidate returns Pass/$true or Fail/$false (simple)
✅ Validation results written to AD attribute (nethzTask default)
✅ Format: [SUCCESS] Validation passed {timestamp} OR [FAIL] {reason} {timestamp}
✅ Invalid candidates logged but processing continues (not blocking)
✅ Get-SharedMailboxACLGroup validates groups correctly ($true/$false)
✅ Get-SharedMailboxCandidatesWithGroups combines all validations
✅ Returns: Array with ReadyForProvisioning flag (both valid = true)

### Data Quality Validation Checks
✅ All 7 DQ issues caught with simple Pass/Fail:
   - Missing mail attribute → [FAIL] Mail attribute missing
   - Duplicate emails → [FAIL] Email already used
   - Invalid email format → [FAIL] Invalid mail format
   - Invalid DisplayName chars → [FAIL] Invalid DisplayName characters
   - TargetAddress set → [FAIL] TargetAddress must be empty
   - Missing M365 address → [FAIL] Missing Exchange Online address
   - Domain not accepted → [FAIL] Domain not in AcceptedDomains

### Phase Beta: Provisioning
✅ New-SharedMailboxRemote provisions valid candidates in Exchange Online
✅ Uses New-RemoteMailbox with validated account info
✅ Updates AD attribute: [SUCCESS] Mailbox created {timestamp}
✅ Updates AD attribute on failure: [FAIL] {reason} {timestamp}
✅ Provision-SharedMailboxBatch orchestrates full workflow
✅ Batch continues on errors (resilient)
✅ Generates: Summary report (X successful, Y failed)

### Overall Success
✅ Unit tests pass (>90% coverage)
✅ Integration tests pass with mock AD data
✅ Real environment testing (ETHZ AD + Exchange Online)
✅ All validation results in audit trail (AD attribute + logs)
✅ No hard-coded values (all parameterized)
✅ Error handling resilient (continue on fail)
✅ Full workflow: AD discovery → Validation → Provisioning

---

**Status:** Plan Complete (with Data Quality Validation Extension), Ready for Implementation

**Next Steps:**
1. Create ADR-007 (or extend ADR-006) for Data Quality Validation Strategy
2. Implement helpers in order (DQ validation before main functions)
3. Integration tests with real AD data quality issues
4. Real environment testing with ETHZ tenant
