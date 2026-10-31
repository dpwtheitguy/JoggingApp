# RUN//PROGRAM — initial design package

Review draft · October 30, 2026 · Phase 1 only

This package proposes the architecture and product behavior for review. No application code has been written. Training ranges below are conservative product proposals, not clinically validated prescriptions or guarantees of race readiness. Implementation starts only after design approval.

## 1. Research and implications

### Reference applications

Verified public documentation:

- Zen Labs describes C25K as eight weeks of progressive walking/running, three sessions weekly, approximately 30 minutes each. This supports simple session-based navigation and gradual beginner intervals. [Zen Labs support](https://www.zenlabsfitness.com/support)
- Zen Labs' 10K Trainer listing describes a 14-week walk/run plan, three sessions weekly, audio alerts, and an entry point for existing 5K graduates. The listing emphasizes pressing Start. These are publisher claims, not independent evidence of effectiveness. [Publisher App Store listing](https://apps.apple.com/us/app/10k-trainer-by-c25k/id511600311)
- Zen Labs documents completion checkmarks, automatic completion after the full workout, and manual marking. RUN//PROGRAM should preserve the clear completion indicator but use an explicit accessible action rather than a hidden long press. [Progress support article](https://www.zenlabsfitness.com/knowledge-base/the-app-is-not-remembering-my-progress-i-lost-all-my-data-help/)
- Zen Labs documents music playback and audio-cue troubleshooting, including locked-device settings. This establishes intended coexistence with music and locked-screen cues, not guaranteed behavior across current Android devices. [Music support](https://www.zenlabsfitness.com/knowledge-base/how-to-play-music-within-the-app-not-finding-my-playlists/), [voice support](https://www.zenlabsfitness.com/knowledge-base/no-voice-cues-voice-cue-is-very-small/)

Not verified: the full current Android interval tables, exact halfway/warning semantics, implementation of audio focus, current repeat-week behavior, and reliability on specific devices. No reference app was installed or tested. The iOS listing cannot establish Android parity. “10K Runner” is an ambiguous title; this research uses Zen Labs' 10K Trainer, not another publisher's similarly named app.

Design inference: borrow the interaction principles—visible next session, gradual walk/run progression, practical voice cues, clear completion—not branding, assets, or a copied curriculum. No proprietary interval table will be transcribed.

### Training evidence

| Source | Relevant findings | Implication |
|---|---|---|
| [NHS Couch to 5K](https://www.nhs.uk/better-health/get-active/get-running-with-couch-to-5k/) | Nine-week beginner progression, three weekly runs with recovery between runs | Ten-week 5K default is a plausible starting proposal; reaching a timed running milestone does not measure 5K |
| [Higdon novice 10K](https://www.halhigdon.com/training-programs/10k-training/novice-10k/) | Eight weeks, three running days plus cross-training; opening workouts already require a running base | A beginner needs a foundation before a distance-specific block |
| [Higdon novice half](https://www.halhigdon.com/training-programs/half-marathon-training/novice-1-half-marathon/) | Twelve weeks, four running days; assumes ability to run about three miles three to four times weekly | Twenty weeks cannot be treated as universally suitable for someone unable to run five minutes |
| [Higdon novice marathon](https://www.halhigdon.com/training-programs/marathon-training/novice-1-marathon/) | Eighteen weeks, four runs weekly; long runs, regular cutbacks, three-week taper | Longer timelines alone do not replace an adequate base or weekly volume |
| [Higdon novice base](https://www.halhigdon.com/training-programs/base-training/novice-base-training/) | Twelve-week base block starts above a true nonrunner's ability | A 30-week base-plus-marathon concept is not automatically a couch-to-marathon plan |
| [Higdon Marathon 3](https://www.halhigdon.com/training-programs/marathon-training/marathon-3/) | Twenty-four weeks; three runs, two cross-training days; intended for experienced runners, with higher mileage per running day | Three running days are possible, but not evidence that three total easy workouts suffice for novice marathon preparation |

These sources inform structure, not a claim that our eventual adaptation is validated. Do not use a universal “10% rule” as a safety guarantee. Original half/marathon templates require qualified running-coach review before release.

## 2. Technology recommendation

Recommend **Flutter for UI and schedule generation, with a narrow Kotlin Android runtime service**. Make this conditional on an early locked-screen/audio proof of reliability.

| Consideration | Flutter + Kotlin service | Kotlin + Jetpack Compose |
|---|---|---|
| Android background/audio integration | Explicit native bridge and service required | Direct native integration; fewer boundaries |
| Future iOS | Reuse UI, training definitions, generator; build Swift runtime | UI rewrite; portable data/schema still reusable |
| Complexity | Two languages and a versioned bridge | Simpler Android-only stack |
| Fit | Preferred given requested iOS path | Fallback if bridge lifecycle complexity defeats maintainability |

Flutter supports asynchronous native platform channels; a Dart isolate is not itself an Android execution guarantee. [Flutter channels](https://docs.flutter.dev/platform-integration/platform-channels), [background processing](https://docs.flutter.dev/packages-and-plugins/background-processes)

Separate modules:

1. **Training catalog/generator (Dart):** pure functions, versioned original templates, readiness validation.
2. **Interval engine (Kotlin on Android):** pure state reducer with injected clock; no widget dependencies.
3. **Coaching adapter:** bundled audio playback and focus handling.
4. **Persistence:** Android SQLite repository owns plans, attempts, checkpoints, progression, and settings transactions.
5. **Flutter UI:** renders authoritative snapshots; sends commands; no independent countdown authority.
6. **Theme/effects:** centralized tokens and decorative renderer.

Use a small versioned MethodChannel/EventChannel protocol initially: initialize plan, get snapshot, start/pause/resume/end, repeat, settings, history. Commands carry unique IDs; stale attempt IDs are rejected. Validate serialized workouts on the native side. UI reconnects request a full snapshot before listening to updates. Share schema and fixture cases; avoid implementing competing timer engines in Dart and Kotlin. iOS later implements the same runtime contract in Swift; it requires its own background execution evaluation.

Minimal dependencies: Flutter SDK, Android platform/AndroidX as necessary, SQLite, test tooling. No backend, analytics, ad SDK, account, location, music player, or elaborate state framework. Exact dependency versions are selected after approval.

## 3. Proposed training model

Durations are integer seconds; runtime elapsed values use milliseconds. Calendar timestamps are UTC with local formatting, never timer inputs.

| Entity | Essential fields |
|---|---|
| PlanRequest | goal enum, requested weeks, ability, frequency (3), readiness answers |
| Readiness | recent consistent running, weekly volume band, longest recent comfortable run, sustained base duration; only fields required for selected distance |
| CurriculumTemplate | id/version, goal, entry requirements, supported lengths, week roles, original workout definitions, progression/cutback/taper constraints, source rationale, review status |
| ProgramInstance | UUID, requested/effective settings, template/generator versions, immutable generated schedule, created time, active/paused/archived/completed status |
| TrainingWeek | index, foundation/build/recovery/taper role, ordered sessions |
| WorkoutDefinition | stable id, week/session, easy/recovery/long role, ordered intervals, total duration, optional route guidance |
| Interval | id, warmup/run/walk/cooldown activity, duration, effort instruction, cue identifiers |
| WorkoutAttempt | UUID, program/workout id, normal/repeat context, start/end timestamps, active duration, complete/stopped/interrupted status, completion method, optional user-reported distance |
| RuntimeCheckpoint | attempt id, state, interval position, committed active elapsed, monotonic anchor, runtime identity, checkpoint timestamp, emitted cue keys, revision |
| Progression | normal next session, optional repeat-week cursor and saved return cursor, completed scheduled-session IDs |
| Settings | voice, halfway, final-minute warning, vibration, ducking, rain; defaults from requirements |

SQLite migrations preserve historical definitions and attempts. Never regenerate an active plan in place when templates change. Finishing an attempt and updating progression happen in one idempotent transaction. Repeats create new attempts; program restarts create new program instances.

Scheduled-workout completion, program completion, and self-reported target-distance completion are separate facts. No elapsed-time-to-distance inference. Optional distance entry belongs only on the completion screen and is labeled “reported by you.”

## 4. Schedule generation and realistic combinations

Use a **reviewed template catalog**, not a formula that stretches any goal into any requested duration. Generate deterministically by selecting an eligible template and adding explicitly permitted foundation/consolidation weeks. Never compress recovery, taper, or entry requirements. Unsupported lengths show a reason and the closest supported alternative; changes require an explicit selection.

Initial candidate ranges for review—not an approved curriculum:

| Goal | Beginner | Intermediate | Experienced |
|---|---|---|---|
| 5K | Recommend 10 weeks; catalog 10–16 | Recommend 10; 8–16 maintenance/completion preparation | Same, without unnecessary intensity |
| 10K | Recommend 18; 18–25 including foundation | Recommend 12; 10–20 with consistent 5K base | Recommend 10; 8–20 with adequate base |
| Half | Redirect to foundation first; provisional combined path 28–36 with reassessment | Recommend 20; 20–30 after base check | Recommend 16; 16–25 after base check |
| Marathon | Foundation first; no automatic 30-week race-ready promise | Base development first; ability label alone insufficient | Recommend 30; candidate 24–36 only after stronger prerequisite check and curriculum review |

The proposed 16-week beginner 10K may be reasonable for some, but is not accepted automatically here. The 20-week half and 30-week marathon are conditional, not defaults for every ability. Common lengths such as 12, 15, 16, 20, 25, 30 appear only where a reviewed template supports them. Experienced does not mean speed training is required.

Candidate prerequisites to review with a coach:

- All beginner entries: comfortable 30-minute walk; otherwise recommend a walking foundation outside the generated running plan.
- Half: established three-day running routine for at least six weeks, comfortable 5K runs, and a recent comfortable longer outing around 8–10K. These stricter entry checks are product proposals, not thresholds proven by the cited four-day plan.
- Marathon: consistent running for at least a year, recent weekly volume around 25–35 km for at least eight weeks, comfortable long run around 12–16 km, and willingness to include supporting activity. These are screening proposals, not sufficient evidence of readiness by themselves.

Use two compact prerequisite selections for long distances: one confirms the displayed base requirements; one confirms supporting activity availability. “No / unsure” routes to a foundation plan with a reassessment gate. Do not hide prerequisites in a disclaimer. Do not market a three-run-only marathon curriculum as equivalent to a plan with cross-training. Final marathon eligibility and supporting activity requirements remain a review decision.

Original curriculum structure:

- 5K: walking warm-up/cooldown, short easy run/walk intervals, consolidation before longer continuous running. First session proposal: 5-minute walk + eight rounds of 60-second run / 90-second walk + 5-minute cooldown = 30 minutes. This example is specified by the brief, not represented as proprietary research.
- 10K: foundation when needed, two shorter easy sessions and one gradually longer session, recovery weeks, final reduced load.
- Half/marathon: distinct easy, recovery/support, and long sessions; explicit cutbacks approximately every third/fourth week; taper reserved before the goal event (candidate half: two weeks; marathon: three). Exact volumes and caps require review.
- Keep effort conversational; allow prescribed walk breaks. Increasing time is not a claim of covering a distance. Long-distance templates need route-distance guidance and optional manual reports because a fixed time cap cannot guarantee enough distance preparation for every pace.

Validation rejects nonpositive durations, inconsistent totals, missing recovery/taper blocks, unmet prerequisites, unsupported lengths, and loads outside template limits. Tests enumerate all supported goal/ability/length combinations and rejection paths. Catalog review examines weekly time, longest run, run/walk ratio, and distance assumptions; passing software tests cannot establish training safety.

Completion-based progression never catches up after missed days. Recommend rest between beginner runs. After an extended pause (proposed 14 days), offer repeat current week or restart an earlier module; keep the existing cursor until chosen. Do not invent a medically precise detraining algorithm.

## 5. Screen flow and interaction budget

One setup screen contains goal, timeline, ability, summary, and Initialize. Defaults are already selected. Ability changes recalculate the recommended timeline unless the user has explicitly selected a custom length, in which case validate visibly. Long-distance prerequisite fields appear inline.

```text
First launch → Setup + summary → INITIALIZE PROGRAM → Dashboard
                                                    ↓ START WORKOUT
                                                Workout player
                                                    ↓
                                               Completion summary

Dashboard → Program / History / Settings
Program → session detail → repeat workout
Dashboard → Repeat Week confirmation → repeat sessions → saved normal cursor
Player → Pause / Resume
Player → End → Confirm stop → incomplete summary
```

Counted setup paths (excluding OS permission dialogs):

- Accept all defaults: Initialize (1), Start Workout (2).
- Fully customized short goal: goal (1), open timeline picker (2), choose weeks (3), ability (4), Initialize (5), Start (6).
- Long goal: same six plus two inline prerequisites (8). If offered an alternative, select it (9). Use direct selection controls; avoid extra Next screens or mandatory keyboard entry.
- Returning user: Dashboard → Start Workout (1). Paused workout: Resume (1). Interrupted recovery: choose Resume (1), confirm recovered position (2).

Blocked combinations cannot satisfy a “start requested race plan” budget; a visible recommended foundation alternative still starts within ten interactions. Measure real taps during usability testing, including picker interactions; these are design counts, not validated results.

Dashboard: status, goal, week/session, next duration, largest Start control; secondary Program, Repeat Week, Settings; history reachable through Program. Player: activity, large countdown, next interval/duration, total progress, Pause/Resume, End. Completion: elapsed time, completion status, Continue, Repeat Workout, and Repeat Week after week end.

Repeat Workout does not move the normal cursor. Repeat Week records the return cursor and replays three sessions; afterward resumes that saved cursor. If replaying an unfinished week completes previously uncompleted scheduled sessions, recompute the next incomplete normal session to avoid scheduling them twice. Repeated attempts never inflate unique program progress. Program progress = unique completed prescribed sessions / total prescribed sessions.

Stopping early always records incomplete. Recovery may offer “I completed the remaining sequence” with explicit confirmation and a manual completion label; it never fabricates timer duration. No automatic completion merely because wall time passed.

## 6. Cyberpunk theme specification

| Token | Value / use |
|---|---|
| background | #050805 |
| panel | #0B160E |
| primary | #00FF41 |
| secondary | #70A080 |
| active | #39FF70 |
| warning | #E6B450 |

Centralize colors, typography, spacing, focus, disabled, and motion tokens. Use bright green for primary emphasis, secondary green for supporting information, and warning color plus explicit text/icon for concerns. Verify contrast for each actual foreground/background combination, including disabled controls; never rely on color alone.

Monospace headings/status; readable system sans-serif controls/body; tabular timer numerals around 64–80sp, body at least 16sp, support system text scaling. Minimum 48dp targets, proposed primary controls 56–64dp high. TalkBack announces activity transitions without per-second timer spam. Keep the screen layout stable when countdown widths change.

Procedural rain: sparse columns behind content, low opacity, maximum about 12 fps, clipped away from text. Disable during active workouts and backgrounding, and whenever system motion is disabled/reduced; persisted user off switch. No video, flashing, constant glow animation, or battery-intensive shader. Theme remains complete without animation.

Use original terminal language such as “SIMULATION READY,” but label actions Start Workout, Pause, Resume, End Workout. No film assets, quotes, names, logos, music, or character references.

## 7. Android timing, audio, and recovery

### Execution and service type

Start the native foreground service from visible Start/Resume actions. Show ongoing notification with activity, remaining time, Pause/Resume, and an End action that opens confirmation. Flutter activity destruction must not end the workout. A foreground service is necessary here but does not guarantee survival.

**Important unresolved release risk:** Android's `health` type has sensor/activity-related prerequisites; this app should not request unrelated permissions just to qualify. Propose `specialUse` for the user-started timed exercise coach, with an accurate manifest subtype and Play declaration. Its suitability and Play acceptance must be evaluated early. `mediaPlayback` cannot simply be assumed to cover silent intervals or muted workouts. Do not use fake silent audio, `dataSync`, or `shortService` to evade restrictions. [Android service types](https://developer.android.com/develop/background-work/services/fgs/service-types)

Candidate permissions: FOREGROUND_SERVICE, FOREGROUND_SERVICE_SPECIAL_USE (if confirmed), WAKE_LOCK, POST_NOTIFICATIONS where applicable; VIBRATE for the optional feature. No GPS, microphone, contacts, sensors, storage runtime permission, or INTERNET in release manifest. Handle notification denial explicitly without an endless permission loop. Request only at relevant actions.

Use a partial wake lock while actively running the sequence, released on pause/end/error, so CPU sleep does not delay cues. Benchmark battery impact and implement cleanup/time bounds. No screen wake lock, exact-alarm permission, WorkManager tick loop, or boot-time workout auto-resume.

### Interval engine

States: idle → running ↔ paused → completed or stopped; unexpected termination → interrupted. Monotonic `elapsedRealtime()` includes deep sleep and is the timer source. [Android SystemClock](https://developer.android.com/reference/android/os/SystemClock)

Active elapsed = committed active elapsed + (current monotonic time − running anchor), clamped to prescribed total. Pause commits elapsed once; resume establishes a fresh anchor. Derive interval index and countdown from cumulative boundaries; callbacks only request reevaluation. Repaint at up to 1 Hz; schedule native reevaluation for boundaries and milestones. Never decrement a stored seconds counter.

Persist on every transition, command, cue decision, and completion, plus a proposed five-second active checkpoint. The native repository serializes commands. A completion command is idempotent even if UI and notification act simultaneously.

If the original service is alive, restore its current authoritative snapshot. If the runtime process died or continuity cannot be proven, recover paused/interrupted at the last durable checkpoint, explain that up to the checkpoint interval may be missing, and require Resume. Never add wall-clock downtime or infer continuation from a same-boot monotonic anchor alone. Reboot/force-stop cannot be promised to continue coaching.

### Voice choice and cue policy

Recommend a small set of **bundled, properly licensed original English recordings**. Platform TTS is small and flexible but installed offline voices vary; Android exposes whether a voice needs a network connection. A hybrid adds branches without a current need. Bundled clips guarantee included speech assets from first offline launch and make timing predictable. [Android voice API](https://developer.android.com/reference/android/speech/tts/Voice)

Record variants for every warm-up/cooldown duration actually used by the approved catalog. Generic practical transition clips cover run and walk. No voice selection, AI voice service, or audio downloaded at runtime.

- On start: “Begin your five-minute warm-up.”
- On run/walk boundaries: “Start running.” / “Stop running. Start walking.”
- At 50% of total active workout time, including warm-up/cooldown: “You're halfway there.”
- At total active remaining time = 60 seconds: “One minute left in this workout.” Never use this as an interval warning.
- Cooldown: duration-specific instruction; finish: “Workout complete.”
- One serialized cue queue; event key = attempt + cue + boundary. Transitions outrank milestones. Combine a simultaneous transition and milestone into a single ordered announcement; cancel obsolete queued instructions. If a callback is materially late (proposal >2 seconds), skip stale milestones, announce only the current activity, and flag timing failure for reliability testing. Do not replay crossed interval instructions in a burst.
- Pause cancels speech; resume announces current activity without replaying milestones. Muting drops speech, preserving timing and completion.

Request transient focus with MAY_DUCK immediately before each clip, use speech attributes, and abandon focus afterward. Do not modify other apps' volume settings. Podcasts may choose to pause rather than duck; compatibility is cooperative and must be tested. Android 15+ restricts focus acquisition to a top app or foreground service. [Android audio focus](https://developer.android.com/media/optimize/audio-focus)

Transient/permanent focus loss during a cue pauses the workout and checkpoints; resume requires user action. A failed focus request also pauses rather than silently allowing an inaudible transition. Headphone disconnection pauses to avoid unexpectedly broadcasting coaching. A notification alone does not pause the timer. Phone-call behavior between cues must be tested; do not request call-log/phone permissions to monitor calls. No platform can guarantee an audible cue while another app or the OS owns audio.

## 8. Roadmap and release boundaries

| Phase | Deliverable | Exit evidence |
|---|---|---|
| 1 — review | This design, curriculum approach, open decisions | User approval before application implementation |
| 2a — reliability proof | Native foreground runtime, basic Flutter control, bundled test cues, checkpoint recovery | Real-device locked-screen/background/muted tests; service-type decision; no assumed reliability from emulator alone |
| 2b — functional prototype | Setup, reviewed templates, player, completion, repeats, history, settings | Offline flows; unit tests for engine, generation and progression; transactional persistence tests |
| 3 — visual design | Central theme, dashboard/player polish, subtle rain | Large text/TalkBack/contrast/reduced-motion checks |
| 4 — reliability | Fault injection and device matrix | Recorded measured results and remaining limitations |
| 5 — UX | Tap budgets and eyes-free workout validation | Observed setup ≤10 actions; normal returning start ≤2; history retained through repeats/restarts |
| 6 — release preparation | Debug/release APK, signing procedure, AAB, disclosures and checklists | Install/upgrade/offline smoke tests on release build; publication requires separate approval |

Tests must include exact boundaries, halfway/final minute collisions, repeated pauses, delayed callbacks, wall-clock changes, duplicate commands, process death, reboot, storage failure, restart/repeat semantics, end confirmation, and unsupported schedules. Device matrix includes supported minimum Android (proposed API 26), API 34/35/36, at least Pixel and Samsung hardware, battery saver, screen lock, Bluetooth disconnect, notification denial, music and spoken podcasts. Proposed normal-condition cue-start target: within one second of threshold; measure actual latency and battery cost rather than declaring hard real-time behavior.

No GPS/maps, watches, HR, accounts, sync, subscriptions, ads, social, calories, analytics, custom voices, AI coaching, theme marketplace, or complex calendar scheduling. Three prescribed running sessions remain the default; any mandatory supporting activity for longer plans must be disclosed and approved, not added silently.

## 9. Privacy, distribution, and documentation

Store data in app-private storage; never log personal history in release diagnostics. Proposed backup policy: exclude history/settings/runtime from cloud backup and device transfer using version-appropriate rules, and set allowBackup explicitly. Android notes manufacturer differences, so verify behavior; explain that uninstall/reset/device loss can lose local history. Export/import is outside MVP unless approved. [Android backup documentation](https://developer.android.com/identity/data/autobackup)

As checked for this draft, new Play submissions must target API 36 or higher. Recheck at release; propose minSdk 26, subject to dependency/device review. [Google Play target requirements](https://support.google.com/googleplay/android-developer/answer/11926878)

After implementation, README must provide pinned development requirements, actual executed test/build commands, emulator/device setup, debug APK sideload instructions, release APK signing, AAB generation, versions, and known limitations. Release APK supports sideloading; signed AAB is the Play upload artifact. Keep keystores/passwords outside source control, use ignored local/CI secret inputs, document key backup and Play App Signing/upload-key responsibilities. Do not create accounts or publish without explicit approval.

Prepare privacy policy, Data Safety answers based on final dependencies and backup behavior, foreground-service declaration/demo evidence, applicable health-app declarations, content rating, testing-track and store checklist. Do not claim “no data collected” solely because there is no app backend without checking all shipped components.

## 10. Decisions and risks for review

1. Approve Flutter plus a small Kotlin runtime, contingent on the reliability proof; Compose is the fallback.
2. Approve reviewed template generation instead of unrestricted timeline interpolation, including revised beginner 10K recommendation and prerequisite-based long-distance redirects.
3. Resolve half/marathon curriculum review and whether supporting cross-training is acceptable within the three-running-session promise. All four goals remain planned; an unreviewed long-distance plan is a release blocker, not a feature quietly removed.
4. Approve bundled English recordings and a whole-workout final-minute warning.
5. Approve conservative paused recovery after process death, and local-only backup exclusions with explicit data-loss limitations.
6. Confirm the proposed API 26 minimum and identify physical devices available for testing during implementation.

Highest risks: foreground-service policy acceptance; OEM process killing; long-distance volume adequacy under time-only coaching; audio interruption behavior; loss of the most recent checkpoint; and iOS background restrictions requiring separate native design. Neither research nor a chosen framework establishes these acceptance criteria. No application tests, builds, or device experiments have been run in this design phase.

**Stop here for user review. No implementation is authorized by this document.**
