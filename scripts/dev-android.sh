#!/usr/bin/env bash
# User-invoked only: builds the current debug app and opens a bounded Wayland UI.
set -euo pipefail
cd "$(dirname "$0")/.."
source scripts/dev-env.sh
case "${1:-app}" in
 app) export RUNPROGRAM_TEST_ACTIVITY=.MainActivity ;;
 audio) export RUNPROGRAM_TEST_ACTIVITY=.DebugAudioActivity ;;
 *) echo 'Usage: bash scripts/dev-android.sh [app|audio]'; exit 2 ;;
esac
export RUNPROGRAM_TEST_APK=build/app/outputs/flutter-apk/app-debug.apk
flutter build apk --debug
exec bash scripts/test-scrcpy-compat.sh --audio
