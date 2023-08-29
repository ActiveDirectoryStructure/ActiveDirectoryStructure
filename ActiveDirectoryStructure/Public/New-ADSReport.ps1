Function New-ADSReport
{
    Param
    (
        [Parameter(Mandatory = $True)]
        [String] $RootPath,

        [Parameter(Mandatory = $True)]
        [String] $OutputPath
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

        $Script:ADDC = $Structure.ADDC
        $Script:ADDN = $Structure.ADDN

        Function Get-ContainerXml
        {
            Param
            (
                [Parameter(Mandatory = $True)]
                [String] $DistinguishedName,
                [Parameter(Mandatory = $True)]
                $ContainerName,
                [Parameter(Mandatory = $True)]
                $ParentElement
            )

            Begin
            {
                $ContainerDistinguishedName = "CN=$($ContainerName),$($DistinguishedName)"
                Write-Verbose "[$($ContainerDistinguishedName)] Start $($MyInvocation.InvocationName)"
            }

            Process
            {
                $ElementName = 'Container'
                $OwnerDocument = $ParentElement.OwnerDocument
                If ($Null -eq $OwnerDocument)
                {
                    $OwnerDocument = $ParentElement
                    $ElementName = $ContainerName
                }
            
                $Element = $OwnerDocument.CreateNode([System.Xml.XmlNodeType]::Element, $ElementName, '')
                $Element.SetAttribute('Name', $ContainerName) | Out-Null
                If ($Null -ne $ParentElement.DocumentElement)
                {
                    $ParentElement.DocumentElement.AppendChild($Element) | Out-Null
                }
                Else
                {
                    $ParentElement.AppendChild($Element) | Out-Null
                }

                $ChildOUs = Get-ADObject -Filter * -SearchBase $ContainerDistinguishedName -SearchScope OneLevel | Where-Object { $_.ObjectClass -eq 'Container' }
                ForEach ($ou in $ChildOUs)
                {
                    Get-ContainerXml -DistinguishedName $ContainerDistinguishedName -ContainerName $($ou.Name) -ParentElement $Element
                }
            }

            End
            {
                Write-Verbose "[$($ContainerDistinguishedName)] End $($MyInvocation.InvocationName)"
            }
        }

        Function Get-OrganizationalUnitXml
        {
            Param
            (
                [Parameter(Mandatory = $True)]
                [String] $DistinguishedName,
                [Parameter(Mandatory = $True)]
                $OrganizationalUnitName,
                [Parameter(Mandatory = $True)]
                $ParentElement
            )

            Begin
            {
                $ContainerDistinguishedName = "OU=$($OrganizationalUnitName),$($DistinguishedName)"
                Write-Verbose "[$($ContainerDistinguishedName)] Start $($MyInvocation.InvocationName)"
            }

            Process
            {
                $OwnerDocument = $ParentElement.OwnerDocument
                If ($Null -eq $OwnerDocument)
                {
                    $OwnerDocument = $ParentElement
                }
            
                $Element = $OwnerDocument.CreateNode([System.Xml.XmlNodeType]::Element, 'OU', '')
                $Element.SetAttribute('Name', $OrganizationalUnitName) | Out-Null
                If ($Null -ne $ParentElement.DocumentElement)
                {
                    $ParentElement.DocumentElement.AppendChild($Element) | Out-Null
                }
                Else
                {
                    $ParentElement.AppendChild($Element) | Out-Null
                }

                $GPOs = Get-GPInheritance -Target $ContainerDistinguishedName | Select-Object -ExpandProperty GpoLinks
                ForEach ($gpo in $GPOs)
                {
                    $gpoElement = $OwnerDocument.CreateNode([System.Xml.XmlNodeType]::Element, 'GPO', '')
                    $gpoElement.SetAttribute('DisplayName', $gpo.DisplayName) | Out-Null
                    $gpoElement.SetAttribute('Order', $gpo.Order) | Out-Null
                    $Element.AppendChild($gpoElement) | Out-Null
                }

                $ChildOUs = Get-ADOrganizationalUnit -Filter * -SearchBase $ContainerDistinguishedName -SearchScope OneLevel
                ForEach ($ou in $ChildOUs)
                {
                    Get-OrganizationalUnitXml -DistinguishedName $ContainerDistinguishedName -OrganizationalUnitName $($ou.Name) -ParentElement $Element
                }
            }

            End
            {
                Write-Verbose "[$($ContainerDistinguishedName)] End $($MyInvocation.InvocationName)"
            }
        }
    }

    Process
    {
        $Script:Document = [XML]("<OrganizationalStructure ADDC='$($Script:ADDC)' ADDN='$($Script:ADDN)'></OrganizationalStructure>")

        ForEach ($container in @('System', 'Configuration', 'Users', 'Computers', 'Builtin'))
        {
            Get-ContainerXml -ContainerName $container -DistinguishedName $Script:ADDC -ParentElement $Script:Document
        }

        $TopLevelOUs = Get-ADOrganizationalUnit -Filter * -SearchBase $Script:ADDN -SearchScope OneLevel
        ForEach ($topLevelOU in $TopLevelOUs)
        {
            Get-OrganizationalUnitXml -OrganizationalUnitName $($topLevelOU.Name) -DistinguishedName $Script:ADDN -ParentElement $Script:Document
        }

        $Script:Document.Save($OutputPath) | Out-Null
        Write-Output "Report saved to $($OutputPath)"
    }
}