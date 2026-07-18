#Requires AutoHotkey v2.0

class WindowService {
    __New(config, logger, monitorService) {
        this.config := config
        this.logger := logger
        this.monitorService := monitorService
        this.excludedProcesses := this.ToLowerMap(config.ReadNumbered("Exclusions", "Process"))
        this.excludedClasses := this.ToLowerMap(config.ReadNumbered("Exclusions", "Class"))
        this.expectedRules := config.ExpectedWindows()
    }

    ToLowerMap(values) {
        result := Map()
        for value in values
            result[StrLower(value)] := true
        return result
    }

    Capture(monitorMap := unset, includeReasons := false) {
        windows := []
        for hwnd in WinGetList() {
            result := this.Inspect(hwnd)
            if !result.eligible {
                if includeReasons
                    windows.Push(result)
                continue
            }
            item := result.window
            if IsSet(monitorMap)
                item.source := this.monitorService.Owner(item.rect, monitorMap)
            windows.Push(item)
        }
        return windows
    }

    Inspect(hwnd) {
        win := "ahk_id " hwnd
        try {
            if !DllCall("IsWindowVisible", "Ptr", hwnd, "Int")
                return {eligible: false, hwnd: hwnd, reason: "not-visible"}
            className := WinGetClass(win)
            processName := WinGetProcessName(win)
            title := WinGetTitle(win)
            if this.excludedClasses.Has(StrLower(className))
                return {eligible: false, hwnd: hwnd, process: processName, class: className, reason: "excluded-class"}
            if this.excludedProcesses.Has(StrLower(processName))
                return {eligible: false, hwnd: hwnd, process: processName, class: className, reason: "excluded-process"}
            if Win32.IsCloaked(hwnd)
                return {eligible: false, hwnd: hwnd, process: processName, class: className, reason: "cloaked"}
            owner := Win32.GetOwner(hwnd)
            exStyle := WinGetExStyle(win)
            if (exStyle & 0x80) && !owner
                return {eligible: false, hwnd: hwnd, process: processName, class: className, reason: "tool-window"}
            style := WinGetStyle(win)
            placement := Win32.GetPlacement(hwnd)
            state := WinGetMinMax(win)
            if state = -1 && !this.config.GetBool("General", "IncludeMinimizedWindows", true)
                return {eligible: false, hwnd: hwnd, process: processName, class: className, reason: "minimized-disabled"}
            if state = 1 && !this.config.GetBool("General", "IncludeMaximizedWindows", true)
                return {eligible: false, hwnd: hwnd, process: processName, class: className, reason: "maximized-disabled"}
            actualRect := Win32.GetRect(hwnd)
            if actualRect.w <= 0 || actualRect.h <= 0
                return {eligible: false, hwnd: hwnd, process: processName, class: className, reason: "invalid-rect"}
            ownershipRect := state = -1 ? placement.normal : actualRect
            fullscreen := this.IsFullscreen(ownershipRect, style)
            ; An untitled borderless window is normally infrastructure/overlay,
            ; but it can also be a legitimate fullscreen application. Desktop
            ; and shell windows have already been filtered by class/process.
            if title = "" && !(style & 0x00C00000) && !fullscreen
                return {eligible: false, hwnd: hwnd, process: processName, class: className, reason: "untitled-borderless"}
            if !this.config.GetBool("General", "IncludeFullscreenWindows", false)
                && fullscreen
                return {eligible: false, hwnd: hwnd, process: processName, class: className, reason: "fullscreen"}
            if !this.config.GetBool("General", "IncludeUnmanagedWindows", true)
                && !this.MatchesExpected(processName, className, title)
                return {eligible: false, hwnd: hwnd, process: processName, class: className, reason: "unmanaged"}
            return {eligible: true, window: {
                hwnd: hwnd, process: processName, class: className, title: title,
                rect: ownershipRect, actualRect: actualRect, placement: placement,
                state: state, minimized: state = -1, maximized: state = 1,
                fullscreen: fullscreen,
                topmost: !!(exStyle & 0x8), owner: owner,
                wasActive: hwnd = Win32.GetActiveWindow()
            }}
        } catch as err {
            return {eligible: false, hwnd: hwnd, reason: "inspect-error:" err.Message}
        }
    }

