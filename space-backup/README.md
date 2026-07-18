# بکاپ کامل `space`

این بسته وضعیت فعلی و تست‌شدهٔ workspace را نگه می‌دارد:

- تعریف PowerToys Workspaces برای `space`
- Task معمولی `space - Workspace`
- Task ادمین `space - Admin Windows`
- اسکریپت اجرای سریع workspace
- اسکریپت اجرای Administrator برای Terminal و WCC و تثبیت چیدمان
- اسکریپت `SwapMonitors.ahk` با رفتار Reset-to-Startup و سپس Swap
- تنظیمات Windows Terminal با StartupTask غیرفعال

## بازیابی

1. فایل ZIP را در یک پوشه استخراج کنید.
2. روی `restore-space.ps1` راست‌کلیک و **Run with PowerShell** را بزنید.
3. UAC را تأیید کنید.
4. یک‌بار Sign out/Sign in یا Restart کنید.

اسکریپت Restore قبل از هر تغییری از وضعیت موجود در پوشهٔ
`%LOCALAPPDATA%\Microsoft\PowerToys\Workspaces\Backups` بکاپ ایمنی می‌گیرد.

## بررسی بدون تغییر

برای کنترل تنظیمات، `verify-space.ps1` را اجرا کنید. این فایل چیزی را تغییر نمی‌دهد.

## محدودهٔ بازیابی

این بکاپ برای همین حساب ویندوز و مسیرهای فعلی ساخته شده است، از جمله:

- `D:\Github\msh_apps\windows_scripts`
- دو مانیتور 1920×1080 با چیدمان ثبت‌شده
