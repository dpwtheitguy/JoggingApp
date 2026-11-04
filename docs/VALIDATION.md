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

Reproduce core checks with `bash scripts/check.sh --device DEVICE_SERIAL`. Kotlin reports are generated under build/app/reports/tests/ and device reports under build/app/reports/androidTests/connected/. Build output/report paths are ignored, not source-controlled.

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

## v0.4: review saved workouts

History entries now open a read-only detail screen containing the original saved
prescription, status, local date/time, program, normal/repeat context, actual
exercise time, prescribed time, optional self-reported distance and individual
skipped intervals. Archived definitions are not regenerated. Modified workouts
clearly distinguish explicit progression confirmation from unaccepted skips;
stopped attempts are not described as completed. History rows are built lazily
for longer timelines and retained repeats. Dashboard now shows remaining
scheduled workouts as well as completed count.

Executed checks: clean Flutter analysis; 19 Dart/widget tests (including archived
prescriptions, actual/skipped time, legacy optional fields, 3,000 retained
attempts and 320×568 at 200% text); 18 native unit tests. Debug APK and explicitly
development-signed optimized APK/AAB builds pass for 0.4.0+4. All ten prototype
voice clips remain byte-for-byte in the optimized APK. No emulator was launched
and device instrumentation was not rerun for this UI increment. Voice quality
remains a deferred production task.

## v0.5 reliability audit

Implemented runtime-only UI polling instead of reloading full plans/history every
second, cached live service settings instead of decoding the entire program four
times a second, and guarded stale polling responses after commands/backgrounding.
Completion still reloads authoritative progress/history. Failed post-command
snapshot reads no longer report UI success.

Fixed skipped-position notification labels, interrupted-state persistence on
service destruction, final-skip atomicity, exact-finish skip speech, duplicate
completion protection, canonical native start validation, paused-program starts
and repeated-week mode selection. Notification permission is requested once
instead of on every workout after denial. Home/settings/player/result now use
separate scroll identities: the large-text test found and fixed a real inherited
scroll-offset bug that could open the player below the activity/countdown.

Executed final offline checks: 41 Dart/widget tests and 29 native unit tests passed,
including every eligible recommended goal/ability setup within ten interactions,
999-week definitions/native bounds, paused/replay behavior, large-text player and
settings, bridge polling races and failed snapshot handling. Analysis is clean.
The fail-fast script output is retained locally in
`docs/host-diagnostics/offline-checks-v0.5-final.log`; native results are under build/
and the local native-check log. The additional Android tests compile; runtime
results are recorded separately below, never inferred from compilation.

Computed WCAG relative-luminance ratios for opaque central theme colors:
primary text 14.74:1 on background / 13.55:1 on panel; secondary text 6.74:1 /
6.19:1; active green 15.06:1 / 13.84:1; warning amber 10.55:1 / 9.70:1. This
calculation is not a claim that every composited UI/TalkBack path was audited.

First read-only native-Wayland runtime regression: 19/20 passed. The notification
visibility test lacked notification permission in its fixture. The disposable
session correctly had POST_NOTIFICATIONS denied; service/background/audio tests
ran despite denial. Added an explicit permission grant to the visibility test,
then reran the suite. Original failed-run log is retained locally rather than
being overwritten. No standalone Qt emulator window was started.


### Executed runtime and manual evidence

The user authorized bounded compatibility sessions. Tests used API 36, a
read-only headless SwiftShader emulator and native-Wayland scrcpy where a UI/audio
window was needed. No standalone Qt window, host driver change or desktop restart
was used. Raw logs, database snapshots and intermediate failed fixtures remain
local and ignored under docs/host-diagnostics/.

- Full native service/database suite: 22 tests passed in
  runtime-20261030-213450/regression.log, including atomic rollback on storage
  failure, stale/duplicate completion, interruption, skipped notification position,
  live voice settings and real separate-UID media playback/focus restoration.
- Opt-in locked-screen soak: one 900-second test passed in
  runtime-20261030-210914/soak.log. The test sampled 899 times, observed elapsed
  within the one-second sampling tolerance without accumulating drift, and
  persisted exactly 900,000 ms, one history record and one advancement. Android
  reported asleep during the run; guest connectivity was disabled during it.
  This does not establish physical battery behavior or several-hour endurance.
- Actual offline controls: start, pause, resume, skip and confirmed stop passed.
  Notification denial still permitted workouts and did not prompt again on the
  next start. Stopped attempts did not advance the cursor.
