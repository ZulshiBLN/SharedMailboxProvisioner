# GitHub Repository Description & Profile

## Short Description (max 125 characters for GitHub)
```
PowerShell automation toolkit for Exchange Online shared mailbox provisioning from Active Directory
```

## Full Description (for GitHub About section)

**SharedMailboxProvisioner** is a production-ready PowerShell toolkit for automating shared mailbox provisioning in Exchange Online, integrated with Active Directory candidate discovery and validation.

### Key Features

- **Active Directory Integration**: Discover eligible mailbox candidates via LDAP queries with flexible filtering
- **Data Quality Validation**: Comprehensive validation of AD user data before Exchange provisioning (RFC 5321 email format, ProxyAddresses compliance, etc.)
- **Exchange Online Provisioning**: Automated remote mailbox creation with built-in retry logic and exponential backoff
- **Audit Trail**: Centralized logging with configurable retention policies (90/30 days)
- **Resilience Patterns**: Intelligent retry logic for transient API failures
- **Error Handling**: Comprehensive try-catch with permanent vs. retryable error classification

### Architecture

Three-phase implementation:
- **Phase Alpha**: AD candidate discovery & data quality validation (Tier 1 complete ✓)
- **Phase Beta**: Exchange Online provisioning operations
- **Phase Gamma**: Bulk orchestration & sync operations

### Technology Stack

- **PowerShell 5.1+** with PowerShell 7.x optional support
- **Exchange Online Management v3.1.0+** (EXO-V3 cmdlets)
- **Active Directory PowerShell module**
- **JSON-based configuration** with Azure Key Vault/Credential Manager integration
- **Pester 5.x** for testing

### Installation

```powershell
Install-Module -Name SharedMailboxProvisioner -RequiredVersion 1.0.0
```

### Quick Start

```powershell
# Load module
Import-Module SharedMailboxProvisioner

# Connect to Exchange Online
Connect-ExchangeOnlineEnv -Tenant "yourorgname.onmicrosoft.com"

# Discover candidates
$candidates = Get-SharedMailboxCandidatesWithGroups -CustomAttribute "MailboxType" -CustomAttributeValue "Shared"

# Filter for valid candidates only
$validCandidates = $candidates | Where-Object { $_.ReadyForProvisioning -eq $true }

# Provision mailboxes
Provision-SharedMailboxBatch -Candidates $validCandidates
```

### Documentation

- **[SETUP.md](docs/SETUP.md)**: Complete developer setup guide (prerequisites, config, credential management)
- **[STRUCTURE.md](STRUCTURE.md)**: Implementation rules & code standards
- **[DECISIONS.md](DECISIONS.md)**: Architectural decision records (ADRs)
- **[IMPLEMENTATION-PLAN](docs/IMPLEMENTATION-PLAN-SharedMailboxCandidates.md)**: Detailed phase-by-phase implementation

### Project Status

**Version**: v1.0.0-alpha.1  
**Phase**: Alpha (Tier 1 complete - validation helpers)  
**Code Quality**: 100% PSScriptAnalyzer compliance  
**Test Coverage**: 35+ unit tests

### Contributing

This is an internal organizational tool. For bugs, feature requests, or contributions:
1. Check [DECISIONS.md](DECISIONS.md) for architectural context
2. Follow [STRUCTURE.md](STRUCTURE.md) code standards
3. Run `.\build.ps1 -Validate` before commit
4. Ensure unit tests pass: `Invoke-Pester tests/`

### License

[Your Organization License] - Internal Use Only

### Support

For issues or questions:
- Check [docs/SETUP.md](docs/SETUP.md) troubleshooting section
- Review [DECISIONS.md](DECISIONS.md) for design rationale
- Check git history: `git log --oneline`

---

**Keywords**: PowerShell, Exchange Online, Active Directory, Provisioning, Automation, EXO-V3, M365
