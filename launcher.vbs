' BigBoiRename — silent launcher, no console flash
Dim oShell, scriptDir, ps1, path
Set oShell = CreateObject("WScript.Shell")
scriptDir = Left(WScript.ScriptFullName, InStrRev(WScript.ScriptFullName, "\"))
ps1 = scriptDir & "rename_menu.ps1"
path = WScript.Arguments(0)
' Window style 0 = hidden. Last arg False = don't wait (let PowerShell manage its own lifetime)
oShell.Run "powershell.exe -WindowStyle Hidden -ExecutionPolicy Bypass -File """ & ps1 & """ """ & path & """", 0, False
Set oShell = Nothing
