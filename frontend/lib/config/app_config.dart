class AppConfig {
  static const configuredApiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );
  static const authTokenKey = 'auth_token';

  static String get apiBaseUrl {
    if (configuredApiBaseUrl.isNotEmpty) {
      return configuredApiBaseUrl;
    }

    final page = Uri.base;
    final host = page.host.isEmpty ? 'localhost' : page.host;
    final scheme = page.scheme == 'https' ? 'https' : 'http';
    return '$scheme://$host:8000/api';
  }
}
