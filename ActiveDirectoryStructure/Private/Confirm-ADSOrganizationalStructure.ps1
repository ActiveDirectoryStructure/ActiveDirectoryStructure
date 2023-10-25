Function Confirm-ADSOrganizationalStructure
{
    [CmdLetBinding(SupportsShouldProcess = $True)]
    Param
    (
        [Parameter(Mandatory = $True)]
        [String] $DistinguishedName,
        [Parameter(Mandatory = $True)]
        [String] $ADServer,
        [Parameter(Mandatory = $True)]
        $OUStructure,
        [Parameter(Mandatory = $True)]
        $Variables,

        [Parameter(Mandatory = $False)]
        [Ref] $CorrectOUs,

        [Switch] $CreateOnly,
        [Switch] $SkipOUDelete,
        [Switch] $DeleteOnly,
        [Switch] $ACLOnly,
        [Switch] $NoACL,
        
        [Switch] $TopLevel
    )

    Begin
    {
        Write-Verbose "[$($DistinguishedName)] Start $($MyInvocation.InvocationName)"

        If ($TopLevel.IsPresent)
        {
            Write-Verbose "[$($DistinguishedName)] CreateOnly: $($CreateOnly.IsPresent)"
            Write-Verbose "[$($DistinguishedName)] SkipOUDelete: $($SkipOUDelete.IsPresent)"
            Write-Verbose "[$($DistinguishedName)] DeleteOnly: $($DeleteOnly.IsPresent)"
            Write-Verbose "[$($DistinguishedName)] ACLOnly: $($ACLOnly.IsPresent)"
            Write-Verbose "[$($DistinguishedName)] NoACL: $($NoACL.IsPresent)"
        }

        $AllOUs = $Null
        $OUTemplate = $Null

        If (-not [String]::IsNullOrEmpty($OUStructure.OrganizationalTemplate))
        {
            $OUTemplate = (Get-ADSOrganizationalTemplate -TemplateName $($OUStructure.OrganizationalTemplate)).OrganizationalStructure.OU
        }
    }

    Process
    {
        $ouName = $($OUStructure.Name)
        $ouDescription = $($OUStructure.Description)

        # When OU name is ForEach then replace it with the variable value
        If ($ouName -eq 'ForEach')
        {
            $ouName = $Variables.Value
            If (-not [String]::IsNullOrEmpty($Variables.Description))
            {
                $ouDescription = $($Variables.Description)
            }
        }
        $ouDistinguishedName = "OU=$($ouName),$($DistinguishedName)"

        If ($Null -eq $CorrectOUs)
        {
            Write-Verbose "[$($DistinguishedName)] Fetching '$($ouDistinguishedName)' ..."
            $ProcessedCorrectOUs = New-Object -TypeName 'System.Collections.Generic.List[System.String]'
            $ProcessedCorrectOUs.Add($ouDistinguishedName)
            $CorrectOUs = ([Ref]$ProcessedCorrectOUs)
        }

        # When name is OU then it has no name
        If (-not [String]::IsNullOrEmpty($OUStructure.Name) -and $($OUStructure.Name) -ne 'OU')
        {
            Write-Verbose "[$($DistinguishedName)] Processing OU ..."

            If (-not [String]::IsNullOrEmpty(($($OUStructure.Filter))))
            {
                If ($Null -ne $Variables)
                {
                    Write-Verbose "[$($DistinguishedName)] Filter: '$($OUStructure.Filter)'"
                    Write-Verbose "[$($DistinguishedName)] FilterSet: '$($Variables.$($OUStructure.Filter))'"
                }
            }

            $ou = Get-ADOrganizationalUnit -Filter "distinguishedName -eq '$ouDistinguishedName'" -Properties Description -Server $ADServer
            If (-not $DeleteOnly.IsPresent -and -not $ACLOnly.IsPresent -and $Null -eq $ou)
            {
                If (([String]::IsNullOrEmpty($OUStructure.Filter) -or $Variables.$($OUStructure.Filter) -eq $True) -and [String]::IsNullOrEmpty($OUStructure.Optional))
                {
                    If ($PSCmdlet.ShouldProcess("-Name $ouName -Path $DistinguishedName -PassThru", 'New-ADOrganizationalUnit'))
                    {
                        Write-Host "[$($DistinguishedName)] $($ouName) is missing. Creating ..." -ForegroundColor Green
                        If (-not [String]::IsNullOrEmpty($ouDescription))
                        {
                            $ou = New-ADOrganizationalUnit -Name $ouName -Path $DistinguishedName -Description $($ouDescription) -PassThru -Server $ADServer
                        }
                        Else
                        {
                            $ou = New-ADOrganizationalUnit -Name $ouName -Path $DistinguishedName -PassThru -Server $ADServer
                        }
                        $CorrectOUs.Value.Add($ouDistinguishedName)
                    }
                }
                ElseIf ($True -eq $OUStructure.Optional)
                {
                    # OU is marked as optional. Do not force created it but add it as a valid OU
                    Write-Verbose "[$($DistinguishedName)] $($ouDistinguishedName) not exist and is optional. Not creating"
                    $CorrectOUs.Value.Add($ouDistinguishedName)
                }
            }
            ElseIf (-not $CreateOnly.IsPresent -and -not $ACLOnly.IsPresent)
            {
                If (Test-ADSOUFilter -DistinguishedName $DistinguishedName -OUStructure $OUStructure -Variables $Variables)
                {
                    If (-not [String]::IsNullOrEmpty($ouDescription) -and $ou.Description -ne $($ouDescription))
                    {
                        Write-Verbose "[$($DistinguishedName)] $($ouDistinguishedName) description is '$($ouDescription)' instead of '$($ou.Description)'"
                        If ($PSCmdlet.ShouldProcess("-Identity $ou -Description $($ouDescription)", 'Set-ADOrganizationalUnit'))
                        {
                            Set-ADOrganizationalUnit -Identity $ou -Description $($ouDescription) -Server $ADServer | Out-Null
                        }
                    }
                    # OU exists and should exist
                    Write-Verbose "[$($DistinguishedName)] $($ouDistinguishedName) should exist"
                    $CorrectOUs.Value.Add($ouDistinguishedName)
                }
            }

            If ($Null -eq $AllOUs -and $Null -ne $ou)
            {
                $AllOUs = Get-ADOrganizationalUnit -Filter * -SearchBase $ouDistinguishedName -Server $ADServer | Select-Object -ExpandProperty distinguishedName
            }

            If ($Null -ne $ou)
            {
                If (-not $ACLOnly.IsPresent)
                {
                    Confirm-ADSOrganizationalStructureGPO -DistinguishedName $ouDistinguishedName -Variables $Variables -OUStructure $OUStructure -WhatIf:$WhatIfPreference -ADServer $ADServer
                }

                If (-not $NoACL.IsPresent -and -not $CreateOnly.IsPresent)
                {
                    Confirm-ADSOrganizationalStructureACL -DistinguishedName $ouDistinguishedName -Variables $Variables -Structure $OUStructure -WhatIf:$WhatIfPreference -ADServer $ADServer
                }
            }

            # Process Groups
            If (-not $CreateOnly.IsPresent -and $Null -ne $OUStructure.Group)
            {
                ForEach ($group in $OUStructure.Group)
                {
                    $groupDistinguishedName = Get-GroupDistinguishedName -Group $group
                    Confirm-ADSOrganizationalStructureACL -DistinguishedName $groupDistinguishedName -Variables $Variables -Structure $group -WhatIf:$WhatIfPreference -ADServer $ADServer
                }
            }

            # Process Sub OUs
            If ($Null -ne $OUStructure.OU)
            {
                ForEach ($ou in $OUStructure.OU)
                {
                    $Parameters = @{
                        ADServer          = $ADServer
                        DistinguishedName = $ouDistinguishedName
                        OUStructure       = $ou
                        Variables         = $Variables
                        CorrectOUs        = $CorrectOUs
                        CreateOnly        = $CreateOnly
                        SkipOUDelete      = $SkipOUDelete
                        DeleteOnly        = $DeleteOnly
                        ACLOnly           = $ACLOnly
                        NoACL             = $NoACL
                        WhatIf            = $WhatIfPreference
                    }
                    
                    If ($OUStructure.IgnoreSubOUs)
                    {
                        $ou.IgnoreSubOUs = $True
                    }
                        
                    Confirm-ADSOrganizationalStructure @Parameters
                }
            }

            Write-Verbose "[$($DistinguishedName)] Finished OU"
        }

        # Process dynamic foreachs
        If ($Null -ne $OUStructure.ForEach)
        {
            Write-Verbose "[$($DistinguishedName)] Processing ForEach ..."
            
            ForEach ($innerLoop in $OUStructure.ForEach)
            {
                Write-Verbose "[$($DistinguishedName)] ForEach -> $($innerLoop.Variable)"
                $content = $Variables.Variable | Where-Object { $_.Name -eq $($innerLoop.Variable) } | Select-Object -ExpandProperty Variable
                If ($Null -ne $content)
                {
                    ForEach ($variable in $content)
                    {
                        Write-Verbose "[$($DistinguishedName)] Processing Variable $($variable.Value)"
                        $Parameters = @{
                            ADServer          = $ADServer
                            DistinguishedName = $ouDistinguishedName
                            OUStructure       = $innerLoop
                            Variables         = $variable
                            CorrectOUs        = $CorrectOUs
                            CreateOnly        = $CreateOnly
                            SkipOUDelete      = $SkipOUDelete
                            DeleteOnly        = $DeleteOnly
                            ACLOnly           = $ACLOnly
                            NoACL             = $NoACL
                            WhatIf            = $WhatIfPreference
                        }

                        If ($OUStructure.IgnoreSubOUs)
                        {
                            $ou.IgnoreSubOUs = $True
                        }
        
                        Confirm-ADSOrganizationalStructure @Parameters
                    }
                }
                Else
                {
                    Write-Warning "[$($DistinguishedName)] Variable $($innerLoop.Variable) not found!"
                }
            }

            Write-Verbose "[$($DistinguishedName)] Finished ForEach"
        }

        If ($Null -ne $OUTemplate)
        {
            Write-Verbose "[$($DistinguishedName)] Processing OUTemplate ..."
            
            ForEach ($ou in $OUTemplate)
            {
                $Parameters = @{
                    ADServer          = $ADServer
                    DistinguishedName = $DistinguishedName
                    OUStructure       = $ou
                    Variables         = $Variables
                    CorrectOUs        = $CorrectOUs
                    CreateOnly        = $CreateOnly
                    SkipOUDelete      = $SkipOUDelete
                    DeleteOnly        = $DeleteOnly
                    ACLOnly           = $ACLOnly
                    NoACL             = $NoACL
                    WhatIf            = $WhatIfPreference
                }

                If ($OUStructure.IgnoreSubOUs)
                {
                    $ou.IgnoreSubOUs = $True
                }

                Confirm-ADSOrganizationalStructure @Parameters
            }

            Write-Verbose "[$($DistinguishedName)] Finished OUTemplate"
        }

        If ($Null -ne $AllOUs -and -not $CreateOnly.IsPresent -and -not $ACLOnly.IsPresent)
        {
            Write-Verbose "[$($DistinguishedName)] Found $($AllOUs.Count) sub-OUs and validated $($ProcessedCorrectOUs.Count)"
            $difference = Compare-Object -ReferenceObject $ProcessedCorrectOUs -DifferenceObject $AllOUs
            $additionalOUs = $difference | Where-Object { $_.SideIndicator -eq '=>' } | Select-Object -ExpandProperty InputObject
                
            If ($Null -ne $additionalOUs -and $additionalOUs.Count -gt 0)
            {
                ForEach ($ou in $additionalOUs)
                {
                    If ($OUStructure.IgnoreSubOUs)
                    {
                        Write-Host "[$($DistinguishedName)] Ignoring OU '$($ou)' since IgnoreSubOUs is set" -ForegroundColor Yellow
                        $CorrectOUs.Value.Remove($ou) | Out-Null
                        Continue
                    }

                    Remove-ADSOUIfEmpty -OUDistinguishedName $ou -WhatIf:$WhatIfPreference
                }
            }
        }
    }

    End
    {
        Write-Verbose "[$($DistinguishedName)] End $($MyInvocation.InvocationName)"
    }
}