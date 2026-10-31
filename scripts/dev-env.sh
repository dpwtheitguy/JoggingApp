# Source this file: source scripts/dev-env.sh
# Override RUNPROGRAM_TOOLS or ANDROID_HOME before sourcing for custom locations.
export RUNPROGRAM_TOOLS="${RUNPROGRAM_TOOLS:-$HOME/Development}"
export ANDROID_HOME="${ANDROID_HOME:-$HOME/Android/Sdk}"
export JAVA_HOME="$RUNPROGRAM_TOOLS/android-studio/jbr"
export PATH="$RUNPROGRAM_TOOLS/flutter/bin:$JAVA_HOME/bin:$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$PATH"
