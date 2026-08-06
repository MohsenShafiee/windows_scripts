# Compatibility launcher for callers that still use the original repository path.
& (Join-Path $PSScriptRoot 'apps\space-workspace\runtime\msh-startup.ps1') @args
exit $LASTEXITCODE