    IsFullscreen(rect, style) {
        borderless := !(style & 0x00C00000)
        if !borderless
            return false
        Loop MonitorGetCount() {
            MonitorGet(A_Index, &l, &t, &r, &b)
            if Abs(rect.l - l) <= 2 && Abs(rect.t - t) <= 2
                && Abs(rect.r - r) <= 2 && Abs(rect.b - b) <= 2
                return true
        }
        return false
    }

    MatchesExpected(processName, className, title) {
        for rule in this.expectedRules {
            if rule.process != "" && StrLower(rule.process) != StrLower(processName)
                continue
            if rule.class != "" && StrLower(rule.class) != StrLower(className)
                continue
            if rule.title != "" && !InStr(title, rule.title)
                continue
            return true
        }
        return false
    }

    ExpectedPresent(snapshot) {
        for rule in this.expectedRules {
            found := false
            for item in snapshot {
                if StrLower(rule.process) = StrLower(item.process)
                    && (rule.class = "" || StrLower(rule.class) = StrLower(item.class))
                    && (rule.title = "" || InStr(item.title, rule.title)) {
                    found := true
                    break
                }
            }
            if !found
                return false
        }
        return true
    }

    IsStable(previous, current, tolerance) {
        if !IsObject(previous) || previous.Length != current.Length
            return false
        lookup := Map()
        for item in previous
            lookup[String(item.hwnd)] := item
        for item in current {
            key := String(item.hwnd)
            if !lookup.Has(key)
                return false
            old := lookup[key]
            if old.state != item.state || !GeometryService.WithinTolerance(old.rect, item.rect, tolerance)
                return false
        }
        return true
    }

    Fingerprint(snapshot) {
        value := "count=" snapshot.Length
        for item in snapshot
            value .= ";" item.hwnd ":" item.rect.l "," item.rect.t "," item.rect.w "," item.rect.h ":" item.state
        return value
    }

    BuildSwapPlan(snapshot, monitorMap) {
        plan := []
        lookup := Map()
        for item in snapshot
            lookup[String(item.hwnd)] := item
        for item in snapshot {
            source := item.source
            if item.owner && lookup.Has(String(item.owner))
                source := lookup[String(item.owner)].source
            if source.index = monitorMap.a.index
                destination := monitorMap.b
            else if source.index = monitorMap.b.index
                destination := monitorMap.a
            else
                continue
            if item.fullscreen {
                ; Keep borderless fullscreen mode intact and move it directly
                ; to the complete bounds of the other display. Restoring an F11
                ; or borderless app first lets the app snap back to its old monitor.
                target := destination.bounds
            } else {
                baseRect := item.state = 0 ? item.rect : item.placement.normal
                target := GeometryService.MapRect(baseRect, source.work, destination.work)
            }
            plan.Push({window: item, source: source, destination: destination,
                target: target, applied: false})
        }
        return plan
    }

