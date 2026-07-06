#Requires AutoHotkey v2.0
#SingleInstance Ignore
DetectHiddenWindows true
SetTitleMatchMode 2

DEST_DIR := "D:\Musics\Selection"

SEARCH_ROOTS := [
    "D:\Musics"
]

; Shortcut:
; Ctrl + Alt + C
^!c::{
    MoveCurrentPotPlayerFileByTitle()
}

MoveCurrentPotPlayerFileByTitle() {
    global DEST_DIR, SEARCH_ROOTS

    DirCreate DEST_DIR

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

    src := FindFileInRoots(fileName, SEARCH_ROOTS, DEST_DIR)

    if !src {
        Notify("File not found:`n" fileName, false)
        return
    }

    SplitPath src, &realFileName, &srcDir, &ext, &nameNoExt

    destPath := DEST_DIR . "\" . realFileName

    ; Same filename only. No rename.
    if FileExist(destPath) {
        Notify("Destination file already exists:`n" realFileName, false)
        return
    }

    try {
        FileMove src, destPath, false

        if FileExist(destPath) && !FileExist(src) {
            Notify("Moved successfully:`n" realFileName, true)
        } else if FileExist(destPath) {
            Notify("Moved, but source check failed:`n" realFileName, true)
        } else {
            Notify("Move failed.", false)
        }
    }
    catch as e {
        Notify("Move error:`n" e.Message, false)
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
        cls := WinGetClass("ahk_id " hwnd)
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

    if !(style & 0x10000000) ; WS_VISIBLE
        return false

    if RegExMatch(title, "i)\.(mp3|flac|wav|m4a|aac|ogg|wma|opus|mp4|mkv|avi|mov|webm|m2ts|ts)")
        return true

    if InStr(title, "PotPlayer")
        return true

    return false
}

ExtractFileNameFromPotTitle(title) {
    t := Trim(title)

    t := Trim(t, " `t`r`n'" . Chr(34))

    ; Example:
    ; MP3 | [9383/16291] Song.mp3
    t := RegExReplace(t, "i)^\s*(MP3|FLAC|WAV|M4A|AAC|OGG|WMA|OPUS|MP4|MKV|AVI|MOV|WEBM|M2TS|TS)\s*\|\s*", "")

    ; Example:
    ; [12387/16291]
    t := RegExReplace(t, "^\s*\[[^\]]+\]\s*", "")

    t := RegExReplace(t, "\s*-\s*PotPlayer.*$", "")
    t := RegExReplace(t, "\s*\|\s*PotPlayer.*$", "")

    t := Trim(t, " `t`r`n'" . Chr(34))

    exts := "mp3|flac|wav|m4a|aac|ogg|wma|opus|mp4|mkv|avi|mov|webm|m2ts|ts"

    if RegExMatch(t, "i)([^\\/:*?<>|]+\.(" . exts . "))", &m)
        t := Trim(m[1])

    return t
}

FindFileInRoots(fileName, roots, destDir) {
    hasExt := RegExMatch(fileName, "i)\.(mp3|flac|wav|m4a|aac|ogg|wma|opus|mp4|mkv|avi|mov|webm|m2ts|ts)$")

    wanted := StrLower(fileName)
    wantedNorm := NormalizeFileName(fileName)

    for root in roots {
        root := RTrim(root, "\")

        if !DirExist(root)
            continue

        Loop Files, root . "\*", "FR" {
            full := A_LoopFileFullPath

            ; Do not search inside Selection again.
            if IsUnderFolder(full, destDir)
                continue

            loopName := A_LoopFileName

            if hasExt {
                if StrLower(loopName) = wanted
                    return full

                if NormalizeFileName(loopName) = wantedNorm
                    return full
            } else {
                SplitPath loopName, , , &loopExt, &loopNameNoExt

                if IsSupportedExt(loopExt) {
                    if StrLower(loopNameNoExt) = wanted
                        return full

                    if NormalizeFileName(loopNameNoExt) = wantedNorm
                        return full
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

IsUnderFolder(filePath, folderPath) {
    folderPath := RTrim(folderPath, "\") . "\"

    fileLower := StrLower(filePath)
    folderLower := StrLower(folderPath)

    return SubStr(fileLower, 1, StrLen(folderLower)) = folderLower
}

Notify(message, success := true) {
    title := success ? "PotPlayer Selection" : "PotPlayer Selection - Error"

    TrayTip message, title

    if success
        SoundBeep 1200, 100
    else
        SoundBeep 500, 180
}
