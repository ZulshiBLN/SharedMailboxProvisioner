<#
.SYNOPSIS
Import and validate shared mailbox candidates from CSV file.

.DESCRIPTION
Reads a CSV file containing shared mailbox candidate data, validates structure and content,
and returns an array of validated candidate objects ready for provisioning.

Required CSV columns: SamAccountName, DisplayName, Email, ACLGroup
Optional CSV columns: AdminGroup, Description, CustomAttribute

This is a manual admin tool for bulk import - NOT automated via ScheduledTask.
Use for: testing, migrations, special cases, bulk corrections.

Per ADR-006: Active Directory Integration & Candidate Selection
Per CLAUDE.md: Zero Data Retention, validation at boundaries

.PARAMETER CSVPath
Full path to CSV file containing candidate data.

.PARAMETER Encoding
File encoding. Default: UTF8BOM. Fallback: UTF8, ASCII

.PARAMETER ValidateADLookup
If $true, cross-reference candidates with Active Directory (slower but safer).
Default: $true

.PARAMETER SearchBase
LDAP search base for AD validation. Default: entire domain.
Example: "OU=Mailboxes,DC=example,DC=com"

.EXAMPLE
$candidates = Import-MailboxCandidatesFromCSV -CSVPath "C:\imports\bulk-mailboxes.csv"

Validate CSV and return all valid candidates.

.EXAMPLE
$candidates = Import-MailboxCandidatesFromCSV -CSVPath "C:\imports\bulk-mailboxes.csv" -ValidateADLookup $false

Skip AD lookup for faster processing (validation only).

.NOTES
- Returns PSCustomObject array with: SamAccountName, DisplayName, Email, ACLGroup, AdminGroup, ValidationStatus, ValidationErrors
- Failed rows are skipped but included in return metadata
- Always logs import with audit trail (file hash, timestamp, user)
- CSV errors are non-blocking (continue with valid rows)
- Encoding errors automatically fallback to UTF8, then ASCII
#>

