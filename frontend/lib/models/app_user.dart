import 'organization.dart';

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
