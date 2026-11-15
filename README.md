# Parvaz Flutter (نیتیو، بدون WebView)

## ۱) سمت سرور (یک‌بار)
فایل‌های `backend/api.php` و `backend/sess.php` را جایگزین فایل‌های هم‌نام روی سرور کنید.
تغییرات: عملیات `app_boot` (دریافت csrf و تنظیمات برای اپ) و پذیرش/برگرداندن هدر `X-Session-ID`.
سایت وب بدون تغییر کار می‌کند.

## ۲) آدرس سرور
در `lib/api_service.dart` مقدار `defaultBase` را به آدرس سایت (با `/` در انتها) تغییر دهید.
(داخل اپ هم با نگه‌داشتن طولانی روی لوگوی صفحه‌ی ورود قابل تغییر است.)

## ۳) ساخت APK با گیت‌هاب
پوشه را در یک ریپوی گیت‌هاب بریزید → تب Actions → «Build APK» → Run workflow → فایل `parvaz-apk` را دانلود کنید.
(برای تست روی کامپیوتر: `flutter create --platforms=android .` سپس `flutter run`.)

## فونت
فونت پیش‌فرض سیستم استفاده می‌شود (همان رفتار سایت که Vazirmatn را ندارد و به Tahoma/سیستم برمی‌گردد).
برای Vazirmatn فایل ttf را در `assets/fonts` بگذارید و در pubspec بخش `fonts:` اضافه کنید.
