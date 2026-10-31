# Pop!_OS emulator instability investigation

Research date: October 30, 2026. No virtual device was started and no host settings or packages were changed during this investigation.

## Local evidence

- Pop!_OS 24.04 LTS, COSMIC, Wayland.
- Intel Raptor Lake-S UHD (i915) plus NVIDIA RTX 4070 Laptop (nvidia); NVIDIA open kernel module 595.84.
- Android Emulator 37.2.13, API 36 AVD; config contains hw.gpu.enabled=no and hw.gpu.mode=auto. Previous launch nevertheless selected software lavapipe/swangle after a GPU warning. Config flags alone are not evidence of which backend ran.
- Bundled Qt platforms include xcb, offscreen, minimal, linuxfb and vnc; no native Wayland platform plugin was found. Installing a system Qt plugin is not established as compatible with this bundled Qt.
- Installed cosmic-comp: 0.1~1786994555~24.04~8806436; installed Xwayland: 2:24.1.12-1pop2~1782241020~24.04~5ac8336.
- Cached apt metadata offers newer cosmic-comp (0.1~1792508925~24.04~8cb1802) and Xwayland (2:24.1.13-1pop1~1786712690~24.04~40c27b9). Cache freshness was not refreshed; no updates installed.
- Previous boot includes cosmic-comp messages about failed X11 event handling and a missing popup surface. Some X11 errors precede the emulator test, so they are not a unique causal signature.
- Targeted previous-boot kernel search found no explicit NVIDIA Xid, OOM-killer or GPU-hang report. Absence of those messages does not exclude a graphics failure.

## Upstream findings

