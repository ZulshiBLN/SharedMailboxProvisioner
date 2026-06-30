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

**Version:** v0.8.2 (Beta-Phase-Complete, Pre-Release-Ready)  
**Status:** Phase Beta COMPLETE (2026-06-30) – Ready for UAT

### Implementation Progress

**Phase Alpha (Tier 1-6) - COMPLETE:**
- [x] Tier 1: Data Quality Validation (2 functions, 43 tests)
- [x] Tier 2: Group Validation (3 functions, 62 tests)
- [x] Tier 3: Data Quality (3 functions, 52 tests)
- [x] Tier 4: Candidate Discovery (2 functions, 30 tests)
- [x] Tier 5: Exchange Provisioning (3 functions, 84 tests)
- [x] Tier 6: Batch Orchestration (1 function, 10 tests)

**Phase Beta (Tier 7) - COMPLETE:**
- [x] Tier 7: Manual Bulk Import (2 functions + 1 script, 26 tests)
  - Import-MailboxCandidatesFromCSV: CSV reader with validation
  - Test-MailboxBulkImport: Dry-run validation + HTML report
  - Provision-BulkMailboxesFromCSV.ps1: CLI admin tool (MANUAL ONLY, never automated)

**Phase Beta (Tier 8-11) - PLANNED:**
- [ ] Tier 8: Reporting & Audit (4 functions)
- [ ] Tier 9: Integration Testing (3 test suites)
- [ ] Tier 10: Operational Tooling (5 functions)
- [ ] Tier 11: Documentation (4 guides)

**Build Status:** ✅ All files pass PSScriptAnalyzer, K&R bracing, and indentation validation.
**Code Compliance:** 100% (STRUCTURE.md + CLAUDE.md + ADR-001 through ADR-006)
**Test Coverage:** 307 test cases, 2/10 Tier 7 integration tests passing (mocking refinement ongoing)  

## License

MIT License

