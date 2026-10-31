#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
source scripts/dev-env.sh
flutter pub get
flutter analyze
flutter test
./android/gradlew -p android testDebugUnitTest
if [[ "${1:-}" == "--device" ]]; then
  ./android/gradlew -p android connectedDebugAndroidTest
fi
flutter build apk --debug
