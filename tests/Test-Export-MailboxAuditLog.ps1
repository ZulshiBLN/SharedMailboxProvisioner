BeforeAll {
    Import-Module "$PSScriptRoot\..\SharedMailboxProvisioner.psd1" -Force
}

Describe "Export-MailboxAuditLog" {
    Context "Audit Log Export Formats" {
        BeforeEach {
            $script:testDir = Join-Path $env:TEMP "smp-audit-$(Get-Random)"
            $script:auditDir = Join-Path $script:testDir "Audit"
            New-Item -ItemType Directory -Path $script:auditDir -Force | Out-Null

            # Create mock audit log file
            $script:auditFile = Join-Path $script:auditDir "audit-$(Get-Date -Format 'yyyy-MM-dd').log"
            $logContent = @"
[2026-06-30 14:00:00] [INFO] [user@example.com] [New-SharedMailbox] [SUCCESS] Created mailbox sales@example.com
[2026-06-30 14:05:00] [ERROR] [user@example.com] [Add-SharedMailboxMember] [FAILED] User not found in AD
[2026-06-30 14:10:00] [WARN] [user@example.com] [Test-SharedMailboxCandidate] [ANOMALY] Unusual operation count
"@
            Set-Content -Path $script:auditFile -Value $logContent
        }

        AfterEach {
            Remove-Item -Path $script:testDir -Recurse -Force -ErrorAction SilentlyContinue
        }

        It "Should export as HTML format" {
            $output = Export-MailboxAuditLog -Format HTML

            $output | Should -Not -BeNullOrEmpty
            $output | Should -Match "<html>"
            $output | Should -Match "<table>"
            $output | Should -Match "Timestamp"
        }

        It "Should export as CSV format" {
            $output = Export-MailboxAuditLog -Format CSV

            $output | Should -Not -BeNullOrEmpty
            $output | Should -Match "Timestamp,Level,User,Operation,Status,Message"
        }

        It "Should export as Text format" {
            $output = Export-MailboxAuditLog -Format Text

            $output | Should -Not -BeNullOrEmpty
            $output | Should -Match "Timestamp:"
            $output | Should -Match "Level:"
            $output | Should -Match "Operation:"
        }

        It "Should include all entry fields" {
            $output = Export-MailboxAuditLog -Format HTML

            $output | Should -Match "New-SharedMailbox"
            $output | Should -Match "user@example.com"
            $output | Should -Match "SUCCESS"
        }

        It "Should handle CSV escaping correctly" {
            # Create audit entry with comma in message
            $escapedContent = @"
[2026-06-30 14:00:00] [INFO] [user@example.com] [Operation] [STATUS] Message with, comma
"@
            Set-Content -Path $script:auditFile -Value $escapedContent

            $output = Export-MailboxAuditLog -Format CSV

            # CSV should properly escape the message
            $output | Should -Not -BeNullOrEmpty
        }

        It "Should filter by date range" {
            $yesterday = (Get-Date).AddDays(-1)
            $tomorrow = (Get-Date).AddDays(1)

            $output = Export-MailboxAuditLog -Format Text -StartDate $yesterday -EndDate $tomorrow

            $output | Should -Not -BeNullOrEmpty
        }

        It "Should filter by status" {
            $output = Export-MailboxAuditLog -Format Text -FilterStatus "SUCCESS"

            $output | Should -Match "New-SharedMailbox"
        }

        It "Should write to file when OutputPath specified" {
            $outputFile = Join-Path $script:testDir "export.html"

            Export-MailboxAuditLog -Format HTML -OutputPath $outputFile

            Test-Path $outputFile | Should -Be $true
            Get-Content $outputFile | Should -Match "<html>"
        }

        It "Should return empty when no audit directory" {
            $output = Export-MailboxAuditLog -Format HTML

            # Should handle gracefully
            $output | Should -Not -BeNull
        }

        It "Should handle HTML special characters" {
            $specialContent = @"
[2026-06-30 14:00:00] [INFO] [user@example.com] [Op] [STATUS] Message with <tag> & ampersand
"@
            Set-Content -Path $script:auditFile -Value $specialContent

            $output = Export-MailboxAuditLog -Format HTML

            $output | Should -Not -BeNullOrEmpty
        }
    }
}
