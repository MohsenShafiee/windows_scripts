#Requires AutoHotkey v2.0
#SingleInstance Force

; An elevated terminal rejects synthetic input from a non-elevated process
; (UIPI). Relaunch this helper elevated so it works in Administrator shells.
if !A_IsAdmin {
    try {
        Run(Format("*RunAs `"{1}`" /restart `"{2}`"", A_AhkPath, A_ScriptFullPath))
    } catch {
        MsgBox "برای Paste در ترمینال Administrator، اسکریپت باید با دسترسی Administrator اجرا شود."
    }
    ExitApp
}

; Middle Click:
; - Text fields: focus + paste
; - Windows Terminal / PowerShell / CMD: focus + paste
; - Elsewhere: normal middle click

; Modified middle-clicks belong to the other mouse shortcuts.  Without this
; guard, Ctrl+Shift+Middle can be forwarded and trigger SwapMonitors twice.
#HotIf !GetKeyState("Ctrl") && !GetKeyState("Shift") && !GetKeyState("Alt") && !GetKeyState("LWin") && !GetKeyState("RWin")
$MButton::{
    MouseGetPos ,, &winId
    proc := ""
    cls := ""

    try proc := WinGetProcessName("ahk_id " winId)
    try cls := WinGetClass("ahk_id " winId)

    isTerminal :=
        proc = "WindowsTerminal.exe"
        || proc = "wt.exe"
        || proc = "powershell.exe"
        || proc = "pwsh.exe"
        || proc = "cmd.exe"
        || cls = "ConsoleWindowClass"
        || cls = "CASCADIA_HOSTING_WINDOW_CLASS"

    if (A_Cursor = "IBeam" || isTerminal) {
        Click "Left"
        Sleep 120
        Send "^v"
    } else {
        Send "{MButton}"
    }
}
#HotIf
