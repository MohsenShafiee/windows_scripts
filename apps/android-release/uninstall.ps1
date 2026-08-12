[CmdletBinding()]
param(
    [string]$InstallDirectory = (Join-Path $env:LOCALAPPDATA 'Programs\AndroidReleaseTool')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$resolvedInstallDirectory = [Environment]::ExpandEnvironmentVariables($InstallDirectory).TrimEnd('\')
$currentPath = [Environment]::GetEnvironmentVariable('Path', 'User')
$parts = @($currentPath -split ';' | Where-Object {
    -not [string]::IsNullOrWhiteSpace($_) -and
    $_.TrimEnd('\') -ine $resolvedInstallDirectory
})
[Environment]::SetEnvironmentVariable('Path', ($parts -join ';'), 'User')

if (Test-Path -LiteralPath $resolvedInstallDirectory) {
    $resolvedFullPath = [IO.Path]::GetFullPath($resolvedInstallDirectory)
    $localAppDataFullPath = [IO.Path]::GetFullPath($env:LOCALAPPDATA).TrimEnd('\') + '\'
    if (-not $resolvedFullPath.StartsWith($localAppDataFullPath, [StringComparison]::OrdinalIgnoreCase)) {
        throw "For safety, automatic deletion is limited to LOCALAPPDATA: $resolvedFullPath"
    }
    Remove-Item -LiteralPath $resolvedFullPath -Recurse -Force
}

Write-Host 'Android & Flutter Release Tool was uninstalled.' -ForegroundColor Green
Write-Host 'Close and reopen existing terminals to refresh PATH.' -ForegroundColor Yellow

