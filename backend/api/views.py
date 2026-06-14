from rest_framework import status, viewsets
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from .models import EmergencyReport, OrganizationMembership, Todo
from .serializers import (
    AuthResponseSerializer,
    CreateOrganizationSerializer,
    EmergencyReportSerializer,
    JoinOrganizationSerializer,
    LoginSerializer,
    OrganizationMembershipSerializer,
    OrganizationSerializer,
    RegisterSerializer,
    TodoSerializer,
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


class TodoViewSet(viewsets.ModelViewSet):
    queryset = Todo.objects.all()
    serializer_class = TodoSerializer
