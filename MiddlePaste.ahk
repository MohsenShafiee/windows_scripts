#Requires AutoHotkey v2.0
#SingleInstance Ignore

; Middle Click:
; - Text fields: focus + paste
; - Windows Terminal / PowerShell / CMD: focus + paste
; - Elsewhere: normal middle click

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
