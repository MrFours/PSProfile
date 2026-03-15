Function Write-XEvent {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [ValidateSet("Critical","Debug","Error","Information","Success","Verbose","Warning")]
        [System.String] $Level,

        [Parameter(Mandatory=$true,ValueFromPipeline=$true )]
        [System.String] $Message,

        [Parameter(Mandatory=$false,ValueFromPipeline=$false)]
        [System.String] $CommandName
    )
    try {
        switch ($Level) {
            "Critical" { $Color = "$([System.Char]27)[31m" }
            "Debug"    { $Color = "$([System.Char]27)[94m" }
            "Error"    { $Color = "$([System.Char]27)[91m" }
            "Success"  { $Color = "$([System.Char]27)[92m" }
            "Verbose"  { $Color = "$([System.Char]27)[96m" }
            "Warning"  { $Color = "$([System.Char]27)[93m" }
            default    { $Color = "$([System.Char]27)[97m" }
        }
        $OutputString  = $Reset = "$([System.Char]27)[37m"
        $OutputString += "{0:yyyy-MM-dd HH:mm:ss.ffff}" -f [System.DateTime]::Now
        $OutputString += " [{0}{1}{2}] " -f $Color,$Level,$Reset
        $OutputString += "{0}@{1}" -f $env:USERNAME,$env:COMPUTERNAME
        if ( $CommandName ) { $OutputString += " {0}{1}:{2}" -f $Color,$CommandName,$Reset }
        $OutputString += " {0}{1}{2}" -f $Color,$Message,$Reset
        Write-Host $OutputString
        if ($LOGWRITER) {
            $LogString = $OutputString -replace "$([System.Char]27)\[\d{2}m", ""
            $LOGWRITER.WriteLine($LogString)
            $LOGWRITER.Flush()
        }
    } catch {
        Write-Error -Message "Error: $($PSItem.Exception.Message) - Line Number: $($PSItem.InvocationInfo.ScriptLineNumber)"
    }
}

Function New-LogWriter {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [System.String] $LogPath
    )
    # Close existing log writer
    try {
        if ( Test-Path -Path "Variable:\LOGWRITER" )
        {
            if ( $Global:LOGWRITER -is [System.IO.TextWriter] ) { $Global:LOGWRITER.Dispose() }
            else                                                { $Global:LOGWRITER = $null }
        }
    } catch {
        Write-Error -Message "Unable to reset log writer - Error: $($PSItem.Exception.Message) - Line Number: $($PSItem.InvocationInfo.ScriptLineNumber)"
    }
    try {
        if ( Test-Path -Path "Variable:\FILESTREAM" )
        {
            if ( $Global:FILESTREAM -is [System.IO.Stream] ) { $Global:FILESTREAM.Dispose() }
            else                                             { $Global:FILESTREAM = $null }
        }
    } catch {
        Write-Error -Message "Unable to reset file stream - Error: $($PSItem.Exception.Message) - Line Number: $($PSItem.InvocationInfo.ScriptLineNumber)"
    }

    if ( -not ( Test-Path -Path $LogPath ) )
    {
        try {
            New-Item -ItemType File -Path $LogPath -ErrorAction "Stop" -Force | Out-Null
        } catch {
            Write-Error -Message "Unable to create '$LogPath' - Error: $($PSItem.Exception.Message) - Line Number: $($PSItem.InvocationInfo.ScriptLineNumber)"
        }
    }
    $env:LOGPATH = $LogPath
    try {
        $Global:FILESTREAM = [System.IO.File]::Open(
            $LogPath,
            [System.IO.FileMode]::Append,
            [System.IO.FileAccess]::Write,
            [System.IO.FileShare]::ReadWrite
        )
    } catch {
        Write-Error -Message "Unable to create FileStream to '$LOGPATH' - Error: $($PSItem.Exception.Message) - Line Number: $($PSItem.InvocationInfo.ScriptLineNumber)"
    }
    try {
        $Global:LOGWRITER = New-Object System.IO.StreamWriter($FILESTREAM)
        $Global:LOGWRITER.AutoFlush = $true
    } catch {
        Write-Error -Message "Unable to create log writer - Error: $($PSItem.Exception.Message) - Line Number: $($PSItem.InvocationInfo.ScriptLineNumber)"
    }
}

Function Test-XEvent {
    [CmdletBinding()]
    Param()
    $Events = @(
        "Information",
        "Success",
        "Verbose",
        "Debug",
        "Warning",
        "Error",
        "Critical"
    )

    foreach ( $XEvent in $Events ) {
        Write-XEvent -Level $XEvent -Message "Test event"
    }
}

Export-ModuleMember -Function * -Alias *
