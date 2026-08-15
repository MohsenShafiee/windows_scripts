[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$Version
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Write-Step {
    param([string]$Message)
    Write-Host "==> $Message" -ForegroundColor Cyan
}

function Show-ReleaseNotification {
    param(
        [string]$ReleaseVersion,
        [string]$ApkPath
    )

    try {
        Add-Type -AssemblyName System.Windows.Forms
        Add-Type -AssemblyName System.Drawing

        $notification = New-Object System.Windows.Forms.NotifyIcon
        try {
            $notification.Icon = [System.Drawing.SystemIcons]::Information
            $notification.BalloonTipIcon = [System.Windows.Forms.ToolTipIcon]::Info
            $notification.BalloonTipTitle = "Release $ReleaseVersion completed"
            $notification.BalloonTipText = "APK created: $(Split-Path -Leaf $ApkPath)`n$ApkPath"
            $notification.Visible = $true
            $notification.ShowBalloonTip(5000)

            # NotifyIcon must remain alive briefly or Windows removes the banner.
            Start-Sleep -Milliseconds 5200
        }
        finally {
            $notification.Visible = $false
            $notification.Dispose()
        }
    }
    catch {
        # Notification failure must not turn a completed release into a failure.
        Write-Warning "Release completed, but the Windows notification could not be shown: $($_.Exception.Message)"
    }
}

function Invoke-Checked {
    param(
        [Parameter(Mandatory = $true)][string]$Command,
        [Parameter(Mandatory = $true)][string[]]$Arguments,
        [Parameter(Mandatory = $true)][string]$FailureMessage
    )

    & $Command @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "$FailureMessage (exit code: $LASTEXITCODE)"
    }
}

