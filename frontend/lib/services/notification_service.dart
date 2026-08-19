import 'notification_service_stub.dart'
    if (dart.library.html) 'notification_service_web.dart';

abstract class NotificationService {
  Future<bool> requestPermission();

  Future<void> show({
    required String title,
    required String body,
  });
}

NotificationService createNotificationService() =>
    createPlatformNotificationService();
