# SharedMailboxProvisioner – Architectural Decision Records (ADRs)

Zentrale Dokumentation für Architektur-Entscheidungen, die das Projekt massgeblich beeinflussen.

**Konkrete Implementierungs-Regeln:** Siehe [STRUCTURE.md](STRUCTURE.md)

---

## Entscheidungen

### ADR-001: Modulare PowerShell-Architektur für Exchange Online Provisioning

**Status:** [ACCEPTED]

**Context:**
SharedMailboxProvisioner automatisiert kritische Exchange Online Operationen. Monolithische Scripts führen zu:
- Code-Duplikation (mehrere Scripts brauchen gleiche Logik)
- Schwierige Fehlerbehandlung (kein zentraler Ort für Fehler)
- Unzureichende Testbarkeit (ganze Script testen vs. einzelne Funktion)
- Wartungs-Albtraum bei Änderungen (müssen mehrere Scripts updaten)

Exchange Online Provisioning braucht robuste, wiederverwendbare Bausteine für:
- Verbindungs-Management (Connect, Reconnect bei Timeouts)
- Fehlerbehandlung & Retries (Throttling, Transient Errors)
- Logging & Audit (kritisch für Compliance)
- Batch-Operationen (viele Mailboxes parallel)

**Decision:**
Klare Modularität mit 3 Schichten:

1. **Functions Layer** (`functions/Public/` & `functions/Private/`)
   - Einzelne, fokussierte Funktionen (Single Responsibility Principle)
   - PUBLIC: Wiederverwendbare Cmdlets mit vollständiger Help
   - PRIVATE: Interne Helpers mit minimaler Help
   - Beispiel: `New-SharedMailbox`, `Add-SharedMailboxMember`, `_RetryExchangeOperation`

2. **Scripts Layer** (`scripts/`)
   - Orchestrierungs-Scripts, die Functions kombinieren
   - CLI-Entry Points: `Provision-BulkMailboxes.ps1`, `RemoveMailbox.ps1`
   - Kommando-Zeilen-Parsing, Config-Loading, Logging-Setup

3. **Tests Layer** (`tests/`)
   - Unit-Tests pro Funktion: `Test-NewSharedMailbox.ps1`
   - Mock Exchange Online calls (Pester -Mocks)
   - Validiere Error Handling, Retry Logic

**Consequences:**
- (+) Hohe Wiederverwendbarkeit: Funktionen können in mehreren Scripts genutzt werden
- (+) Isolierte Testbarkeit: `Invoke-Pester Test-*.ps1` testet einzelne Funktionen
- (+) Zentrale Fehlerbehandlung: Retry-Logik an einem Ort definiert
- (+) Einfacheres Debugging: Stack-Traces zeigen exakte Fehler-Stelle
- (+) Zukünftige Integration in andere Tools (APIs, Web-UIs) einfacher
- (-) Mehr Initial-Struktur erforderlich
- (-) Function-Status muss gepflegt werden (FUNCTION-STATUS.md)
- (-) Größere Code-Base durch Modularität (vs. Monolith)

**Alternatives:**
- **[REJECTED] Monolithische Scripts:** Schneller initial, aber unmaintainable ab >500 Zeilen Code
- **[REJECTED] Alles in einer `functions.ps1`:** Funktioniert klein, aber unübersichtlich bei >20 Funktionen
- **[CONSIDERED] Klassen-basierte Architektur:** PowerShell-Klassen sind modern, aber Kompatibilität mit PS 5.1 schwierig

---

### ADR-002: PowerShell-Version & Exchange Online Compatibility

**Status:** [ACCEPTED]

**Context:**
Exchange Online Management braucht modernste APIs und Module:

- **EXO Module History:**
  - Legacy: `MSOnline`, `AzureAD` (deprecated, sunset 2024)
  - Old: `ExchangeOnlineManagement` v1.x (slower, REST wrapper)
  - Modern: **ExchangeOnlineManagement v3.x (EXO-V3)** – Performance-optimiert, native cmdlets

