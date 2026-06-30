# SharedMailboxProvisioner – Pre-Release Phase Roadmap

**Date:** 2026-06-30  
**Project:** SharedMailboxProvisioner  
**Phase:** Pre-Release (v0.9.x)  
**Duration:** 3 weeks  
**Goal:** Real-world validation and preparation for v1.0.0 launch

---

## Executive Summary

Pre-Release Phase focuses on **practical validation** through real-world deployment, manual testing of critical workflows, and establishing performance baselines. This phase bridges Beta (code-complete) → Release (production-ready).

**Current State:** v0.8.2 (Beta-Phase-Complete)  
**Target State:** v0.9.0 (Pre-Release Ready for v1.0.0)  
**Next Milestone:** v1.0.0 (Full Production Release)  
**Duration:** 3 weeks (July 1 - July 21)

---

## Release Process – Three-Tier Model (after WinHarden)

### Version Progression

```
v0.8.2 (Beta-Complete, current)
    ↓
v0.9.0-beta.1 (Initial pre-release)
    ↓ [after testing OK]
v0.9.0 (Pre-Release Stable - Ready for v1.0.0)
    ↓ [after go-live validation]
v1.0.0 (Full Production Release)
```

### Release Branches (Three-Tier Model)

```
develop (Daily development)
    ↓ [merge after code complete]
prerelease (v0.9.x testing branch)
    ↓ [merge after testing + fixes]
main (v0.9.0 stable, production-ready)
    ↓ [tag + publish to PSGallery + GitHub Releases]
v1.0.0 (Launch)
```

### Release Strategy

**PowerShell Gallery Publication:**
- ✅ v0.9.0-beta.1 (Pre-release flag) - Week 1
- ✅ v0.9.0 (Stable release) - Week 3
- ✅ v1.0.0 (Production release) - After go-live

**GitHub Release Automation:**
- Annotated tags: `v0.9.0`, `v0.9.0-beta.1`
- Release notes automatically published
- Same format as WinHarden (features, fixes, compatibility notes)

**Dual-Remote Strategy (like WinHarden):**
- `origin` = Azure DevOps (primary)
- `github` = GitHub (secondary mirror)
- All tags and releases pushed to both remotes

---

## Phase Objectives

| Objective | Success Criteria | Owner | Timeline |
|-----------|------------------|-------|----------|
| **Real-World Deployment** | Deploy to staging; all functions work | DevOps | Week 1 |
| **Manual Testing** | 10 candidates, all critical workflows pass | QA | Week 1 |
| **Performance Baseline** | Throughput, latency, resources documented | DevOps | Week 1 |
| **Upgrade Validation** | v0.8.2 → v0.9.0 path tested | DevOps | Week 1 |
| **Documentation Updates** | Updated with findings | Tech Writer | Week 2 |
| **Release Process** | PSGallery + GitHub releases automated | Release Mgr | Week 2-3 |
| **v0.9.0 Ready** | Go/No-Go decision for v1.0.0 | Steering Cmte | Week 3 |

---

## Pre-Release Phase Timeline (3 Weeks)

### WEEK 1 (July 1-5): Deployment & Testing

```
MONDAY (July 1)
├─ 9:00 AM: Staging infrastructure ready
├─ 10:00 AM: v0.8.2 deployed to staging
├─ 12:00 PM: Smoke tests (basic connectivity)
└─ 2:00 PM: Staging deployment complete

TUESDAY (July 2)
├─ 9:00 AM: Manual testing begins (10 prepared candidates)
├─ 10:00 AM: Find & validate candidates
├─ 11:00 AM: Test provisioning (all 10 mailboxes)
├─ 12:00 PM: Verify permission assignment
├─ 1:00 PM: Test reporting & recovery
├─ 2:00 PM: Test retry mechanism
└─ 3:00 PM: Testing complete - all pass/issues documented

WEDNESDAY (July 3)
├─ 9:00 AM: Performance baseline testing
│  ├─ Throughput (mailboxes/hour)
│  ├─ Latency (time per mailbox)
│  └─ Resource utilization (CPU, memory, disk)
└─ 5:00 PM: Performance report complete

THURSDAY (July 4)
├─ 9:00 AM: Upgrade path validation
│  ├─ Test v0.8.2 → v0.9.0 upgrade
│  ├─ Verify configuration preservation
│  └─ Validate rollback procedure
└─ 5:00 PM: Upgrade path validated

FRIDAY (July 5)
├─ 9:00 AM: Week 1 results review
├─ 10:00 AM: Issue triage (if any)
├─ 11:00 AM: Fix critical issues (if any)
└─ 5:00 PM: Ready for Week 2
```

**Milestone:** Real-world deployment validated, all critical workflows tested

---

### WEEK 2 (July 8-12): Fixes & Release Preparation

```
MONDAY (July 8)
├─ 9:00 AM: Fix any issues from Week 1 (if any)
└─ 5:00 PM: Issues resolved

TUESDAY (July 9)
├─ 9:00 AM: Documentation updates
│  ├─ Add findings from testing
│  ├─ Update troubleshooting guides
│  └─ Add performance metrics
└─ 5:00 PM: Documentation complete

WEDNESDAY (July 10)
├─ 9:00 AM: Prepare Release Process documentation
│  ├─ Three-Tier Model diagram
│  ├─ PSGallery publication procedure
│  └─ GitHub release automation
└─ 5:00 PM: Release process documented

THURSDAY (July 11)
├─ 9:00 AM: Update version numbers (v0.9.0)
├─ 10:00 AM: Prepare release notes
├─ 11:00 AM: Update GitHub release template
└─ 5:00 PM: Release materials ready

FRIDAY (July 12)
├─ 9:00 AM: Final validation
├─ 10:00 AM: Security/compliance check
├─ 11:00 AM: Go/No-Go decision prep
└─ 5:00 PM: Week 2 complete
```

