# SharedMailboxProvisioner – Pre-Release Phase Roadmap

**Date:** 2026-06-30  
**Project:** SharedMailboxProvisioner  
**Phase:** Pre-Release (v0.9.x)  
**Duration:** 4-6 weeks  
**Goal:** Prepare for v1.0.0 launch via real-world testing and user feedback

---

## Executive Summary

Pre-Release Phase focuses on **real-world validation** of the codebase through deployment to staging/test environments, comprehensive UAT, performance baseline establishment, and early user feedback collection. This phase bridges Beta (code-complete) → Release (production-ready).

**Current State:** v0.8.2 (Beta-Phase-Complete)  
**Target State:** v1.0.0 (Full Production Release)  
**Intermediate Milestone:** v0.9.0 (Pre-Release Final)

---

## Phase Objectives

| Objective | Success Criteria | Owner | Timeline |
|-----------|------------------|-------|----------|
| **Real-World Deployment** | Deploy to staging; no critical issues | DevOps/Admin | Week 1-2 |
| **Post-Launch UAT** | All critical workflows validated | QA/Users | Week 2-4 |
| **Performance Baseline** | Establish perf metrics; <5% variance | DevOps | Week 2-3 |
| **Upgrade Path Validation** | v0.8.2 → v0.9.0 successful | DevOps | Week 3 |
| **Gallery Publication** | Pre-release published to PSGallery | Release Manager | Week 2 |
| **User Feedback** | 3+ early adopters, feedback collected | Product | Week 1-4 |
| **Documentation Updates** | Updated based on UAT findings | Tech Writer | Week 4 |
| **Release Candidate Ready** | v0.9.0-rc.1 approved for final testing | Release Manager | Week 4-5 |

---

## Pre-Release Phase Timeline

```
WEEK 1 (July 1-5): Deployment & Initial Testing
├─ Day 1: Deploy to staging environment
├─ Day 2-3: Smoke testing (basic functionality)
├─ Day 3-4: Publish pre-release to PSGallery
├─ Day 4-5: Gather initial user feedback
└─ Milestone: v0.8.2 → v0.8.3 (bug fixes if needed)

WEEK 2 (July 8-12): UAT & Performance Testing
├─ Day 1-2: Begin UAT with early adopters
├─ Day 2-3: Performance baseline testing
├─ Day 3-4: Resolve critical UAT issues
├─ Day 4-5: Performance report + tuning recommendations
└─ Milestone: Identify & prioritize issues

WEEK 3 (July 15-19): Stability & Upgrade Testing
├─ Day 1-2: Fix UAT issues (P0/P1)
├─ Day 2-3: Upgrade path testing (v0.8.2 → v0.9.0)
├─ Day 3-4: Stabilization testing
├─ Day 4-5: Final user acceptance sign-off
└─ Milestone: v0.9.0-rc.1 ready

WEEK 4 (July 22-26): Final Validation & Documentation
├─ Day 1-2: Release candidate final testing
├─ Day 2-3: Documentation updates from UAT findings
├─ Day 3-4: Security validation review
├─ Day 4-5: Prepare v1.0.0 launch plan
└─ Milestone: v0.9.0 final approved

WEEK 5-6 (July 29-Aug 9): Buffer & Launch Prep
├─ Buffer for unexpected issues
├─ Fine-tuning based on feedback
├─ Launch readiness verification
├─ v1.0.0 release preparation
└─ Milestone: GO/NO-GO decision for v1.0.0
```

---

## Scope: What's Included in Pre-Release

### ✅ Included (In Scope)

1. **Real-World Deployment Testing**
   - Deploy to staging/test environment with real EXO/AD systems
   - Validate against production-like data volumes
   - Test with realistic user workflows

2. **User Acceptance Testing (UAT)**
   - 3+ early adopter organizations
   - Full workflow validation (provision, manage, report, fail-over)
   - Edge case discovery and handling
   - User feedback collection

3. **Performance Baseline**
   - Throughput testing (mailboxes/hour)
   - Latency measurements (provision time)
   - Resource utilization (CPU, memory, disk)
   - Bottleneck identification

4. **Upgrade Path Validation**
   - Test v0.8.2 → v0.9.0 upgrade procedure
   - Validate backward compatibility
   - Test rollback procedures

5. **PowerShell Gallery Publication**
   - Publish as pre-release (v0.9.0-beta.1, etc.)
   - Enable community testing
   - Gather install/usage feedback

6. **Documentation Updates**
   - Incorporate UAT findings
   - Update troubleshooting guides
   - Add performance tuning docs
   - Refine based on user questions

### ❌ Out of Scope (Defer to v1.1+)

- Advanced automation (Tier 9 - Integration Testing)
- Mail-flow policies integration
- Delegated access management
- Performance optimizations beyond baseline
- Container/Docker support
- CI/CD pipeline automation
- Load testing (>1000 concurrent users)

---

## Key Milestones

