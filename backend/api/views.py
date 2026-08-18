from rest_framework import status
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from .ai_summary import AiSummaryUnavailable, generate_recent_report_summary
from .models import EmergencyReport, GlobalAlert, OrganizationMembership
from .serializers import (
    AuthResponseSerializer,
    CreateOrganizationSerializer,
    EmergencyReportSerializer,
    GlobalAlertSerializer,
    JoinOrganizationSerializer,
    LoginSerializer,
    OrganizationMembershipSerializer,
    OrganizationSerializer,
    PublishGlobalAlertSerializer,
    RegisterSerializer,
    UpdateOrganizationMembershipRoleSerializer,
    UserSerializer,
)


class HealthView(APIView):
    def get(self, request):
        return Response({"status": "ok"})


class RegisterView(APIView):
    permission_classes = [AllowAny]

    def post(self, request):
        serializer = RegisterSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        auth_data = serializer.save()
        return Response(
            AuthResponseSerializer(auth_data).data,
            status=status.HTTP_201_CREATED,
        )


class LoginView(APIView):
    permission_classes = [AllowAny]

    def post(self, request):
        serializer = LoginSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        return Response(AuthResponseSerializer(serializer.validated_data).data)


class LogoutView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        if request.auth is not None:
            request.auth.delete()
        return Response(status=status.HTTP_204_NO_CONTENT)


class MeView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        return Response(UserSerializer(request.user).data)


class CreateOrganizationView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        serializer = CreateOrganizationSerializer(
            data=request.data,
            context={"request": request},
        )
        serializer.is_valid(raise_exception=True)
        organization = serializer.save()
        return Response(
            OrganizationSerializer(organization).data,
            status=status.HTTP_201_CREATED,
        )


class JoinOrganizationView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        serializer = JoinOrganizationSerializer(
            data=request.data,
            context={"request": request},
        )
        serializer.is_valid(raise_exception=True)
        membership = serializer.save()
        return Response(OrganizationSerializer(membership.organization).data)


class OrganizationMembersView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        membership = getattr(request.user, "organization_membership", None)
        if membership is None or membership.role != OrganizationMembership.ROLE_ADMINISTRATOR:
            return Response(
                {"detail": "Only administrators can view organization members."},
                status=status.HTTP_403_FORBIDDEN,
            )

        memberships = OrganizationMembership.objects.filter(organization=membership.organization).select_related("user")
        serializer = OrganizationMembershipSerializer(memberships, many=True)
        return Response(serializer.data)

    def patch(self, request):
        membership = getattr(request.user, "organization_membership", None)
        if membership is None or membership.role != OrganizationMembership.ROLE_ADMINISTRATOR:
            return Response(
                {"detail": "Only administrators can change member roles."},
                status=status.HTTP_403_FORBIDDEN,
            )

        serializer = UpdateOrganizationMembershipRoleSerializer(
            data=request.data,
            context={"request": request},
        )
        serializer.is_valid(raise_exception=True)

        target_membership = OrganizationMembership.objects.filter(
            organization=membership.organization,
            user_id=serializer.validated_data["user_id"],
        ).select_related("user").first()
        if target_membership is None:
            return Response({"detail": "That member was not found."}, status=status.HTTP_404_NOT_FOUND)
        if target_membership.organization.owner_id == target_membership.user_id:
            return Response(
                {"detail": "The organization owner cannot have their role changed."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        target_membership.role = serializer.validated_data["role"]
        target_membership.save(update_fields=["role"])
        return Response(OrganizationMembershipSerializer(target_membership).data)


class EmergencyReportView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        membership = getattr(request.user, "organization_membership", None)
        if membership is None or membership.role != OrganizationMembership.ROLE_ADMINISTRATOR:
            return Response(
                {"detail": "Only administrators can view emergency reports."},
                status=status.HTTP_403_FORBIDDEN,
            )

        reports = EmergencyReport.objects.filter(organization=membership.organization).select_related("reported_by")
        serializer = EmergencyReportSerializer(reports, many=True)
        return Response(serializer.data)

    def post(self, request):
        serializer = EmergencyReportSerializer(data=request.data, context={"request": request})
        serializer.is_valid(raise_exception=True)
        report = serializer.save()
        return Response(EmergencyReportSerializer(report).data, status=status.HTTP_201_CREATED)


class AlertSummaryView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        membership = getattr(request.user, "organization_membership", None)
        if membership is None or membership.role != OrganizationMembership.ROLE_ADMINISTRATOR:
            return Response(
                {"detail": "Only administrators can view alert summaries."},
                status=status.HTTP_403_FORBIDDEN,
            )

        try:
            summary = generate_recent_report_summary(membership.organization)
        except AiSummaryUnavailable as exc:
            return Response({"detail": str(exc)}, status=status.HTTP_503_SERVICE_UNAVAILABLE)

        return Response(summary)


class GlobalAlertView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        membership = getattr(request.user, "organization_membership", None)
        if membership is None:
            return Response(
                {"detail": "You must belong to an organization to view alerts."},
                status=status.HTTP_403_FORBIDDEN,
            )

        alert = GlobalAlert.objects.filter(organization=membership.organization).select_related("created_by").first()
        if alert is None:
            return Response({"alert": None})
        return Response({"alert": GlobalAlertSerializer(alert).data})

    def post(self, request):
        membership = getattr(request.user, "organization_membership", None)
        if membership is None or membership.role != OrganizationMembership.ROLE_ADMINISTRATOR:
            return Response(
                {"detail": "Only administrators can publish global alerts."},
                status=status.HTTP_403_FORBIDDEN,
            )

        serializer = PublishGlobalAlertSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        alert = GlobalAlert.objects.create(
            organization=membership.organization,
            created_by=request.user,
            headline=serializer.validated_data["headline"],
            message=serializer.validated_data["message"],
        )
        return Response(GlobalAlertSerializer(alert).data, status=status.HTTP_201_CREATED)