- **PowerShell Version Reality:**
  - Windows Server 2016, frühe 2019: Nur PowerShell 5.1 verfügbar
  - Windows Server 2022+, modernes Windows 10/11: PowerShell 7.x möglich
  - Viele Enterprises still on 5.1 (keine neueren Server deployed yet)

- **Feature-Gaps zwischen 5.1 und 7.x:**
  - Parallel Pipelines (7.0+): Kann viele Operationen parallellisieren
  - Null-Coalescing `??` (7.0+): Einfachere Default-Handling
  - Faster Regex: 7.x ~30% schneller
  - UTF-8 by default: 7.x, 5.1 braucht `.NET` Workarounds

**Decision:**
1. **Minimum-Version: PowerShell 5.1**
   - Funktioniert auf allen Windows Server 2016+
   - Erlaubt breite Deployment
   - Kein breaking change bei Update

2. **Target-Version: PowerShell 7.x (optional)**
   - Wenn auf modernen Servern verfügbar, nutze 7.x Features
   - Runtime-Check: `if ($PSVersionTable.PSVersion.Major -ge 7)` für optionale Speedups
   - Parallel Processing für Bulk-Operationen (7.x hat ForEach-Object -Parallel)

3. **Module-Requirement:**
   - **Mandate:** `ExchangeOnlineManagement >= 3.1.0` (EXO-V3 only)
   - Moderne API, bessere Performance, aktiv maintained
   - Fallback auf v2.x = NICHT unterstützt

4. **Compatibility Matrix:**
   | PowerShell | Exchange Module | Status | Notes |
   |------------|-----------------|--------|-------|
   | 5.1 | EXO-V3 3.1+ | ✅ SUPPORTED | Primary target |
   | 7.0-7.2 | EXO-V3 3.1+ | ✅ SUPPORTED | Works, no 7.x-exclusive features needed |
   | 7.3+ | EXO-V3 3.1+ | ✅ OPTIMIZED | Use -Parallel for bulk ops |

**Consequences:**
- (+) Breite Kompatibilität mit Windows Server 2016+ (mindestens 5.1 verfügbar)
- (+) Moderne APIs durch EXO-V3 (bessere Performance, weniger Bugs)
- (+) Zukunftssicher: Kann 7.x Features nutzen wenn verfügbar
- (+) Keine Legacy Module (MSOnline, AzureAD deprecation einfacher handhaben)
- (-) Fallback-Logik erforderlich für 5.1 vs 7.x Features (minimal)
- (-) PowerShell 5.1 Eigenheiten (kein Null-Coalescing, etc.) manchmal workaround-schwierig

**Alternatives:**
- **[REJECTED] PowerShell 7.x mandatory:** Würde ältere Server ausschließen (nicht akzeptabel)
- **[REJECTED] Support alte EXO v2 Module:** Legacy, unmaintained, sehr langsam
- **[CONSIDERED] Über-Engineer für 5.1 Kompatibilität:** Zu viel Fallback-Code

---

### ADR-003: Error Handling & Robustness for Exchange Online

**Status:** [ACCEPTED]

**Context:**
Exchange Online Provisioning schlägt regelmäßig fehl – NICHT wegen Bugs, sondern wegen Cloud-Infrastruktur:

- **Häufige Fehler:**
  - Throttling: Microsoft limitiert Requests (429 Too Many Requests)
  - Transient Errors: Temporäre Netzwerk-Hiccups, Server-Restarts
  - Timeouts: 30-Sekunden-Limit bei REST-Calls
  - Service Degradation: Microsoft plant Maintenance (unangekündigt)

- **Wirkung:**
  - Skript bricht nach 1-2 Retries ab → Provisioning unvollständig
  - User kriegt kryptische Fehlermeldung
  - Manuelles Retry erforderlich (böse für 100+ Mailboxes)