1. [COSMIC #2965](https://github.com/pop-os/cosmic-comp/issues/2965), open when checked: emulator transient utility/message-bar windows repeatedly map/unmap through COSMIC's X window manager, causing whole-desktop mouse/frame stalls. Report uses emulator 37.2.12, Intel+NVIDIA and driver 595.84, close to this host. Reporter measured a window-event loop and says no-window mode avoids that particular failure. This is a user report, not a confirmed diagnosis of this laptop.
2. [COSMIC #3000](https://github.com/pop-os/cosmic-comp/issues/3000), open when checked: another Qt/X11 client freezes desktop input; software OpenGL did not resolve it. Supports investigating the window-system path independently of GPU rendering.
3. [COSMIC #2614](https://github.com/pop-os/cosmic-comp/issues/2614): Android Emulator Qt/XWayland startup and interaction instability on Pop!_OS/COSMIC, including disruption of other apps.
4. [COSMIC #2995](https://github.com/pop-os/cosmic-comp/issues/2995): a separate hybrid Intel/NVIDIA freeze with cross-device texture import errors, across multiple compositor versions. Those specific errors were not established here. Updating packages is not a demonstrated cure for our incident.
5. [Android graphics documentation](https://developer.android.com/studio/run/emulator-acceleration) documents explicit software modes including swiftshader. Software rendering changes guest rendering but does not remove a visible emulator's Qt/XWayland windows.
6. [Android command-line documentation](https://developer.android.com/studio/run/emulator-commandline) documents headless no-window mode. This is a plausible isolation step, not a guarantee of host stability.

## Assessment and next steps

The leading hypothesis is an emulator Qt/XWayland/COSMIC interaction. Hardware-driver or hybrid-GPU issues remain possible. We did not reproduce or prove the exact failure and found no verified fix for this host.

Keep visible emulator use suspended. Continue normal app analysis/build/unit tests and use a physical Android phone for device checks. Review normal Pop!_OS updates with the user, without promising they fix this issue. Do not switch graphics modes, replace drivers, restart the desktop or install alternate Qt plugins as speculative fixes.

If the user later explicitly authorizes a compatibility test, start with one short headless emulator using explicit software rendering, bounded CPU/RAM and no snapshots; capture logs and ensure automatic process cleanup. Have an independent recovery/termination path ready before the test. This avoids the implicated Qt windows but remains unverified on this host. Do not automatically launch that test from this document.

## First post-update compatibility test

October 30, 2026: cosmic-comp now 0.1~1792508925~24.04~8cb1802 and Xwayland 2:24.1.13-1pop1~1786712690~24.04~40c27b9. User explicitly authorized a short compatibility test after reboot.

Ran one headless emulator with explicit SwiftShader, 1536 MB guest RAM, two vCPUs, no audio and no snapshots. An independent timeout capped lifetime at 180 seconds with a 10-second forced-stop grace period. Android booted in approximately 16 seconds. The existing app launched, remained alive for a 25-second observation, and produced an inspected screenshot of the Week 1 / Day 2 dashboard. The user reported normal pointer/desktop response. Captured user journal contained no matching X11/popup failure signatures; targeted kernel search found no explicit Xid/OOM/GPU-hang messages. Emulator shutdown completed and a host process check found no remaining emulator/QEMU process.

Logs and screenshot were captured locally under /tmp/runprogram-compat; these temporary artifacts are not durable or committed. No workout was started and no sustained/background workload was tested. This is a successful brief headless smoke test, not proof that updates fixed the original incident or that visible/long-running emulation is stable. Both package versions and launch configuration changed, so their effects cannot be separated by this test. Keep routine emulator launches suspended under AGENTS.md; further tests require explicit authorization.

## Visible test reproduced instability

After the successful headless test, the user explicitly authorized a two-minute visible compatibility test using the same SwiftShader/software rendering, 1536 MB RAM, two vCPUs and no snapshots. Android booted and the app opened. The user then reported mouse jumping and desktop lockup. Updates plus software rendering therefore did not resolve visible-session instability. An immediate follow-up host check found no QEMU process; the test emulator's port refused connections. The test had a 120-second timeout and forced-stop grace period, but the available evidence does not establish whether timeout, a crash or another event ended it. Do not repeat visible emulator testing on this host. A short headless success does not establish long-term stability. Prefer a physical device or separately investigated remote/VM testing.

### Persistent-journal review after forced restart

The user confirmed a hard restart was necessary. Previous boot ID 0228124e32bf45148fa60466d12eb375 runs from 19:47:47 to its last journal entry at 19:52:56 PDT; the next boot begins 19:54:10. There is no normal shutdown sequence at the end of that boot. Captures under /tmp did not survive the restart, so detailed emulator output and resource samples cannot now be reviewed; future authorized diagnostics must use persistent storage rather than /tmp.

Persistent journal contains failed X11 event messages at 19:48:27–19:48:31, before either test; they are not evidence of a new error at the freeze. The kernel logged an unhandled guest WRMSR for the headless QEMU PID at 19:50:30 and the visible QEMU PID at 19:52:54. The shared message does not discriminate between the successful headless test and failed visible test. The final entries at 19:52:56 concern notifications; no definitive compositor crash, NVIDIA Xid, OOM-kill or GPU-hang signature was found in the targeted searches. Root cause remains unconfirmed despite the strong visible-window association. The observed failure also shows that an emulator timeout alone is insufficient protection against desktop lockup; do not describe it as guaranteeing recovery.

## Local interactive emulator remains the objective

Do not treat physical-device testing as the permanent resolution of this host defect. Next targeted route: run the Android emulator without its Qt windows and provide an interactive UI through a separate native Wayland client (scrcpy), or investigate Android Studio's embedded Running Devices display. This separates Android execution from the suspected standalone Qt/XWayland window interaction. Neither route is yet verified here. scrcpy is not currently installed. Its official FAQ documents SDL_VIDEODRIVER=wayland; do not silently fall back to X11 during a compatibility experiment. Sources: https://github.com/Genymobile/scrcpy/blob/master/FAQ.md and https://developer.android.com/studio/run/emulator-launch-separate-window .

Preserved previous-boot COSMIC and kernel journals under docs/host-diagnostics/ (gitignored because they contain host details). Future captures must be written there, not /tmp. Establish external recovery before any new launch; no further test was started during this planning/investigation step.

## Expanded upstream investigation

Reviewed October 30, 2026 without launching a device:

- https://github.com/pop-os/cosmic-comp/issues/1576 (August 11, 2025, open on inspected page): reproducible Android-emulator-associated RAM/VRAM growth attributed by reporter to Xwayland on Intel+iGPU/NVIDIA hardware. A distinct candidate failure mode; we did not preserve measurements proving it occurred here.
- https://github.com/pop-os/cosmic-comp/issues/2592 (July 17, 2026, open): standalone emulator toolbar and snapshot windows fail to stay with the parent; reporter contrasts working KDE behavior and explicitly distinguishes standalone from embedded Studio usage. This is window-handling evidence, not proof embedded mode solves freezes.
- https://github.com/pop-os/cosmic-comp/issues/2614 (July 21, 2026, open): unstable emulator interaction can disrupt other applications; report identifies no-window plus scrcpy as a workaround. No independent verification on this host.
- https://github.com/pop-os/cosmic-comp/issues/2965 (October 18, 2026, open): closest documented stall, with measured transient-window map/unmap loop. The reporter describes hours before failure, whereas our visible test failed quickly, so do not claim identical root cause.
- https://github.com/pop-os/cosmic-comp/issues/3000 (October 27, 2026, open): non-emulator Qt/X11 client freezes desktop input; software GL does not fix it, native Wayland build works for that reporter. Shows this class of problem is not uniquely tied to Android or NVIDIA.
- https://github.com/pop-os/cosmic-comp/pull/2835 (September 8, 2026, open on inspected page): proposed X11 transient/shape handling changes. Motivated by a game launcher, not a demonstrated emulator freeze fix. No basis to install an unreviewed compositor build as an established cure.

Inspected pages did not provide a maintainer-confirmed fix for the closest emulator stall. GitHub sometimes reports loading errors, so absence of rendered comments must not be represented as proof no discussions exist. Recommended next experiment remains a different UI presentation path (native Wayland scrcpy or embedded Studio) with durable capture and external recovery, rather than another identical standalone launch. An alternate desktop session would be a useful controlled comparison if separately approved; it is not yet installed or tested here. A VM adds a virtual graphics layer before the direct window-path hypothesis has been isolated.

## Native Wayland scrcpy experiment

Installed official scrcpy 5.0.1 x86_64 release locally under .local-tools/; verified archive SHA-256 against the official Linux installation page (9f969d30cc574816077edecda65719c1c70b0aee1df1ba5fa00779ac07b8fd6e). No system packages or graphics settings changed. Added explicit-only scripts/test-scrcpy-compat.sh with persistent diagnostics, a headless SwiftShader emulator and a Wayland-only scrcpy window with software renderer, 1280px maximum stream size and 30fps cap. First attempt stopped because the app was missing; retry installed the existing development-signed APK successfully.

The user confirmed the app was visible and the desktop stable during the scrcpy test. The window-icon protocol warning is cosmetic. This establishes a promising interactive local emulator route; it does not yet establish long-session or audio reliability. Routine automatic emulator launching remains prohibited. Run this script only as an explicitly authorized compatibility test, not as part of normal build/test checks.

## Sound testing

Initial scrcpy output capture was silent to the user although coaching playback delivered frames and volumes were unmuted. Direct host-emulator playback also failed with `Could not init pa audio driver`, including when the PulseAudio socket was specified. Host pactl connected successfully to PipeWire's PulseAudio service; no host audio configuration was changed.

Added `--audio` to scripts/test-scrcpy-compat.sh: native Wayland video plus required Android playback capture, raw PCM and 100ms buffer, without emulator host audio. Coaching speech was changed from driving-navigation usage to spoken media; the debug build and native unit suite passed. This classification allows media playback capture, but audible coaching after that change has not yet been verified separately.

Added DebugAudioActivity under src/debug only. It synthesizes and loops an original eight-note melody through AudioTrack using media attributes, with Pause/Close controls and lifecycle cleanup. User explicitly confirmed **music audible and desktop stable** during this test. This verifies the end-to-end continuous Android-to-scrcpy-to-host audio path, not headset/call/ducking behavior or individual coaching cues. The screen is excluded from release builds. No microphone capture is used.

To reproduce only when authorized: `RUNPROGRAM_TEST_ACTIVITY=.DebugAudioActivity RUNPROGRAM_TEST_APK=build/app/outputs/flutter-apk/app-debug.apk bash scripts/test-scrcpy-compat.sh --audio`. The script stops the session automatically. The earlier --host-audio path remains diagnostic only and failed here.


## Real coaching cue acceptance and launcher improvements

User confirmed actual voice cues audible and desktop stable in the audio lab. Logcat recorded the real CoachAudio sequence (warmup, resume_warmup, run, walk, halfway, minute, cooldown, resume_cooldown, complete, modified). Added local RunProgramAudio cue start/completion/focus/error logs, individual replay buttons and Play all coaching cues. Lab layout scrolls and accounts for the bottom system inset.

New user-invoked scripts/dev-android.sh builds the current debug APK and opens either app or audio lab through the pinned native-Wayland scrcpy setup. Default duration is 120 seconds; explicit sessions can select 30–1200 seconds. The harness preserves logs, checks duplicate sessions, propagates scrcpy failure status and stops helper process groups. No standalone emulator window or desktop configuration change is involved.
