# Android & Flutter Release Tool

فرمان سراسری `release` برای ساخت APK نسخهٔ Release در پروژه‌های Flutter و Native Android است.

## نصب روی سیستم جدید

پوشهٔ `android-release` را همراه همهٔ فایل‌هایش به سیستم مقصد منتقل کنید و سپس یکی از این دو روش را اجرا کنید:

```cmd
install.cmd
```

یا از PowerShell:

```powershell
.\install.ps1
```

نصاب فایل‌های ابزار را به مسیر زیر کپی می‌کند و آن را به User PATH اضافه می‌کند؛ دسترسی Administrator لازم نیست:

```text
%LOCALAPPDATA%\Programs\AndroidReleaseTool
```

پس از نصب، ترمینال‌های باز را ببندید و دوباره باز کنید.

## پیش‌نیازها

- Git با `user.name` و `user.email` تنظیم‌شده
- JDK و متغیر `JAVA_HOME` برای پروژه‌های Android
- Flutter SDK برای پروژه‌های Flutter
- Gradle Wrapper یعنی `gradlew.bat` داخل پروژه‌های Native Android

نصاب وجود Git، Java و Flutter را گزارش می‌کند. نبود Flutter مانع نصب ابزار نمی‌شود و فقط ساخت پروژه‌های Flutter را غیرممکن می‌کند.

## استفاده

در ریشهٔ پروژه یا یکی از زیرپوشه‌های آن اجرا کنید:

```cmd
release 1.0.1
```

نسخه باید دقیقاً در قالب `major.minor.patch` باشد.

ابزار این مراحل را انجام می‌دهد:

1. نوع پروژه را از روی `pubspec.yaml` یا `gradlew.bat` تشخیص می‌دهد.
2. در Flutter، نسخهٔ `pubspec.yaml` را به `1.0.1+N` تغییر می‌دهد و build number را یک واحد افزایش می‌دهد.
3. در Native Android، `versionName` را تغییر می‌دهد و `versionCode` عددی را یک واحد افزایش می‌دهد. فایل‌های `build.gradle` و `build.gradle.kts` پشتیبانی می‌شوند.
4. فرمان مناسب را اجرا می‌کند:

   ```text
   flutter build apk --release
   gradlew.bat assembleRelease
   ```

5. APK را با این قالب در Downloads ویندوز قرار می‌دهد:

   ```text
   appName_1.0.1.apk
   ```

6. فقط فایل نسخه را با این پیام commit می‌کند:

   ```text
   version: 1.0.1
   ```

7. تگ محلی `1.0.1` را ایجاد می‌کند.
8. پس از موفقیت کامل، یک Windows notification شامل نسخه و مسیر APK نمایش می‌دهد.

ابزار commit و tag را به remote پوش نمی‌کند. در صورت نیاز بعد از موفقیت اجرا کنید:

```cmd
git push
git push origin 1.0.1
```

## قواعد ایمنی

- Git working tree باید قبل از اجرا کاملاً clean باشد؛ تغییرات موجود را commit یا stash کنید.
- اگر تگ نسخه از قبل وجود داشته باشد، عملیات شروع نمی‌شود.
- اگر build یا مرحله‌ای پیش از commit شکست بخورد، فایل نسخه و APK مقصد به حالت قبلی برمی‌گردند.
- فایل‌های `pubspec.yaml` و Gradle با line ending ویندوزی CRLF و یونیکسی LF هر دو پشتیبانی می‌شوند.
- برای Native Android باید دقیقاً یک application module قابل تشخیص وجود داشته باشد و `versionCode` یک عدد مستقیم باشد. تعریف مستقیم plugin و Gradle Version Catalog مانند `alias(libs.plugins.android.application)` پشتیبانی می‌شوند.
- اگر چند APK خروجی ساخته شود، ابزار فایل Release اصلی و جدیدتر را انتخاب و هشدار چاپ می‌کند.

## نام برنامه

- Flutter: ابتدا `android:label` در Manifest یا مقدار متناظر `@string/app_name`، سپس `CFBundleDisplayName`/`CFBundleName` در iOS، و در نهایت مقدار `name` در `pubspec.yaml`
- Android: ابتدا `android:label` در Manifest و مقدار متناظر در `strings.xml`؛ در صورت نبودن آن، `rootProject.name` یا نام پوشهٔ پروژه

کاراکترهای غیرمجاز نام فایل ویندوز به `_` تبدیل می‌شوند.

## حذف

```cmd
uninstall.cmd
```

یا:

```powershell
.\uninstall.ps1
```

حذف‌کننده فایل‌های نصب‌شده و ورودی PATH مربوط به ابزار را پاک می‌کند. فایل‌های این مخزن و APKهای Downloads حذف نمی‌شوند.

## فایل‌های پکیج

- `release.cmd`: فرمان قابل اجرا از CMD و PowerShell
- `release.ps1`: منطق تشخیص پروژه، نسخه‌گذاری، build، خروجی و Git
- `install.cmd` و `install.ps1`: نصب برای کاربر فعلی
- `uninstall.cmd` و `uninstall.ps1`: حذف نصب
