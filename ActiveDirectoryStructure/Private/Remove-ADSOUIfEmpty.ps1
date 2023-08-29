Function Remove-ADSOUIfEmpty
{
    [CmdletBinding(SupportsShouldProcess = $True)]
    Param
    (
        [Parameter(Mandatory = $True)]
        [String] $OUDistinguishedName
    )

    Begin
    {
        Write-Verbose "[$($OUDistinguishedName)] Start $($MyInvocation.InvocationName)"
        [Bool]$YesToAllOU = $False
        [Bool]$NoToAllOU = $False
    }

    Process
    {
        Write-Verbose "[$($OUDistinguishedName)] Checking if OU should be deleted"
        # OU exists but should not
        $objects = Get-ADObject -Filter * -SearchBase $OUDistinguishedName

        # the ou itself is also found as an objects too so -1 the total object count
        $count = 0
        If (-not [String]::IsNullOrEmpty($objects.Count))
        {
            $count = $objects.Count - 1
        }

        Write-Host "$OUDistinguishedName exists with $($count) subobjects. " -NoNewline -ForegroundColor 'Red'
        If ($count -eq 0)
        {
            If (-not $SkipOUDelete.IsPresent)
            {
                Write-Host 'Deleting will continue as OU is empty !' -ForegroundColor Red
                If ($PSCmdlet.ShouldProcess($OUDistinguishedName, 'Remove-ADOrganizationalUnit'))
                {
                    If ($Force -or $PSCmdlet.ShouldContinue("Delete OU '$($OUDistinguishedName)'", "Are you sure you want to delete the OU '$($OUDistinguishedName)'", $True, [Ref]$YesToAllOU, [Ref]$NoToAllOU))
                    {
                        Set-ADOrganizationalUnit -Identity $OUDistinguishedName -ProtectedFromAccidentalDeletion $False
                        Remove-ADOrganizationalUnit -Identity $OUDistinguishedName -Confirm:$False | Out-Null
                    }
                }
            }
            Else
            {
                Write-Host 'Deleting will NOT continue -SkipOUDelete is set !' -ForegroundColor Green
            }
        }
        Else
        {
            Write-Host ''
        }
    }

    End
    {
        Write-Verbose "[$($OUDistinguishedName)] End $($MyInvocation.InvocationName)"
    }
}