- **Kritikalität:**
  - SharedMailbox-Provisioning ist **kritischer Pfad** (User können nicht arbeiten ohne Mailbox)
  - Fehler müssen **handlebar** sein (retry, nicht fail)
  - Audit-Trail **erforderlich** (was ist schief gelaufen?)

**Decision:**
Explizites Error-Handling mit Retry-Logik nach dem Resilience Pattern:

1. **Try-Catch für alle Exchange Online Calls:**
   ```powershell
   try {
       $mailbox = Get-Mailbox -Identity $smtpAddress -ErrorAction Stop
   } catch {
       # Handle specific error types
       if ($_ -match "Throttling") {
           # exponential backoff
       } elseif ($_ -match "Transient|Timeout") {
           # retry immediately
       } else {
           # log & rethrow
       }
   }
   ```

2. **Retry-Strategie (Exponential Backoff):**
   - **Transient Errors** (429, 503, Timeout): Retry mit exponential backoff
   - **Backoff Formula:** `wait = (2^attempt) * 100ms` + random jitter
   - **Max Retries:** 3 attempts (9-11 Sekunden total)
   - **Beispiel:** 1st wait = 100ms, 2nd = 200ms, 3rd = 400ms (+ random)

3. **Error Classification:**
   - **Retryable:** Throttling (429), Service Unavailable (503), Timeout
   - **Permanent:** Access Denied (403), Invalid Mailbox (404), Bad Request (400)
   - **Unknown:** Log & alert, ask human

4. **Central Helper Function:**
   ```
   _RetryExchangeOperation.ps1
     ├─ Takes: ScriptBlock, MaxRetries, BackoffMs
     ├─ Handles: Retry logic, exponential backoff, logging
     └─ Returns: Result or throws permanent error
   ```

5. **Error Output:**
   - **Never silent fail:** Always log/output what happened
   - `Write-Error` for failures (sets `$?` to false)
   - `Write-Log` for audit trail (timestamps, user context)

**Consequences:**
- (+) Resilient gegen Cloud-Flakiness (selbstheilend bei Transient Errors)
- (+) Bessere Fehlerdiagnose (Unterscheidung retryable vs permanent)
- (+) Zuverlässiges Provisioning (weniger manuelles Retry erforderlich)
- (+) Compliance-ready (vollständige Audit-Logs)
- (-) Mehr Code pro Exchange Online Call (~5-10 Zeilen + Try-Catch)
- (-) Langsamer bei Timeouts (9-11 Sekunden Warten)
- (-) Komplexer zu debuggen (Retry-Logik hinzufügen)

**Alternatives:**
- **[REJECTED] Fail-Fast:** Skript bricht sofort ab – nicht akzeptabel für Provisioning
- **[REJECTED] Max Retries ohne Backoff:** Hammert Server mit Requests – verschlimmert Throttling
- **[CONSIDERED] Circuit Breaker Pattern:** Zu komplex für MVP, erst bei maturity überlegen

---

### ADR-004: Logging & Audit Trail

**Status:** [ACCEPTED]

**Context:**
SharedMailbox-Provisioning ist sicherheitskritisch:

- **Compliance-Anforderungen:**
  - SOX, HIPAA, GDPR: Wer hat Mailbox wann erstellt/geändert?
  - Audit-Trail >= 90 Tage (oft mandatorisch)
  - Unveränderbare Logs (WORM – Write-Once-Read-Many)

- **Operationale Anforderungen:**
  - Debugging: "Warum ist die Provisioning fehlgeschlagen?"
  - Troubleshooting: Stack-Traces, Fehler-Kontexte
  - Alerting: "Wer hat gerade 50 Mailboxes gelöscht?"

- **Sicherheits-Anforderungen:**
  - Access Control: Nur berechtigte Personen provisionen
  - Sensitive Data Protection: Keine Passwords/Tokens in Logs
  - Immutability: Logs können nicht nachträglich gelöscht werden

**Decision:**
Strukturierte Logging mit 2 Streams:

