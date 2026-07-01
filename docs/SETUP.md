# Developer Setup Guide – SharedMailboxProvisioner

Getting your development environment ready for SharedMailboxProvisioner.

---

## Prerequisites

- **Windows 10/11 or Windows Server 2016+**
- **PowerShell 5.1+** (Check: `$PSVersionTable.PSVersion`)
- **Git** (Check: `git --version`)
- **Exchange Online Tenant Access** (for testing)

---

## Step 1: Clone Repository

```powershell
git clone <repository-url>
cd SharedMailboxProvisioner
```

---

## Step 2: Create Local Configuration

Copy the template and fill in YOUR tenant details:

```powershell
# Copy template
Copy-Item config\config.template.json -Destination config\config.dev.json

# Edit with your tenant details
notepad config\config.dev.json
```

**Example config.dev.json:**
```json
{
  "Organization": "myorg.onmicrosoft.com",
  "AppId": "12345678-1234-1234-1234-123456789012",
  "CertificateThumbprint": "AB12CD34EF56AB12CD34EF56AB12CD34EF56AB12",
  "DefaultMailboxQuota": "50GB",
  "LogRetentionDays": 90,
  "MaxRetries": 5
}
```

**Fields used for the EXO app connection** (see `Connect-ExchangeOnlineEnv`, or generate this
file via `scripts\Initialize-ProvisioningConnections.ps1`):
- `Organization`: Your tenant's `*.onmicrosoft.com` domain (or TenantId GUID)
- `AppId`: Application (client) ID of the App Registration used for EXO app auth
- `CertificateThumbprint`: Thumbprint of the auth certificate, already installed in the local certificate store

None of these are hard-required by `_Get-Configuration` itself - `Connect-ExchangeOnlineEnv` validates what it actually needs at connect time.

---

## Step 3: Setup Service Account Credentials

There are two independent mechanisms in this codebase. Use **Option A** below
first - it's the mechanism `New-SharedMailboxRemote` actually reads today via
its `-CredentialPath` parameter. Options B-D are an alternate/fallback chain
(`_Get-ServiceAccountCredential`) that other code paths can use instead; choose
ONE of B/C/D if you need that fallback chain.

### Option A: Initialize-ProvisioningConnections.ps1 (clixml, actually used by New-SharedMailboxRemote)

Run this once per environment, as the Service Account, elevated:

```powershell
.\scripts\Initialize-ProvisioningConnections.ps1 -UserName "D\SvcExchangeAdmin" -Environment dev `
    -Organization "myorg.onmicrosoft.com" `
    -AppId "12345678-1234-1234-1234-123456789012" `
    -CertificateThumbprint "AB12CD34EF56AB12CD34EF56AB12CD34EF56AB12"
```

This does two things in one step:
- Prompts for the Service Account password and saves it as an encrypted clixml
  credential file at `config\Credential_{UserName}.clixml` (via `Export-Clixml`,
  DPAPI-encrypted and tied to the running user/account). `New-SharedMailboxRemote`
  reads this file via its `-CredentialPath` parameter as the fallback when the
  current user context cannot establish an on-premises Exchange PSSession.
- Writes `Organization`/`AppId`/`CertificateThumbprint` into
  `config\config.<Environment>.json`, so `Connect-ExchangeOnlineEnv` can resolve
  the EXO app connection without explicit parameters (see Step 7).

Must be run as the target Service Account with elevated privileges. `.gitignore`
excludes `*.clixml`, so the generated credential file never lands in Git.

### Alternate/fallback chain: `_Get-ServiceAccountCredential`

`_Get-ServiceAccountCredential` (in `functions/Private/_Get-Configuration.ps1`)
tries Azure Key Vault, then Windows Credential Manager, then an environment
variable, in that order, and returns whichever it finds first. This is a
separate mechanism from Option A above - use it only if your code path calls
`_Get-ServiceAccountCredential` directly. Choose ONE of the following:

### Option B: Windows Credential Manager (Local Development)

```powershell
# Open Credential Manager
Start rundll32.exe keycred.dll,KRShowKeyMgr

# Add new credential:
# - Internet or network address: SharedMailboxProvisioner-ServiceAccount
# - Username: your-service-account@tenant.onmicrosoft.com
# - Password: [your-app-password or token]
```

### Option C: Azure Key Vault (Production)

```powershell
# Prerequisites: Az PowerShell module
Install-Module -Name Az.KeyVault -Force

# Login
Connect-AzAccount

