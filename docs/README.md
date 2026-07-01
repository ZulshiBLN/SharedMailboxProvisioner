# SharedMailboxProvisioner Documentation

**Version:** v0.9.0-beta.1 | **Status:** Pre-Release Phase  
**Last Updated:** 2026-07-01

---

## Documentation Index

### For Users: Getting Started

**→ [USER-GUIDE.md](USER-GUIDE.md)** (~40 pages)

Start here! Covers:
- Installation & setup
- First-time provisioning
- Common workflows
- Manual bulk import (CSV)
- Monitoring & status checks
- Troubleshooting common issues
- FAQ

**Best for:**
- New users learning the system
- Manual bulk import scenarios
- Operational staff
- First-time setup

---

### For Administrators: Deployment & Configuration

**→ [ADMIN-GUIDE.md](ADMIN-GUIDE.md)** (~40 pages)

Technical deep-dive covering:
- Architecture overview
- Installation & deployment
- Configuration management
- Performance tuning
- Monitoring & alerting
- Disaster recovery
- Security considerations

**Best for:**
- System administrators
- Infrastructure teams
- Deployment planning
- Performance optimization
- Security reviews

---

### For Operations: Daily Management

**→ [OPERATIONS-RUNBOOK.md](OPERATIONS-RUNBOOK.md)** (~30 pages)

Day-to-day operational procedures:
- Morning/daily health checks
- Incident response playbooks
- Failure handling & recovery
- Escalation procedures
- Maintenance windows
- Performance troubleshooting
- Operational checklists

**Best for:**
- Operations staff
- On-call support
- Incident response
- Maintenance scheduling
- Shift handoffs

---

### For Developers: API Reference

**→ [API-REFERENCE.md](API-REFERENCE.md)** (~20 pages)

Complete function reference:
- All public functions documented
- Parameter descriptions
- Return value details
- Code examples
- Common patterns

**Best for:**
- Developers integrating with the module
- Script writers
- Automation engineers
- API consumers
- Integration scenarios

---

## Quick Links

### Getting Started (5 minutes)

