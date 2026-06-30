# Pre-Release Phase Implementation Plan

**Date:** 2026-06-30  
**Project:** SharedMailboxProvisioner  
**Phase:** Pre-Release (v0.9.x)  
**Status:** READY TO EXECUTE  
**Duration:** 3 weeks (July 1-21)  
**Total Effort:** ~64 person-hours

---

## Executive Summary

Focused, pragmatic Pre-Release Phase to validate code in real-world conditions and prepare v0.9.0 for v1.0.0 launch. Three weeks with 7 clearly-defined work packages.

**Key Deliverables:** v0.9.0 (stable pre-release), Release Process Documentation, v1.0.0 Launch Plan

---

## Work Packages Overview

| WP | Name | Duration | Owner | Effort |
|----|------|----------|-------|--------|
| **1** | Real-World Deployment | Days 1-2 | DevOps | 12h |
| **2** | Manual Testing (10 Candidates) | Day 3 | QA | 8h |
| **3** | Performance Baseline | Day 4 | DevOps | 8h |
| **4** | Upgrade Path Validation | Day 5 | DevOps | 4h |
| **5** | Documentation Updates | Days 6-9 | Tech Writer | 12h |
| **6** | Release Process & Publication | Days 10-15 | Release Mgr | 8h |
| **7** | v0.9.0 Release Ready | Days 16-21 | All | 12h |

---

## WP-1: Real-World Deployment (Days 1-2, 12 hours)

**Objective:** Deploy v0.8.2 to staging environment with real EXO/AD integration

**Tasks:**

### 1.1 Prepare Staging Infrastructure (Monday, Day 1)
- [ ] Provision staging servers (PowerShell 5.1+, same spec as planned prod)
- [ ] Configure network isolation (no cross-contamination with prod)
- [ ] Setup logging & monitoring (audit logs, performance monitoring)
- [ ] Validate Exchange Online connectivity
- [ ] Validate Active Directory connectivity
- [ ] Document infrastructure configuration

**Owner:** DevOps | **Effort:** 8 hours | **Due:** July 1, 5 PM

**Success Criteria:**
- ✅ Staging servers ready
- ✅ EXO connectivity verified
- ✅ AD connectivity verified
- ✅ Logging functional

---

### 1.2 Deploy & Baseline v0.8.2 (Monday-Tuesday, Day 1-2)
- [ ] Deploy v0.8.2 module to staging
- [ ] Verify all 25+ functions are accessible
- [ ] Run smoke tests (basic connectivity)
- [ ] Provision 2-3 test mailboxes for validation
- [ ] Verify audit logs capturing correctly
- [ ] Document any issues found

**Owner:** DevOps/QA | **Effort:** 4 hours | **Due:** July 2, 12 PM

**Success Criteria:**
- ✅ All functions callable
- ✅ 2-3 test mailboxes provisioned
- ✅ No critical blockers

**Deliverable:** Staging Deployment Report

---

## WP-2: Manual Testing of Critical Workflows (Day 3, 8 hours)

**Objective:** Validate all critical workflows with 10 real candidates

**Test Candidates:**
- 10 accounts prepared via IT-Shop (pre-ordered, ready to use)
- All accounts follow IT-Shop specifications exactly
- Accounts ready in AD by July 2

**Critical Workflows to Test:**

### 2.1 Find & Validate Candidates (Morning, 1.5 hours)
**Test 1: Find Candidates & Groups**
- [ ] Run `Get-SharedMailboxCandidates` 
- [ ] Verify all 10 accounts found
- [ ] Verify candidate attributes correct
- [ ] Find associated ACL groups for each
- [ ] Verify all groups present and valid

**Expected Result:** All 10 candidates found with correct groups

---

### 2.2 Validate Candidates (Morning, 1.5 hours)
**Test 2: Candidate Validation**
- [ ] Run `Get-SharedMailboxCandidatesWithGroups`
- [ ] Verify each candidate fully validated
- [ ] Verify all groups are correct type (Universal Security Group)
- [ ] Verify no errors in validation
- [ ] Document validation results

**Expected Result:** All 10 candidates pass validation

---

### 2.3 Test Provisioning (Late Morning, 2 hours)
**Test 3: Provision Mailboxes**
- [ ] Provision all 10 mailboxes via `New-SharedMailbox`
- [ ] Verify all 10 created in EXO
- [ ] Verify naming conventions correct
- [ ] Check provisioning time per mailbox
- [ ] Verify no throttling errors
- [ ] Document any issues (if IT-Shop account malformed)

