$Modules = Get-ChildItem "/usr/local/sbin/PSProfile/"
foreach ( $Module in $Modules ) {
    Import-Module -Name $Module.FullName
}

$Commands = @(
    "update",
    "upgrade",
    "dist-upgrade",
    "autoremove"
)

$LogPath = "/var/log/ps_update.log"
if ( -not ( Test-Path -Path $LogPath ) ) {
    try {
        New-Item -Path $LogPath -ItemType "File" | Out-Null
    } catch {
        Write-Error -Message "Unable to create log at $($LogPath)"
    }
}

if ( Test-Path -Path $LogPath ) {
    try {
        New-LogWriter -LogPath $LogPath
    } catch {
        Write-Error -Message "Failed to initialize log writer for '$LogPath': $($_.Exception.Message)"
    }
    $Log = Get-Item -Path $LogPath
    if ( $Log.Length -gt 10MB ) {
        try {
            Get-Content -Path $LogPath -Tail 100 -ErrorAction "Stop" | Set-Content -Path $LogPath -ErrorAction "Stop"
            Write-XEvent -Level "Information" -Message "Log file '$LogPath' exceeded 10MB and was cleared, retaining the last 100 lines."
        } catch {
            Write-Error -Message "Failed to clear log file '$LogPath': $($_.Exception.Message)"
        }
    }
}

foreach ( $Command in $Commands ) {
    $CmdString = "sudo /bin/apt-get {0} -y" -f $Command
    try {
        Write-XEvent -Level "Information" -Message "Executing command: $CmdString"
        $Output = Invoke-Expression $CmdString -ErrorAction "Stop"
    } catch {
        Write-Host "Command '$CmdString' failed with error: $($_.Exception.Message)" -ForegroundColor "Red"
    }
    foreach ( $Line in ( $Output | Where-Object { $_ -match "^\s*E:" } ) ) {
        Write-XEvent -Level "Error" -Message "$($Command): $Line"
    }
}

if ( Test-Path -Path "/var/run/reboot-required" ) {
    Write-XEvent -Level "Warning" -Message "A reboot is required to complete the update process. Rebooting now..."
    Invoke-Expression "/bin/systemctl reboot -i" | Out-Null
}