# Set secret
$secret = ConvertTo-SecureString -String "your-app-password" -AsPlainText -Force
Set-AzKeyVaultSecret -VaultName "kv-dev" -Name "SharedMailboxProvisioner-ServiceAccount" -SecretValue $secret
```

### Option D: Environment Variable (Testing Only – Not Recommended)

```powershell
# Set environment variable (expires with shell)
$env:SHARED_MAILBOX_CRED_dev = "your-app-password"
```

---

## Step 4: Install Pre-Commit Hook

The pre-commit hook automatically validates code before commits (optional but recommended):

```powershell
.\setup-hooks.ps1
```

**What it does:**
- Runs PSScriptAnalyzer linting
- Checks indentation (4 spaces)
- Validates K&R bracing
- Blocks commits with errors
- Can bypass with `git commit --no-verify` (not recommended)

---

## Step 5: Verify Setup

### Test Module Loading

```powershell
# Import module
Import-Module .\SharedMailboxProvisioner.psd1

# Check exports
Get-Module SharedMailboxProvisioner | Select-Object -ExpandProperty ExportedFunctions
```

### Test Build System

```powershell
# Run validation
.\build.ps1 -Validate

# Expected output:
# [OK] All files passed PSScriptAnalyzer checks
# [OK] Build validation PASSED
```

### Test Helper Functions

```powershell
# Source helper functions
. .\functions\Private\_RetryExchangeOperation.ps1
. .\functions\Private\_Write-Log.ps1
. .\functions\Private\_Get-Configuration.ps1

# Test retry function
$result = _RetryExchangeOperation -ScriptBlock { "Success" } -OperationName "Test"
# Expected: "Success"

# Test configuration loading
$config = _Get-Configuration -ConfigPath "config\config.dev.json"
Write-Output "Organization: $($config.Organization)"
```

---

## Step 6: Test Validation Functions

### Tier 1: Email & DisplayName Validation (IMPLEMENTED)

```powershell
# Source validation functions
. .\functions\Private\_ValidateEmailFormat.ps1
. .\functions\Private\_ValidateDisplayName.ps1

# Test email validation (RFC 5321)
_ValidateEmailFormat "user@ethz.ch"           # Returns: $true
_ValidateEmailFormat "invalid email"          # Returns: $false

# Test DisplayName validation
_ValidateDisplayName "Shared Mailbox"         # Returns: $true
_ValidateDisplayName "Shared <Mailbox>"       # Returns: $false (invalid char)

# Run Pester tests
Invoke-Pester tests/Test-ValidateEmailFormat.ps1
Invoke-Pester tests/Test-ValidateDisplayName.ps1
```

**Available Tier 1 Validation Functions:**
- `_ValidateEmailFormat`: RFC 5321 email format validation (local@domain)
- `_ValidateDisplayName`: Exchange Online DisplayName character validation

### Tier 2: Group Validation (IMPLEMENTED)

```powershell
# Source group validation functions
. .\functions\Private\_ParseSharedMailboxGroupDescription.ps1
. .\functions\Private\_ValidateSharedMailboxGroup.ps1
. .\functions\Public\Get-SharedMailboxACLGroup.ps1

# Test group description parsing
$desc = "Permission group for shared mailbox user@ethz.ch; Owner; AdminGroup"
$parsed = _ParseSharedMailboxGroupDescription $desc
# Returns: PSCustomObject with Email, Role, AdminGroup, IsValid

# Test group validation (requires AD group object)
$result = _ValidateSharedMailboxGroup $adGroupObject
# Returns: PSCustomObject with IsValid, ValidationErrors, ParsedMetadata

# Test ACL group lookup - Basic usage
$group = Get-SharedMailboxACLGroup -SamAccountName "smbx_12345678"
if ($group) {
    Write-Output "Found group: $($group.Name)"
    Write-Output "Email: $($group.Mail)"
    Write-Output "Scope: $($group.GroupScope)"
}

# Test ACL group lookup - With SearchBase parameter
$group = Get-SharedMailboxACLGroup -SamAccountName "smbx_12345678" `
    -SearchBase "OU=Groups,DC=ethz,DC=ch"

# Test error handling - Invalid SAM format
$group = Get-SharedMailboxACLGroup -SamAccountName "invalid_name"
# Returns: $null with error logged

# Test error handling - Group not found
$group = Get-SharedMailboxACLGroup -SamAccountName "smbx_nonexistent"
# Returns: $null with warning logged

# Run Pester tests for Tier 2
Invoke-Pester tests/Test-ParseSharedMailboxGroupDescription.ps1
Invoke-Pester tests/Test-ValidateSharedMailboxGroup.ps1
Invoke-Pester tests/Test-GetSharedMailboxACLGroup.ps1
```

