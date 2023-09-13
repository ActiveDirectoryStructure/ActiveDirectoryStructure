Function Confirm-ADSOrganizationalStructureACL
{
    [CmdLetBinding(SupportsShouldProcess = $True)]
    Param
    (
        [Parameter(Mandatory = $True)]
        [String] $DistinguishedName,
        [Parameter(Mandatory = $True)]
        [String] $ADServer,
        [Parameter(Mandatory = $True)]
        $Structure,
        [Parameter(Mandatory = $False)]
        $Variables
    )

    Begin
    {
        Write-Verbose "[$($DistinguishedName)] Start $($MyInvocation.InvocationName)"

        $ErrorActionPreference = 'Stop'
    }

    Process
    {
        If (-not $Structure.Permission)
        {
            Return
        }

        $ADPath = "AD:\$($DistinguishedName)"
        $CurrentACLs = Get-Acl -Path $ADPath | Select-Object -ExpandProperty Access
        $NewACLs = Get-Acl -Path $ADPath 
        $SetAcl = $False

        ForEach ($permission in $Structure.Permission)
        {
            $identityDistinguishedName = Get-ADSIdentityDistinguishedName -DistinguishedName $DistinguishedName -Permission $permission -Variables $Variables

            [System.Security.Principal.SecurityIdentifier]$identity = $Null
            Try
            {
                If ($($permission.Identity) -like 'S-1-5-*')
                {
                    $identity = New-Object -TypeName System.Security.Principal.SecurityIdentifier -ArgumentList $($permission.Identity)
                }
                Else
                {
                    $sid = (Get-ADObject -Identity $($identityDistinguishedName) -Properties objectSID).objectSID
                    $identity = New-Object -TypeName System.Security.Principal.SecurityIdentifier -ArgumentList $sid
                }
            }

            Catch
            {
                If ([String]::IsNullOrEmpty($permission.Optional) -or -not [Bool]$permission.Optional)
                {
                    Write-Error "[$($DistinguishedName)]->$($permission.Identity): Failed to find identity with DN '$($identityDistinguishedName)' and not marked as optional"
                }
                
                # If the permission is optional then skip setting it if the group does not exist
                Continue
            }

            Write-Verbose "[$($DistinguishedName)]->$($permission.Identity) identified as '$($identity.Value)' with resolved name of '$($identityDistinguishedName)'"

            $permissions = Get-ADSPermissions -GroupName $($permission.Permission)
            Write-Verbose "[$($DistinguishedName)]->$($permission.Identity): processing $($newPermission.AccessRules.AccessRule.Length) permissions"

            ForEach ($newPermission in $permissions.AccessRules.AccessRule)
            {
                Write-Verbose "[$($DistinguishedName)]->$($permission.Identity)->$($newPermission.Description): Processing"

                $existingAcl = $CurrentACLs | Where-Object { 
                    $_.IdentityReference.Translate([System.Security.Principal.SecurityIdentifier]).Value -eq $($identity.Value) -and
                    $_.ActiveDirectoryRights -eq $($newPermission.ActiveDirectoryRights) -and
                    $_.InheritanceType -eq $($newPermission.InheritanceType) -and
                    $_.ObjectType -eq $($newPermission.ObjectType) -and
                    $_.InheritedObjectType -eq $($newPermission.InheritedObjectType) -and
                    $_.AccessControlType -eq 'Allow'
                }

                If ($Null -eq $existingAcl)
                {
                    Write-Host "[$($DistinguishedName)]->$($permission.Identity)->$($newPermission.Description): permission not found. Creating" -ForegroundColor Green

                    Write-Verbose "[$($DistinguishedName)]->$($permission.Identity)->$($newPermission.Description)->ActiveDirectoryRights: $($newPermission.ActiveDirectoryRights)"
                    Write-Verbose "[$($DistinguishedName)]->$($permission.Identity)->$($newPermission.Description)->ObjectType: $($newPermission.ObjectType)"
                    Write-Verbose "[$($DistinguishedName)]->$($permission.Identity)->$($newPermission.Description)->InheritanceType: $($newPermission.InheritanceType)"
                    Write-Verbose "[$($DistinguishedName)]->$($permission.Identity)->$($newPermission.Description)->InheritedObjectType: $($newPermission.InheritedObjectType)"

                    $parameters = @(
                        $identity
                        $($newPermission.ActiveDirectoryRights)
                        'Allow' # $($newPermission.InheritanceType)
                        ([GUID]$($newPermission.ObjectType)).Guid
                        $($newPermission.InheritanceType)
                        ([GUID]$($newPermission.InheritedObjectType)).Guid
                    )

                    $accessRule = New-Object -TypeName System.DirectoryServices.ActiveDirectoryAccessRule -ArgumentList $Parameters
                    $NewACLs.AddAccessRule($accessRule) | Out-Null
                    $SetAcl = $True
                }

                Write-Verbose "[$($DistinguishedName)]->$($permission.Identity)->$($newPermission.Description): Finished processing"
            }

            If ($SetAcl)
            {
                If ($PSCmdlet.ShouldProcess("-Path $ADPath -AclObject $NewACLs", 'Set-Acl'))
                {
                    Write-Verbose "[$($DistinguishedName)]->$($permission.Identity) Updating ACL for object"
                    Set-Acl -Path $ADPath -AclObject $NewACLs | Out-Null
                }
            }
        }
    }

    End
    {
        Write-Verbose "[$($DistinguishedName)] End $($MyInvocation.InvocationName)"
    }
}
