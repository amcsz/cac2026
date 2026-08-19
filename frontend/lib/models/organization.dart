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

class OrganizationMembership {
  const OrganizationMembership({
    required this.id,
    required this.userId,
    required this.username,
    required this.email,
    required this.role,
    required this.joinedAt,
    required this.isOwner,
  });

  final int id;
  final int userId;
  final String username;
  final String email;
  final String role;
  final String joinedAt;
  final bool isOwner;

  factory OrganizationMembership.fromJson(Map<String, dynamic> json) {
    return OrganizationMembership(
      id: json['id'] as int,
      userId: json['user_id'] as int,
      username: json['username'] as String,
      email: json['email'] as String? ?? '',
      role: json['role'] as String,
      joinedAt: json['joined_at'] as String? ?? '',
      isOwner: json['is_owner'] as bool? ?? false,
    );
  }

  String get roleLabel {
    switch (role) {
      case 'administrator':
        return 'Administrator';
      case 'teacher':
        return 'Teacher';
      default:
        return 'Member';
    }
  }
}

class EmergencyReport {
  const EmergencyReport({
    required this.id,
    required this.emergencyType,
    required this.location,
    required this.details,
    required this.createdAt,
    required this.reportedByUsername,
    required this.organizationName,
  });

  final int id;
  final String emergencyType;
  final String location;
  final String details;
  final String createdAt;
  final String reportedByUsername;
  final String organizationName;

  factory EmergencyReport.fromJson(Map<String, dynamic> json) {
    return EmergencyReport(
      id: json['id'] as int,
      emergencyType: json['emergency_type'] as String,
      location: json['location'] as String,
      details: json['details'] as String? ?? '',
      createdAt: json['created_at'] as String? ?? '',
      reportedByUsername: json['reported_by_username'] as String? ?? 'Unknown',
      organizationName: json['organization_name'] as String? ?? '',
    );
  }

  String get emergencyTypeLabel {
    switch (emergencyType) {
      case 'medical':
        return 'Medical';
      case 'intruder':
        return 'Intruder';
      default:
        return 'Fire';
    }
  }
}

class AlertSummary {
  const AlertSummary({
    required this.headline,
    required this.summary,
    required this.draftMessage,
    required this.reportCount,
    required this.generatedAt,
    required this.windowHours,
  });

  final String headline;
  final String summary;
  final String draftMessage;
  final int reportCount;
  final String generatedAt;
  final int windowHours;

  factory AlertSummary.fromJson(Map<String, dynamic> json) {
    return AlertSummary(
      headline: json['headline'] as String? ?? '',
      summary: json['summary'] as String? ?? '',
      draftMessage: json['draft_message'] as String? ?? '',
      reportCount: json['report_count'] as int? ?? 0,
      generatedAt: json['generated_at'] as String? ?? '',
      windowHours: json['window_hours'] as int? ?? 24,
    );
  }
}

class GlobalAlert {
  const GlobalAlert({
    required this.id,
    required this.headline,
    required this.message,
    required this.createdAt,
    required this.createdByUsername,
  });

  final int id;
  final String headline;
  final String message;
  final String createdAt;
  final String createdByUsername;

  factory GlobalAlert.fromJson(Map<String, dynamic> json) {
    return GlobalAlert(
      id: json['id'] as int,
      headline: json['headline'] as String? ?? '',
      message: json['message'] as String? ?? '',
      createdAt: json['created_at'] as String? ?? '',
      createdByUsername: json['created_by_username'] as String? ?? '',
    );
  }
}

class ReportArchiveDay {
  const ReportArchiveDay({
    required this.date,
    required this.count,
    required this.reportCount,
    required this.alertCount,
  });

  final String date;
  final int count;
  final int reportCount;
  final int alertCount;

  factory ReportArchiveDay.fromJson(Map<String, dynamic> json) {
    return ReportArchiveDay(
      date: json['date'] as String? ?? '',
      count: json['count'] as int? ?? 0,
      reportCount: json['report_count'] as int? ?? 0,
      alertCount: json['alert_count'] as int? ?? 0,
    );
  }
}

class ArchiveEvent {
  const ArchiveEvent({
    required this.type,
    required this.createdAt,
    required this.report,
    required this.globalAlert,
  });

  final String type;
  final String createdAt;
  final EmergencyReport? report;
  final GlobalAlert? globalAlert;

  factory ArchiveEvent.fromJson(Map<String, dynamic> json) {
    final type = json['type'] as String? ?? '';
    final payload = json['payload'] as Map<String, dynamic>? ?? {};
    return ArchiveEvent(
      type: type,
      createdAt: json['created_at'] as String? ?? '',
      report: type == 'report' ? EmergencyReport.fromJson(payload) : null,
      globalAlert:
          type == 'global_alert' ? GlobalAlert.fromJson(payload) : null,
    );
  }
}

class PaginatedResult<T> {
  const PaginatedResult({
    required this.results,
    required this.page,
    required this.pageSize,
    required this.totalPages,
    required this.totalCount,
    required this.hasNext,
    required this.hasPrevious,
  });

  final List<T> results;
  final int page;
  final int pageSize;
  final int totalPages;
  final int totalCount;
  final bool hasNext;
  final bool hasPrevious;

  factory PaginatedResult.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    final decodedResults = json['results'] as List<dynamic>? ?? [];
    return PaginatedResult(
      results: decodedResults
          .map((item) => fromJson(item as Map<String, dynamic>))
          .toList(),
      page: json['page'] as int? ?? 1,
      pageSize: json['page_size'] as int? ?? 10,
      totalPages: json['total_pages'] as int? ?? 1,
      totalCount: json['total_count'] as int? ?? 0,
      hasNext: json['has_next'] as bool? ?? false,
      hasPrevious: json['has_previous'] as bool? ?? false,
    );
  }
}
