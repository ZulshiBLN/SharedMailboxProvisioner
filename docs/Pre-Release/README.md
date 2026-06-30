# SharedMailboxProvisioner – Pre-Release Phase Documentation

**Current Status:** READY TO EXECUTE (v0.8.2 → v0.9.0)  
**Phase Start:** July 1, 2026  
**Phase Duration:** 3 weeks (July 1-21)  
**Next Milestone:** v1.0.0 Full Production Release

---

## Phase Overview

Pre-Release Phase (v0.9.x) is the **practical validation phase** for SharedMailboxProvisioner. Three weeks of focused testing, performance baselining, and release preparation.

**Duration:** 3 weeks  
**Effort:** ~64 person-hours  
**Key Deliverable:** v0.9.0 (Pre-Release Stable)

---

## Key Documents

### 1. PHASE-PRERELEASE-ROADMAP.md
**High-level roadmap and timeline for Pre-Release Phase**

- Release Process (Three-Tier Model: develop → prerelease → main)
- Week-by-week detailed timeline
- Success criteria and Go/No-Go decision gate
- Resource allocation and risk management
- Version progression: v0.9.0-beta.1 → v0.9.0

**Use This For:** Strategic planning, stakeholder communication, schedule tracking

---

### 2. IMPLEMENTATION-PLAN-PRERELEASE.md
**Detailed, step-by-step execution plan with 7 work packages**

**7 Work Packages (64 hours total):**

1. **WP-1:** Real-World Deployment (12h)
   - Staging infrastructure setup
   - v0.8.2 deployment and baseline testing
   - Real EXO/AD connectivity validation

2. **WP-2:** Manual Testing – Critical Workflows (8h)
   - 10 prepared test candidates (via IT-Shop)
   - Find & validate candidates
   - Provision, permission assignment
   - Reporting and recovery testing

3. **WP-3:** Performance Baseline (8h)
   - Throughput testing (mailboxes/hour)
   - Latency testing (time per mailbox)
   - Resource utilization monitoring

4. **WP-4:** Upgrade Path Validation (4h)
   - v0.8.2 → v0.9.0 upgrade process
   - Configuration preservation verification
   - Rollback procedure testing

5. **WP-5:** Documentation Updates (12h)
   - Update USER-GUIDE.md, ADMIN-GUIDE.md
   - Update OPERATIONS-RUNBOOK.md
   - Add real-world examples and findings

6. **WP-6:** Release Process & Publication (8h)
   - Document Three-Tier release process
   - PSGallery publication automation
   - GitHub Releases automation

7. **WP-7:** v0.9.0 Release Ready & v1.0.0 Prep (12h)
   - Final validation and sign-off
   - Go/No-Go decision
   - v1.0.0 launch plan

**Use This For:** Daily execution, task assignment, progress tracking

---

## Phase Timeline (3 Weeks)

### WEEK 1 (July 1-5): Deployment & Testing
**All testing activities consolidated into one week**

- **Days 1-2:** Real-World Deployment to staging
- **Day 3:** Manual Testing (1 full day, 10 candidates, 6 workflows)
- **Day 4:** Performance Baseline Testing
- **Day 5:** Upgrade Path Validation

**Milestone:** All critical validation complete

---

### WEEK 2 (July 8-12): Fixes & Release Prep
- Fix any issues from Week 1 (if any)
- Documentation updates (from real-world findings)
- Release process documentation
- Release materials preparation

**Milestone:** Ready for release

---

### WEEK 3 (July 15-21): Release & v1.0.0 Prep
- Make Go/No-Go decision
- Publish v0.9.0 (PSGallery + GitHub Releases)
- Begin v1.0.0 launch preparation

**Milestone:** v0.9.0 released, v1.0.0 launch plan ready

---

## Release Process (Three-Tier Model)

### Branch Strategy (after WinHarden)

