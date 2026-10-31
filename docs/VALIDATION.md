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

## v0.3 update: flexible timelines, written days, and interval skipping

- 60-week beginner 5K generation is tested with 180 scheduled workouts and a gentler 21-stage interval ladder; 104-week requests also pass eligibility checks. The former distance-specific upper caps are removed; custom entry supports up to 999 weeks.
- Full written run/walk, repeat, warm-up/cooldown and total-time descriptions are derived from stored definitions. Program view groups Week X into Day 1 / Day 2 / Day 3; dashboard and player show the actual prescription.
- Skip Interval tracks sequence position separately from active exercise time, persists skip details, supports paused skipping, and restores skipped-time metadata after interruption. Modified completion does not silently advance the cursor; explicit confirmation is idempotent.
- Executed checks for this update: 15 Dart/widget tests, 18 native unit tests and 15 emulator tests; 48 total passing. Static analysis is clean. Debug APK, development-signed release APK and AAB builds pass. The release asset check confirms all 10 bundled clips are retained, including the new modified-workout announcement.
- Actual emulator UI smoke: entered a custom 60-week plan, inspected weekly Day 1/2/3 instructions, skipped the warm-up into running, skipped through completion, and explicitly continued to Day 2. SQLite confirmed one advancement with 106,166 ms active and 1,753,834 ms skipped (exactly the prescribed 31 minutes combined). Screenshots: dashboard-60-weeks.png, week-days.png, skip-interval.png and finished-with-skips.png.

## Audio lab and repeatable local testing

Added a debug-only audio lab for all ten real coaching clips, individual replay,
continuous melody and a link to the workout app. The user confirmed actual voice
cues audible and desktop stable via native-Wayland scrcpy. Audible transport is
accepted; the eSpeak voice quality was explicitly rejected for production (see
VOICE-DIRECTION.md). Latest checks: clean Flutter analysis, 15 Dart/widget tests,
18 native unit tests and successful debug APK builds. No device instrumentation
suite was rerun for these tooling changes. Native audio logs identify cue
start/completion, focus changes and failures. User-invoked development launcher
builds the current APK, captures durable logs and cleans up helper groups.

Actual workout UI smoke through scrcpy also passed: Start Workout, Pause, Resume,
Skip Interval, End Workout and Confirm. SQLite evidence retained locally shows
the latest attempt stopped and the existing program cursor still 1 (Day 2).
The test emulator was deliberately shut down afterward; scrcpy reports device
disconnection for that explicit shutdown. This was a short control smoke test,
not a completed 15–20 minute stability soak.
