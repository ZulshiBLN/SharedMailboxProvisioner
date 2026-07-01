# SharedMailboxProvisioner – CLAUDE.md

PowerShell Automation für Exchange Online SharedMailbox Provisioning & Management.

---

## Projekt-Kontext

**Version:** v0.9.0-beta.1  
**Status:** [ACTIVE] Pre-Release Phase – Real-World Testing & Validation  
**Sprache:** PowerShell 5.1+ (Exchange Online)  
**Ziel:** Sichere, performante, tokensparende Zusammenarbeit mit Claude

**Timeline:** July 1 - July 21, 2026 (3 weeks)  
**Next Milestone:** v0.9.0 stable release (Week 3), then v1.0.0 launch prep

**Wichtige Dokumente:**
- [RULES] **[STRUCTURE.md](STRUCTURE.md)** – Konkrete Implementierungs-Regeln (HOW)
- [ADR] **[DECISIONS.md](DECISIONS.md)** – Architektur-Entscheidungen & Begründungen (WHY)
- [COLLAB] **[CLAUDE.md](CLAUDE.md)** (dieses Dokument) – Collaboration Rules & Best Practices
- [TRACK] **[PROJECT-TRACKING.md](PROJECT-TRACKING.md)** – Active project status & roadmap

➡️ **Lese-Reihenfolge:** DECISIONS.md (Kontext) → STRUCTURE.md (Regeln) → CLAUDE.md (Collaboration)

---

## Allgemeine Collaboration Rules (Claude Best Practices)

### Sicherheit & Datenhandling

**Regel 1.1 - Zero Data Retention (ZDR)**
- Keine Credentials, Secrets oder sensible Daten in Prompts
- `.env`, `.local`, `secrets.json` grundsätzlich NICHT mit Claude teilen
- Nur Struktur/Patterns zeigen, keine echten Werte
- Bei Sicherheitsreviews: Anonymisierte Beispiele verwenden

**Regel 1.2 - Validierung an Grenzen**
- Externe Eingaben validieren (User-Input, APIs, Config-Files)
- Interne Code-Garantien vertrauen; nicht über-validieren
- OWASP Top 10 im Auge behalten (XSS, Injection, etc.)

**Regel 1.3 - Destructive Operations erfordern Bestätigung**
- Force-Push, Hard-Reset, Permanent Delete → Explizite Genehmigung ERST einholen
- Bei Unsicherheit fragen, nicht silent weitermachen
- Git-Hooks nicht skippen (--no-verify) ohne guten Grund

**Regel 1.4 - Invoke-Expression VERMEIDEN (Security)**
- **NIEMALS `Invoke-Expression` nutzen** (Security-Risiko, PSAvoidUsingInvokeExpression)
- Grund: Injection-Anfälligkeit, Debugging-Probleme, Performance-Overhead
- **Alternativen:** `&` Call-Operator, `.NET APIs`, Explizite Parameter, `Invoke-Command` mit `-ScriptBlock`

**Regel 1.5 - Dokumentation von Public vs Private Funktionen (STRUCTURE.md Regel 3.1)**
- **PUBLIC Funktionen** (keine `_` prefix): Vollständige Comment-based Help erforderlich
- **PRIVATE Funktionen** (mit `_` prefix): Minimal-Help erforderlich

---

### Token-Effizienz & Context-Management

**Regel 2.1 - Token-bewusste Prompts**
- Relevante Code-Ausschnitte gezielt teilen (nicht ganze Dateien)
- Grep/Glob für Suche nutzen → Read nur spezifische Bereiche

**Regel 2.2 - Context Discipline**
- **Progressive Disclosure:** Nur relevante Kontexte pro Request
- **Tool-Strategien:** Grep, Glob, Edit/Write statt Bash-Kommands

**Regel 2.3 - Parallelisierung wo möglich**
- Unabhängige Tool-Calls parallel ausführen

---

### Code-Qualität & Hygiene