1. **Central `Write-Log` Function** (Privat)
   - Single point of truth für alle Logging
   - Format: `[TIMESTAMP] [LEVEL] [USER] [OPERATION] [STATUS] [MESSAGE]`
   - Beispiel: `[2026-06-29 14:23:15] [INFO] [michel@contoso.com] [New-SharedMailbox] [SUCCESS] Created mailbox sales@contoso.com`

2. **Audit Log** (Compliance & Security)
   - **Location:** `$env:ProgramData\SharedMailboxProvisioner\Audit\audit-YYYY-MM-DD.log`
   - **Rotation:** Daily (new file per day)
   - **Retention:** 90 days (auto-cleanup old files)
   - **What goes in:** CREATE, DELETE, MODIFY, GRANT-ACCESS, REVOKE-ACCESS
   - **No Sensitive Data:** Never log passwords, tokens, keys
   - **User Context:** Always log WHO did it ($env:USERNAME)
   - **Immutable:** Append-only (no edit/delete after written)

3. **Error Log** (Troubleshooting)
   - **Location:** `$env:ProgramData\SharedMailboxProvisioner\Errors\errors-YYYY-MM-DD.log`
   - **Rotation:** Daily
   - **Retention:** 30 days
   - **What goes in:** Exceptions, stack traces, failed operations
   - **User-Friendly Messages:** "Failed to create mailbox 'sales@contoso.com': Throttling error (429). Will retry in 200ms."

4. **Log Levels** (not all persisted):
   | Level | Persisted | Use |
   |-------|-----------|-----|
   | ERROR | Audit + Error | Critical failures |
   | WARN | Audit | Anomalies (unusual operation count, long retry) |
   | INFO | Audit | Normal operations (create, modify, delete) |
   | DEBUG | Never | Verbose output for debugging (pipe to file manually) |
   | VERBOSE | Never | `-Verbose` flag only, not persisted |

5. **Example Log Entries:**
   ```
   # Audit Log (success)
   [2026-06-29 14:23:15] [INFO] [michel@contoso.com] [New-SharedMailbox] [SUCCESS] Created mailbox 'Sales Team' (sales@contoso.com)
   
   # Audit Log (security event)
   [2026-06-29 14:24:00] [WARN] [michel@contoso.com] [Add-SharedMailboxMember] [ANOMALY] Added 10 members in batch (unusual volume)
   
   # Error Log (transient, will retry)
   [2026-06-29 14:25:30] [WARN] [michel@contoso.com] [New-SharedMailbox] [TRANSIENT] Throttling error (429). Retrying in 200ms...
   
   # Error Log (permanent failure)
   [2026-06-29 14:26:15] [ERROR] [michel@contoso.com] [New-SharedMailbox] [FAILED] Access denied: User does not have permissions to create mailbox
   ```

**Consequences:**
- (+) Vollständige Audit-Trail (Compliance-ready)
- (+) Debugging & Troubleshooting einfacher (Stack-Traces, Context)
- (+) Security-aware (kein Sensitive Data in Logs)
- (+) Immutable logs (WORM, nicht manipulierbar)
- (-) Log-Rotation & Cleanup-Script erforderlich (90-day retention)
- (-) Disk-Space: ~1-2 MB pro 1000 operations (monitor required)
- (-) Performance Impact: Minimal (append-only, asynchron möglich)

**Alternatives:**
- **[REJECTED] Console Output Only:** Keine Persistierung – nach Script-Ende verloren
- **[REJECTED] Cloud Logging (Azure Monitor):** Overkill für MVP, licensing costs
- **[CONSIDERED] Syslog / Eventlog:** Windows Eventlog ist okay, aber file-based einfacher zu implementieren

---

### ADR-005: Configuration Management

**Status:** [ACCEPTED]

**Context:**
SharedMailboxProvisioner muss über mehrere Tenants/Organizations arbeiten:

- **Non-Sensitive Config** (Tenant-spezifisch):
  - `TenantId`, `OrganizationName`, `PrimarySmtpDomain`
  - `DefaultMailboxQuota`, `ComplianceLabels`
  - `DelegatedAdministration` (Enable/Disable)
  - Unterschiedliche Settings für dev/test/prod