- Real force-stop/reopen: exact 5,039 ms durable checkpoint recovered as interrupted,
  stayed frozen while waiting, and saved that time on explicit stop. History-row
  navigation opened the original written workout details successfully. Evidence:
  scrcpy-20261102-194948/manual-checks.log and associated database snapshots.
- Same-certificate upgrade: built committed v0.4.0+4 in an isolated temporary
  source directory, installed it then installed v0.5.0+5 without clearing data.
  Every stored database document compared equal after upgrade. Both certificates
  matched the local Android development certificate; this is not a production-key
  upgrade test.
- Actual custom 999-week initialization created 2,997 workouts and retained old
  history. The UI action and snapshot assertion completed in 4.4 seconds on this
  emulator; this includes automation overhead, not a pure generator benchmark.

Initial fixture failures were corrected and rerun: notification visibility needed
an explicit permission grant; the separate test APK fixture initially relied on
unpackaged Kotlin runtime and was rewritten in Java; starting an already-running
activity from another app required a nonblocking start. The app was not declared
passing from a partial instrumentation run. A reboot UI assertion initially saw
the OS notification dialog covering the app; subsequent evidence is recorded below.

Final optimized APK and AAB built with explicit development signing for 0.5.0+5.
The release asset checker confirmed all ten voice clips byte-for-byte. Release
manifest/certificate checks exclude debug/test activities and verify the five intended Android permissions plus AndroidX’s generated
app-signature-only receiver permission; no release INTERNET/location/microphone permission. Production
signing remains an external release gate. Voice quality remains explicitly deferred.


Final rerun: **23 Android regressions passed** in
runtime-20261102-200634/regression.log, including the added complete three-day
week replay with immutable prior attempts. Together with the separate 900-second
soak, 41 Flutter tests and 29 native unit tests, **94 tests passed**. The final
routine script completed successfully with clean static analysis.

Guest reboot recovery passed after dismissing the covering OS permission dialog:
the exact **5,169 ms** checkpoint reopened as interrupted, no downtime was added,
and explicit stop retained that time without advancing the new program. Evidence:
scrcpy-20261102-200404/upgrade-check.log, pre/post-reboot database snapshots and
reboot-stopped.db. The initial covered-screen assertion is retained in that log.

Final release APK verification passed; the AAB reports `jar verified` with the
expected local self-signed development certificate warnings. Both builds are local
test artifacts, not production-signed store submissions. The signing guard rejects
release tasks without production configuration or the explicit development opt-in.
Every bounded emulator session was stopped; no emulator was intentionally left
running. Host observations during these sessions do not prove the original COSMIC
issue is fixed, so the AGENTS.md restriction remains in force.


## v0.5.1: approved neural coaching voice

On November 3, 2026 the user selected Kokoro `af_heart` from three stock voice
samples, then heard all ten replacement clips in the updated Android audio lab
through the already-authorized native-Wayland scrcpy session and answered
**“Yes, use this voice.”** All ten eSpeak WAVs are replaced. No actor voice clone
or Cortana recording is used. Generation is local CPU-only; Android bundles only
finished audio and remains offline with no new runtime dependency or permission.

Executed checks for this audio-only update:

- Debug APK, development-signed optimized APK and AAB builds passed for 0.5.1+6.
- Static analysis passed. Python generators/checker compile and git whitespace
  checks passed. The previous 94-test reliability suite was not rerun for WAV-only
  runtime changes; its results remain the v0.5 acceptance evidence above.
- Each of the ten files is non-silent mono 24 kHz PCM16, 0.98–2.68 seconds long,
  peak -1.5 dBFS without clipping, with bounded leading/trailing silence. The asset
  checker validates exact cue membership, provenance hashes and byte-for-byte
  retention in both debug and optimized APKs.
- Android RunProgramAudio logs show every new cue started and finished without
  playback errors. The user confirmed clarity and accepted this voice in the app.
- Published model/embedding SHA-256 digests matched downloaded files. Model/tool
  source URLs, licenses and regeneration settings are in VOICE-DIRECTION.md;
  exact per-cue text/duration/hash is in audio/coaching-manifest.json.
- The compatibility session was deliberately closed after listening; no test
  emulator was intentionally left running.

Local detailed output is retained in .local-tools/voice/{build.log,bundle.log,
analysis.log,debug-assets.log,android-playback.log}. Physical headset, call,
music/podcast interoperability and battery checks remain the existing release gates.
