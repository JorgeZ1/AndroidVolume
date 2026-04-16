# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Floating Volume is an Android app (Flutter/Dart) that renders a draggable floating volume slider overlay anywhere on the screen. It targets F-Droid as the primary distribution channel and must produce reproducible builds.

## Commands

### Code Generation (required before building after any Pigeon changes)
```bash
dart run pigeon --input pigeons/native_api.dart
dart run pigeon --input pigeons/native_events.dart
```
Generated files land in `lib/generated/` (Dart) and `android/app/src/main/kotlin/generated/` (Kotlin). Never edit generated files manually.

### Build
```bash
flutter build apk --release
```
Requires `android/key.properties` with signing credentials. Build must run from inside the `.git`-containing directory — not a shallow clone or tarball.

### Reproducible Build (F-Droid-compatible)
```bash
docker build -t floating_volume .
docker run --rm -v $(pwd):/tmp/app floating_volume /tmp/app/build.py
```

### Analyze & Test
```bash
flutter analyze
flutter test
```

## Architecture

The app has three layers that communicate in one direction: Flutter UI → BLoC state → Kotlin Android Service.

### Flutter ↔ Kotlin Bridge (Pigeon)
- **`pigeons/native_api.dart`** defines `NativeApi` — imperative calls from Dart into Kotlin (`startService`, `stopService`, `showFloatingVolume`, `hideFloatingVolume`, `setMaxVolume`, `setMinVolume`, `showToast`).
- **`pigeons/native_events.dart`** defines event streams from Kotlin back to Dart (`serviceStatus`, `floatingVolumeVisibility`).
- Any change to these pigeon definitions requires re-running the code generation commands above.

### Flutter State (BLoC)
Located in `lib/src/bloc/`:
- **`PermissionsBloc`** — tracks three Android permissions: system alert window (overlay), notification, and battery optimization ignore. Drives the permissions screen.
- **`StatusBloc`** — tracks service running state and widget visibility by subscribing to `NativeEvents` streams.
- **`ThemeBloc`** — persists theme selection (light/dark/system) to `SharedPreferences`.

### Flutter UI
- `lib/main.dart` — entry point.
- `lib/src/app.dart` — `MaterialApp` with BLoC providers and Material 3 theming.
- `lib/src/screens/home.dart` — main screen; shows widget style selector and start/stop toggle.
- `lib/src/screens/permissions.dart` — permission request UI, shown before home when permissions are missing.
- `lib/src/widget_settings.dart` — `WidgetStyle` enum (9 styles) and their in-app preview widgets.

### Android Service (Kotlin)
Located in `android/app/src/main/kotlin/`:
- Manages the `WindowManager` overlay that renders the floating slider.
- Contains its own BLoC-style classes under `bloc/` for volume level, position, orientation, and service status.
- Communicates back to Dart via Pigeon event channels.

### Monetization
- `lib/src/services/ad_service.dart` — AdMob rewarded ads gate the four premium widget styles (RGB Aurora, RGB Neon, Cosmic, Lava) behind a 3-day unlock. The unlock expiry is stored in `SharedPreferences`.

## Key Notes

- **Freezed** is used for immutable BLoC state models. Run `dart run build_runner build` if you add or change `@freezed` classes.
- The app is **GPL v3**; keep all additions compatible.
- Ad unit IDs in `ad_service.dart` and the AdMob App ID in `AndroidManifest.xml` are placeholders — do not replace them with real IDs in commits.
