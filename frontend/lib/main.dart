import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

const configuredApiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: '',
);
const authTokenKey = 'auth_token';

void main() {
  runApp(const CacApp());
}

String get apiBaseUrl {
  if (configuredApiBaseUrl.isNotEmpty) {
    return configuredApiBaseUrl;
  }

  final page = Uri.base;
  final host = page.host.isEmpty ? 'localhost' : page.host;
  final scheme = page.scheme == 'https' ? 'https' : 'http';
  return '$scheme://$host:8000/api';
}

class CacApp extends StatelessWidget {
  const CacApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'CAC 2026',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xff2f6f73),
          secondary: const Color(0xffb85c38),
        ),
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
        ),
        useMaterial3: true,
      ),
      home: const AuthGate(),
    );
  }
}

class Organization {
  const Organization({
    required this.id,
    required this.name,
    required this.joinCode,
    required this.memberCount,
  });

  final int id;
  final String name;
  final String joinCode;
  final int memberCount;

  factory Organization.fromJson(Map<String, dynamic> json) {
    return Organization(
      id: json['id'] as int,
      name: json['name'] as String,
      joinCode: json['join_code'] as String,
      memberCount: json['member_count'] as int? ?? 0,
    );
  }
}

class AppUser {
  const AppUser({
    required this.id,
    required this.username,
    required this.email,
    required this.organization,
  });

  final int id;
  final String username;
  final String email;
  final Organization? organization;

  factory AppUser.fromJson(Map<String, dynamic> json) {
    final organizationJson = json['organization'];
    return AppUser(
      id: json['id'] as int,
      username: json['username'] as String,
      email: json['email'] as String? ?? '',
      organization: organizationJson == null
          ? null
          : Organization.fromJson(organizationJson as Map<String, dynamic>),
    );
  }

  AppUser copyWith({Organization? organization}) {
    return AppUser(
      id: id,
      username: username,
      email: email,
      organization: organization ?? this.organization,
    );
  }
}

class AuthSession {
  const AuthSession({required this.token, required this.user});

  final String token;
  final AppUser user;

  factory AuthSession.fromJson(Map<String, dynamic> json) {
    return AuthSession(
      token: json['token'] as String,
      user: AppUser.fromJson(json['user'] as Map<String, dynamic>),
    );
  }
}

class ApiException implements Exception {
  const ApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

class ApiClient {
  const ApiClient({this.token});

  final String? token;

  Map<String, String> get _headers {
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Token $token',
    };
  }

  Future<AuthSession> register({
    required String username,
    required String email,
    required String password,
  }) async {
    final response = await http.post(
      Uri.parse('$apiBaseUrl/auth/register/'),
      headers: _headers,
      body: jsonEncode({
        'username': username,
        'email': email,
        'password': password,
      }),
    );
    return AuthSession.fromJson(_decode(response, expected: 201));
  }

  Future<AuthSession> login({
    required String username,
    required String password,
  }) async {
    final response = await http.post(
      Uri.parse('$apiBaseUrl/auth/login/'),
      headers: _headers,
      body: jsonEncode({'username': username, 'password': password}),
    );
    return AuthSession.fromJson(_decode(response));
  }

  Future<void> logout() async {
    if (token == null) {
      return;
    }

    await http.post(Uri.parse('$apiBaseUrl/auth/logout/'), headers: _headers);
  }

  Future<AppUser> me() async {
    final response = await http.get(
      Uri.parse('$apiBaseUrl/auth/me/'),
      headers: _headers,
    );
    return AppUser.fromJson(_decode(response));
  }

  Future<Organization> createOrganization({required String name}) async {
    final response = await http.post(
      Uri.parse('$apiBaseUrl/organizations/create/'),
      headers: _headers,
      body: jsonEncode({'name': name}),
    );
    return Organization.fromJson(_decode(response, expected: 201));
  }

  Future<Organization> joinOrganization({required String joinCode}) async {
    final response = await http.post(
      Uri.parse('$apiBaseUrl/organizations/join/'),
      headers: _headers,
      body: jsonEncode({'join_code': joinCode}),
    );
    return Organization.fromJson(_decode(response));
  }

  Map<String, dynamic> _decode(http.Response response, {int expected = 200}) {
    if (response.statusCode == expected) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }

    throw ApiException(_extractError(response));
  }

  String _extractError(http.Response response) {
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        if (decoded['detail'] != null) {
          return decoded['detail'].toString();
        }
        if (decoded['non_field_errors'] is List) {
          return (decoded['non_field_errors'] as List).join(' ');
        }
        final messages = <String>[];
        decoded.forEach((key, value) {
          if (value is List) {
            messages.add('$key: ${value.join(' ')}');
          } else {
            messages.add('$key: $value');
          }
        });
        if (messages.isNotEmpty) {
          return messages.join('\n');
        }
      }
    } catch (_) {
      return 'Backend returned ${response.statusCode}.';
    }
    return 'Backend returned ${response.statusCode}.';
  }
}

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
    final token = preferences.getString(authTokenKey);

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
      await preferences.remove(authTokenKey);
      if (mounted) {
        setState(() => _loadingSession = false);
      }
    }
  }

  Future<void> _setSession(AuthSession session) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(authTokenKey, session.token);
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
    await preferences.remove(authTokenKey);
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

class AuthPage extends StatefulWidget {
  const AuthPage({required this.onAuthenticated, super.key});

