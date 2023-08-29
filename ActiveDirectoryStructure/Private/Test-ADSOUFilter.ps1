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
            Write-Verbose "[$($DistinguishedName)] Filter success -> No filter"
            Return $True
        }
        If ($True -eq $Variables.$($OUStructure.Filter))
        {
            Write-Verbose "[$($DistinguishedName)] Filter success -> $($Variables.$($OUStructure.Filter))"
            Return $True
        }
        Write-Verbose "[$($DistinguishedName)] Variables: $($Variables.OuterXml)"
        Write-Verbose "[$($DistinguishedName)] Filter denied -> $($Variables.$($OUStructure.Filter))"
        Return $False
    }

    End
    {
        Write-Verbose "[$($DistinguishedName)] End $($MyInvocation.InvocationName)"
    }
}