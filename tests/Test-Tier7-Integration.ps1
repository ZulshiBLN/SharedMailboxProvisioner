BeforeAll {
    Import-Module "$PSScriptRoot\..\SharedMailboxProvisioner.psd1" -Force
}

Describe "Tier 7 - Manual Bulk Import Tool (Integration)" {
    Context "End-to-End CSV Import Workflow" {
        BeforeEach {
            $script:testDir = Join-Path $env:TEMP "smp-tier7-$(Get-Random)"
            New-Item -ItemType Directory -Path $script:testDir -Force | Out-Null
        }

        AfterEach {
            Remove-Item -Path $script:testDir -Recurse -Force -ErrorAction SilentlyContinue
        }

        It "Should complete full CSV import workflow - valid candidates" {
            # Create test CSV
            $csvPath = Join-Path $script:testDir "valid-candidates.csv"
            $csvContent = @"
SamAccountName,DisplayName,Email,ACLGroup,AdminGroup
smbx_001,Department A,dept-a@example.com,smbx_acl_001,ZO-Admins-A
smbx_002,Department B,dept-b@example.com,smbx_acl_002,ZO-Admins-B
"@
            Set-Content -Path $csvPath -Value $csvContent

            # Step 1: Import CSV
            $import = Import-MailboxCandidatesFromCSV -CSVPath $csvPath -ValidateADLookup $false

            # Verify import
            $import | Should -Not -BeNullOrEmpty
            $import.ImportMetadata.SourceFile | Should -Be "valid-candidates.csv"
            $import.ImportMetadata.SourceHash | Should -Not -BeNullOrEmpty
            $import.Candidates | Should -Not -BeNullOrEmpty
        }

        It "Should convert CSV rows to normalized candidate objects" {
            $csvPath = Join-Path $script:testDir "conversion-test.csv"
            $csvContent = @"
SamAccountName,DisplayName,Email,ACLGroup
  SMBX_001  ,  Department A  ,  DEPT-A@EXAMPLE.COM  ,  smbx_acl_001
"@
            Set-Content -Path $csvPath -Value $csvContent

            $import = Import-MailboxCandidatesFromCSV -CSVPath $csvPath -ValidateADLookup $false

            $candidate = $import.Candidates[0]
            $candidate.SamAccountName | Should -Be "smbx_001"
            $candidate.Email | Should -Be "dept-a@example.com"
        }

        It "Should handle missing required columns" {
            $csvPath = Join-Path $script:testDir "invalid-columns.csv"
            $csvContent = @"
SamAccountName,DisplayName,Email
smbx_001,Department A,dept-a@example.com
"@
            Set-Content -Path $csvPath -Value $csvContent

            $import = Import-MailboxCandidatesFromCSV -CSVPath $csvPath -ValidateADLookup $false

            $import.SuccessCount | Should -Be 0
        }

        It "Should skip invalid rows and continue processing" {
            $csvPath = Join-Path $script:testDir "mixed-valid-invalid.csv"
            $csvContent = @"
SamAccountName,DisplayName,Email,ACLGroup
smbx_001,Department A,dept-a@example.com,smbx_acl_001
invalid_002,Department B,dept-b@example.com,smbx_acl_002
smbx_003,Department C,dept-c@example.com,smbx_acl_003
"@
            Set-Content -Path $csvPath -Value $csvContent

            $import = Import-MailboxCandidatesFromCSV -CSVPath $csvPath -ValidateADLookup $false

            # Invalid row should be skipped
            $import.SuccessCount | Should -BeGreaterThan 0
        }

        It "Should generate bulk import report with HTML output" {
            $csvPath = Join-Path $script:testDir "report-test.csv"
            $reportPath = Join-Path $script:testDir "preview-report.html"

            $csvContent = @"
SamAccountName,DisplayName,Email,ACLGroup,AdminGroup
smbx_001,Department A,dept-a@example.com,smbx_acl_001,ZO-Admins
smbx_002,Department B,dept-b@example.com,smbx_acl_002,
"@
            Set-Content -Path $csvPath -Value $csvContent

            $import = Import-MailboxCandidatesFromCSV -CSVPath $csvPath -ValidateADLookup $false

            # Generate report
            $result = Test-MailboxBulkImport -Candidates $import.Candidates `
                -GenerateReport $true `
                -ReportPath $reportPath

            $result | Should -Not -BeNullOrEmpty
            $result.CandidatesToProcess | Should -BeGreaterThan 0
        }

        It "Should detect duplicates within batch" {
            $csvPath = Join-Path $script:testDir "duplicates.csv"
            $csvContent = @"
SamAccountName,DisplayName,Email,ACLGroup
smbx_001,Department A,same@example.com,smbx_acl_001
smbx_001,Department A2,same@example.com,smbx_acl_001
"@
            Set-Content -Path $csvPath -Value $csvContent

            $import = Import-MailboxCandidatesFromCSV -CSVPath $csvPath -ValidateADLookup $false

            # Bulk import validation should detect duplicates
            $result = Test-MailboxBulkImport -Candidates $import.Candidates -GenerateReport $false

            $result.Issues | Should -Not -BeNullOrEmpty
        }

        It "Should handle large CSV files efficiently" {
            $csvPath = Join-Path $script:testDir "large-file.csv"

            # Create CSV with 50 rows
            $lines = @("SamAccountName,DisplayName,Email,ACLGroup")
            for ($i = 1; $i -le 50; $i++) {
                $lines += "smbx_$('{0:0000}' -f $i),Department $i,dept-$i@example.com,smbx_acl_$('{0:0000}' -f $i)"
            }
            Set-Content -Path $csvPath -Value ($lines -join "`n")

            $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
            $import = Import-MailboxCandidatesFromCSV -CSVPath $csvPath -ValidateADLookup $false
            $stopwatch.Stop()

            $import.Candidates.Count | Should -BeGreaterThan 0
            $stopwatch.ElapsedMilliseconds | Should -BeLessThan 5000  # Should complete in < 5 seconds
        }

        It "Should maintain audit trail metadata" {
            $csvPath = Join-Path $script:testDir "audit-test.csv"
            Set-Content -Path $csvPath -Value "SamAccountName,DisplayName,Email,ACLGroup`nsmbx_001,Dept A,dept-a@example.com,smbx_acl_001"

            $import = Import-MailboxCandidatesFromCSV -CSVPath $csvPath -ValidateADLookup $false

            $import.ImportMetadata.ImportedBy | Should -Not -BeNullOrEmpty
            $import.ImportMetadata.ImportedAt | Should -Not -BeNullOrEmpty
            $import.ImportMetadata.SourceHash | Should -Match "^[A-F0-9]{64}$"  # SHA256 hex
        }

        It "Should handle special characters in display names" {
            $csvPath = Join-Path $script:testDir "special-chars.csv"
            $csvContent = @"
SamAccountName,DisplayName,Email,ACLGroup
smbx_001,Department (A) - Test & Co.,dept-a@example.com,smbx_acl_001
"@
            Set-Content -Path $csvPath -Value $csvContent

            $import = Import-MailboxCandidatesFromCSV -CSVPath $csvPath -ValidateADLookup $false

            $import.Candidates.Count | Should -BeGreaterThan 0
        }

        It "Should handle optional AdminGroup field" {
            $csvPath = Join-Path $script:testDir "optional-admin-group.csv"
            $csvContent = @"
SamAccountName,DisplayName,Email,ACLGroup,AdminGroup
smbx_001,Department A,dept-a@example.com,smbx_acl_001,ZO-Admins
smbx_002,Department B,dept-b@example.com,smbx_acl_002,
"@
            Set-Content -Path $csvPath -Value $csvContent

            $import = Import-MailboxCandidatesFromCSV -CSVPath $csvPath -ValidateADLookup $false

            $import.Candidates[0].AdminGroup | Should -Be "ZO-Admins"
            $import.Candidates[1].AdminGroup | Should -Be ""
        }
    }
}
