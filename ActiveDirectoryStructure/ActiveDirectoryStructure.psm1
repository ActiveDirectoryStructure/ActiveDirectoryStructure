$Public = @( Get-ChildItem -Path "$($PSScriptRoot)\Public\*.ps1" -ErrorAction SilentlyContinue )
$Private = @( Get-ChildItem -Path "$($PSScriptRoot)\Private\*.ps1" -ErrorAction SilentlyContinue )

ForEach ($import in @($Public + $Private))
{
    Try
    {
        . $import.FullName
    }
    Catch
    {
        Write-Error -Message "Failed to import function $($import.fullname): $_"
    }
}
