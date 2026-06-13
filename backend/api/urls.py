from django.urls import path
from rest_framework.routers import DefaultRouter

from .views import (
    CreateOrganizationView,
    HealthView,
    JoinOrganizationView,
    LoginView,
    LogoutView,
    MeView,
    RegisterView,
    TodoViewSet,
)


router = DefaultRouter()
router.register("todos", TodoViewSet, basename="todo")

urlpatterns = [
    path("health/", HealthView.as_view(), name="health"),
    path("auth/register/", RegisterView.as_view(), name="register"),
    path("auth/login/", LoginView.as_view(), name="login"),
    path("auth/logout/", LogoutView.as_view(), name="logout"),
    path("auth/me/", MeView.as_view(), name="me"),
    path("organizations/create/", CreateOrganizationView.as_view(), name="create-organization"),
    path("organizations/join/", JoinOrganizationView.as_view(), name="join-organization"),
]
urlpatterns += router.urls
