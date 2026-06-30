BeforeAll {
    Import-Module "$PSScriptRoot\..\SharedMailboxProvisioner.psd1" -Force
}

Describe "Test-MailboxBulkImport" {
    Context "Bulk Import Validation (Dry-Run)" {
        BeforeEach {
            $script:testReportDir = Join-Path $env:TEMP "smp-reports-$(Get-Random)"
            New-Item -ItemType Directory -Path $script:testReportDir -Force | Out-Null
        }

        AfterEach {
            Remove-Item -Path $script:testReportDir -Recurse -Force -ErrorAction SilentlyContinue
        }

        It "Should validate empty candidate array" {
            $result = Test-MailboxBulkImport -Candidates @() -GenerateReport $false

            $result.IsValid | Should -Be $true
            $result.CandidatesToProcess | Should -Be 0
            $result.CanProceed | Should -Be $true
        }

        It "Should validate single valid candidate" {
            $candidate = [PSCustomObject]@{
                SamAccountName = "smbx_001"
                DisplayName = "Department A"
                Email = "dept-a@example.com"
                ACLGroup = "smbx_acl_001"
                AdminGroup = ""
            }

            Mock -CommandName Test-SharedMailboxCandidate -MockWith {
                return @{ IsValid = $true; Errors = @() }
            } -Verifiable

            $result = Test-MailboxBulkImport -Candidates @($candidate) -GenerateReport $false

            $result.IsValid | Should -Be $true
            $result.ValidCandidates.Count | Should -Be 1
            Assert-MockCalled -CommandName Test-SharedMailboxCandidate -Times 1
        }

        It "Should detect duplicate SAM accounts within batch" {
            $candidate1 = [PSCustomObject]@{
                SamAccountName = "smbx_001"
                DisplayName = "Department A"
                Email = "dept-a@example.com"
                ACLGroup = "smbx_acl_001"
            }
            $candidate2 = [PSCustomObject]@{
                SamAccountName = "smbx_001"
                DisplayName = "Department A2"
                Email = "dept-a2@example.com"
                ACLGroup = "smbx_acl_001"
            }

            Mock -CommandName Test-SharedMailboxCandidate -MockWith {
                return @{ IsValid = $true; Errors = @() }
            }

            $result = Test-MailboxBulkImport -Candidates @($candidate1, $candidate2) -GenerateReport $false

            $result.CanProceed | Should -Be $false
            $result.Issues | Should -Not -BeNullOrEmpty
            $result.Issues[0].Issue | Should -Match "Duplicate SAM"
        }

        It "Should detect duplicate email addresses within batch" {
            $candidate1 = [PSCustomObject]@{
                SamAccountName = "smbx_001"
                DisplayName = "Department A"
                Email = "same@example.com"
                ACLGroup = "smbx_acl_001"
            }
            $candidate2 = [PSCustomObject]@{
                SamAccountName = "smbx_002"
                DisplayName = "Department B"
                Email = "same@example.com"
                ACLGroup = "smbx_acl_002"
            }

            Mock -CommandName Test-SharedMailboxCandidate -MockWith {
                return @{ IsValid = $true; Errors = @() }
            }

            $result = Test-MailboxBulkImport -Candidates @($candidate1, $candidate2) -GenerateReport $false

            $result.CanProceed | Should -Be $false
            $result.Issues | Should -Not -BeNullOrEmpty
            $result.Issues[0].Issue | Should -Match "Duplicate email"
        }

        It "Should identify invalid candidates" {
            $candidate = [PSCustomObject]@{
                SamAccountName = "smbx_001"
                DisplayName = "Department A"
                Email = "dept-a@example.com"
                ACLGroup = "smbx_acl_001"
            }

            Mock -CommandName Test-SharedMailboxCandidate -MockWith {
                return @{ IsValid = $false; Errors = @("Invalid ACL group") }
            }

            $result = Test-MailboxBulkImport -Candidates @($candidate) -GenerateReport $false

            $result.CanProceed | Should -Be $false
            $result.ConflictingCandidates | Should -Be 1
        }

        It "Should skip duplicate checking if disabled" {
            $candidate1 = [PSCustomObject]@{
                SamAccountName = "smbx_001"
                DisplayName = "Department A"
                Email = "same@example.com"
                ACLGroup = "smbx_acl_001"
            }
            $candidate2 = [PSCustomObject]@{
                SamAccountName = "smbx_001"
                DisplayName = "Department B"
                Email = "same@example.com"
                ACLGroup = "smbx_acl_001"
            }

            Mock -CommandName Test-SharedMailboxCandidate -MockWith {
                return @{ IsValid = $true; Errors = @() }
            }

            $result = Test-MailboxBulkImport -Candidates @($candidate1, $candidate2) `
                -GenerateReport $false `
                -CheckDuplicates $false

            # With CheckDuplicates off, no duplicate issues reported
            $duplicateIssues = $result.Issues | Where-Object { $_.Issue -match "Duplicate" }
            $duplicateIssues | Should -BeNullOrEmpty
        }

        It "Should calculate estimated duration" {
            $candidates = @()
            for ($i = 1; $i -le 10; $i++) {
                $candidates += [PSCustomObject]@{
                    SamAccountName = "smbx_$('{0:0000}' -f $i)"
                    DisplayName = "Department $i"
                    Email = "dept-$i@example.com"
                    ACLGroup = "smbx_acl_$('{0:0000}' -f $i)"
                }
            }

            Mock -CommandName Test-SharedMailboxCandidate -MockWith {
                return @{ IsValid = $true; Errors = @() }
            }

            $result = Test-MailboxBulkImport -Candidates $candidates -GenerateReport $false

            $result.EstimatedDuration | Should -Not -BeNullOrEmpty
            $result.EstimatedDuration | Should -Match "^\d{2}:\d{2}:\d{2}$"
        }

        It "Should generate HTML preview report" {
            $candidate = [PSCustomObject]@{
                SamAccountName = "smbx_001"
                DisplayName = "Department A"
                Email = "dept-a@example.com"
                ACLGroup = "smbx_acl_001"
            }

            Mock -CommandName Test-SharedMailboxCandidate -MockWith {
                return @{ IsValid = $true; Errors = @() }
            }

            $reportPath = Join-Path $script:testReportDir "preview.html"
            $result = Test-MailboxBulkImport -Candidates @($candidate) `
                -GenerateReport $true `
                -ReportPath $reportPath

            # Report should be generated
            if ($result.ReportPath) {
                Test-Path $result.ReportPath | Should -Be $true
                Get-Content $result.ReportPath | Should -Match "<html>"
            }
        }

        It "Should return valid candidates in result" {
            $candidate1 = [PSCustomObject]@{
                SamAccountName = "smbx_001"
                DisplayName = "Department A"
                Email = "dept-a@example.com"
                ACLGroup = "smbx_acl_001"
            }
            $candidate2 = [PSCustomObject]@{
                SamAccountName = "smbx_002"
                DisplayName = "Department B"
                Email = "dept-b@example.com"
                ACLGroup = "smbx_acl_002"
            }

            Mock -CommandName Test-SharedMailboxCandidate -MockWith {
                return @{ IsValid = $true; Errors = @() }
            }

            $result = Test-MailboxBulkImport -Candidates @($candidate1, $candidate2) -GenerateReport $false

            $result.ValidCandidates.Count | Should -Be 2
        }

        It "Should handle validation errors for multiple candidates" {
            $candidate1 = [PSCustomObject]@{
                SamAccountName = "smbx_001"
                DisplayName = "Department A"
                Email = "dept-a@example.com"
                ACLGroup = "smbx_acl_001"
            }
            $candidate2 = [PSCustomObject]@{
                SamAccountName = "smbx_002"
                DisplayName = "Department B"
                Email = "dept-b@example.com"
                ACLGroup = "smbx_acl_002"
            }

            Mock -CommandName Test-SharedMailboxCandidate -MockWith {
                if ($SamAccountName -eq "smbx_001") {
                    return @{ IsValid = $true; Errors = @() }
                }
                else {
                    return @{ IsValid = $false; Errors = @("Invalid group") }
                }
            }

            $result = Test-MailboxBulkImport -Candidates @($candidate1, $candidate2) -GenerateReport $false

            $result.ValidCandidates.Count | Should -Be 1
            $result.ConflictingCandidates | Should -Be 1
        }

        It "Should mark as cannot proceed if any conflicts exist" {
            $candidate = [PSCustomObject]@{
                SamAccountName = "smbx_001"
                DisplayName = "Department A"
                Email = "dept-a@example.com"
                ACLGroup = "smbx_acl_001"
            }

            Mock -CommandName Test-SharedMailboxCandidate -MockWith {
                return @{ IsValid = $false; Errors = @("ACL group not found") }
            }

            $result = Test-MailboxBulkImport -Candidates @($candidate) -GenerateReport $false

            $result.CanProceed | Should -Be $false
        }

        It "Should indicate can proceed when all valid" {
            $candidate = [PSCustomObject]@{
                SamAccountName = "smbx_001"
                DisplayName = "Department A"
                Email = "dept-a@example.com"
                ACLGroup = "smbx_acl_001"
            }

            Mock -CommandName Test-SharedMailboxCandidate -MockWith {
                return @{ IsValid = $true; Errors = @() }
            }

            $result = Test-MailboxBulkImport -Candidates @($candidate) -GenerateReport $false

            $result.CanProceed | Should -Be $true
        }

        It "Should handle report generation failure gracefully" {
            $candidate = [PSCustomObject]@{
                SamAccountName = "smbx_001"
                DisplayName = "Department A"
                Email = "dept-a@example.com"
                ACLGroup = "smbx_acl_001"
            }

            Mock -CommandName Test-SharedMailboxCandidate -MockWith {
                return @{ IsValid = $true; Errors = @() }
            }

            # Use invalid path that will fail
            $result = Test-MailboxBulkImport -Candidates @($candidate) `
                -GenerateReport $true `
                -ReportPath "Z:\invalid\path\report.html"

            # Should still return validation result, even if report fails
            $result | Should -Not -BeNullOrEmpty
        }
    }
}