1. **Read:** [USER-GUIDE.md#introduction](USER-GUIDE.md#introduction)
2. **Install:** [USER-GUIDE.md#installation--setup](USER-GUIDE.md#installation--setup)
3. **Test:** [USER-GUIDE.md#step-4-test-connection](USER-GUIDE.md#step-4-test-connection)

### Connecting to Exchange Online (2026-07-01 auth model)

`Connect-ExchangeOnlineEnv` supports certificate-based app authentication and a
corporate outbound proxy, and can resolve its connection details entirely from
config instead of explicit parameters:

- `-Tenant` / `-AppId` are now **optional** - if omitted, they fall back to the
  `Organization` / `AppId` values in `config.<Environment>.json`
- `-CertificateThumbprint` authenticates against a certificate already installed
  in the local certificate store (no `.pfx`/password file); also falls back to
  config if omitted
- `-ProxyUrl` configures `HTTP_PROXY`/`HTTPS_PROXY` and .NET's `DefaultWebProxy`
  for the session before connecting
- `-Prefix` (default `"ETH"`) prefixes cloud cmdlet nouns (e.g. `Get-ETHMailbox`)
  so an unprefixed on-premises `Import-PSSession` can stay open in the same
  window without cmdlet name collisions

Run `scripts\Initialize-ProvisioningConnections.ps1` once per environment to
write `Organization`/`AppId`/`CertificateThumbprint` into
`config.<Environment>.json` and create the on-premises Service Account
credential file - after that, `Connect-ExchangeOnlineEnv` (no parameters)
resolves everything from config. See [SETUP.md](SETUP.md) Step 3 and Step 7.

### Deploy to Production (1 hour)

1. **Follow:** [ADMIN-GUIDE.md#installation--deployment](ADMIN-GUIDE.md#installation--deployment)
2. **Configure:** [ADMIN-GUIDE.md#configuration](ADMIN-GUIDE.md#configuration)
3. **Monitor:** [ADMIN-GUIDE.md#monitoring--alerting](ADMIN-GUIDE.md#monitoring--alerting)

### Operating Day-to-Day (Daily)

1. **Morning:** [OPERATIONS-RUNBOOK.md#daily-operations](OPERATIONS-RUNBOOK.md#daily-operations)
2. **Incidents:** [OPERATIONS-RUNBOOK.md#incident-response](OPERATIONS-RUNBOOK.md#incident-response)
3. **Weekly:** [OPERATIONS-RUNBOOK.md#weekly-reporting](OPERATIONS-RUNBOOK.md#weekly-reporting)

### Find a Specific Function

Use [API-REFERENCE.md](API-REFERENCE.md) for complete reference:
- Connection: `Connect-ExchangeOnlineEnv`
- Discovery: `Get-SharedMailboxCandidates`, `Get-SharedMailboxCandidatesWithGroups`
- Validation: `Test-SharedMailboxCandidate`
- Provisioning: `New-SharedMailboxRemote`, `Invoke-MailboxPermissionQueue`
- Orchestration: `Invoke-SharedMailboxProvisioning`
- Bulk Import: `Import-MailboxCandidatesFromCSV`, `Test-MailboxBulkImport`
- Reporting: `Get-MailboxProvisioningReport`, `Export-MailboxAuditLog`, `Get-MailboxProvisioningMetrics`
- Operations: `Get-MailboxProvisioningStatus`, `Resolve-MailboxProvisioningFailure`, `Invoke-MailboxProvisioningRetry`

---

## Common Scenarios

### Scenario 1: Automatic Provisioning

**Question:** How do shared mailboxes get created automatically?

**Answer:**
1. ScheduledTask runs every 15 minutes
2. Discovers candidates in AD (SamAccountName = smbx_*)
3. Creates mailboxes in Exchange Online
4. Assigns permissions from ACL groups
5. Logs all operations

**Read:** [USER-GUIDE.md#workflow-1-automatic-discovery-scheduled](USER-GUIDE.md#workflow-1-automatic-discovery-scheduled)

---

### Scenario 2: Manual Bulk Import

**Question:** How do I provision 20 mailboxes from a CSV file?

**Answer:**
1. Prepare CSV with candidates
2. Run `Test-MailboxBulkImport` to validate
3. Run `Import-MailboxCandidatesFromCSV` to provision
4. Check status with `Get-MailboxProvisioningStatus`

**Read:** [USER-GUIDE.md#workflow-2-manual-bulk-import-csv](USER-GUIDE.md#workflow-2-manual-bulk-import-csv)

---

### Scenario 3: System is Slow

**Question:** Provisioning taking >10 minutes per mailbox, what to do?

**Answer:**
1. Check metrics: `Get-MailboxProvisioningMetrics`
2. Check resources: CPU, memory, disk
3. Reduce batch size (10 → 5 mailboxes)
4. Increase ScheduledTask interval (15 → 30 min)

**Read:** [ADMIN-GUIDE.md#performance-tuning](ADMIN-GUIDE.md#performance-tuning)

---

### Scenario 4: Incident - System Down

**Question:** Provisioning hasn't run in 2 hours, what to do?

**Answer:**
1. Follow P0 response: [OPERATIONS-RUNBOOK.md#p0-response-system-down](OPERATIONS-RUNBOOK.md#p0-response-system-down)
2. Check ScheduledTask, EXO connection, AD connectivity
3. Manual trigger: `Start-ScheduledTask`
4. Monitor recovery

**Read:** [OPERATIONS-RUNBOOK.md#incident-response](OPERATIONS-RUNBOOK.md#incident-response)

---

### Scenario 5: Find All Failing Mailboxes

**Question:** How do I see which mailboxes failed to provision?

**Answer:**
```powershell
# Get failures
Get-MailboxProvisioningStatus | 
  Where-Object { $_.CurrentStatus -like "FAILED*" }

# Get diagnosis
Resolve-MailboxProvisioningFailure -DiagnoseAll
```

**Read:** [API-REFERENCE.md#get-mailboxprovisioningstatus](API-REFERENCE.md#get-mailboxprovisioningstatus)

---

## Documentation Map

```
SharedMailboxProvisioner Docs/
├── README.md (you are here)
├── USER-GUIDE.md
│   ├─ Installation & Setup
│   ├─ Getting Started
│   ├─ Core Workflows
│   ├─ Manual Bulk Import
│   ├─ Monitoring & Status
│   ├─ Troubleshooting
│   └─ FAQ
├── ADMIN-GUIDE.md
│   ├─ Architecture Overview
│   ├─ Installation & Deployment
│   ├─ Configuration
│   ├─ Performance Tuning
│   ├─ Monitoring & Alerting
│   ├─ Troubleshooting
│   ├─ Disaster Recovery
│   └─ Security
├── OPERATIONS-RUNBOOK.md
│   ├─ Daily Operations
│   ├─ Incident Response
│   ├─ Failure Handling
│   ├─ Escalation
│   ├─ Maintenance
│   ├─ Performance Troubleshooting
│   └─ Checklists
└── API-REFERENCE.md
    ├─ Connection Functions
    ├─ Discovery & Validation
    ├─ Provisioning Functions
    ├─ Bulk Import Functions
    ├─ Reporting Functions
    ├─ Operational Functions
    ├─ Common Patterns
    └─ Return Values
```

---

## Module Architecture

```
TIER 0: Connection
  └─ Connect-ExchangeOnlineEnv

TIER 2-4: Discovery & Validation
  ├─ Get-SharedMailboxCandidates
  ├─ Get-SharedMailboxCandidatesWithGroups
  ├─ Get-SharedMailboxACLGroup
  └─ Test-SharedMailboxCandidate

TIER 5: Provisioning
  ├─ New-SharedMailboxRemote
  └─ Invoke-MailboxPermissionQueue

TIER 6: Orchestration
  └─ Invoke-SharedMailboxProvisioning

TIER 7: Bulk Import (MANUAL)
  ├─ Import-MailboxCandidatesFromCSV
  └─ Test-MailboxBulkImport

TIER 8: Reporting & Audit
  ├─ Get-MailboxProvisioningReport
  ├─ Export-MailboxAuditLog
  └─ Get-MailboxProvisioningMetrics

TIER 10: Operational Tooling
  ├─ Get-MailboxProvisioningStatus
  ├─ Resolve-MailboxProvisioningFailure
  ├─ Invoke-MailboxProvisioningRetry
  ├─ Set-MailboxProvisioningSchedule
  └─ Get-MailboxProvisioningHealth
```

---

## Support & Resources

### Documentation

- **USER-GUIDE:** Getting started and basic operations
- **ADMIN-GUIDE:** Technical deployment and configuration
- **OPERATIONS-RUNBOOK:** Daily procedures and incident response
- **API-REFERENCE:** Complete function reference

### Getting Help

1. **Check Troubleshooting:** See relevant guide (USER/ADMIN/OPERATIONS)
2. **Review API Docs:** Find function reference in API-REFERENCE.md
3. **Check FAQ:** [USER-GUIDE.md#faq](USER-GUIDE.md#faq)
4. **File Issue:** GitHub Issues (for bugs/enhancement requests)

### Training

- **Self-paced:** Read USER-GUIDE.md (30 min)
- **Hands-on:** Deploy to test environment following ADMIN-GUIDE.md (2 hours)
- **Operational:** Learn daily procedures from OPERATIONS-RUNBOOK.md

---

## Document Versions

| Document | Version | Status | Last Updated |
|----------|---------|--------|---|
| USER-GUIDE.md | 1.0 | Production | 2026-06-30 |
| ADMIN-GUIDE.md | 1.0 | Production | 2026-06-30 |
| OPERATIONS-RUNBOOK.md | 1.0 | Production | 2026-06-30 |
| API-REFERENCE.md | 1.0 | Production | 2026-06-30 |

---

## Document Standards

All documentation follows these standards:
- **Clarity:** Written for target audience (users, admins, operators, developers)
- **Completeness:** Covers all features and scenarios
- **Examples:** Real-world code examples for every feature
- **Accuracy:** Tested against actual module behavior
- **Maintainability:** Updated with each release

---

## Feedback & Updates

Documentation is maintained alongside code. Updates happen:
- **With each feature release:** New functions documented
- **Quarterly:** Review for accuracy and completeness
- **When issues arise:** Troubleshooting sections enhanced

---

**Documentation Version:** 0.9.0-beta.1 | **Module Version:** v0.9.0-beta.1 | **Status:** Pre-Release Phase

---

## Quick Reference Card

```powershell
# Connection
Connect-ExchangeOnlineEnv

# Discover & Validate
$candidates = Get-SharedMailboxCandidates
Test-SharedMailboxCandidate -ADUser $user

# Provision
New-SharedMailboxRemote -SamAccountName $sam -DisplayName $name -Email $email
Invoke-MailboxPermissionQueue -MailboxEmail $email -ACLGroupName $group

# Orchestrate
Invoke-SharedMailboxProvisioning

# Bulk Import
Import-MailboxCandidatesFromCSV -CsvPath "candidates.csv"
Test-MailboxBulkImport -CsvPath "candidates.csv" -GenerateReport

# Monitor & Report
Get-MailboxProvisioningStatus -SamAccountName "smbx_001" -ShowTimeline
Get-MailboxProvisioningHealth -CheckAll
Get-MailboxProvisioningMetrics

# Troubleshoot
Resolve-MailboxProvisioningFailure -DiagnoseAll
Invoke-MailboxProvisioningRetry -RetryAll

# Manage
Set-MailboxProvisioningSchedule -Interval 30
Export-MailboxAuditLog -Format HTML -OutputPath "report.html"
```

