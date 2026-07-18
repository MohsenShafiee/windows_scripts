#Requires AutoHotkey v2.0

SplitPath(A_LineFile, , &toolsDir)
root := toolsDir "\.."
RunWait(Format("`"{1}`" `"{2}\SwapMonitors.ahk`" --diagnose", A_AhkPath, root), root)
