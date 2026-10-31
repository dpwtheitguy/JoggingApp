#!/usr/bin/env bash
# Explicit compatibility test only; never invoked by routine checks.
set -euo pipefail
cd "$(dirname "$0")/.."
source scripts/dev-env.sh
out="$PWD/docs/host-diagnostics/scrcpy-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$out"
exec > >(tee "$out/test.log") 2>&1
mirror="$PWD/.local-tools/scrcpy-linux-x86_64-v5.0.1/scrcpy"
[[ -x "$mirror" ]] || { echo 'Official scrcpy 5.0.1 local tool is missing'; exit 1; }
[[ "${XDG_SESSION_TYPE:-}" == wayland ]] || { echo 'Wayland session required'; exit 1; }
audio_args=(--no-audio)
emulator_audio_args=(-no-audio)
if [[ "${1:-}" == --audio ]]; then
 audio_args=(--require-audio --audio-source=playback --audio-codec=raw --audio-buffer=100)
 emulator_audio_args=(-no-audio)
fi
if [[ "${1:-}" == --host-audio ]]; then
 emulator_audio_args=()
 export PULSE_SERVER="unix:${XDG_RUNTIME_DIR}/pulse/native"
fi
pids=()
cleanup() {
 trap - EXIT INT TERM
 for pid in "${pids[@]}"; do kill -TERM "$pid" 2>/dev/null || true; done
 for pid in "${pids[@]}"; do wait "$pid" 2>/dev/null || true; done
 echo 'Compatibility test stopped.'
}
trap cleanup EXIT INT TERM
journalctl --user -f --since now > "$out/desktop.log" 2>&1 & pids+=("$!")
journalctl -k -f --since now > "$out/kernel.log" 2>&1 & pids+=("$!")
(while :; do date -Is; free -m; ps -eo pid,comm,pcpu,rss --sort=-pcpu | head -12; sleep 5; done) > "$out/resources.log" & pids+=("$!")
timeout --signal=TERM --kill-after=10s 150s emulator -avd RunProgram_API_36 -port 5580 -no-window "${emulator_audio_args[@]}" -no-boot-anim -no-snapshot -gpu swiftshader -memory 1536 -cores 2 > "$out/emulator.log" 2>&1 & ep=$!; pids+=("$ep")
booted=0
for n in $(seq 1 35); do
 kill -0 "$ep" 2>/dev/null || { echo 'Emulator exited'; exit 1; }
 boot=$(timeout 3s adb -s emulator-5580 shell getprop sys.boot_completed 2>/dev/null || true)
 if [[ "$boot" == 1* ]]; then booted=1; break; fi
 sleep 2
done
[[ "$booted" == 1 ]] || { echo 'Boot deadline exceeded'; exit 1; }
adb -s emulator-5580 logcat -v threadtime > "$out/android.log" 2>&1 & pids+=("$!")
timeout 30s adb -s emulator-5580 install -r "${RUNPROGRAM_TEST_APK:-build/app/outputs/flutter-apk/app-release.apk}"
adb -s emulator-5580 shell am start -n "com.joggingapp.runprogram/${RUNPROGRAM_TEST_ACTIVITY:-.MainActivity}"
# Force Wayland only. No X11 fallback; do not grab input or enter fullscreen.
SDL_VIDEODRIVER=wayland SDL_VIDEO_DRIVER=wayland timeout --signal=TERM --kill-after=5s 90s "$mirror" -s emulator-5580 "${audio_args[@]}" --max-size=1280 --max-fps=30 --render-driver=software --time-limit=75 --window-title='RUN PROGRAM compatibility test' --verbosity=debug > "$out/scrcpy.log" 2>&1 & sp=$!; pids+=("$sp")
echo "Interactive test started. Logs: $out"
wait "$sp" || true
adb -s emulator-5580 exec-out screencap -p > "$out/app.png" || true
timeout 5s adb -s emulator-5580 emu kill || true
