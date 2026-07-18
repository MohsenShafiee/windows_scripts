#Requires AutoHotkey v2.0

class Logger {
    __New(logDir, enabled := true, level := "INFO") {
        this.logDir := logDir
        this.enabled := enabled
        this.level := StrUpper(level)
        this.levels := Map("DEBUG", 10, "INFO", 20, "WARN", 30, "ERROR", 40)
        if enabled {
            DirCreate(logDir)
            this.path := logDir "\swap-" SubStr(Win32.Timestamp(), 1, 10) ".log"
            this.Rotate()
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
        FileAppend(Format("{1}Z [{2}] [{3}] {4}`n", Win32.Timestamp(true),
            level, operationId, safe), this.path, "UTF-8")
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