**Regel 3.1 - Minimale Kommentare, maximale Klarheit**
- Keine Kommentare für offensichtliches (selbsprechende Namen reichen)
- Nur Kommentare für **WHY**, nicht WHAT

**Regel 3.1a - ASCII-only Output Strings**
- Alle Output-Strings verwenden **AUSSCHLIESSLICH ASCII-Zeichen**
- NICHT verwenden: Unicode Symbole oder Emoji
- STATTDESSEN: [OK]/[ERROR]/[WARN]/[INFO], *, -, #, etc.

**Regel 3.1b - Richtige Output-Cmdlets nutzen**
- `Write-Output` für normale Ausgaben
- `Write-Verbose` für Debug-Info
- `Write-Error` nur für echte Fehler
- **`Write-Host` VERMEIDEN**

**Regel 3.2 - Keine Über-Abstraktionen**
- YAGNI-Prinzip: Nicht für hypothetische Zukunft bauen

---

## Arbeitsregeln für SharedMailboxProvisioner

### Context-Management

**Regel 5.1 - Build & Validate vor jedem Commit**
- PSScriptAnalyzer Validierung vor Commit
- `.\build.ps1 -Validate` ausführen
- Hook blockiert Commits mit Linting-Fehlern (Historie zu einem zeitweiligen Ausfall dieses Mechanismus am 2026-07-01: siehe `docs/Pre-Release/COMPLIANCE-AUDIT-PHASE-PRERELEASE.md`)

**Regel 5.2 - CLAUDE.md aktuell halten**
- Nach Änderungen updaten wenn neue Konventionen etablieren
- Kompakt formulieren

**Regel 5.3 - Dokumentation vor Code**
1. **Architektur-Entscheidung** → ADR in [DECISIONS.md](DECISIONS.md)
2. **Implementierungs-Regel** → Regel in [STRUCTURE.md](STRUCTURE.md)
3. **Collaboration-Update** → Anpassung in [CLAUDE.md](CLAUDE.md)

---

### Decision Making & Architecture

**Regel 5.4 - Architektur-Entscheidungen in DECISIONS.md (ADRs)**
Gehört in DECISIONS.md:
- Projekt-Struktur / Architektur
- Tech-Stack Änderungen
- Prozess-Entscheidungen
- Design-Patterns

Gehört in STRUCTURE.md:
- Implementierungs-Standards
- Verzeichnis-Layout
- Anforderungen pro Funktion

---

### Sicherheit in Development

**Regel 6.1 - Keine Secrets in Code**
- Credentials über `$env:VAR` oder Credential Manager
- Lokale `.env.local` → `.gitignore`

**Regel 6.2 - Code Review vor Security-Commits**
- Alles das Auth/Permissions berührt → `/code-review` vorher
- Oder direkt `/security-review` für sensible Änderungen

---

## Git-Workflow: Three-Tier Release Model

### Branch-Struktur

```
develop (Aktive Entwicklung)
    ↓
prerelease (Testing/Beta)
    ↓
main (Stable Production)
```

| Branch | Typ | Zweck |
|--------|-----|-------|
| `develop` | Integration | Aktive Entwicklung |
| `prerelease` | Testing | Pre-Release/Beta Testing |
| `main` | Production | Stable Releases |

### Versionierung (Semantic Versioning)

```
MAJOR.MINOR.PATCH
0.1.0
│ │  │
│ │  └─ PATCH (Bugfixes)
│ └──── MINOR (Features)
└────── MAJOR (Breaking)
```

### PowerShell Gallery Listing Policy

**Kritische Regel:** Nur stabile Releases werden zu PowerShell Gallery published.

- Stable Versions (v1.x.x): ✅ Published zu PSGallery
- Pre-Release Versions (v1.x.x-beta.*): ❌ NICHT published, nur GitHub Releases

---

## Dokumentation & Referenzen

**Architektur-Entscheidungen (WHY):**
- Siehe [DECISIONS.md](DECISIONS.md) für alle ADRs

**Implementierungs-Regeln (HOW):**
- Siehe [STRUCTURE.md](STRUCTURE.md) für alle Regel-Blöcke

