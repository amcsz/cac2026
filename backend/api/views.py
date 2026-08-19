import logging
import threading

from rest_framework import status
from django.core.paginator import EmptyPage, Paginator
from django.utils import timezone
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from .ai_summary import (
    AiSummaryUnavailable,
    get_cached_daily_report_summary,
    refresh_daily_report_summary,
)
from .models import (
    ArchiveDay,
    EmergencyReport,
    GlobalAlert,
    OrganizationMembership,
    get_archive_day_for_datetime,
)
from .scenarios import SCENARIOS, generate_scenario_reports
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
    SimulateEmergencySerializer,
    UpdateOrganizationMembershipRoleSerializer,
    UserSerializer,
)


DEFAULT_PAGE_SIZE = 10
MAX_PAGE_SIZE = 50
logger = logging.getLogger(__name__)


def _admin_membership_or_response(user, message):
    membership = getattr(user, "organization_membership", None)
    if membership is None or membership.role != OrganizationMembership.ROLE_ADMINISTRATOR:
        return None, Response({"detail": message}, status=status.HTTP_403_FORBIDDEN)
    return membership, None


def _page_number(request):
    try:
        return max(int(request.query_params.get("page", "1")), 1)
    except ValueError:
        return 1


def _page_size(request):
    try:
        return min(max(int(request.query_params.get("page_size", DEFAULT_PAGE_SIZE)), 1), MAX_PAGE_SIZE)
    except ValueError:
        return DEFAULT_PAGE_SIZE


def _paginated_response(queryset_or_list, request, serializer=None):
    paginator = Paginator(queryset_or_list, _page_size(request))
    if paginator.count == 0:
        return Response(
            {
                "results": [],
                "page": 1,
                "page_size": paginator.per_page,
                "total_pages": 0,
                "total_count": 0,
                "has_next": False,
                "has_previous": False,
            }
        )

    page_number = _page_number(request)
    try:
        page = paginator.page(page_number)
    except EmptyPage:
        page = paginator.page(paginator.num_pages or 1)

    results = list(page.object_list)
    if serializer is not None:
        results = serializer(results, many=True).data

    return Response(
        {
            "results": results,
            "page": page.number,
            "page_size": paginator.per_page,
            "total_pages": paginator.num_pages,
            "total_count": paginator.count,
            "has_next": page.has_next(),
            "has_previous": page.has_previous(),
        }
    )


def _refresh_summary_after_report(organization):
    organization_id = organization.id

    def refresh():
        try:
            from .models import Organization

            refresh_daily_report_summary(Organization.objects.get(id=organization_id))
        except AiSummaryUnavailable as exc:
            logger.warning("Could not refresh daily alert summary: %s", exc)
        except Exception:
            logger.exception("Unexpected error refreshing daily alert summary.")

    threading.Thread(target=refresh, daemon=True).start()


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
        membership, response = _admin_membership_or_response(
            request.user,
            "Only administrators can view emergency reports.",
        )
        if response is not None:
            return response

        today = timezone.localdate()
        reports = EmergencyReport.objects.filter(
            organization=membership.organization,
            created_at__date=today,
        ).select_related("reported_by")
        serializer = EmergencyReportSerializer(reports, many=True)
        return Response(serializer.data)

    def post(self, request):
        serializer = EmergencyReportSerializer(data=request.data, context={"request": request})
        serializer.is_valid(raise_exception=True)
        report = serializer.save()
        _refresh_summary_after_report(report.organization)
        return Response(EmergencyReportSerializer(report).data, status=status.HTTP_201_CREATED)


class ReportArchiveDaysView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        membership, response = _admin_membership_or_response(
            request.user,
            "Only administrators can view archived reports.",
        )
        if response is not None:
            return response

        today = timezone.localdate()
        days = ArchiveDay.objects.filter(
            organization=membership.organization,
        ).exclude(date=today).prefetch_related(
            "reports",
            "global_alerts",
        )
        results = [
            {
                "date": day.date.isoformat(),
                "report_count": day.reports.count(),
                "alert_count": day.global_alerts.count(),
                "count": day.reports.count() + day.global_alerts.count(),
            }
            for day in days
            if day.reports.count() + day.global_alerts.count() > 0
        ]
        return _paginated_response(results, request)


