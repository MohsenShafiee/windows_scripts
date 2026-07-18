# نصب و راه‌اندازی

## پیش‌نیاز

فقط AutoHotkey v2 لازم است. PowerToys، Workspaces و FancyZones جزو پیش‌نیازها نیستند.

## مراحل

1. در `config/config.ini` مقدار `DeviceName` مانیتور A و B را تنظیم کنید.
2. `tools/Diagnose.ahk` را اجرا کنید و نام مانیتورها و تعداد پنجره‌های Swap plan را کنترل کنید.
3. `SwapMonitors.ahk` را اجرا کنید.
4. با `Ctrl + Shift + Middle Click` محتوای دو مانیتور را جابه‌جا کنید.

برای اجرای Administrator در Logon، در Task Scheduler برنامه `C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe` و آرگومان مسیر کامل `SwapMonitors.ahk` را ثبت کنید. فعال‌کردن `Run with highest privileges` امکان انتقال پنجره‌های elevated را فراهم می‌کند.

## تست اولیه

```powershell
& 'C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe' .\SwapMonitors.ahk --diagnose
& 'C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe' .\tests\SmokeTest.ahk
& 'C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe' .\tests\WindowOnlySwapTest.ahk
```
