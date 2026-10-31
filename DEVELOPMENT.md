# Development environment

Installed October 30, 2026 on Pop!_OS 24.04 LTS, Linux x86_64. Current functional MVP commands and limits are in README.md and docs/VALIDATION.md; the setup/foundation records below are historical. The user subsequently authorized the first Android app foundation. Outstanding curriculum and background-service decisions in DESIGN.md still require validation.

## Installed tools

| Component | Installed version | Location |
|---|---|---|
| Flutter stable | 3.47.9, commit c197ca5199e9ee5661e865596c9c07294dfab51c | ~/Development/flutter |
| Dart / DevTools | 3.13.7 / 2.60.0 | Included in Flutter |
| Android Studio Rabbit 2 | 2026.2.2, AI-262.10968.63.2622.16730706 | ~/Development/android-studio |
| Java JDK / javac | JetBrains OpenJDK 25.0.4 | ~/Development/android-studio/jbr |
| Studio Flutter / Dart plugins | 97.0.0 / 510.0.0 | ~/.local/share/Google/AndroidStudio2026.2.2 |
| Android command-line tools | 22.0, archive 15859902 | ~/Android/Sdk/cmdline-tools/latest |
| Android platform | API 36, revision 2 | ~/Android/Sdk/platforms/android-36 |
| Build tools | 36.0.0 | ~/Android/Sdk/build-tools/36.0.0 |
| Platform tools / adb | 37.0.1 | ~/Android/Sdk/platform-tools |
| Android Emulator | 37.2.13 | ~/Android/Sdk/emulator |
| Google APIs emulator image | API 36 x86_64, revision 7 | ~/Android/Sdk/system-images |
| NDK / Android CMake | 28.2.13676358 / 3.22.1 | ~/Android/Sdk/ndk and cmake |
| Sample Gradle / AGP / Kotlin plugin | 9.3.1 / 9.1.0 / 2.4.0 | Project wrapper and downloaded Gradle cache |

Flutter includes Dart; Android Studio includes Java and Android/Kotlin IDE support. Gradle and the Kotlin compiler are resolved through each project's pinned wrapper/plugins, not separately installed global compilers. The NDK includes native Clang. Linux desktop Flutter tools and a separate VS Code installation are unnecessary for this Android project.

## Start a development session

New interactive Bash terminals automatically source ~/.config/runprogram/dev-env.sh. In an existing terminal:

```bash
cd /home/dwilson/Documents/JoggingApp
source scripts/dev-env.sh
flutter --version
java -version
flutter doctor -v
```

The environment sets ANDROID_HOME, JAVA_HOME, and PATH. Flutter is explicitly configured to use this SDK, Studio directory, and JDK. Flutter telemetry is disabled. Web and Linux desktop targets are disabled in the user's Flutter configuration; re-enable only if needed with `flutter config --enable-web --enable-linux-desktop`.

Open **Android Studio** from the application menu, or run:

```bash
~/Development/android-studio/bin/studio.sh
```

On first GUI launch, complete any welcome/setup screens using the existing SDK at /home/dwilson/Android/Sdk. No account or AI assistant is needed. Under Settings → Languages & Frameworks → Flutter, select /home/dwilson/Development/flutter if not detected. Flutter and Dart plugins have already been installed. GUI first-run settings have not been interactively validated.

## Emulator and physical devices

The `RunProgram_API_36` AVD uses a Pixel 7 device profile and the API 36 Google APIs x86_64 image. Start through Studio's Device Manager or:

```bash
source scripts/dev-env.sh
emulator -accel-check
emulator -avd RunProgram_API_36
```

For headless automation, in a separate terminal:

```bash
emulator -avd RunProgram_API_36 -no-window -no-audio -no-boot-anim -no-snapshot -gpu swiftshader
```

Then use `adb devices -l` and `flutter devices`. A device appearing in adb is not proof that Android has finished booting: `adb -s emulator-5554 shell getprop sys.boot_completed` must return `1`. Serial numbers can differ when multiple emulators run. Shut down a test instance with `adb -s emulator-5554 emu kill`.

Host-level `emulator -accel-check` verified usable KVM. The Codex sandbox does not expose /dev/kvm; run emulator/adb commands with host execution approval when working through Codex. Do not confuse sandbox visibility with a host virtualization failure.

