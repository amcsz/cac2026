# FastGuard Android APK on Debian/WSL

## One-time setup

Install Android Debug Bridge and the SDK command-line license tool:

```bash
sudo apt update
sudo apt install android-tools-adb sdkmanager
yes | sdkmanager --licenses
```

If license acceptance fails because `/usr/lib/android-sdk` is not writable, use:

```bash
yes | sudo sdkmanager --licenses
```

On your Android phone:

1. Enable Developer Options.
2. Enable USB debugging.
3. Connect the phone by USB.
4. Accept the USB debugging prompt.

If WSL cannot see the phone, attach the USB device to WSL from Windows with `usbipd`.

## Build

Use your Cloud Run Django API base URL. It should end with `/api`.

```bash
./scripts/build-android-apk.sh https://YOUR-CLOUD-RUN-URL.run.app/api
```

If the build says an Android SDK license was not accepted, run:

```bash
yes | sdkmanager --licenses
```

The APK will be created at:

```text
frontend/build/app/outputs/flutter-apk/app-release.apk
```

## Install

```bash
./scripts/install-android-apk.sh
```

Then open FastGuard from the Android app drawer.

## Notes

- This creates an installable Android app, not the local web version.
- The Cloud Run service must be reachable from the phone.
- The Cloud Run/IAM layer must allow requests to reach Django. FastGuard login still handles app-level authentication.
- Android system push notifications are not implemented yet. The installed app still shows in-app emergency/global-alert UI.
