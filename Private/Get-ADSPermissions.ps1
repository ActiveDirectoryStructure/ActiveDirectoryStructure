Function Get-ADSPermissions
{
    Param
    (
        [Parameter(Mandatory = $True)]
        [String] $GroupName
    )

    Begin
    {
        Write-Verbose "[$($GroupName)] Start $($MyInvocation.InvocationName)"

        If ($Null -eq $Script:Permissions)
        {
            [XML]$Script:Permissions = Get-Content -Path (Join-Path -Path $Script:XmlRootPath -ChildPath 'Permissions.xml')
        }
    }

    Process
    {
        $permission = $Script:Permissions.Permissions.Permission | Where-Object { $_.Name -eq $GroupName }
        If ($Null -eq $permission)
        {
            Write-Error "Failed to find ACL Group '$($GroupName)'"
        }
        
        Return $permission
    }

    End
    {
        Write-Verbose "[$($GroupName)] End $($MyInvocation.InvocationName)"
    }
}