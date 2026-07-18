# Changelog

## 2026-07-18

- تبدیل کامل برنامه به Window-only swap؛ حذف Reset، Workspace normalization و FancyZones mutation از runtime.
- حذف State و تأخیر retry از مسیر موفق برای Swap سریع‌تر.
- تغییر Toggle به Window-only swap؛ Workspace و FancyZones Layout هر مانیتور ثابت می‌ماند.
- حذف وابستگی Toggle به PowerToys و FancyZones CLI؛ این وابستگی‌ها فقط برای Reset باقی مانده‌اند.
- اصلاح Toggle: حذف کامل اجرای Workspace از Hotkey و Swap مستقیم محتوای فعلی دو مانیتور.
- افزودن retry برای پنجره‌هایی که اولین درخواست Move را موقتاً رد می‌کنند.
- جایگزینی Swap hardcoded با معماری ماژولار AutoHotkey v2.
- افزودن Workspace normalization با stable polling.
- افزودن FancyZones layout transaction و verification.
- افزودن هندسه نسبی، atomic move و پشتیبانی minimized/maximized.
- افزودن state machine، rollback، logging، diagnostic، calibration و reset.
- حفظ نسخه قبلی در پوشه `legacy`.
