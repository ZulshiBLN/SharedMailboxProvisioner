<#
.SYNOPSIS
Unit tests for Write-Log function

.DESCRIPTION
Tests logging to audit and error logs
#>

$functionPath = Join-Path (Join-Path (Split-Path -Parent $PSScriptRoot) "functions") "Private\_Write-Log.ps1"
. $functionPath

Describe "WriteLog" {

    BeforeEach {
        $testLogPath = Join-Path $env:TEMP "SharedMailboxProvisioner-Test-$(Get-Random)"
        New-Item -ItemType Directory -Path $testLogPath -Force | Out-Null
    }

    AfterEach {
        if (Test-Path $testLogPath) {
            Remove-Item -Path $testLogPath -Recurse -Force
        }
    }

    Context "Write audit log entry" {
        It "Should create audit log file with INFO message" {
            Write-Log -Message "Test message" -Level INFO -Operation "TestOp" -LogPath $testLogPath

            $auditFile = Join-Path $testLogPath "Audit" "audit-*.log"
            Get-ChildItem -Path $auditFile | Should -Not -BeNullOrEmpty
        }

        It "Should write timestamp and user context" {
            Write-Log -Message "Test message" -Level INFO -LogPath $testLogPath

            $auditFile = Get-ChildItem -Path (Join-Path $testLogPath "Audit" "audit-*.log")
            $content = Get-Content $auditFile.FullName
            $content | Should -Match '\[\d{4}-\d{2}-\d{2}'
        }
    }

    Context "Write error log entry" {
        It "Should create error log file with ERROR message" {
            Write-Log -Message "Test error" -Level ERROR -Operation "FailedOp" -LogPath $testLogPath

            $errorFile = Get-ChildItem -Path (Join-Path $testLogPath "Errors" "errors-*.log")
            $errorFile | Should -Not -BeNullOrEmpty
        }
    }

    Context "Log retention cleanup" {
        It "Should remove audit logs older than retention period" {
            $auditDir = Join-Path $testLogPath "Audit"
            New-Item -ItemType Directory -Path $auditDir -Force | Out-Null

            # Create old log files
            "old content" | Out-File -FilePath (Join-Path $auditDir "audit-2020-01-01.log")
            "new content" | Out-File -FilePath (Join-Path $auditDir "audit-$(Get-Date -Format 'yyyy-MM-dd').log")

            # Run cleanup
            _Remove-OldLogs -AuditRetentionDays 30 -LogPath $testLogPath

            # Old file should be gone
            Test-Path (Join-Path $auditDir "audit-2020-01-01.log") | Should -Be $false
        }
    }
}
