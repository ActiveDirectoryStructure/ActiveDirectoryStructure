Function Test-ADSGPOFilter
{
    Param
    (
        [Parameter(Mandatory = $True)]
        [String] $DistinguishedName,
        [Parameter(Mandatory = $True)]
        $XML,
        [Parameter(Mandatory = $True)]
        $OUStructure
    )

    Begin
    {
        $LogTitle = "[$($DistinguishedName)]->[$($gpo.DisplayName)$($gpo.FormattedName)]"
        Write-Verbose "$($LogTitle) Start $($MyInvocation.InvocationName)"

        $HasCountryExcludes = -not [String]::IsNullOrEmpty($XML.CountryExclude)
        $HasCountryFilter = -not [String]::IsNullOrEmpty($XML.CountryFilter)
        $HasLocationExcludes = -not [String]::IsNullOrEmpty($XML.LocationExclude)
        $HasLocationFilter = -not [String]::IsNullOrEmpty($XML.LocationFilter)
    }

    Process
    {
        $CountryOnly = $False
        If ($DistinguishedName -notmatch 'OU=([A-Z]{3}),OU=([A-Z]{2})')
        {
            If ($HasCountryExcludes -or $HasCountryFilter -or $HasLocationExcludes -or $HasLocationFilter)
            {
                If ($DistinguishedName -notmatch 'OU=([A-Z]{2}),' -and $HasLocationExcludes -and $HasLocationFilter)
                {
                    Write-Error "$($LogTitle) Failed to extract required information ($HasCountryExcludes, $HasCountryFilter, $HasLocationExcludes, $HasLocationFilter) from '$($DistinguishedName)'"
                }
                $CountryOnly = $True
            }
            Else
            {
                Write-Verbose "$($LogTitle) no filtering required"
                Return $True
            }
        }

        $Location = $Matches[1]
        $Country = $Matches[2]

        If ($CountryOnly)
        {
            $Country = $Matches[1]
        }

        Write-Verbose "$($LogTitle) applying filters CE:$($HasCountryExcludes),CF:$($HasCountryFilter),LE:$($HasLocationExcludes),LF:$($HasLocationFilter)"
            
        If ($HasCountryExcludes)
        {
            If ($Country -in $XML.CountryExclude)
            {
                Write-Verbose "$($LogTitle)->EXCLUDE: $($Country) in $($XML.CountryExclude)"
                Return $False
            }
        }
        If ($HasCountryFilter)
        {
            If ($Country -notin $XML.CountryFilter)
            {
                Write-Verbose "$($LogTitle)->FILTER: $($Country) not in $($XML.CountryFilter)"
                If (-not $HasLocationFilter)
                {
                    Return $False
                }
            }
            Else
            {
                # County is in selected Filter. No need to process Location Filters
                Write-Verbose "$($LogTitle) will be applied to '$($DistinguishedName)'"
                Return $True
            }
        }

        If (-not $CountryOnly)
        {
            If ($HasLocationExcludes)
            {
                If ($Location -in $XML.LocationExclude)
                {
                    Write-Verbose "$($LogTitle)->EXCLUDE: $($Location) in $($XML.CountLocationExcluderyFilter)"
                    Return $False
                }
            }
            If ($HasLocationFilter)
            {
                If ($Location -notin $XML.LocationFilter)
                {
                    Write-Verbose "$($LogTitle)->FILTER: $($Location) not in $($XML.LocationFilter)"
                    Return $False
                }
            }
        }

        Write-Verbose "$($LogTitle) will be applied to '$($DistinguishedName)'"
        Return $True
    }

    End
    {
        Write-Verbose "$($LogTitle) End $($MyInvocation.InvocationName)"
    }
}