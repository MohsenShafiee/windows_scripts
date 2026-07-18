#Requires AutoHotkey v2.0

class MonitorService {
    __New(config, logger) {
        this.config := config
        this.logger := logger
    }

    Enumerate() {
        monitors := []
        primary := MonitorGetPrimary()
        Loop MonitorGetCount() {
            index := A_Index
            MonitorGet(index, &l, &t, &r, &b)
            MonitorGetWorkArea(index, &wl, &wt, &wr, &wb)
            name := MonitorGetName(index)
            dpi := Win32.GetDpiAt(l + Floor((r - l) / 2), t + Floor((b - t) / 2))
            monitors.Push({index: index, name: name,
                bounds: {l: l, t: t, r: r, b: b, x: l, y: t, w: r - l, h: b - t},
                work: {l: wl, t: wt, r: wr, b: wb, x: wl, y: wt, w: wr - wl, h: wb - wt},
                dpi: dpi, scale: Round(dpi * 100 / 96), primary: index = primary})
        }
        return monitors
    }

    ResolveConfigured() {
        monitors := this.Enumerate()
        if this.config.GetBool("General", "RequireExactlyTwoMonitors", true) && monitors.Length != 2
            throw Error("Exactly two monitors are required; found " monitors.Length)
        a := this.FindByName(monitors, this.config.Get("MonitorA", "DeviceName"))
        b := this.FindByName(monitors, this.config.Get("MonitorB", "DeviceName"))
        if !IsObject(a) || !IsObject(b) || a.index = b.index
            throw Error("Configured MonitorA/MonitorB could not be resolved unambiguously")
        return {a: a, b: b, all: monitors}
    }

    FindByName(monitors, name) {
        name := StrLower(Trim(name))
        for monitor in monitors {
            if StrLower(monitor.name) = name
                return monitor
        }
        return false
    }

    Owner(rect, monitorMap) {
        areaA := GeometryService.IntersectionArea(rect, monitorMap.a.work)
        areaB := GeometryService.IntersectionArea(rect, monitorMap.b.work)
        if areaA > areaB
            return monitorMap.a
        if areaB > areaA
            return monitorMap.b
        cx := rect.l + rect.w / 2, cy := rect.t + rect.h / 2
        if GeometryService.PointInRect(cx, cy, monitorMap.a.work)
            return monitorMap.a
        if GeometryService.PointInRect(cx, cy, monitorMap.b.work)
            return monitorMap.b
        return this.Nearest(cx, cy, monitorMap)
    }

    Nearest(x, y, monitorMap) {
        best := false, bestDistance := 0
        for monitor in [monitorMap.a, monitorMap.b] {
            cx := Max(monitor.work.l, Min(x, monitor.work.r))
            cy := Max(monitor.work.t, Min(y, monitor.work.b))
            distance := (x - cx) ** 2 + (y - cy) ** 2
            if !IsObject(best) || distance < bestDistance
                best := monitor, bestDistance := distance
        }
        return best
    }

    InvariantSnapshot() {
        primary := MonitorGetName(MonitorGetPrimary())
        taskbars := []
        for className in ["Shell_TrayWnd", "Shell_SecondaryTrayWnd"] {
            for hwnd in WinGetList("ahk_class " className) {
                try taskbars.Push(className ":" this.RectKey(Win32.GetRect(hwnd)))
            }
        }
        return {count: MonitorGetCount(), primary: primary, taskbars: taskbars}
    }

    VerifyInvariants(before) {
        after := this.InvariantSnapshot()
        if before.count != after.count
            throw Error("Monitor count changed during operation")
        if StrLower(before.primary) != StrLower(after.primary)
            throw Error("Primary monitor changed during operation")
        if before.taskbars.Length != after.taskbars.Length
            throw Error("Taskbar count changed during operation")
        Loop before.taskbars.Length {
            if before.taskbars[A_Index] != after.taskbars[A_Index]
                throw Error("Taskbar rectangle changed during operation")
        }
        return true
    }

    RectKey(rect) => rect.l "," rect.t "," rect.r "," rect.b
}
