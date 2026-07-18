param(
    [switch]$NoLaunch,
    [switch]$ArrangeOnce
)

$ErrorActionPreference = 'Stop'

$terminal = Join-Path $env:LOCALAPPDATA 'Microsoft\WindowsApps\wt.exe'
$wcc = Join-Path $env:LOCALAPPDATA 'WindowsCommandCenter\bin\wcc.cmd'
$logFile = Join-Path $PSScriptRoot 'space-admin-layout.log'

Add-Type @'
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Text;

public static class SpaceLayout
{
    public delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);

    [StructLayout(LayoutKind.Sequential)]
    public struct RECT
    {
        public int Left;
        public int Top;
        public int Right;
        public int Bottom;
    }

    public sealed class WindowInfo
    {
        public long Hwnd;
        public uint ProcessId;
        public string ProcessName = "";
        public string Title = "";
        public int X;
        public int Y;
        public int Width;
        public int Height;
    }

    [DllImport("user32.dll")]
    private static extern bool EnumWindows(EnumWindowsProc callback, IntPtr lParam);

    [DllImport("user32.dll")]
    private static extern bool IsWindowVisible(IntPtr hWnd);

    [DllImport("user32.dll", CharSet = CharSet.Unicode)]
    private static extern int GetWindowText(IntPtr hWnd, StringBuilder text, int count);

    [DllImport("user32.dll")]
    private static extern bool GetWindowRect(IntPtr hWnd, out RECT rect);

    [DllImport("user32.dll")]
    private static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint processId);

    [DllImport("user32.dll", SetLastError = true)]
    private static extern bool SetWindowPos(
        IntPtr hWnd,
        IntPtr hWndInsertAfter,
        int x,
        int y,
        int width,
        int height,
        uint flags);

    [DllImport("user32.dll", SetLastError = true)]
    private static extern bool PostMessage(IntPtr hWnd, uint message, IntPtr wParam, IntPtr lParam);

    public static List<WindowInfo> GetWindows()
    {
        var result = new List<WindowInfo>();
        EnumWindows((hWnd, lParam) =>
        {
            if (!IsWindowVisible(hWnd))
            {
                return true;
            }

            var title = new StringBuilder(1024);
            GetWindowText(hWnd, title, title.Capacity);
            if (title.Length == 0)
            {
                return true;
            }

            RECT rect;
            if (!GetWindowRect(hWnd, out rect) || rect.Right <= rect.Left || rect.Bottom <= rect.Top)
            {
                return true;
            }

            uint processId;
            GetWindowThreadProcessId(hWnd, out processId);
            var processName = "";
            try
            {
                processName = Process.GetProcessById((int)processId).ProcessName;
            }
            catch
            {
            }

            result.Add(new WindowInfo
            {
                Hwnd = hWnd.ToInt64(),
                ProcessId = processId,
                ProcessName = processName,
                Title = title.ToString(),
                X = rect.Left,
                Y = rect.Top,
                Width = rect.Right - rect.Left,
                Height = rect.Bottom - rect.Top
            });
            return true;
        }, IntPtr.Zero);

        return result;
    }

    public static bool Move(long hwnd, int x, int y, int width, int height)
    {
        const uint SWP_NOZORDER = 0x0004;
        const uint SWP_NOACTIVATE = 0x0010;
        return SetWindowPos(new IntPtr(hwnd), IntPtr.Zero, x, y, width, height, SWP_NOZORDER | SWP_NOACTIVATE);
    }

    public static bool Close(long hwnd)
    {
        const uint WM_CLOSE = 0x0010;
        return PostMessage(new IntPtr(hwnd), WM_CLOSE, IntPtr.Zero, IntPtr.Zero);
    }
}
'@

