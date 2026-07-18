#Requires AutoHotkey v2.0
#SingleInstance Force

; Ctrl + Shift + . toggles hidden files in File Explorer.
^+.::
{
    key := "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
    current := RegRead(key, "Hidden", 2)
    next := current = 1 ? 2 : 1

    RegWrite(next, "REG_DWORD", key, "Hidden")

    DllCall("SendMessageTimeout"
        , "Ptr", 0xFFFF
        , "UInt", 0x1A
        , "Ptr", 0
        , "Str", "Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
        , "UInt", 0x2
        , "UInt", 1000
        , "Ptr*", 0)

    DllCall("Shell32\SHChangeNotify"
        , "Int", 0x08000000
        , "UInt", 0
        , "Ptr", 0
        , "Ptr", 0)

    RefreshExplorerWindows()
}

RefreshExplorerWindows()
{
    explorerHwnds := []

    for window in ComObject("Shell.Application").Windows {
        try {
            if InStr(window.FullName, "explorer.exe") {
                explorerHwnds.Push(window.HWND)
                window.Refresh()
            }
        }
    }

    Sleep(120)

    ; Explorer sometimes paints an empty view after changing Hidden. Sending its
    ; own Refresh command usually fixes that without leaving the current folder.
    for hwnd in explorerHwnds {
        try PostMessage(0x111, 41504, 0, , "ahk_id " hwnd)
    }

    Sleep(120)

    for window in ComObject("Shell.Application").Windows {
        try {
            if InStr(window.FullName, "explorer.exe")
                window.Refresh()
        }
    }
}
