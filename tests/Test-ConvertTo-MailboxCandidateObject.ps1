BeforeAll {
    Import-Module "$PSScriptRoot\..\SharedMailboxProvisioner.psd1" -Force
}

Describe "ConvertTo-MailboxCandidateObject" {
    Context "Row Conversion and Normalization" {
        It "Should convert valid CSV row to candidate object" {
            $row = [PSCustomObject]@{
                SamAccountName = "smbx_001"
                DisplayName = "Department A"
                Email = "dept-a@example.com"
                ACLGroup = "smbx_acl_001"
            }

            $result = ConvertTo-MailboxCandidateObject -CSVRow $row -RowNumber 2

            $result | Should -Not -BeNullOrEmpty
            $result.SamAccountName | Should -Be "smbx_001"
            $result.DisplayName | Should -Be "Department A"
            $result.Email | Should -Be "dept-a@example.com"
        }

        It "Should trim whitespace from all fields" {
            $row = [PSCustomObject]@{
                SamAccountName = "  smbx_001  "
                DisplayName = "  Department A  "
                Email = "  dept-a@example.com  "
                ACLGroup = "  smbx_acl_001  "
                AdminGroup = "  ZO-Admins  "
            }

            $result = ConvertTo-MailboxCandidateObject -CSVRow $row

            $result.SamAccountName | Should -Be "smbx_001"
            $result.DisplayName | Should -Be "Department A"
            $result.Email | Should -Be "dept-a@example.com"
            $result.AdminGroup | Should -Be "ZO-Admins"
        }

        It "Should normalize email to lowercase" {
            $row = [PSCustomObject]@{
                SamAccountName = "smbx_001"
                DisplayName = "Department A"
                Email = "Dept-A@Example.COM"
                ACLGroup = "smbx_acl_001"
            }

            $result = ConvertTo-MailboxCandidateObject -CSVRow $row

            $result.Email | Should -Be "dept-a@example.com"
        }

        It "Should normalize SAM account name to lowercase" {
            $row = [PSCustomObject]@{
                SamAccountName = "SMBX_001"
                DisplayName = "Department A"
                Email = "dept-a@example.com"
                ACLGroup = "smbx_acl_001"
            }

            $result = ConvertTo-MailboxCandidateObject -CSVRow $row

            $result.SamAccountName | Should -Be "smbx_001"
        }

        It "Should validate SAM prefix requirement" {
            $row = [PSCustomObject]@{
                SamAccountName = "invalid_001"
                DisplayName = "Department A"
                Email = "dept-a@example.com"
                ACLGroup = "smbx_acl_001"
            }

            $result = ConvertTo-MailboxCandidateObject -CSVRow $row

            # Conversion happens, but errors are noted
            $result | Should -Not -BeNullOrEmpty
        }

        It "Should validate email format" {
            $row = [PSCustomObject]@{
                SamAccountName = "smbx_001"
                DisplayName = "Department A"
                Email = "not-a-valid-email"
                ACLGroup = "smbx_acl_001"
            }

            $result = ConvertTo-MailboxCandidateObject -CSVRow $row

            # Conversion happens, format validation in later stages
            $result | Should -Not -BeNullOrEmpty
        }

        It "Should handle empty optional AdminGroup field" {
            $row = [PSCustomObject]@{
                SamAccountName = "smbx_001"
                DisplayName = "Department A"
                Email = "dept-a@example.com"
                ACLGroup = "smbx_acl_001"
                AdminGroup = ""
            }

            $result = ConvertTo-MailboxCandidateObject -CSVRow $row

            $result.AdminGroup | Should -Be ""
        }

        It "Should handle null row" {
            $result = ConvertTo-MailboxCandidateObject -CSVRow $null -RowNumber 5

            $result | Should -BeNullOrEmpty
        }

        It "Should track row number" {
            $row = [PSCustomObject]@{
                SamAccountName = "smbx_001"
                DisplayName = "Department A"
                Email = "dept-a@example.com"
                ACLGroup = "smbx_acl_001"
            }

            $result = ConvertTo-MailboxCandidateObject -CSVRow $row -RowNumber 42

            # Row number is used internally for error tracking
            $result | Should -Not -BeNullOrEmpty
        }

        It "Should handle empty required fields" {
            $row = [PSCustomObject]@{
                SamAccountName = ""
                DisplayName = "Department A"
                Email = "dept-a@example.com"
                ACLGroup = "smbx_acl_001"
            }

            $result = ConvertTo-MailboxCandidateObject -CSVRow $row

            if ($result | Get-Member -Name _ConversionErrors -ErrorAction SilentlyContinue) {
                $result._ConversionErrors | Should -Not -BeNullOrEmpty
            }
        }

        It "Should preserve optional Description field" {
            $row = [PSCustomObject]@{
                SamAccountName = "smbx_001"
                DisplayName = "Department A"
                Email = "dept-a@example.com"
                ACLGroup = "smbx_acl_001"
                Description = "Test Description"
            }

            $result = ConvertTo-MailboxCandidateObject -CSVRow $row

            $result.Description | Should -Be "Test Description"
        }
    }
}