**Expected Result:** All 10 mailboxes successfully provisioned

---

### 2.4 Test Permission Assignment (Early Afternoon, 1.5 hours)
**Test 4: Permission Assignment**
- [ ] Verify all 10 mailboxes have correct permissions
- [ ] Verify correct groups assigned as Full Access
- [ ] Verify correct groups assigned as Send-As
- [ ] Verify audit logs show permission assignments
- [ ] Spot-check 2-3 mailboxes in EXO for verification

**Expected Result:** All permissions correctly assigned

---

### 2.5 Test Reporting (Afternoon, 1 hour)
**Test 5: Reporting**
- [ ] Run `Get-MailboxProvisioningReport`
- [ ] Verify all 10 mailboxes in report
- [ ] Verify metrics accurate (count, timestamps)
- [ ] Export to CSV
- [ ] Export to HTML
- [ ] Verify all formats correct

**Expected Result:** All exports functional and accurate

---

### 2.6 Test Failure Recovery (Afternoon, 0.5 hours)
**Test 6: Recovery & Retry**
- [ ] Verify `Resolve-MailboxProvisioningFailure` working
- [ ] Verify `Invoke-MailboxProvisioningRetry` working
- [ ] Document retry success rate

**Expected Result:** Recovery mechanisms functional

---

**Owner:** QA | **Effort:** 8 hours | **Due:** July 2, 5 PM

**Success Criteria:**
- ✅ All 10 candidates found and validated
- ✅ All 10 mailboxes provisioned successfully
- ✅ All permissions correctly assigned
- ✅ Reporting functional (all formats)
- ✅ Recovery/retry mechanisms working
- ✅ 0 critical issues (minor issues documented)

**Deliverable:** Manual Testing Report (pass/fail per candidate, findings)

---

## WP-3: Performance Baseline Testing (Day 4, 8 hours)

**Objective:** Establish performance metrics for future comparison

**Performance Tests:**

### 3.1 Throughput Test (Morning, 2 hours)
**What:** How many mailboxes can we provision per hour?
- [ ] Provision 10 mailboxes in sequence (using our 10 test accounts)
- [ ] Measure total time
- [ ] Calculate: mailboxes/hour
- [ ] Note any throttling observed
- [ ] Document CPU/memory during provisioning

**Target:** ≥60 mailboxes/hour

**Owner:** DevOps | **Due:** July 3, 12 PM

---

### 3.2 Latency Test (Late Morning, 2 hours)
**What:** Average time per mailbox?
- [ ] Provision 5 additional test accounts individually
- [ ] Measure time for each
- [ ] Calculate average latency
- [ ] Identify slowest operations (EXO call, AD call, reporting, etc.)
- [ ] Document breakdown by operation type

**Target:** ≤3 minutes per mailbox

**Owner:** DevOps | **Due:** July 3, 2 PM

---

### 3.3 Resource Utilization Test (Afternoon, 2 hours)
**What:** CPU, Memory, Disk usage during operations?
- [ ] Monitor during throughput test:
  - [ ] CPU usage (peak, average)
  - [ ] Memory usage (peak, average)
  - [ ] Disk I/O (logs, audit logs)
  - [ ] Network bandwidth (EXO calls)
- [ ] Document peak utilization
- [ ] Identify bottlenecks (if any)

**Target:** CPU <50%, Memory <70%, Disk <80% during peak

**Owner:** DevOps | **Due:** July 3, 5 PM

---

### 3.4 Document Baseline (End of Day)
- [ ] Create performance baseline report
- [ ] Include: Throughput, Latency, Resources, Bottlenecks
- [ ] Document for future v1.1 optimization planning

**Deliverable:** Performance Baseline Report

---

## WP-4: Upgrade Path Validation (Day 5, 4 hours)

**Objective:** Verify v0.8.2 → v0.9.0 upgrade process works safely

**Tasks:**

### 4.1 Prepare Upgrade Test
- [ ] Setup clean staging server with v0.8.2 fully deployed
- [ ] Create test data (existing provisioned mailboxes, configs, audit logs)
- [ ] Backup all data before upgrade

**Effort:** 1 hour | **Due:** July 4, 9 AM

