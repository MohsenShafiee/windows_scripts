#Requires AutoHotkey v2.0

class WorkspaceService {
    __New(config, logger, windowService) {
        this.config := config
        this.logger := logger
        this.windowService := windowService
    }

    Normalize(operationId := "-") {
        shortcut := this.config.ResolvePath(this.config.Get("General", "WorkspaceShortcut"))
        if !FileExist(shortcut)
            throw Error("Workspace shortcut not found: " shortcut)
        this.logger.Info("Launching canonical PowerToys Workspace shortcut", operationId)
        try Run(shortcut)
        catch as err
            throw Error("Could not launch Workspace shortcut: " err.Message)
        return this.WaitUntilStable(operationId)
    }

    WaitUntilStable(operationId := "-") {
        timeout := this.config.GetInt("General", "WorkspaceSettleTimeoutMs", 12000)
        required := this.config.GetInt("General", "WorkspaceStableSamples", 4)
        interval := this.config.GetInt("General", "WorkspaceSampleIntervalMs", 250)
        tolerance := this.config.GetInt("General", "GeometryTolerancePx", 5)
        minimum := this.config.GetInt("General", "WorkspaceMinimumSettleMs", 1500)
        started := A_TickCount
        previous := false, stable := 0
        while A_TickCount - started <= timeout {
            current := this.windowService.Capture()
            if A_TickCount - started >= minimum
                && this.windowService.IsStable(previous, current, tolerance)
                && this.windowService.ExpectedPresent(current)
                stable += 1
            else
                stable := 0
            if stable >= required {
                duration := A_TickCount - started
                this.logger.Info("Workspace stable after " duration "ms; windows=" current.Length, operationId)
                return current
            }
            previous := current
            Sleep(interval)
        }
        throw Error("Workspace did not become stable within " timeout "ms")
    }
}
