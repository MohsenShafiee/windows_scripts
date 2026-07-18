#Requires AutoHotkey v2.0

class Logger {
    __New(logDir, enabled := true, level := "INFO") {
        this.logDir := logDir
        this.enabled := enabled
        this.level := StrUpper(level)
        this.levels := Map("DEBUG", 10, "INFO", 20, "WARN", 30, "ERROR", 40)
        if enabled {
            this.path := logDir "\swap-" SubStr(Win32.Timestamp(), 1, 10) ".log"
            try {
                DirCreate(logDir)
                this.Rotate()
            } catch as err {
                this.enabled := false
                OutputDebug("SwapMonitors logger initialization failed: " err.Message)
            }
        } else {
            this.path := ""
        }
    }

    Write(level, message, operationId := "-") {
        level := StrUpper(level)
        if !this.enabled || !this.levels.Has(level)
            return
        threshold := this.levels.Has(this.level) ? this.levels[this.level] : 20
        if this.levels[level] < threshold
            return
        safe := StrReplace(StrReplace(message, "`r", " "), "`n", " ")
        try {
            ; The folder can disappear while the resident script is running (for example after a sync).
            if !DirExist(this.logDir)
                DirCreate(this.logDir)
            FileAppend(Format("{1}Z [{2}] [{3}] {4}`n", Win32.Timestamp(true),
                level, operationId, safe), this.path, "UTF-8")
        } catch as err {
            ; Logging must never abort an otherwise successful monitor swap.
            OutputDebug("SwapMonitors log write failed: " err.Message)
        }
    }

    Debug(message, operationId := "-") => this.Write("DEBUG", message, operationId)
    Info(message, operationId := "-") => this.Write("INFO", message, operationId)
    Warn(message, operationId := "-") => this.Write("WARN", message, operationId)
    Error(message, operationId := "-") => this.Write("ERROR", message, operationId)

    Rotate() {
        try {
            Loop Files this.logDir "\swap-*.log", "F" {
                if DateDiff(A_Now, A_LoopFileTimeModified, "Days") > 14
                    FileDelete(A_LoopFileFullPath)
            }
        }
    }
}
