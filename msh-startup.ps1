$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$lockFile = Join-Path $scriptDir "msh-startup.lock"
$workspaceShortcut = Join-Path $scriptDir "msh-space.lnk"

if (Test-Path $lockFile) {
    $age = (Get-Date) - (Get-Item $lockFile).LastWriteTime
    if ($age.TotalMinutes -lt 3) {
        exit
    }
}

New-Item -ItemType File -Path $lockFile -Force | Out-Null

# Keep this marker for a few minutes after launch so duplicate logon/startup
# triggers do not re-run the PowerToys workspace while windows are settling.
Start-Sleep -Seconds 5

Start-Process $workspaceShortcut
