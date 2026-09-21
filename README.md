# practsearch

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Flutter version (FVM)

This project is pinned to Flutter **3.38.4** (Dart 3.10.3) via [FVM](https://fvm.app).
The pin lives in `.fvmrc`, so the same SDK is used on every machine regardless of
the globally installed Flutter version.

### One-time setup

Windows (PowerShell):

```powershell
dart pub global activate fvm
```

macOS / Linux:

```sh
brew tap leoafarias/fvm && brew install fvm   # or: dart pub global activate fvm
```

Make sure `fvm` is on your PATH (`%LOCALAPPDATA%\Pub\Cache\bin` on Windows).

### Per-clone setup

```sh
fvm install      # downloads Flutter 3.38.4 into the FVM cache
fvm flutter pub get
```

### Daily use

Prefix Flutter/Dart commands with `fvm`:

```sh
fvm flutter run
fvm flutter build apk
fvm dart format .
```

VS Code is already configured (`.vscode/settings.json` points
`dart.flutterSdkPath` at `.fvm/flutter_sdk`). In Android Studio / IntelliJ set
the Flutter SDK path to `<project>/.fvm/flutter_sdk`.
