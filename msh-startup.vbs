Option Explicit

Dim fileSystem, shell, target
Set fileSystem = CreateObject("Scripting.FileSystemObject")
Set shell = CreateObject("WScript.Shell")

target = fileSystem.BuildPath( _
    fileSystem.GetParentFolderName(WScript.ScriptFullName), _
    "apps\space-workspace\runtime\msh-startup.vbs")

WScript.Quit shell.Run("wscript.exe " & Quote(target), 0, True)

Function Quote(value)
    Quote = Chr(34) & value & Chr(34)
End Function
