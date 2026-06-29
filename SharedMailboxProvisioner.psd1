@{
    RootModule = 'SharedMailboxProvisioner.psm1'
    ModuleVersion = '0.1.0'
    GUID = '50f777da-b442-4736-a21a-d05fc91849f5'
    Author = 'Michel Brosche'
    CompanyName = 'Cloud Operations'
    Description = 'PowerShell Automation für Exchange Online SharedMailbox Provisioning'
    PowerShellVersion = '5.1'
    RequiredModules = @(
        @{ ModuleName = 'ExchangeOnlineManagement'; ModuleVersion = '3.1.0' }
    )
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
