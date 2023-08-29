Function Get-ADSGPOsFromGPOGroup
{
    Param
    (
        [Parameter(Mandatory = $True)]
        [String] $GroupName
    )

    Begin
    {
        Write-Verbose "[$($GroupName)] Start $($MyInvocation.InvocationName)"

        If ($Null -eq $Script:GPOGroups)
        {
            [XML]$Script:GPOGroups = Get-Content -Path (Join-Path -Path $Script:XmlRootPath -ChildPath 'GPOGroups.xml')
        }
    }

    Process
    {
        $gpos = $GPOGroups.GPOGroups.GPOGroup | Where-Object { $_.GroupName -eq $GroupName }
        If ($Null -eq $gpos)
        {
            Write-Error "Failed to find GPOGroup '$($GroupName)'"
        }

        Return $gpos
    }

    End
    {
        Write-Verbose "[$($GroupName)] End $($MyInvocation.InvocationName)"
    }
}