  final Future<void> Function(AuthSession session) onAuthenticated;

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _registering = false;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _submitting) {
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      const api = ApiClient();
      final session = _registering
          ? await api.register(
              username: _usernameController.text.trim(),
              email: _emailController.text.trim(),
              password: _passwordController.text,
            )
          : await api.login(
              username: _usernameController.text.trim(),
              password: _passwordController.text,
            );
      await widget.onAuthenticated(session);
    } on ApiException catch (error) {
      setState(() => _error = error.message);
    } catch (error) {
      setState(() => _error = 'Could not reach backend at $apiBaseUrl.');
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _registering ? 'Create your account' : 'Log in to continue',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'You need an account before you can join or create an organization.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: _usernameController,
                    decoration: const InputDecoration(labelText: 'Username'),
                    textInputAction: TextInputAction.next,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Enter a username.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  if (_registering) ...[
                    TextFormField(
                      controller: _emailController,
                      decoration: const InputDecoration(labelText: 'Email'),
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 12),
                  ],
                  TextFormField(
                    controller: _passwordController,
                    decoration: const InputDecoration(labelText: 'Password'),
                    obscureText: true,
                    onFieldSubmitted: (_) => _submit(),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Enter a password.';
                      }
                      if (_registering && value.length < 8) {
                        return 'Use at least 8 characters.';
                      }
                      return null;
                    },
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      style:
                          TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                  ],
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: _submitting ? null : _submit,
                    icon: _submitting
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(_registering ? Icons.person_add : Icons.login),
                    label: Text(
                      _submitting
                          ? 'Please wait'
                          : _registering
                              ? 'Register'
                              : 'Log in',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _submitting
                        ? null
                        : () {
                            setState(() {
                              _registering = !_registering;
                              _error = null;
                            });
                          },
                    child: Text(
                      _registering
                          ? 'Already have an account? Log in'
                          : 'Need an account? Register',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class OrganizationPage extends StatefulWidget {
  const OrganizationPage({
    required this.token,
    required this.username,
    required this.onOrganizationReady,
    required this.onLogout,
    super.key,
  });

  final String token;
  final String username;
  final ValueChanged<Organization> onOrganizationReady;
  final VoidCallback onLogout;

  @override
  State<OrganizationPage> createState() => _OrganizationPageState();
}

class _OrganizationPageState extends State<OrganizationPage> {
  final _joinCodeController = TextEditingController();
  final _organizationNameController = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _joinCodeController.dispose();
    _organizationNameController.dispose();
    super.dispose();
  }

  Future<void> _joinOrganization() async {
    final joinCode = _joinCodeController.text.trim();
    if (joinCode.isEmpty || _submitting) {
      setState(() => _error = 'Enter a join code.');
      return;
    }
    await _saveOrganization(
      () => ApiClient(token: widget.token).joinOrganization(joinCode: joinCode),
    );
  }

  Future<void> _createOrganization() async {
    final name = _organizationNameController.text.trim();
    if (name.isEmpty || _submitting) {
      setState(() => _error = 'Enter an organization name.');
      return;
    }
    await _saveOrganization(
      () => ApiClient(token: widget.token).createOrganization(name: name),
    );
  }

  Future<void> _saveOrganization(Future<Organization> Function() action) async {
    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final organization = await action();
      widget.onOrganizationReady(organization);
    } on ApiException catch (error) {
      setState(() => _error = error.message);
    } catch (_) {
      setState(() => _error = 'Could not reach backend at $apiBaseUrl.');
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Signed in as ${widget.username}'),
        actions: [
          IconButton(
            tooltip: 'Log out',
            onPressed: _submitting ? null : widget.onLogout,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Join one organization',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'Your account must belong to exactly one organization. Use a join code or create a new organization.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 24),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final panelWidth = constraints.maxWidth < 720
                        ? constraints.maxWidth
                        : (constraints.maxWidth - 16) / 2;
                    return Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      children: [
                        SizedBox(
                          width: panelWidth,
                          child: _ActionPanel(
                            title: 'Use a join code',
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                TextField(
                                  controller: _joinCodeController,
                                  decoration: const InputDecoration(
                                      labelText: 'Join code'),
                                  textCapitalization:
                                      TextCapitalization.characters,
                                  onSubmitted: (_) => _joinOrganization(),
                                ),
                                const SizedBox(height: 12),
                                FilledButton.icon(
                                  onPressed:
                                      _submitting ? null : _joinOrganization,
                                  icon: const Icon(Icons.group_add),
                                  label: const Text('Join organization'),
                                ),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(
                          width: panelWidth,
                          child: _ActionPanel(
                            title: 'Create a new organization',
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                TextField(
                                  controller: _organizationNameController,
                                  decoration: const InputDecoration(
                                    labelText: 'Organization name',
                                  ),
                                  onSubmitted: (_) => _createOrganization(),
                                ),
                                const SizedBox(height: 12),
                                OutlinedButton.icon(
                                  onPressed:
                                      _submitting ? null : _createOrganization,
                                  icon: const Icon(Icons.add_business),
                                  label: const Text('Create organization'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    _error!,
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class LoggedInPage extends StatelessWidget {
  const LoggedInPage({
    required this.user,
    required this.organization,
    required this.onLogout,
    super.key,
  });

  final AppUser user;
  final Organization organization;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('CAC 2026'),
        actions: [
          IconButton(
            tooltip: 'Log out',
            onPressed: onLogout,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(
                  Icons.verified_user,
                  size: 56,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 16),
                Text(
                  'You are logged in',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 24),
                _InfoRow(label: 'User', value: user.username),
                _InfoRow(label: 'Organization', value: organization.name),
                _InfoRow(label: 'Join code', value: organization.joinCode),
                _InfoRow(
                  label: 'Members',
                  value: organization.memberCount.toString(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionPanel extends StatelessWidget {
  const _ActionPanel({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelLarge,
            ),
          ),
          Expanded(child: SelectableText(value)),
        ],
      ),
    );
  }
}
