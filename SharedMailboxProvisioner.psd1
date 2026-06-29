@{
    RootModule = 'SharedMailboxProvisioner.psm1'
    ModuleVersion = '0.1.0'
    GUID = [System.Guid]::NewGuid().ToString()
    Author = 'Michel Brosche'
    CompanyName = 'Cloud Operations'
    Description = 'PowerShell Automation für Exchange Online SharedMailbox Provisioning'
    PowerShellVersion = '5.1'
    RequiredModules = @()
    FunctionsToExport = @()
    CmdletsToExport = @()
    VariablesToExport = @()
    AliasesToExport = @()
    PrivateData = @{
        PSData = @{
            Tags = @('ExchangeOnline', 'SharedMailbox', 'Provisioning', 'Automation')
            ProjectUri = 'https://github.com/yourusername/SharedMailboxProvisioner'
            LicenseUri = 'https://github.com/yourusername/SharedMailboxProvisioner/blob/main/LICENSE'
        }
    }
}
