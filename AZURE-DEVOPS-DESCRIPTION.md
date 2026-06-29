# Azure DevOps Repository Description

## Project Overview

**SharedMailboxProvisioner** is an internal organizational PowerShell automation toolkit for managing shared mailbox provisioning across Exchange Online and Active Directory environments.

**Organization**: [Your Organization Name]  
**Project**: [Project Name]  
**Repository**: SharedMailboxProvisioner  
**Language**: PowerShell 5.1+  
**Status**: Alpha Phase (Production Ready for Tier 1)

---

## Purpose & Business Value

### Problem Statement
Manual shared mailbox creation in Exchange Online is error-prone and time-consuming. Data quality issues in Active Directory (missing mail attributes, invalid formats, duplicates) cause provisioning failures.

### Solution
Automated discovery of AD candidates → comprehensive data validation → automated Exchange provisioning with full audit trail.

### Business Impact
- **Time Savings**: Reduce mailbox provisioning time from hours to minutes
- **Data Quality**: Automatic validation prevents provisioning of malformed accounts
- **Audit Trail**: Complete logging for compliance and troubleshooting
- **Error Reduction**: Intelligent retry logic handles transient API failures
- **Scalability**: Batch provisioning of hundreds of mailboxes

---

## Technical Architecture

### Three-Phase Release Model

```
develop (Daily integration)
  ↓
prerelease (Testing/Beta v1.x.x-beta.*)
  ↓
main (Stable production v1.x.x)
```

**PowerShell Gallery**: Only stable versions published (v1.x.x)  
**GitHub**: Beta/RC versions available (v1.x.x-beta.*, v1.x.x-rc.*)

### Phase Breakdown

| Phase | Status | Functions | Timeline | Details |
|-------|--------|-----------|----------|---------|
| **Alpha** | IN-PROGRESS | 12 total (2 complete) | 6-7 days | AD discovery + validation |
| **Beta** | PLANNED | 6 functions | 4-5 days | EXO provisioning + sync |
| **Gamma** | PLANNED | 4 scripts | 3-4 days | Bulk orchestration |

### Tier 1 Status (Complete ✓)

**Validation Helpers** - Data quality checks before provisioning:
- `_ValidateEmailFormat.ps1` - RFC 5321 email validation
- `_ValidateDisplayName.ps1` - DisplayName character validation
- **Metrics**: 164 lines, 35 unit tests, 100% compliance

---

## Key Dependencies

### Required Modules
- **ExchangeOnlineManagement** v3.1.0+ (auto-installed)
- **ActiveDirectory** (Windows Server RSAT)
- **Pester** 5.x (for testing)

### Infrastructure
- Azure Key Vault or Credential Manager (for service account credentials)
- Exchange Online tenant with appropriate admin permissions
- Active Directory access (LDAP queries, read-only)

### Code Quality Standards
- **PowerShell Version**: 5.1 (Windows), optional 7.x support
- **Style Guide**: K&R bracing, 4-space indentation (STRUCTURE.md)
- **Validation**: PSScriptAnalyzer, pre-commit hooks
- **Testing**: Pester unit tests (35+ tests)
- **Output**: ASCII-only (no Unicode symbols)

---

## Development Setup

### Prerequisites
1. PowerShell 5.1+
2. Git
3. Active Directory access
4. Exchange Online Global Admin permissions

### Quick Start
```powershell
# Clone repository
git clone <azure-devops-url>
cd SharedMailboxProvisioner

# Setup development environment
.\docs\SETUP.md # Follow 6-step guide

# Run build validation
.\build.ps1 -Validate

# Run unit tests
Invoke-Pester tests/
```

### Branch Strategy

| Branch | Purpose | Merges From | Merges To |
|--------|---------|-------------|-----------|
| `develop` | Daily integration | Feature branches | prerelease (weekly) |
| `prerelease` | Testing/Beta | develop | main (after approval) |
| `main` | Production stable | prerelease | - |

---

## Code Quality Standards

### Compliance Requirements (100% enforced)

✅ **Build Validation** (`.\build.ps1 -Validate`)
- PSScriptAnalyzer linting
- 4-space indentation check
- K&R bracing validation
- BOM check

✅ **Pre-commit Hooks**
- Automatic build validation before commit
- Blocks commits with violations

✅ **Testing**
- Minimum 15 test cases per function
- Valid + invalid + edge case coverage
- All tests must pass before commit

✅ **Documentation**
- Comment-based Help for PUBLIC functions (full)
- Comment-based Help for PRIVATE functions (minimal)
- Architectural decisions in DECISIONS.md
- Implementation rules in STRUCTURE.md

### Security Standards (CLAUDE.md)

❌ **Prohibited**
- Invoke-Expression (security risk)
- Write-Host (not compatible with automation)
- Hardcoded credentials
- Unicode symbols in output

✅ **Required**
- ASCII-only output strings
- Proper error handling (try-catch)
- Write-Log for audit trail
- Configuration via JSON + Azure KV

---

## Release Process

### Version Numbering (Semantic Versioning)

```
MAJOR.MINOR.PATCH
1.0.0
│ │   │
│ │   └─ PATCH (bugfixes): 1.0.0 → 1.0.1
│ └───── MINOR (features): 1.0.0 → 1.1.0
└─────── MAJOR (breaking): 1.x → 2.0.0
```

### Pre-Release Versions
- `v1.0.0-beta.1`, `v1.0.0-beta.2` (Beta testing)
- `v1.0.0-rc.1` (Release candidate)
- `v1.0.0` (Final stable)

### Publication Policy

**PowerShell Gallery**: Only `v1.x.x` (stable) published
**GitHub Releases**: All versions (v1.x.x, v1.x.x-beta.*, v1.x.x-rc.*)

### Release Checklist
- [ ] All tests passing (`Invoke-Pester tests/`)
- [ ] Build validation passing (`.\build.ps1 -Validate`)
- [ ] Version updated in `.psd1` and CLAUDE.md
- [ ] CHANGELOG entries added
- [ ] Code review approved
- [ ] Tag created: `git tag -a v1.0.0 -m "Release: v1.0.0"`
- [ ] Pushed to both remotes (origin + github)

---

## Contacts & Governance

| Role | Contact | Responsibility |
|------|---------|-----------------|
| **Project Owner** | [Name] | Vision, priorities, releases |
| **Tech Lead** | [Name] | Architecture decisions, ADRs |
| **DevOps** | [Name] | CI/CD, GitHub/Azure DevOps setup |
| **QA** | [Name] | Testing strategy, bug verification |

---

## Useful Links

- **[STRUCTURE.md](STRUCTURE.md)** - Code standards & rules (HOW)
- **[DECISIONS.md](DECISIONS.md)** - Architecture decisions & rationale (WHY)
- **[CLAUDE.md](CLAUDE.md)** - Collaboration guidelines & best practices
- **[docs/SETUP.md](docs/SETUP.md)** - Developer setup guide
- **[docs/IMPLEMENTATION-PLAN](docs/IMPLEMENTATION-PLAN-SharedMailboxCandidates.md)** - Detailed implementation plan

---

## Support & Escalation

| Issue Type | Channel | Response Time |
|------------|---------|----------------|
| **Code Review** | Pull Request comments | 24 hours |
| **Bug Report** | Azure DevOps Work Item | 48 hours |
| **Design Question** | Team Sync | Weekly |
| **Production Issue** | Escalation | 2 hours |

---

**Last Updated**: 2026-06-29  
**Maintained By**: Development Team  
**Status**: Active Development
