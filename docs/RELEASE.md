# Android release procedure and publication checklist

Current stage: functional development MVP. No store account, production key or store listing has been created; nothing has been published.

## Signing and artifacts

Debug builds use Android's local development certificate. Release tasks fail unless production signing is configured or the developer explicitly opts into local development signing with RUNPROGRAM_DEVELOPMENT_SIGNING=1. The latter is for testing optimized builds only, never Play submission.

For production, create and protect a keystore outside the repository using the installed JDK keytool. Choose the legal publisher identity and application ownership before generating it. Back up the keystore and recovery information securely; do not send passwords in chat or commit credentials.

Create android/key.properties locally (already ignored):

```properties
storeFile=/absolute/path/outside/repository/upload-keystore.jks
storePassword=YOUR_LOCAL_SECRET
keyAlias=upload
keyPassword=YOUR_LOCAL_SECRET
```

The Gradle production signing configuration consumes this file. Never reuse the development certificate. Configure Google Play App Signing and protect its separate upload key; understand recovery before first publication.

```bash
source scripts/dev-env.sh
bash scripts/check.sh --device DEVICE_SERIAL
flutter build apk --release
flutter build appbundle --release
```

Sideloading artifact: build/app/outputs/flutter-apk/app-release.apk. Play upload artifact: build/app/outputs/bundle/release/app-release.aab. Verify APK signer/certificate with the installed build-tools apksigner, and verify bundle signing with jarsigner. Match the intended certificate fingerprint; successful compilation alone does not prove correct production signing. Test clean installation and upgrades using the same certificate. Debug and production packages with the same application ID but different certificates cannot upgrade each other.

Version is controlled by pubspec.yaml (currently 0.5.1+6). Increment the build number for every uploaded Play build; never reuse it. Keep lockfiles and Gradle wrapper in version control.

## Permissions and execution

- FOREGROUND_SERVICE and FOREGROUND_SERVICE_SPECIAL_USE: user-started interval coaching/timing, including muted operation. The accurate subtype declaration is in the manifest. Play suitability/approval is unresolved; do not claim store acceptance from emulator success.
- WAKE_LOCK: partial CPU wake lock only while the workout is running, released on pause/stop/completion. Benchmark physical-device battery use.
- POST_NOTIFICATIONS: requested on workout start on applicable Android versions. Denial must not cause a permission loop; foreground execution still follows Android notification restrictions.
- VIBRATE: optional transition cue, off by default.
- INTERNET: Flutter debug/profile development only; absent from the main/release manifest. No GPS, sensors, microphone, contacts, or user-files permissions.

References: [Android foreground service types](https://developer.android.com/develop/background-work/services/fgs/service-types), [audio focus](https://developer.android.com/media/optimize/audio-focus), [Play target API requirements](https://support.google.com/googleplay/android-developer/answer/11926878).

Target API 36 is the required new-app baseline rechecked against the official Play policy on October 30, 2026. Recheck current Play policy immediately before submitting. Do not acquire unrelated sensor permissions just to qualify for the health service type, or play silent media to evade service restrictions.

## Privacy disclosure draft

RUN//PROGRAM works offline without an account. It stores selected programs, settings, workout attempts and optional self-reported distance in app-private SQLite. The app has no analytics, advertising, location collection or cloud service. Bundled Kokoro Heart neural English voice clips are included locally; no speech service receives workout data. Android backup/transfer exclusions are explicit, with allowBackup=false; verify manufacturer behavior. Uninstalling, resetting or losing the device can lose history. No export/sync feature is included in this MVP.

Before publication, provide a publisher/contact identity, host an accurate privacy policy, review every shipped dependency, complete Data Safety and applicable health-app declarations, content rating, and foreground-service forms/demo evidence. This draft is not a published policy URL or a claim of completed Play review.

## Remaining release gates

- Independent running-coach review of all original curricula, especially half/marathon entry readiness and weekly volume. Do not claim scientifically validated training or guaranteed race completion.
- Pixel and Samsung physical-device tests, including screen lock, battery saver, several-hour sessions, Bluetooth disconnect, calls, music and podcasts, denied notifications, low storage, process termination and reboot.
- Audible cue clarity, exact threshold latency, restoration of other-app audio after cues, and battery impact. Emulator MediaPlayer-start tests do not establish audible quality or compatibility with every app/headset.
- TalkBack traversal, reduced motion, large text on player/history/settings, contrast, and all initial-setup paths ≤10 interactions. Every eligible recommended goal/ability setup is widget-tested within ten interactions; default and 999-week flows were exercised on the emulator. Observed TalkBack and physical-device UX remain.
- Production signing, release installation/upgrade, final artifact/certificate verification, current target policy, store disclosures and testing-track requirements.
- No publication without explicit user approval.

Development acceptance and remaining gates are tracked in [ACCEPTANCE.md](ACCEPTANCE.md); executed evidence is in [VALIDATION.md](VALIDATION.md). The privacy disclosure draft is [PRIVACY.md](PRIVACY.md).
