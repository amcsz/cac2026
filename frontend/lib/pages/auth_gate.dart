import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';
import '../models/auth_session.dart';
import '../models/organization.dart';
import '../services/api_client.dart';
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

  @override
  void initState() {
    super.initState();
    _restoreSession();
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
  }

  void _setOrganization(Organization organization) {
    final session = _session;
    if (session == null) {
      return;
    }

    setState(() {
      _session = AuthSession(
        token: session.token,
        user: session.user.copyWith(organization: organization),
      );
    });
  }

  Future<void> _logout() async {
    final session = _session;
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
      onLogout: _logout,
    );
  }
}