    ApplyPlan(plan, useAtomic := true) {
        movable := [], minimized := [], restoreFirst := [], remaximize := []
        for item in plan {
            if item.window.state = -1 {
                minimized.Push(item)
                continue
            }
            movable.Push(item)
            if item.window.maximized && !item.window.fullscreen
                restoreFirst.Push(item)
            if item.window.maximized && !item.window.fullscreen
                remaximize.Push(item)
        }

        ; Maximized windows must leave their display state before SetWindowPos.
        ; Fullscreen windows deliberately stay fullscreen and move by bounds.
        for item in restoreFirst {
            if WinExist("ahk_id " item.window.hwnd)
                DllCall("ShowWindow", "Ptr", item.window.hwnd, "Int", 9, "Int") ; SW_RESTORE
        }
        if restoreFirst.Length
            Sleep(100)

        failures := 0
        if useAtomic && movable.Length > 0 {
            hdwp := DllCall("BeginDeferWindowPos", "Int", movable.Length, "Ptr")
            if hdwp {
                flags := Win32.SWP_NOZORDER | Win32.SWP_NOACTIVATE | Win32.SWP_NOOWNERZORDER | Win32.SWP_NOSENDCHANGING
                for item in movable {
                    itemFlags := flags | (item.window.fullscreen ? Win32.SWP_FRAMECHANGED : 0)
                    next := DllCall("DeferWindowPos", "Ptr", hdwp, "Ptr", item.window.hwnd, "Ptr", 0,
                        "Int", item.target.l, "Int", item.target.t, "Int", item.target.w, "Int", item.target.h,
                        "UInt", itemFlags, "Ptr")
                    if !next {
                        hdwp := 0
                        break
                    }
                    hdwp := next
                }
                if hdwp && DllCall("EndDeferWindowPos", "Ptr", hdwp, "Int") {
                    for item in movable
                        item.applied := true
                } else {
                    for item in movable {
                        item.applied := Win32.SetRect(item.window.hwnd, item.target, item.window.fullscreen)
                        if !item.applied
                            failures += 1
                    }
                }
            }
        }
        if !useAtomic || (movable.Length > 0 && !movable[1].applied) {
            for item in movable {
                if item.applied
                    continue
                item.applied := Win32.SetRect(item.window.hwnd, item.target, item.window.fullscreen)
                if !item.applied
                    failures += 1
            }
        }

        for item in remaximize {
            if item.applied && WinExist("ahk_id " item.window.hwnd)
                DllCall("ShowWindow", "Ptr", item.window.hwnd, "Int", 3, "Int") ; SW_MAXIMIZE
        }

        for item in minimized {
            if !WinExist("ahk_id " item.window.hwnd) {
                failures += 1
                continue
            }
            item.applied := Win32.SetPlacement(item.window.hwnd, item.window.placement,
                item.target, item.window.placement.showCmd)
            if !item.applied
                failures += 1
        }
        ; Retry only if at least one live window rejected its first move. The
        ; normal successful path remains delay-free.
        needsRetry := false
        for item in plan {
            if !item.applied && WinExist("ahk_id " item.window.hwnd) {
                needsRetry := true
                break
            }
        }
        if needsRetry
            Sleep(60)
        failures := 0, moved := 0, skipped := 0
        for item in plan {
            if !item.applied {
                if !WinExist("ahk_id " item.window.hwnd) {
                    skipped += 1
                    continue
                }
                if item.window.state = -1 {
                    item.applied := Win32.SetPlacement(item.window.hwnd, item.window.placement,
                        item.target, item.window.placement.showCmd)
                } else {
                    if item.window.maximized && !item.window.fullscreen
                        DllCall("ShowWindow", "Ptr", item.window.hwnd, "Int", 9, "Int")
                    item.applied := Win32.SetRect(item.window.hwnd, item.target, item.window.fullscreen)
                    if item.applied && item.window.maximized && !item.window.fullscreen
                        DllCall("ShowWindow", "Ptr", item.window.hwnd, "Int", 3, "Int")
                }
            }
            if item.applied
                moved += 1
            else {
                failures += 1
                this.logger.Warn("Window rejected move hwnd=" item.window.hwnd
                    " process=" item.window.process " state=" item.window.state)
            }
        }
        return {moved: moved, failed: failures, skipped: skipped}
    }

    VerifyPlan(plan, tolerance) {
        failures := []
        for item in plan {
            if !item.applied
                continue
            if !WinExist("ahk_id " item.window.hwnd)
                continue
            try {
                actual := (item.window.fullscreen || item.window.state = 0) ? Win32.GetRect(item.window.hwnd)
                    : Win32.GetPlacement(item.window.hwnd).normal
                if !GeometryService.WithinTolerance(actual, item.target, tolerance)
                    failures.Push(item.window.hwnd)
            } catch {
                failures.Push(item.window.hwnd)
            }
        }
        if failures.Length
            throw Error("Window geometry verification failed for " failures.Length " window(s)")
        return true
    }

    RestoreSnapshot(snapshot) {
        restored := 0, failed := 0
        for item in snapshot {
            if !WinExist("ahk_id " item.hwnd)
                continue
            try {
                if item.fullscreen
                    ok := Win32.SetRect(item.hwnd, item.actualRect, true)
                else if item.state = 0
                    ok := Win32.SetRect(item.hwnd, item.rect)
                else if item.state = -1
                    ok := Win32.SetPlacement(item.hwnd, item.placement, item.placement.normal, item.placement.showCmd)
                else {
                    DllCall("ShowWindow", "Ptr", item.hwnd, "Int", 9, "Int")
                    ok := Win32.SetRect(item.hwnd, item.placement.normal)
                    if ok
                        DllCall("ShowWindow", "Ptr", item.hwnd, "Int", 3, "Int")
                }
                ok ? restored += 1 : failed += 1
            } catch {
                failed += 1
            }
        }
        return {restored: restored, failed: failed}
    }
}
