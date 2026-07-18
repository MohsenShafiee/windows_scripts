#Requires AutoHotkey v2.0

class FancyZonesService {
    __New(config, logger) {
        this.config := config
        this.logger := logger
        this.path := ""
    }

    Discover() {
        configured := this.config.ResolvePath(this.config.Get("General", "FancyZonesCliPath", "AUTO"))
        candidates := []
        if configured != "" && StrUpper(configured) != "AUTO"
            candidates.Push(configured)
        localAppData := EnvGet("LOCALAPPDATA")
        programFiles := EnvGet("ProgramFiles")
        candidates.Push(localAppData "\PowerToys\FancyZonesCLI.exe")
        candidates.Push(localAppData "\Microsoft\PowerToys\FancyZonesCLI.exe")
        candidates.Push(programFiles "\PowerToys\FancyZonesCLI.exe")
        for path in candidates {
            if FileExist(path) {
                this.path := path
                return path
            }
        }
        shell := ComObject("WScript.Shell")
        exec := shell.Exec(A_ComSpec " /d /c where.exe FancyZonesCLI.exe")
        output := Trim(exec.StdOut.ReadAll())
        if exec.ExitCode = 0 && output != "" {
            this.path := StrSplit(output, "`n")[1]
            return this.path
        }
        throw Error("FancyZonesCLI.exe was not found")
    }

    EnsurePath() {
        if this.path = ""
            this.Discover()
        return this.path
    }

    RunCli(arguments, timeoutMs := 10000) {
        path := this.EnsurePath()
        token := Win32.Timestamp(false, true) "-" DllCall("GetCurrentProcessId", "UInt") "-" Random(100000, 999999)
        stdoutPath := A_Temp "\SwapMonitors-" token ".out"
        stderrPath := A_Temp "\SwapMonitors-" token ".err"
        ; FancyZonesCLI is a console executable. Launching it with WScript.Exec
        ; creates a visible console for every query/update. A hidden cmd host
        ; with redirected streams avoids all flashes while preserving output.
        command := Format("{1} /d /s /c `"`"{2}`" {3} 1>`"{4}`" 2>`"{5}`"`"",
            A_ComSpec, path, arguments, stdoutPath, stderrPath)
        shell := ComObject("WScript.Shell")
        started := A_TickCount
        try {
            exitCode := shell.Run(command, 0, true)
            if A_TickCount - started > timeoutMs
                throw Error("FancyZonesCLI timed out: " arguments)
            stdout := FileExist(stdoutPath) ? FileRead(stdoutPath) : ""
            stderr := FileExist(stderrPath) ? FileRead(stderrPath) : ""
        } finally {
            try FileDelete(stdoutPath)
            try FileDelete(stderrPath)
        }
        result := {exitCode: exitCode, stdout: stdout, stderr: stderr, command: arguments}
        this.logger.Debug("FancyZonesCLI " arguments " exit=" result.exitCode
            " duration=" (A_TickCount - started) "ms")
        return result
    }

    GetMonitorsText() {
        result := this.RunCli("get-monitors")
        if result.exitCode != 0
            throw Error("FancyZones get-monitors failed: " Trim(result.stderr))
        return result.stdout
    }

    GetActiveLayouts() {
        result := this.RunCli("get-active-layout")
        if result.exitCode != 0
            throw Error("FancyZones get-active-layout failed: " Trim(result.stderr))
        layouts := Map()
        offset := 1
        pattern := "is)Monitor\s+(\d+):.*?Layout UUID:\s*(\{[^}]+\})"
        while RegExMatch(result.stdout, pattern, &match, offset) {
            layouts[Integer(match[1])] := this.NormalizeUuid(match[2])
            offset := match.Pos + match.Len
        }
        if layouts.Count = 0
            throw Error("Could not parse FancyZones active layouts")
        return layouts
    }

    SetLayout(monitorIndex, uuid) {
        uuid := this.NormalizeUuid(uuid)
        result := this.RunCli("set-layout " uuid " --monitor " monitorIndex)
        if result.exitCode != 0
            throw Error("FancyZones set-layout failed for monitor " monitorIndex ": " Trim(result.stderr " " result.stdout))
        return true
    }

    ApplyLayouts(targets, rollbackLayouts := unset) {
        applied := []
        try {
            for monitorIndex, uuid in targets {
                this.SetLayout(monitorIndex, uuid)
                applied.Push(monitorIndex)
            }
        } catch as err {
            if IsSet(rollbackLayouts) {
                for monitorIndex in applied {
                    try {
                        if rollbackLayouts.Has(monitorIndex)
                            this.SetLayout(monitorIndex, rollbackLayouts[monitorIndex])
                    }
                }
            }
            throw err
        }
    }

    VerifyLayouts(expected) {
        actual := this.GetActiveLayouts()
        for monitorIndex, uuid in expected {
            if !actual.Has(monitorIndex)
                || this.NormalizeUuid(actual[monitorIndex]) != this.NormalizeUuid(uuid)
                throw Error("FancyZones verification failed for monitor " monitorIndex)
        }
        return true
    }

    RestoreLayouts(layouts) {
        failures := 0
        for monitorIndex, uuid in layouts {
            try this.SetLayout(monitorIndex, uuid)
            catch
                failures += 1
        }
        return failures = 0
    }

    ParseMonitorPositions(text) {
        positions := Map()
        offset := 1
        pattern := "is)Monitor\s+(\d+):.*?Position:\s*\((-?\d+),\s*(-?\d+)\)"
        while RegExMatch(text, pattern, &match, offset) {
            positions[Integer(match[1])] := {x: Integer(match[2]), y: Integer(match[3])}
            offset := match.Pos + match.Len
        }
        return positions
    }

    NormalizeUuid(uuid) => StrUpper(Trim(uuid))
}
