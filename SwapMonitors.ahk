#Requires AutoHotkey v2.0
#SingleInstance Off

if !A_IsAdmin {
    try {
        Run(Format("*RunAs `"{1}`" /restart `"{2}`"", A_AhkPath, A_ScriptFullPath))
    } catch {
        MsgBox "برای جابه‌جایی پنجره‌های ادمین، اسکریپت باید با دسترسی Administrator اجرا شود."
    }
    ExitApp
}

global SingleInstanceMutex := DllCall(
    "CreateMutex",
    "ptr", 0,
    "int", false,
    "str", "Global\msh_SwapMonitors_ahk",
    "ptr"
)

if (A_LastError = 183) ; ERROR_ALREADY_EXISTS
    ExitApp

SetWinDelay(-1)
SetControlDelay(-1)
SetMouseDelay(-1)

TrayTip "AutoHotkey", "SwapMonitors is running - Ctrl + Shift + Middle Click", 2

; تنظیمات انیمیشن
global FadeSteps := 5
global FadeDelay := 20
global FadeMinAlpha := 185
global HoldAfterMove := 40
global PendingRestore := ""

; Ctrl + Shift + Middle Mouse Button
^+MButton::SwapWindowsBetweenMonitors(1, 2)

SwapWindowsBetweenMonitors(monA := 1, monB := 2) {
    global PendingRestore

    if (MonitorGetCount() < 2) {
        MsgBox "حداقل دو مانیتور لازم است."
        return
    }

    MonitorGetWorkArea(monA, &aL, &aT, &aR, &aB)
    MonitorGetWorkArea(monB, &bL, &bT, &bR, &bB)

    aW := aR - aL
    aH := aB - aT
    bW := bR - bL
    bH := bB - bT

    if IsObject(PendingRestore) {
        restoreMoves := FilterExistingMoves(PendingRestore)
        PendingRestore := ""

        if (restoreMoves.Length > 0) {
            ApplyMoves(restoreMoves)
            return
        }
    }

    moves := []
    restoreMoves := []

    for hwnd in WinGetList() {
        if !IsRealWindow(hwnd)
            continue

        win := "ahk_id " hwnd

        try state := WinGetMinMax(win)
        catch
            continue

        if (state = -1)
            continue

        try WinGetPos(&x, &y, &w, &h, win)
        catch
            continue

        if (w <= 0 || h <= 0)
            continue

        cx := x + w / 2
        cy := y + h / 2

        if PointInRect(cx, cy, aL, aT, aR, aB) {
            dest := CalculateDestination(x, y, w, h, aL, aT, aW, aH, bL, bT, bW, bH)
            targetL := bL
            targetT := bT
            targetR := bR
            targetB := bB
            restoreL := aL
            restoreT := aT
            restoreR := aR
            restoreB := aB
        } else if PointInRect(cx, cy, bL, bT, bR, bB) {
            dest := CalculateDestination(x, y, w, h, bL, bT, bW, bH, aL, aT, aW, aH)
            targetL := aL
            targetT := aT
            targetR := aR
            targetB := aB
            restoreL := bL
            restoreT := bT
            restoreR := bR
            restoreB := bB
        } else {
            continue
        }

        moves.Push({
            hwnd: hwnd,
            state: state,
            x: dest.x,
            y: dest.y,
            w: dest.w,
            h: dest.h,
            dL: targetL,
            dT: targetT,
            dR: targetR,
            dB: targetB
        })

        restoreMoves.Push({
            hwnd: hwnd,
            state: state,
            x: x,
            y: y,
            w: w,
            h: h,
            dL: restoreL,
            dT: restoreT,
            dR: restoreR,
            dB: restoreB
        })
    }

    if (moves.Length = 0)
        return

    PendingRestore := restoreMoves
    ApplyMoves(moves)
}

FilterExistingMoves(moves) {
    activeMoves := []

    for item in moves {
        win := "ahk_id " item.hwnd

        if !WinExist(win)
            continue

        try state := WinGetMinMax(win)
        catch
            continue

        if (state = -1)
            continue

        activeMoves.Push(item)
    }

    return activeMoves
}

ApplyMoves(moves) {
    global HoldAfterMove

    if (moves.Length = 0)
        return

    ; محو نرم قبل از جابه‌جایی
    FadeWindowsOut(moves)

    ; پنجره‌های Maximize شده قبل از WinMove باید Restore شوند.
    for item in moves {
        win := "ahk_id " item.hwnd

        try {
            currentState := WinGetMinMax(win)
            if (currentState = 1)
                WinRestore(win)
        }
    }

    Sleep 25

    ; جابه‌جایی instant، نه تیک‌تیکی
    for item in moves {
        MoveWindowAndKeepInBounds(item)
    }

    Sleep HoldAfterMove

    ; Maximize مجدد پنجره‌هایی که قبلاً Maximize بودند
    for item in moves {
        try {
            if (item.state = 1)
                WinMaximize("ahk_id " item.hwnd)
        }
    }

    Sleep 25

    ; ظاهر شدن نرم بعد از جابه‌جایی
    FadeWindowsIn(moves)
}

MoveWindowAndKeepInBounds(item) {
    win := "ahk_id " item.hwnd

    try WinMove(item.x, item.y, item.w, item.h, win)
    catch
        return

    try {
        dL := item.dL
        dT := item.dT
        dR := item.dR
        dB := item.dB
    } catch {
        return
    }

    ; بعضی پنجره‌ها حداقل اندازه اجباری دارند؛ بعد از Move اندازه واقعی را clamp کن.
    Sleep 10

    try WinGetPos(&x, &y, &w, &h, win)
    catch
        return

    dW := dR - dL
    dH := dB - dT
    nw := Min(w, dW)
    nh := Min(h, dH)
    nx := x
    ny := y

    if (nx < dL)
        nx := dL
    if (nx + nw > dR)
        nx := dR - nw
    if (ny < dT)
        ny := dT
    if (ny + nh > dB)
        ny := dB - nh

    nx := Max(dL, nx)
    ny := Max(dT, ny)

    if (nx != x || ny != y || nw != w || nh != h) {
        try WinMove(nx, ny, nw, nh, win)
    }
}

FadeWindowsOut(moves) {
    global FadeSteps, FadeDelay, FadeMinAlpha

    Loop FadeSteps {
        t := A_Index / FadeSteps
        alpha := Round(255 - ((255 - FadeMinAlpha) * t))

        for item in moves {
            try WinSetTransparent alpha, "ahk_id " item.hwnd
        }

        Sleep FadeDelay
    }
}

FadeWindowsIn(moves) {
    global FadeSteps, FadeDelay, FadeMinAlpha

    Loop FadeSteps {
        t := A_Index / FadeSteps
        alpha := Round(FadeMinAlpha + ((255 - FadeMinAlpha) * t))

        for item in moves {
            try WinSetTransparent alpha, "ahk_id " item.hwnd
        }

        Sleep FadeDelay
    }

    ; برگرداندن شفافیت به حالت طبیعی ویندوز
    for item in moves {
        try WinSetTransparent "Off", "ahk_id " item.hwnd
    }
}

CalculateDestination(x, y, w, h, sL, sT, sW, sH, dL, dT, dW, dH) {
    nx := dL + Round((x - sL) * dW / sW)
    ny := dT + Round((y - sT) * dH / sH)
    nw := Max(200, Round(w * dW / sW))
    nh := Max(150, Round(h * dH / sH))

    nw := Min(nw, dW)
    nh := Min(nh, dH)

    nx := Max(dL, Min(nx, dL + dW - nw))
    ny := Max(dT, Min(ny, dT + dH - nh))

    return {
        x: nx,
        y: ny,
        w: nw,
        h: nh
    }
}

PointInRect(x, y, l, t, r, b) {
    return (x >= l && x < r && y >= t && y < b)
}

IsRealWindow(hwnd) {
    win := "ahk_id " hwnd

    try {
        if !DllCall("IsWindowVisible", "ptr", hwnd)
            return false

        title := WinGetTitle(win)
        class := WinGetClass(win)
        exStyle := WinGetExStyle(win)
        style := WinGetStyle(win)

        ; حذف Desktop و Taskbar
        if (class ~= "^(Progman|WorkerW|Shell_TrayWnd|Shell_SecondaryTrayWnd)$")
            return false

        ; حذف Tool Window ها
        if (exStyle & 0x80)
            return false

        ; باید Visible باشد
        if !(style & 0x10000000)
            return false

        ; حذف پنجره‌های بی‌عنوان و بی‌قاب
        if (title = "" && !(style & 0x00C00000))
            return false

        return true
    } catch {
        return false
    }
}
