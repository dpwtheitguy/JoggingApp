# Validation record — October 30, 2026

Development MVP, tested on the API 36 Pixel 7-profile x86_64 emulator on this workstation. This is not a claim that all physical-device or store-release acceptance gates are satisfied.

## Executed checks

| Check | Result |
|---|---|
| Flutter static analysis | No issues |
| Dart schedule/widget tests | 9 passing |
| Kotlin interval/progression unit tests | 14 passing |
| Android emulator instrumentation tests | 13 passing |
| Debug APK build/install/launch | Passed |
| Optimized development-signed APK build | Passed |
| Development-signed AAB build | Passed |
| APK signature verification | Passed; explicitly Android Debug certificate |
| AAB signature check | jarsigner reports jar verified; self-signed/development certificate and JDK 25 archive-ordering warnings, not Play validation |
| Release audio asset regression check | All 9 clips retained byte-for-byte |
| Optimized app offline UI smoke | Setup, start, pause, confirmed stop, and return Home passed with emulator Wi-Fi/mobile data disabled |
| Production-signing fail-safe | Unsigned/unconfigured release dry-run rejected as intended |
| Release permission inspection | No INTERNET, GPS, microphone or sensor permission |

Reproduce core checks with `bash scripts/check.sh --device`. Kotlin reports are generated under build/app/reports/tests/ and device reports under build/app/reports/androidTests/connected/. Build output/report paths are ignored, not source-controlled.

Schedule tests enumerate supported/rejected goal/ability/week combinations, consistent positive interval totals, complete beginner foundation, prerequisite rejection, timeline extensions, recovery/taper and supporting running volume. Widget tests cover the default two-action initialize/start, one-action returning start, early-stop confirmation, and setup layout at 320×568 with 200% text.

Native unit tests cover monotonic elapsed time, callback independence, exact boundaries, pause/resume excluding downtime, whole-workout milestones without duplicate cues, delayed-callback suppression, clamped completion, interrupted recovery, invalid intervals, idempotent progression and repeat semantics.

The 13 emulator tests cover real SQLite reopen/checkpoint persistence, atomic/idempotent completion, early stop, retained repeated attempts, interrupted recovery without advancement, background timer operation, pause/resume, screen-locked timing, bundled audio startup, focus-loss pause, explicit resume speech, immediate-repeat cleanup, and return of transient ducking focus to a previous audio client. These tests establish playback startup/focus behavior, not the subjective sound quality or compatibility of every music/podcast app.

Use a disposable emulator/test profile. The database tests use coach-test.db. Service tests restore saved document contents within their run, but Android instrumentation install/test tooling may reset app data; do not run them against valuable workout history.

## Actual UI and process-termination checks

The default setup and dashboard were exercised through Android UI nodes. Initialize was one action, Start Workout the second; the OS notification permission dialog was excluded from that count. Returning Home exposes Start Workout directly.

During a real development workout, the app was force-stopped and reopened. The durable runtime changed from running to interrupted at exactly **50,431 ms** in both database snapshots. There was no history entry and the program cursor stayed at zero. After explicit confirmed early stop, one stopped attempt was retained and the cursor remained zero. Downtime was not invented as exercise.

Screenshots were captured and inspected for setup, dashboard, player, and interrupted recovery under docs/screenshots/. The final screenshots supersede the historical Hello World image where present.

## Release-only defect found and fixed

The first optimized APK build removed every voice clip: the resource shrinker could not identify dynamically generated resource names passed to getIdentifier. Playback now uses explicit R.raw references. `python3 scripts/check-audio-assets.py` checks that every source cue is retained byte-for-byte in the optimized APK; this is required after release build changes. Rebuilding alone would not have caught this defect.

Voice files are bundled synthetic English speech generated locally by scripts/generate-coaching-audio.py with the installed eSpeak NG development library. No network voice service, downloaded voice data or TTS engine is needed at runtime. Human listening/clarity validation remains pending.

## Remaining checks before production

See [release gates](RELEASE.md): independent curriculum review, Pixel/Samsung physical devices, prolonged battery/background tests, full headset/call/music/podcast matrix, all large-text/TalkBack flows, production signing and upgrade tests, accurate store/privacy declarations, and acceptance of the specialUse foreground-service declaration. No store publication occurred.

Known implementation limits: no GPS or distance measurement; no automatic race-completion claim; local-only history can be lost on uninstall/reset/device loss; no individualized injury/return-to-running assessment; no iOS runtime yet. All supported timelines are development templates rather than validated training prescriptions.
