# SharedMailboxProvisioner – Release Process

**Based on**: Three-Tier Release Model (inspired by WinHarden)  
**Status**: Ready for Phase Alpha release  
**Last Updated**: 2026-06-29

---

## Overview

This document describes the complete release workflow for SharedMailboxProvisioner from development through PowerShell Gallery publication.

### Release Tiers

```
develop (Active development)
    ↓
prerelease (Beta testing)
    ↓
main (Production stable)
```

| Branch | Type | Cadence | Releases | Gallery |
|--------|------|---------|----------|---------|
| `develop` | Integration | Daily | None | ❌ No |
| `prerelease` | Testing | Weekly | v1.x.x-beta.* | ❌ No |
| `main` | Production | As needed | v1.x.x (stable) | ✅ Yes |

---

## Phase 1: Development (develop branch)

### Workflow

```powershell
# Update from main
git checkout develop
git pull origin develop

# Create feature branch (optional)
git checkout -b feature/tier2-helpers

# Work on new feature
# ... edit files, test, commit ...

git add <files>
git commit -m "Feat: Description of feature"

# Push to develop
git push origin develop
git push github develop  # Mirror to GitHub
```

### Requirements

✅ **Before each commit**:
- Run build validation: `.\build.ps1 -Validate`
- Run unit tests: `Invoke-Pester tests/`
- Pre-commit hook blocks violations

✅ **Commit message format**:
```
<Type>: <Description>

Optional longer explanation if needed.
```

**Types**: `Feat`, `Fix`, `Refactor`, `Docs`, `Test`, `Chore`

### Example: Tier 2 Development

```
Feat: Implement _ParseSharedMailboxGroupDescription helper
Fix: K&R bracing in _RetryExchangeOperation
Refactor: Extract validation logic to helpers
Test: Add 15 test cases for group parsing
Docs: Update FUNCTION-STATUS.md with Tier 2 progress
```

### Merging develop → prerelease

When a feature tier is **complete and tested**:

```powershell
# 1. Create prerelease branch
git checkout prerelease
git pull origin prerelease

# 2. Merge develop
git merge develop
git push origin prerelease && git push github prerelease

# 3. Create beta tag
git tag -a v1.0.0-beta.1 -m "Release: v1.0.0-beta.1 - Phase Alpha Tier 2

## What's New
- Feat: Group validation helper functions
- Feat: ACL group discovery from AD
- Fix: Handle invalid group descriptions

## Testing Focus
- Test group discovery with various AD structures
- Test validation with edge cases
- Test error handling for missing groups"

git push origin v1.0.0-beta.1
git push github v1.0.0-beta.1
```

**GitHub Automation**: Release created (Pre-release checkbox enabled)

---

## Phase 2: Pre-Release Testing (prerelease branch)

### Timeline

Each pre-release has a **1-2 week testing window**:

| Day | Activity | Owner |
|-----|----------|-------|
| 0-1 | Beta release created, distribution | DevOps |
| 2-5 | Testing in staging environment | QA + Dev |
| 6-10 | Bugfix iterations (minor releases) | Dev |
| 11-14 | Final validation, release candidate prep | QA |
| 15 | Release candidate tag, production readiness review | Lead |

### Bugfix Process (during prerelease)

If bugs found during testing:

```powershell
# 1. Fix on prerelease branch
git checkout prerelease
# ... fix code ...
git commit -m "Fix: Describe the bug fix"

# 2. Update patch version
# Edit: SharedMailboxProvisioner.psd1
# ModuleVersion = '1.0.0'  # Already correct, no change needed

# 3. Create new beta tag
git tag -a v1.0.0-beta.2 -m "Release: v1.0.0-beta.2 - Bugfix

## Fixes
- Fix: Handle null group descriptions
- Fix: Improve error message clarity"

git push origin v1.0.0-beta.2
git push github v1.0.0-beta.2

# 4. Update develop to match
git checkout develop
git merge prerelease
git push origin develop && git push github develop
```

**Do NOT release to PowerShell Gallery** during prerelease phase!

### Testing Checklist

Before moving to main/stable:

