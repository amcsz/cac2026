import 'package:flutter/material.dart';

import '../models/app_user.dart';
import '../models/organization.dart';
import '../widgets/info_row.dart';

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
                InfoRow(label: 'User', value: user.username),
                InfoRow(label: 'Organization', value: organization.name),
                InfoRow(label: 'Join code', value: organization.joinCode),
                InfoRow(
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
