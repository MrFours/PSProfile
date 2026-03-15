#region Microsoft.PowerShell_profile.ps1
if ( Test-Path -Path ([System.IO.Path]::Combine($env:USERPROFILE,"PSProfile")) ) { $ModulePath = [System.IO.Path]::Combine($env:USERPROFILE,"PSProfile") }
if ( Test-Path -Path ([System.IO.Path]::Combine($env:HOME,"PSProfile")) )        { $ModulePath = [System.IO.Path]::Combine($env:HOME,"PSProfile") }

if ( -not ( $ModulePath ) ) { Write-Warning -Message "Local ModulePath not found";return }

$Modules = Get-ChildItem -Path $ModulePath -Filter "*.psm1" -File
foreach ( $Modules in $Modules) {
    try {
        Import-Module $Modules.FullName -ErrorAction "Stop"
    } catch {
        Write-Error -Message "Unable to import '$($Modules.Name)' - Error: $($_.Exception.Message)"
    }
}
#endregion
