import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../models/app_user.dart';
import '../models/auth_session.dart';
import '../models/organization.dart';

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
      Uri.parse('${AppConfig.apiBaseUrl}/auth/register/'),
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
      Uri.parse('${AppConfig.apiBaseUrl}/auth/login/'),
      headers: _headers,
      body: jsonEncode({'username': username, 'password': password}),
    );
    return AuthSession.fromJson(_decode(response));
  }

  Future<void> logout() async {
    if (token == null) {
      return;
    }

    await http.post(
      Uri.parse('${AppConfig.apiBaseUrl}/auth/logout/'),
      headers: _headers,
    );
  }

  Future<void> registerFcmDevice({
    required String fcmToken,
    required String platform,
  }) async {
    final response = await http.post(
      Uri.parse('${AppConfig.apiBaseUrl}/auth/fcm-device/'),
      headers: _headers,
      body: jsonEncode({'token': fcmToken, 'platform': platform}),
    );

    if (response.statusCode == 200) {
      return;
    }

    throw ApiException(_extractError(response));
  }

  Future<void> unregisterFcmDevice({String? fcmToken}) async {
    final response = await http.delete(
      Uri.parse('${AppConfig.apiBaseUrl}/auth/fcm-device/'),
      headers: _headers,
      body: fcmToken == null ? null : jsonEncode({'token': fcmToken}),
    );

    if (response.statusCode == 204) {
      return;
    }

    throw ApiException(_extractError(response));
  }

  Future<AppUser> me() async {
    final response = await http.get(
      Uri.parse('${AppConfig.apiBaseUrl}/auth/me/'),
      headers: _headers,
    );
    return AppUser.fromJson(_decode(response));
  }

  Future<Organization> createOrganization({required String name}) async {
    final response = await http.post(
      Uri.parse('${AppConfig.apiBaseUrl}/organizations/create/'),
      headers: _headers,
      body: jsonEncode({'name': name}),
    );
    return Organization.fromJson(_decode(response, expected: 201));
  }

  Future<Organization> joinOrganization({required String joinCode}) async {
    final response = await http.post(
      Uri.parse('${AppConfig.apiBaseUrl}/organizations/join/'),
      headers: _headers,
      body: jsonEncode({'join_code': joinCode}),
    );
    return Organization.fromJson(_decode(response));
  }

  Future<List<OrganizationMembership>> fetchOrganizationMembers() async {
    final response = await http.get(
      Uri.parse('${AppConfig.apiBaseUrl}/organizations/members/'),
      headers: _headers,
    );

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body) as List<dynamic>;
      return decoded
          .map((item) =>
              OrganizationMembership.fromJson(item as Map<String, dynamic>))
          .toList();
    }

    throw ApiException(_extractError(response));
  }

  Future<OrganizationMembership> updateOrganizationMemberRole({
    required int userId,
    required String role,
  }) async {
    final response = await http.patch(
      Uri.parse('${AppConfig.apiBaseUrl}/organizations/members/'),
      headers: _headers,
      body: jsonEncode({'user_id': userId, 'role': role}),
    );

    if (response.statusCode == 200) {
      return OrganizationMembership.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    }

    throw ApiException(_extractError(response));
  }

  Future<EmergencyReport> submitEmergencyReport({
    required String emergencyType,
    required String details,
  }) async {
    final response = await http.post(
      Uri.parse('${AppConfig.apiBaseUrl}/reports/'),
      headers: _headers,
      body: jsonEncode({
        'emergency_type': emergencyType,
        'details': details,
      }),
    );

    if (response.statusCode == 201) {
      return EmergencyReport.fromJson(
          jsonDecode(response.body) as Map<String, dynamic>);
    }

    throw ApiException(_extractError(response));
  }

  Future<List<EmergencyReport>> fetchEmergencyReports() async {
    final response = await http.get(
      Uri.parse('${AppConfig.apiBaseUrl}/reports/'),
      headers: _headers,
    );

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body) as List<dynamic>;
      return decoded
          .map((item) => EmergencyReport.fromJson(item as Map<String, dynamic>))
          .toList();
    }

    throw ApiException(_extractError(response));
  }

  Future<PaginatedResult<ReportArchiveDay>> fetchReportArchiveDays({
    int page = 1,
  }) async {
    final response = await http.get(
      Uri.parse('${AppConfig.apiBaseUrl}/reports/archive/days/?page=$page'),
      headers: _headers,
    );

    if (response.statusCode == 200) {
      return PaginatedResult.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
        ReportArchiveDay.fromJson,
      );
    }

    throw ApiException(_extractError(response));
  }

  Future<PaginatedResult<ArchiveEvent>> fetchArchivedReports({
    required String date,
    int page = 1,
  }) async {
    final response = await http.get(
      Uri.parse(
          '${AppConfig.apiBaseUrl}/reports/archive/?date=$date&page=$page'),
      headers: _headers,
    );

    if (response.statusCode == 200) {
      return PaginatedResult.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
        ArchiveEvent.fromJson,
      );
    }

    throw ApiException(_extractError(response));
  }

  Future<List<EmergencyReport>> simulateEmergencyScenario({
    required String scenario,
  }) async {
    final response = await http.post(
      Uri.parse('${AppConfig.apiBaseUrl}/reports/simulate/'),
      headers: _headers,
      body: jsonEncode({'scenario': scenario}),
    );

    if (response.statusCode == 201) {
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final reports = decoded['reports'] as List<dynamic>? ?? [];
      return reports
          .map((item) => EmergencyReport.fromJson(item as Map<String, dynamic>))
          .toList();
    }

    throw ApiException(_extractError(response));
  }

  Future<AlertSummary> fetchAlertSummary() async {
    final response = await http.get(
      Uri.parse('${AppConfig.apiBaseUrl}/alerts/summary/'),
      headers: _headers,
    );

    if (response.statusCode == 200) {
      return AlertSummary.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    }

    throw ApiException(_extractError(response));
  }

  Future<AlertSummary> verifyAlertSummary() async {
    final response = await http.post(
      Uri.parse('${AppConfig.apiBaseUrl}/alerts/summary/'),
      headers: _headers,
    );

    if (response.statusCode == 200) {
      return AlertSummary.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    }

    throw ApiException(_extractError(response));
  }

  Future<GlobalAlert?> fetchGlobalAlert() async {
    final response = await http.get(
      Uri.parse('${AppConfig.apiBaseUrl}/alerts/global/'),
      headers: _headers,
    );

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final alertJson = decoded['alert'];
      if (alertJson == null) {
        return null;
      }
      return GlobalAlert.fromJson(alertJson as Map<String, dynamic>);
    }

    throw ApiException(_extractError(response));
  }

  Future<GlobalAlert> publishGlobalAlert({
    required String headline,
    required String message,
    required String incidentType,
    required bool adminsOnly,
  }) async {
    final response = await http.post(
      Uri.parse('${AppConfig.apiBaseUrl}/alerts/global/'),
      headers: _headers,
      body: jsonEncode({
        'headline': headline,
        'message': message,
        'incident_type': incidentType,
        'admins_only': adminsOnly,
      }),
    );

    if (response.statusCode == 201) {
      return GlobalAlert.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    }

    throw ApiException(_extractError(response));
  }

  Future<List<ReportConversation>> fetchReportConversations() async {
    final response = await http.get(
      Uri.parse('${AppConfig.apiBaseUrl}/communications/'),
      headers: _headers,
    );

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body) as List<dynamic>;
      return decoded
          .map((item) =>
              ReportConversation.fromJson(item as Map<String, dynamic>))
          .toList();
    }

    throw ApiException(_extractError(response));
  }

  Future<ReportConversation> createReportConversation({
    required int reportId,
  }) async {
    final response = await http.post(
      Uri.parse('${AppConfig.apiBaseUrl}/communications/'),
      headers: _headers,
      body: jsonEncode({'report_id': reportId}),
    );

    if (response.statusCode == 201) {
      return ReportConversation.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    }

    throw ApiException(_extractError(response));
  }

  Future<List<ReportChatMessage>> fetchConversationMessages({
    required int conversationId,
  }) async {
    final response = await http.get(
      Uri.parse(
          '${AppConfig.apiBaseUrl}/communications/$conversationId/messages/'),
      headers: _headers,
    );

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body) as List<dynamic>;
      return decoded
          .map((item) =>
              ReportChatMessage.fromJson(item as Map<String, dynamic>))
          .toList();
    }

    throw ApiException(_extractError(response));
  }

  Future<ReportChatMessage> sendConversationMessage({
    required int conversationId,
    required String body,
  }) async {
    final response = await http.post(
      Uri.parse(
          '${AppConfig.apiBaseUrl}/communications/$conversationId/messages/'),
      headers: _headers,
      body: jsonEncode({'body': body}),
    );

    if (response.statusCode == 201) {
      return ReportChatMessage.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    }

    throw ApiException(_extractError(response));
  }

  Future<void> clearGlobalAlert() async {
    final response = await http.delete(
      Uri.parse('${AppConfig.apiBaseUrl}/alerts/global/'),
      headers: _headers,
    );

    if (response.statusCode == 204) {
      return;
    }

    throw ApiException(_extractError(response));
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
