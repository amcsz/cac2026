from django.conf import settings
from django.db import models
from django.utils import timezone


class Organization(models.Model):
    name = models.CharField(max_length=255)
    join_code = models.CharField(max_length=32, unique=True)
    owner = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.PROTECT,
        related_name="owned_organizations",
    )
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["name"]

    def __str__(self):
        return self.name


class OrganizationMembership(models.Model):
    ROLE_MEMBER = "member"
    ROLE_ADMINISTRATOR = "administrator"

    ROLE_CHOICES = [
        (ROLE_MEMBER, "Member"),
        (ROLE_ADMINISTRATOR, "Administrator"),
    ]

    user = models.OneToOneField(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="organization_membership",
    )
    organization = models.ForeignKey(
        Organization,
        on_delete=models.CASCADE,
        related_name="memberships",
    )
    role = models.CharField(max_length=20, choices=ROLE_CHOICES, default=ROLE_MEMBER)
    joined_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["-joined_at"]

    def __str__(self):
        return f"{self.user} in {self.organization}"


class ArchiveDay(models.Model):
    organization = models.ForeignKey(
        Organization,
        on_delete=models.CASCADE,
        related_name="archive_days",
    )
    date = models.DateField()

    class Meta:
        ordering = ["-date"]
        constraints = [
            models.UniqueConstraint(
                fields=["organization", "date"],
                name="unique_archive_day_per_organization",
            )
        ]

    def __str__(self):
        return f"{self.organization} archive for {self.date}"


def get_archive_day_for_datetime(organization, value):
    return ArchiveDay.objects.get_or_create(
        organization=organization,
        date=timezone.localtime(value).date(),
    )[0]


class EmergencyReport(models.Model):
    TYPE_FIRE = "fire"
    TYPE_MEDICAL = "medical"
    TYPE_INTRUDER = "intruder"

    TYPE_CHOICES = [
        (TYPE_FIRE, "Fire"),
        (TYPE_MEDICAL, "Medical"),
        (TYPE_INTRUDER, "Intruder"),
    ]

    organization = models.ForeignKey(
        Organization,
        on_delete=models.CASCADE,
        related_name="emergency_reports",
    )
    reported_by = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="emergency_reports",
    )
    emergency_type = models.CharField(max_length=20, choices=TYPE_CHOICES)
    details = models.TextField(blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    archive_day = models.ForeignKey(
        ArchiveDay,
        on_delete=models.CASCADE,
        related_name="reports",
        null=True,
        blank=True,
    )

    class Meta:
        ordering = ["-created_at"]

    def __str__(self):
        return f"{self.get_emergency_type_display()} emergency report"


class ReportConversation(models.Model):
    organization = models.ForeignKey(
        Organization,
        on_delete=models.CASCADE,
        related_name="report_conversations",
    )
    report = models.OneToOneField(
        EmergencyReport,
        on_delete=models.CASCADE,
        related_name="conversation",
    )
    created_by = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="created_report_conversations",
    )
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ["-updated_at"]

    def __str__(self):
        return f"Conversation for report {self.report_id}"


class ReportMessage(models.Model):
    conversation = models.ForeignKey(
        ReportConversation,
        on_delete=models.CASCADE,
        related_name="messages",
    )
    sender = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="report_messages",
    )
    body = models.TextField()
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["created_at"]

    def __str__(self):
        return f"Message in conversation {self.conversation_id}"


class GlobalAlert(models.Model):
    INCIDENT_FIRE = "fire"
    INCIDENT_INTRUDER = "intruder"
    INCIDENT_CHOICES = [
        (INCIDENT_FIRE, "Fire"),
        (INCIDENT_INTRUDER, "Intruder"),
    ]

    organization = models.ForeignKey(
        Organization,
        on_delete=models.CASCADE,
        related_name="global_alerts",
    )
    created_by = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="global_alerts",
    )
    headline = models.CharField(max_length=120)
    message = models.TextField()
    incident_type = models.CharField(
        max_length=20,
        choices=INCIDENT_CHOICES,
        default=INCIDENT_FIRE,
    )
    admins_only = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)
    archive_day = models.ForeignKey(
        ArchiveDay,
        on_delete=models.CASCADE,
        related_name="global_alerts",
        null=True,
        blank=True,
    )
    is_active = models.BooleanField(default=True)

    class Meta:
        ordering = ["-created_at"]

    def __str__(self):
        return self.headline


class DailyAlertSummary(models.Model):
    INCIDENT_MEDICAL = "medical"
    INCIDENT_CHOICES = [
        *GlobalAlert.INCIDENT_CHOICES,
        (INCIDENT_MEDICAL, "Medical"),
    ]
    organization = models.ForeignKey(
        Organization,
        on_delete=models.CASCADE,
        related_name="daily_alert_summaries",
    )
    date = models.DateField()
    headline = models.CharField(max_length=120)
    summary = models.TextField()
    draft_message = models.TextField()
    incident_type = models.CharField(
        max_length=20,
        choices=INCIDENT_CHOICES,
        default=GlobalAlert.INCIDENT_FIRE,
    )
    verified = models.BooleanField(default=False)
    needs_verification = models.BooleanField(default=False)
    report_count = models.PositiveIntegerField(default=0)
    generated_at = models.DateTimeField(default=timezone.now)
    ai_unavailable = models.BooleanField(default=False)

    class Meta:
        ordering = ["-date"]
        constraints = [
            models.UniqueConstraint(
                fields=["organization", "date"],
                name="unique_daily_alert_summary_per_organization",
            )
        ]

    def __str__(self):
        return f"{self.organization} summary for {self.date}"


class FcmDevice(models.Model):
    PLATFORM_ANDROID = "android"
    PLATFORM_IOS = "ios"
    PLATFORM_WEB = "web"

    PLATFORM_CHOICES = [
        (PLATFORM_ANDROID, "Android"),
        (PLATFORM_IOS, "iOS"),
        (PLATFORM_WEB, "Web"),
    ]

    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="fcm_devices",
    )
    organization = models.ForeignKey(
        Organization,
        on_delete=models.CASCADE,
        related_name="fcm_devices",
        null=True,
        blank=True,
    )
    token = models.TextField(unique=True)
    platform = models.CharField(max_length=20, choices=PLATFORM_CHOICES)
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ["-updated_at"]

    def __str__(self):
        return f"{self.user} {self.platform} FCM device"
