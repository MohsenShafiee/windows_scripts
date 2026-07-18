$scriptDirectory = Split-Path -Parent $MyInvocation.MyCommand.Path
$launcherScript = Join-Path $scriptDirectory 'msh-startup.vbs'

# Compatibility entry point. The real startup host is wscript.exe so this
# PowerShell process exits before PowerToys looks for the workspace Terminal.
Start-Process -FilePath "$env:SystemRoot\System32\wscript.exe" -ArgumentList ('"{0}"' -f $launcherScript)
