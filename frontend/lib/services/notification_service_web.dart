import 'dart:js_interop';

import 'notification_service.dart';
import 'package:web/web.dart' as web;

@JS('Notification')
external JSObject? get _notificationConstructor;

NotificationService createPlatformNotificationService() =>
    _WebNotificationService();

class _WebNotificationService implements NotificationService {
  @override
  Future<bool> requestPermission() async {
    try {
      if (!_isSupported) {
        return false;
      }

      if (web.Notification.permission == 'granted') {
        return true;
      }

      if (web.Notification.permission == 'denied') {
        return false;
      }

      final permission =
          (await web.Notification.requestPermission().toDart).toDart;
      return permission == 'granted';
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> show({
    required String title,
    required String body,
  }) async {
    if (!_isSupported || web.Notification.permission != 'granted') {
      return;
    }

    try {
      web.Notification(
        title,
        web.NotificationOptions(
          body: body,
          icon: 'icons/Icon-192.png',
          tag: 'swiftguard-global-alert',
        ),
      );
    } catch (_) {}
  }

  bool get _isSupported => _notificationConstructor != null;
}
