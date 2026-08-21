#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "Usage: $0 https://YOUR-CLOUD-RUN-URL.run.app/api" >&2
}

if [[ $# -ne 1 ]]; then
  usage
  exit 2
fi

api_base_url="${1%/}"

if [[ ! "$api_base_url" =~ ^https:// ]]; then
  echo "ApiBaseUrl must be an HTTPS URL, for example:" >&2
  echo "  https://your-service.run.app/api" >&2
  exit 2
fi

if [[ ! "$api_base_url" =~ /api$ ]]; then
  echo "Warning: ApiBaseUrl does not end with /api." >&2
  echo "FastGuard expects the Django API base URL." >&2
fi

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd -- "$script_dir/.." && pwd)"
frontend_dir="$repo_root/frontend"
android_dir="$frontend_dir/android"
local_properties="$android_dir/local.properties"
google_services_file="$android_dir/app/google-services.json"

required_ndk_version="28.2.13676358"

if [[ ! -f "$google_services_file" ]]; then
  cat >&2 <<EOF
Firebase Android config is missing:
  $google_services_file

Download google-services.json from Firebase Console for Android package:
  com.example.cac2026_frontend

Then rerun this build script.
EOF
  exit 1
fi

# ---------------------------------------------------------------------------
# Find sdkmanager
# ---------------------------------------------------------------------------

if ! command -v sdkmanager >/dev/null 2>&1; then
  cat >&2 <<'EOF'
sdkmanager was not found.

On Debian/WSL, install it with:

  sudo apt update
  sudo apt install sdkmanager

Then rerun this build script.
EOF
  exit 127
fi

sdkmanager_bin="$(command -v sdkmanager)"

# ---------------------------------------------------------------------------
# Determine Android SDK root
#
# Priority:
#   1. sdk.dir in frontend/android/local.properties
#   2. ANDROID_SDK_ROOT
#   3. ANDROID_HOME
#   4. Debian/WSL default: /usr/lib/android-sdk
# ---------------------------------------------------------------------------

sdk_root=""

if [[ -f "$local_properties" ]]; then
  sdk_dir_line="$(
    grep -E '^sdk\.dir=' "$local_properties" 2>/dev/null | tail -n 1 || true
  )"

  if [[ -n "$sdk_dir_line" ]]; then
    sdk_root="${sdk_dir_line#sdk.dir=}"

    # local.properties may escape ':' and '\' on some platforms.
    sdk_root="${sdk_root//\\:/:}"
    sdk_root="${sdk_root//\\\\/\\}"
  fi
fi

if [[ -z "$sdk_root" && -n "${ANDROID_SDK_ROOT:-}" ]]; then
  sdk_root="$ANDROID_SDK_ROOT"
fi

if [[ -z "$sdk_root" && -n "${ANDROID_HOME:-}" ]]; then
  sdk_root="$ANDROID_HOME"
fi

if [[ -z "$sdk_root" ]]; then
  sdk_root="/usr/lib/android-sdk"
fi

echo "Android SDK:"
echo "  $sdk_root"
echo

if [[ ! -d "$sdk_root" ]]; then
  echo "Android SDK directory does not exist:" >&2
  echo "  $sdk_root" >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# Decide whether sdkmanager needs sudo
# ---------------------------------------------------------------------------

sdkmanager_cmd=(
  "$sdkmanager_bin"
  "--sdk_root=$sdk_root"
)

if [[ ! -w "$sdk_root" ]]; then
  if ! command -v sudo >/dev/null 2>&1; then
    cat >&2 <<EOF
The Android SDK is not writable by the current user:

  $sdk_root

sudo is also unavailable.

Either make the SDK writable by your user or accept/install the required
Android packages manually.
EOF
    exit 1
  fi

  sdkmanager_cmd=(
    sudo
    "$sdkmanager_bin"
    "--sdk_root=$sdk_root"
  )
fi

# ---------------------------------------------------------------------------
# Accept Android SDK licenses
#
# With `set -o pipefail`, `yes` may exit with SIGPIPE after sdkmanager stops
# reading stdin. We therefore inspect sdkmanager's own exit status rather
# than the status of the entire pipeline.
# ---------------------------------------------------------------------------

accept_android_licenses() {
  local sdkmanager_status

  echo "Accepting Android SDK licenses..."

  set +o pipefail

  yes | "${sdkmanager_cmd[@]}" --licenses >/dev/null
  sdkmanager_status="${PIPESTATUS[1]}"

  set -o pipefail

  if [[ "$sdkmanager_status" -ne 0 ]]; then
    echo "Failed to accept Android SDK licenses." >&2
    return "$sdkmanager_status"
  fi

  echo "Android SDK licenses accepted."
}

if ! accept_android_licenses; then
  cat >&2 <<EOF

Try running this manually:

  yes | sudo "$sdkmanager_bin" --sdk_root="$sdk_root" --licenses

Then rerun:

  $0 "$api_base_url"
EOF
  exit 1
fi

echo

# ---------------------------------------------------------------------------
# Install the exact NDK required by the Android project
# ---------------------------------------------------------------------------

ndk_dir="$sdk_root/ndk/$required_ndk_version"

if [[ ! -d "$ndk_dir" ]]; then
  echo "Android NDK $required_ndk_version is not installed."
  echo "Installing:"
  echo "  ndk;$required_ndk_version"
  echo

  "${sdkmanager_cmd[@]}" "ndk;$required_ndk_version"
else
  echo "Android NDK already installed:"
  echo "  $ndk_dir"
fi

echo

# ---------------------------------------------------------------------------
# Verify Flutter
# ---------------------------------------------------------------------------

if ! command -v flutter >/dev/null 2>&1; then
  echo "flutter was not found in PATH." >&2
  exit 127
fi

# ---------------------------------------------------------------------------
# Build APK
# ---------------------------------------------------------------------------

echo "Building Android release APK..."
echo
echo "API base URL:"
echo "  $api_base_url"
echo

cd "$frontend_dir"

flutter build apk \
  --release \
  --dart-define="API_BASE_URL=$api_base_url"

apk_path="$frontend_dir/build/app/outputs/flutter-apk/app-release.apk"

echo
echo "============================================================"
echo "APK build complete"
echo "============================================================"
echo

if [[ -f "$apk_path" ]]; then
  echo "APK:"
  echo "  $apk_path"
else
  echo "Warning: Flutter completed, but the expected APK was not found:" >&2
  echo "  $apk_path" >&2
fi

echo
echo "Install with:"
echo "  $repo_root/scripts/install-android-apk.sh"
echo
