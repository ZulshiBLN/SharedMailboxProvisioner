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
  "TenantId": "12345678-1234-1234-1234-123456789012",
  "OrganizationName": "MyOrg",
  "PrimarySmtpDomain": "myorg.com",
  "DefaultMailboxQuota": "50GB",
  "ComplianceLabels": ["Internal"],
  "DelegatedAdministration": true,
  "LogRetentionDays": 90,
  "MaxRetries": 3,
  "InitialBackoffMs": 100
}
```

**Required fields:**
- `TenantId`: Your Azure AD Tenant ID (GUID format)
- `PrimarySmtpDomain`: Your primary SMTP domain (e.g., contoso.com)

---

## Step 3: Setup Service Account Credentials

Choose ONE method:

### Option A: Windows Credential Manager (Local Development)

```powershell
# Open Credential Manager
Start rundll32.exe keycred.dll,KRShowKeyMgr

# Add new credential:
# - Internet or network address: SharedMailboxProvisioner-ServiceAccount
# - Username: your-service-account@tenant.onmicrosoft.com
# - Password: [your-app-password or token]
```

### Option B: Azure Key Vault (Production)

```powershell
# Prerequisites: Az PowerShell module
Install-Module -Name Az.KeyVault -Force

# Login
Connect-AzAccount

# Set secret
$secret = ConvertTo-SecureString -String "your-app-password" -AsPlainText -Force
Set-AzKeyVaultSecret -VaultName "kv-dev" -Name "SharedMailboxProvisioner-ServiceAccount" -SecretValue $secret
```

### Option C: Environment Variable (Testing Only – Not Recommended)

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
. .\functions\Private\Write-Log.ps1
. .\functions\Private\Get-Configuration.ps1

# Test retry function
$result = _RetryExchangeOperation -ScriptBlock { "Success" } -OperationName "Test"
# Expected: "Success"

# Test configuration loading
$config = Get-Configuration -ConfigPath "config\config.dev.json"
Write-Output "Tenant: $($config.TenantId)"
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

---

## Step 7: Connect to Exchange Online (Testing)

```powershell
# Source the connect function
. .\functions\Public\Connect-ExchangeOnlineEnv.ps1

# Connect interactively
Connect-ExchangeOnlineEnv -Tenant "mytenant.onmicrosoft.com"

# Test connection
Get-Mailbox -Filter "RecipientType -eq 'SharedMailbox'" | Select-Object -First 5
```

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
│   │   ├── Write-Log.ps1
│   │   └── Get-Configuration.ps1
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
├── scripts/                        # Orchestration scripts (future)
│   └── (placeholder)
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
# Check tenant ID format
$config = Get-Configuration -ConfigPath "config\config.dev.json"
$config.TenantId  # Should be GUID format

# Check credential availability
$cred = Get-ServiceAccountCredential -EnvironmentName "dev"
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

**Last Updated:** 2026-06-29  
**PowerShell Version:** 5.1+  
**Exchange Online Module:** ExchangeOnlineManagement 3.1.0+
