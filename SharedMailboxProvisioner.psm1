# SharedMailboxProvisioner Module Root
# Imports all public functions for external use

$Public = @(Get-ChildItem -Path "$PSScriptRoot\functions\Public" -Filter "*.ps1" -ErrorAction SilentlyContinue)
$Private = @(Get-ChildItem -Path "$PSScriptRoot\functions\Private" -Filter "*.ps1" -ErrorAction SilentlyContinue)

foreach ($import in @($Public + $Private)) {
    try {
        . $import.FullName
    }
    catch {
        Write-Error "Failed to import $($import.FullName): $_"
    }
}

Export-ModuleMember -Function $Public.BaseName
