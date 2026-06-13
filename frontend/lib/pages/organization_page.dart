import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../models/organization.dart';
import '../services/api_client.dart';
import '../widgets/action_panel.dart';

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
      setState(() => _error = 'Could not reach backend at ${AppConfig.apiBaseUrl}.');
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
                          child: ActionPanel(
                            title: 'Use a join code',
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                TextField(
                                  controller: _joinCodeController,
                                  decoration: const InputDecoration(
                                      labelText: 'Join code'),
                                  textCapitalization: TextCapitalization.characters,
                                  onSubmitted: (_) => _joinOrganization(),
                                ),
                                const SizedBox(height: 12),
                                FilledButton.icon(
                                  onPressed: _submitting ? null : _joinOrganization,
                                  icon: const Icon(Icons.group_add),
                                  label: const Text('Join organization'),
                                ),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(
                          width: panelWidth,
                          child: ActionPanel(
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
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
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
