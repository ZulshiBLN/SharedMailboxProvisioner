# Open Issues – Before Public Functions Implementation

Blockers und Optimierungen, die wir klären müssen, bevor wir mit Public Cmdlets anfangen.

---

## CRITICAL ISSUES (Blockers)

### 1. ❌ PSD1 Manifest – GUID ist nicht literal

**Problem:**
```powershell
GUID = [System.Guid]::NewGuid().ToString()  # ERROR: Method calls not allowed in PSD1
```

**Impact:** Module kann nicht geladen werden
**Fix:** GUID muss literal sein (wird nur einmal bei Projekt-Init generiert)

**Solution:**
```powershell
GUID = '50f777da-b442-4736-a21a-d05fc91849f5'  # Static value
```

---

### 2. ❌ _RetryExchangeOperation.ps1 – Variable Syntax Error

**Problem:**
```powershell
Write-Verbose "[Retry] Attempt $attempt of $MaxRetries: $Operation"
# ERROR: $MaxRetries: wird als Variable "$MaxRetries:" interpretiert
```

**Line:** 40+  
**Impact:** Function kann nicht geladen werden (Parse Error)  
**Fix:** Variable mit `${}` escapen oder String umbauen

**Solution:**
```powershell
Write-Verbose "[Retry] Attempt $attempt of $MaxRetries - $Operation"
# ODER
Write-Verbose "[Retry] Attempt $attempt of ${MaxRetries}: $Operation"
```

---

### 3. ❌ Get-Configuration.ps1 – Function Call Syntax Error

**Problem:**
```powershell
if (-not _ValidateGuid $config.TenantId) {  # ERROR: Missing parentheses
```

**Lines:** 82, 87, etc.  
**Impact:** Function kann nicht geladen werden (Parse Error)  
**Fix:** PowerShell function calls brauchen Klammern

**Solution:**
```powershell
if (-not (_ValidateGuid $config.TenantId)) {  # Add parentheses
# ODER
if (-not (_ValidateGuid -Value $config.TenantId)) {  # Explicit parameter
```

---

### 4. ❌ Private Functions – Export-ModuleMember in Einzeldateien

**Problem:**
```powershell
# In _RetryExchangeOperation.ps1, Write-Log.ps1, Get-Configuration.ps1:
Export-ModuleMember -Function _RetryExchangeOperation  # ERROR: Can only call from module
```

**Impact:** Error wenn Function direkt geladen wird  
**Fix:** `Export-ModuleMember` nur im PSM1 aufrufen, nicht in einzelnen Files

**Solution:** Entfernen Sie alle `Export-ModuleMember` aus Private Functions. PSM1 kümmert sich darum.

---

## HIGH PRIORITY (Needed for Testing)

### 5. 🔧 Connect-ExchangeOnline Wrapper

**Needed for:** Alle Public Functions, die EXO API aufrufen

**Status:** [PLANNED]

**What:**
```powershell
function Connect-ExchangeOnline {
    <#
    .SYNOPSIS
    Establish connection to Exchange Online
    
    .EXAMPLE
    Connect-ExchangeOnline -Tenant "mytenant.onmicrosoft.com"
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$Tenant,
        
        [Parameter(Mandatory=$false)]
        [string]$AppId = ""  # For app-based auth
    )
    
    # Use ExchangeOnlineManagement v3.x module
    # Handle connection pooling (reconnect if timed out)
    # Log connection events
}
```

**Why:** 
- Wrapper für moderne EXO-V3 Module
- Fehlerbehandlung (Timeout, Reconnect)
- Logging (Audit Trail)

---

### 6. 🔧 .gitignore – Environment Setup Docs

**Needed for:** Developers, die Code auschecken und lokal arbeiten

**Status:** [PARTIAL]

