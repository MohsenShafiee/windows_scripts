#Requires AutoHotkey v2.0
#SingleInstance Ignore

TrayTip "AutoHotkey", "Max/Restore is running - Ctrl + Middle Click", 3

global SavedWindows := Map()

; Ctrl + Middle Click
; اگر Shift پایین باشد کاری نمی‌کند تا با Ctrl+Shift+Middle اسکریپت SwapMonitors تداخل نداشته باشد
#HotIf !GetKeyState("Shift", "P")
^MButton::ToggleMaxRestoreUnderMouse()
#HotIf

ToggleMaxRestoreUnderMouse() {
    global SavedWindows

    MouseGetPos(, , &hwnd)

    if !hwnd
        return

    win := "ahk_id " hwnd

    if !IsRealWindow(hwnd)
        return

    try {
        state := WinGetMinMax(win)

        ; اگر پنجره Minimize است، اول Restore کن
        if (state = -1) {
            WinRestore(win)
            Sleep 50
        }

        ; اگر الان Maximize است، برگردان به حالت قبلی
        if (state = 1) {
            WinRestore(win)
            Sleep 50

            if SavedWindows.Has(hwnd) {
                data := SavedWindows[hwnd]
                WinMove(data.x, data.y, data.w, data.h, win)
                SavedWindows.Delete(hwnd)
            }

            BringWindowToFront(hwnd)

            ToolTip "Restored"
            SetTimer () => ToolTip(), -800
            return
        }

        ; اگر Maximize نیست، وضعیت فعلی را ذخیره کن
        WinGetPos(&x, &y, &w, &h, win)

        SavedWindows[hwnd] := {
            x: x,
            y: y,
            w: w,
            h: h
        }

        ; بیاورد روی بقیه پنجره‌ها
        BringWindowToFront(hwnd)

        ; بعد Maximize کند
        WinMaximize(win)
        Sleep 50

        ; دوباره بیاورد جلو، چون بعضی برنامه‌ها بعد از Maximize فوکوس را پس می‌زنند
        BringWindowToFront(hwnd)

        ToolTip "Maximized"
        SetTimer () => ToolTip(), -800

    } catch {
        ; خطاهای پنجره‌های خاص/سیستمی نادیده گرفته می‌شود
    }
}

BringWindowToFront(hwnd) {
    win := "ahk_id " hwnd

    try {
        exStyle := WinGetExStyle(win)
        wasTopMost := exStyle & 0x8

        WinActivate(win)
        DllCall("SetForegroundWindow", "ptr", hwnd)
        DllCall("BringWindowToTop", "ptr", hwnd)

        ; برای آوردن قطعی روی بقیه پنجره‌ها، موقتاً TopMost می‌کند و برمی‌گرداند
        if !wasTopMost {
            WinSetAlwaysOnTop true, win
            Sleep 40
            WinSetAlwaysOnTop false, win
        }
    } catch {
    }
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

        ; حذف دسکتاپ و تسک‌بار
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
