import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'notification_service.dart';

NotificationService createPlatformNotificationService() =>
    _NativeNotificationService();

class _NativeNotificationService implements NotificationService {
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  @override
  Future<bool> requestPermission() async {
    try {
      await _initialize();

      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      return await android?.requestNotificationsPermission() ?? true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> show({
    required String title,
    required String body,
  }) async {
    try {
      await _initialize();

      await _plugin.show(
        id: DateTime.now().millisecondsSinceEpoch.remainder(1000000),
        title: _plainText(title),
        body: _plainText(body),
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'fastguard_alerts',
            'FastGuard alerts',
            channelDescription: 'Emergency and global alert notifications.',
            importance: Importance.max,
            priority: Priority.high,
            category: AndroidNotificationCategory.alarm,
            visibility: NotificationVisibility.public,
          ),
        ),
      );
    } catch (_) {}
  }

  Future<void> _initialize() async {
    if (_initialized) {
      return;
    }

    const androidSettings = AndroidInitializationSettings('ic_stat_fastguard');
    const settings = InitializationSettings(android: androidSettings);
    await _plugin.initialize(settings: settings);
    _initialized = true;
  }

  String _plainText(String value) {
    return value
        .replaceAllMapped(RegExp(r'\*\*([^*]+)\*\*'), (match) {
          return match.group(1) ?? '';
        })
        .replaceAll(RegExp(r'[_`#>-]'), '')
        .trim();
  }
}
