# SharedMailboxProvisioner

PowerShell Automation für Exchange Online SharedMailbox Provisioning & Management.

## Overview

SharedMailboxProvisioner bietet automatisierte Provisioning-Operationen für Exchange Online SharedMailboxes:
- Erstellen & Verwalten von SharedMailboxes
- Delegierte Zugriffe & Berechtigungen
- Batch-Operationen für große Mengen
- Audit-Logging & Compliance

## Quick Start

### Installation

```powershell
# Aus PowerShell Gallery (zukünftig)
Install-Module -Name SharedMailboxProvisioner

# Lokal aus Projekt
Import-Module "C:\Repos\SharedMailboxProvisioner\SharedMailboxProvisioner.psd1"
```

### Usage

```powershell
# Connect to Exchange Online
Connect-ExchangeOnline -Tenant "mytenant.onmicrosoft.com"

# Create a SharedMailbox
New-SharedMailbox -DisplayName "Sales Team" -PrimarySmtpAddress "sales@contoso.com"

# Add members
Add-SharedMailboxMember -Identity "sales@contoso.com" -Members @("user1@contoso.com", "user2@contoso.com")
```

## Documentation

- **[CLAUDE.md](CLAUDE.md)** – Collaboration Rules & Best Practices
- **[DECISIONS.md](DECISIONS.md)** – Architectural Decision Records (ADRs)
- **[STRUCTURE.md](STRUCTURE.md)** – Implementierungs-Regeln & Code-Standards

## Project Status

**Version:** v0.1.0 (Early Development)  
**Status:** Phase Alpha - Tier 1 Complete (2026-06-29)

### Implementation Progress

**Tier 1 - Data Quality Validation (COMPLETE):**
- [x] _ValidateEmailFormat: RFC 5321 email format validation (108 lines, 16 tests)
- [x] _ValidateDisplayName: DisplayName character validation (56 lines, 19 tests)

**Tier 2-6 (PLANNED):**
- [ ] AD Candidate Discovery & ACL Group Validation (10 functions)
- [ ] Exchange Online Provisioning Operations (4 functions)
- [ ] Batch Orchestration Scripts (4 scripts)

**Build Status:** All files pass PSScriptAnalyzer, K&R bracing, and indentation validation.
**Code Compliance:** 100% (STRUCTURE.md + CLAUDE.md + ADR-010)  

## License

MIT License

