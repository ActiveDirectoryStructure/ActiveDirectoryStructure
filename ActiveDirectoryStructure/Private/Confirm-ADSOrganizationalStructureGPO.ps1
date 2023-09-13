Function Confirm-ADSOrganizationalStructureGPO
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
        $Variables
    )

    Begin
    {
        Write-Verbose "[$($DistinguishedName)] Start $($MyInvocation.InvocationName)"

        [Bool]$YesToAllGPLink = $False
        [Bool]$NoToAllGPLink = $False
    }

    Process
    {
        Write-Verbose "[$($DistinguishedName)] Processing GPOs"

        # Clone node so to not overwrite settings in the template node
        $OUStructure = $OUStructure.CloneNode($True)
        If ($Null -ne $OUStructure.GPOGroup)
        {
            Write-Verbose "[$($DistinguishedName)] Processing GPO groups"
            ForEach ($group in $OUStructure.GPOGroup)
            {
                Write-Verbose "[$($DistinguishedName)] Importing $($group.GroupName)"

                $groupGPOs = Get-ADSGPOsFromGPOGroup -GroupName $($group.GroupName)
                $node = $OUStructure.OwnerDocument.ImportNode($groupGPOs, $True)
                ForEach ($childNode in $node.GPO)
                {
                    # Write-Verbose "Importing $($childNode.OuterXml)"
                    $OUStructure.AppendChild($childNode) | Out-Null
                }
                # Write-Verbose "$($OUStructure.OuterXml)"
            }
        }

        # BlockInheritance
        $Inheritance = Get-GPInheritance -Target $DistinguishedName -Server $ADServer
        $RequstedInheritanceStatus = $False
        If (-not [String]::IsNullOrEmpty($OUStructure.BlockInheritance))
        {
            $RequstedInheritanceStatus = [Bool]$OUStructure.BlockInheritance
        }

        If ($Inheritance.GpoInheritanceBlocked -ne $RequstedInheritanceStatus)
        {
            Write-Verbose "[$($DistinguishedName)] Setting inheritance to '$($RequstedInheritanceStatus)'"
            If ($RequstedInheritanceStatus)
            {
                Set-GPInheritance -Target $DistinguishedName -IsBlocked 'Yes' -Confirm:$False -Server $ADServer | Out-Null
            }
            Else
            {
                Set-GPInheritance -Target $DistinguishedName -IsBlocked 'No' -Confirm:$False -Server $ADServer | Out-Null
            }
        }

        $LinkedGPOs = $Inheritance.GpoLinks
        # Sort by Order as INTEGER otherwise ASCII order will take preference (e.g, 1,10,100 then 2,20,200 and so on)
        $OrderedGPOs = $OUStructure.GPO | Sort-Object { [Int]$_.Order }
        $Order = 1

        $ProcessedGPOs = @()
        ForEach ($gpo in $OrderedGPOs)
        {
            If (-not (Test-ADSGPOFilter -DistinguishedName $DistinguishedName -XML $gpo -OUStructure $OUStructure))
            {
                Continue
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

            Write-Verbose "[$($DistinguishedName)]->[$($name)] Calculated order is $($gpo.Order) "

            $linkedGPO = $LinkedGPOs | Where-Object { $_.DisplayName -eq $name }
            # GPO is not linked but should be
            If (-not $DeleteOnly.IsPresent -and $Null -eq $linkedGPO)
            {
                If ($Null -eq ($AllGPOs | Where-Object { $_.DisplayName -eq $name }))
                {
                    $Order--
                    Write-Host "[$($DistinguishedName)] Expected GPO '$($name)' in '$($DistinguishedName)' but did not find any matching GPO" -ForegroundColor Yellow
                    Continue
                }

                Write-Host "[$($DistinguishedName)] Linking '$($name)' to '$($DistinguishedName)'" -ForegroundColor Green
                If ($PSCmdlet.ShouldProcess("-Name '$($name)' -Target '$($DistinguishedName)' -Order $($gpo.Order)", 'New-GPLink'))
                {
                    New-GPLink -Name $($name) -Target $($DistinguishedName) -Order $($gpo.Order) -Server $ADServer | Out-Null
                }
            }
            # GPO is already linked but order is wrong
            ElseIf (-not $DeleteOnly.IsPresent -and ($linkedGPO.Order -ne $gpo.Order -or $ForceSetOUOrder.IsPresent)) 
            {
                Write-Host "[$($DistinguishedName)] " -NoNewline -ForegroundColor Green
                If ($ForceSetOUOrder.IsPresent -and $linkedGPO.Order -eq $gpo.Order)
                {
                    Write-Host 'FORCE ' -ForegroundColor Yellow -NoNewline
                }

                Write-Host "Setting order of '$($name)' in '$($DistinguishedName)' to $($gpo.Order)" -ForegroundColor Green

                If ($PSCmdlet.ShouldProcess("-Name '$($name)' -Target '$($DistinguishedName)' -Order $($gpo.Order)", 'Set-GPLink'))
                {
                    Set-GPLink -Name $($name) -Target $($DistinguishedName) -Order $($gpo.Order) -Server $ADServer | Out-Null
                }
            }

            $ProcessedGPOs += $name
        }

        If (-not $CreateOnly.IsPresent)
        {
            $additionalGPOs = $LinkedGPOs | Where-Object { $_.DisplayName -notin $ProcessedGPOs }
            ForEach ($gpo in $additionalGPOs)
            {
                If ($gpo.DisplayName -like 'TEMP_*')
                {
                    Write-Host "[$($DistinguishedName)] NOT deleting Link '$($gpo.DisplayName)' from '$($DistinguishedName)' as it's marked as temporary GPO" -ForegroundColor Yellow
                    Continue
                }

                Write-Host "[$($DistinguishedName)] Deleting Link '$($gpo.DisplayName)' from '$($DistinguishedName)'" -ForegroundColor Red
                If ($PSCmdlet.ShouldProcess("-Name '$($gpo.DisplayName)' -Target '$($DistinguishedName)'", 'Remove-GPLink'))
                {
                    If ($Force -or $PSCmdlet.ShouldContinue("Delete link of GPO '$($gpo.DisplayName)' from '$($DistinguishedName)'", "Are you sure you want to delete link of GPO '$($gpo.DisplayName)' from '$($DistinguishedName)'?", $False, [Ref]$YesToAllGPLink, [Ref]$NoToAllGPLink))
                    {
                        Remove-GPLink -Name $($gpo.DisplayName) -Target $($DistinguishedName) -Server $ADServer | Out-Null
                    }
                }
            }
        }
    }

    End
    {
        Write-Verbose "[$($DistinguishedName)] End $($MyInvocation.InvocationName)"
    }
}