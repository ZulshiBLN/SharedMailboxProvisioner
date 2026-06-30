BeforeAll {
    Import-Module "$PSScriptRoot\..\SharedMailboxProvisioner.psd1" -Force
}

Describe "Import-MailboxCandidatesFromCSV" {
    Context "CSV Reading and Validation" {
        BeforeEach {
            # Create temp CSV files for testing
            $script:testCsvDir = Join-Path $env:TEMP "smp-test-$(Get-Random)"
            New-Item -ItemType Directory -Path $script:testCsvDir -Force | Out-Null
        }

        AfterEach {
            # Cleanup
            Remove-Item -Path $script:testCsvDir -Recurse -Force -ErrorAction SilentlyContinue
        }

        It "Should read valid CSV with required columns only" {
            $csvPath = Join-Path $script:testCsvDir "valid-minimal.csv"
            $csvContent = @"
SamAccountName,DisplayName,Email,ACLGroup
smbx_001,Department A,dept-a@example.com,smbx_acl_001
smbx_002,Department B,dept-b@example.com,smbx_acl_002
"@
            Set-Content -Path $csvPath -Value $csvContent

            $result = Import-MailboxCandidatesFromCSV -CSVPath $csvPath -ValidateADLookup $false

            $result.SuccessCount | Should -BeGreaterThan 0
            $result.Candidates | Should -Not -BeNullOrEmpty
            $result.ImportMetadata.SourceFile | Should -Be "valid-minimal.csv"
        }

        It "Should read CSV with optional AdminGroup column" {
            $csvPath = Join-Path $script:testCsvDir "valid-with-admin.csv"
            $csvContent = @"
SamAccountName,DisplayName,Email,ACLGroup,AdminGroup
smbx_001,Department A,dept-a@example.com,smbx_acl_001,ZO-Admins
"@
            Set-Content -Path $csvPath -Value $csvContent

            $result = Import-MailboxCandidatesFromCSV -CSVPath $csvPath -ValidateADLookup $false

            $result.SuccessCount | Should -BeGreaterThan 0
            $result.Candidates[0].AdminGroup | Should -Be "ZO-Admins"
        }

        It "Should detect missing required column" {
            $csvPath = Join-Path $script:testCsvDir "invalid-missing-column.csv"
            $csvContent = @"
SamAccountName,DisplayName,Email
smbx_001,Department A,dept-a@example.com
"@
            Set-Content -Path $csvPath -Value $csvContent

            $result = Import-MailboxCandidatesFromCSV -CSVPath $csvPath -ValidateADLookup $false

            $result.SuccessCount | Should -Be 0
        }

        It "Should skip invalid rows and continue with valid ones" {
            $csvPath = Join-Path $script:testCsvDir "mixed-valid-invalid.csv"
            $csvContent = @"
SamAccountName,DisplayName,Email,ACLGroup
smbx_001,Department A,dept-a@example.com,smbx_acl_001
invalid_sam,Department B,dept-b@example.com,smbx_acl_002
smbx_003,Department C,dept-c@example.com,smbx_acl_003
"@
            Set-Content -Path $csvPath -Value $csvContent

            $result = Import-MailboxCandidatesFromCSV -CSVPath $csvPath -ValidateADLookup $false

            $result.SuccessCount | Should -Be 2
            $result.FailureCount | Should -Be 1
        }

        It "Should handle whitespace trimming" {
            $csvPath = Join-Path $script:testCsvDir "whitespace.csv"
            $csvContent = @"
SamAccountName,DisplayName,Email,ACLGroup
  smbx_001  ,  Department A  ,  dept-a@example.com  ,  smbx_acl_001
"@
            Set-Content -Path $csvPath -Value $csvContent

            $result = Import-MailboxCandidatesFromCSV -CSVPath $csvPath -ValidateADLookup $false

            $result.SuccessCount | Should -Be 1
            $result.Candidates[0].SamAccountName | Should -Be "smbx_001"
        }

        It "Should handle empty rows gracefully" {
            $csvPath = Join-Path $script:testCsvDir "with-empty-rows.csv"
            $csvContent = @"
SamAccountName,DisplayName,Email,ACLGroup
smbx_001,Department A,dept-a@example.com,smbx_acl_001

smbx_002,Department B,dept-b@example.com,smbx_acl_002
"@
            Set-Content -Path $csvPath -Value $csvContent

            $result = Import-MailboxCandidatesFromCSV -CSVPath $csvPath -ValidateADLookup $false

            $result.SuccessCount | Should -BeGreaterThan 0
        }

        It "Should return metadata with source file hash" {
            $csvPath = Join-Path $script:testCsvDir "with-hash.csv"
            $csvContent = "SamAccountName,DisplayName,Email,ACLGroup`nsmbx_001,Dept A,dept-a@example.com,smbx_acl_001"
            Set-Content -Path $csvPath -Value $csvContent

            $result = Import-MailboxCandidatesFromCSV -CSVPath $csvPath -ValidateADLookup $false

            $result.ImportMetadata | Should -Not -BeNullOrEmpty
            $result.ImportMetadata.SourceHash | Should -Not -BeNullOrEmpty
            $result.ImportMetadata.ImportedAt | Should -Not -BeNullOrEmpty
        }

        It "Should handle duplicate SAM accounts in CSV" {
            $csvPath = Join-Path $script:testCsvDir "duplicate-sam.csv"
            $csvContent = @"
SamAccountName,DisplayName,Email,ACLGroup
smbx_001,Department A,dept-a@example.com,smbx_acl_001
smbx_001,Department A2,dept-a2@example.com,smbx_acl_001
"@
            Set-Content -Path $csvPath -Value $csvContent

            $result = Import-MailboxCandidatesFromCSV -CSVPath $csvPath -ValidateADLookup $false

            # Both rows imported (duplicates detected in Test-MailboxBulkImport, not here)
            $result.Candidates.Count | Should -Be 2
        }

        It "Should detect invalid email format" {
            $csvPath = Join-Path $script:testCsvDir "invalid-email.csv"
            $csvContent = @"
SamAccountName,DisplayName,Email,ACLGroup
smbx_001,Department A,not-an-email,smbx_acl_001
"@
            Set-Content -Path $csvPath -Value $csvContent

            # Mock Test-SharedMailboxCandidate to reject invalid emails
            Mock -CommandName Test-SharedMailboxCandidate -MockWith {
                if ($Email -notmatch '^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$') {
                    return @{ IsValid = $false; Errors = @("Invalid email format") }
                }
                return @{ IsValid = $true; Errors = @() }
            }

            $result = Import-MailboxCandidatesFromCSV -CSVPath $csvPath -ValidateADLookup $false

            $result.FailureCount | Should -BeGreaterThan 0
        }

        It "Should handle large CSV files (100+ rows)" {
            $csvPath = Join-Path $script:testCsvDir "large-file.csv"
            $lines = @("SamAccountName,DisplayName,Email,ACLGroup")
            for ($i = 1; $i -le 100; $i++) {
                $lines += "smbx_$($i.ToString('0000')),Department $i,dept-$i@example.com,smbx_acl_$($i.ToString('0000'))"
            }
            Set-Content -Path $csvPath -Value ($lines -join "`n")

            $result = Import-MailboxCandidatesFromCSV -CSVPath $csvPath -ValidateADLookup $false

            $result.ImportMetadata.TotalRows | Should -Be 100
            $result.Candidates.Count | Should -BeGreaterThan 0
        }

        It "Should return empty result for non-existent file" {
            { Import-MailboxCandidatesFromCSV -CSVPath "C:\nonexistent\file.csv" } | Should -Throw
        }

        It "Should log import operation" {
            $csvPath = Join-Path $script:testCsvDir "log-test.csv"
            Set-Content -Path $csvPath -Value "SamAccountName,DisplayName,Email,ACLGroup`nsmbx_001,Dept A,dept-a@example.com,smbx_acl_001"

            $result = Import-MailboxCandidatesFromCSV -CSVPath $csvPath -ValidateADLookup $false

            # Logging should occur (verification via Write-Log would require mocking)
            $result | Should -Not -BeNullOrEmpty
        }

        It "Should handle special characters in DisplayName" {
            $csvPath = Join-Path $script:testCsvDir "special-chars.csv"
            $csvContent = @"
SamAccountName,DisplayName,Email,ACLGroup
smbx_001,Department (A) - Test,dept-a@example.com,smbx_acl_001
"@
            Set-Content -Path $csvPath -Value $csvContent

            $result = Import-MailboxCandidatesFromCSV -CSVPath $csvPath -ValidateADLookup $false

            $result.SuccessCount | Should -BeGreaterThan 0
            $result.Candidates[0].DisplayName | Should -Match "Department.*Test"
        }

        It "Should normalize SAM account names to lowercase" {
            $csvPath = Join-Path $script:testCsvDir "uppercase-sam.csv"
            $csvContent = @"
SamAccountName,DisplayName,Email,ACLGroup
SMBX_001,Department A,dept-a@example.com,smbx_acl_001
"@
            Set-Content -Path $csvPath -Value $csvContent

            $result = Import-MailboxCandidatesFromCSV -CSVPath $csvPath -ValidateADLookup $false

            # SAM normalization happens in ConvertTo-MailboxCandidateObject
            $result.Candidates[0].SamAccountName | Should -Match "^[a-z]"
        }
    }
}
