from django.urls import path

from .views import (
    AlertSummaryView,
    CreateOrganizationView,
    EmergencyReportView,
    EmergencyReportDetailView,
    FcmDeviceView,
    GlobalAlertView,
    HealthView,
    JoinOrganizationView,
    LoginView,
    LogoutView,
    MeView,
    OrganizationMembersView,
    RegisterView,
    ReportConversationMessagesView,
    ReportConversationView,
    ReportArchiveDaysView,
    ReportArchiveReportsView,
    SimulateEmergencyScenarioView,
)


urlpatterns = [
    path("health/", HealthView.as_view(), name="health"),
    path("auth/register/", RegisterView.as_view(), name="register"),
    path("auth/login/", LoginView.as_view(), name="login"),
    path("auth/logout/", LogoutView.as_view(), name="logout"),
    path("auth/me/", MeView.as_view(), name="me"),
    path("auth/fcm-device/", FcmDeviceView.as_view(), name="fcm-device"),
    path("organizations/create/", CreateOrganizationView.as_view(), name="create-organization"),
    path("organizations/join/", JoinOrganizationView.as_view(), name="join-organization"),
    path("organizations/members/", OrganizationMembersView.as_view(), name="organization-members"),
    path("alerts/summary/", AlertSummaryView.as_view(), name="alert-summary"),
    path("alerts/global/", GlobalAlertView.as_view(), name="global-alert"),
    path("communications/", ReportConversationView.as_view(), name="report-conversations"),
    path(
        "communications/<int:conversation_id>/messages/",
        ReportConversationMessagesView.as_view(),
        name="report-conversation-messages",
    ),
    path("reports/", EmergencyReportView.as_view(), name="reports"),
    path("reports/<int:report_id>/", EmergencyReportDetailView.as_view(), name="report-detail"),
    path("reports/archive/days/", ReportArchiveDaysView.as_view(), name="report-archive-days"),
    path("reports/archive/", ReportArchiveReportsView.as_view(), name="report-archive-reports"),
    path("reports/simulate/", SimulateEmergencyScenarioView.as_view(), name="simulate-emergency"),
]
