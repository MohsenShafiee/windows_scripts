#Requires AutoHotkey v2.0

class ConfigService {
    __New(path) {
        this.path := path
        SplitPath(path, , &configDir)
        this.dir := configDir
        if !FileExist(path)
            throw Error("Config file not found: " path)
    }

    Get(section, key, default := "") => IniRead(this.path, section, key, default)

    GetBool(section, key, default := false) {
        value := StrLower(Trim(this.Get(section, key, default ? "1" : "0")))
        return value = "1" || value = "true" || value = "yes" || value = "on"
    }

    GetInt(section, key, default := 0) {
        value := this.Get(section, key, default)
        return IsNumber(value) ? Integer(value) : default
    }

    ResolvePath(value) {
        value := Trim(value, " `t`r`n`"")
        if value = "" || StrUpper(value) = "AUTO"
            return value
        value := this.ExpandEnvironment(value)
        if !RegExMatch(value, "i)^[A-Z]:\\|^\\\\")
            value := this.dir "\" value
        return ComObject("Scripting.FileSystemObject").GetAbsolutePathName(value)
    }

    ExpandEnvironment(value) {
        start := 1
        while RegExMatch(value, "%([^%]+)%", &match, start) {
            replacement := EnvGet(match[1])
            value := SubStr(value, 1, match.Pos - 1) replacement SubStr(value, match.Pos + match.Len)
            start := match.Pos + StrLen(replacement)
        }
        return value
    }

    ReadNumbered(section, prefix, maxItems := 100) {
        values := []
        Loop maxItems {
            value := Trim(this.Get(section, prefix A_Index, ""))
            if value != ""
                values.Push(value)
        }
        return values
    }

    ExpectedWindows() {
        rules := []
        for value in this.ReadNumbered("ExpectedWindows", "Rule") {
            parts := StrSplit(value, "|")
            rules.Push({process: parts.Length >= 1 ? parts[1] : "",
                class: parts.Length >= 2 ? parts[2] : "",
                title: parts.Length >= 3 ? parts[3] : ""})
        }
        return rules
    }

    Validate() {
        for section in ["MonitorA", "MonitorB"] {
            if Trim(this.Get(section, "DeviceName")) = ""
                throw Error(section " DeviceName is missing")
        }
    }
}