**Available Tier 2 Validation Functions:**
- `_ParseSharedMailboxGroupDescription`: Parse ACL group description format
- `_ValidateSharedMailboxGroup`: Validate group structure (type, mail, description)
- `Get-SharedMailboxACLGroup`: Find and validate ACL group for shared mailbox user

**Expected Group Properties:**
```powershell
# Get-SharedMailboxACLGroup returns PSCustomObject with:
PSCustomObject @{
    ADGroup          # Original AD group object
    Name             # Group display name
    SamAccountName   # Group SAM account name
    Mail             # Group email address
    GroupScope       # Group scope (should be "Universal")
    Description      # Group description
    IsValid          # Validation status ($true if all checks pass)
}
```

### Tier 3: Data Quality Validation (IMPLEMENTED)

```powershell
# Source data quality validation functions
. .\functions\Private\_CheckForDuplicateEmails.ps1
. .\functions\Private\_ValidateDomainInExchangeOnline.ps1
. .\functions\Public\Test-SharedMailboxCandidate.ps1

# Test duplicate email detection
$hasDuplicate = _CheckForDuplicateEmails -EmailAddress "user@ethz.ch" -ExcludeUser "smbx_test"
# Returns: $true if email found in other accounts, $false if unique

# Test domain validation in Exchange Online
$isValid = _ValidateDomainInExchangeOnline -Domain "ethz.ch" -AcceptedDomains @("ethz.ch", "ethz.onmicrosoft.com")
# Returns: $true if domain in list, $false if not accepted

# Test comprehensive candidate validation
$validation = Test-SharedMailboxCandidate -ADUser $adUserObject -AcceptedDomains @("ethz.ch")
# Returns: PSCustomObject with IsValid, ValidationErrors, ValidationChecks

# Run Pester tests for Tier 3
Invoke-Pester tests/Test-CheckForDuplicateEmails.ps1
Invoke-Pester tests/Test-ValidateDomainInExchangeOnline.ps1
Invoke-Pester tests/Test-SharedMailboxCandidate.ps1
```

**Available Tier 3 Validation Functions:**
- `_CheckForDuplicateEmails`: Detect duplicate emails in Active Directory
- `_ValidateDomainInExchangeOnline`: Validate domain against Exchange Online AcceptedDomains
- `Test-SharedMailboxCandidate`: Comprehensive validation combining all checks (public function)

### Tier 4: Candidate Discovery (IMPLEMENTED)

```powershell
# Source candidate discovery functions
. .\functions\Public\Get-SharedMailboxCandidates.ps1
. .\functions\Public\Get-SharedMailboxCandidatesWithGroups.ps1

# Example 1: Get all shared mailbox candidates from AD
$candidates = Get-SharedMailboxCandidates
Write-Output "Found $($candidates.Count) candidates"
foreach ($candidate in $candidates) {
    Write-Output "  - $($candidate.SamAccountName): $($candidate.DisplayName)"
}

# Example 2: Get candidates with custom search base (specific OU)
$candidates = Get-SharedMailboxCandidates -SearchBase "OU=SharedMailboxes,DC=ethz,DC=ch"
Write-Output "Found $($candidates.Count) candidates in OU"

# Example 3: Get candidates with custom naming prefix
$candidates = Get-SharedMailboxCandidates -SamAccountNamePrefix "smbx_" -SearchBase "OU=SharedMailboxes,DC=ethz,DC=ch"

# Example 4: Get candidates with custom attribute filtering
$candidates = Get-SharedMailboxCandidates -CustomAttribute "nethzTask" -CustomAttributeValue "Create RemoteMailbox"

# Example 5: Get candidates and filter by account status (enabled vs disabled)
$enabledCandidates = Get-SharedMailboxCandidates -AccountStatus "Enabled"
$disabledCandidates = Get-SharedMailboxCandidates -AccountStatus "Disabled"
$allUsers = Get-SharedMailboxCandidates -AccountStatus "Any"

# Example 6: Get candidates WITH their associated ACL groups (validates groups)
$candidatesWithGroups = Get-SharedMailboxCandidatesWithGroups
foreach ($item in $candidatesWithGroups) {
    Write-Output "Candidate: $($item.SamAccountName)"
    Write-Output "  ACL Group: $($item.ACLGroupName)"
    Write-Output "  Valid: $($item.HasValidGroup)"
    if ($item.HasValidGroup) {
        Write-Output "  Group Email: $($item.ACLGroupMail)"
    }
}

# Example 7: Get candidates but include those without valid groups
$allCandidates = Get-SharedMailboxCandidatesWithGroups -ValidateAll $false
$readyToProvision = $allCandidates | Where-Object { $_.HasValidGroup }
$needsGroupCreation = $allCandidates | Where-Object { -not $_.HasValidGroup }
Write-Output "Ready: $($readyToProvision.Count), Need Groups: $($needsGroupCreation.Count)"

# Run Pester tests for Tier 4
Invoke-Pester tests/Test-GetSharedMailboxCandidates.ps1
Invoke-Pester tests/Test-GetSharedMailboxCandidatesWithGroups.ps1
```

