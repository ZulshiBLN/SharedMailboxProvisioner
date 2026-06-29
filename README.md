# SharedMailboxProvisioner

PowerShell Automation für Exchange Online SharedMailbox Provisioning & Management.

## Overview

SharedMailboxProvisioner bietet automatisierte Provisioning-Operationen für Exchange Online SharedMailboxes:
- Erstellen & Verwalten von SharedMailboxes
- Delegierte Zugriffe & Berechtigungen
- Batch-Operationen für große Mengen
- Audit-Logging & Compliance

## Quick Start

### Installation

```powershell
# Aus PowerShell Gallery (zukünftig)
Install-Module -Name SharedMailboxProvisioner

# Lokal aus Projekt
Import-Module "C:\Repos\SharedMailboxProvisioner\SharedMailboxProvisioner.psd1"
```

### Usage

```powershell
# Connect to Exchange Online
Connect-ExchangeOnline -Tenant "mytenant.onmicrosoft.com"

# Create a SharedMailbox
New-SharedMailbox -DisplayName "Sales Team" -PrimarySmtpAddress "sales@contoso.com"

# Add members
Add-SharedMailboxMember -Identity "sales@contoso.com" -Members @("user1@contoso.com", "user2@contoso.com")
```

## Documentation

- **[CLAUDE.md](CLAUDE.md)** – Collaboration Rules & Best Practices
- **[DECISIONS.md](DECISIONS.md)** – Architectural Decision Records (ADRs)
- **[STRUCTURE.md](STRUCTURE.md)** – Implementierungs-Regeln & Code-Standards

## Project Status

**Version:** v0.1.0 (Early Development)  
**Status:** Infrastructure Phase  

## License

MIT License

