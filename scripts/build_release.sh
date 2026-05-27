#!/usr/bin/env bash
set -euo pipefail

# Smart Flutter release build helper.
# Uses --flavor safe only when a 'safe' flavor is actually defined in android/app Gradle config.

if ! command -v flutter >/dev/null 2>&1; then
  echo "flutter not found in PATH" >&2
  exit 127
fi

HAS_SAFE_FLAVOR=0
if [[ -f android/app/build.gradle ]]; then
  if rg -n "productFlavors|create\(\"safe\"\)|safe\s*\{" android/app/build.gradle >/dev/null 2>&1; then
    HAS_SAFE_FLAVOR=1
  fi
fi
if [[ -f android/app/build.gradle.kts ]]; then
  if rg -n "productFlavors|create\(\"safe\"\)|safe\s*\{" android/app/build.gradle.kts >/dev/null 2>&1; then
    HAS_SAFE_FLAVOR=1
  fi
fi

flutter clean
flutter pub get

if [[ "$HAS_SAFE_FLAVOR" -eq 1 ]]; then
  echo "Detected 'safe' flavor. Running flavored release build..."
  flutter build apk --flavor safe --release
else
  echo "No 'safe' flavor detected. Running default release build..."
  flutter build apk --release
fi