**Available Tier 4 Discovery Functions:**
- `Get-SharedMailboxCandidates`: Query Active Directory for eligible shared mailbox candidates
- `Get-SharedMailboxCandidatesWithGroups`: Get candidates enriched with their associated ACL groups

**Candidate Properties Returned:**
```powershell
# Get-SharedMailboxCandidates returns PSCustomObject array with:
@{
    SamAccountName      # "smbx_12345678"
    DisplayName         # "Shared Mailbox 12345678"
    Mail                # Email address (may be null)
    Description         # "Shared Mailbox Persona - Purpose"
    DistinguishedName   # AD distinguished name
    Enabled             # $true or $false
    ADUser              # Original AD user object
}
```

**Candidate with Groups Properties Returned:**
```powershell
# Get-SharedMailboxCandidatesWithGroups returns PSCustomObject array with:
@{
    SamAccountName      # Candidate SamAccountName
    DisplayName         # Candidate display name
    Mail                # Candidate email
    ACLGroup            # ACL group object (if found)
    ACLGroupName        # ACL group name
    ACLGroupMail        # ACL group email
    HasValidGroup       # $true if group is valid, $false otherwise
    Enabled             # Candidate enabled status
    ADUser              # Original AD user object
}
```

---

## Step 7: Connect to Exchange Online (Testing)

```powershell
# Source the connect function
. .\functions\Public\Connect-ExchangeOnlineEnv.ps1

# Connect interactively (no app auth) - Tenant only
Connect-ExchangeOnlineEnv -Tenant "mytenant.onmicrosoft.com"

# Connect with app-based (certificate) authentication through a corporate proxy
Connect-ExchangeOnlineEnv -Tenant "mytenant.onmicrosoft.com" `
    -AppId "12345678-1234-1234-1234-123456789012" `
    -CertificateThumbprint "AB12CD34EF56AB12CD34EF56AB12CD34EF56AB12" `
    -ProxyUrl "http://proxyserver:8080" `
    -Prefix "ETH"

# Connect with everything resolved from config (no explicit parameters needed)
# once Step 3 Option A / Initialize-ProvisioningConnections.ps1 has been run
Connect-ExchangeOnlineEnv

# Test connection (cmdlets are prefixed per -Prefix, default "ETH")
Get-ETHMailbox -Filter "RecipientType -eq 'SharedMailbox'" | Select-Object -First 5
```

- `-Tenant`/`-AppId`/`-CertificateThumbprint` are all optional and fall back to
  `Organization`/`AppId`/`CertificateThumbprint` in `config.<Environment>.json`
  if omitted (see Step 2). Omitting `-Tenant` entirely requires the config
  fallback to succeed, or the function errors out.
- `-AppId` and `-CertificateThumbprint` are required together for app-based
  (certificate) authentication; without both, the connection falls back to
  interactive auth.
- `-ProxyUrl` is only needed behind a corporate outbound proxy.
- `-Prefix` (default `"ETH"`) prefixes cloud cmdlet nouns so an on-premises
  `Import-PSSession` (unprefixed cmdlets) can stay open in the same window;
  pass `-Prefix ""` for unprefixed cloud cmdlets.

---

## Development Workflow

### Writing New Functions

1. Create function in `functions/Public/` or `functions/Private/`
2. Add comment-based help (PUBLIC functions only)
3. Write unit tests in `tests/Test-*.ps1`
4. Run validation: `.\build.ps1 -Validate`
5. Commit: `git commit -m "Feat: ..."`

### Running Tests

```powershell
# Install Pester if needed
Install-Module -Name Pester -Force

# Run all tests
Invoke-Pester tests/

# Run specific test
Invoke-Pester tests/Test-RetryExchangeOperation.ps1
```