---

### 4.2 Execute Upgrade
- [ ] Uninstall v0.8.2
- [ ] Install v0.9.0
- [ ] Verify module loads correctly
- [ ] Verify all functions accessible

**Effort:** 1 hour | **Due:** July 4, 11 AM

---

### 4.3 Validate Post-Upgrade
- [ ] Verify existing audit logs still readable
- [ ] Verify configurations still valid
- [ ] Verify ScheduledTask still configured
- [ ] Run 2-3 provisioning operations
- [ ] Verify no data loss

**Effort:** 1 hour | **Due:** July 4, 1 PM

---

### 4.4 Test Rollback
- [ ] Restore v0.8.2 from backup
- [ ] Verify rollback successful
- [ ] Verify data integrity after rollback
- [ ] Document rollback procedure

**Effort:** 1 hour | **Due:** July 4, 3 PM

---

**Owner:** DevOps | **Effort:** 4 hours | **Due:** July 4, 5 PM

**Success Criteria:**
- ✅ v0.8.2 → v0.9.0 upgrade completes without error
- ✅ All configurations preserved
- ✅ All functions work post-upgrade
- ✅ No data loss
- ✅ Rollback procedure validated

**Deliverable:** Upgrade Procedure Documentation

---

## WP-5: Documentation Updates (Days 6-9, 12 hours)

**Objective:** Update docs based on Week 1 findings

**Tasks:**

### 5.1 Update USER-GUIDE.md (Days 6-7, 4 hours)
- [ ] Add real-world provisioning example (from testing)
- [ ] Add performance metrics section (based on baseline)
- [ ] Update troubleshooting guide with findings (if any issues found)
- [ ] Add FAQ based on test experience
- [ ] Add upgrade procedure from WP-4

**Owner:** Tech Writer | **Due:** July 8 PM

---

### 5.2 Update ADMIN-GUIDE.md (Days 7-8, 4 hours)
- [ ] Add staging deployment procedures
- [ ] Add performance tuning recommendations
- [ ] Add monitoring setup procedures
- [ ] Add runbook for common scenarios

**Owner:** Tech Writer | **Due:** July 9 PM

---

### 5.3 Update OPERATIONS-RUNBOOK.md (Days 8-9, 4 hours)
- [ ] Add daily health check procedures
- [ ] Add incident response procedures (based on testing)
- [ ] Add recovery procedures
- [ ] Add on-call handoff procedures

**Owner:** Tech Writer | **Due:** July 10 PM

---

**Success Criteria:**
- ✅ All docs updated from real-world findings
- ✅ Examples accurate and tested
- ✅ No broken links
- ✅ All procedures documented

**Deliverable:** Updated Documentation Suite

---

## WP-6: Release Process & Publication (Days 10-15, 8 hours)

**Objective:** Document and execute release process (PSGallery + GitHub)

**Release Process (Three-Tier Model):**

### 6.1 Release Process Documentation (Days 10-11, 3 hours)
- [ ] Document branch strategy: develop → prerelease → main
- [ ] Document version progression: v0.9.0-beta.1 → v0.9.0
- [ ] Document tagging procedure (annotated tags)
- [ ] Document PSGallery publication steps
- [ ] Document GitHub release automation
- [ ] Document dual-remote strategy (origin/azure + github/github)
- [ ] Document release notes template

**Owner:** Release Manager | **Due:** July 11 PM

**Deliverable:** Release Process Documentation

---

### 6.2 Prepare Release (Days 12-13, 2 hours)
- [ ] Update module version: v0.8.2 → v0.9.0
- [ ] Update CLAUDE.md version
- [ ] Update README.md version
- [ ] Prepare release notes (features, fixes, compatibility)
- [ ] Verify no broken links in docs

**Owner:** Release Manager | **Due:** July 13 PM

---

### 6.3 Execute Release (Days 14-15, 3 hours)
- [ ] Merge develop → prerelease
- [ ] Merge prerelease → main
- [ ] Create annotated tag: v0.9.0
- [ ] Push all branches and tags to origin (Azure DevOps)
- [ ] Push all branches and tags to github (GitHub)
- [ ] Publish to PowerShell Gallery
- [ ] Verify published on PSGallery
- [ ] Verify GitHub Releases created
- [ ] Test installation: `Install-Module -Name SharedMailboxProvisioner -RequiredVersion 0.9.0`

