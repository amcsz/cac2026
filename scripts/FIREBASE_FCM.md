# SwiftGuard Firebase Cloud Messaging Setup

## Firebase console

1. Create or open a Firebase project.
2. Add an Android app with package name:

```text
com.example.cac2026_frontend
```

3. Download `google-services.json`.
4. Put it here:

```text
frontend/android/app/google-services.json
```

## Backend credentials

Create a Firebase service account key in Firebase/GCP and provide it to Django with one of these environment variables:

```bash
FIREBASE_CREDENTIALS_JSON='{"type":"service_account",...}'
```

or:

```bash
FIREBASE_CREDENTIALS_FILE=/path/to/service-account.json
```

On Cloud Run, prefer Secret Manager for `FIREBASE_CREDENTIALS_JSON`.

## Build Android

After adding `google-services.json`:

```bash
./scripts/build-android-apk.sh https://YOUR-CLOUD-RUN-URL.run.app/api
```

Install:

```bash
./scripts/install-android-apk.sh
```

## How it works

- The Android app asks Firebase for an FCM token after login.
- The app registers that token with Django at `/api/auth/fcm-device/`.
- When an admin publishes a global alert, Django sends an FCM push to active devices in the organization.
- Foreground FCM messages are displayed using local notifications.
