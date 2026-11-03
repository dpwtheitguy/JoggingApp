#!/usr/bin/env bash
# Run only on an explicitly selected disposable device/read-only emulator session.
set -euo pipefail
cd "$(dirname "$0")/.."
source scripts/dev-env.sh
serial="${1:-}"
soak="${2:-0}"
[[ -n "$serial" && "$soak" =~ ^[0-9]+$ ]] || { echo 'Usage: bash scripts/run-runtime-tests.sh SERIAL [SOAK_SECONDS]'; exit 2; }
((soak == 0 || (soak >= 60 && soak <= 1200))) || { echo 'Soak must be 0 or 60–1200 seconds.'; exit 2; }
adb -s "$serial" get-state >/dev/null
out="$PWD/docs/host-diagnostics/runtime-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$out"
./android/gradlew -p android assembleDebug assembleDebugAndroidTest > "$out/build.log" 2>&1
adb -s "$serial" install -r build/app/outputs/apk/debug/app-debug.apk
adb -s "$serial" install -r build/app/outputs/apk/androidTest/debug/app-debug-androidTest.apk
# A failing instrumentation runner may still return adb exit status zero.
timeout 300s adb -s "$serial" shell am instrument -w \
 -e class com.joggingapp.runprogram.CoachDatabaseTest,com.joggingapp.runprogram.WorkoutServiceTest \
 com.joggingapp.runprogram.test/androidx.test.runner.AndroidJUnitRunner | tee "$out/regression.log"
rg -q '^OK \([0-9]+ tests?\)' "$out/regression.log" || { echo "Device regression failed; inspect $out/regression.log"; exit 1; }
if ((soak > 0)); then
 timeout "$((soak + 120))s" adb -s "$serial" shell am instrument -w \
  -e class com.joggingapp.runprogram.WorkoutSoakTest -e soakSeconds "$soak" \
  com.joggingapp.runprogram.test/androidx.test.runner.AndroidJUnitRunner | tee "$out/soak.log"
 rg -q '^OK \(1 test\)' "$out/soak.log" || { echo "Soak failed; inspect $out/soak.log"; exit 1; }
fi
echo "Runtime checks passed. Logs: $out"
