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
