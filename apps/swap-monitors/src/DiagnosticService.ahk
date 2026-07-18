#Requires AutoHotkey v2.0

class DiagnosticService {
    __New(rootDir, config, logger, monitorService, windowService) {
        this.rootDir := rootDir
        this.config := config
        this.logger := logger
        this.monitors := monitorService
        this.windows := windowService
    }

    Run() {
        logDir := this.rootDir "\logs"
        DirCreate(logDir)
        path := logDir "\diagnostic-" Win32.Timestamp(false, true) ".txt"
        lines := []
        lines.Push("Dual Monitor Window Swap diagnostic")
        lines.Push("Generated: " StrReplace(Win32.Timestamp(), "T", " "))
        lines.Push("AutoHotkey: " A_AhkVersion)
        lines.Push("Administrator: " (A_IsAdmin ? "yes" : "no"))
        try {
            this.config.Validate()
            lines.Push("Config validation: ok")
        } catch as err {
            lines.Push("Config validation error: " err.Message)
        }
        lines.Push("")
        lines.Push("Monitors:")
        for monitor in this.monitors.Enumerate() {
            lines.Push(Format("  #{1} {2} bounds={3},{4},{5}x{6} work={7},{8},{9}x{10} dpi={11} scale={12}% primary={13}",
                monitor.index, monitor.name, monitor.bounds.l, monitor.bounds.t, monitor.bounds.w, monitor.bounds.h,
                monitor.work.l, monitor.work.t, monitor.work.w, monitor.work.h, monitor.dpi, monitor.scale,
                monitor.primary ? "yes" : "no"))
        }
        try {
            configured := this.monitors.ResolveConfigured()
            lines.Push("Configured A: " configured.a.name)
            lines.Push("Configured B: " configured.b.name)
            currentWindows := this.windows.Capture(configured)
            movePlan := this.windows.BuildSwapPlan(currentWindows, configured)
            lines.Push("Current swap plan windows: " movePlan.Length)
        } catch as err {
            lines.Push("Configured monitor error: " err.Message)
        }
        lines.Push("")
        lines.Push("Top-level windows:")
        for item in this.windows.Capture(, true) {
            if item.HasOwnProp("eligible") {
                lines.Push("  hwnd=" item.hwnd " excluded=" item.reason)
            } else {
                title := this.config.Get("General", "LogLevel", "INFO") = "DEBUG" ? item.title : "<hidden>"
                lines.Push(Format("  hwnd={1} process={2} class={3} state={4} rect={5},{6},{7}x{8} title={9}",
                    item.hwnd, item.process, item.class, item.state, item.rect.l, item.rect.t,
                    item.rect.w, item.rect.h, title))
            }
        }
        FileAppend(this.Join(lines, "`r`n") "`r`n", path, "UTF-8")
        this.logger.Info("Diagnostic report written: " path)
        return path
    }

    Join(values, delimiter) {
        result := ""
        for value in values
            result .= (result = "" ? "" : delimiter) value
        return result
    }
}
