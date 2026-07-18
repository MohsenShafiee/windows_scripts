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
global SwapBusy := false

; Ctrl + Shift + Middle Mouse Button
^+MButton::ResetDefaultWorkspaceThenSwap(1, 2)

ResetDefaultWorkspaceThenSwap(monA := 1, monB := 2) {
    global SwapBusy

    if SwapBusy
        return

    SwapBusy := true

    try {
        ; ابتدا workspace پیش‌فرض را برگردان و بعد همهٔ پنجره‌ها را، به‌جز
        ; Desktop و Taskbar، بین دو مانیتور جابه‌جا کن.
        ApplyDefaultWorkspaceLayout()
        Sleep 50
        SwapWindowsBetweenMonitors(monA, monB)
    } finally {
        SwapBusy := false
    }
}

ApplyDefaultWorkspaceLayout() {
    rules := [
        { process: "explorer.exe",        title: "",                                      class: "CabinetWClass", all: true,  x: -2,   y: 5,   w: 1425, h: 413  },
        { process: "ChatGPT Classic.exe", title: "ChatGPT Classic",                       class: "",              all: false, x: -2,   y: 415, w: 552,  h: 619  },
        { process: "ChatGPT.exe",         title: "ChatGPT",                               class: "",              all: false, x: 547,  y: 415, w: 869,  h: 612  },
        { process: "cmd.exe",             title: "Administrator: Windows Command Center", class: "",              all: false, x: 1413, y: 5,   w: 509,  h: 498  },
        { process: "WindowsTerminal.exe", title: "Administrator: PowerShell",             class: "",              all: false, x: 1413, y: 500, w: 509,  h: 534  },
        { process: "chrome.exe",          title: "",                                      class: "",              all: true,  x: 1918, y: 5,   w: 1413, h: 1029 },
        { process: "Telegram.exe",        title: "",                                      class: "",              all: true,  x: 3321, y: 5,   w: 521,  h: 846  },
        { process: "PotPlayerMini64.exe", title: "",                                      class: "",              all: true,  x: 3328, y: 848, w: 507,  h: 179  }
    ]

    windows := WinGetList()
    for rule in rules
        MoveMatchingWindows(windows, rule)
}

MoveMatchingWindows(windows, rule) {
    for hwnd in windows {
        if !IsRealWindow(hwnd)
            continue

        win := "ahk_id " hwnd

        try processName := WinGetProcessName(win)
        catch
            continue

        if (StrLower(processName) != StrLower(rule.process))
            continue

        if (rule.class != "") {
            try windowClass := WinGetClass(win)
            catch
                continue

            if (windowClass != rule.class)
                continue
        }

        if (rule.title != "") {
            try windowTitle := WinGetTitle(win)
            catch
                continue

            if (windowTitle != rule.title)
                continue
        }

        MoveWindowExact(hwnd, rule.x, rule.y, rule.w, rule.h)

        if !rule.all
            break
    }
}

MoveWindowExact(hwnd, x, y, w, h) {
    win := "ahk_id " hwnd

    try state := WinGetMinMax(win)
    catch
        return

    if (state != 0) {
        try WinRestore(win)
    }

    ; SWP_NOZORDER | SWP_NOACTIVATE: بدون تغییر Focus و ترتیب پنجره‌ها.
    DllCall(
        "SetWindowPos",
        "ptr", hwnd,
        "ptr", 0,
        "int", x,
        "int", y,
        "int", w,
        "int", h,
        "uint", 0x0014
    )
}

SwapWindowsBetweenMonitors(monA := 1, monB := 2) {
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

    moves := []

    for hwnd in WinGetList() {
        if !IsRealWindow(hwnd)
            continue

        win := "ahk_id " hwnd

        try state := WinGetMinMax(win)
        catch
            continue

        if (state = -1)
            continue

        if !GetWindowRectExact(hwnd, &x, &y, &w, &h)
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
        } else if PointInRect(cx, cy, bL, bT, bR, bB) {
            dest := CalculateDestination(x, y, w, h, bL, bT, bW, bH, aL, aT, aW, aH)
            targetL := aL
            targetT := aT
            targetR := aR
            targetB := aB
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

    }

    if (moves.Length = 0)
        return

    ApplyMoves(moves)
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

    if !SetWindowRectExact(item.hwnd, item.x, item.y, item.w, item.h)
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

    if !GetWindowRectExact(item.hwnd, &x, &y, &w, &h)
        return

    dW := dR - dL
    dH := dB - dT
    nw := Min(w, dW)
    nh := Min(h, dH)
    nx := x
    ny := y

    ; Windows keeps a small invisible resize border outside the work area.
    ; Preserve it so a round trip returns to the exact original rectangle.
    borderSlack := 16

    if (nx < dL - borderSlack)
        nx := dL - borderSlack
    if (nx + nw > dR + borderSlack)
        nx := dR + borderSlack - nw
    if (ny < dT - borderSlack)
        ny := dT - borderSlack
    if (ny + nh > dB + borderSlack)
        ny := dB + borderSlack - nh

    nx := Max(dL - borderSlack, nx)
    ny := Max(dT - borderSlack, ny)

    if (nx != x || ny != y || nw != w || nh != h) {
        SetWindowRectExact(item.hwnd, nx, ny, nw, nh)
    }
}

GetWindowRectExact(hwnd, &x, &y, &w, &h) {
    rect := Buffer(16, 0)

    if !DllCall("GetWindowRect", "ptr", hwnd, "ptr", rect, "int")
        return false

    x := NumGet(rect, 0, "int")
    y := NumGet(rect, 4, "int")
    w := NumGet(rect, 8, "int") - x
    h := NumGet(rect, 12, "int") - y
    return (w > 0 && h > 0)
}

SetWindowRectExact(hwnd, x, y, w, h) {
    ; SWP_NOZORDER | SWP_NOACTIVATE
    return DllCall(
        "SetWindowPos",
        "ptr", hwnd,
        "ptr", 0,
        "int", x,
        "int", y,
        "int", w,
        "int", h,
        "uint", 0x0014,
        "int"
    )
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
    ; Equal-sized monitors need only a translation. Avoid scaling/clamping so
    ; invisible resize borders and exact window sizes survive a round trip.
    if (sW = dW && sH = dH) {
        return {
            x: x + dL - sL,
            y: y + dT - sT,
            w: w,
            h: h
        }
    }

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
