# SharedMailboxProvisioner

PowerShell Automation für Exchange Online SharedMailbox Provisioning & Management.

**Status:** 🔄 Pre-Release Phase Active (v0.9.0-beta.1)  
**Timeline:** July 1 - July 21, 2026 (Real-world testing & validation)  
**Next:** v0.9.0 release (Week 3), then v1.0.0 launch prep

---

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

# Lokal aus Projekt (nachdem das Repo geklont und der Ordner betreten wurde)
Import-Module .\SharedMailboxProvisioner.psd1
```

### Usage

```powershell
# Connect to Exchange Online (Tenant/AppId/CertificateThumbprint from config.<Environment>.json if omitted)
Connect-ExchangeOnlineEnv -Tenant "mytenant.onmicrosoft.com"

# Discover shared mailbox candidates in Active Directory
$candidates = Get-SharedMailboxCandidates

# Run the full provisioning pipeline: create remote mailboxes + assign permissions
Invoke-SharedMailboxProvisioning
```

## Documentation

- **[CLAUDE.md](CLAUDE.md)** – Collaboration Rules & Best Practices
- **[DECISIONS.md](DECISIONS.md)** – Architectural Decision Records (ADRs)
- **[STRUCTURE.md](STRUCTURE.md)** – Implementierungs-Regeln & Code-Standards

## Project Status

**Version:** v0.9.0-beta.1 (Pre-Release Phase Active)  
**Status:** Pre-Release Phase, Week 1 of 3 – Staging deployment & real-world validation underway

### Implementation Progress

**Phase Alpha (Tier 1-6) - COMPLETE:**
- [x] Tier 1: Data Quality Validation
- [x] Tier 2: Group Validation
- [x] Tier 3: Data Quality
- [x] Tier 4: Candidate Discovery
- [x] Tier 5: Exchange Provisioning
- [x] Tier 6: Batch Orchestration

**Phase Beta (Tier 7-8, 10-11) - COMPLETE:**
- [x] Tier 7: Manual Bulk Import (2 functions + 1 script)
  - Import-MailboxCandidatesFromCSV: CSV reader with validation
  - Test-MailboxBulkImport: Dry-run validation + HTML report
  - Provision-BulkMailboxesFromCSV.ps1: CLI admin tool (MANUAL ONLY, never automated)
- [x] Tier 8: Reporting & Audit (4 functions)
- [x] Tier 10: Operational Tooling (5 functions)
- [x] Tier 11: Documentation

Tier 9 (Integration Testing) was explicitly removed as not applicable to this environment - see `PROJECT-TRACKING.md`.

**Build Status:** Build validation passed (0 PSScriptAnalyzer violations, 2026-07-01).
**Total Functions:** 18 Public + 11 Private.
**Test Coverage:** 345 test cases across 27 test files; 72/345 (21%) passing under Pester 5.x (first real run 2026-07-01) - see `PROJECT-TRACKING.md` for details and known gaps.

## License

MIT License

