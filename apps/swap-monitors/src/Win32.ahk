#Requires AutoHotkey v2.0

class Win32 {
    static ERROR_ALREADY_EXISTS := 183
    static SWP_NOZORDER := 0x0004
    static SWP_NOACTIVATE := 0x0010
    static SWP_NOOWNERZORDER := 0x0200
    static SWP_NOSENDCHANGING := 0x0400
    static SWP_FRAMECHANGED := 0x0020

    static EnablePerMonitorDpiV2() {
        try {
            if DllCall("User32\SetProcessDpiAwarenessContext", "Ptr", -4, "Int")
                return true
            if A_LastError = 5 ; awareness was already selected by the AHK host
                return true
            context := DllCall("User32\GetThreadDpiAwarenessContext", "Ptr")
            awareness := DllCall("User32\GetAwarenessFromDpiAwarenessContext", "Ptr", context, "Int")
            return awareness >= 2
        } catch {
            return false
        }
    }

    static CreateMutex(name, &alreadyExists := false) {
        handle := DllCall("CreateMutex", "Ptr", 0, "Int", false, "Str", name, "Ptr")
        alreadyExists := (A_LastError = this.ERROR_ALREADY_EXISTS)
        return handle
    }

    static CloseHandle(handle) {
        if handle
            DllCall("CloseHandle", "Ptr", handle)
    }

    static GetRect(hwnd) {
        rect := Buffer(16, 0)
        if !DllCall("GetWindowRect", "Ptr", hwnd, "Ptr", rect, "Int")
            throw OSError(A_LastError, "GetWindowRect failed")
        return this.RectFromBuffer(rect, 0)
    }

    static RectFromBuffer(buffer, offset) {
        l := NumGet(buffer, offset, "Int")
        t := NumGet(buffer, offset + 4, "Int")
        r := NumGet(buffer, offset + 8, "Int")
        b := NumGet(buffer, offset + 12, "Int")
        return {l: l, t: t, r: r, b: b, x: l, y: t, w: r - l, h: b - t}
    }

    static PutRect(buffer, offset, rect) {
        NumPut("Int", rect.l, buffer, offset)
        NumPut("Int", rect.t, buffer, offset + 4)
        NumPut("Int", rect.r, buffer, offset + 8)
        NumPut("Int", rect.b, buffer, offset + 12)
    }

    static SetRect(hwnd, rect, frameChanged := false) {
        flags := this.SWP_NOZORDER | this.SWP_NOACTIVATE | this.SWP_NOOWNERZORDER | this.SWP_NOSENDCHANGING
        if frameChanged
            flags |= this.SWP_FRAMECHANGED
        return !!DllCall("SetWindowPos", "Ptr", hwnd, "Ptr", 0, "Int", rect.l, "Int", rect.t,
            "Int", rect.w, "Int", rect.h, "UInt", flags, "Int")
    }

    static GetPlacement(hwnd) {
        placement := Buffer(44, 0)
        NumPut("UInt", 44, placement, 0)
        if !DllCall("GetWindowPlacement", "Ptr", hwnd, "Ptr", placement, "Int")
            throw OSError(A_LastError, "GetWindowPlacement failed")
        return {
            flags: NumGet(placement, 4, "UInt"),
            showCmd: NumGet(placement, 8, "UInt"),
            minX: NumGet(placement, 12, "Int"), minY: NumGet(placement, 16, "Int"),
            maxX: NumGet(placement, 20, "Int"), maxY: NumGet(placement, 24, "Int"),
            normal: this.RectFromBuffer(placement, 28)
        }
    }

    static SetPlacement(hwnd, source, normalRect := unset, showCmd := unset) {
        placement := Buffer(44, 0)
        NumPut("UInt", 44, placement, 0)
        NumPut("UInt", source.flags, placement, 4)
        NumPut("UInt", IsSet(showCmd) ? showCmd : source.showCmd, placement, 8)
        NumPut("Int", source.minX, placement, 12)
        NumPut("Int", source.minY, placement, 16)
        NumPut("Int", source.maxX, placement, 20)
        NumPut("Int", source.maxY, placement, 24)
        this.PutRect(placement, 28, IsSet(normalRect) ? normalRect : source.normal)
        return !!DllCall("SetWindowPlacement", "Ptr", hwnd, "Ptr", placement, "Int")
    }

    static IsCloaked(hwnd) {
        cloaked := 0
        try {
            hr := DllCall("Dwmapi\DwmGetWindowAttribute", "Ptr", hwnd, "UInt", 14,
                "UInt*", &cloaked, "UInt", 4, "Int")
            return (hr = 0 && cloaked != 0)
        } catch {
            return false
        }
    }

    static GetOwner(hwnd) => DllCall("GetWindow", "Ptr", hwnd, "UInt", 4, "Ptr")
    static GetActiveWindow() => DllCall("GetForegroundWindow", "Ptr")

    static RestoreActiveWindow(hwnd) {
        if hwnd && WinExist("ahk_id " hwnd) {
            try WinActivate("ahk_id " hwnd)
        }
    }

    static GetDpiAt(x, y) {
        point := ((y & 0xFFFFFFFF) << 32) | (x & 0xFFFFFFFF)
        hmon := DllCall("MonitorFromPoint", "Int64", point, "UInt", 2, "Ptr")
        dpiX := 96, dpiY := 96
        try {
            hr := DllCall("Shcore\GetDpiForMonitor", "Ptr", hmon, "Int", 0,
                "UInt*", &dpiX, "UInt*", &dpiY, "Int")
            if (hr != 0)
                dpiX := 96
        }
        return dpiX
    }

    static Timestamp(utc := false, compact := false) {
        value := Buffer(16, 0)
        DllCall(utc ? "GetSystemTime" : "GetLocalTime", "Ptr", value)
        year := NumGet(value, 0, "UShort"), month := NumGet(value, 2, "UShort")
        day := NumGet(value, 6, "UShort"), hour := NumGet(value, 8, "UShort")
        minute := NumGet(value, 10, "UShort"), second := NumGet(value, 12, "UShort")
        if compact
            return Format("{:04}{:02}{:02}-{:02}{:02}{:02}", year, month, day, hour, minute, second)
        return Format("{:04}-{:02}-{:02}T{:02}:{:02}:{:02}", year, month, day, hour, minute, second)
    }
}
