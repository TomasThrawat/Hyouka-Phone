# هاتف

تطبيق هاتف Flutter/Dart بواجهة سوداء بالكامل.

## الوظائف

- لوحة أرقام من 0 إلى 9 و * و # بدون حروف إنجليزية تحت الأرقام.
- أرقام أزرار صغيرة ومنخفضة داخل الواجهة.
- إظهار جهات الاتصال المطابقة للرقم المكتوب.
- عند اختيار جهة اتصال أو رقم من المكالمات الحديثة يظهر زرا اتصال وإلغاء.
- المكالمات الحديثة تعمل بجلسة التطبيق وتفتح تطبيق الهاتف عبر tel URI.
- اسم التطبيق: هاتف
- Android applicationId: com.dailer.phone
- إصدار Android المرفوع إلى GitHub Actions: arm64-v8a فقط.

## Build

```bash
flutter pub get
flutter analyze
flutter test
flutter build apk --release --split-per-abi --target-platform android-arm64
```
