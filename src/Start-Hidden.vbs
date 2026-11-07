' Start installed PowerShell monitor without a visible console.
' No network calls, elevation or driver changes.
Option Explicit
Dim wsh, fso, folder, powershellExe, launcherPs1, cmd, exitCode
Set wsh = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")
folder = fso.GetParentFolderName(WScript.ScriptFullName)
powershellExe = wsh.ExpandEnvironmentStrings("%WINDIR%") & "\System32\WindowsPowerShell\v1.0\powershell.exe"
launcherPs1 = fso.BuildPath(folder, "Launch.ps1")
If Not fso.FileExists(launcherPs1) Then WScript.Quit 2
cmd = Chr(34) & powershellExe & Chr(34) & " -NoProfile -NonInteractive -ExecutionPolicy Bypass -File " & Chr(34) & launcherPs1 & Chr(34)
exitCode = wsh.Run(cmd, 0, True)
WScript.Quit exitCode
