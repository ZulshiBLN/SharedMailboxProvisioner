# SharedMailboxProvisioner – STRUCTURE.md

Projekt-spezifische Struktur- und Organisationsregeln für SharedMailboxProvisioner.

---

## 1. VERZEICHNIS-STRUKTUR

```
SharedMailboxProvisioner/
├── functions/              # Wiederverwendbare Funktionen
│   ├── Public/            # Exportierte (public) Funktionen
│   └── Private/           # Interne (private) Helper-Funktionen
├── scripts/               # Standalone-Scripts & CLI-Einsatzpunkte
├── tests/                 # Unit-Tests per Funktion
├── docs/                  # Dokumentation & Guides
├── build.ps1              # Build & Validation
├── SharedMailboxProvisioner.psd1  # Module Manifest
├── SharedMailboxProvisioner.psm1  # Module Root
├── CLAUDE.md              # Collaboration Rules
├── DECISIONS.md           # Architectural Decision Records
├── STRUCTURE.md           # Implementierungs-Regeln (dieses Dokument)
└── README.md              # Projekt-Überblick
```

**Regel 1.1:** Funktionen → `functions/Public/` oder `functions/Private/`
**Regel 1.2:** Scripts → `scripts/` (Orchestrierung, CLI-Einsatzpunkte)
**Regel 1.3:** Tests → `tests/` (pro Funktion eine Test-Datei)

---

## 2. DESIGN-PRINZIPIEN

**Regel 2.1:** Scripts müssen modular aus Funktionen aufgebaut sein
- Keine Logik direkt in Scripts → in Funktionen auslagern
- Scripts orchestrieren & stellen CLI-Interface bereit

**Regel 2.2:** Funktionen müssen allgemeingültig & wiederverwendbar sein
- High Reuse Value: Funktion kann in mehreren Kontexten verwendet werden
- Single Responsibility Principle (SRP)
- Keine Abhängigkeiten auf spezifische Umgebungen

---

## 3. FUNKTIONS-ANFORDERUNGEN

Performance-optimiert, dokumentiert, robust:

**Regel 3.1:** Comment-based Help für alle Funktionen (PUBLIC vs PRIVATE unterschiedlich)

### PUBLIC Funktionen (keine `_` prefix)

Vollständige Help erforderlich:
- `.SYNOPSIS` (Zusammenfassung, 1-2 Zeilen)
- `.DESCRIPTION` (Detaillierte Erklärung)
- `.PARAMETER` (Für jeden Parameter)
- `.EXAMPLE` (Mindestens 1 Anwendungsbeispiel)
- `.NOTES` (Dependencies, Requirements, etc.)

**Enforcement:** PSScriptAnalyzer Regel `PSProvideCommentHelp` (Fehler)

### PRIVATE Funktionen (mit `_` prefix)

Minimal-Help erforderlich:
- `.SYNOPSIS` (Zusammenfassung, 1-2 Zeilen)
- ODER aussagekräftige Inline-Kommentare `# ...`

**Grund:** Private Funktionen sind interne Helpers (keine public API)
**Enforcement:** PSScriptAnalyzer wird nicht auf private Funktionen angewendet

---

## 4. FEHLERBEHANDLUNG

**Regel 4.1:** Explizites Error-Handling für alle Exchange Online-Aufrufe
```powershell
try {
    $mailbox = Get-Mailbox -Identity $Identity -ErrorAction Stop
} catch {
    Write-Error "Failed to retrieve mailbox: $_"
    return $false
}
```

**Regel 4.2:** Aussagekräftige Error-Messages
- Nicht nur Exception dumpen
- Context mitgeben: Was wurde versucht? Was ist schiefgelaufen?

**Regel 4.3:** Keine stummen Fehler
- Immer zu Logs/Output schreiben
- `Write-Error` für Fehler (setzt `$?` zu `$false`)

---

## 5. LOGGING & AUDIT

**Regel 5.1:** Zentrale `Write-Log` Funktion für alle Aktionen
- Timestamp, Level (INFO/WARN/ERROR)
- User-Context (wer hat das ausgelöst?)
- Operation-Details (was wurde gemacht?)

