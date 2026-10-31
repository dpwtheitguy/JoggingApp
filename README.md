# RUN//PROGRAM

An offline-first Android running coach with an original terminal-inspired cyberpunk interface. Planned goals: 5K, 10K, half marathon, and marathon, subject to appropriate readiness checks and curriculum review.

Current status: the first Android app foundation. The app displays a dark/green Hello World screen under the RUN//PROGRAM name. Android application ID: `com.joggingapp.runprogram`. Minimum Android: 8.0 (API 26).

Read the [initial design package](DESIGN.md) for reference research, architecture, training model, screen flows, Android reliability plan, roadmap, and review decisions. The app foundation is authorized; curriculum and background-service decisions still need validation before those features ship.

From this directory:

```bash
source scripts/dev-env.sh
flutter pub get
flutter analyze
flutter test
flutter build apk --debug
emulator -avd RunProgram_API_36
# In another terminal, with the environment sourced:
flutter run -d emulator-5554
```

During `flutter run`, press `r` for hot reload, `R` for hot restart, or `d` to detach and leave the app running. Android Studio opens this directory as a Flutter project; open android/ separately when working on native Kotlin code.

The debug APK is `build/app/outputs/flutter-apk/app-debug.apk`. To sideload it:

```bash
adb -s DEVICE_SERIAL install -r build/app/outputs/flutter-apk/app-debug.apk
```

Project layout: lib/main.dart starts the app; lib/src/app.dart owns application setup; lib/src/theme/ owns theme tokens; lib/src/screens/ owns screens; android/ contains the native Kotlin host; test/ contains widget tests. No third-party runtime packages are included. Commit pubspec.lock and the Gradle wrapper to preserve the dependency baseline.

Known limits: this is a Hello World foundation, with no training generator, timer, coaching, history, or persistence yet. Release signing is not configured; the template release variant currently uses a development key. INTERNET permission exists only in debug/profile manifests for Flutter debugging. Native launch colors mirror the Flutter theme. Digital rain and other effects are deferred.

See [DEVELOPMENT.md](DEVELOPMENT.md) for installed tool versions, Android Studio setup, shell environment, emulator/device usage, build/test commands, APK installation, signing boundaries, and actual verification results. No cloud account, GPS, analytics, advertising, or subscription is planned.
