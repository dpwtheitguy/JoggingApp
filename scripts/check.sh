#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
source scripts/dev-env.sh
serial=''
case "${1:-}" in
 '') ;;
 --device)
  serial="${2:-${ANDROID_SERIAL:-}}"
  [[ -n "$serial" ]] || { echo 'Select a disposable device explicitly: bash scripts/check.sh --device DEVICE_SERIAL'; exit 2; }
  ;;
 *) echo 'Usage: bash scripts/check.sh [--device DEVICE_SERIAL]'; exit 2 ;;
esac
flutter pub get
flutter analyze
flutter test
./android/gradlew -p android testDebugUnitTest
flutter build apk --debug
if [[ -n "$serial" ]]; then
  bash scripts/run-runtime-tests.sh "$serial"
fi
