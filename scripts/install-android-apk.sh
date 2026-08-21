#!/usr/bin/env bash
set -euo pipefail

if ! command -v adb >/dev/null 2>&1; then
  echo "adb was not found." >&2
  echo "Install it on Debian/WSL with: sudo apt update && sudo apt install android-tools-adb" >&2
  exit 127
fi

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd -- "$script_dir/.." && pwd)"
apk_path="${1:-$repo_root/frontend/build/app/outputs/flutter-apk/app-release.apk}"

if [[ ! -f "$apk_path" ]]; then
  echo "APK not found: $apk_path" >&2
  echo "Build it first with: $repo_root/scripts/build-android-apk.sh https://YOUR-CLOUD-RUN-URL.run.app/api" >&2
  exit 2
fi

echo "Checking connected Android devices..."
adb devices

if ! adb devices | awk 'NR > 1 && $2 == "device" { found = 1 } END { exit found ? 0 : 1 }'; then
  echo "No authorized Android device found." >&2
  echo "Enable Developer Options, enable USB debugging, connect the phone, and accept the debugging prompt." >&2
  exit 1
fi

echo "Installing $apk_path..."
adb install -r "$apk_path"

echo
echo "Installed. Open SwiftGuard from your Android app drawer."