function Add-PersistedEnvironmentToProcess {
    $persistedJavaHome = [Environment]::GetEnvironmentVariable('JAVA_HOME', 'User')
    if ([string]::IsNullOrWhiteSpace($persistedJavaHome)) {
        $persistedJavaHome = [Environment]::GetEnvironmentVariable('JAVA_HOME', 'Machine')
    }

    if (-not [string]::IsNullOrWhiteSpace($persistedJavaHome)) {
        $javaExecutable = Join-Path $persistedJavaHome 'bin\java.exe'
        if (Test-Path -LiteralPath $javaExecutable) {
            $env:JAVA_HOME = $persistedJavaHome
        }
    }

    $persistedPaths = @(
        [Environment]::GetEnvironmentVariable('Path', 'User'),
        [Environment]::GetEnvironmentVariable('Path', 'Machine')
    )
    $currentParts = @($env:Path -split ';')
    foreach ($persistedPath in $persistedPaths) {
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

function Find-Project {
    param([string]$StartPath)

    $directory = Get-Item -LiteralPath $StartPath
    if (-not $directory.PSIsContainer) { $directory = $directory.Directory }
    $androidCandidate = $null

    while ($null -ne $directory) {
        $pubspecPath = Join-Path $directory.FullName 'pubspec.yaml'
        if (Test-Path -LiteralPath $pubspecPath) {
            $pubspecText = [IO.File]::ReadAllText($pubspecPath)
            if ($pubspecText -match '(?m)^[ \t]*flutter[ \t]*:[ \t]*(?:#.*)?$') {
                return [PSCustomObject]@{ Type = 'Flutter'; Root = $directory.FullName; VersionFile = $pubspecPath }
            }
        }

        if ($null -eq $androidCandidate -and (Test-Path -LiteralPath (Join-Path $directory.FullName 'gradlew.bat'))) {
            $androidCandidate = $directory.FullName
        }

        $directory = $directory.Parent
    }

    if ($null -ne $androidCandidate) {
        return [PSCustomObject]@{ Type = 'Android'; Root = $androidCandidate; VersionFile = $null }
    }

    throw 'No Flutter or native Android project was found in this directory or its parents.'
}

function Test-AndroidApplicationBuildFile {
    param([string]$Path)

    $text = [IO.File]::ReadAllText($Path)
    $hasApplicationIdentity =
        $text -match 'com\.android\.application' -or
        $text -match '(?m)^[ \t]*applicationId(?:[ \t]*=[ \t]*|[ \t]+)["''][^"'']+["'']'
    $hasAndroidBlock = $text -match '(?m)^[ \t]*android[ \t]*\{'
    $hasNumericVersionCode = $text -match '(?m)^[ \t]*versionCode(?:[ \t]*=[ \t]*|[ \t]+)\d+'
    $hasQuotedVersionName = $text -match '(?m)^[ \t]*versionName(?:[ \t]*=[ \t]*|[ \t]+)["''][^"'']*["'']'

    return $hasApplicationIdentity -and $hasAndroidBlock -and $hasNumericVersionCode -and $hasQuotedVersionName
}

function Find-AndroidBuildFile {
    param([string]$ProjectRoot)

    $preferred = @(
        (Join-Path $ProjectRoot 'app\build.gradle'),
        (Join-Path $ProjectRoot 'app\build.gradle.kts')
    )

    foreach ($candidate in $preferred) {
        if ((Test-Path -LiteralPath $candidate) -and (Test-AndroidApplicationBuildFile -Path $candidate)) {
            return $candidate
        }
    }

    $matches = @(Get-ChildItem -LiteralPath $ProjectRoot -Recurse -File -ErrorAction Stop |
        Where-Object {
            ($_.Name -eq 'build.gradle' -or $_.Name -eq 'build.gradle.kts') -and
            $_.FullName -notmatch '[\\/](?:build|\.gradle)[\\/]'
        } |
        Where-Object { Test-AndroidApplicationBuildFile -Path $_.FullName })

    if ($matches.Count -eq 1) { return $matches[0].FullName }
    if ($matches.Count -eq 0) { throw 'Could not find the Gradle file for an Android application module.' }

    $paths = ($matches.FullName -join [Environment]::NewLine)
    throw "More than one Android application module was found. Run release from a single-app project.`n$paths"
}

function Get-FlutterMetadata {
    param([string]$PubspecPath)

    $text = [IO.File]::ReadAllText($PubspecPath)
    $nameMatch = [regex]::Match($text, '(?m)^name[ \t]*:[ \t]*["'']?(?<name>[^#\r\n"'']+)["'']?[ \t]*(?:#.*)?$')
    if (-not $nameMatch.Success) { throw 'The app name could not be read from pubspec.yaml.' }

    $versionMatch = [regex]::Match($text, '(?m)^version[ \t]*:[ \t]*(?<value>[^#\r\n]+?)[ \t]*(?<comment>#.*)?$')
    $currentCode = 0
    if ($versionMatch.Success) {
        $currentValue = $versionMatch.Groups['value'].Value.Trim()
        $codeMatch = [regex]::Match($currentValue, '\+(?<code>\d+)$')
        if ($codeMatch.Success) { $currentCode = [int64]$codeMatch.Groups['code'].Value }
    }

    return [PSCustomObject]@{
        Name = $nameMatch.Groups['name'].Value.Trim()
        CurrentCode = $currentCode
        Text = $text
        VersionMatch = $versionMatch
    }
}

function Set-FlutterVersion {
    param(
        [string]$PubspecPath,
        [string]$NewVersion
    )

    $metadata = Get-FlutterMetadata -PubspecPath $PubspecPath
    $newCode = $metadata.CurrentCode + 1
    $comment = if ($metadata.VersionMatch.Success) { $metadata.VersionMatch.Groups['comment'].Value } else { '' }
    $newLine = "version: $NewVersion+$newCode"
    if (-not [string]::IsNullOrWhiteSpace($comment)) { $newLine += " $($comment.Trim())" }

    if ($metadata.VersionMatch.Success) {
        $newText = $metadata.Text.Remove($metadata.VersionMatch.Index, $metadata.VersionMatch.Length).Insert($metadata.VersionMatch.Index, $newLine)
    }
    else {
        $nameLine = [regex]::Match($metadata.Text, '(?m)^name[^\r\n]*(?:\r?\n)?')
        if (-not $nameLine.Success) { throw 'A version line could not be inserted into pubspec.yaml.' }
        $newline = if ($metadata.Text.Contains("`r`n")) { "`r`n" } else { "`n" }
        $newText = $metadata.Text.Insert($nameLine.Index + $nameLine.Length, "$newLine$newline")
    }

    [IO.File]::WriteAllText($PubspecPath, $newText, [Text.UTF8Encoding]::new($false))
    return [PSCustomObject]@{ Name = $metadata.Name; VersionCode = $newCode }
}

function Set-AndroidVersion {
    param(
        [string]$BuildFile,
        [string]$NewVersion
    )

    $text = [IO.File]::ReadAllText($BuildFile)
    # Do not anchor to `$`: in .NET multiline mode it stops before `\n`, but after
    # the `\r` in CRLF files. The suffix already consumes the complete logical line.
    $codePattern = '(?m)^(?<prefix>[ \t]*versionCode(?:[ \t]*=[ \t]*|[ \t]+))(?<code>\d+)(?<suffix>[^\r\n]*)'
    $namePattern = '(?m)^(?<prefix>[ \t]*versionName(?:[ \t]*=[ \t]*|[ \t]+))(?<quote>["''])(?<name>[^"'']*)(?<close>["''])(?<suffix>[^\r\n]*)'
    $codeMatches = [regex]::Matches($text, $codePattern)
    $nameMatches = [regex]::Matches($text, $namePattern)

    if ($codeMatches.Count -ne 1) { throw "Expected exactly one numeric versionCode in $BuildFile, but found $($codeMatches.Count)." }
    if ($nameMatches.Count -ne 1) { throw "Expected exactly one quoted versionName in $BuildFile, but found $($nameMatches.Count)." }

    $oldCode = [int64]$codeMatches[0].Groups['code'].Value
    $newCode = $oldCode + 1
    $codeEvaluator = [Text.RegularExpressions.MatchEvaluator]{
        param($match)
        return "$($match.Groups['prefix'].Value)$newCode$($match.Groups['suffix'].Value)"
    }
    $newText = [regex]::Replace($text, $codePattern, $codeEvaluator, 1)

    $nameEvaluator = [Text.RegularExpressions.MatchEvaluator]{
        param($match)
        $quote = $match.Groups['quote'].Value
        return "$($match.Groups['prefix'].Value)$quote$NewVersion$quote$($match.Groups['suffix'].Value)"
    }
    $newText = [regex]::Replace($newText, $namePattern, $nameEvaluator, 1)
    [IO.File]::WriteAllText($BuildFile, $newText, [Text.UTF8Encoding]::new($false))

    return $newCode
}

function Get-AndroidAppName {
    param(
        [string]$ProjectRoot,
        [string]$BuildFile
    )

    $moduleRoot = Split-Path -Parent $BuildFile
    $manifestPath = Join-Path $moduleRoot 'src\main\AndroidManifest.xml'
    if (Test-Path -LiteralPath $manifestPath) {
        try {
            [xml]$manifest = [IO.File]::ReadAllText($manifestPath)
            $label = $manifest.manifest.application.GetAttribute('label', 'http://schemas.android.com/apk/res/android')
            if (-not [string]::IsNullOrWhiteSpace($label)) {
                $resourceMatch = [regex]::Match($label, '^@string/(?<key>.+)$')
                if (-not $resourceMatch.Success) { return $label }
                $stringsPath = Join-Path $moduleRoot 'src\main\res\values\strings.xml'
                if (Test-Path -LiteralPath $stringsPath) {
                    [xml]$strings = [IO.File]::ReadAllText($stringsPath)
                    $key = $resourceMatch.Groups['key'].Value
                    $stringNode = @($strings.resources.string | Where-Object { $_.name -eq $key }) | Select-Object -First 1
                    if ($null -ne $stringNode -and -not [string]::IsNullOrWhiteSpace($stringNode.InnerText)) {
                        return $stringNode.InnerText.Trim()
                    }
                }
            }
        }
        catch {
            Write-Warning "Could not read the Android app label: $($_.Exception.Message)"
        }
    }

    foreach ($settingsName in @('settings.gradle', 'settings.gradle.kts')) {
        $settingsPath = Join-Path $ProjectRoot $settingsName
        if (Test-Path -LiteralPath $settingsPath) {
            $settingsText = [IO.File]::ReadAllText($settingsPath)
            $nameMatch = [regex]::Match($settingsText, 'rootProject\.name[ \t]*(?:=[ \t]*)?["''](?<name>[^"'']+)["'']')
            if ($nameMatch.Success) { return $nameMatch.Groups['name'].Value.Trim() }
        }
    }

    return (Split-Path -Leaf $ProjectRoot)
}

function Get-DownloadsPath {
    if (-not [string]::IsNullOrWhiteSpace($env:RELEASE_DOWNLOADS_PATH)) {
        return [Environment]::ExpandEnvironmentVariables($env:RELEASE_DOWNLOADS_PATH)
    }

    $shellFoldersKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders'
    $downloadsId = '{374DE290-123F-4565-9164-39C4925E467B}'
    try {
        $path = Get-ItemPropertyValue -LiteralPath $shellFoldersKey -Name $downloadsId -ErrorAction Stop
        return [Environment]::ExpandEnvironmentVariables($path)
    }
    catch {
        return (Join-Path ([Environment]::GetFolderPath('UserProfile')) 'Downloads')
    }
}

function Get-SafeFileName {
    param([string]$Name)
    $safe = [regex]::Replace($Name.Trim(), '[<>:"/\\|?*]', '_').TrimEnd('.', ' ')
    if ([string]::IsNullOrWhiteSpace($safe)) { throw 'The application name is not valid for a Windows file name.' }
    return $safe
}

if ($Version -notmatch '^\d+\.\d+\.\d+$') {
    Write-Host 'Usage: release <major.minor.patch>  (example: release 1.0.1)' -ForegroundColor Red
    exit 2
}

Add-PersistedEnvironmentToProcess

$gitCommand = Get-Command git -ErrorAction SilentlyContinue
if ($null -eq $gitCommand) { throw 'Git was not found in PATH.' }

$project = Find-Project -StartPath (Get-Location).Path
$projectRoot = $project.Root
Write-Step "Detected $($project.Type) project: $projectRoot"

$gitRootOutput = @(& $gitCommand.Source -C $projectRoot rev-parse --show-toplevel 2>$null)
if ($LASTEXITCODE -ne 0 -or $gitRootOutput.Count -eq 0) { throw 'The project is not inside a Git repository.' }
$gitRoot = $gitRootOutput[-1].Trim()

$dirty = @(& $gitCommand.Source -C $gitRoot status --porcelain --untracked-files=normal)
if ($LASTEXITCODE -ne 0) { throw 'Could not read Git status.' }
if ($dirty.Count -gt 0) {
    throw "The Git working tree is not clean. Commit or stash these changes first:`n$($dirty -join "`n")"
}

$existingTag = @(& $gitCommand.Source -C $gitRoot tag --list $Version)
if ($LASTEXITCODE -ne 0) { throw 'Could not inspect Git tags.' }
if ($existingTag -contains $Version) { throw "Git tag '$Version' already exists." }

& $gitCommand.Source -C $gitRoot var GIT_AUTHOR_IDENT *> $null
if ($LASTEXITCODE -ne 0) { throw 'Git user.name or user.email is not configured.' }

$versionFile = $project.VersionFile
if ($project.Type -eq 'Android') {
    $versionFile = Find-AndroidBuildFile -ProjectRoot $projectRoot
}
$originalText = [IO.File]::ReadAllText($versionFile)
$commitCreated = $false
$destinationPath = $null
$destinationBackup = $null
$destinationExisted = $false

try {
    if ($project.Type -eq 'Flutter') {
        $flutterCommand = Get-Command flutter -ErrorAction SilentlyContinue
        if ($null -eq $flutterCommand) { throw 'Flutter was not found in PATH.' }

        $metadata = Set-FlutterVersion -PubspecPath $versionFile -NewVersion $Version
        $appName = $metadata.Name
        Write-Step "Updated pubspec.yaml: version $Version+$($metadata.VersionCode)"
        Write-Step 'Building Flutter release APK'
        Push-Location $projectRoot
        try {
            Invoke-Checked -Command $flutterCommand.Source -Arguments @('build', 'apk', '--release') -FailureMessage 'Flutter release build failed'
        }
        finally { Pop-Location }

        $apkPath = Join-Path $projectRoot 'build\app\outputs\flutter-apk\app-release.apk'
        if (-not (Test-Path -LiteralPath $apkPath)) { throw "Flutter finished but the APK was not found at $apkPath" }
    }
    else {
        $newCode = Set-AndroidVersion -BuildFile $versionFile -NewVersion $Version
        $appName = Get-AndroidAppName -ProjectRoot $projectRoot -BuildFile $versionFile
        Write-Step "Updated $(Split-Path -Leaf $versionFile): versionName $Version, versionCode $newCode"
        Write-Step 'Building native Android release APK'
        $buildStarted = [DateTime]::UtcNow.AddSeconds(-5)
        Push-Location $projectRoot
        try {
            Invoke-Checked -Command (Join-Path $projectRoot 'gradlew.bat') -Arguments @('assembleRelease') -FailureMessage 'Android release build failed'
        }
        finally { Pop-Location }

        $apkCandidates = @(Get-ChildItem -LiteralPath $projectRoot -Recurse -File -Filter '*.apk' -ErrorAction Stop |
            Where-Object {
                $_.FullName -match '[\\/]build[\\/]outputs[\\/]apk[\\/].*release' -and
                $_.LastWriteTimeUtc -ge $buildStarted
            } |
            Sort-Object -Property @{ Expression = { if ($_.Name -match '-release\.apk$') { 0 } else { 1 } } },
                                  @{ Expression = 'LastWriteTimeUtc'; Descending = $true })
        if ($apkCandidates.Count -eq 0) { throw 'Gradle finished but no newly built release APK was found.' }
        $apkPath = $apkCandidates[0].FullName
        if ($apkCandidates.Count -gt 1) {
            Write-Warning "Multiple release APKs were found; using $apkPath"
        }
    }

    $downloadsPath = Get-DownloadsPath
    if (-not (Test-Path -LiteralPath $downloadsPath)) {
        New-Item -ItemType Directory -Path $downloadsPath -Force | Out-Null
    }
    $safeAppName = Get-SafeFileName -Name $appName
    $destinationPath = Join-Path $downloadsPath "${safeAppName}_${Version}.apk"
    $destinationExisted = Test-Path -LiteralPath $destinationPath
    if ($destinationExisted) {
        $destinationBackup = Join-Path ([IO.Path]::GetTempPath()) "release-tool-$([guid]::NewGuid().ToString('N')).apk"
        Copy-Item -LiteralPath $destinationPath -Destination $destinationBackup -Force
    }
    Copy-Item -LiteralPath $apkPath -Destination $destinationPath -Force
    Write-Step "Copied APK to $destinationPath"

    $normalizedGitRoot = [IO.Path]::GetFullPath($gitRoot).Replace('/', '\').TrimEnd('\')
    $normalizedVersionFile = [IO.Path]::GetFullPath($versionFile).Replace('/', '\')
    if (-not $normalizedVersionFile.StartsWith("$normalizedGitRoot\", [StringComparison]::OrdinalIgnoreCase)) {
        throw "The version file is outside the Git repository: $versionFile"
    }
    $relativeVersionFile = $normalizedVersionFile.Substring($normalizedGitRoot.Length).TrimStart('\').Replace('\', '/')
    Invoke-Checked -Command $gitCommand.Source -Arguments @('-C', $gitRoot, 'add', '--', $relativeVersionFile) -FailureMessage 'Could not stage the version file'
    Invoke-Checked -Command $gitCommand.Source -Arguments @('-C', $gitRoot, 'commit', '--only', '-m', "version: $Version", '--', $relativeVersionFile) -FailureMessage 'Could not create the version commit'
    $commitCreated = $true
    Invoke-Checked -Command $gitCommand.Source -Arguments @('-C', $gitRoot, 'tag', $Version) -FailureMessage "The commit was created, but tag '$Version' could not be created"

    if ($null -ne $destinationBackup -and (Test-Path -LiteralPath $destinationBackup)) {
        Remove-Item -LiteralPath $destinationBackup -Force
    }

    Write-Host ''
    Write-Host "Release $Version completed successfully." -ForegroundColor Green
    Write-Host "APK: $destinationPath" -ForegroundColor Green
    Write-Host "Commit: version: $Version" -ForegroundColor Green
    Write-Host "Tag: $Version" -ForegroundColor Green
    Show-ReleaseNotification -ReleaseVersion $Version -ApkPath $destinationPath
}
catch {
    if (-not $commitCreated) {
        [IO.File]::WriteAllText($versionFile, $originalText, [Text.UTF8Encoding]::new($false))
        & $gitCommand.Source -C $gitRoot restore --staged -- $versionFile 2>$null

        if ($null -ne $destinationPath) {
            if ($destinationExisted -and $null -ne $destinationBackup -and (Test-Path -LiteralPath $destinationBackup)) {
                Copy-Item -LiteralPath $destinationBackup -Destination $destinationPath -Force
            }
            elseif (-not $destinationExisted -and (Test-Path -LiteralPath $destinationPath)) {
                Remove-Item -LiteralPath $destinationPath -Force
            }
        }
    }

    if ($null -ne $destinationBackup -and (Test-Path -LiteralPath $destinationBackup)) {
        Remove-Item -LiteralPath $destinationBackup -Force
    }

    Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
