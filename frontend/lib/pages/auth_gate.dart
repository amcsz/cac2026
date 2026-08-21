import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';
import '../models/auth_session.dart';
import '../models/organization.dart';
import '../services/api_client.dart';
import '../services/fcm_service.dart';
import '../services/notification_service.dart';
import 'auth_page.dart';
import 'logged_in_page.dart';
import 'organization_page.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  AuthSession? _session;
  bool _loadingSession = true;
  FcmService? _fcmService;

  @override
  void initState() {
    super.initState();
    _restoreSession();
  }

  @override
  void dispose() {
    _fcmService?.stop();
    super.dispose();
  }

  Future<void> _restoreSession() async {
    final preferences = await SharedPreferences.getInstance();
    final token = preferences.getString(AppConfig.authTokenKey);

    if (token == null) {
      if (mounted) {
        setState(() => _loadingSession = false);
      }
      return;
    }

    try {
      final user = await ApiClient(token: token).me();
      if (mounted) {
        setState(() {
          _session = AuthSession(token: token, user: user);
          _loadingSession = false;
        });
        _startFcmForSession(_session);
      }
    } catch (_) {
      await preferences.remove(AppConfig.authTokenKey);
      if (mounted) {
        setState(() => _loadingSession = false);
      }
    }
  }

  Future<void> _setSession(AuthSession session) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(AppConfig.authTokenKey, session.token);
    setState(() => _session = session);
    _startFcmForSession(session);
  }

  Future<void> _setOrganization(Organization organization) async {
    final session = _session;
    if (session == null) {
      return;
    }

    try {
      final refreshedUser = await ApiClient(token: session.token).me();
      if (mounted) {
        setState(() {
          _session = AuthSession(
            token: session.token,
            user: refreshedUser.copyWith(organization: organization),
          );
        });
        _startFcmForSession(_session);
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _session = AuthSession(
            token: session.token,
            user: session.user.copyWith(organization: organization),
          );
        });
        _startFcmForSession(_session);
      }
    }
  }

  Future<void> _logout() async {
    final session = _session;
    await _fcmService?.stop();
    try {
      if (session != null) {
        await ApiClient(token: session.token).logout();
      }
    } catch (_) {
      // Local logout should still complete if the token is already invalid.
    }
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(AppConfig.authTokenKey);
    if (mounted) {
      setState(() => _session = null);
    }
  }

  void _startFcmForSession(AuthSession? session) {
    if (session == null) {
      return;
    }

    _fcmService?.stop();
    final service = FcmService(
      apiClient: ApiClient(token: session.token),
      notificationService: createNotificationService(),
    );
    _fcmService = service;
    service.start();
  }

  @override
  Widget build(BuildContext context) {
    final session = _session;

    if (_loadingSession) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (session == null) {
      return AuthPage(onAuthenticated: _setSession);
    }

    final organization = session.user.organization;
    if (organization == null) {
      return OrganizationPage(
        token: session.token,
        username: session.user.username,
        onOrganizationReady: _setOrganization,
        onLogout: _logout,
      );
    }

    return LoggedInPage(
      user: session.user,
      organization: organization,
      token: session.token,
      onLogout: _logout,
    );
  }
}
