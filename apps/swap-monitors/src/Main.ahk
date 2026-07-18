#Requires AutoHotkey v2.0

#Include "Win32.ahk"
#Include "ConfigService.ahk"
#Include "Logger.ahk"
#Include "GeometryService.ahk"
#Include "MonitorService.ahk"
#Include "WindowService.ahk"
#Include "SwapService.ahk"
#Include "DiagnosticService.ahk"
#Include "AppController.ahk"

SetWinDelay(-1)
SetControlDelay(-1)

SplitPath(A_LineFile, , &sourceDir)
projectRoot := ComObject("Scripting.FileSystemObject").GetAbsolutePathName(sourceDir "\..")
global SwapMonitorApp := AppController(projectRoot)
SwapMonitorApp.Start()