### Code Review Checklist

Before committing:

```
✅ Function has -ErrorAction Stop
✅ Try-Catch wraps Exchange Online calls
✅ Write-Log used for audit events
✅ Comment-based help complete (PUBLIC only)
✅ Parameter validation in place
✅ Verbose messages at key points
✅ No Invoke-Expression or Write-Host
✅ Tests pass: Invoke-Pester tests/
✅ Build passes: .\build.ps1 -Validate
✅ No secrets in code or config
✅ ASCII-only output (no Unicode symbols per ADR-010)
✅ K&R bracing (opening brace on same line, closing on own)
✅ 4-space indentation (never tabs)
```

---

## Directory Structure

```
SharedMailboxProvisioner/
├── config/                          # Configuration (NOT in Git)
│   ├── config.template.json        # Template
│   ├── config.dev.json             # Your development config
│   └── .gitignore                  # config/*.json excluded
│
├── functions/
│   ├── Public/                     # Exported cmdlets
│   │   └── Connect-ExchangeOnlineEnv.ps1
│   │
│   ├── Private/                    # Internal helpers
│   │   ├── _RetryExchangeOperation.ps1
│   │   ├── _Write-Log.ps1
│   │   └── _Get-Configuration.ps1
│   │
│   └── FUNCTION-STATUS.md          # Function tracking
│
├── tests/                          # Unit tests
│   ├── Test-RetryExchangeOperation.ps1
│   ├── Test-WriteLog.ps1
│   ├── Test-GetConfiguration.ps1
│   ├── Test-ValidateEmailFormat.ps1        # RFC 5321 validation tests
│   └── Test-ValidateDisplayName.ps1        # DisplayName validation tests
│
├── scripts/                        # Admin CLI scripts (manual-only, never scheduled)
│   ├── Provision-BulkMailboxesFromCSV.ps1      # Bulk CSV provisioning CLI
│   └── Initialize-ProvisioningConnections.ps1  # One-time credential + EXO config setup
│
├── docs/                           # Documentation
│   └── SETUP.md (this file)
│
├── build.ps1                       # Build & validation
├── setup-hooks.ps1                 # Git hook installer
├── PSScriptAnalyzerSettings.psd1   # Linting rules
├── SharedMailboxProvisioner.psd1   # Module manifest
├── SharedMailboxProvisioner.psm1   # Module root
│
└── CLAUDE.md                       # Collaboration rules
```

---

## Troubleshooting

### Module won't load

```powershell
# Check for parse errors
. .\functions\Private\_RetryExchangeOperation.ps1
# If error: Check line numbers in error message

# Run build validation
.\build.ps1 -Validate
# PSScriptAnalyzer will catch issues
```

### Config file not found

```powershell
# Ensure config file exists
Test-Path config\config.dev.json

# Create from template if missing
Copy-Item config\config.template.json config\config.dev.json
```

### Exchange Online connection fails

```powershell
# Check EXO app connection fields
$config = _Get-Configuration -ConfigPath "config\config.dev.json"
$config.Organization             # Should be your tenant's *.onmicrosoft.com domain
$config.AppId                    # Should be a GUID
$config.CertificateThumbprint    # Should match a cert in Cert:\CurrentUser\My or Cert:\LocalMachine\My

# Check credential availability
$cred = _Get-ServiceAccountCredential -EnvironmentName "dev"
# If null: Setup credentials per Step 3
```

### Pre-commit hook not working

```powershell
# Reinstall hook
.\setup-hooks.ps1

# Test manually
.\build.ps1 -Validate

# Bypass (temporary, not recommended)
git commit --no-verify
```

---

## Next Steps

1. ✅ Complete setup steps 1-6
2. 📖 Read [CLAUDE.md](../CLAUDE.md) for collaboration rules
3. 📖 Read [DECISIONS.md](../DECISIONS.md) for architecture
4. 📖 Read [STRUCTURE.md](../STRUCTURE.md) for code standards
5. 🔨 Start implementing public functions (see [FUNCTION-STATUS.md](../functions/FUNCTION-STATUS.md))

---

## Getting Help

- **Questions about architecture?** → Check DECISIONS.md (ADRs)
- **Code standards?** → Check STRUCTURE.md (implementation rules)
- **Collaboration expectations?** → Check CLAUDE.md
- **Function status?** → Check functions/FUNCTION-STATUS.md

---

**Last Updated:** 2026-07-01  
**PowerShell Version:** 5.1+  
**Exchange Online Module:** ExchangeOnlineManagement 3.1.0+
