Function New-GeneratedReport
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

        $Script:Document = [XML](Get-Content -Path (Join-Path -Path $Script:XmlRootPath -ChildPath 'Structure.xml'))
        $Structure = ($Document).OrganizationalStructure
        $Variables = ([XML](Get-Content -Path (Join-Path -Path $Script:XmlRootPath -ChildPath 'Variables.xml'))).Variables

        $Script:ADDC = $Structure.ADDC
        $Script:ADDN = $Structure.ADDN

        $Script:GPOGroups = $Null
        $Script:Permissions = $Null

        Function Get-ContainerXml
        {
            Param
            (
                [Parameter(Mandatory = $True)]
                [String] $DistinguishedName,
                [Parameter(Mandatory = $True)]
                $ContainerStructure,
                [Parameter(Mandatory = $False)]
                [Switch] $Template
            )

            Begin
            {
                $ContainerName = $ContainerStructure.Name
                $ContainerDistinguishedName = "CN=$($ContainerName),$($DistinguishedName)"
                Write-Verbose "[$($ContainerDistinguishedName)] Start $($MyInvocation.InvocationName)"
            }

            Process
            {
                If ($Template.IsPresent)
                {
                    Write-Verbose "[$($ContainerDistinguishedName)] Skipping Processing in template mode"
                    Return
                }

                If ($Null -ne $ContainerStructure.Permission)
                {
                    ForEach ($permission in $ContainerStructure.Permission)
                    {
                        $identityDistinguishedName = Get-ADSIdentityDistinguishedName -DistinguishedName $DistinguishedName -Permission $permission -Variables $Variables
                        $permission.Identity = $identityDistinguishedName
                        $permission.SetAttribute('AccessControlType', 'Allow')
                    }
                }

                If ($Null -ne $ContainerStructure.Group)
                {
                    ForEach ($group in $ContainerStructure.Group)
                    {
                        $groupDistinguishedName = Get-ADSGroupDistinguishedName -Group $group
                        If ($Null -ne $group.SID)
                        {
                            $group.SID = $groupDistinguishedName
                        }
                        Else
                        {
                            $group.Name = $groupDistinguishedName
                        }
                    }
                }

                If ($Null -ne $ContainerStructure.Container)
                {
                    ForEach ($subContainer in $ContainerStructure.Container)
                    {
                        Get-ContainerXml -ContainerStructure $subContainer -DistinguishedName $ContainerDistinguishedName
                    }
                }
            }

            End
            {
                Write-Verbose "[$($ContainerDistinguishedName)] End $($MyInvocation.InvocationName)"
            }
        }

        Function Get-GPOXml
        {
            Param
            (
                [Parameter(Mandatory = $True)]
                [String] $DistinguishedName,
                [Parameter(Mandatory = $True)]
                $OUStructure,
                [Parameter(Mandatory = $True)]
                $Variables,
                [Parameter(Mandatory = $False)]
                [Switch] $Template
            )

            Begin
            {
                Write-Verbose "[$($DistinguishedName)] Start $($MyInvocation.InvocationName)"
            }

            Process
            {
                If ($Null -ne $OUStructure.GPOGroup)
                {
                    Write-Verbose "[$($DistinguishedName)] Processing GPO groups"
                    ForEach ($group in $OUStructure.GPOGroup)
                    {
                        Write-Verbose "[$($DistinguishedName)] Importing Group $($group.GroupName)"

                        $groupGPOs = Get-ADSGPOsFromGPOGroup -GroupName $($group.GroupName)
                        $node = $OUStructure.OwnerDocument.ImportNode($groupGPOs, $True)
                        ForEach ($childNode in $node.GPO)
                        {
                            $OUStructure.AppendChild($childNode) | Out-Null
                            Write-Verbose "[$($DistinguishedName)] Imported GPO $($childNode.DisplayName)"
                        }

                        $OUStructure.RemoveChild($group) | Out-Null
                        Write-Verbose "[$($DistinguishedName)] Removed Group $($group.GroupName)"
                    }
                }

                If (-not $Template.IsPresent)
                {
                    $OrderedGPOs = $OUStructure.GPO | Sort-Object { [Int]$_.Order }
                    $Order = 1

                    ForEach ($gpo in $OrderedGPOs)
                    {
                        If (-not (Test-ADSGPOFilter -DistinguishedName $DistinguishedName -XML $gpo -OUStructure $OUStructure))
                        {
                            Write-Verbose "[$($DistinguishedName)] Removing $($gpo.DisplayName)$($gpo.FormattedName)"
                            $OUStructure.RemoveChild($gpo) | Out-Null
                            Continue
                        }

                        # Remove filters
                        $childNodeCount = $gpo.ChildNodes.Count
                        For ($i = $childNodeCount; $i -ne 0; $i--)
                        {
                            $gpo.RemoveChild($gpo.ChildNodes[$i - 1]) | Out-Null
                        }

                        $name = $gpo.DisplayName
                        If ([String]::IsNullOrEmpty($name))
                        {
                            If (-not [String]::IsNullOrEmpty($gpo.FormattedName))
                            {
                                If ($DistinguishedName -match 'OU=([A-Z]{3}),OU=([A-Z]{2})')
                                {
                                    $name = $gpo.FormattedName -replace '@COUNTRY@', $Matches[2]
                                }
                                Else
                                {
                                    Write-Error "[$($DistinguishedName)] Failed to format name"
                                }
                            }
                            Else
                            {
                                Write-Warning "[$($DistinguishedName)] No GPO Name set. Skipping processing"
                                Continue
                            }
                        }

                        If (-not [String]::IsNullOrEmpty($gpo.Order))
                        {
                            $gpo.Order = ($Order++).ToString()
                        }
                        Else
                        {
                            $gpo.SetAttribute('Order', $Order++) | Out-Null
                        }
        
                        $gpo.SetAttribute('DisplayName', $name) | Out-Null
                    }
                }
            }

            End
            {
                Write-Verbose "[$($DistinguishedName)] End $($MyInvocation.InvocationName)"
            }
        }

        Function Get-OrganizationalUnitXml
        {
            Param
            (
                [Parameter(Mandatory = $True)]
                [String] $DistinguishedName,
                [Parameter(Mandatory = $True)]
                $OrganizationalUnitStructure,
                [Parameter(Mandatory = $True)]
                $Variables,
                [Parameter(Mandatory = $False)]
                [Switch] $Template
            )

            Begin
            {
                $OUTemplate = $Null
                Write-Verbose "[$($DistinguishedName)] Start $($MyInvocation.InvocationName)"
            }

            Process
            {
                If (-not [String]::IsNullOrEmpty($OrganizationalUnitStructure.OrganizationalTemplate))
                {
                    If (-not $Template.IsPresent)
                    {
                        Write-Error "[$($DistinguishedName)] Found template in non templating mode ($($OrganizationalUnitStructure.OrganizationalTemplate))"
                    }

                    $OUTemplate = (Get-ADSOrganizationalTemplate -TemplateName $($OrganizationalUnitStructure.OrganizationalTemplate)).OrganizationalStructure.OU
                    ForEach ($node in $OUTemplate)
                    {
                        $node = $OrganizationalUnitStructure.OwnerDocument.ImportNode($node, $True)
                        $OrganizationalUnitStructure.ParentNode.AppendChild($node) | Out-Null
                    }
                
                    $OrganizationalUnitStructure.ParentNode.RemoveChild($OrganizationalUnitStructure) | Out-Null
                    Return
                }

                $OUName = $($OrganizationalUnitStructure.Name)
                # When OU name is ForEach then replace it with the variable value
                If ($OUName -eq 'ForEach')
                {
                    $OUName = $Variables.Value
                }
                If (-not $Template.IsPresent -and $OUName.Name -eq 'OU')
                {
                    Write-Error "[$($OUName)] Invalid XML. If no OrganizationalTemplate is specified, a Name is mandatory"
                }
                ElseIf (-not $Template.IsPresent -and $OUName.Name -eq 'ForEach')
                {
                    $OrganizationalUnitStructure.Name = $OUName
                }

                $OUDistinguishedName = "OU=$($ouName),$($DistinguishedName)"
                Write-Verbose "[$($OUDistinguishedName)] Processing"

                If (-not (Test-ADSOUFilter -DistinguishedName $DistinguishedName -OUStructure $OrganizationalUnitStructure -Variables $Variables))
                {
                    $OrganizationalUnitStructure.ParentNode.RemoveChild($OrganizationalUnitStructure) | Out-Null
                    Continue
                }

                If ($Null -ne $OrganizationalUnitStructure.ForEach)
                {
                    If (-not $Template.IsPresent)
                    {
                        Write-Error "[$($DistinguishedName)] Found ForEach in non templating mode ($($OrganizationalUnitStructure.ForEach))"
                    }

                    Write-Verbose "[$($OUDistinguishedName)] Processing ForEach ..."
            
                    ForEach ($innerLoop in $OrganizationalUnitStructure.ForEach)
                    {
                        Write-Verbose "[$($OUDistinguishedName)] ForEach -> $($innerLoop.Variable)"
                        $content = $Variables.Variable | Where-Object { $_.Name -eq $($innerLoop.Variable) } | Select-Object -ExpandProperty Variable
                        If ($Null -ne $content)
                        {
                            ForEach ($variable in $content)
                            {
                                Write-Verbose "[$($OUDistinguishedName)] Processing Variable $($variable.Value)"
                                $copy = $innerLoop.CloneNode($True)
                                Get-OrganizationalUnitXml -OrganizationalUnitStructure $copy -Variables $variable -DistinguishedName $OUDistinguishedName -Template:$($Template.IsPresent)
                                $newElement = $innerLoop.OwnerDocument.CreateNode('element', 'OU', '')
                                $newElement.SetAttribute('Name', $($variable.Value)) | Out-Null
                                ForEach ($childNode in $copy.ChildNodes)
                                {
                                    $clonedNode = $childNode.CloneNode($True)
                                    $newElement.AppendChild($clonedNode) | Out-Null
                                }
                                $innerLoop.ParentNode.AppendChild($newElement) | Out-Null
                            }
                        }
                        Else
                        {
                            Write-Warning "[$($OUDistinguishedName)] Variable $($innerLoop.Variable) not found!"
                        }
                    }

                    $OrganizationalUnitStructure.RemoveChild($OrganizationalUnitStructure.ForEach) | Out-Null

                    Write-Verbose "[$($OUDistinguishedName)] Finished ForEach"
                }
                Else
                {
                    If (-not $Template.IsPresent)
                    {
                        If ($Null -ne $OrganizationalUnitStructure.Permission)
                        {
                            ForEach ($permission in $OrganizationalUnitStructure.Permission)
                            {
                                If ($permission.Identity -like '*,DC=*')
                                {
                                    Continue
                                }
                        
                                $identityDistinguishedName = Get-ADSIdentityDistinguishedName -DistinguishedName $OUDistinguishedName -Permission $permission -Variables $Variables
                                $permission.Identity = $identityDistinguishedName
                            }
                        }

                        If ($Null -ne $OrganizationalUnitStructure.Group)
                        {
                            ForEach ($group in $OrganizationalUnitStructure.Group)
                            {
                                $groupDistinguishedName = Get-ADSGroupDistinguishedName -Group $group
                                If ($Null -ne $group.SID)
                                {
                                    $group.SID = $groupDistinguishedName
                                }
                                Else
                                {
                                    $group.Name = $groupDistinguishedName
                                }
                            }
                        }
                    }

                    If ($Null -ne $OrganizationalUnitStructure.OU)
                    {
                        ForEach ($subOU in $OrganizationalUnitStructure.OU)
                        {
                            Get-OrganizationalUnitXml -OrganizationalUnitStructure $subOU -Variables $Variables -DistinguishedName $OUDistinguishedName -Template:$($Template.IsPresent)
                        }
                    }
                }

                Get-GPOXml -OUStructure $OrganizationalUnitStructure -Variables $Variables -DistinguishedName $OUDistinguishedName -Template:$($Template.IsPresent)
            }

            End
            {
                Write-Verbose "[$($DistinguishedName)] End $($MyInvocation.InvocationName)"
            }
        }
    }

    Process
    {
        ForEach ($container in @('System', 'Configuration', 'Users', 'Computers', 'Builtin'))
        {
            $xmlContainer = $Structure.$container
            If ($Null -ne $xmlContainer)
            {
                Get-ContainerXml -ContainerStructure $xmlContainer -DistinguishedName $Script:ADDC -Template
                Get-ContainerXml -ContainerStructure $xmlContainer -DistinguishedName $Script:ADDC
            }
        }

        ForEach ($topLevelOU in $Structure.OU)
        {
            Get-OrganizationalUnitXml -OrganizationalUnitStructure $topLevelOU -Variables $Variables -DistinguishedName $Script:ADDN -Template
            Get-OrganizationalUnitXml -OrganizationalUnitStructure $topLevelOU -Variables $Variables -DistinguishedName $Script:ADDN
        }

        $Script:Document.Save($OutputPath) | Out-Null
        Write-Output "Report saved to $($OutputPath)"
    }
}
