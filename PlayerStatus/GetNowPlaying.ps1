<#
  GetNowPlaying.ps1

  Polls Windows' System Media Transport Controls (SMTC) - the same
  system that powers the media flyout on your volume icon - and
  writes whatever is currently playing to nowplaying.json next to
  this script.

  This catches Windows Media Player, Spotify, and browser tabs
  (Chrome / Edge) including YouTube Music, since Chromium reports
  HTML5 media playback to SMTC automatically.

  Run this hidden, in the background, at login (see install notes
  in PlayerStatus.ini). It updates once a second.
#>

$OutFile = Join-Path $PSScriptRoot "nowplaying.json"
$TempFile = Join-Path $PSScriptRoot "nowplaying.json.tmp"

Add-Type -AssemblyName System.Runtime.WindowsRuntime

$asTaskGeneric = ([System.WindowsRuntimeSystemExtensions].GetMethods() |
    Where-Object {
        $_.Name -eq 'AsTask' -and
        $_.GetParameters().Count -eq 1 -and
        $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1'
    })[0]

function Await($WinRtTask, $ResultType) {
    $asTask = $asTaskGeneric.MakeGenericMethod($ResultType)
    $netTask = $asTask.Invoke($null, @($WinRtTask))
    $netTask.Wait(-1) | Out-Null
    $netTask.Result
}

[Windows.Media.Control.GlobalSystemMediaTransportControlsSessionManager,Windows.Media.Control,ContentType=WindowsRuntime] | Out-Null
[Windows.Media.Control.GlobalSystemMediaTransportControlsSessionMediaProperties,Windows.Media.Control,ContentType=WindowsRuntime] | Out-Null

$sessionManager = Await ([Windows.Media.Control.GlobalSystemMediaTransportControlsSessionManager]::RequestAsync()) `
    ([Windows.Media.Control.GlobalSystemMediaTransportControlsSessionManager])

function Get-FriendlyApp($aumid) {
    if (-not $aumid) { return "" }
    switch -Wildcard ($aumid) {
        "*chrome*"        { return "Chrome" }
        "*msedge*"        { return "Edge" }
        "*firefox*"       { return "Firefox" }
        "*wmplayer*"      { return "Windows Media Player" }
        "*Spotify*"       { return "Spotify" }
        default           { return ($aumid -split '\\')[-1] -replace '\.exe$', '' }
    }
}

# Build JSON by hand - PowerShell's ConvertTo-Json HTML-escapes apostrophes
# (' -> \u0027) and forward slashes (/ -> \/) by default, which our simple
# regex parser in Rainmeter doesn't decode. Only escape what JSON actually
# requires: backslash and double-quote.
function ConvertTo-SafeJsonString($s) {
    if ($null -eq $s) { return "" }
    $s = $s -replace '\\', '\\\\'
    $s = $s -replace '"', '\"'
    $s = $s -replace "`r", ''
    $s = $s -replace "`n", ' '
    $s = $s -replace "`t", ' '
    return $s
}

function Write-NowPlaying($data) {
    $json = '{"Title":"' + (ConvertTo-SafeJsonString $data.Title) +
        '","Artist":"' + (ConvertTo-SafeJsonString $data.Artist) +
        '","App":"' + (ConvertTo-SafeJsonString $data.App) +
        '","State":' + [int]$data.State + '}'
    # Write without a BOM so non-ASCII titles (e.g. Japanese) come through clean
    [System.IO.File]::WriteAllText($TempFile, $json, (New-Object System.Text.UTF8Encoding($false)))
    Move-Item -Path $TempFile -Destination $OutFile -Force
}

while ($true) {
    try {
        $sessions = $sessionManager.GetSessions()

        # Only pick a session that's actually PLAYING and has a real artist
        # set. SMTC has no concept of "which website" - it only knows which
        # app (e.g. Chrome) is playing something - so this is the closest
        # proxy for "real music" (YouTube Music always sets an artist;
        # a Reddit video almost never does) and it filters out random tab
        # audio/video without needing exact site detection.
        $session = $null
        $props = $null
        foreach ($s in $sessions) {
            $playing = $s.GetPlaybackInfo().PlaybackStatus -eq [Windows.Media.Control.GlobalSystemMediaTransportControlsSessionPlaybackStatus]::Playing
            if (-not $playing) { continue }
            $p = Await ($s.TryGetMediaPropertiesAsync()) `
                ([Windows.Media.Control.GlobalSystemMediaTransportControlsSessionMediaProperties])
            if (-not [string]::IsNullOrWhiteSpace($p.Artist)) {
                $session = $s
                $props = $p
                break
            }
        }

        if ($session) {
            $status = [int]$session.GetPlaybackInfo().PlaybackStatus
            # PlaybackStatus: 0 Closed, 1 Opened, 2 Changing, 3 Stopped, 4 Playing, 5 Paused

            $data = [PSCustomObject]@{
                Title    = $props.Title
                Artist   = $props.Artist
                App      = Get-FriendlyApp $session.SourceAppUserModelId
                State    = $status
            }
        }
        else {
            $data = [PSCustomObject]@{ Title = ""; Artist = ""; App = ""; State = 0 }
        }

        Write-NowPlaying $data
    }
    catch {
        Write-NowPlaying ([PSCustomObject]@{ Title = ""; Artist = ""; App = ""; State = 0 })
    }

    Start-Sleep -Seconds 1
}
