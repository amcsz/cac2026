import secrets

from django.contrib.auth import authenticate, get_user_model
from django.contrib.auth.password_validation import validate_password
from django.db import IntegrityError, transaction
from rest_framework import serializers
from rest_framework.authtoken.models import Token

from .models import EmergencyReport, GlobalAlert, Organization, OrganizationMembership


User = get_user_model()


class OrganizationSerializer(serializers.ModelSerializer):
    member_count = serializers.IntegerField(source="memberships.count", read_only=True)

    class Meta:
        model = Organization
        fields = ["id", "name", "join_code", "member_count", "created_at"]
        read_only_fields = ["id", "join_code", "member_count", "created_at"]


class OrganizationMembershipSerializer(serializers.ModelSerializer):
    user_id = serializers.IntegerField(source="user.id", read_only=True)
    username = serializers.CharField(source="user.username", read_only=True)
    email = serializers.EmailField(source="user.email", read_only=True)
    is_owner = serializers.SerializerMethodField()

    class Meta:
        model = OrganizationMembership
        fields = ["id", "user_id", "username", "email", "role", "joined_at", "is_owner"]
        read_only_fields = ["id", "user_id", "username", "email", "joined_at", "is_owner"]

    def get_is_owner(self, membership):
        return membership.organization.owner_id == membership.user_id


class UpdateOrganizationMembershipRoleSerializer(serializers.Serializer):
    user_id = serializers.IntegerField()
    role = serializers.ChoiceField(choices=OrganizationMembership.ROLE_CHOICES)


class EmergencyReportSerializer(serializers.ModelSerializer):
    reported_by_username = serializers.CharField(source="reported_by.username", read_only=True)
    organization_name = serializers.CharField(source="organization.name", read_only=True)

    class Meta:
        model = EmergencyReport
        fields = [
            "id",
            "emergency_type",
            "location",
            "details",
            "created_at",
            "reported_by_username",
            "organization_name",
        ]
        read_only_fields = ["id", "created_at", "reported_by_username", "organization_name"]

    def validate(self, attrs):
        user = self.context["request"].user
        membership = getattr(user, "organization_membership", None)
        if membership is None:
            raise serializers.ValidationError("You must belong to an organization before submitting an emergency report.")
        return attrs

    def create(self, validated_data):
        user = self.context["request"].user
        membership = user.organization_membership
        validated_data["reported_by"] = user
        validated_data["organization"] = membership.organization
        return super().create(validated_data)


class GlobalAlertSerializer(serializers.ModelSerializer):
    created_by_username = serializers.CharField(source="created_by.username", read_only=True)

    class Meta:
        model = GlobalAlert
        fields = ["id", "headline", "message", "created_at", "created_by_username"]
        read_only_fields = ["id", "created_at", "created_by_username"]


class PublishGlobalAlertSerializer(serializers.Serializer):
    headline = serializers.CharField(max_length=120)
    message = serializers.CharField()

    def validate_headline(self, value):
        headline = value.strip()
        if not headline:
            raise serializers.ValidationError("Headline is required.")
        return headline

    def validate_message(self, value):
        message = value.strip()
        if not message:
            raise serializers.ValidationError("Message is required.")
        return message


class UserSerializer(serializers.ModelSerializer):
    organization = serializers.SerializerMethodField()
    organization_role = serializers.SerializerMethodField()

    class Meta:
        model = User
        fields = ["id", "username", "email", "organization", "organization_role"]

    def get_organization(self, user):
        membership = getattr(user, "organization_membership", None)
        if membership is None:
            return None
        return OrganizationSerializer(membership.organization).data

    def get_organization_role(self, user):
        membership = getattr(user, "organization_membership", None)
        if membership is None:
            return None
        return membership.role


class AuthResponseSerializer(serializers.Serializer):
    token = serializers.CharField()
    user = UserSerializer()


class RegisterSerializer(serializers.Serializer):
    username = serializers.CharField(max_length=150)
    email = serializers.EmailField(required=False, allow_blank=True)
    password = serializers.CharField(write_only=True, min_length=8)

    def validate_username(self, value):
        username = value.strip()
        if not username:
            raise serializers.ValidationError("Username is required.")
        if User.objects.filter(username__iexact=username).exists():
            raise serializers.ValidationError("A user with this username already exists.")
        return username

    def validate_password(self, value):
        validate_password(value)
        return value

    def create(self, validated_data):
        user = User.objects.create_user(
            username=validated_data["username"],
            email=validated_data.get("email", ""),
            password=validated_data["password"],
        )
        token, _ = Token.objects.get_or_create(user=user)
        return {"token": token.key, "user": user}


class LoginSerializer(serializers.Serializer):
    username = serializers.CharField()
    password = serializers.CharField(write_only=True)

    def validate(self, attrs):
        user = authenticate(username=attrs["username"], password=attrs["password"])
        if user is None:
            raise serializers.ValidationError("Unable to log in with those credentials.")
        if not user.is_active:
            raise serializers.ValidationError("This account is inactive.")

        token, _ = Token.objects.get_or_create(user=user)
        return {"token": token.key, "user": user}


class CreateOrganizationSerializer(serializers.Serializer):
    name = serializers.CharField(max_length=255)

    def validate_name(self, value):
        name = value.strip()
        if not name:
            raise serializers.ValidationError("Organization name is required.")
        return name

    def validate(self, attrs):
        user = self.context["request"].user
        if hasattr(user, "organization_membership"):
            raise serializers.ValidationError("You already belong to an organization.")
        return attrs

    def create(self, validated_data):
        user = self.context["request"].user
        with transaction.atomic():
            organization = Organization.objects.create(
                name=validated_data["name"],
                join_code=self._generate_join_code(),
                owner=user,
            )
            OrganizationMembership.objects.create(
                user=user,
                organization=organization,
                role=OrganizationMembership.ROLE_ADMINISTRATOR,
            )
        return organization

    def _generate_join_code(self):
        for _ in range(10):
            code = secrets.token_urlsafe(8).replace("-", "").replace("_", "")[:10].upper()
            if not Organization.objects.filter(join_code=code).exists():
                return code
        raise serializers.ValidationError("Could not generate a unique join code.")


class JoinOrganizationSerializer(serializers.Serializer):
    join_code = serializers.CharField(max_length=32)

    def validate_join_code(self, value):
        code = value.strip().upper()
        if not code:
            raise serializers.ValidationError("Join code is required.")
        return code

    def validate(self, attrs):
        user = self.context["request"].user
        if hasattr(user, "organization_membership"):
            raise serializers.ValidationError("You already belong to an organization.")

        try:
            attrs["organization"] = Organization.objects.get(join_code=attrs["join_code"])
        except Organization.DoesNotExist as exc:
            raise serializers.ValidationError({"join_code": "No organization uses that join code."}) from exc

        return attrs

    def create(self, validated_data):
        user = self.context["request"].user
        try:
            return OrganizationMembership.objects.create(
                user=user,
                organization=validated_data["organization"],
                role=OrganizationMembership.ROLE_MEMBER,
            )
        except IntegrityError as exc:
            raise serializers.ValidationError("You already belong to an organization.") from exc