- **Sensitive Config** (Credentials & Secrets):
  - Service Account Credentials (für Provisioning-Scripts)
  - Azure Key Vault URIs
  - Audit Log Encryption Keys (future)
  - **Niemals hardcoded**, niemals in Git

- **Environment-Variabilität:**
  - Lokal (Dev Machine): Credential Manager
  - Test: Azure Key Vault (test tenant)
  - Prod: Azure Key Vault (prod tenant, RBAC-protected)

**Decision:**
Zwei-Schichten-Konfiguration:

1. **Non-Sensitive Config: JSON-Dateien**
   - Location: `$PSScriptRoot\..\config\config.json` (per environment)
   - Per Environment:
     - `config.dev.json` (local development)
     - `config.test.json` (CI/CD testing)
     - `config.prod.json` (production)
   - **Loaded at Runtime:**
     ```powershell
     $config = Get-Content -Path "config.$env.json" -Raw | ConvertFrom-Json
     ```
   - **Not in Git:** All `config.*.json` → `.gitignore`
   - **Example:**
     ```json
     {
       "TenantId": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
       "OrganizationName": "Contoso",
       "PrimarySmtpDomain": "contoso.com",
       "DefaultMailboxQuota": "50GB",
       "ComplianceLabels": ["Internal", "Confidential"],
       "DelegatedAdministration": true,
       "LogRetentionDays": 90
     }
     ```

2. **Sensitive Config: Credential Manager / Azure Key Vault**
   - Local Dev: `Get-StoredCredential` (Credential Manager)
   - Prod: `Get-AzKeyVaultSecret` (Azure Key Vault)
   - **Never in Environment Variables** (visible in `Get-ChildItem env:` & logs)
   - **Loaded via Helper Function:**
     ```powershell
     $cred = Get-ServiceAccountCredential -EnvironmentName "prod"
     ```

3. **Config Validation at Startup:**
   - Verify required keys present
   - Verify format correctness (GUIDs, domains, etc.)
   - Verify Azure KV access (if applicable)
   - **Fail Fast:** If config invalid, error before doing anything

4. **Config Hierarchy** (precedence):
   ```
   Environment Variable (if set, overrides all)
       ↓
   Command-Line Parameter (if provided)
       ↓
   config.{env}.json (file)
       ↓
   Hardcoded Defaults (if sensible)
   ```

5. **Example Structure:**
   ```
   SharedMailboxProvisioner/
   ├── config/
   │   ├── config.template.json      # Template (in Git)
   │   ├── config.dev.json           # .gitignore (local only)
   │   ├── config.test.json          # .gitignore (test only)
   │   └── config.prod.json          # .gitignore (prod only)
   └── functions/Private/
       └── Get-Configuration.ps1     # Load & validate config
   ```

**Consequences:**
- (+) Portabilität zwischen Umgebungen (same code, different config)
- (+) Keine Secrets im Code (sicherer, auditable)
- (+) Validation at startup (fail-fast, less mysterious errors)
- (+) Environment-specific tunables (dev != prod)
- (-) Config files must be managed separately (not in Git)
- (-) More setup required for new environments (copy template, fill values)
- (-) Potential for config drift (prod config out-of-sync)

**Alternatives:**
- **[REJECTED] All Hardcoded:** Fast initial, unmaintainable with multiple environments
- **[REJECTED] Environment Variables Only:** Security risk (visible in logs, `Get-ChildItem env:`)
- **[CONSIDERED] Azure App Configuration:** Overkill for MVP, revisit for scale-up

---

## Zukünftige ADRs (TBD)

- ADR-006: Pagination & Bulk Operations
- ADR-007: Mail-Flow & Automation Policies
- ADR-008: Delegated Access & Permissions
- ADR-009: Testing Strategy (Unit/Integration/E2E)
- ADR-010: Output Handling (ASCII-only per ADR-010 in WinHarden)

