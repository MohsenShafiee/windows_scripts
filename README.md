# Windows Scripts

این مخزن بر اساس کاربرد هر اسکریپت سازمان‌دهی شده است:

```text
apps/
├── desktop-helpers/    ابزارهای عمومی دسکتاپ و ماوس
├── potplayer/          فرمان‌های اختصاصی PotPlayer
├── space-workspace/    اجرای خودکار و بکاپ Workspace با نام space
└── swap-monitors/      برنامهٔ جابه‌جایی پنجره‌ها بین دو مانیتور
```

## مسیرهای اصلی

- [SwapMonitors](apps/swap-monitors/README.md): برنامهٔ ماژولار AutoHotkey، تنظیمات، تست‌ها و ابزارهای تشخیصی.
- [Desktop Helpers](apps/desktop-helpers/README.md): نمایش فایل‌های مخفی، Maximize/Restore زیر ماوس و Middle Paste.
- [PotPlayer](apps/potplayer/README.md): کپی یا حذف فایل در حال پخش.
- [Space Workspace](apps/space-workspace/README.md): اسکریپت‌های Startup، چیدمان پنجره‌ها، بستهٔ بازیابی و آرشیو ZIP.

هر برنامه فایل‌های مرتبط با خودش را در همان پوشه نگه می‌دارد تا تنظیمات، مستندات، تست‌ها و بکاپ‌ها با برنامه‌های دیگر مخلوط نشوند.
