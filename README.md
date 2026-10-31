# RUN//PROGRAM

An offline-first Android running coach with a dark terminal-inspired interface. Application ID: `com.joggingapp.runprogram`. Minimum Android: 8.0 / API 26; target SDK: 36.

## Functional development MVP

- Default 5K setup in two actions through workout start; returning users start from Home in one action.
- Goal/ability/timeline selection, with prerequisite checks and conservative redirects for longer-distance goals.
- Structured walk/run, easy, long, recovery, and taper sessions.
- Native Android foreground-service timer, monotonic elapsed time, pause/resume, confirmed early stop, and conservative interrupted-process recovery.
- Bundled offline voice coaching, transient audio focus/ducking requests, optional vibration, and a mute control.
- SQLite progress, completion history, repeated workouts/weeks, program pause/restart, and optional self-reported distance.
- Central dark/green theme and optional low-intensity rain, disabled during workouts and reduced-motion mode.

No account, backend, GPS, analytics, ads, subscription, music player, or wearable integration. No third-party runtime packages beyond Flutter/Android platform libraries.

**Development release:** original curricula are not independently validated. Half/marathon prerequisites and templates require qualified review before production release. Finishing a timed workout or program does not prove completion of a measured race distance. Read [curriculum assumptions](docs/CURRICULUM.md) and [release checklist](docs/RELEASE.md).

## Develop and test

Installed versions, shell/IDE setup, and device instructions: [DEVELOPMENT.md](DEVELOPMENT.md).

```bash
source scripts/dev-env.sh
flutter pub get
flutter analyze
flutter test
./android/gradlew -p android testDebugUnitTest
flutter build apk --debug
emulator -avd RunProgram_API_36
# In another configured terminal:
flutter run -d emulator-5554
```

Run the full checks with `bash scripts/check.sh --device` when an emulator/device is connected; omit `--device` for Dart/native unit tests and a debug build only. The emulator tests exercise real SQLite, foreground execution, locked-screen timing, audio focus, bundled playback, and completion/progression. Use a disposable emulator/profile: persistence tests use a separate database and service tests restore saved documents, but instrumentation installs may reset test app data. End active workouts before running them.

During `flutter run`: `r` hot reloads, `R` restarts, `d` detaches. Open the repository root in Android Studio for Flutter, or android/ for native Kotlin work.

## Install

Debug APK: `build/app/outputs/flutter-apk/app-debug.apk`.

```bash
adb -s DEVICE_SERIAL install -r build/app/outputs/flutter-apk/app-debug.apk
```

For local release-mode testing only:

```bash
RUNPROGRAM_DEVELOPMENT_SIGNING=1 flutter build apk --release
RUNPROGRAM_DEVELOPMENT_SIGNING=1 flutter build appbundle --release
```

These explicit test builds use the development certificate and **must not be submitted to Play**. Production signing requires an ignored android/key.properties file referencing a protected external keystore; see [release procedure](docs/RELEASE.md). Release APK and Play AAB are different artifacts. No app-store publication or account creation is performed by these commands.

## Code map

- lib/src/training/: pure schedule generation and serialized curriculum definitions.
- lib/src/data/: native bridge and UI state snapshots; the UI is not the timer authority.
- lib/src/screens/: setup, dashboard, program, history, settings, and player.
- lib/src/theme/: centralized visual tokens.
- android/app/src/main/kotlin/: interval engine, foreground service, audio, SQLite, progression, and bridge.
- test/: schedule and widget tests; Android unit/device tests live under android/app/src/.

See [verification record](docs/VALIDATION.md) for actual results and remaining device/release checks. The original [design](DESIGN.md) records research and proposed architecture; deviations implemented for the prototype are documented in the curriculum and release notes.
