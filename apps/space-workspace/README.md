# Space Workspace

فایل‌های مربوط به PowerToys Workspace با نام `space` در سه بخش نگه‌داری می‌شوند:

- `runtime/`: اسکریپت‌های Startup و تثبیت چیدمان، Shortcut و لاگ‌های فعلی.
- `backup/`: بستهٔ قابل‌بازیابی شامل تنظیمات Workspace، Task Scheduler و Windows Terminal.
- `archive/`: نسخهٔ ZIP آرشیوشدهٔ بستهٔ بکاپ.

## اجرای دستی

```powershell
.\runtime\msh-startup.ps1
.\runtime\space-admin-layout.ps1 -ArrangeOnce
```

برای بازیابی کامل، `backup/restore-space.ps1` را با PowerShell اجرا کنید. برای بررسی بدون تغییر، از `backup/verify-space.ps1` استفاده کنید.

> مسیر Taskهای ذخیره‌شده به پوشهٔ جدید `apps/space-workspace/runtime` اشاره می‌کند. اگر Taskهای قبلی هم‌اکنون در ویندوز ثبت شده‌اند، آن‌ها را دوباره از بستهٔ بکاپ ثبت کنید تا مسیر جدید اعمال شود.
