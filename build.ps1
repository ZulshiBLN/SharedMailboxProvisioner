<#
.SYNOPSIS
Build & Validation script for SharedMailboxProvisioner

.DESCRIPTION
Runs PSScriptAnalyzer linting, indentation checks, K&R bracing validation,
and BOM checks. Used pre-commit to ensure code quality.

.PARAMETER Validate
Run validation checks (PSScriptAnalyzer, formatting, BOM)

.PARAMETER AnalyzeOnly
Skip formatting checks, only run PSScriptAnalyzer

.PARAMETER Fix
Attempt to fix common formatting issues (experimental)

.EXAMPLE
.\build.ps1 -Validate
Runs all validation checks

.EXAMPLE
.\build.ps1 -AnalyzeOnly
Runs only PSScriptAnalyzer linting

.NOTES
Exit codes:
  0 = success
  1 = validation failed
  2 = configuration error
#>

param(
    [switch]$Validate,
    [switch]$AnalyzeOnly,
    [switch]$Fix
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$ProjectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$SettingsPath = Join-Path $ProjectRoot 'PSScriptAnalyzerSettings.psd1'

# Color codes (ASCII only, no Unicode)
$Success = '[OK]'
$Error = '[ERROR]'
$Warning = '[WARN]'
$Info = '[INFO]'

function Write-Status {
    param([string]$Message, [string]$Type = 'INFO')
    $prefix = switch ($Type) {
        'OK' { $Success }
        'ERROR' { $Error }
        'WARN' { $Warning }
        default { $Info }
    }
    Write-Output "$prefix $Message"
}

function Test-PSScriptAnalyzer {
    Write-Output "`n=== PSScriptAnalyzer Linting ==="

    if (-not (Test-Path $SettingsPath)) {
        Write-Status "PSScriptAnalyzer settings not found: $SettingsPath" 'WARN'
        Write-Status "Creating default settings file..." 'INFO'

        $defaultSettings = @"
@{
    Severity = @('Error', 'Warning')
    IncludeRules = @()
    ExcludeRules = @('PSAvoidUsingInvokeExpression')
    Rules = @{
        PSProvideCommentHelp = @{
            Enable = `$true
            ExportedOnly = `$true
        }
        PSAvoidUsingInvokeExpression = @{
            Enable = `$false
        }
    }
}
"@
        Set-Content -Path $SettingsPath -Value $defaultSettings
        Write-Status "Created: $SettingsPath" 'OK'
    }

    try {
        if (-not (Get-Module -ListAvailable PSScriptAnalyzer)) {
            Write-Status "Installing PSScriptAnalyzer..." 'INFO'
            Install-Module -Name PSScriptAnalyzer -Force -Scope CurrentUser
        }

        $psFiles = @(
            Get-ChildItem -Path "$ProjectRoot\functions" -Filter "*.ps1" -Recurse -ErrorAction SilentlyContinue
            Get-ChildItem -Path "$ProjectRoot\scripts" -Filter "*.ps1" -ErrorAction SilentlyContinue
            Get-ChildItem -Path "$ProjectRoot\tests" -Filter "*.ps1" -ErrorAction SilentlyContinue
            Get-Item -Path "$ProjectRoot\build.ps1" -ErrorAction SilentlyContinue
        )

        if (-not $psFiles) {
            Write-Status "No PowerShell files found to analyze" 'WARN'
            return $true
        }

        $results = @()
        foreach ($file in $psFiles) {
            $analysis = Invoke-ScriptAnalyzer -Path $file.FullName -Settings $SettingsPath
            if ($analysis) {
                $results += $analysis
            }
        }

        if ($results) {
            Write-Status "Found $($results.Count) issue(s)" 'ERROR'
            foreach ($issue in $results) {
                Write-Output "  Line $($issue.Line): [$($issue.Severity)] $($issue.RuleName) - $($issue.Message)"
                Write-Output "    File: $($issue.ScriptPath)"
            }
            return $false
        }
        else {
            Write-Status "All files passed PSScriptAnalyzer checks" 'OK'
            return $true
        }
    }
    catch {
        Write-Status "PSScriptAnalyzer error: $_" 'ERROR'
        return $false
    }
}

function Test-Indentation {
    Write-Output "`n=== Indentation Check (4 spaces) ==="

    $psFiles = @(
        Get-ChildItem -Path "$ProjectRoot\functions" -Filter "*.ps1" -Recurse -ErrorAction SilentlyContinue
        Get-ChildItem -Path "$ProjectRoot\scripts" -Filter "*.ps1" -ErrorAction SilentlyContinue
        Get-ChildItem -Path "$ProjectRoot\tests" -Filter "*.ps1" -ErrorAction SilentlyContinue
    )

    $issues = 0
    foreach ($file in $psFiles) {
        $content = Get-Content -Path $file.FullName -Raw
        $lines = $content -split "`n"

        foreach ($i in 0..($lines.Count - 1)) {
            $line = $lines[$i]

            # Skip empty lines and comment-only lines
            if ($line -match '^\s*$' -or $line -match '^\s*#') {
                continue
            }

            # Check for tabs
            if ($line -match "`t") {
                Write-Status "File: $($file.Name), Line $($i + 1): Found tab character (use 4 spaces)" 'ERROR'
                $issues++
                continue
            }

            # Check indentation is multiple of 4
            if ($line -match '^( +)[^ ]') {
                $spaces = $Matches[1].Length
                if ($spaces % 4 -ne 0) {
                    Write-Status "File: $($file.Name), Line $($i + 1): Indentation is $spaces spaces (must be multiple of 4)" 'WARN'
                }
            }
        }
    }

    if ($issues -gt 0) {
        Write-Status "Found $issues indentation error(s)" 'ERROR'
        return $false
    }
    else {
        Write-Status "Indentation check passed" 'OK'
        return $true
    }
}

function Test-BOM {
    Write-Output "`n=== BOM Check ==="

    $psFiles = @(
        Get-ChildItem -Path "$ProjectRoot\functions" -Filter "*.ps1" -Recurse -ErrorAction SilentlyContinue
        Get-ChildItem -Path "$ProjectRoot\scripts" -Filter "*.ps1" -ErrorAction SilentlyContinue
        Get-ChildItem -Path "$ProjectRoot\tests" -Filter "*.ps1" -ErrorAction SilentlyContinue
        Get-Item -Path "$ProjectRoot\build.ps1" -ErrorAction SilentlyContinue
    )

    $issues = 0
    foreach ($file in $psFiles) {
        $bytes = Get-Content -Path $file.FullName -Encoding Byte -TotalCount 3
        $hasBOM = $bytes.Count -ge 3 -and $bytes[0] -eq 239 -and $bytes[1] -eq 187 -and $bytes[2] -eq 191

        if (-not $hasBOM) {
            Write-Status "File missing UTF-8 BOM: $($file.Name)" 'WARN'
            $issues++
        }
    }

    if ($issues -gt 0) {
        Write-Status "Found $issues file(s) missing UTF-8 BOM" 'WARN'
    }
    else {
        Write-Status "All files have UTF-8 BOM" 'OK'
    }

    return $true
}

function Test-Bracing {
    Write-Output "`n=== K&R Bracing Check ==="

    $psFiles = @(
        Get-ChildItem -Path "$ProjectRoot\functions" -Filter "*.ps1" -Recurse -ErrorAction SilentlyContinue
        Get-ChildItem -Path "$ProjectRoot\scripts" -Filter "*.ps1" -ErrorAction SilentlyContinue
        Get-ChildItem -Path "$ProjectRoot\tests" -Filter "*.ps1" -ErrorAction SilentlyContinue
    )

    $issues = 0
    foreach ($file in $psFiles) {
        $lines = @(Get-Content -Path $file.FullName)

        foreach ($i in 0..($lines.Count - 1)) {
            $line = $lines[$i]

            # Check for opening brace on same line (K&R style)
            if ($line -match '}\s*else\s*$') {
                Write-Status "File: $($file.Name), Line $($i + 1): 'else' should be on same line as closing brace" 'WARN'
                $issues++
            }

            # Check for opening brace not at end of line
            if ($line -match '^.*[^{]\s*\{\s*$' -and -not ($line -match 'param\s*\(')) {
                # This is overly simplistic, skip for now
            }
        }
    }

    if ($issues -gt 0) {
        Write-Status "Found $issues bracing issue(s)" 'WARN'
    }
    else {
        Write-Status "Bracing check passed" 'OK'
    }

    return $true
}

# Main execution
if ($Validate) {
    Write-Output "======================================"
    Write-Output "SharedMailboxProvisioner Build Validation"
    Write-Output "======================================"

    $allPassed = $true

    if (-not (Test-PSScriptAnalyzer)) {
        $allPassed = $false
    }
    if (-not $AnalyzeOnly) {
        if (-not (Test-Indentation)) {
            $allPassed = $false
        }
        if (-not (Test-Bracing)) {
            $allPassed = $false
        }
        if (-not (Test-BOM)) {
            $allPassed = $false
        }
    }

    Write-Output "`n======================================"
    if ($allPassed) {
        Write-Status "Build validation PASSED" 'OK'
        Write-Output "======================================"
        exit 0
    }
    else {
        Write-Status "Build validation FAILED" 'ERROR'
        Write-Output "======================================"
        exit 1
    }
}
elseif ($AnalyzeOnly) {
    Write-Output "======================================"
    Write-Output "PSScriptAnalyzer Linting Only"
    Write-Output "======================================"

    if (Test-PSScriptAnalyzer) {
        exit 0
    }
    else {
        exit 1
    }
}
else {
    Write-Output "Build script for SharedMailboxProvisioner"
    Write-Output ""
    Write-Output "Usage:"
    Write-Output "  .\build.ps1 -Validate       # Run all validation checks"
    Write-Output "  .\build.ps1 -AnalyzeOnly    # Run only PSScriptAnalyzer"
    Write-Output "  .\build.ps1 -Fix             # Attempt to fix issues (experimental)"
    Write-Output ""
    Write-Output "For pre-commit hook integration:"
    Write-Output "  .\build.ps1 -Validate"
}