**What's missing:**
```markdown
# docs/SETUP.md – Developer Setup Guide

1. Clone repository
2. Create environment config: `config/config.dev.json`
   - Copy from config/config.template.json
   - Fill in your tenant details
3. Setup credentials:
   - Windows: Credential Manager (search "Manage Credentials")
   - Or: Azure Key Vault for prod
4. Run: `.\setup-hooks.ps1` (enables pre-commit validation)
5. Import module: `Import-Module .\SharedMailboxProvisioner.psd1`
```

---

### 7. 🔧 Exchange Online Module Dependency

**Needed for:** Public Functions, Tests

**Status:** [MISSING]

**What:**
- PSD1 Manifest sollte `ExchangeOnlineManagement` (>= 3.1.0) als Required Module deklarieren
- Test-Setup sollte Module auto-installieren

**Solution – PSD1:**
```powershell
RequiredModules = @(
    @{ ModuleName = 'ExchangeOnlineManagement'; ModuleVersion = '3.1.0' }
)
```

**Solution – Tests:**
```powershell
# In Test-*.ps1 files:
if (-not (Get-Module ExchangeOnlineManagement)) {
    Install-Module -Name ExchangeOnlineManagement -Force -Scope CurrentUser
}
```

---

## MEDIUM PRIORITY (Cleanup & Best Practices)

### 8. 🧹 FUNCTION-STATUS.md – Consistency

**Status:** Created, but needs refinement

**What:**
- Track test coverage per function
- Link Functions → ADRs
- Dependency mapping (which functions depend on which)

**Example:**
```
New-SharedMailbox
  ├─ Depends: _RetryExchangeOperation, Write-Log, Get-Configuration
  ├─ Tests: Test-NewSharedMailbox.ps1
  └─ ADR: ADR-001, ADR-003, ADR-004
```

---

### 9. 🧹 Code Review Checklist

**Needed for:** Before committing Public Functions

**What:**
```
✅ Function has -ErrorAction Stop
✅ Try-Catch wraps _RetryExchangeOperation calls
✅ Write-Log called for audit events
✅ Comment-based Help complete (PUBLIC only)
✅ Parameter validation (email format, SMTP domain, etc.)
✅ Verbose messages at key points
✅ No Invoke-Expression or Write-Host
✅ Tests pass: Invoke-Pester tests/Test-*.ps1
✅ Build passes: .\build.ps1 -Validate
```

---

### 10. 🧹 Error Scenarios – Test Matrix

**Needed for:** Robust Public Functions

**What:** Test these error scenarios:
```
Throttling (429)         → Retry 3x, then fail
Timeout (30s)            → Retry, exponential backoff
Unauthorized (403)       → Fail immediately, clear error
Invalid Input (400)      → Fail immediately
Object Not Found (404)   → Fail immediately
Service Degradation      → Retry with backoff
Network interruption     → Retry
```

**Status:** _RetryExchangeOperation handles classification, but need integration tests

---

## SUMMARY – What to Fix Before Starting Public Functions

### BLOCKING (Must fix):
1. ✅ **PSD1 Manifest** – Make GUID literal (5 min)
2. ✅ **_RetryExchangeOperation.ps1** – Fix string syntax (5 min)
3. ✅ **Get-Configuration.ps1** – Fix function calls (5 min)
4. ✅ **Remove Export-ModuleMember** from Private Files (2 min)

### IMPORTANT (Should add):
5. 🔧 **Connect-ExchangeOnline** wrapper (30 min)
6. 🔧 **SETUP.md** developer guide (20 min)
7. 🔧 **RequiredModules** in PSD1 (5 min)
8. 🔧 **Test install logic** for ExchangeOnlineManagement (10 min)

### NICE-TO-HAVE (Polish):
9. 🧹 Refine FUNCTION-STATUS.md
10. 🧹 Create code review checklist
11. 🧹 Document error scenarios

---

## Recommended Order

1. **TODAY:** Fix critical blockers (1-4) – 20 min
2. **TODAY:** Add important setup (5-8) – 65 min
3. **THEN:** Start implementing Public Functions (`New-SharedMailbox`, etc.)
4. **LATER:** Polish & documentation (9-11)

