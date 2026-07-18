# Dual Monitor Window Swap

این اسکریپت AutoHotkey v2 فقط محتوای فعلی دو مانیتور را جابه‌جا می‌کند. Workspace، FancyZones Layout، تنظیمات Display، Primary Monitor، Taskbar و Virtual Desktop هیچ تغییری نمی‌کنند.

## استفاده

- اجرا: `SwapMonitors.ahk`
- جابه‌جایی سریع تمام پنجره‌ها: `Ctrl + Shift + Middle Click`
- گزارش تشخیصی خواندنی: `Ctrl + Alt + Shift + D`

در هر بار فشردن Hotkey، پنجره‌های مانیتور A به B و پنجره‌های B به A منتقل می‌شوند. موقعیت و اندازه نسبی حفظ می‌شود؛ روی مانیتورهای هم‌اندازه انتقال دقیق است. پنجره‌های minimized، maximized و fullscreen نیز با حفظ حالت منتقل می‌شوند.

پنجره‌های معمولی با یک حرکت نرم و سریع ۱۸۰ میلی‌ثانیه‌ای بین دو مانیتور جابه‌جا می‌شوند. فریم‌های میانی مستقیماً با compositor ویندوز هماهنگ می‌شوند و فقط فریم آخر redraw می‌شود. این حرکت با `EnableWindowAnimation=0` غیرفعال و با `WindowAnimationDurationMs` تنظیم می‌شود. پنجره‌های fullscreen و minimized برای حفظ پایداری بدون اسلاید منتقل می‌شوند.

نشانگر جداگانه به‌صورت پیش‌فرض خاموش است تا حرکت پنجره‌ها بدون مکث اضافه اجرا شود. با `EnableSwapAnimation=1` می‌توان آن را فعال کرد و مدت آن با `AnimationDurationMs` قابل تنظیم است.

مسیرهای Reset و Calibration غیرفعال‌اند و PowerToys یا FancyZones CLI اصلاً توسط مسیر Swap فراخوانی نمی‌شوند.

## پیکربندی

فقط `DeviceName` دو مانیتور در `config/config.ini` ضروری است:

```ini
[MonitorA]
DeviceName=\\.\DISPLAY2

[MonitorB]
DeviceName=\\.\DISPLAY1
```

تنظیمات مهم دیگر:

- `Hotkey`: کلید جابه‌جایی.
- `IncludeMinimizedWindows`، `IncludeMaximizedWindows` و `IncludeFullscreenWindows`: انواع پنجره‌های قابل انتقال.
- `UseAtomicWindowMove=1`: انتقال گروهی سریع پنجره‌های معمولی.
- `RestoreActiveWindow=1`: حفظ Focus فعلی.
- `Exclusions`: پردازش‌ها و کلاس‌هایی مانند Desktop و Taskbar که نباید منتقل شوند.

## تست

```powershell
& 'C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe' .\tests\SmokeTest.ahk
& 'C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe' .\tests\WindowOnlySwapTest.ahk
```

تست fullscreen به دو مانیتور متصل نیاز دارد:

```powershell
& 'C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe' .\tests\FullscreenIntegrationTest.ahk
```

برای اعمال تغییرات پس از ویرایش، نمونه در حال اجرای `SwapMonitors` را ببندید و دوباره اجرا کنید.
