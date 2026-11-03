# MVP requirements and acceptance ledger

This is the completion ledger for the user's app goal. Passing software checks
is distinct from physical-device validation and permission to publish. The voice
upgrade is explicitly deferred by the user; current clips remain placeholders.

| Requirement | Implementation / current evidence | Remaining verification |
|---|---|---|
| Fast setup; next workout directly on Home | Goal/ability/timeline defaults; initialize/start; returning start widget tests | Eligible recommended setup paths are widget-tested; custom 60-week path tested. TalkBack observation remains. |
| Four goals; reasonable progression | Versioned original generator, readiness screens, recovery/taper and supporting volume; schedule tests | Independent qualified curriculum review before production claims |
| Flexible timelines and interval options | 60-week plan, 21-stage gentle ladder, custom up to 999 weeks | 999-week serialization/native bounds and actual 2,997-workout initialization passed; physical-device performance remains |
| Day 1/2/3 written workouts | Stored warm-up, run/walk pairs, repetitions, cooldown, total; widget tests | Actual dashboard/program/player visual checks passed |
| Timer and skip | Monotonic native foreground engine; separate active/skipped time; unit tests | Native instrumented engine/service/database regressions passed |
| Pause/resume/confirmed stop | Native service, immediate UI pause/resume, explicit stop, saved incomplete attempt | Native service regressions and actual control smoke passed |
| Background and locked screen | Partial wake lock while running, service notification, checkpoints | 15-minute locked-screen real-time soak passed; physical battery-saver/extended sessions remain |
| Offline audio | Ten bundled cues; audible via Wayland scrcpy confirmed; media audio focus and local logs | Separate-UID playback/focus suite passed; physical music/podcast/headset/call matrix remains; voice quality deferred |
| Honest recovery | No invented elapsed downtime; interrupted checkpoint on destruction/reopen | Interruption regression and actual force-stop/reopen passed; actual guest reboot also retained the exact checkpoint |
| Completion and repeats | Atomic/idempotent progress; repeat queue; explicit modified completion; native start policy | Atomic completion/duplicate/replay and skipped notification regressions passed |
| Local history | Original stored prescriptions, statuses, dates, repeat contexts, skipped intervals; lazy 3,000-row widget test | Actual history-row navigation and prescription detail passed |
| Program pause/restart | Pause blocks starts from every UI entry; new program retains old history | Paused/replay widget and native start-policy tests; restart retains prior programs/history in device check |
| Settings/defaults | Locally persisted voice/milestone/duck/vibration/rain; cached live service settings | Live settings and separate-UID focus behavior passed |
| Theme/accessibility | Central dark/green tokens, readable timer, reduced-motion rain, small-screen large-text tests | Large-text player/settings and Android tap-target/label tests passed; observed TalkBack and physical readability remain |
| Privacy | Local SQLite, no account/GPS/analytics/cloud; backup exclusions; release manifest checked | Manufacturer backup behavior; publisher privacy policy details |
| Distribution | Debug APK; explicitly development-signed optimized APK/AAB; production-signing fail-safe | Final APK/AAB and same-signature development upgrade passed; production identity/key, store policy/account/testing-track gates remain |

## Runtime test policy

The user explicitly authorized the bounded scrcpy compatibility tests. AGENTS.md
requires explicit permission for emulator compatibility tests after the host desktop freezes.
The prepared route is headless SwiftShader plus native-Wayland scrcpy, persistent
logs, read-only AVD option and bounded shutdown. Never return to standalone Qt
emulator windows. A watchdog cannot guarantee recovery from a compositor freeze.

Native tests use a disposable/read-only test session: instrumentation install
can reset data. The opt-in WorkoutSoakTest accepts soakSeconds=900 and checks
real monotonic timing with the Android screen locked, completion persistence and
one advancement, then restores its saved documents. The default short suite skips
that long test unless its duration is explicitly supplied. Compiling a test is
not evidence it passed; executed results belong in VALIDATION.md.

## External release gates

No publication or external account creation is authorized. Publisher identity,
production signing, store declarations/approval, independent curriculum review
and physical-device compatibility cannot be declared complete by a build or an
emulator pass. Keep them visible in RELEASE.md rather than claiming production
readiness. Local test artifacts and development signing are not a Play release.

Notification permission prompting is now recorded locally after the first request,
so denying it does not cause a new prompt on every workout start. The service
still starts from the explicit workout action. Actual notification denial allowed workouts, kept progression unchanged after early
stop, and did not repeat the permission prompt. Physical-device re-enable UX remains
a release check.