### Milestone 1: Staging Deployment (Week 1)
**Criteria:**
- ✅ Module deployed to staging environment
- ✅ Basic connectivity verified (EXO, AD)
- ✅ Smoke tests passing (all critical functions accessible)
- ✅ Pre-release published to PowerShell Gallery

**Deliverable:** v0.8.2-staging (internal), v0.9.0-beta.1 (PSGallery)

---

### Milestone 2: UAT Execution (Week 2-3)
**Criteria:**
- ✅ 3+ early adopter organizations provisioning mailboxes
- ✅ 50+ mailboxes provisioned through real workflows
- ✅ All critical workflows tested (Create, Manage, Report, Recover)
- ✅ P0/P1 issues logged and prioritized
- ✅ Performance metrics captured

**Deliverable:** UAT Report (issues, findings, recommendations)

---

### Milestone 3: Release Candidate (Week 4)
**Criteria:**
- ✅ All P0/P1 UAT issues resolved
- ✅ Upgrade path v0.8.2 → v0.9.0 validated
- ✅ Performance baseline documented
- ✅ Documentation updated from UAT
- ✅ Security review completed
- ✅ User feedback integrated

**Deliverable:** v0.9.0-rc.1 (Release Candidate)

---

### Milestone 4: Launch Ready (Week 5)
**Criteria:**
- ✅ v0.9.0-rc.1 final testing complete
- ✅ v1.0.0 launch plan finalized
- ✅ Go/No-Go decision made
- ✅ Communication plan prepared
- ✅ Support procedures documented

**Deliverable:** v1.0.0 ready for launch

---

## Risk Management

### High-Risk Areas

1. **Real EXO/AD Environment Compatibility**
   - Risk: Code works in mock, fails in production
   - Mitigation: Deploy to staging with real systems early
   - Owner: DevOps

2. **Performance Under Load**
   - Risk: Provisioning too slow for user expectations
   - Mitigation: Establish baseline; identify bottlenecks
   - Owner: Performance Team

3. **User Adoption Issues**
   - Risk: Early adopters struggle with workflows
   - Mitigation: Gather feedback early; iterate docs/processes
   - Owner: Product/Support

### Medium-Risk Areas

4. **Upgrade Path Failures**
   - Mitigation: Test on staging before production
   - Owner: DevOps

5. **Documentation Gaps**
   - Mitigation: UAT findings → immediate doc updates
   - Owner: Tech Writer

---

## Success Criteria

**Pre-Release Phase is successful when:**

- ✅ All critical workflows validated in real environment
- ✅ 3+ organizations can provision mailboxes without blockers
- ✅ Performance baseline documented (<5% variance)
- ✅ Upgrade path tested and documented
- ✅ All P0 issues resolved
- ✅ 80% of P1 issues resolved
- ✅ Documentation updated from UAT findings
- ✅ User feedback collected and prioritized
- ✅ v0.9.0 release candidate approved
- ✅ v1.0.0 launch plan finalized

---

## Versioning Strategy (Pre-Release)

```
v0.9.0-beta.1 (Week 1) – Initial pre-release to PSGallery
       ↓
v0.9.0-beta.2 (Week 2) – After initial UAT feedback
       ↓
v0.9.0-rc.1 (Week 3-4) – Release Candidate (final testing)
       ↓
v0.9.0 (Week 4-5) – Final pre-release (ready for v1.0.0 launch)
       ↓
v1.0.0 (Late Aug/Early Sep) – FULL PRODUCTION RELEASE 🚀
```

---

## Resource Allocation

| Role | Effort | Timeline |
|------|--------|----------|
| DevOps/SRE | 40 hours | Week 1, 3 (deployment, performance) |
| QA/Testers | 60 hours | Week 2-4 (UAT, validation) |
| Tech Writer | 20 hours | Week 4-5 (documentation updates) |
| Product Manager | 15 hours | Ongoing (feedback collection) |
| Support/On-Call | 10 hours | Week 1-4 (issue triage) |
| **TOTAL** | **145 hours** | **4-5 weeks** |

---

## Next Steps

1. **Week 1 (June 30-July 5):**
   - [ ] Finalize staging environment
   - [ ] Deploy v0.8.2 to staging
   - [ ] Publish v0.9.0-beta.1 to PSGallery
   - [ ] Identify 3+ early adopter organizations

2. **Week 2 (July 8-12):**
   - [ ] Begin UAT with early adopters
   - [ ] Execute performance baseline testing
   - [ ] Triage and prioritize issues

3. **Week 3 (July 15-19):**
   - [ ] Fix P0/P1 UAT issues
   - [ ] Validate upgrade path
   - [ ] Prepare v0.9.0-rc.1

4. **Week 4-5 (July 22-Aug 2):**
   - [ ] Final validation and sign-off
   - [ ] Update documentation
   - [ ] Prepare v1.0.0 launch

---

**Pre-Release Phase is the bridge from "Code Complete" to "Production Ready"**

**Goal: Make v1.0.0 a confident, well-validated, user-approved production release.** 🎯
