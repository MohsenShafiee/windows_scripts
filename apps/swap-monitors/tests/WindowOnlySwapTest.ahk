#Requires AutoHotkey v2.0

#Include "..\src\SwapService.ahk"

Assert(condition, message) {
    if !condition
        throw Error(message)
}

class TestConfig {
    GetBool(section, key, default := false) => false
    GetInt(section, key, default := 0) => default
}

class TestLogger {
    Info(*) {
    }

    Warn(*) {
    }
}

class TestWindows {
    __New() {
        this.verified := false
    }

    BuildSwapPlan(snapshot, monitorMap) => [{window: snapshot[1], monitorMap: monitorMap}]

    ApplyPlan(plan, useAtomic) => {moved: plan.Length, failed: 0, skipped: 0}

    VerifyPlan(plan, tolerance) {
        this.verified := plan.Length = 1
        return this.verified
    }
}

windows := TestWindows()
service := SwapService(TestConfig(), TestLogger(), windows)
plan := service.ApplyCurrentSwap([{hwnd: 1}], {a: {index: 1}, b: {index: 2}}, "test")

Assert(plan.Length = 1, "Window swap plan was not returned")
Assert(windows.verified, "Window swap plan was not verified")
FileAppend("Window-only swap test passed.`n", "*")