```
develop (Daily development)
    ↓
prerelease (v0.9.0-beta.x testing)
    ↓
main (v0.9.0 stable)
    ↓
v1.0.0 (Production Release)
```

### Version Progression

```
v0.8.2 (Current - Beta Phase Complete)
   ↓ [Week 1]
v0.9.0-beta.1 (Initial pre-release)
   ↓ [Week 2-3 after testing]
v0.9.0 (Stable pre-release, ready for v1.0.0)
   ↓ [After go-live validation]
v1.0.0 (FULL PRODUCTION RELEASE)
```

### Release Automation

- **Dual-Remote Strategy:** origin (Azure DevOps) + github (GitHub)
- **Tagging:** Annotated tags with release notes (WinHarden format)
- **PowerShell Gallery:** v0.9.0-beta.1 (pre-release flag) → v0.9.0 (stable)
- **GitHub Releases:** Automatic creation from tags

---

## Manual Testing Plan (Day 3, 1 Day)

### Test Scope: 10 Prepared Candidates

All accounts prepared via IT-Shop (by July 2), following exact IT-Shop specifications.

**6 Critical Workflows to Test:**

1. **Find & Validate Candidates** (1.5 hours)
   - Run `Get-SharedMailboxCandidates`
   - Verify all 10 accounts found
   - Find and validate associated groups

2. **Validate Candidates** (1.5 hours)
   - Run `Get-SharedMailboxCandidatesWithGroups`
   - Verify all candidates pass validation

3. **Test Provisioning** (2 hours)
   - Provision all 10 mailboxes
   - Verify creation in Exchange Online
   - Verify no throttling errors

4. **Test Permission Assignment** (1.5 hours)
   - Verify all groups correctly assigned
   - Verify Full Access and Send-As correct
   - Verify audit logs capture assignments

5. **Test Reporting** (1 hour)
   - Run `Get-MailboxProvisioningReport`
   - Export to CSV, HTML, JSON
   - Verify all formats work correctly

6. **Test Recovery & Retry** (0.5 hours)
   - Test `Resolve-MailboxProvisioningFailure`
   - Test `Invoke-MailboxProvisioningRetry`
   - Verify recovery mechanisms work

**Expected Result:** All 10 candidates provisioned, all workflows pass (Happy Path)

---

## Success Criteria

**Pre-Release Phase is successful when:**

✅ Real-World Deployment successful (staging ready)  
✅ All 10 test candidates provisioned  
✅ All 6 critical workflows pass  
✅ Performance baseline documented (≥60 mailboxes/hour)  
✅ Upgrade path v0.8.2 → v0.9.0 validated  
✅ Documentation updated with findings  
✅ Release process documented  
✅ v0.9.0 published (PSGallery + GitHub)  
✅ Go/No-Go decision for v1.0.0 made  
✅ v1.0.0 launch plan finalized  

---

## Go/No-Go Criteria (End of Week 3)

### GO Decision when:
- ✅ All 10 test candidates provisioned successfully
- ✅ All 6 critical workflows pass validation
- ✅ Performance ≥60 mailboxes/hour (acceptable)
- ✅ Upgrade path validated, rollback tested
- ✅ No critical blockers remaining
- ✅ Documentation complete and accurate

### NO-GO Decision if:
- ❌ Critical workflow fails in real environment
- ❌ Performance <40 mailboxes/hour (unacceptable)
- ❌ Upgrade path breaks or can't rollback
- ❌ Unresolved security/compliance issues

---

## Work Package Overview

| WP | Name | Days | Owner | Effort |
|----|------|------|-------|--------|
| 1 | Real-World Deployment | 1-2 | DevOps | 12h |
| 2 | Manual Testing (10 Candidates) | 3 | QA | 8h |
| 3 | Performance Baseline | 4 | DevOps | 8h |
| 4 | Upgrade Path Validation | 5 | DevOps | 4h |
| 5 | Documentation Updates | 6-9 | Tech Writer | 12h |
| 6 | Release Process & Publication | 10-15 | Release Mgr | 8h |
| 7 | v0.9.0 Release Ready | 16-21 | All | 12h |