- [ ] All unit tests pass (100%)
- [ ] Build validation passes
- [ ] Manual integration testing complete
- [ ] Documentation is accurate and current
- [ ] No security issues or hardcoded credentials
- [ ] Performance acceptable
- [ ] Rollback procedure documented
- [ ] Code review approved (2+ reviewers)
- [ ] Release notes complete
- [ ] Version number finalized

---

## Phase 3: Stable Release (main branch)

### Prerequisites

Before merging to main:
1. ✅ All prerelease testing complete
2. ✅ Bugfixes resolved
3. ✅ Code review approved
4. ✅ Version number decided

### Release to Production

```powershell
# 1. Merge prerelease → main
git checkout main
git pull origin main
git merge prerelease

# 2. Push to remotes
git push origin main
git push github main

# 3. Create stable release tag
git tag -a v1.0.0 -m "Release: v1.0.0 - Phase Alpha Complete

## What's New
- Feature: Active Directory candidate discovery with flexible filtering
- Feature: Comprehensive data quality validation (RFC 5321, duplicates, etc.)
- Feature: Centralized logging with retention policies
- Feature: Connection pooling & retry logic for Exchange Online
- Feature: JSON-based configuration with Azure KV integration

## Installation
Install-Module -Name SharedMailboxProvisioner -RequiredVersion 1.0.0
Get-Help Connect-ExchangeOnlineEnv -Full

## Compatibility
- Windows Server 2019, 2022, 2025
- PowerShell 5.1, 7.x
- Exchange Online (EXO-V3 module v3.1.0+)
- Active Directory Module (RSAT)

## Known Issues
- None for v1.0.0

## Upgrade Path
From v0.x: Update module via Install-Module -Force

## Support
See SETUP.md for troubleshooting and support contacts"

# 4. Push tag
git push origin v1.0.0
git push github v1.0.0
```

**GitHub Automation**:
- Release created (Final Release, not Pre-release)
- ZIP download automatically generated

### PowerShell Gallery Publication

**Automatic** (~4-5 minutes after tag push):

```powershell
# GitHub Actions workflow triggers:
# 1. Detects v1.0.0 tag on main
# 2. Publishes to PowerShell Gallery
# 3. Generates module documentation
# 4. Updates README with version

# Verify publication
Find-Module -Name SharedMailboxProvisioner
Install-Module -Name SharedMailboxProvisioner -RequiredVersion 1.0.0
```

**Gallery Listing Policy** (Critical):
- ✅ Stable versions (v1.x.x) published → listed, visible
- ❌ Pre-release (v1.x.x-beta.*) NOT published
- ❌ Release candidates (v1.x.x-rc.*) NOT published
- **Why**: Users see only production-ready versions on first search

---

## Version Management

### Semantic Versioning

```
MAJOR.MINOR.PATCH-PRERELEASE.BUILD
1.0.0-beta.1
│ │ │  └──┬──┘  └────┬─────┘
│ │ │    │           │
│ │ │    │           └─ Build metadata (optional)
│ │ │    └──────────── Pre-release identifier
│ │ └────────────────── Patch (bugfixes)
│ └──────────────────── Minor (features)
└────────────────────── Major (breaking changes)
```

### Version Update Locations

Files to update for each release:

1. **SharedMailboxProvisioner.psd1**
   ```powershell
   ModuleVersion = '1.0.0'
   ```

2. **CLAUDE.md** (top)
   ```
   **Version:** v1.0.0
   **Status:** [OK] ...
   ```

3. **README.md**
   ```
   ## Status
   **Version**: v1.0.0
   ```

### Increment Rules

| Change | Update | Example |
|--------|--------|---------|
| **Bugfixes only** | PATCH | 1.0.0 → 1.0.1 |
| **New features** | MINOR | 1.0.0 → 1.1.0 |
| **Breaking changes** | MAJOR | 1.x → 2.0.0 |
| **Beta testing** | PATCH+beta | 1.0.0-beta.1 → 1.0.0-beta.2 |

---

## Release Checklist

### Before moving develop → prerelease

- [ ] All code reviewed
- [ ] Build validation: PASSED
- [ ] All unit tests: PASSED (100%)
- [ ] No hardcoded credentials
- [ ] Documentation updated
- [ ] FUNCTION-STATUS.md updated
- [ ] No outstanding critical/high issues
- [ ] Git history clean (meaningful commits)

