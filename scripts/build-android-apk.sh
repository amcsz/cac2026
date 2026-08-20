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
  echo "ApiBaseUrl must be an HTTPS URL, for example https://your-service.run.app/api" >&2
  exit 2
fi

if [[ ! "$api_base_url" =~ /api$ ]]; then
  echo "Warning: ApiBaseUrl does not end with /api. FastGuard expects the Django API base URL." >&2
fi

if ! command -v sdkmanager >/dev/null 2>&1; then
  cat >&2 <<'EOF'
sdkmanager was not found.

Install the Android SDK command-line tools on Debian/WSL:
  sudo apt update
  sudo apt install sdkmanager

Then accept Android SDK licenses:
  yes | sdkmanager --licenses

After that, rerun this build script.
EOF
  exit 127
fi

if ! yes | sdkmanager --licenses >/dev/null; then
  cat >&2 <<'EOF'
Warning: sdkmanager could not verify licenses as the current user.

Continuing anyway because Debian/WSL SDK licenses are often accepted with sudo:
  yes | sudo sdkmanager --licenses

If Gradle fails with LicenceNotAcceptedException, run that command and rebuild.
EOF
fi

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd -- "$script_dir/.." && pwd)"

cd "$repo_root/frontend"
flutter build apk --release --dart-define="API_BASE_URL=$api_base_url"

echo
echo "APK built:"
echo "  $repo_root/frontend/build/app/outputs/flutter-apk/app-release.apk"
echo
echo "Install with:"
echo "  $repo_root/scripts/install-android-apk.sh"
