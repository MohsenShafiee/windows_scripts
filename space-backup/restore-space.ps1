$ErrorActionPreference = 'Stop'

$isAdministrator = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator
)

if (-not $isAdministrator)
{
    Start-Process -FilePath "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" `
        -Verb RunAs `
        -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', ('"{0}"' -f $PSCommandPath))
    exit
}

$packageRoot = Split-Path -Parent $PSCommandPath
$workspaceDir = Join-Path $env:LOCALAPPDATA 'Microsoft\PowerToys\Workspaces'
$terminalDir = Join-Path $env:LOCALAPPDATA 'Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState'
$scriptDir = 'D:\Github\msh_apps\windows_scripts'
$startupDir = [Environment]::GetFolderPath('Startup')
$stamp = [DateTime]::Now.ToString('yyyyMMdd-HHmmss', [Globalization.CultureInfo]::InvariantCulture)
$safetyDir = Join-Path $workspaceDir "Backups\restore-safety-$stamp"

New-Item -ItemType Directory -Path $safetyDir -Force | Out-Null
New-Item -ItemType Directory -Path $workspaceDir -Force | Out-Null
New-Item -ItemType Directory -Path $terminalDir -Force | Out-Null
New-Item -ItemType Directory -Path $scriptDir -Force | Out-Null

foreach ($item in @(
    (Join-Path $workspaceDir 'workspaces.json'),
    (Join-Path $terminalDir 'settings.json'),
    (Join-Path $scriptDir 'msh-startup.vbs'),
    (Join-Path $scriptDir 'space-admin-layout.ps1'),
    (Join-Path $scriptDir 'SwapMonitors.ahk')
))
{
    if (Test-Path -LiteralPath $item)
    {
        Copy-Item -LiteralPath $item -Destination $safetyDir -Force
    }
}

foreach ($taskName in @('space - Admin Windows', 'space - Workspace'))
{
    if (Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue)
    {
        Export-ScheduledTask -TaskName $taskName |
            Out-File -LiteralPath (Join-Path $safetyDir "$taskName.xml") -Encoding unicode
    }
}

foreach ($shortcutName in @('space.lnk', 'msh-startup-workspace.lnk', 'msh-space.lnk'))
{
    $shortcut = Join-Path $startupDir $shortcutName
    if (Test-Path -LiteralPath $shortcut)
    {
        Move-Item -LiteralPath $shortcut -Destination (Join-Path $safetyDir $shortcutName) -Force
    }
}

Copy-Item -LiteralPath (Join-Path $packageRoot 'config\workspaces.json') `
    -Destination (Join-Path $workspaceDir 'workspaces.json') -Force
Copy-Item -LiteralPath (Join-Path $packageRoot 'terminal\settings.json') `
    -Destination (Join-Path $terminalDir 'settings.json') -Force
Copy-Item -LiteralPath (Join-Path $packageRoot 'scripts\msh-startup.vbs') `
    -Destination (Join-Path $scriptDir 'msh-startup.vbs') -Force
Copy-Item -LiteralPath (Join-Path $packageRoot 'scripts\space-admin-layout.ps1') `
    -Destination (Join-Path $scriptDir 'space-admin-layout.ps1') -Force
Copy-Item -LiteralPath (Join-Path $packageRoot 'scripts\SwapMonitors.ahk') `
    -Destination (Join-Path $scriptDir 'SwapMonitors.ahk') -Force

$registryImport = Start-Process -FilePath "$env:SystemRoot\System32\reg.exe" `
    -ArgumentList @('import', ('"{0}"' -f (Join-Path $packageRoot 'terminal\StartTerminalOnLoginTask.reg'))) `
    -Wait -PassThru -WindowStyle Hidden
if ($registryImport.ExitCode -ne 0)
{
    throw "Importing the Terminal StartupTask state failed with exit code $($registryImport.ExitCode)."
}

foreach ($taskName in @('space - Admin Windows', 'space - Workspace'))
{
    $taskXml = Get-Content -LiteralPath (Join-Path $packageRoot "tasks\$taskName.xml") -Raw
    Register-ScheduledTask -TaskName $taskName -Xml $taskXml -Force | Out-Null
}

foreach ($legacyTask in @('space - Admin Terminal', 'msh-space - Admin PowerShell'))
{
    if (Get-ScheduledTask -TaskName $legacyTask -ErrorAction SilentlyContinue)
    {
        Unregister-ScheduledTask -TaskName $legacyTask -Confirm:$false
    }
}

$adminTask = Get-ScheduledTask -TaskName 'space - Admin Windows'
$workspaceTask = Get-ScheduledTask -TaskName 'space - Workspace'
$workspace = Get-Content -LiteralPath (Join-Path $workspaceDir 'workspaces.json') -Raw | ConvertFrom-Json
$terminalSettings = Get-Content -LiteralPath (Join-Path $terminalDir 'settings.json') -Raw | ConvertFrom-Json

if ($adminTask.Principal.RunLevel -ne 'Highest')
{
    throw 'The administrator task was restored without Highest run level.'
}
if ($workspaceTask.Principal.RunLevel -ne 'Limited')
{
    throw 'The normal workspace task was restored with the wrong run level.'
}
if ($workspace.workspaces.Count -ne 1 -or $workspace.workspaces[0].name -ne 'space')
{
    throw 'The PowerToys workspace definition did not pass verification.'
}
if ($terminalSettings.startOnUserLogin -ne $false)
{
    throw 'Windows Terminal startup was not disabled.'
}

Write-Host ''
Write-Host 'space restored successfully.' -ForegroundColor Green
Write-Host "Safety backup: $safetyDir"
Write-Host 'Sign out and sign back in, or restart Windows, to test the restored startup.'
