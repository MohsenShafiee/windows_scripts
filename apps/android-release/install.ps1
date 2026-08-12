[CmdletBinding()]
param(
    [string]$InstallDirectory = (Join-Path $env:LOCALAPPDATA 'Programs\AndroidReleaseTool'),
    [switch]$NoPathUpdate
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Add-ToUserPath {
    param([string]$Directory)

    $currentPath = [Environment]::GetEnvironmentVariable('Path', 'User')
    $parts = @($currentPath -split ';' | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    if (-not ($parts | Where-Object { $_.TrimEnd('\') -ieq $Directory.TrimEnd('\') })) {
        $parts += $Directory
        [Environment]::SetEnvironmentVariable('Path', ($parts -join ';'), 'User')
        return $true
    }
    return $false
}

function Publish-EnvironmentChange {
    Add-Type -Namespace Native -Name EnvironmentBroadcast -MemberDefinition @'
[System.Runtime.InteropServices.DllImport("user32.dll", SetLastError = true, CharSet = System.Runtime.InteropServices.CharSet.Auto)]
public static extern System.IntPtr SendMessageTimeout(
    System.IntPtr hWnd,
    int Msg,
    System.IntPtr wParam,
    string lParam,
    int fuFlags,
    int uTimeout,
    out System.IntPtr lpdwResult);
'@
    $result = [IntPtr]::Zero
    [void][Native.EnvironmentBroadcast]::SendMessageTimeout(
        [IntPtr]0xffff, 0x001A, [IntPtr]::Zero, 'Environment', 2, 5000, [ref]$result)
}

function Import-PersistedEnvironment {
    $javaHome = [Environment]::GetEnvironmentVariable('JAVA_HOME', 'User')
    if ([string]::IsNullOrWhiteSpace($javaHome)) {
        $javaHome = [Environment]::GetEnvironmentVariable('JAVA_HOME', 'Machine')
    }
    if (-not [string]::IsNullOrWhiteSpace($javaHome)) {
        $env:JAVA_HOME = $javaHome
    }

    $currentParts = @($env:Path -split ';')
    foreach ($scope in @('User', 'Machine')) {
        $persistedPath = [Environment]::GetEnvironmentVariable('Path', $scope)
        foreach ($part in @($persistedPath -split ';')) {
            if ([string]::IsNullOrWhiteSpace($part)) { continue }
            $expandedPart = [Environment]::ExpandEnvironmentVariables($part.Trim())
            if (-not ($currentParts | Where-Object { $_.TrimEnd('\') -ieq $expandedPart.TrimEnd('\') })) {
                $env:Path = "$env:Path;$expandedPart"
                $currentParts += $expandedPart
            }
        }
    }

    if (-not [string]::IsNullOrWhiteSpace($env:JAVA_HOME)) {
        $javaBin = Join-Path $env:JAVA_HOME 'bin'
        if (-not ($currentParts | Where-Object { $_.TrimEnd('\') -ieq $javaBin.TrimEnd('\') })) {
            $env:Path = "$javaBin;$env:Path"
        }
    }
}

$sourceFiles = @('release.cmd', 'release.ps1')
foreach ($file in $sourceFiles) {
    $sourcePath = Join-Path $PSScriptRoot $file
    if (-not (Test-Path -LiteralPath $sourcePath)) {
        throw "Required package file is missing: $sourcePath"
    }
}

$resolvedInstallDirectory = [Environment]::ExpandEnvironmentVariables($InstallDirectory)
New-Item -ItemType Directory -Path $resolvedInstallDirectory -Force | Out-Null

foreach ($file in $sourceFiles) {
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot $file) -Destination (Join-Path $resolvedInstallDirectory $file) -Force
}

$pathChanged = $false
if (-not $NoPathUpdate) {
    $pathChanged = Add-ToUserPath -Directory $resolvedInstallDirectory
    if ($pathChanged) { Publish-EnvironmentChange }
}

$env:Path = "$resolvedInstallDirectory;$env:Path"
Import-PersistedEnvironment

Write-Host ''
Write-Host 'Android & Flutter Release Tool installed successfully.' -ForegroundColor Green
Write-Host "Location: $resolvedInstallDirectory"
Write-Host "Command:  release 1.0.1"
if ($pathChanged) {
    Write-Host 'PATH was updated. Close and reopen existing terminals before using the command.' -ForegroundColor Yellow
}
elseif ($NoPathUpdate) {
    Write-Host 'PATH update was skipped because -NoPathUpdate was supplied.' -ForegroundColor Yellow
}
else {
    Write-Host 'The install directory was already present in User PATH.'
}

Write-Host ''
Write-Host 'Dependency check:' -ForegroundColor Cyan
foreach ($dependency in @('git', 'java', 'flutter')) {
    $command = Get-Command $dependency -ErrorAction SilentlyContinue
    if ($null -ne $command) {
        Write-Host "  [OK] $dependency -> $($command.Source)" -ForegroundColor Green
    }
    else {
        Write-Host "  [MISSING] $dependency" -ForegroundColor Yellow
    }
}