function Write-SpaceLog
{
    param([string]$Message)
    Add-Content -LiteralPath $logFile -Value ("{0} {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Message)
}

function Get-SpaceWindows
{
    return [SpaceLayout]::GetWindows()
}

$rules = @(
    [pscustomobject]@{ Name = 'File Explorer';       Process = 'explorer';          Title = $null;                                   X = -2;   Y = 5;   Width = 1425; Height = 413 },
    [pscustomobject]@{ Name = 'ChatGPT Classic';     Process = 'ChatGPT Classic';   Title = 'ChatGPT Classic';                       X = -2;   Y = 415; Width = 552;  Height = 619 },
    [pscustomobject]@{ Name = 'ChatGPT';             Process = 'ChatGPT';           Title = 'ChatGPT';                               X = 547;  Y = 415; Width = 869;  Height = 612 },
    [pscustomobject]@{ Name = 'WCC (Administrator)'; Process = 'cmd';               Title = 'Administrator: Windows Command Center'; X = 1413; Y = 5;   Width = 509;  Height = 498 },
    [pscustomobject]@{ Name = 'Terminal (Admin)';    Process = 'WindowsTerminal';   Title = 'Administrator: PowerShell';             X = 1413; Y = 500; Width = 509;  Height = 534 },
    [pscustomobject]@{ Name = 'Google Chrome';       Process = 'chrome';            Title = $null;                                   X = 1918; Y = 5;   Width = 1413; Height = 1029 },
    [pscustomobject]@{ Name = 'Telegram';            Process = 'Telegram';          Title = $null;                                   X = 3321; Y = 5;   Width = 521;  Height = 846 },
    [pscustomobject]@{ Name = 'PotPlayer';           Process = 'PotPlayerMini64';   Title = $null;                                   X = 3328; Y = 848; Width = 507;  Height = 179 }
)

Write-SpaceLog ("Layout helper started. NoLaunch={0}; ArrangeOnce={1}" -f $NoLaunch.IsPresent, $ArrangeOnce.IsPresent)

if (-not $NoLaunch)
{
    $explorerDeadline = (Get-Date).AddSeconds(15)
    while (-not (Get-Process -Name explorer -ErrorAction SilentlyContinue) -and (Get-Date) -lt $explorerDeadline)
    {
        Start-Sleep -Milliseconds 250
    }

    if (-not (Get-Process -Name explorer -ErrorAction SilentlyContinue))
    {
        Write-SpaceLog 'Explorer was not ready within 15 seconds.'
        exit 3
    }

    $windows = Get-SpaceWindows

    if (-not ($windows | Where-Object { $_.ProcessName -eq 'WindowsTerminal' -and $_.Title -eq 'Administrator: PowerShell' }))
    {
        Start-Process -FilePath $terminal -ArgumentList @('-w', 'space-admin')
        Write-SpaceLog 'Started elevated Terminal.'
    }

    if (-not ($windows | Where-Object { $_.Title -eq 'Administrator: Windows Command Center' }))
    {
        Start-Process -FilePath "$env:SystemRoot\System32\cmd.exe" -ArgumentList @('/d', '/k', ('"{0}"' -f $wcc))
        Write-SpaceLog 'Started elevated Windows Command Center.'
    }
}

$started = Get-Date
$minimumRunSeconds = if ($ArrangeOnce) { 0 } elseif ($NoLaunch) { 3 } else { 35 }
$requiredStablePasses = if ($ArrangeOnce) { 1 } else { 8 }
$timeoutSeconds = if ($ArrangeOnce) { 10 } else { 75 }
$stablePasses = 0

while (((Get-Date) - $started).TotalSeconds -lt $timeoutSeconds)
{
    $windows = Get-SpaceWindows

    $allFound = $true
    $allAligned = $true

    foreach ($rule in $rules)
    {
        $target = $windows |
            Where-Object {
                $_.ProcessName -eq $rule.Process -and
                ($null -eq $rule.Title -or $_.Title -eq $rule.Title)
            } |
            Select-Object -First 1

        if (-not $target)
        {
            $allFound = $false
            $allAligned = $false
            continue
        }

        $isAligned =
            $target.X -eq $rule.X -and
            $target.Y -eq $rule.Y -and
            $target.Width -eq $rule.Width -and
            $target.Height -eq $rule.Height

        if (-not $isAligned)
        {
            $allAligned = $false
            if (-not [SpaceLayout]::Move($target.Hwnd, $rule.X, $rule.Y, $rule.Width, $rule.Height))
            {
                Write-SpaceLog ("SetWindowPos failed for {0}." -f $rule.Name)
            }
        }
    }

    if ($allFound -and $allAligned)
    {
        $stablePasses++
    }
    else
    {
        $stablePasses = 0
    }

    $elapsed = ((Get-Date) - $started).TotalSeconds
    if ($elapsed -ge $minimumRunSeconds -and $stablePasses -ge $requiredStablePasses)
    {
        Write-SpaceLog 'All eight windows are present and stable in the expected rectangles.'
        exit 0
    }

    Start-Sleep -Seconds 1
}

Write-SpaceLog 'Timed out before all eight windows were simultaneously stable.'
exit 2
