Function Get-ADSGroupDistinguishedName
{
    Param
    (
        [Parameter(Mandatory = $True)]
        [ValidateNotNull()]
        [System.Xml.XmlElement] $Group
    )

    Begin
    {
        $ErrorActionPreference = 'Stop'

        Write-Verbose "[$($Group.Name)/$($Group.SID)] Start $($MyInvocation.InvocationName)"

        $GroupDistinguishedName = "$($Group.Name),$($Script:ADDN)"
    }

    Process
    {
        # If the name attribute is not set, then XML sets it per default to the Attribute name, which is Group in that case (<Group>)
        If (([String]::IsNullOrEmpty($($Group.Name)) -or $($Group.Name) -eq 'Group') -and -not [String]::IsNullOrEmpty($Group.SID))
        {
            # If the SID is only 3 long, we assume that this is a Well-Known SID, therefore we translate it to a Domain SID
            If ($group.SID.Length -eq 3)
            {
                $group.SID = "$((Get-ADDomain).DomainSID)-$($group.SID)"
            }
            $identity = Get-ADGroup -Identity $($group.SID)
            $GroupDistinguishedName = $identity.distinguishedName
        }
        Else
        {
            Write-Error "[$($DistinguishedName)] Invalid Group ($($Group.Name) / $($Group.SID))"
        }
    }
    End
    {
        Write-Verbose "[$($Group.Name)/$($Group.SID)] End $($MyInvocation.InvocationName)"
        Return $GroupDistinguishedName
    }
}