### Before moving prerelease → main

- [ ] Prerelease testing: COMPLETE
- [ ] Bug fixes: RESOLVED
- [ ] Code review: APPROVED (2+ reviewers)
- [ ] Version number: FINALIZED
- [ ] Release notes: WRITTEN
- [ ] Module manifest: UPDATED
- [ ] README: CURRENT
- [ ] CHANGELOG: CREATED (optional, for v1.0.0)

### After main merge

- [ ] Tag created and pushed
- [ ] GitHub Release created
- [ ] PowerShell Gallery publication: VERIFIED
- [ ] Documentation deployed
- [ ] Team notified of new version
- [ ] Monitoring alerts active

---

## Timeline Examples

### Typical Phase Alpha Release

```
Week 1:
  Mon-Fri: Tier 2 + 3 implementation (develop)

Week 2:
  Mon:     Merge develop → prerelease, create v1.0.0-beta.1
  Tue-Thu: Testing, bugfixes (v1.0.0-beta.2, beta.3)
  Fri:     Code review complete

Week 3:
  Mon:     Merge prerelease → main, create v1.0.0
  Mon+5min: Automatically published to PowerShell Gallery
  Tue:     Announce release
```

### Phase Beta Release (example)

```
Week 6-7: Exchange provisioning functions (develop)
Week 8:   Prerelease testing (prerelease)
Week 9:   Main release (main) → v1.1.0
```

---

## Rollback Procedure

### If serious issue found after release

```powershell
# 1. Create hotfix branch from main
git checkout main
git checkout -b hotfix/issue-description

# 2. Fix the issue
# ... edit code ...
git commit -m "Fix: Critical issue in v1.0.0"

# 3. Merge back to main
git checkout main
git merge hotfix/issue-description

# 4. Create hotfix tag
git tag -a v1.0.1 -m "Hotfix: v1.0.1 - Critical fix

## Issue
[Description of critical bug]

## Fix
[What was changed]"

git push origin v1.0.1
git push github v1.0.1

# 5. Also merge to develop
git checkout develop
git merge main
git push origin develop && git push github develop
```

**PowerShell Gallery**: Automatically updated with v1.0.1 (hotfix version)

---

## Remote Configuration

### Git Remotes

```bash
# Primary (Azure DevOps)
git remote add origin https://dev.azure.com/org/project/_git/SharedMailboxProvisioner

# Secondary (GitHub mirror)
git remote add github https://github.com/org/SharedMailboxProvisioner

# Verify
git remote -v
```

### Sync Strategy

All branches pushed to both remotes:

```powershell
git push origin main       # Primary
git push github main       # Mirror

git push origin prerelease
git push github prerelease

git push origin develop
git push github develop

# Tags too
git push origin v1.0.0
git push github v1.0.0
```

---

## FAQ

### Q: When should we release to PowerShell Gallery?
**A**: Only when merging prerelease → main (stable versions only). Never publish beta/RC versions.

### Q: Can we skip the prerelease phase?
**A**: No. Prerelease testing catches bugs before production. Minimum 3-5 days.

### Q: What if we need a hotfix?
**A**: Create from `main`, merge back to both `main` and `develop`, tag with patch version (v1.0.1).

### Q: How do we handle breaking changes?
**A**: Create MAJOR version bump, document migration path, announce prominently.

### Q: Who approves releases?
**A**: Project Lead + 2 code reviewers minimum. For hotfixes: Tech Lead approval required.

---

## Support & Documentation

- **[CLAUDE.md](CLAUDE.md)** – Collaboration guidelines
- **[DECISIONS.md](DECISIONS.md)** – Architectural decisions (ADRs)
- **[STRUCTURE.md](STRUCTURE.md)** – Code standards
- **[docs/SETUP.md](docs/SETUP.md)** – Developer setup
- **[GitHub Actions](.github/workflows/)** – CI/CD pipelines (to be created)

---

**Last Updated**: 2026-06-29  
**Maintained By**: Development Team  
**Status**: Ready for Phase Alpha releases