**Regel 5.2:** Keine sensiblen Daten in Logs
- Keine Passwords, Tokens, Keys
- Email-Adressen anonymisieren wenn möglich

---

## 6. PARAMETER-VALIDIERUNG

**Regel 6.1:** Externe Eingaben validieren (User-Input, Parameters)
```powershell
param(
    [Parameter(Mandatory=$true)]
    [ValidatePattern('^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$')]
    [string]$EmailAddress
)
```

**Regel 6.2:** Interne Code-Garantien vertrauen
- Nicht über-validieren wenn Code selbst validiert hat

---

## 7. OUTPUT-HANDLING

**Regel 7.1:** ASCII-only Output Strings
- Alle Output-Strings verwenden **AUSSCHLIESSLICH ASCII-Zeichen**
- NICHT verwenden: Unicode Symbole (✓, ✗, •, etc.) oder Emoji
- STATTDESSEN: [OK]/[ERROR]/[WARN]/[INFO], *, -, #, etc.

**Grund:** PowerShell 5.1 + Windows UTF-8 Encoding erzeugt Ausgabe-Korruption

**Regel 7.2:** Richtige Output-Cmdlets nutzen
- `Write-Output` für normale Ausgaben (kann gepipet werden)
- `Write-Verbose` für Debug-Info (gesteuert via `-Verbose` Flag)
- `Write-Error` nur für echte Fehler
- **`Write-Host` VERMEIDEN** (funktioniert nicht überall)
- `Write-Log` für persistente Audit-Logs

---

## 8. CODE-STIL & FORMATIERUNG

**Regel 8.1:** Indentation: 4 Leerzeichen (nie Tabs)

**Regel 8.2:** K&R Bracing
```powershell
function Test-Provisioning {
    if ($condition) {
        Write-Output "Success"
    } else {
        Write-Output "Failure"
    }
}
```

**Regel 8.3:** Minimale Kommentare
- Nur Kommentare für **WHY**, nicht WHAT
- Selbssprechende Namen statt Kommentare

---

## 9. TESTING

**Regel 9.1:** Unit-Tests für öffentliche Funktionen
- Test-Datei: `tests/Test-FunctionName.ps1`
- Per Funktion ein Test-Script

**Regel 9.2:** Test-Struktur
- Arrange (Vorbereitung)
- Act (Test ausführen)
- Assert (Ergebnis validieren)

---

## 10. BUILD & VALIDATION

**Regel 10.1:** `build.ps1 -Validate` vor jedem Commit
- PSScriptAnalyzer Linting
- Indentation Check
- Bracing Check
- BOM Check

**Regel 10.2:** Pre-Commit Hook blockiert Commits mit Linting-Fehlern
- Fehler müssen vor Commit behoben werden
- Hinweis: Dieser Mechanismus war am 2026-07-01 zeitweise nicht funktionsfähig (Hook nicht installiert, `build.ps1`-Absturz, Gate konnte strukturell nie fehlschlagen) und wurde noch am selben Tag behoben und verifiziert - siehe `docs/Pre-Release/COMPLIANCE-AUDIT-PHASE-PRERELEASE.md` für Details

---

## 11. CONFIGURATION & SECRETS

**Regel 11.1:** Config via JSON-Dateien
```json
{
  "TenantId": "xxx",
  "ExchangeOnlineOrganization": "myorg.onmicrosoft.com"
}
```

**Regel 11.2:** Secrets NICHT in Code
- Credentials via `$env:VAR` oder Credential Manager
- Lokale `.env.local` → `.gitignore`

---

## 12. MODULE STRUCTURE

**Regel 12.1:** PSM1 (Module Root) importiert alle Funktionen
```powershell
# SharedMailboxProvisioner.psm1
Get-ChildItem -Path "$PSScriptRoot\functions\Public" -Filter "*.ps1" | ForEach-Object {
    . $_.FullName
}
```

**Regel 12.2:** PSD1 (Manifest) definiert exportierte Funktionen
```powershell
FunctionsToExport = @(
    'New-SharedMailbox',
    'Add-SharedMailboxMember'
)
```

