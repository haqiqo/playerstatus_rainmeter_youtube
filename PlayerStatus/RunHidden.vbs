' RunHidden.vbs
' Launches GetNowPlaying.ps1 with a fully invisible window.
' powershell.exe's own -WindowStyle Hidden still briefly flashes a
' console; running it through this VBS wrapper (window style 0) does not.
'
' This script auto-detects its own folder, so it works wherever you
' put the PlayerStatus folder - no path editing needed.
'
' IMPORTANT: put a SHORTCUT to this file in your Startup folder
' (Win+R -> shell:startup), not a copy of the file itself. A copied
' file placed directly in Startup would look for GetNowPlaying.ps1
' inside the Startup folder instead of here, and fail silently.

Set fso = CreateObject("Scripting.FileSystemObject")
scriptDir = fso.GetParentFolderName(WScript.ScriptFullName)
ps1Path = scriptDir & "\GetNowPlaying.ps1"

cmd = "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File """ & ps1Path & """"

CreateObject("WScript.Shell").Run cmd, 0, False
