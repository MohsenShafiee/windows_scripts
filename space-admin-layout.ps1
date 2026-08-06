# Compatibility launcher for the existing elevated Scheduled Task.
& (Join-Path $PSScriptRoot 'apps\space-workspace\runtime\space-admin-layout.ps1') @args
exit $LASTEXITCODE