**Milestone:** All fixes applied, documentation updated, release process ready

---

### WEEK 3 (July 15-19): Release & v1.0.0 Preparation

```
MONDAY (July 15)
├─ 9:00 AM: Final Go/No-Go meeting
├─ 10:00 AM: Stakeholder sign-off
└─ 11:00 AM: Release decision confirmed

TUESDAY (July 16)
├─ 9:00 AM: Create release tag (v0.9.0)
├─ 10:00 AM: Publish to PSGallery
├─ 11:00 AM: Publish to GitHub Releases
└─ 2:00 PM: Release published

WEDNESDAY (July 17)
├─ 9:00 AM: Verify PSGallery installation works
├─ 10:00 AM: Verify GitHub release downloads
├─ 11:00 AM: Monitor initial feedback
└─ 5:00 PM: Release monitoring stable

THURSDAY (July 18)
├─ 9:00 AM: Begin v1.0.0 launch preparation
├─ 10:00 AM: Finalize launch timeline
├─ 11:00 AM: Prepare launch announcement
└─ 5:00 PM: Launch plan ready

FRIDAY (July 19)
├─ 9:00 AM: Final v1.0.0 readiness review
├─ 10:00 AM: Support team briefing
├─ 11:00 AM: Monitoring setup verification
└─ 5:00 PM: Ready for v1.0.0 launch
```

**Milestone:** v0.9.0 released, v1.0.0 launch plan finalized

---

## Success Criteria

**Pre-Release Phase is successful when:**

- ✅ v0.8.2 deployed to staging with real EXO/AD integration
- ✅ All 10 test candidates provisioned successfully
- ✅ All critical workflows validated (provision, permissions, report, recovery, retry)
- ✅ Performance baseline established (throughput, latency, resources)
- ✅ Upgrade path v0.8.2 → v0.9.0 tested and validated
- ✅ Documentation updated with real-world findings
- ✅ Release process documented (Three-Tier Model, PSGallery/GitHub automation)
- ✅ v0.9.0 published to PSGallery and GitHub Releases
- ✅ Go/No-Go decision obtained for v1.0.0
- ✅ v1.0.0 launch plan finalized and approved

---

## Risk Management

### Critical Risks

| Risk | Probability | Impact | Mitigation |
|------|------------|--------|-----------|
| Real EXO/AD issues in staging | Medium | HIGH | Deploy early, test immediately |
| Test candidate preparation delays | Low | MEDIUM | Prepare accounts via IT-Shop in advance |
| Performance below expectations | Low | MEDIUM | Identify bottlenecks; plan optimizations for v1.1 |

### Medium Risks

| Risk | Probability | Impact | Mitigation |
|------|------------|--------|-----------|
| Upgrade path breaks settings | Low | HIGH | Test thoroughly; document rollback |
| Release automation issues | Low | MEDIUM | Test PSGallery publish process early |

---

## Resource Allocation

| Role | Effort | Timeline |
|------|--------|----------|
| DevOps/SRE | 24 hours | Week 1-2 (deployment, performance) |
| QA/Testers | 16 hours | Week 1 (manual testing, validation) |
| Tech Writer | 12 hours | Week 2 (documentation) |
| Release Manager | 8 hours | Week 2-3 (release process) |
| Support Manager | 4 hours | Week 2-3 (support prep) |
| **TOTAL** | **64 hours** | **3 weeks** |

---

## Go/No-Go Criteria (Week 3)

**GO Decision when:**
- ✅ All 10 test candidates provisioned successfully
- ✅ All critical workflows pass validation
- ✅ Performance metrics acceptable (throughput ≥60 mailboxes/hour)
- ✅ Upgrade path validated and documented
- ✅ No critical blockers remaining
- ✅ Documentation complete and accurate
- ✅ Release process tested and working

**NO-GO Decision if:**
- ❌ Critical workflow fails in staging
- ❌ Performance unacceptable (<40 mailboxes/hour)
- ❌ Upgrade path breaks (blocking v1.0.0)
- ❌ Unresolved security issues

---

## Next Steps

### Immediate (Today - June 30)
- [ ] Approve Pre-Release Phase Roadmap
- [ ] Assign owners to each role
- [ ] Prepare 10 test candidates via IT-Shop

### Week 1 (July 1-5)
- [ ] Deploy v0.8.2 to staging
- [ ] Execute manual testing (1 day, 10 candidates)
- [ ] Complete performance baseline
- [ ] Validate upgrade path

### Week 2 (July 8-12)
- [ ] Fix any issues from Week 1
- [ ] Update documentation
- [ ] Prepare release materials
- [ ] Test release process

### Week 3 (July 15-19)
- [ ] Make Go/No-Go decision
- [ ] Publish v0.9.0 (PSGallery + GitHub)
- [ ] Finalize v1.0.0 launch plan

---

**Pre-Release Phase: READY TO EXECUTE** ✅

**Target v1.0.0 Launch: Late July/Early August 2026** 🚀
