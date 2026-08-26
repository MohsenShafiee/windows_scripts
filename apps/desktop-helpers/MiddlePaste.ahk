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

    isBrowser :=
        proc = "chrome.exe"
        || proc = "msedge.exe"
        || proc = "firefox.exe"
        || proc = "brave.exe"
        || proc = "opera.exe"
        || proc = "vivaldi.exe"

    ; A selected hyperlink often leaves a Hand/Arrow cursor, so A_Cursor alone
    ; cannot identify it as selected text. Probe the browser selection while
    ; preserving every clipboard format, then paste only when text was copied.
    browserHasSelection := isBrowser
        && WinActive("ahk_id " winId)
        && HasSelectedText()

    if (A_Cursor = "IBeam" || isTerminal || browserHasSelection) {
        ; A left click collapses an existing text/link selection before paste.
        ; Keep the current selection and only activate the target window when
        ; it is not already active.
        if !WinActive("ahk_id " winId) {
            WinActivate "ahk_id " winId
            if !WinWaitActive("ahk_id " winId, , 0.5)
                return
        }
        Send "^v"
    } else {
        Send "{MButton}"
    }
}
#HotIf

HasSelectedText() {
    savedClipboard := ClipboardAll()
    A_Clipboard := ""
    Send "^c"
    hasText := ClipWait(0.2) && A_Clipboard != ""
    A_Clipboard := savedClipboard
    Sleep 30
    return hasText
}
