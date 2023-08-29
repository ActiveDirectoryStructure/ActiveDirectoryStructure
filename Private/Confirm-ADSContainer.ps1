Function Confirm-ADSContainer
{
    [CmdLetBinding(SupportsShouldProcess = $True)]
    Param
    (
        [Parameter(Mandatory = $True)]
        [String] $DistinguishedName,
        [Parameter(Mandatory = $True)]
        $ContainerStructure,

        [Switch] $ACLOnly,
        [Switch] $NoACL,
        
        [Switch] $TopLevel
    )

    Begin
    {
        Write-Verbose "[$($DistinguishedName)] Start $($MyInvocation.InvocationName)"

        $ErrorActionPreference = 'Stop'

        If ($TopLevel.IsPresent)
        {
            Write-Verbose "[$($DistinguishedName)] ACLOnly: $($ACLOnly.IsPresent)"
            Write-Verbose "[$($DistinguishedName)] NoACL: $($NoACL.IsPresent)"
        }
    }

    Process
    {
        $ContainerName = $($ContainerStructure.Name)
        If ([String]::IsNullOrEmpty($ContainerName))
        {
            # This basically means that the XML object is empty so skip it
            Write-Verbose "[$($DistinguishedName)] Container seems to contain no rules. Skipping"
            Continue
        }

        $ContainerDistinguishedName = "CN=$($ContainerName),$($DistinguishedName)"

        $Container = Get-ADObject -Identity $ContainerDistinguishedName -ErrorAction SilentlyContinue
        If ($Null -eq $Container)
        {
            Write-Error "[$($DistinguishedName)] Expected Container at '$($ContainerDistinguishedName)' but found nothing"
        }
        Else
        {
            If (-not $NoACL.IsPresent)
            {
                Confirm-ADSOrganizationalStructureACL -DistinguishedName $ContainerDistinguishedName -Structure $ContainerStructure -WhatIf:$WhatIfPreference
            }
        }

        # Process Groups
        If ($Null -ne $ContainerStructure.Group)
        {
            ForEach ($group in $ContainerStructure.Group)
            {
                $groupDistinguishedName = Get-GroupDistinguishedName -Group $group
                Confirm-ADSOrganizationalStructureACL -DistinguishedName $groupDistinguishedName -Variables $Variables -Structure $group -WhatIf:$WhatIfPreference
            }
        }

        If ($Null -ne $ContainerStructure.Container)
        {
            ForEach ($subContainer in $ContainerStructure.Container)
            {
                $Parameters = @{
                    DistinguishedName  = $ContainerDistinguishedName
                    ContainerStructure = $subContainer
                    ACLOnly            = $ACLOnly
                    NoACL              = $NoACL
                    WhatIf             = $WhatIfPreference
                }
                Confirm-ADSContainer @Parameters
            }
        }
    }
}