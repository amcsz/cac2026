import json
import logging

import firebase_admin
from django.conf import settings
from firebase_admin import credentials, messaging

from .models import FcmDevice, OrganizationMembership


logger = logging.getLogger(__name__)


def send_global_alert_push(alert):
    devices = FcmDevice.objects.filter(
        organization=alert.organization,
        is_active=True,
    )
    if alert.admins_only:
        devices = devices.filter(
            user__organization_membership__role=OrganizationMembership.ROLE_ADMINISTRATOR,
        )
    _send_push(
        devices,
        title=alert.headline,
        body=_plain_text(alert.message),
        data={
            "type": "global_alert",
            "alert_id": str(alert.id),
            "organization_id": str(alert.organization_id),
        },
        log_context=(
            "global alert",
            f"alert_id={alert.id} organization_id={alert.organization_id}",
        ),
    )


def send_new_report_push(report):
    """Notify organization administrators about a newly submitted report."""
    devices = FcmDevice.objects.filter(
        organization=report.organization,
        is_active=True,
        user__organization_membership__role=OrganizationMembership.ROLE_ADMINISTRATOR,
    ).exclude(user_id=report.reported_by_id)
    _send_push(
        devices,
        title=f"New {report.emergency_type} report",
        body=f"{report.reported_by.username}: {_plain_text(report.details)[:180]}",
        data={
            "type": "new_report",
            "report_id": str(report.id),
            "organization_id": str(report.organization_id),
        },
        log_context=(
            "new report",
            f"report_id={report.id} organization_id={report.organization_id}",
        ),
    )


def send_comms_message_push(message):
    """Notify the report author and all organization administrators except sender."""
    conversation = message.conversation
    recipient_ids = set(
        OrganizationMembership.objects.filter(
            organization=conversation.organization,
            role=OrganizationMembership.ROLE_ADMINISTRATOR,
        ).values_list("user_id", flat=True)
    )
    recipient_ids.add(conversation.report.reported_by_id)
    recipient_ids.discard(message.sender_id)

    devices = FcmDevice.objects.filter(
        organization=conversation.organization,
        is_active=True,
        user_id__in=recipient_ids,
    )
    _send_push(
        devices,
        title=f"Message about {conversation.report.reported_by.username}",
        body=f"{message.sender.username}: {_plain_text(message.body)[:180]}",
        data={
            "type": "comms_message",
            "conversation_id": str(conversation.id),
            "report_id": str(conversation.report_id),
            "organization_id": str(conversation.organization_id),
        },
        log_context=(
            "Comms message",
            f"message_id={message.id} conversation_id={conversation.id}",
        ),
    )


def _send_push(devices, *, title, body, data, log_context):
    tokens = list(devices.values_list("token", flat=True).distinct())
    if not tokens:
        logger.info("No active FCM devices for %s %s", log_context[0], log_context[1])
        return

    try:
        _ensure_firebase_app()
    except Exception:
        logger.exception("Firebase Admin is not configured; push not sent.")
        return

    # FCM multicast requests accept at most 500 registration tokens.
    for start in range(0, len(tokens), 500):
        batch = tokens[start:start + 500]
        message = messaging.MulticastMessage(
            tokens=batch,
            notification=messaging.Notification(title=title, body=body),
            data=data,
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
            "Sent %s %s success=%s failure=%s",
            log_context[0],
            log_context[1],
            response.success_count,
            response.failure_count,
        )
        if response.failure_count:
            _log_failed_tokens(batch, response.responses)
            _deactivate_failed_tokens(batch, response.responses)


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