For a physical Android phone: enable Developer options and USB debugging, connect a data-capable USB cable, unlock the phone, approve its RSA authorization dialog, then check `adb devices -l`. Select its serial explicitly with `flutter run -d SERIAL`. No physical device was connected during setup. Physical-device USB rules may require the prerequisite script below. Real phones remain required for background/audio reliability validation.

## Reproduce the installation

Use the official [Flutter installation](https://docs.flutter.dev/install/manual), [Flutter Android setup](https://docs.flutter.dev/platform-integration/android/setup), and [Android Studio download](https://developer.android.com/studio) documentation. Downloads and dependency resolution require internet; offline app behavior does not mean a fresh build environment is offline.

1. Check disk space and x86_64 architecture. On this workstation there was over 700 GB free before setup.
2. Clone Flutter stable and pin the recorded commit:

   ```bash
   mkdir -p ~/Development
   git clone --branch stable https://github.com/flutter/flutter.git ~/Development/flutter
   git -C ~/Development/flutter checkout c197ca5199e9ee5661e865596c9c07294dfab51c
   ~/Development/flutter/bin/flutter --disable-analytics
   ```

3. Download and checksum-verify the Studio and command-line archives listed below. Extract Studio under ~/Development. Extract the command-line tools so sdkmanager is at ~/Android/Sdk/cmdline-tools/latest/bin/sdkmanager, not inside an extra cmdline-tools directory.
4. Run `source scripts/dev-env.sh`, then configure:

   ```bash
   flutter config --android-sdk "$ANDROID_HOME"
   flutter config --android-studio-dir "$RUNPROGRAM_TOOLS/android-studio"
   flutter config --jdk-dir "$JAVA_HOME"
   sdkmanager 'platform-tools' 'platforms;android-36' 'build-tools;36.0.0' \
     'emulator' 'system-images;android-36;google_apis;x86_64' \
     'ndk;28.2.13676358' 'cmake;3.22.1'
   flutter doctor --android-licenses
   flutter precache --android
   ~/Development/android-studio/bin/studio.sh installPlugins io.flutter Dart
   avdmanager create avd --name RunProgram_API_36 \
     --package 'system-images;android-36;google_apis;x86_64' --device pixel_7
   python3 scripts/configure-user-tools.py
   flutter doctor -v
   ```

   Read and accept the SDK license prompts. Current SDK tools warn that sdkmanager is deprecated in favor of `android sdk`; the installed sdkmanager remains functional and compatible with Flutter's checks. SDK package aliases such as platform-tools/emulator and marketplace plugin IDs resolve current versions; consult the table for the versions actually tested, rather than assuming future installs are identical.

5. If required libraries are missing on a fresh Pop!_OS/Ubuntu 24.04 installation:

   ```bash
   bash scripts/install-linux-prerequisites.sh
   ```

   This invokes sudo in your terminal and may ask for your password. It was **not executed successfully during setup**: noninteractive sudo requires a password. Existing host libraries support the tools tested here, and KVM is already usable. Do not run it solely to fix a sandbox-only /dev/kvm absence. If host KVM truly fails, verify virtualization in firmware, load the appropriate Intel/AMD KVM module, and grant the user KVM access; group changes require a new login.

Archives used, both checked against Google's published SHA-256 values before extraction:

| Archive | Source | SHA-256 |
|---|---|---|
| Studio Rabbit 2 Linux | [Google download](https://edgedl.me.gvt1.com/android/studio/ide-zips/2026.2.2.8/android-studio-rabbit2-linux.tar.gz) | b47fdcc0703019618a7afd5ad1822cafc5de66bed984640be2977a0fdb538304 |
| Command-line tools Linux | [Google download](https://dl.google.com/android/repository/commandlinetools-linux-15859902_latest.zip) | 4e4c464f145a7512b57d088ac6c278c03c9eea610886b35a5e0804e74eedf583 |

Flutter's release-metadata archive URL returned HTTP 404 during setup; the official GitHub stable branch was used instead and its exact revision recorded. Downloaded archives remain in ~/.cache/runprogram-setup. Build dependencies are cached in ~/.gradle, ~/.pub-cache, and Flutter's SDK cache. Avoid upgrading individual components during a feature change without rerunning the smoke checks.

## Build, test, and install workflow

The RUN//PROGRAM Flutter app is at the repository root. Source scripts/dev-env.sh first, then run:

```bash
flutter pub get
flutter analyze
flutter test
flutter build apk --debug
flutter run -d DEVICE_SERIAL
adb -s DEVICE_SERIAL install -r build/app/outputs/flutter-apk/app-debug.apk
```

Use the Gradle wrapper inside android/ for native tests, e.g. `./gradlew testDebugUnitTest`; add the real module-specific tasks once native tests exist. Dart widget tests alone do not test the Kotlin service.

Release workflow, after production signing has been configured:

```bash
flutter build apk --release
flutter build appbundle --release
```

Outputs normally appear under build/app/outputs/flutter-apk/ and build/app/outputs/bundle/release/. A successful release command does not prove production signing: Flutter templates can use debug signing until explicitly configured. No production key, signing config, store account, or AAB has been created. Never commit keys/passwords; .gitignore excludes common signing files. Play publication remains separately authorized.

## Verification record

Disposable sample: /tmp/runprogram-toolchain-smoke, project name toolchain_smoke. It is not part of RUN//PROGRAM and may disappear when /tmp is cleaned.

- Flutter version and Android Studio version commands succeeded.
- Flutter and Dart IDE plugin installation succeeded; installed versions were read from their plugin descriptors.
- Google archive checksums matched before extraction.
- Android platform/build/emulator/NDK/CMake packages installed; SDK licenses accepted.
- `flutter analyze`: no issues in the generated sample.
- `flutter test`: one generated widget test passed.
- Host KVM acceleration check passed.
- `flutter build apk --debug`: succeeded in 115.2 seconds; output /tmp/runprogram-toolchain-smoke/build/app/outputs/flutter-apk/app-debug.apk.
- `flutter doctor -v`: **No issues found** with Android tooling and the API 36 emulator connected. Full snapshot: [toolchain-doctor.txt](toolchain-doctor.txt). Installed SDK snapshot: [toolchain-sdk-packages.txt](toolchain-sdk-packages.txt).
- Emulator boot: `sys.boot_completed` returned `1`.
- `adb install -r`: Success. `am start -W`: Status ok; com.example.toolchain_smoke/.MainActivity became the top resumed activity and had a running process.
- Shell scripts passed `bash -n`; user-configuration Python script compiled and executed successfully.

The initial build emitted Java native-access and SDK XML-version warnings but completed successfully. Treat these as recorded tool-version warnings; investigate if later upgrades turn them into failures. No additional system packages were necessary for the verified build and headless emulator path. A visible Studio GUI session, emulator host audio, physical USB connection, release signing, and release APK/AAB builds remain unverified. The headless test emulator was shut down after verification; the AVD remains available.

The initial foundation checks above did not include running-coach functionality, locked-screen audio, or timer recovery; current results are documented in docs/VALIDATION.md. iOS builds require macOS/Xcode and are not configured on this Linux host.

## RUN//PROGRAM foundation verification

The actual project at /home/dwilson/Documents/JoggingApp was subsequently scaffolded and verified on October 30, 2026:

- `flutter analyze`: no issues.
- `flutter test`: two passing tests, covering the welcome screen and a 320×568 viewport with 200% text scaling.
- `flutter build apk --debug`: succeeded.
- `flutter run -d emulator-5554`: installed and launched the app on Android 16 / API 36.
- Hot reload (`r`): completed successfully; the Flutter reassemble reported 68 ms.
- APK metadata: com.joggingapp.runprogram, RUN//PROGRAM, version 0.1.0+1, minSdk 26, target/compile SDK 36.
- Activity inspection: com.joggingapp.runprogram/.MainActivity was the top resumed activity.
- [First-screen screenshot](docs/screenshots/hello-world.png) captured and visually inspected; no clipping in the emulator's default viewport.

The emulator was left open for the user to inspect after verification. These checks establish the app foundation, not training or background-coaching reliability. The repository is initialized on main, with the user-supplied Git identity configured locally for the initial foundation commit.
