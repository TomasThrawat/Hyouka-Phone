# هاتف

تطبيق Dialer Flutter/Dart بواجهة سوداء بالكامل، يقتصر على لوحة الأرقام والمكالمات الحديثة مع بحث بسيط.

## الوظائف

- لوحة أرقام من 0 إلى 9 و * و # بدون حروف إنجليزية تحت الأرقام.
- أرقام أزرار صغيرة ومنخفضة داخل الواجهة.
- عند اختيار رقم من المكالمات الحديثة يظهر زرا اتصال وإلغاء.
- المكالمات الحديثة تُحمّل من سجل المكالمات على Android، مع إمكانية البحث بالاسم أو الرقم وإعادة الاتصال.
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
