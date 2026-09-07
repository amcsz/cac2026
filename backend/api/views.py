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
    FcmDevice,
    GlobalAlert,
    OrganizationMembership,
    ReportConversation,
    ReportMessage,
    get_archive_day_for_datetime,
)
from .push_notifications import (
    send_comms_message_push,
    send_global_alert_push,
    send_new_report_push,
)
from .scenarios import SCENARIOS, generate_scenario_reports
from .serializers import (
    AuthResponseSerializer,
    CreateReportConversationSerializer,
    CreateOrganizationSerializer,
    EmergencyReportSerializer,
    FcmDeviceSerializer,
    GlobalAlertSerializer,
    JoinOrganizationSerializer,
    LoginSerializer,
    OrganizationMembershipSerializer,
    OrganizationSerializer,
    PublishGlobalAlertSerializer,
    RegisterSerializer,
    ReportConversationSerializer,
    ReportMessageSerializer,
    SendReportMessageSerializer,
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


class FcmDeviceView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        serializer = FcmDeviceSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        membership = getattr(request.user, "organization_membership", None)
        device, _ = FcmDevice.objects.update_or_create(
            token=serializer.validated_data["token"],
            defaults={
                "user": request.user,
                "organization": membership.organization if membership else None,
                "platform": serializer.validated_data["platform"],
                "is_active": True,
            },
        )
        logger.warning(
            "Registered FCM device id=%s user_id=%s organization_id=%s platform=%s",
            device.id,
            request.user.id,
            device.organization_id,
            device.platform,
        )
        return Response({"id": device.id}, status=status.HTTP_200_OK)

    def delete(self, request):
        token = str(request.data.get("token", "")).strip()
        queryset = FcmDevice.objects.filter(user=request.user)
        if token:
            queryset = queryset.filter(token=token)
        updated = queryset.update(is_active=False)
        logger.warning("Deactivated %s FCM devices for user_id=%s", updated, request.user.id)
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

    def delete(self, request):
        membership, response = _admin_membership_or_response(
            request.user,
            "Only administrators can remove organization members.",
        )
        if response is not None:
            return response

        try:
            user_id = int(request.data.get("user_id"))
        except (TypeError, ValueError):
            return Response(
                {"detail": "A valid user_id is required."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        target_membership = OrganizationMembership.objects.filter(
            organization=membership.organization,
            user_id=user_id,
        ).first()
        if target_membership is None:
            return Response(
                {"detail": "That member was not found."},
                status=status.HTTP_404_NOT_FOUND,
            )
        if target_membership.organization.owner_id == target_membership.user_id:
            return Response(
                {"detail": "The organization owner cannot be removed."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        target_membership.delete()
        return Response(status=status.HTTP_204_NO_CONTENT)


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
        send_new_report_push(report)
        _refresh_summary_after_report(report.organization)
        return Response(EmergencyReportSerializer(report).data, status=status.HTTP_201_CREATED)


class EmergencyReportDetailView(APIView):
    permission_classes = [IsAuthenticated]

    def delete(self, request, report_id):
        membership, response = _admin_membership_or_response(
            request.user,
            "Only administrators can delete emergency reports.",
        )
        if response is not None:
            return response

        report = EmergencyReport.objects.filter(
            id=report_id,
            organization=membership.organization,
            created_at__date=timezone.localdate(),
        ).first()
        if report is None:
            return Response(
                {"detail": "That report was not found."},
                status=status.HTTP_404_NOT_FOUND,
            )

        organization = report.organization
        report.delete()
        _refresh_summary_after_report(organization)
        return Response(status=status.HTTP_204_NO_CONTENT)


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

        for report in reports:
            send_new_report_push(report)
        _refresh_summary_after_report(membership.organization)

        return Response(
            {
                "scenario": serializer.validated_data["scenario"],
                "label": SCENARIOS[serializer.validated_data["scenario"]]["label"],
                "reports": EmergencyReportSerializer(reports, many=True).data,
            },
            status=status.HTTP_201_CREATED,
        )


class ReportConversationView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        membership = getattr(request.user, "organization_membership", None)
        if membership is None:
            return Response(
                {"detail": "You must belong to an organization to view communications."},
                status=status.HTTP_403_FORBIDDEN,
            )

        conversations = ReportConversation.objects.filter(
            organization=membership.organization,
        ).select_related(
            "report",
            "report__reported_by",
        )
        if membership.role != OrganizationMembership.ROLE_ADMINISTRATOR:
            conversations = conversations.filter(report__reported_by=request.user)

        serializer = ReportConversationSerializer(
            conversations,
            many=True,
            context={"request": request},
        )
        return Response(serializer.data)

    def post(self, request):
        membership, response = _admin_membership_or_response(
            request.user,
            "Only administrators can respond to reports.",
        )
        if response is not None:
            return response

        serializer = CreateReportConversationSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        report = EmergencyReport.objects.filter(
            id=serializer.validated_data["report_id"],
            organization=membership.organization,
        ).select_related("reported_by").first()
        if report is None:
            return Response({"detail": "That report was not found."}, status=status.HTTP_404_NOT_FOUND)

        conversation, _ = ReportConversation.objects.get_or_create(
            report=report,
            defaults={
                "organization": membership.organization,
                "created_by": request.user,
            },
        )
        return Response(
            ReportConversationSerializer(conversation, context={"request": request}).data,
            status=status.HTTP_201_CREATED,
        )


class ReportConversationMessagesView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request, conversation_id):
        conversation, response = self._get_accessible_conversation(request.user, conversation_id)
        if response is not None:
            return response

        messages = conversation.messages.select_related("sender")
        serializer = ReportMessageSerializer(messages, many=True, context={"request": request})
        return Response(serializer.data)

    def post(self, request, conversation_id):
        conversation, response = self._get_accessible_conversation(request.user, conversation_id)
        if response is not None:
            return response

        serializer = SendReportMessageSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        message = ReportMessage.objects.create(
            conversation=conversation,
            sender=request.user,
            body=serializer.validated_data["body"],
        )
        conversation.updated_at = timezone.now()
        conversation.save(update_fields=["updated_at"])
        send_comms_message_push(message)

        return Response(
            ReportMessageSerializer(message, context={"request": request}).data,
            status=status.HTTP_201_CREATED,
        )

    def _get_accessible_conversation(self, user, conversation_id):
        membership = getattr(user, "organization_membership", None)
        if membership is None:
            return None, Response(
                {"detail": "You must belong to an organization to view communications."},
                status=status.HTTP_403_FORBIDDEN,
            )

        conversation = ReportConversation.objects.filter(
            id=conversation_id,
            organization=membership.organization,
        ).select_related(
            "report",
            "report__reported_by",
        ).first()
        if conversation is None:
            return None, Response({"detail": "Conversation not found."}, status=status.HTTP_404_NOT_FOUND)

        is_admin = membership.role == OrganizationMembership.ROLE_ADMINISTRATOR
        is_reporter = conversation.report.reported_by_id == user.id
        if not is_admin and not is_reporter:
            return None, Response(
                {"detail": "You do not have access to this conversation."},
                status=status.HTTP_403_FORBIDDEN,
            )

        return conversation, None


class AlertSummaryView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        membership = getattr(request.user, "organization_membership", None)
        if membership is None:
            return Response(
                {"detail": "You must belong to an organization to view alert summaries."},
                status=status.HTTP_403_FORBIDDEN,
            )

        return Response(get_cached_daily_report_summary(membership.organization))

    def post(self, request):
        membership, response = _admin_membership_or_response(
            request.user,
            "Only administrators can refresh alert summaries.",
        )
        if response is not None:
            return response

        try:
            return Response(refresh_daily_report_summary(membership.organization))
        except AiSummaryUnavailable as exc:
            logger.warning("Could not refresh daily alert summary: %s", exc)
            return Response(
                {"detail": "Could not refresh alert summary right now."},
                status=status.HTTP_503_SERVICE_UNAVAILABLE,
            )


class GlobalAlertView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        membership = getattr(request.user, "organization_membership", None)
        if membership is None:
            return Response(
                {"detail": "You must belong to an organization to view alerts."},
                status=status.HTTP_403_FORBIDDEN,
            )

        alerts = GlobalAlert.objects.filter(
            organization=membership.organization,
            is_active=True,
        ).select_related("created_by")
        if membership.role != OrganizationMembership.ROLE_ADMINISTRATOR:
            alerts = alerts.filter(admins_only=False)
        alert = alerts.first()
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
        if not serializer.is_valid():
            logger.warning(
                "Global alert validation failed fields=%s incident_type=%s",
                list(serializer.errors.keys()),
                request.data.get("incident_type"),
            )
            return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)
        alert = GlobalAlert.objects.create(
            organization=membership.organization,
            created_by=request.user,
            headline=serializer.validated_data["headline"],
            message=serializer.validated_data["message"],
            incident_type=serializer.validated_data["incident_type"],
            admins_only=serializer.validated_data["admins_only"],
        )
        alert.archive_day = get_archive_day_for_datetime(
            membership.organization,
            alert.created_at,
        )
        alert.save(update_fields=["archive_day"])
        send_global_alert_push(alert)
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