**Owner:** Release Manager | **Due:** July 15 PM

---

**Success Criteria:**
- ✅ Release process fully documented
- ✅ v0.9.0 published to PSGallery
- ✅ v0.9.0 available on GitHub Releases
- ✅ Installation works via `Install-Module`
- ✅ Dual-remote sync complete

**Deliverable:** v0.9.0 Released (PSGallery + GitHub)

---

## WP-7: v0.9.0 Release Ready & v1.0.0 Prep (Days 16-21, 12 hours)

**Objective:** Final validation and prepare for v1.0.0 launch

### 7.1 Week 3 Validation (Days 16-17, 4 hours)
- [ ] Test v0.9.0 installation from PSGallery
- [ ] Smoke test v0.9.0 functions
- [ ] Verify GitHub release downloads work
- [ ] Monitor initial user feedback
- [ ] Address any critical issues (if any)

**Owner:** QA | **Due:** July 17 PM

---

### 7.2 Go/No-Go Review (Days 17-18, 4 hours)
- [ ] Review all WP deliverables
- [ ] Verify all success criteria met
- [ ] Steering committee sign-off
- [ ] Go/No-Go decision documented

**Decision Criteria:**
- ✅ GO if: All critical workflows pass, performance acceptable, no blockers
- ❌ NO-GO if: Critical workflow fails, performance unacceptable, unresolved issues

**Owner:** Steering Committee | **Due:** July 18 PM

---

### 7.3 v1.0.0 Launch Preparation (Days 19-21, 4 hours)
- [ ] Schedule v1.0.0 release date
- [ ] Prepare launch announcement
- [ ] Brief support team
- [ ] Setup monitoring for v1.0.0 launch
- [ ] Coordinate launch timeline
- [ ] Finalize v1.0.0 release procedures

**Owner:** Product Manager | **Due:** July 21 PM

---

**Success Criteria:**
- ✅ v0.9.0 fully validated
- ✅ Go/No-Go decision obtained
- ✅ v1.0.0 launch plan finalized
- ✅ Support team ready
- ✅ Monitoring setup complete

**Deliverable:** Go/No-Go Decision Report, v1.0.0 Launch Plan

---

## Overall Success Criteria

**Pre-Release Phase succeeds when:**

✅ **WP-1 Complete:** v0.8.2 deployed to staging, all systems working  
✅ **WP-2 Complete:** All 10 test candidates provisioned, all workflows pass  
✅ **WP-3 Complete:** Performance baseline established and documented  
✅ **WP-4 Complete:** Upgrade path tested, rollback validated  
✅ **WP-5 Complete:** Documentation updated with real-world findings  
✅ **WP-6 Complete:** v0.9.0 released (PSGallery + GitHub)  
✅ **WP-7 Complete:** Go/No-Go decision obtained, v1.0.0 launch plan ready  

---

## Risk Mitigation

| Risk | Mitigation |
|------|-----------|
| **Staging not ready** | Prepare infrastructure Day 1; don't wait |
| **Test candidates delayed** | Pre-order via IT-Shop immediately (by June 30) |
| **Performance issues found** | Document for v1.1; don't block v0.9.0 if acceptable |
| **Upgrade path broken** | Rollback procedure tested; can revert if needed |
| **Release issues** | Test PSGallery publish process early (Day 10) |

---

## Next Steps (Immediate)

### By June 30 (Today)
- [ ] Approve this Implementation Plan
- [ ] Assign owners to each Work Package
- [ ] **PRE-ORDER 10 TEST ACCOUNTS VIA IT-SHOP** (critical!)

### July 1-5 (Week 1)
- [ ] Execute WP-1 (Deployment)
- [ ] Execute WP-2 (Manual Testing)
- [ ] Execute WP-3 (Performance)
- [ ] Execute WP-4 (Upgrade Validation)

### July 8-12 (Week 2)
- [ ] Execute WP-5 (Documentation)
- [ ] Execute WP-6 (Release)

### July 15-21 (Week 3)
- [ ] Execute WP-7 (Final Validation & v1.0.0 Prep)

---

**Pre-Release Phase Implementation Plan: READY TO EXECUTE** ✅

**Timeline:** 3 weeks (July 1-21)  
**Effort:** ~64 person-hours  
**Target:** v0.9.0 released, v1.0.0 launch plan ready
