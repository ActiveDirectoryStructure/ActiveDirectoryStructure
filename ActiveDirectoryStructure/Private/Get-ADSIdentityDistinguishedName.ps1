Function Get-ADSIdentityDistinguishedName
{
    Param
    (
        [Parameter(Mandatory = $True)]
        [String] $DistinguishedName,
        [Parameter(Mandatory = $True)]
        $Permission,
        [Parameter(Mandatory = $False)]
        $Variables
    )

    Begin
    {
        Write-Verbose "[$($DistinguishedName)] Start $($MyInvocation.InvocationName)"
    }

    Process
    {
        $IdentityDistinguishedName = $($permission.Identity)
        If ($IdentityDistinguishedName.Contains('DC='))
        {
            Write-Error "[$($DistinguishedName)] Identity reference cannot contain DC of domain (e.g. DC=Contoso,DC=ch). Found: '$($IdentityDistinguishedName)'"
        }
        $IdentityDistinguishedName = "$($IdentityDistinguishedName),$($Script:ADDN)"
        Write-Verbose "[$($DistinguishedName)] Generated '$($IdentityDistinguishedName)'"

        If ($($permission.Identity) -notlike 'S-1-5-*')
        {
            $matchedVariables = ([Regex]'@([^@]*)@').Matches($IdentityDistinguishedName)
            If ($matchedVariables.Count -gt 0)
            {
                ForEach ($match in $matchedVariables)
                {
                    $value = $match.Value
                    # Special variable indicating that we just want to insert the current variable value
                    If ($value -eq '@@')
                    {
                        Write-Verbose "[$($DistinguishedName)]->$($permission.Identity): Replacing '@@' with $($Variables.Value)"
                        $IdentityDistinguishedName = $IdentityDistinguishedName.Replace('@@', $Variables.Value)
                    }
                    Else
                    {
                        $variableValue = $Variables.Variable | Where-Object { $_.Name -eq $value }
                        If ($Null -eq $variableValue)
                        {
                            Write-Warning "[$($DistinguishedName)]->$($permission.Identity): Searched for variable with name '$($value)' but found nothing"
                            Continue
                        }

                        Write-Verbose "[$($DistinguishedName)]->$($permission.Identity): Replacing '$($value)' with $($variableValue.Value)"
                        $IdentityDistinguishedName = $IdentityDistinguishedName.Replace($value, $variableValue.Value)
                    }
                }
            }

            Return $IdentityDistinguishedName
        }
        
        Return $($permission.Identity)
    }

    End
    {
        Write-Verbose "[$($DistinguishedName)] End $($MyInvocation.InvocationName)"
    }
}