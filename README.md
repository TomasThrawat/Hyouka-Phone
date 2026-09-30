# Hyouka Phone

Flutter/Dart phone dialer with a Material 3 dark interface.

## Features

- Dial keypad for 0-9, * and #
- Delete and clear controls
- Opens the Android phone app with a `tel:` URI
- Recent calls for the current app session
- Call again from recents
- Responsive keypad layout that avoids vertical overflow on compact screens
- Flutter widget tests
- Flutter static analysis in CI
- Debug APK build in GitHub Actions

## Run

```bash
flutter pub get
flutter run
```

## Build

```bash
flutter test
flutter analyze
flutter build apk --debug
```