function Import-MailboxCandidatesFromCSV {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateScript({ Test-Path $_ })]
        [string]$CSVPath,

        [Parameter(Mandatory = $false)]
        [ValidateSet("UTF8", "UTF8BOM", "ASCII")]
        [string]$Encoding = "UTF8BOM",

        [Parameter(Mandatory = $false)]
        [bool]$ValidateADLookup = $true,

        [Parameter(Mandatory = $false)]
        [string]$SearchBase = ""
    )

    Write-Verbose "Starting CSV import from: $CSVPath"

    $result = @{
        SuccessCount = 0
        FailureCount = 0
        Candidates = @()
        FailedRows = @()
        ImportMetadata = @{
            SourceFile = Split-Path -Leaf $CSVPath
            SourceHash = (Get-FileHash -Path $CSVPath -Algorithm SHA256).Hash
            ImportedAt = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            ImportedBy = $env:USERNAME
            TotalRows = 0
        }
    }

    try {
        # ================================================================
        # STEP 1: Read CSV with encoding fallback
        # ================================================================
        Write-Verbose "Reading CSV file with encoding: $Encoding"
        $csvData = $null

        try {
            $csvData = Import-Csv -Path $CSVPath -Encoding $Encoding -ErrorAction Stop
        }
        catch {
            Write-Verbose "Encoding $Encoding failed, trying UTF8..."
            try {
                $csvData = Import-Csv -Path $CSVPath -Encoding UTF8 -ErrorAction Stop
            }
            catch {
                Write-Verbose "UTF8 failed, trying ASCII..."
                try {
                    $csvData = Import-Csv -Path $CSVPath -Encoding ASCII -ErrorAction Stop
                }
                catch {
                    Write-Error "Failed to read CSV file with any encoding: $_"
                    return $result
                }
            }
        }

        if (-not $csvData) {
            Write-Output "CSV file is empty or contains no data"
            Write-Log -Message "CSV import: File is empty ($CSVPath)" `
                -Level WARN -Operation "Import-MailboxCandidatesFromCSV" -Status "EMPTY_FILE"
            return $result
        }

        # ================================================================
        # STEP 2: Validate column headers
        # ================================================================
        $requiredColumns = @("SamAccountName", "DisplayName", "Email", "ACLGroup")
        $optionalColumns = @("AdminGroup", "Description", "CustomAttribute")

        if ($csvData -is [System.Collections.IEnumerable] -and $csvData -isnot [string]) {
            $firstRow = $csvData[0]
        }
        else {
            $firstRow = $csvData
        }

        if (-not $firstRow) {
            Write-Error "CSV file has no data rows"
            return $result
        }

        $csvColumns = $firstRow.PSObject.Properties.Name
        $missingColumns = @()

        foreach ($required in $requiredColumns) {
            if ($required -notin $csvColumns) {
                $missingColumns += $required
            }
        }

        if ($missingColumns.Count -gt 0) {
            $msg = "CSV missing required columns: $($missingColumns -join ', '). Found columns: $($csvColumns -join ', ')"
            Write-Error $msg
            Write-Log -Message "CSV import: Missing columns ($CSVPath): $($missingColumns -join ', ')" `
                -Level ERROR -Operation "Import-MailboxCandidatesFromCSV" -Status "INVALID_HEADERS"
            return $result
        }

        Write-Verbose "CSV columns validated: $($csvColumns -join ', ')"

        # ================================================================
        # STEP 3: Process each row
        # ================================================================
        $rowNumber = 1
        if ($csvData -is [System.Collections.IEnumerable] -and $csvData -isnot [string]) {
            $rows = $csvData
            $result.ImportMetadata.TotalRows = @($rows).Count
        }
        else {
            $rows = @($csvData)
            $result.ImportMetadata.TotalRows = 1
        }

        foreach ($row in $rows) {
            $rowNumber++

            try {
                # Convert row to candidate object
                $candidate = ConvertTo-MailboxCandidateObject -CSVRow $row -RowNumber $rowNumber

                if (-not $candidate) {
                    $result.FailureCount++
                    $result.FailedRows += @{
                        RowNumber = $rowNumber
                        Error = "ConvertTo-MailboxCandidateObject returned null"
                    }
                    continue
                }

                Write-Verbose "Row $rowNumber converted: $($candidate.SamAccountName)"

                # Validate candidate
                $validateParams = @{
                    SamAccountName = $candidate.SamAccountName
                    DisplayName = $candidate.DisplayName
                    Email = $candidate.Email
                    ACLGroup = $candidate.ACLGroup
                    ValidateADLookup = $ValidateADLookup
                }

                if (-not [string]::IsNullOrWhiteSpace($SearchBase)) {
                    $validateParams['SearchBase'] = $SearchBase
                }

                $validation = Test-SharedMailboxCandidate @validateParams

                if ($validation.IsValid) {
                    $candidate | Add-Member -NotePropertyName ValidationStatus -NotePropertyValue "VALID"
                    $candidate | Add-Member -NotePropertyName ValidationErrors -NotePropertyValue @()
                    $candidate | Add-Member -NotePropertyName SourceRow -NotePropertyValue $rowNumber

                    $result.Candidates += $candidate
                    $result.SuccessCount++

                    Write-Verbose "Row $rowNumber VALID: $($candidate.SamAccountName)"
                }
                else {
                    $candidate | Add-Member -NotePropertyName ValidationStatus -NotePropertyValue "INVALID"
                    $candidate | Add-Member -NotePropertyName ValidationErrors -NotePropertyValue $validation.Errors
                    $candidate | Add-Member -NotePropertyName SourceRow -NotePropertyValue $rowNumber

                    $result.Candidates += $candidate
                    $result.FailureCount++

                    Write-Verbose "Row $rowNumber INVALID: $($candidate.SamAccountName) - Errors: $($validation.Errors -join '; ')"
                }
            }
            catch {
                $result.FailureCount++
                $result.FailedRows += @{
                    RowNumber = $rowNumber
                    SamAccountName = $row.SamAccountName
                    Error = $_.Exception.Message
                }

                Write-Verbose "Row $rowNumber exception: $_"
            }
        }

        # ================================================================
        # STEP 4: Log import
        # ================================================================
        Write-Log -Message "CSV import completed: $($result.SuccessCount) valid, $($result.FailureCount) invalid from $($result.ImportMetadata.TotalRows) total rows ($CSVPath)" `
            -Level INFO -Operation "Import-MailboxCandidatesFromCSV" -Status "COMPLETE"

        Write-Output "Import Summary: $($result.SuccessCount) valid, $($result.FailureCount) invalid, $($result.ImportMetadata.TotalRows) total"

        return $result
    }
    catch {
        $msg = "CSV import failed: $_"
        Write-Error $msg
        Write-Log -Message $msg -Level ERROR -Operation "Import-MailboxCandidatesFromCSV" -Status "FAILED"
        return $result
    }
}

Export-ModuleMember -Function Import-MailboxCandidatesFromCSV
