#Requires AutoHotkey v2.0
#SingleInstance Force

#Include "..\src\Win32.ahk"
#Include "..\src\GeometryService.ahk"
#Include "..\src\MonitorService.ahk"
#Include "..\src\WindowService.ahk"

SetWinDelay(-1)

Assert(condition, message) {
    if !condition
        throw Error(message)
}

class TestConfig {
    ReadNumbered(*) => []
    ExpectedWindows() => []
    GetBool(section, key, default := false) => key = "IncludeFullscreenWindows"
        || key = "IncludeUnmanagedWindows" || key = "IncludeMinimizedWindows"
        || key = "IncludeMaximizedWindows"
}

class TestLogger {
    Warn(*) {
    }
}

logger := TestLogger()
monSvc := MonitorService(TestConfig(), logger)
monitors := monSvc.Enumerate()
if monitors.Length < 2 {
    FileAppend("Fullscreen integration test skipped: two monitors are required.`n", "*")
    ExitApp
}

monitorMap := {a: monitors[1], b: monitors[2], all: monitors}
testWindow := Gui("-Caption", "SwapMonitors fullscreen integration test")
testWindow.BackColor := "202020"
source := monitorMap.a.bounds
testWindow.Show("NA x" source.l " y" source.t " w" source.w " h" source.h)
Sleep(100)

try {
    hwnd := testWindow.Hwnd
    inspected := WindowService(TestConfig(), logger, monSvc).Inspect(hwnd)
    if !inspected.eligible
        throw Error("Fullscreen test window was not eligible: " inspected.reason)
    Assert(inspected.window.fullscreen, "Borderless monitor-sized window was not detected as fullscreen")
    inspected.window.source := monitorMap.a

    service := WindowService(TestConfig(), logger, monSvc)
    plan := service.BuildSwapPlan([inspected.window], monitorMap)
    Assert(plan.Length = 1, "Fullscreen swap plan was not created")
    Assert(GeometryService.WithinTolerance(plan[1].target, monitorMap.b.bounds, 0),
        "Fullscreen target is not the destination monitor bounds")

    result := service.ApplyPlan(plan, false)
    Assert(result.moved = 1 && result.failed = 0, "Fullscreen window move failed")
    service.VerifyPlan(plan, 2)
    service.RestoreSnapshot([inspected.window])
    FileAppend("Fullscreen integration test passed.`n", "*")
} finally {
    testWindow.Destroy()
}
ExitApp(0)
