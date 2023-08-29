Function Test-ADSOUFilter
{
    Param
    (
        [Parameter(Mandatory = $True)]
        [String] $DistinguishedName,
        [Parameter(Mandatory = $True)]
        $OUStructure,
        [Parameter(Mandatory = $True)]
        $Variables
    )

    Begin
    {
        Write-Verbose "[$($DistinguishedName)] Start $($MyInvocation.InvocationName)"
    }

    Process
    {
        Write-Verbose "[$($DistinguishedName)] Applying filter '$($OUStructure.Filter)'"
        If ([String]::IsNullOrEmpty($OUStructure.Filter))
        {
            Return $True
        }
        If ($True -eq $Variables.$($OUStructure.Filter))
        {
            Return $True
        }
        Return $False
    }

    End
    {
        Write-Verbose "[$($DistinguishedName)] End $($MyInvocation.InvocationName)"
    }
}