<#
.SYNOPSIS
Format raw data for human-readable output.

Helper function for report formatting (percentages, durations, dates, CSV escaping).
#>

function _ConvertTo-MailboxReportFormat {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseApprovedVerbs', '', Justification = 'Verb is approved (ConvertTo) - PSScriptAnalyzer cannot parse verb-noun past the leading underscore when analyzing a standalone file. See COMPLIANCE-AUDIT-PHASE-PRERELEASE.md Finding 2.2')]
    param(
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$ReportData,

        [Parameter(Mandatory = $false)]
        [ValidateSet("HTML", "CSV", "Text", "JSON")]
        [string]$Format = "Text"
    )

    Write-Verbose "Formatting report data for $Format output"

    try {
        switch ($Format) {
            "HTML" {
                _FormatAsHtmlTable $ReportData
            }
            "CSV" {
                _FormatAsCsv $ReportData
            }
            "Text" {
                _FormatAsText $ReportData
            }
            "JSON" {
                $ReportData | ConvertTo-Json -Depth 10
            }
        }
    }
    catch {
        Write-Error "Failed to format report data: $_"
        return $null
    }
}

function _FormatAsHtmlTable {
    param([PSCustomObject]$Data)

    $html = "<table>`n"

    if ($Data.GetType().Name -eq "Object[]") {
        $properties = $Data[0].PSObject.Properties.Name
        $html += "<tr>"
        foreach ($prop in $properties) {
            $html += "<th>$prop</th>"
        }
        $html += "</tr>`n"

        foreach ($item in $Data) {
            $html += "<tr>"
            foreach ($prop in $properties) {
                $value = $item.$prop
                $html += "<td>$value</td>"
            }
            $html += "</tr>`n"
        }
    }
    else {
        $properties = $Data.PSObject.Properties.Name
        foreach ($prop in $properties) {
            $value = $Data.$prop
            $html += "<tr><th>$prop</th><td>$value</td></tr>`n"
        }
    }

    $html += "</table>"
    return $html
}

function _FormatAsCsv {
    param([PSCustomObject]$Data)

    $csv = ""

    if ($Data.GetType().Name -eq "Object[]") {
        $properties = $Data[0].PSObject.Properties.Name
        $csv += ($properties -join ",") + "`n"

        foreach ($item in $Data) {
            $values = @()
            foreach ($prop in $properties) {
                $value = [string]($item.$prop)
                # Escape CSV: quote if contains comma, quote, or newline
                if ($value -match '[",\n]') {
                    $value = "`"$($value -replace '"', '""')`""
                }
                $values += $value
            }
            $csv += ($values -join ",") + "`n"
        }
    }
    else {
        $properties = $Data.PSObject.Properties.Name
        foreach ($prop in $properties) {
            $value = $Data.$prop
            if ($value -match '[",\n]') {
                $value = "`"$($value -replace '"', '""')`""
            }
            $csv += "$prop,`"$value`"`n"
        }
    }

    return $csv
}

function _FormatAsText {
    param([PSCustomObject]$Data)

    $text = ""

    if ($Data.GetType().Name -eq "Object[]") {
        foreach ($item in $Data) {
            $text += _FormatObjectAsText $item
            $text += "`n"
        }
    }
    else {
        $text = _FormatObjectAsText $Data
    }

    return $text
}

function _FormatObjectAsText {
    param([PSCustomObject]$Item)

    $text = ""
    $properties = $Item.PSObject.Properties.Name

    foreach ($prop in $properties) {
        $value = $Item.$prop
        $text += "$($prop): $value`n"
    }

    return $text
}