class ReportArchiveReportsView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        membership, response = _admin_membership_or_response(
            request.user,
            "Only administrators can view archived reports.",
        )
        if response is not None:
            return response

        date_value = request.query_params.get("date", "")
        try:
            archive_date = timezone.datetime.fromisoformat(date_value).date()
        except ValueError:
            return Response({"detail": "A valid date query parameter is required."}, status=status.HTTP_400_BAD_REQUEST)

        if archive_date == timezone.localdate():
            return Response({"detail": "Today's reports are shown on the Alerts tab."}, status=status.HTTP_400_BAD_REQUEST)

        archive_day = ArchiveDay.objects.filter(
            organization=membership.organization,
            date=archive_date,
        ).first()
        if archive_day is None:
            return _paginated_response([], request)

        reports = EmergencyReport.objects.filter(
            archive_day=archive_day,
        ).select_related("reported_by")
        alerts = GlobalAlert.objects.filter(
            archive_day=archive_day,
        ).select_related("created_by")

        events = []
        for report in reports:
            events.append(
                {
                    "type": "report",
                    "created_at": report.created_at,
                    "payload": EmergencyReportSerializer(report).data,
                }
            )
        for alert in alerts:
            events.append(
                {
                    "type": "global_alert",
                    "created_at": alert.created_at,
                    "payload": GlobalAlertSerializer(alert).data,
                }
            )
        events.sort(key=lambda event: event["created_at"])

        results = [
            {
                "type": event["type"],
                "created_at": event["created_at"].isoformat(),
                "payload": event["payload"],
            }
            for event in events
        ]
        return _paginated_response(results, request)


class SimulateEmergencyScenarioView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        membership, response = _admin_membership_or_response(
            request.user,
            "Only administrators can simulate emergency reports.",
        )
        if response is not None:
            return response

        serializer = SimulateEmergencySerializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        try:
            reports = generate_scenario_reports(
                membership.organization,
                serializer.validated_data["scenario"],
                append=True,
                random_reporters=True,
            )
        except ValueError as exc:
            return Response({"detail": str(exc)}, status=status.HTTP_400_BAD_REQUEST)

        _refresh_summary_after_report(membership.organization)

        return Response(
            {
                "scenario": serializer.validated_data["scenario"],
                "label": SCENARIOS[serializer.validated_data["scenario"]]["label"],
                "reports": EmergencyReportSerializer(reports, many=True).data,
            },
            status=status.HTTP_201_CREATED,
        )


class AlertSummaryView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        membership = getattr(request.user, "organization_membership", None)
        if membership is None or membership.role != OrganizationMembership.ROLE_ADMINISTRATOR:
            return Response(
                {"detail": "Only administrators can view alert summaries."},
                status=status.HTTP_403_FORBIDDEN,
            )

        return Response(get_cached_daily_report_summary(membership.organization))


class GlobalAlertView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        membership = getattr(request.user, "organization_membership", None)
        if membership is None:
            return Response(
                {"detail": "You must belong to an organization to view alerts."},
                status=status.HTTP_403_FORBIDDEN,
            )

        alert = GlobalAlert.objects.filter(organization=membership.organization, is_active=True).select_related("created_by").first()
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
        alert.archive_day = get_archive_day_for_datetime(
            membership.organization,
            alert.created_at,
        )
        alert.save(update_fields=["archive_day"])
        return Response(GlobalAlertSerializer(alert).data, status=status.HTTP_201_CREATED)

    def delete(self, request):
        membership = getattr(request.user, "organization_membership", None)
        if membership is None or membership.role != OrganizationMembership.ROLE_ADMINISTRATOR:
            return Response(
                {"detail": "Only administrators can clear global alerts."},
                status=status.HTTP_403_FORBIDDEN,
            )

        GlobalAlert.objects.filter(
            organization=membership.organization,
            is_active=True,
        ).update(is_active=False)
        return Response(status=status.HTTP_204_NO_CONTENT)
