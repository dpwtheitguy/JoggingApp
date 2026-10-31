#!/usr/bin/env bash
# Run in your own terminal; sudo may request your password.
set -euo pipefail
sudo apt-get update
sudo apt-get install -y curl git unzip xz-utils zip libglu1-mesa \
  libx11-6 libxrender1 libxtst6 libxi6 libfreetype6 libfontconfig1 \
  libnss3 libasound2t64 libpulse0 libbz2-1.0 lib32z1 lib32stdc++6 \
  qemu-kvm cpu-checker android-sdk-platform-tools-common
printf '%s\n' 'This script targets the current Intel Pop!_OS/Ubuntu 24.04 workstation.'
printf '%s\n' 'Use emulator -accel-check to verify KVM; see DEVELOPMENT.md if access is denied.'
