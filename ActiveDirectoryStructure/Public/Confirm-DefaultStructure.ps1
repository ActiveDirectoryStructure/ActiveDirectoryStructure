Function Confirm-DefaultStructure
{
    [CmdletBinding(
        DefaultParameterSetName = 'Default',
        SupportsShouldProcess = $True,
        ConfirmImpact = 'High'
    )]
    Param
    (
        [Parameter(Mandatory = $True, ParameterSetName = 'Default')]
        [Parameter(Mandatory = $True, ParameterSetName = 'CreateOnly')]
        [Parameter(Mandatory = $True, ParameterSetName = 'SkipOUDelete')]
        [Parameter(Mandatory = $True, ParameterSetName = 'DeleteOnly')]
        [Parameter(Mandatory = $True, ParameterSetName = 'ACLOnly')]
        [Parameter(Mandatory = $True, ParameterSetName = 'NoACL')]
        [Parameter(Mandatory = $True, ParameterSetName = 'ContainerOnly')]
        [String] $RootPath,

        [Parameter(Mandatory = $True, ParameterSetName = 'Default')]
        [Parameter(Mandatory = $True, ParameterSetName = 'CreateOnly')]
        [Parameter(Mandatory = $True, ParameterSetName = 'SkipOUDelete')]
        [Parameter(Mandatory = $True, ParameterSetName = 'DeleteOnly')]
        [Parameter(Mandatory = $True, ParameterSetName = 'ACLOnly')]
        [Parameter(Mandatory = $True, ParameterSetName = 'NoACL')]
        [Parameter(Mandatory = $True, ParameterSetName = 'ContainerOnly')]
        [String] $ADServer,

        [Parameter(Mandatory = $False, ParameterSetName = 'CreateOnly')]
        [Switch] $CreateOnly,

        [Parameter(Mandatory = $False, ParameterSetName = 'SkipOUDelete')]
        [Switch] $SkipOUDelete,

        [Parameter(Mandatory = $False, ParameterSetName = 'DeleteOnly')]
        [Switch] $DeleteOnly,

        [Parameter(Mandatory = $False, ParameterSetName = 'ACLOnly')]
        [Switch] $ACLOnly,

        [Parameter(Mandatory = $False, ParameterSetName = 'NoACL')]
        [Switch] $NoACL,

        [Parameter(Mandatory = $False, ParameterSetName = 'ContainerOnly')]
        [Switch] $ContainerOnly
    )
    Begin
    {
        $ErrorActionPreference = 'Stop'

        If ($Null -eq (Get-Module -Name ActiveDirectory))
        {
            Import-Module ActiveDirectory
        }
        If ($Null -eq (Get-Module -Name GroupPolicy))
        {
            Import-Module GroupPolicy
        }

        $Script:XmlRootPath = $RootPath
    
        $Structure = ([XML](Get-Content -Path (Join-Path -Path $Script:XmlRootPath -ChildPath 'Structure.xml'))).OrganizationalStructure
        $Variables = ([XML](Get-Content -Path (Join-Path -Path $Script:XmlRootPath -ChildPath 'Variables.xml'))).Variables

        $Script:ADDC = $Structure.ADDC
        $Script:ADDN = $Structure.ADDN

        $Script:GPOGroups = $Null
        $Script:Permissions = $Null
        $Script:AllGPOs = Get-GPO -All -Server $ADServer
    }

    Process
    {
        If (-not $CreateOnly.IsPresent)
        {
            ForEach ($container in @('System', 'Configuration', 'Users', 'Computers', 'Builtin'))
            {
                $xmlContainer = $Structure.$container
                If ($Null -ne $xmlContainer)
                {
                    $Parameters = @{
                        ADServer           = $ADServer
                        DistinguishedName  = $Script:ADDC
                        ContainerStructure = $xmlContainer
                        ACLOnly            = $ACLOnly.IsPresent
                        NoACL              = $NoACL.IsPresent
                        WhatIf             = $WhatIfPreference
                        TopLevel           = $True
                    }
                    Confirm-ADSContainer @Parameters
                }
            }
        }

        If (-not $ContainerOnly.IsPresent)
        {
            ForEach ($topLevelOU in $Structure.OU)
            {
                $Parameters = @{
                    ADServer          = $ADServer
                    DistinguishedName = $Script:ADDN
                    OUStructure       = $topLevelOU
                    CreateOnly        = $CreateOnly.IsPresent
                    SkipOUDelete      = $SkipOUDelete.IsPresent
                    DeleteOnly        = $DeleteOnly.IsPresent
                    ACLOnly           = $ACLOnly.IsPresent
                    NoACL             = $NoACL.IsPresent
                    Variables         = $Variables
                    WhatIf            = $WhatIfPreference
                    TopLevel          = $True
                }
                Confirm-ADSOrganizationalStructure @Parameters
            }
        }
    }
}
