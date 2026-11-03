#!/usr/bin/env bash
# Explicit compatibility test only; never invoked by routine checks.
set -euo pipefail
cd "$(dirname "$0")/.."
source scripts/dev-env.sh
seconds="${RUNPROGRAM_TEST_SECONDS:-120}"
[[ "$seconds" =~ ^[0-9]+$ ]] && ((seconds >= 30 && seconds <= 1200)) || { echo 'Duration must be 30–1200 seconds.'; exit 2; }
mirror="$PWD/.local-tools/scrcpy-linux-x86_64-v5.0.1/scrcpy"
apk="${RUNPROGRAM_TEST_APK:-build/app/outputs/flutter-apk/app-debug.apk}"
[[ -x "$mirror" && -f "$apk" ]] || { echo 'scrcpy or APK missing; see DEVELOPMENT.md.'; exit 1; }
[[ "${XDG_SESSION_TYPE:-}" == wayland ]] || { echo 'Wayland session required'; exit 1; }
# Protect the shared AVD and port; never terminate someone else's device.
mkdir -p docs/host-diagnostics
exec 9>docs/host-diagnostics/scrcpy.lock
flock -n 9 || { echo 'Another compatibility test is running.'; exit 1; }
if pgrep -f '^/.*qemu-system.*-avd RunProgram_API_36' >/dev/null || adb devices | rg -q '^emulator-5580[[:space:]]'; then
 echo 'The test AVD or port is already in use. Close it before testing.'; exit 1
fi
out="$PWD/docs/host-diagnostics/scrcpy-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$out"
exec > >(tee "$out/test.log") 2>&1
audio_args=(--no-audio)
emulator_audio_args=(-no-audio)
case "${1:-}" in
 '') ;;
 --audio) audio_args=(--require-audio --audio-source=playback --audio-codec=raw --audio-buffer=100) ;;
 --host-audio) emulator_audio_args=(); export PULSE_SERVER="unix:${XDG_RUNTIME_DIR}/pulse/native" ;;
 *) echo 'Usage: bash scripts/test-scrcpy-compat.sh [--audio|--host-audio]'; exit 2 ;;
esac
read_only_args=()
[[ "${RUNPROGRAM_TEST_READ_ONLY:-0}" == 1 ]] && read_only_args=(-read-only)
pids=()
ep=''
cleanup() {
 trap - EXIT INT TERM
 if [[ -n "$ep" ]] && kill -0 "$ep" 2>/dev/null; then
  timeout 5s adb -s emulator-5580 emu kill || true
 fi
 # Each helper has its own process group, including resource sampler children.
 for pid in "${pids[@]}"; do kill -TERM -- "-$pid" 2>/dev/null || true; done
 sleep 1
 for pid in "${pids[@]}"; do kill -KILL -- "-$pid" 2>/dev/null || true; done
 for pid in "${pids[@]}"; do wait "$pid" 2>/dev/null || true; done
 echo 'Compatibility test stopped.'
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
setsid journalctl --user -f --since now > "$out/desktop.log" 2>&1 & pids+=("$!")
setsid journalctl -k -f --since now > "$out/kernel.log" 2>&1 & pids+=("$!")
setsid bash -c 'while :; do date -Is; free -m; ps -eo pid,comm,pcpu,rss --sort=-pcpu | head -12; sleep 5; done' > "$out/resources.log" & pids+=("$!")
# This deadline is independent of the UI. It cannot guarantee desktop recovery.
setsid timeout --signal=TERM --kill-after=10s "$((seconds + 120))s" emulator -avd RunProgram_API_36 "${read_only_args[@]}" -port 5580 -no-window "${emulator_audio_args[@]}" -no-boot-anim -no-snapshot -gpu swiftshader -memory 2560 -cores 2 > "$out/emulator.log" 2>&1 & ep=$!; pids+=("$ep")
booted=0
for n in $(seq 1 35); do
 kill -0 "$ep" 2>/dev/null || { echo 'Emulator exited'; exit 1; }
 boot=$(timeout 3s adb -s emulator-5580 shell getprop sys.boot_completed 2>/dev/null || true)
 if [[ "$boot" == 1* ]]; then booted=1; break; fi
 sleep 2
done
[[ "$booted" == 1 ]] || { echo 'Boot deadline exceeded'; exit 1; }
setsid adb -s emulator-5580 logcat -v threadtime > "$out/android.log" 2>&1 & pids+=("$!")
timeout 40s adb -s emulator-5580 install -r "$apk"
# Start after the launcher has settled; cold-boot home can otherwise cover the activity.
adb -s emulator-5580 shell input keyevent 82
activity="${RUNPROGRAM_TEST_ACTIVITY:-.MainActivity}"
extra=()
[[ "$activity" == .DebugAudioActivity ]] && extra=(--ez cues true)
adb -s emulator-5580 shell am start -W -n "com.joggingapp.runprogram/$activity" "${extra[@]}" | tee "$out/launch.log"
# A guest reboot disconnects scrcpy. Explicit headless checks keep the same
# bounded emulator alive without auto-restarting a window or virtual device.
if [[ "${RUNPROGRAM_TEST_HEADLESS_ONLY:-0}" == 1 ]]; then
 echo "Headless test started for $seconds seconds. Logs: $out"
 for ((second=0; second<seconds; second++)); do
  [[ -f "$out/session-complete" ]] && break
  kill -0 "$ep" 2>/dev/null || { echo 'Emulator exited during headless test.'; exit 1; }
  sleep 1
 done
 timeout 5s adb -s emulator-5580 exec-out screencap -p > "$out/app.png" || true
 exit 0
fi
# Force native Wayland. Do not silently fall back to X11, grab input or use fullscreen.
setsid env SDL_VIDEODRIVER=wayland SDL_VIDEO_DRIVER=wayland timeout --signal=TERM --kill-after=5s "$((seconds + 10))s" "$mirror" -s emulator-5580 "${audio_args[@]}" --max-size=1280 --max-fps=30 --render-driver=software --time-limit="$seconds" --window-title='RUN PROGRAM development test' --verbosity=debug > "$out/scrcpy.log" 2>&1 & sp=$!; pids+=("$sp")
echo "Interactive test started for $seconds seconds. Logs: $out"
result=0
wait "$sp" || result=$?
timeout 5s adb -s emulator-5580 exec-out screencap -p > "$out/app.png" || true
if ((result != 0)); then tail -30 "$out/scrcpy.log"; echo "scrcpy failed ($result)"; exit "$result"; fi
