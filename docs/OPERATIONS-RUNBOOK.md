# SharedMailboxProvisioner - Operations Runbook

**Version:** v0.9.0-beta.1 | **Status:** Pre-Release Phase Active  
**Last Updated:** 2026-07-01

---

## Table of Contents

1. [Daily Operations](#daily-operations)
2. [Incident Response](#incident-response)
3. [Failure Handling](#failure-handling)
4. [Escalation Procedures](#escalation-procedures)
5. [Maintenance Windows](#maintenance-windows)
6. [Performance Troubleshooting](#performance-troubleshooting)
7. [Operational Checklists](#operational-checklists)

---

## Daily Operations

### Morning Health Check (8:00 AM)

```powershell
# 1. System Health
Write-Host "=== System Health Check ===" -ForegroundColor Green
Get-MailboxProvisioningHealth -CheckAll

# Expected output:
# OverallStatus: HEALTHY
# Issues: (empty)

# 2. Last Night's Run
Write-Host "=== Last Night's Provisioning ===" -ForegroundColor Green
Get-MailboxProvisioningStatus | 
  Where-Object { $_.CreatedAt -like "$(Get-Date -Format 'yyyy-MM-dd')*" } | 
  Format-Table SamAccountName, CurrentStatus, CreatedAt -AutoSize

# 3. Pending Mailboxes
Write-Host "=== Pending Provisioning ===" -ForegroundColor Green
Get-MailboxProvisioningStatus | 
  Where-Object { $_.CurrentStatus -eq "PENDING" } | 
  Measure-Object | Select-Object Count

# 4. Failed Mailboxes
Write-Host "=== Failed Mailboxes ===" -ForegroundColor Yellow
Get-MailboxProvisioningStatus | 
  Where-Object { $_.CurrentStatus -like "FAILED*" } | 
  Format-Table SamAccountName, CurrentStatus, ErrorCode -AutoSize
```

### Daily Metrics Review (4:00 PM)

```powershell
# Generate daily metrics
$metrics = Get-MailboxProvisioningMetrics

Write-Host "=== Daily KPI Report ===" -ForegroundColor Cyan
Write-Output "Success Rate: $($metrics.SuccessRate * 100)%"
Write-Output "Avg Time: $($metrics.AvgTimeToCompletion) minutes"
Write-Output "Retry Rate: $($metrics.RetryRatio * 100)%"
Write-Output "Processed Today: $($metrics.ProcessedToday)"

# Alert thresholds:
# - Success Rate < 90%: WARN
# - Avg Time > 10 min: INVESTIGATE
# - Retry Rate > 10%: REVIEW
```

### Weekly Reporting (Friday 3:00 PM)

```powershell
# Generate comprehensive weekly report
$report = Get-MailboxProvisioningReport -StartDate (Get-Date).AddDays(-7) -EndDate (Get-Date)

Export-MailboxAuditLog -StartDate (Get-Date).AddDays(-7) `
  -EndDate (Get-Date) -Format HTML `
  -OutputPath "C:\Reports\Weekly-Report-$(Get-Date -Format 'yyyy-MM-dd').html"

# Review:
# - Total processed
# - Success/failure distribution
# - Common errors
# - Trend analysis
```

---

## Incident Response

### Incident Severity Levels

| Level | Description | Response Time | Example |
|-------|-------------|---|---------|
| **P0 - Critical** | System down, no provisioning | 15 min | No EXO connection, ScheduledTask disabled |
| **P1 - High** | >50% failures, data corruption | 30 min | High failure rate >50% |
| **P2 - Medium** | >10% failures, performance degraded | 1 hour | Slow provisioning, high retry rate |
| **P3 - Low** | Individual mailbox failure | 4 hours | Single mailbox stuck |

### P0 Response: System Down

**Symptom:** No provisioning happening, zero mailboxes processed in last 2 hours

```powershell
# Step 1: Verify ScheduledTask
$task = Get-ScheduledTask -TaskName "SharedMailboxProvisioning"
if ($task.State -ne "Running") {
    Write-Host "[ALERT] Task is $($task.State)" -ForegroundColor Red
    Enable-ScheduledTask -TaskName $task.TaskName
}

# Step 2: Check EXO Connection
# CAVEAT (open, tracked defect - do not skip this): Get-MailboxProvisioningHealth
# -CheckEXO looks for Get-PSSession | Where ConfigurationName -eq "Microsoft.Exchange" -
# a classic remoting marker. Modern EXO-V3 REST-based Connect-ExchangeOnline /
# Connect-ExchangeOnlineEnv sessions do NOT set this marker, so this check can
# report "DISCONNECTED" even when EXO is fully healthy (false positive), or miss
# a real disconnect (false negative). DO NOT treat this as the sole signal during
# P0 triage. Always cross-check with a real, lightweight EXO cmdlet call below.
$exoHealth = Get-MailboxProvisioningHealth -CheckEXO
$exoReallyConnected = $false
try {
    # Adjust cmdlet noun to your configured -Prefix (default "ETH")
    Get-ETHMailbox -ResultSize 1 -ErrorAction Stop | Out-Null
    $exoReallyConnected = $true
}
catch {
    $exoReallyConnected = $false
}

if ($exoHealth.Details.Status -ne "CONNECTED" -or -not $exoReallyConnected) {
    if ($exoHealth.Details.Status -eq "CONNECTED" -and -not $exoReallyConnected) {
        Write-Host "[ALERT] Health check said CONNECTED but live cmdlet call failed - trust the live call" -ForegroundColor Red
    }
    elseif ($exoHealth.Details.Status -ne "CONNECTED" -and $exoReallyConnected) {
        Write-Host "[INFO] Health check says DISCONNECTED but live cmdlet call succeeded - likely the known EXO-V3 health-check gap, connection is actually fine" -ForegroundColor Yellow
    }
    else {
        Write-Host "[ALERT] EXO disconnected - reconnecting" -ForegroundColor Red
        Connect-ExchangeOnlineEnv
    }
}

# Step 3: Verify AD Connection
$adHealth = Get-MailboxProvisioningHealth -CheckAD
if ($adHealth.Details.Status -ne "CONNECTED") {
    Write-Host "[ALERT] AD disconnected" -ForegroundColor Red
    # Contact network team
}

# Step 4: Check Disk Space
$disk = Get-Volume C:
if ($disk.SizeRemaining -lt 1GB) {
    Write-Host "[ALERT] Low disk space" -ForegroundColor Red
    # Cleanup old logs
}

# Step 5: Manual Provisioning Trigger
Start-ScheduledTask -TaskName "SharedMailboxProvisioning"

# Step 6: Monitor for 5 minutes
Start-Sleep -Seconds 300
Get-MailboxProvisioningStatus -ShowTimeline | 
  Where-Object { $_.CreatedAt -gt (Get-Date).AddMinutes(-5) }
```

### P1 Response: High Failure Rate

**Symptom:** >50% mailboxes failing

```powershell
# Step 1: Identify Error Pattern
$failures = Get-MailboxProvisioningStatus | 
  Where-Object { $_.CurrentStatus -like "FAILED*" }

$errorSummary = $failures | Group-Object ErrorCode | 
  Sort-Object Count -Descending

Write-Host "=== Error Distribution ===" -ForegroundColor Yellow
$errorSummary | Format-Table Name, Count

# Step 2: Get Diagnostic Info
Resolve-MailboxProvisioningFailure -DiagnoseAll | 
  Format-Table SamAccountName, ErrorCode, RecommendedAction

# Step 3: Take Action Based on Error Type
switch ($errorSummary[0].Name) {
    "MailboxNotFound" {
        Write-Host "→ Azure AD Connect sync delay" -ForegroundColor Cyan
        Write-Host "→ Waiting for next sync cycle (~60 min)" -ForegroundColor Cyan
        # No action - wait for sync
    }
    "PermissionError" {
        Write-Host "→ Service account lacks permissions" -ForegroundColor Red
        Write-Host "→ ESCALATE: Verify group membership" -ForegroundColor Red
    }
    "GroupNotFound" {
        Write-Host "→ ACL group doesn't exist" -ForegroundColor Red
        Write-Host "→ ESCALATE: Create or update groups" -ForegroundColor Red
    }
}

# Step 4: Pause Provisioning if Critical
Set-MailboxProvisioningSchedule -Disable
Write-Host "⚠️  Provisioning PAUSED - investigate before resuming" -ForegroundColor Red
```

### P2 Response: Performance Degradation

**Symptom:** Provisioning taking >10 minutes per mailbox

```powershell
# Step 1: Check Performance Metrics
$metrics = Get-MailboxProvisioningMetrics

Write-Host "=== Performance Report ===" -ForegroundColor Yellow
Write-Output "Avg Time: $($metrics.AvgTimeToCompletion) min"
Write-Output "Retry Ratio: $($metrics.RetryRatio)%"
Write-Output "Peak Hour: $($metrics.PeakProcessingHour)"

# Step 2: Check Server Resources
Get-Counter -Counter "\Processor(_Total)\% Processor Time", `
                     "\Memory\Available MBytes" | Format-Table

# Step 3: Optimize if Needed
if ($metrics.AvgTimeToCompletion -gt 10) {
    Write-Host "→ Reducing batch size" -ForegroundColor Cyan
    # Reduce batch from 10 to 5 mailboxes
}

# Step 4: Monitor Trend
$trend = Get-MailboxProvisioningMetrics | Select-Object TrendAnalysis7Day
Write-Host "7-day trend: $($trend.TrendAnalysis7Day)" -ForegroundColor Cyan
```

### P3 Response: Single Mailbox Failure

**Symptom:** One mailbox stuck in FAILED status

```powershell
# Get mailbox details
$mailbox = Get-MailboxProvisioningStatus -SamAccountName "smbx_001" -ShowTimeline

# Diagnose
$diagnosis = Resolve-MailboxProvisioningFailure -SamAccountName "smbx_001"

Write-Host "=== Failure Analysis ===" -ForegroundColor Cyan
Write-Output "Error: $($diagnosis.ErrorCode)"
Write-Output "Can Retry: $($diagnosis.CanRetry)"
Write-Output "Action: $($diagnosis.RecommendedAction)"

# If retryable
if ($diagnosis.CanRetry) {
    Invoke-MailboxProvisioningRetry -SamAccountName "smbx_001"
    Write-Host "✓ Retry triggered" -ForegroundColor Green
} else {
    Write-Host "⚠️  Manual intervention required" -ForegroundColor Yellow
    Write-Host "Action: $($diagnosis.RecommendedAction)" -ForegroundColor Yellow
}
```

---

## Failure Handling

### Automatic Retry Strategy

**Current configuration:**
- Max retries: 5 attempts
- Retry delay: 5 minutes between attempts
- Exponential backoff (5m → 10m → 20m → 40m)

```powershell
# View retry status
Get-MailboxProvisioningStatus | 
  Where-Object { $_.RetryCount -gt 0 } | 
  Format-Table SamAccountName, RetryCount, LastRetryAt
```

### Manual Retry Procedures

#### Scenario 1: Retry Single Mailbox

```powershell
# Check before retry
$status = Get-MailboxProvisioningStatus -SamAccountName "smbx_001"
Write-Host "Current status: $($status.CurrentStatus)" 
Write-Host "Retries: $($status.RetryCount)/$($status.MaxRetries)"

# Retry if within limit
if ($status.RetryCount -lt $status.MaxRetries) {
    Invoke-MailboxProvisioningRetry -SamAccountName "smbx_001"
    Write-Host "✓ Retrying..." -ForegroundColor Green
} else {
    Write-Host "❌ Max retries reached - ESCALATE" -ForegroundColor Red
}
```

#### Scenario 2: Retry All Failed

```powershell
# Count failures
$failures = Get-MailboxProvisioningStatus | 
  Where-Object { $_.CurrentStatus -like "FAILED*" }

Write-Host "Found $($failures.Count) failed mailboxes" -ForegroundColor Yellow

# Batch retry
Invoke-MailboxProvisioningRetry -RetryAll

# Monitor progress
for ($i = 1; $i -le 5; $i++) {
    $status = Get-MailboxProvisioningStatus | 
      Where-Object { $_.Status -eq "PENDING_RETRY" } | 
      Measure-Object
    
    Write-Host "[$i/5] Pending retries: $($status.Count)"
    Start-Sleep -Seconds 60
}
```

#### Scenario 3: Force Retry (Override Limit)

```powershell
# CAUTION: Only use if specifically approved

$mailbox = "smbx_001"
$status = Get-MailboxProvisioningStatus -SamAccountName $mailbox

Write-Host "⚠️  OVERRIDE: Retrying mailbox beyond max limit" -ForegroundColor Red
Write-Host "Current retries: $($status.RetryCount)/$($status.MaxRetries)" -ForegroundColor Red

Invoke-MailboxProvisioningRetry -SamAccountName $mailbox -Force

Write-Host "✓ Force retry completed - monitor closely" -ForegroundColor Yellow
```

### Dead Letter Handling

For mailboxes that exhaust all retries:

```powershell
# Find dead-lettered mailboxes
$deadLetters = Get-MailboxProvisioningStatus | 
  Where-Object { $_.RetryCount -ge $_.MaxRetries }

# Export for manual review
$deadLetters | Export-Csv "C:\DeadLetters-$(Get-Date -Format 'yyyy-MM-dd').csv" -NoTypeInformation

# Manual Investigation Checklist:
# - Verify AD user still exists
# - Check if email already provisioned
# - Verify ACL group exists
# - Check Exchange Online quota
# - Verify no duplicate SamAccountName
```

---

## Escalation Procedures

### When to Escalate

| Condition | Escalate To | Timeline |
|-----------|-------------|----------|
| System down >1 hour | Infrastructure Team | Immediately |
| >75% failure rate | Engineering + Infrastructure | 30 min |
| Disk/memory critical | System Admin | Immediately |
| EXO service degraded | Microsoft Support | As needed |
| Data corruption detected | Engineering Lead | Immediately |

### Escalation Template

**Caveat:** as noted in the P0 procedure above, `Get-MailboxProvisioningHealth -CheckEXO`'s "EXO Connection" status is not reliable against EXO-V3 REST sessions (known, tracked gap). When filling in the Investigation block below, pair it with a live cmdlet result (e.g. `Get-ETHMailbox -ResultSize 1`) so the escalation report isn't built on a potentially false signal.

```powershell
# Prepare escalation report
$exoLiveOk = $false
try { Get-ETHMailbox -ResultSize 1 -ErrorAction Stop | Out-Null; $exoLiveOk = $true } catch { $exoLiveOk = $false }

$report = @{
    TimeDetected = Get-Date
    Severity = "P1"
    Symptoms = "System not provisioning mailboxes"
    Investigation = @(
        "Checked ScheduledTask: $(Get-ScheduledTask -TaskName 'SharedMailboxProvisioning' | Select -ExpandProperty State)"
        "EXO Connection (health check, may be unreliable - see caveat): $((Get-MailboxProvisioningHealth -CheckEXO).Details.Status)"
        "EXO Connection (live cmdlet cross-check): $(if ($exoLiveOk) { 'CONNECTED' } else { 'FAILED' })"
        "AD Connection: $((Get-MailboxProvisioningHealth -CheckAD).Details.Status)"
    )
    ProposedAction = "Restart service account session, re-run ScheduledTask"
    Resources = @(
        "Failure log: audit-2026-06-30.log"
        "Metrics: attached report"
        "Status snapshot: attached CSV"
    )
}

# Send to escalation team with:
# - System health report
# - Metrics summary (last 24 hours)
# - Failure analysis
# - Current backlog status
```

---

## Maintenance Windows

### Planned Maintenance

**Schedule:** 2nd Sunday, 2:00-4:00 AM (off-hours)

```powershell
# Pre-maintenance checklist
# - Backup all data
# - Notify stakeholders
# - Verify rollback plan

# During maintenance
Set-MailboxProvisioningSchedule -Disable
Write-Host "System maintenance: Provisioning DISABLED" -ForegroundColor Yellow

# [Perform updates]

Set-MailboxProvisioningSchedule -Enable
Start-ScheduledTask -TaskName "SharedMailboxProvisioning"

# Post-maintenance verification
Start-Sleep -Seconds 300  # Wait 5 min for first run
$status = Get-MailboxProvisioningHealth -CheckAll
if ($status.OverallStatus -eq "HEALTHY") {
    Write-Host "✓ Maintenance complete - system healthy" -ForegroundColor Green
}
```

### Emergency Maintenance

**Trigger:** Critical issues that cannot wait

```powershell
# Immediate shutdown
Set-MailboxProvisioningSchedule -Disable
Write-Host "⚠️  EMERGENCY: Provisioning DISABLED" -ForegroundColor Red

# Notify team
# Fix issue
# Test thoroughly before re-enabling
# Resume with monitoring
```

---

## Performance Troubleshooting

### Slow Provisioning

**Diagnosis:**

```powershell
# Check how long each step takes
$status = Get-MailboxProvisioningStatus -ShowTimeline

# Parse timeline
$timeline = $status.Timeline -split " > "
foreach ($event in $timeline) {
    Write-Host $event -ForegroundColor Cyan
}

# Typical timeline:
# [CREATED] 10:00:00 (immediate)
# [MAILBOX_CREATED] 10:02:00 (2 min - EXO latency)
# [COMPLETED] 10:05:00 (3 min - permissions)
# Total: ~5 minutes
```

**Solutions:**

```powershell
# If >10 minutes total:
# 1. Check EXO latency (might be external)
# 2. Reduce batch size (less parallelism)
# 3. Check network bandwidth
# 4. Verify service account permissions

# Monitor specific metric
$metrics = Get-MailboxProvisioningMetrics
Write-Host "Average: $($metrics.AvgTimeToCompletion) min" -ForegroundColor Cyan
```

### High CPU Usage

```powershell
# During provisioning run
Get-Process powershell | 
  Select-Object ProcessName, Id, CPU, WorkingSet | 
  Sort-Object CPU -Descending

# Solutions:
# - Reduce batch size (5 instead of 10)
# - Increase ScheduledTask interval (30 min instead of 15)
# - Run during off-hours if consistently high
```

### Disk Space Issues

```powershell
# Check log directory
Get-ChildItem "$env:ProgramData\SharedMailboxProvisioner\Audit" | 
  Measure-Object -Sum -Property Length | 
  Select-Object Count, @{N="Size(GB)"; E={$_.Sum/1GB}}

# Archive old logs if >10GB
Get-ChildItem "$env:ProgramData\SharedMailboxProvisioner\Audit\*.log" -OlderThan (Get-Date).AddDays(-30) | 
  Move-Item -Destination "\\fileserver\archive\provisioner-logs"
```

---

## Operational Checklists

### Daily Checklist (5 min)

```
[ ] Morning health check passed
[ ] No critical failures overnight
[ ] ScheduledTask running on schedule
[ ] Disk space OK (>10GB free)
[ ] Review pending provisioning count
```

### Weekly Checklist (15 min)

```
[ ] Weekly report generated
[ ] Success rate >= 90%
[ ] No P1 incidents this week
[ ] Backup verified (restore test if possible)
[ ] Logs archived if needed
[ ] Performance trending OK
```

### Monthly Checklist (30 min)

```
[ ] Security audit: Check service account activity
[ ] Capacity planning: Review growth rate
[ ] Cost analysis: Mailbox count vs. licenses
[ ] Documentation updated
[ ] Disaster recovery drill (simulate failure)
[ ] Update runbook if needed
```

### Quarterly Checklist

```
[ ] Security review: Audit account permissions
[ ] Performance optimization: Review bottlenecks
[ ] Update module to latest version
[ ] Test upgrade path with non-prod instance
[ ] Team training: Refresh incident response
[ ] Plan for next quarter operations
```

---

## On-Call Procedures

### On-Call Responsibilities

1. **Availability:** 24/7 for P0/P1 incidents
2. **Response Time:** P0: 15 min, P1: 30 min, P2: 1 hour
3. **Escalation:** After 1 hour unresolved → escalate
4. **Communication:** Update team every 30 min

### Handoff Process

```
Outgoing On-Call:
  - 5 min before end: Brief incoming on-call
  - Show: Current status, any open incidents, overnight watch items
  - Incoming: Confirm understanding, note contact info

Incoming On-Call:
  - Immediately: Run daily health check
  - Verify: System healthy, no urgent issues
  - Review: Last 24 hours incident log
```

---

**Document Version:** 1.1 | **Last Updated:** 2026-07-01