**Total Effort:** 64 person-hours over 3 weeks

---

## Critical Prerequisites

**Must be ready BEFORE July 1:**

1. ✅ **10 test accounts pre-ordered via IT-Shop**
   - All accounts prepared and ready for provisioning
   - All IT-Shop specifications followed exactly
   - Accounts will be available in AD by July 2

2. ✅ **Staging infrastructure planned**
   - Real EXO and AD environments available
   - Necessary permissions granted to deploy module
   - Logging and monitoring configured

3. ✅ **DevOps and QA team assigned**
   - Clear owners for each work package
   - Availability confirmed for July 1-21

---

## Stakeholders & Owners

| Role | Responsibility |
|------|-----------------|
| **DevOps/SRE** | Staging deployment, performance testing, upgrade validation |
| **QA/Testers** | Manual testing of 10 candidates |
| **Tech Writer** | Documentation updates from findings |
| **Release Manager** | Release process, PSGallery/GitHub publication |
| **Product Manager** | v1.0.0 launch coordination |
| **Support Manager** | Support team preparation |

---

## Key Differences from Beta Phase

| Aspect | Beta Phase | Pre-Release Phase |
|--------|-----------|-------------------|
| **Environment** | Mock-based testing | Real EXO/AD staging |
| **Testing Scope** | 41+ unit test cases | 10 manual test candidates |
| **Duration** | Completed | 3 weeks (focused) |
| **Scope** | Code-complete | Real-world validation |
| **Release** | v0.8.2 (internal) | v0.9.0 (PSGallery + GitHub) |

---

## Next Steps (Immediate)

### By June 30 (TODAY)
- [ ] Approve Roadmap and Implementation Plan
- [ ] Assign owners to each Work Package
- [ ] **PRE-ORDER 10 TEST ACCOUNTS VIA IT-SHOP** (CRITICAL!)
- [ ] Confirm DevOps and QA availability

### July 1-5 (Week 1)
- [ ] Execute WP-1 through WP-4 (Deployment, Testing, Performance, Upgrade)
- [ ] Document any issues found
- [ ] Complete all Week 1 testing

### July 8-12 (Week 2)
- [ ] Fix any issues from Week 1 (if any)
- [ ] Execute WP-5 (Documentation updates)
- [ ] Execute WP-6 (Release process preparation)

### July 15-21 (Week 3)
- [ ] Execute WP-7 (Final validation, Go/No-Go, release)
- [ ] Publish v0.9.0 to PSGallery and GitHub
- [ ] Finalize v1.0.0 launch plan

---

## Communication Plan

**Weekly Status Updates:** Friday 5 PM
- Progress against milestones
- Issues and resolutions
- Go/No-Go decision (Week 3)

**Escalation Path:**
- Critical blockers: Immediate escalation
- Performance issues: Daily sync
- Documentation gaps: As discovered

---

## Related Documentation

- **[PHASE-PRERELEASE-ROADMAP.md](PHASE-PRERELEASE-ROADMAP.md)** – Strategic roadmap and timeline
- **[IMPLEMENTATION-PLAN-PRERELEASE.md](IMPLEMENTATION-PLAN-PRERELEASE.md)** – Detailed execution plan

---

## Archive Reference

**Previous Phases:**
- [../Beta-Phase/COMPLIANCE-AUDIT-PHASE-BETA-COMPLETE.md](../Beta-Phase/COMPLIANCE-AUDIT-PHASE-BETA-COMPLETE.md) – Beta Phase completion audit
- [../Alpha-Phase/](../Alpha-Phase/) – Alpha Phase documentation

---

**Pre-Release Phase: READY TO EXECUTE** ✅

**Timeline:** 3 weeks (July 1-21)  
**Effort:** 64 person-hours  
**Target:** v0.9.0 released, v1.0.0 launch ready 🚀
