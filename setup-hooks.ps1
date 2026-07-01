<#
.SYNOPSIS
Setup Git pre-commit hooks for SharedMailboxProvisioner

.DESCRIPTION
Installs Git pre-commit hook that runs build.ps1 -Validate before each commit.
Prevents commits with linting errors.

.EXAMPLE
.\setup-hooks.ps1
Installs pre-commit hook

.NOTES
This script must be run from the project root directory.
#>

param(
    [switch]$Remove
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$ProjectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$GitHooksDir = Join-Path (Join-Path $ProjectRoot '.git') 'hooks'
$PreCommitHook = Join-Path $GitHooksDir 'pre-commit'

$Success = '[OK]'
$ErrorLabel = '[ERROR]'
$Info = '[INFO]'

function Write-Status {
    param([string]$Message, [string]$Type = 'INFO')
    $prefix = switch ($Type) {
        'OK' {
            $Success
        }
        'ERROR' {
            $ErrorLabel
        }
        default {
            $Info
        }
    }
    Write-Output "$prefix $Message"
}

if ($Remove) {
    if (Test-Path $PreCommitHook) {
        Remove-Item $PreCommitHook -Force
        Write-Status "Pre-commit hook removed" 'OK'
    }
    else {
        Write-Status "Pre-commit hook not found" 'INFO'
    }
    exit 0
}

# Verify we're in a Git repository
if (-not (Test-Path (Join-Path $ProjectRoot '.git'))) {
    Write-Status "Not a Git repository: $ProjectRoot" 'ERROR'
    exit 1
}

# Create hooks directory if it doesn't exist
if (-not (Test-Path $GitHooksDir)) {
    New-Item -ItemType Directory -Path $GitHooksDir -Force | Out-Null
    Write-Status "Created Git hooks directory" 'OK'
}

# Create pre-commit hook script (bash/sh format for Git).
# Single-quoted here-string: content is 100% literal, no PowerShell interpolation
# needed (and `$(...)` is NOT reliably escaped by a backtick in an expandable
# here-string - it still gets evaluated as a subexpression despite the backtick).
$hookContent = @'
#!/bin/bash
# Pre-commit hook for SharedMailboxProvisioner
# Runs build.ps1 -Validate before each commit

cd "$(git rev-parse --show-toplevel)"

# Run PowerShell build validation (Windows PowerShell 5.1 per ADR-002 baseline).
# The whole -Command payload must be a single quoted bash argument - unquoted
# multi-line/brace content gets split into separate bash commands instead of
# reaching powershell.exe as one script block.
powershell.exe -NoProfile -Command '& ".\build.ps1" -Validate; exit $LASTEXITCODE'

if [ $? -ne 0 ]; then
    echo "[ERROR] Pre-commit validation failed. Commit blocked."
    echo "Fix the errors above and try again, or use: git commit --no-verify"
    exit 1
fi

exit 0
'@

# Write hook file
Set-Content -Path $PreCommitHook -Value $hookContent -Encoding ASCII

# Make hook executable (on Unix-like systems). $PSVersionTable.Platform doesn't
# exist before PowerShell 6, so check the version first to avoid a StrictMode
# error on Windows PowerShell 5.1 (this project's ADR-002 baseline).
if ($PSVersionTable.PSVersion.Major -ge 6 -and $PSVersionTable.Platform -ne 'Win32NT') {
    chmod +x $PreCommitHook
}

Write-Status "Pre-commit hook installed: $PreCommitHook" 'OK'
Write-Output ""
Write-Output "Hook behavior:"
Write-Output "  - Runs before each git commit"
Write-Output "  - Executes: build.ps1 -Validate"
Write-Output "  - Blocks commit if validation fails"
Write-Output "  - Bypass with: git commit --no-verify (not recommended)"
Write-Output ""
Write-Status "Setup complete" 'OK'
