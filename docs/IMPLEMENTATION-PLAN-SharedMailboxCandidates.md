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

## Phase 4: Implementation Order

### Step 1: Create ADR-006
File: `DECISIONS.md` → Add ADR-006
- AD Integration strategy
- Filter approach (server-side LDAP vs PowerShell)
- Error handling philosophy
- Custom attribute mapping

### Step 2: Implement Core Helper (Private Functions)
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

### Step 3: Implement Main Function (Public)
1. `Get-SharedMailboxCandidates.ps1`
   - Parameter validation (custom attr logic)
   - LDAP filter building
   - Ad user queries
   - ~150 lines

2. `Get-SharedMailboxCandidatesWithGroups.ps1`
   - Orchestrates all helpers
   - Combines results
   - Logging integration
   - ~200 lines

### Step 4: Testing
1. Unit tests for parsing logic
2. Unit tests for validation
3. Integration tests with mock AD objects
4. Real AD environment testing

### Step 5: Documentation
1. Update FUNCTION-STATUS.md
2. Add examples to functions
3. Document AD schema requirements (custom attribute mapping)

---

## Phase 5: Testing Strategy

### Unit Tests (No AD Required)

**Test 1: _ParseSharedMailboxGroupDescription**
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

## Summary Timeline

| Phase | Task | Effort | Days |
|-------|------|--------|------|
| 1 | Create ADR-006 | 30 min | 0.5 |
| 2 | Implement 3 private helpers | 3 hours | 1 |
| 3 | Implement 2 public functions | 3 hours | 1 |
| 4 | Write tests (unit + integration) | 3 hours | 1 |
| 5 | Documentation & examples | 1 hour | 0.5 |
| 6 | Testing in real environment | 2 hours | 1 |
| **Total** | | **12.5 hours** | **4-5 days** |

---

## Success Criteria

✅ Get-SharedMailboxCandidates returns eligible users
✅ Get-SharedMailboxACLGroup validates groups correctly
✅ Get-SharedMailboxCandidatesWithGroups combines correctly
✅ All edge cases handled (missing groups, invalid format, etc.)
✅ Unit tests pass (>90% coverage)
✅ Integration tests pass with mock data
✅ Documentation complete with examples
✅ No hard-coded values (all parameterized)
✅ Logging integration working
✅ Parameter validation strict (custom attr + value rules)

---

**Status:** Plan Complete, Ready for Implementation
