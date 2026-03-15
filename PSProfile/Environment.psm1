#region Add Namespaces
using namespace System.Management.Automation
using namespace System.Management.Automation.Language
#endregion

#region ErrorHandling
$ErrorActionPreference = "Stop"
#endregion

#region Check PSVersion
if ( $PSVersionTable.PSVersion.Major -lt 7 ) {
    $env:PSSTYLE = "Legacy"
} else {
    $env:PSSTYLE = "Modern"
}
#endregion

#region PlatformVariables
# Add variables to make powershell the same on each platform
try {
    if($IsMacOS) {
        $env:ICON         = [char]61817                                    # [char]61817 is the MacOS icon
        $env:COMPUTERNAME = $(scutil --get LocalHostName)                  # Set COMPUTERNAME in $env using scutil on MacOS
        $env:USERNAME     = $env:USER                                      # Set USERNAME in $env
        $env:USERPROFILE  = $env:HOME                                      # Set USERPROFILE in $env
        $env:ISADMIN      = if ( $(id -u) -eq 0) { $true } else { $false } # Set IsAdmin in $env
    } elseif ($IsWindows -or [System.Environment]::OSVersion.Platform -eq "Win32NT") {
        $env:ICON    = [char]58922                                                                              # [char]58922 is the Windows icon
        $AdminRole   = [Security.Principal.WindowsBuiltInRole]::Administrator                                   # Get the Administrator role
        $CurrentRole = [Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent() # Get the current role
        $env:ISADMIN = if ( $CurrentRole.IsInRole($AdminRole) ) { $true } else { $false }                       # Set IsAdmin in $env
    } elseif ($IsLinux) {
        $env:ICON         = [char]62235                                    # [char]59154 is the Linux icon
        $env:COMPUTERNAME = $(hostname)                                    # Set hostname in $env using scutil on Linux
        $env:USERNAME     = $env:USER                                      # Set USERNAME in $env
        $env:USERPROFILE  = $env:HOME                                      # Set USERPROFILE in $env
        $env:ISADMIN      = if ( $(id -u) -eq 0) { $true } else { $false } # Set IsAdmin in $env
    } else {
        Write-Error -Message "Unable to determine the operating system - Error: $($_.Exception.Message)"
    }
} catch {
    Write-Error -Message "Unable to determine the operating system - Error: $($_.Exception.Message)"
}
#endregion

#region Pyenv
try {
    $env:PYENV_ROOT = [System.IO.Path]::Combine($env:HOME,".pyenv")
    if ( Test-Path -Path $env:PYENV_ROOT ) {
        $ShimsPath = [System.IO.Path]::Combine($env:PYENV_ROOT,"shims")
        if ( Test-Path -Path $ShimsPath) {
            if ( -not ( $env:PATH -match $ShimsPath ) ) {
                $env:PATH = "{0}:{1}" -f $ShimsPath,$env:PATH
            }
        }
    }
} catch {
    Write-Error -Message "PYENV: Unable to load pyenv - Error: $($_.Exception.Message)"
}
#endregion

#region DOTNET
try {
    $env:DOTNET_ROOT = "/usr/local/share/dotnet"
    if ( Test-Path -Path $env:DOTNET_ROOT ) {
        if ( -not ( $env:PATH -match $env:DOTNET_ROOT ) ) {
            $env:PATH = "{0}:{1}" -f $env:DOTNET_ROOT,$env:PATH
        }
    }
} catch {
    Write-Error -Message "DOTNET: Unable to load dotnet - Error: $($_.Exception.Message)"
}
#endregion

#region DefaultLocation
try {
    Set-Location -Path $env:USERPROFILE -ErrorAction "Stop"
} catch {
    Write-Error -Message "Unable to set the default location to $env:USERPROFILE"
}
#endregion

#region SetCulture
try {
    $Swedish = [System.Globalization.CultureInfo]::new("sv-SE")
    $Current = [System.Globalization.CultureInfo]::CurrentCulture

    if ( $Current -ne $Swedish )
    {
        [System.Globalization.CultureInfo]::CurrentCulture = $Swedish
    }
} catch {
    Write-Error -Message "Unable to set the current culture to Swedish - Error: $($_.Exception.Message)"
}
#endregion

#region Set Domain Controller
if ( $IsWindows )
{
    try { $Domain            = [System.DirectoryServices.ActiveDirectory.Domain]::GetCurrentDomain() } catch { }
    try { $DomainSite        = [System.DirectoryServices.ActiveDirectory.ActiveDirectorySite]::GetComputerSite() } catch { }
    try { $DomainContextType = [System.DirectoryServices.ActiveDirectory.DirectoryContextType]::Domain } catch { }
    try { $DomainContext     = [System.DirectoryServices.ActiveDirectory.DirectoryContext]::New($DomainContextType, $Domain.Name) } catch { }
    try { $DomainController  = [System.DirectoryServices.ActiveDirectory.DomainController]::FindOne($DomainContext, $DomainSite) } catch { }
    try { $env:DC            = $DomainController.Name } catch { }
}
#endregion

#region PSGallery
try {
    $Gallery = Get-PSRepository -Name "PSGallery" -ErrorAction "Stop"
} catch {
    Write-Error -Message "Unable to find PSGallery repository - Error: $($_.Exception.Message)"
}

try {
    if ( $Gallery ) {
        if ( $Gallery.InstallationPolicy -ne "Trusted" ){
            Set-PSRepository -Name "PSGallery" -InstallationPolicy "Trusted" -ErrorAction "Stop"
        }
    }
} catch {
    Write-Error -Message "Unable to set PSGallery repository to Trusted - Error: $($_.Exception.Message)"
}
#endregion

#region Modules
$Modules = [System.Collections.ArrayList]::New()
$Modules.Add("PSReadLine") | Out-Null
$Modules.Add("Terminal-Icons") | Out-Null

if ( $PSVersionTable.PSVersion.Major -lt 7 )
{
    $Modules.Add("PSStyle") | Out-Null
}

foreach ( $Module in $Modules ) {
    if ( Get-Module -Name $Module -ListAvailable ) {
        try {
            Import-Module -Name $Module -ErrorAction "Stop"
        } catch {
            Write-Error -Message "Unable to import '$Module' - Error: $($_.Exception.Message) - Line Number: $($_.InvocationInfo.ScriptLineNumber)"
        }
    } else {
        try {
            $GalleryModule = Find-Module -Name $Module -ErrorAction "Stop"
            if ( $GalleryModule ) {
                Install-Module -Name $GalleryModule.Name -ErrorAction "Stop" -WarningAction "SilentlyContinue" | Out-Null
                Import-Module -Name $GalleryModule.Name -ErrorAction "Stop"
            }
        } catch {
            Write-Error -Message "Unable to install '$Module' - Error: $($_.Exception.Message) - Line Number: $($_.InvocationInfo.ScriptLineNumber)"
        }
    }
}
#endregion

#region PSReadLine options
if ( Get-Module | Where-Object {$_.Name -eq "PSReadLine"} )
{
    $PSReadLineOptions = @{
        "PredictionSource"    = "History"
        "PredictionViewStyle" = "ListView"
        "EditMode"            = "Windows"
        "Colors"              = @{
            ContinuationPrompt     = "White"
            Emphasis               = "DarkYellow"
            Error                  = "Red"
            Selection              = if ( $env:PSSTYLE -eq "Legacy") { "$([char]0x1b)[30;107m" } else { "`e[48;5;238m" }
            Default                = "White"
            Comment                = "DarkGreen"
            Keyword                = "White"
            String                 = "DarkYellow"
            Operator               = "White"
            Variable               = "Cyan"
            Command                = "Yellow"
            Parameter              = "White"
            Type                   = "Blue"
            Number                 = "White"
            Member                 = "White"
            InlinePrediction       = "Gray"
            ListPrediction         = "Blue"
            ListPredictionSelected = if ( $env:PSSTYLE -eq "Legacy") { "$([char]0x1b)[48;5;238m" } else { "`e[48;5;238m" }
        }
    }

    try {
        Set-PSReadLineOption @PSReadLineOptions -ErrorAction "Stop"
    } catch {
        Write-Host "Unable to set PSReadLine options" -ForegroundColor "Red"
    }

}
#endregion

#region winget CLI
try {
    Register-ArgumentCompleter -Native -CommandName winget -ScriptBlock {
        Param(
            $WordToComplete,
            $CommandAst,
            $CursorPosition
        )
        [System.Console]::InputEncoding = [System.Console]::OutputEncoding = $OutputEncoding = [System.Text.Utf8Encoding]::New()
        $Local:Word = $WordToComplete.Replace('"', '""')
        $Local:Ast  = $CommandAst.ToString().Replace('"', '""')
        $Arguments  = winget complete --word="$Local:Word" --commandline "$Local:Ast" --position $CursorPosition
        foreach ( $Arg in $Arguments ) {
            [System.Management.Automation.CompletionResult]::New($Arg, $Arg, 'ParameterValue', $arg)
        }
    } -ErrorAction "Stop"
} catch {
    Write-Host "Unable to register argument completers for winget" -ForegroundColor "Red"
}
#endregion

#region Prompt
Function Prompt {
    if ($?) {
        $PromptString = " $([Char]27)[0m{0}  " -f $Env:ICON
    } else {
        $PromptString = " $([Char]27)[31m{0}  " -f $([char]61453) # [char]61453 is the error icon
    }
    $PromptString += "$([Char]27)[32m{0}" -f $env:USERNAME
    $PromptString += "$([Char]27)[0m@"
    $PromptString += "$([Char]27)[32m{0} " -f $env:COMPUTERNAME.ToLower()

    if ( $($executionContext.SessionState.Path.CurrentLocation).ToString() -eq $env:USERPROFILE ) {
        $PromptString += "$([Char]27)[0m~"
    } else {
        $PromptString += "$([Char]27)[0m{0}" -f $($executionContext.SessionState.Path.CurrentLocation)
    }
    $EndString = "{0} | {1:HH:mm:ss} " -f [System.Diagnostics.Process]::GetCurrentProcess().ProcessName.ToLower(),[DateTime]::Now

    $PrompStringLength = $PromptString -replace "$([Char]27)\[[0-9;]*[mK]", "" | Measure-Object -Character | Select-Object -ExpandProperty Characters
    $EndStringLength   = $EndString    -replace "$([Char]27)\[[0-9;]*[mK]", "" | Measure-Object -Character | Select-Object -ExpandProperty Characters

    $Spacing = " " * ( $Host.UI.RawUI.WindowSize.Width - $PrompStringLength - $EndStringLength )

    $PromptString += $Spacing
    $PromptString += $EndString
    Write-Host $PromptString

    " $([char]10095) "
}
#endregion

Export-ModuleMember -Function * -Alias *
