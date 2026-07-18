#Requires AutoHotkey v2.0

class AppController {
    __New(rootDir) {
        this.rootDir := rootDir
        this.busy := false
        this.instanceMutex := 0
        this.dpiAware := Win32.EnablePerMonitorDpiV2()
        configPath := rootDir "\config\config.ini"
        examplePath := rootDir "\config\config.example.ini"
        if !FileExist(configPath) && FileExist(examplePath)
            FileCopy(examplePath, configPath, false)
        this.config := ConfigService(configPath)
        this.logger := Logger(rootDir "\logs", this.config.GetBool("General", "EnableLog", true),
            this.config.Get("General", "LogLevel", "INFO"))
        this.monitorService := MonitorService(this.config, this.logger)
        this.windowService := WindowService(this.config, this.logger, this.monitorService)
        this.swapService := SwapService(this.config, this.logger, this.windowService)
        this.animation := AnimationService(this.config, this.logger)
        this.diagnostics := DiagnosticService(rootDir, this.config, this.logger,
            this.monitorService, this.windowService)
    }

    Start() {
        command := this.GetCommand()
        if command != "--diagnose" && command != "--diagnose-quiet"
            && this.config.GetBool("General", "RequireAdmin", true) && !A_IsAdmin {
            this.RelaunchElevated()
            return
        }
        if command = "" {
            alreadyExists := false
            this.instanceMutex := Win32.CreateMutex("Global\msh_DualMonitorWorkspaceSwap", &alreadyExists)
            if alreadyExists {
                TrayTip("Workspace swap is already running.", "SwapMonitors", 2)
                Win32.CloseHandle(this.instanceMutex)
                ExitApp
            }
        }
        if !this.dpiAware
            this.logger.Warn("Per-monitor DPI awareness v2 could not be enabled")
        switch command {
            case "--diagnose", "--diagnose-quiet":
                try {
                    path := this.diagnostics.Run()
                    if command != "--diagnose-quiet"
                        MsgBox("Diagnostic report created:`n" path, "SwapMonitors")
                } catch as err {
                    if command != "--diagnose-quiet"
                        MsgBox("Diagnostic failed:`n" err.Message, "SwapMonitors", "Iconx")
                    else
                        FileAppend("Diagnostic failed: " err.Message "`n", "*")
                }
                ExitApp
            case "--calibrate", "--reset":
                MsgBox("This command is disabled. SwapMonitors only moves windows between monitors.",
                    "SwapMonitors", "Iconi")
                ExitApp
        }
        this.RegisterHotkeys()
        this.logger.Info("SwapMonitors started; hotkey=" this.config.Get("General", "Hotkey"))
        TrayTip("SwapMonitors is running.", "SwapMonitors", 2)
    }

    GetCommand() {
        for arg in A_Args {
            arg := StrLower(arg)
            if arg = "--diagnose" || arg = "--diagnose-quiet" || arg = "--reset" || arg = "--calibrate"
                return arg
        }
        return ""
    }

    RelaunchElevated() {
        arguments := ""
        for arg in A_Args
            arguments .= " " arg
        try Run(Format("*RunAs `"{1}`" /restart `"{2}`"{3}", A_AhkPath, A_ScriptFullPath, arguments))
        catch as err
            MsgBox("Administrator permission is required.`n" err.Message, "SwapMonitors", "Iconx")
        ExitApp
    }

    RegisterHotkeys() {
        Hotkey(this.config.Get("General", "Hotkey", "^+MButton"), ObjBindMethod(this, "Toggle"))
        diagnosticHotkey := this.config.Get("General", "DiagnosticHotkey", "^!+d")
        if diagnosticHotkey != ""
            Hotkey(diagnosticHotkey, ObjBindMethod(this, "RunDiagnostic"))
    }

    Toggle(*) => this.Execute()

    RunDiagnostic(*) {
        try {
            path := this.diagnostics.Run()
            TrayTip("Diagnostic report created.", "SwapMonitors", 2)
        } catch as err {
            this.logger.Error("Diagnostic failed: " err.Message)
            TrayTip("Diagnostic failed.", "SwapMonitors", 3)
        }
    }

    Execute() {
        Critical
        if this.busy {
            TrayTip("Workspace swap is already running.", "SwapMonitors", 2)
            return
        }
        alreadyExists := false
        operationMutex := Win32.CreateMutex("Global\msh_DualMonitorWorkspaceSwap_Operation", &alreadyExists)
        if alreadyExists {
            Win32.CloseHandle(operationMutex)
            TrayTip("Workspace swap is already running.", "SwapMonitors", 2)
            return
        }
        this.busy := true
        Critical("Off")
        operationId := Win32.Timestamp(false, true) "-" Random(1000, 9999)
        started := A_TickCount
        activeWindow := Win32.GetActiveWindow()
        preSnapshot := [], changed := false
        try {
            this.logger.Info("Window-only swap started", operationId)
            this.config.Validate()
            monitorMap := this.monitorService.ResolveConfigured()
            invariants := this.monitorService.InvariantSnapshot()
            this.logger.Info("MonitorA=" monitorMap.a.name "@" monitorMap.a.work.l "," monitorMap.a.work.t
                " MonitorB=" monitorMap.b.name "@" monitorMap.b.work.l "," monitorMap.b.work.t, operationId)
            preSnapshot := this.windowService.Capture(monitorMap)
            this.logger.Info("Pre-operation windows=" preSnapshot.Length, operationId)
            changed := true
            this.swapService.ApplyCurrentSwap(preSnapshot, monitorMap, operationId)
            this.monitorService.VerifyInvariants(invariants)
            try this.animation.PlaySwap(monitorMap)
            catch as animationError
                this.logger.Warn("Swap animation failed: " animationError.Message, operationId)
            message := "Monitor contents swapped successfully."
            this.logger.Info(message " duration=" (A_TickCount - started) "ms", operationId)
            if this.config.GetBool("General", "ShowSuccessNotification", true)
                TrayTip(message, "SwapMonitors", 2)
        } catch as err {
            rollbackText := "not-needed"
            if changed || preSnapshot.Length {
                windowRollback := this.windowService.RestoreSnapshot(preSnapshot)
                rollbackText := "windows=" windowRollback.restored "/failed=" windowRollback.failed
            }
            this.logger.Error("Operation failed: " err.Message " rollback=" rollbackText, operationId)
            if this.config.GetBool("General", "ShowErrorNotification", true)
                TrayTip("Swap failed. Windows were restored.", "SwapMonitors", 3)
        } finally {
            if this.config.GetBool("General", "RestoreActiveWindow", true)
                Win32.RestoreActiveWindow(activeWindow)
            this.busy := false
            Win32.CloseHandle(operationMutex)
        }
    }
}
