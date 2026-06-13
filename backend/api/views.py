from rest_framework import status, viewsets
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from .models import Todo
from .serializers import (
    AuthResponseSerializer,
    CreateOrganizationSerializer,
    JoinOrganizationSerializer,
    LoginSerializer,
    OrganizationSerializer,
    RegisterSerializer,
    TodoSerializer,
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


class TodoViewSet(viewsets.ModelViewSet):
    queryset = Todo.objects.all()
    serializer_class = TodoSerializer
