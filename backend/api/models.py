from django.conf import settings
from django.db import models


class Todo(models.Model):
    title = models.CharField(max_length=255)
    completed = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["-created_at"]

    def __str__(self):
        return self.title


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
    ROLE_TEACHER = "teacher"
    ROLE_ADMINISTRATOR = "administrator"

    ROLE_CHOICES = [
        (ROLE_MEMBER, "Member"),
        (ROLE_TEACHER, "Teacher"),
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
    location = models.CharField(max_length=255)
    details = models.TextField(blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["-created_at"]

    def __str__(self):
        return f"{self.get_emergency_type_display()} reported in {self.location}"
