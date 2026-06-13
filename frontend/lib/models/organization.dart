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
