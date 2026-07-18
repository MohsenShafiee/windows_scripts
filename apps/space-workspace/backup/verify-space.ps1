$ErrorActionPreference = 'Stop'

$workspaceFile = Join-Path $env:LOCALAPPDATA 'Microsoft\PowerToys\Workspaces\workspaces.json'
$terminalSettingsFile = Join-Path $env:LOCALAPPDATA 'Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json'
$terminalStartupKey = 'HKCU:\Software\Classes\Local Settings\Software\Microsoft\Windows\CurrentVersion\AppModel\SystemAppData\Microsoft.WindowsTerminal_8wekyb3d8bbwe\StartTerminalOnLoginTask'

$workspace = Get-Content -LiteralPath $workspaceFile -Raw | ConvertFrom-Json
$terminalSettings = Get-Content -LiteralPath $terminalSettingsFile -Raw | ConvertFrom-Json
$terminalStartup = Get-ItemProperty -LiteralPath $terminalStartupKey
$adminTask = Get-ScheduledTask -TaskName 'space - Admin Windows'
$workspaceTask = Get-ScheduledTask -TaskName 'space - Workspace'

$result = [pscustomobject]@{
    WorkspaceName = $workspace.workspaces[0].name
    WorkspaceCount = $workspace.workspaces.Count
    NormalWorkspaceApps = $workspace.workspaces[0].applications.Count
    AdminTaskRunLevel = $adminTask.Principal.RunLevel
    AdminTaskDelay = if ($adminTask.Triggers.Delay) { $adminTask.Triggers.Delay } else { 'none' }
    WorkspaceTaskRunLevel = $workspaceTask.Principal.RunLevel
    WorkspaceTaskDelay = if ($workspaceTask.Triggers.Delay) { $workspaceTask.Triggers.Delay } else { 'none' }
    TerminalStartOnLogin = $terminalSettings.startOnUserLogin
    TerminalStartupTaskState = $terminalStartup.State
    TerminalUserEnabledOnce = $terminalStartup.UserEnabledStartupOnce
}

$result | Format-List

if (
    $result.WorkspaceName -ne 'space' -or
    $result.WorkspaceCount -ne 1 -or
    $result.AdminTaskRunLevel -ne 'Highest' -or
    $result.WorkspaceTaskRunLevel -ne 'Limited' -or
    $result.AdminTaskDelay -ne 'none' -or
    $result.WorkspaceTaskDelay -ne 'none' -or
    $result.TerminalStartOnLogin -ne $false -or
    $result.TerminalStartupTaskState -ne 1
)
{
    throw 'space verification failed.'
}

Write-Host 'Verification passed.' -ForegroundColor Green

