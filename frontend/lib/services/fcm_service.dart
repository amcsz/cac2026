import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'api_client.dart';
import 'notification_service.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

class FcmService {
  FcmService({
    required this.apiClient,
    required this.notificationService,
  });

  final ApiClient apiClient;
  final NotificationService notificationService;
  StreamSubscription<String>? _tokenRefreshSubscription;
  StreamSubscription<RemoteMessage>? _foregroundMessageSubscription;

  static Future<void> initializeFirebase() async {
    if (kIsWeb) {
      return;
    }

    try {
      await Firebase.initializeApp();
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    } catch (_) {}
  }

  Future<void> start() async {
    if (kIsWeb) {
      return;
    }

    // Register this before token registration so a slow or failed API request
    // cannot prevent notifications while the app is in the foreground.
    try {
      _foregroundMessageSubscription?.cancel();
      _foregroundMessageSubscription =
          FirebaseMessaging.onMessage.listen(_showForegroundNotification);
    } catch (error) {
      debugPrint('Could not register foreground FCM listener: $error');
    }

    try {
      await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
    } catch (error) {
      debugPrint('Could not request FCM permission: $error');
    }

    try {
      await notificationService.requestPermission();
    } catch (error) {
      debugPrint('Could not initialize local notifications: $error');
    }

    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        await _registerToken(token);
      }

      _tokenRefreshSubscription?.cancel();
      _tokenRefreshSubscription =
          FirebaseMessaging.instance.onTokenRefresh.listen(_registerToken);
    } catch (error) {
      debugPrint('Could not register FCM device: $error');
    }
  }

  Future<void> stop() async {
    await stopListening();

    if (kIsWeb) {
      return;
    }

    try {
      final token = await FirebaseMessaging.instance.getToken();
      await apiClient.unregisterFcmDevice(fcmToken: token);
    } catch (_) {}
  }

  Future<void> stopListening() async {
    await _tokenRefreshSubscription?.cancel();
    await _foregroundMessageSubscription?.cancel();
    _tokenRefreshSubscription = null;
    _foregroundMessageSubscription = null;
  }

  Future<void> _registerToken(String token) async {
    try {
      await apiClient.registerFcmDevice(
        fcmToken: token,
        platform: 'android',
      );
    } catch (_) {}
  }

  Future<void> _showForegroundNotification(RemoteMessage message) async {
    final notification = message.notification;
    final title = notification?.title ?? message.data['title'] ?? 'SwiftGuard';
    final body = notification?.body ?? message.data['body'] ?? '';

    if (body.toString().trim().isEmpty) {
      return;
    }

    try {
      await notificationService.show(
        title: title.toString(),
        body: body.toString(),
      );
    } catch (error) {
      debugPrint('Could not show foreground notification: $error');
    }
  }
}
