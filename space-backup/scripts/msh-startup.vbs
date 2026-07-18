Option Explicit

Const ForAppending = 8

Dim shell, fileSystem, scriptDirectory, lockFile, logFile
Dim launcher, workspaceId, launcherCommand, index, lockAge, launchResult

Set shell = CreateObject("WScript.Shell")
Set fileSystem = CreateObject("Scripting.FileSystemObject")

scriptDirectory = fileSystem.GetParentFolderName(WScript.ScriptFullName)
lockFile = fileSystem.BuildPath(scriptDirectory, "msh-startup.lock")
logFile = fileSystem.BuildPath(scriptDirectory, "msh-startup.log")
launcher = shell.ExpandEnvironmentStrings("%LOCALAPPDATA%") & "\PowerToys\PowerToys.WorkspacesLauncher.exe"
workspaceId = "{9C843AB4-AFBB-4DFE-A7F2-F132E38E3469}"
launcherCommand = Quote(launcher) & " " & workspaceId & " 1"

If fileSystem.FileExists(lockFile) Then
    lockAge = DateDiff("s", fileSystem.GetFile(lockFile).DateLastModified, Now)
    If lockAge >= 0 And lockAge < 180 Then
        WScript.Quit 0
    End If
End If

fileSystem.CreateTextFile(lockFile, True).Close
On Error Resume Next

WriteLog "Waiting for Explorer."

For index = 1 To 40
    If ProcessIsRunning("explorer.exe") Then
        Exit For
    End If
    WScript.Sleep 250
Next

If Not fileSystem.FileExists(launcher) Then
    Err.Raise 53, "msh-startup", "PowerToys Workspaces launcher was not found: " & launcher
End If

WriteLog "Launching space."
launchResult = shell.Run(launcherCommand, 0, True)

If Err.Number = 0 And launchResult = 0 Then
    WriteLog "Workspace startup completed."
Else
    WriteLog "Workspace startup failed (exit " & launchResult & "): " & Err.Description
End If

fileSystem.DeleteFile lockFile, True

Function ProcessIsRunning(processName)
    Dim processes
    Set processes = GetObject("winmgmts:\\.\root\cimv2").ExecQuery( _
        "SELECT ProcessId FROM Win32_Process WHERE Name='" & processName & "'")
    ProcessIsRunning = (processes.Count > 0)
End Function

Function Quote(value)
    Quote = Chr(34) & value & Chr(34)
End Function

Sub WriteLog(message)
    Dim stream
    Set stream = fileSystem.OpenTextFile(logFile, ForAppending, True)
    stream.WriteLine Year(Now) & "-" & Right("0" & Month(Now), 2) & "-" & _
        Right("0" & Day(Now), 2) & " " & Right("0" & Hour(Now), 2) & ":" & _
        Right("0" & Minute(Now), 2) & ":" & Right("0" & Second(Now), 2) & " " & message
    stream.Close
End Sub
