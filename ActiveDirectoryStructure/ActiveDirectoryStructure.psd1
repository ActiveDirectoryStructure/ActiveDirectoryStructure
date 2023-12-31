@{

    RootModule           = 'ActiveDirectoryStructure.psm1'

    ModuleVersion        = '1.1.2'

    CompatiblePSEditions = @('Desktop')

    GUID                 = 'd58f88a2-d582-49ae-8cf7-14abf6d4db3a'

    Author               = 'Gerald Doeserich'
    CompanyName          = 'ActiveDirectoryStructure'
    Copyright            = '(c) 2023 Gerald Doeserich. All rights reserved.'
    Description          = 'Provides ways to validate a ActiveDirectory environment'

    PowerShellVersion    = '5.1'

    FunctionsToExport    = @(
        'Confirm-DefaultStructure'
        'New-GeneratedReport'
        'New-Report'
    )

    CmdletsToExport      = @()

    VariablesToExport    = ''

    AliasesToExport      = @()

    FileList             = @()

    PrivateData          = @{

        PSData = @{
            Tags       = @('ActiveDirectory')
            LicenseUri = 'https://github.com/ActiveDirectoryStructure/ActiveDirectoryStructure/blob/main/LICENSE'
            ProjectUri = 'https://github.com/ActiveDirectoryStructure/ActiveDirectoryStructure'
        }

    }

    HelpInfoURI          = 'https://github.com/ActiveDirectoryStructure/ActiveDirectoryStructure'
    DefaultCommandPrefix = 'ADS'
}
