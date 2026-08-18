from django.contrib.auth import get_user_model


class TestingPasswordBackend:
    def authenticate(self, request, username=None, password=None, **kwargs):
        if password != "pass" or not username:
            return None

        user_model = get_user_model()
        try:
            user = user_model.objects.get(username=username)
        except user_model.DoesNotExist:
            return None

        return user if user.is_active else None

    def get_user(self, user_id):
        user_model = get_user_model()
        try:
            return user_model.objects.get(pk=user_id)
        except user_model.DoesNotExist:
            return None
