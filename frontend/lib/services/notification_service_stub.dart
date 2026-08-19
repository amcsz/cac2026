import 'notification_service.dart';

NotificationService createPlatformNotificationService() =>
    _StubNotificationService();

class _StubNotificationService implements NotificationService {
  @override
  Future<bool> requestPermission() async => false;

  @override
  Future<void> show({
    required String title,
    required String body,
  }) async {}
}
