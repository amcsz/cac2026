import json
import logging

import firebase_admin
from django.conf import settings
from firebase_admin import credentials, messaging

from .models import FcmDevice


logger = logging.getLogger(__name__)


def send_global_alert_push(alert):
    tokens = list(
        FcmDevice.objects.filter(
            organization=alert.organization,
            is_active=True,
        ).values_list("token", flat=True)
    )
    if not tokens:
        logger.warning(
            "No active FCM devices for global alert id=%s organization_id=%s",
            alert.id,
            alert.organization_id,
        )
        return

    try:
        _ensure_firebase_app()
    except Exception:
        logger.exception("Firebase Admin is not configured; push not sent.")
        return

    message = messaging.MulticastMessage(
        tokens=tokens,
        notification=messaging.Notification(
            title=alert.headline,
            body=_plain_text(alert.message),
        ),
        data={
            "type": "global_alert",
            "alert_id": str(alert.id),
            "organization_id": str(alert.organization_id),
        },
        android=messaging.AndroidConfig(
            priority="high",
            notification=messaging.AndroidNotification(
                channel_id="swiftguard_alerts",
                priority="high",
            ),
        ),
    )

    response = messaging.send_each_for_multicast(message)
    logger.warning(
        "Sent global alert push alert_id=%s organization_id=%s success=%s failure=%s",
        alert.id,
        alert.organization_id,
        response.success_count,
        response.failure_count,
    )
    if response.failure_count:
        _log_failed_tokens(tokens, response.responses)
        _deactivate_failed_tokens(tokens, response.responses)


def _ensure_firebase_app():
    if firebase_admin._apps:
        return

    credentials_json = getattr(settings, "FIREBASE_CREDENTIALS_JSON", "")
    credentials_file = getattr(settings, "FIREBASE_CREDENTIALS_FILE", "")

    if credentials_json:
        credential = credentials.Certificate(json.loads(credentials_json))
    elif credentials_file:
        credential = credentials.Certificate(credentials_file)
    else:
        credential = credentials.ApplicationDefault()

    firebase_admin.initialize_app(credential)


def _deactivate_failed_tokens(tokens, responses):
    invalid_tokens = [
        token
        for token, response in zip(tokens, responses)
        if not response.success and _is_invalid_token_error(response.exception)
    ]
    if invalid_tokens:
        FcmDevice.objects.filter(token__in=invalid_tokens).update(is_active=False)
        logger.warning("Deactivated %s invalid FCM tokens.", len(invalid_tokens))


def _log_failed_tokens(tokens, responses):
    for token, response in zip(tokens, responses):
        if response.success:
            continue

        exception = response.exception
        logger.warning(
            "FCM push failure token_suffix=%s exception_type=%s code=%s message=%s",
            token[-12:],
            exception.__class__.__name__ if exception else "None",
            getattr(exception, "code", ""),
            str(exception),
        )


def _is_invalid_token_error(exception):
    if exception is None:
        return False

    code = getattr(exception, "code", "")
    message = str(exception).lower()
    return code in {
        "registration-token-not-registered",
        "invalid-registration-token",
        "permission_denied",
        "unregistered",
    } or any(
        text in message
        for text in [
            "registration token is not a valid fcm registration token",
            "senderid mismatch",
            "sender id mismatch",
        ]
    )


def _plain_text(value):
    return (
        value.replace("**", "")
        .replace("_", "")
        .replace("`", "")
        .replace("#", "")
        .strip()
    )
