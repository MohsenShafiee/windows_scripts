#Requires AutoHotkey v2.0
#SingleInstance Ignore
DetectHiddenWindows true
SetTitleMatchMode 2

; Options:
; "permanent" = delete permanently
; "recycle"   = move to Recycle Bin
DELETE_MODE := "recycle"

SEARCH_ROOTS := [
    "D:\Musics"
]

; Shortcut:
; Ctrl + Alt + D
^!d::{
    DeleteCurrentPotPlayerFileByTitle()
}

DeleteCurrentPotPlayerFileByTitle() {
    global DELETE_MODE, SEARCH_ROOTS

    pot := FindPotPlayer()
    if !pot {
        Notify("PotPlayer not found.", false)
        return
    }

    title := WinGetTitle("ahk_id " pot)
    fileName := ExtractFileNameFromPotTitle(title)

    if !fileName {
        Notify("Could not read the current file name from PotPlayer.", false)
        return
    }

    src := FindFileInRoots(fileName, SEARCH_ROOTS)

    if !src {
        Notify("File not found:`n" fileName, false)
        return
    }

    SplitPath src, &realFileName

    ; Move PotPlayer to next item first, so the current file is released.
    PlayNextInPotPlayer(pot)

    ; Give PotPlayer a moment to release the old file.
    Sleep 800

    try {
        if DELETE_MODE = "permanent" {
            FileDelete src

            if !FileExist(src)
                Notify("Deleted permanently:`n" realFileName, true)
            else
                Notify("Permanent delete failed:`n" realFileName, false)
        }
        else if DELETE_MODE = "recycle" {
            FileRecycle src

            if !FileExist(src)
                Notify("Moved to Recycle Bin:`n" realFileName, true)
            else
                Notify("Recycle failed:`n" realFileName, false)
        }
        else {
            Notify("Invalid DELETE_MODE:`n" DELETE_MODE, false)
        }
    }
    catch as e {
        Notify("Delete error:`n" e.Message, false)
    }
}

PlayNextInPotPlayer(pot) {
    oldWin := WinExist("A")

    try {
        WinActivate "ahk_id " pot
        WinWaitActive "ahk_id " pot, , 0.8

        ; PotPlayer default shortcut for next item/file
        Send "{PgDn}"

        Sleep 180

        if oldWin && WinExist("ahk_id " oldWin)
            WinActivate "ahk_id " oldWin
    }
    catch {
        ; If switching fails, deletion will still be attempted after Sleep.
    }
}

FindPotPlayer() {
    exes := [
        "PotPlayerMini64.exe",
        "PotPlayerMini.exe",
        "PotPlayer64.exe",
        "PotPlayer.exe"
    ]

    for exe in exes {
        for hwnd in WinGetList("ahk_exe " exe) {
            if IsGoodPotPlayerWindow(hwnd)
                return hwnd
        }
    }

    for hwnd in WinGetList() {
        try {
            title := WinGetTitle("ahk_id " hwnd)
            cls := WinGetClass("ahk_id " hwnd)

            if (InStr(title, "PotPlayer") || InStr(cls, "PotPlayer")) && IsGoodPotPlayerWindow(hwnd)
                return hwnd
        }
    }

    return 0
}

IsGoodPotPlayerWindow(hwnd) {
    try {
        title := Trim(WinGetTitle("ahk_id " hwnd))
        style := WinGetStyle("ahk_id " hwnd)
    } catch {
        return false
    }

    if title = ""
        return false

    badTitles := [
        "ActiveMovie Window",
        "Default IME",
        "MSCTFIME UI"
    ]

    for bad in badTitles {
        if title = bad
            return false
    }

    ; WS_VISIBLE
    if !(style & 0x10000000)
        return false

    if RegExMatch(title, "i)\.(mp3|flac|wav|m4a|aac|ogg|wma|opus|mp4|mkv|avi|mov|webm|m2ts|ts)")
        return true

    if InStr(title, "PotPlayer")
        return true

    return false
}

ExtractFileNameFromPotTitle(title) {
    t := Trim(title)

    ; Remove quotes.
    t := Trim(t, " `t`r`n'" . Chr(34))

    ; Example:
    ; MP3 | [9383/16291] Song.mp3
    t := RegExReplace(t, "i)^\s*(MP3|FLAC|WAV|M4A|AAC|OGG|WMA|OPUS|MP4|MKV|AVI|MOV|WEBM|M2TS|TS)\s*\|\s*", "")

    ; Example:
    ; [12387/16291]
    t := RegExReplace(t, "^\s*\[[^\]]+\]\s*", "")

    ; Remove PotPlayer suffix if present.
    t := RegExReplace(t, "\s*-\s*PotPlayer.*$", "")
    t := RegExReplace(t, "\s*\|\s*PotPlayer.*$", "")

    t := Trim(t, " `t`r`n'" . Chr(34))

    exts := "mp3|flac|wav|m4a|aac|ogg|wma|opus|mp4|mkv|avi|mov|webm|m2ts|ts"

    if RegExMatch(t, "i)([^\\/:*?<>|]+\.(" . exts . "))", &m)
        t := Trim(m[1])

    return t
}

FindFileInRoots(fileName, roots) {
    hasExt := RegExMatch(fileName, "i)\.(mp3|flac|wav|m4a|aac|ogg|wma|opus|mp4|mkv|avi|mov|webm|m2ts|ts)$")

    wanted := StrLower(fileName)
    wantedNorm := NormalizeFileName(fileName)

    for root in roots {
        root := RTrim(root, "\")

        if !DirExist(root)
            continue

        Loop Files, root . "\*", "FR" {
            loopName := A_LoopFileName

            if hasExt {
                if StrLower(loopName) = wanted
                    return A_LoopFileFullPath

                if NormalizeFileName(loopName) = wantedNorm
                    return A_LoopFileFullPath
            } else {
                SplitPath loopName, , , &loopExt, &loopNameNoExt

                if IsSupportedExt(loopExt) {
                    if StrLower(loopNameNoExt) = wanted
                        return A_LoopFileFullPath

                    if NormalizeFileName(loopNameNoExt) = wantedNorm
                        return A_LoopFileFullPath
                }
            }
        }
    }

    return ""
}

NormalizeFileName(name) {
    n := StrLower(name)

    n := StrReplace(n, "–", "-")
    n := StrReplace(n, "—", "-")
    n := StrReplace(n, "−", "-")

    n := RegExReplace(n, "\s+", " ")
    n := RegExReplace(n, "\s*-\s*", "-")
    n := Trim(n)

    return n
}

IsSupportedExt(ext) {
    return RegExMatch(ext, "i)^(mp3|flac|wav|m4a|aac|ogg|wma|opus|mp4|mkv|avi|mov|webm|m2ts|ts)$")
}

Notify(message, success := true) {
    title := success ? "PotPlayer Delete" : "PotPlayer Delete - Error"

    TrayTip message, title

    if success
        SoundBeep 1200, 100
    else
        SoundBeep 500, 180
}
