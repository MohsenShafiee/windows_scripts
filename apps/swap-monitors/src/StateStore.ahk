#Requires AutoHotkey v2.0

class StateStore {
    __New(path) {
        this.path := path
        if !FileExist(path) {
            IniWrite("baseline", path, "SwapState", "Mode")
            IniWrite("1", path, "SwapState", "SchemaVersion")
        }
    }

    Read() {
        mode := StrLower(Trim(IniRead(this.path, "SwapState", "Mode", "baseline")))
        if mode != "baseline" && mode != "swapped"
            return "baseline"
        return mode
    }

    Commit(mode, fingerprint := "") {
        if mode != "baseline" && mode != "swapped"
            throw Error("Refusing to commit invalid state: " mode)
        IniWrite(mode, this.path, "SwapState", "Mode")
        IniWrite(Win32.Timestamp(true) "Z", this.path, "SwapState", "LastSuccessUtc")
        IniWrite(fingerprint, this.path, "SwapState", "LastWorkspaceFingerprint")
        IniWrite("", this.path, "SwapState", "LastError")
        IniWrite("1", this.path, "SwapState", "SchemaVersion")
    }

    RecordError(message) {
        IniWrite(SubStr(StrReplace(message, "`n", " "), 1, 500), this.path, "SwapState", "LastError")
    }
}
