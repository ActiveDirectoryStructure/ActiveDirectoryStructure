Function Get-ADSOrganizationalTemplate
{
    Param
    (
        [Parameter(Mandatory = $True)]
        [String] $TemplateName
    )

    Begin
    {
        Write-Verbose "[$($TemplateName)] Start $($MyInvocation.InvocationName)"

        $TemplatePath = Join-Path -Path $Script:XmlRootPath -ChildPath "OrganizationTemplates\$($TemplateName).xml"
        If (-not (Test-Path -Path $TemplatePath))
        {
            Write-Error "Template not found at '$($TemplatePath)'"
        }

        # $SchemePath = Join-Path -Path $PSScriptRoot -ChildPath "OrganizationTemplates\OrganizationalSchema.xsd"
    }

    Process
    {
        [XML]$Template = [XML](Get-Content -Path $TemplatePath)
        # $Template.Schemas.Add($Null, $SchemePath) | Out-Null
        # $Template.Validate($Null)
        Return $Template
    }

    End
    {
        Write-Verbose "[$($TemplateName)] End $($MyInvocation.InvocationName)"
    }
}