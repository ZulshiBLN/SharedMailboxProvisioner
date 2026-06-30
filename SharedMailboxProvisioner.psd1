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
    FunctionsToExport = @(
        # Tier 0: Connection
        'Connect-ExchangeOnlineEnv'
        # Tier 2: Group Discovery
        'Get-SharedMailboxACLGroup'
        # Tier 3: Validation
        'Test-SharedMailboxCandidate'
        # Tier 4: Candidate Discovery
        'Get-SharedMailboxCandidates'
        'Get-SharedMailboxCandidatesWithGroups'
        # Tier 5: Exchange Provisioning
        'New-SharedMailboxRemote'
        'Invoke-MailboxPermissionQueue'
        # Tier 6: Orchestration
        'Invoke-SharedMailboxProvisioning'
        # Tier 7: Manual Bulk Import
        'Import-MailboxCandidatesFromCSV'
        'Test-MailboxBulkImport'
        # Tier 8: Reporting & Audit
        'Get-MailboxProvisioningReport'
        'Export-MailboxAuditLog'
        'Get-MailboxProvisioningMetrics'
        # Tier 10: Operational Tooling
        'Get-MailboxProvisioningStatus'
        'Resolve-MailboxProvisioningFailure'
        'Invoke-MailboxProvisioningRetry'
        'Set-MailboxProvisioningSchedule'
        'Get-MailboxProvisioningHealth'
    )
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
