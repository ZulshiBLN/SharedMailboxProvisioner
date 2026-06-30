<#
.SYNOPSIS
Transform CSV row into normalized candidate PSCustomObject.
#>

function _BuildMailboxCandidateObject {
    param(
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$CSVRow,

        [Parameter(Mandatory = $false)]
        [int]$RowNumber = 0
    )

    Write-Verbose "Converting CSV row to candidate object (row $RowNumber)"

    try {
        if (-not $CSVRow) {
            Write-Error "CSVRow is null"
            return $null
        }

        # Extract and normalize fields
        $samAccountName = $CSVRow.SamAccountName
        $displayName = $CSVRow.DisplayName
        $email = $CSVRow.Email
        $aclGroup = $CSVRow.ACLGroup
        $adminGroup = $CSVRow.AdminGroup
        $description = $CSVRow.Description

        # ================================================================
        # Normalize: Trim whitespace
        # ================================================================
        if ($samAccountName) {
            $samAccountName = $samAccountName.Trim()
        }
        if ($displayName) {
            $displayName = $displayName.Trim()
        }
        if ($email) {
            $email = $email.Trim()
        }
        if ($aclGroup) {
            $aclGroup = $aclGroup.Trim()
        }
        if ($adminGroup) {
            $adminGroup = $adminGroup.Trim()
        }
        if ($description) {
            $description = $description.Trim()
        }

        # ================================================================
        # Normalize: Convert to lowercase where applicable
        # ================================================================
        if ($samAccountName) {
            $samAccountName = $samAccountName.ToLower()
        }
        if ($email) {
            $email = $email.ToLower()
        }

        # ================================================================
        # Validate format (basic checks, detailed validation in Test-SharedMailboxCandidate)
        # ================================================================
        $errors = @()

        if ([string]::IsNullOrWhiteSpace($samAccountName)) {
            $errors += "SamAccountName is empty"
        }
        elseif (-not $samAccountName.StartsWith("smbx_")) {
            $errors += "SamAccountName must start with 'smbx_' prefix"
        }

        if ([string]::IsNullOrWhiteSpace($displayName)) {
            $errors += "DisplayName is empty"
        }

        if ([string]::IsNullOrWhiteSpace($email)) {
            $errors += "Email is empty"
        }
        elseif ($email -notmatch '^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$') {
            $errors += "Email format is invalid"
        }

        if ([string]::IsNullOrWhiteSpace($aclGroup)) {
            $errors += "ACLGroup is empty"
        }

        # Return candidate object
        $adminGroupVal = if ([string]::IsNullOrWhiteSpace($adminGroup)) {
            ""
        }
        else {
            $adminGroup
        }

        $descriptionVal = if ([string]::IsNullOrWhiteSpace($description)) {
            ""
        }
        else {
            $description
        }

        $candidate = [PSCustomObject]@{
            SamAccountName = $samAccountName
            DisplayName = $displayName
            Email = $email
            ACLGroup = $aclGroup
            AdminGroup = $adminGroupVal
            Description = $descriptionVal
        }

        if ($errors.Count -gt 0) {
            $candidate | Add-Member -NotePropertyName _ConversionErrors -NotePropertyValue $errors
            Write-Verbose "Row $RowNumber conversion completed with errors: $($errors -join '; ')"
        }
        else {
            Write-Verbose "Row $RowNumber converted successfully: $samAccountName"
        }

        return $candidate
    }
    catch {
        Write-Error "Failed to convert CSV row: $_"
        return $null
    }
}
