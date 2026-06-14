import 'package:flutter/material.dart';

import '../models/app_user.dart';
import '../models/organization.dart';
import '../services/api_client.dart';
import '../widgets/info_row.dart';

class LoggedInPage extends StatefulWidget {
  const LoggedInPage({
    required this.user,
    required this.organization,
    required this.token,
    required this.onLogout,
    super.key,
  });

  final AppUser user;
  final Organization organization;
  final String token;
  final VoidCallback onLogout;

  @override
  State<LoggedInPage> createState() => _LoggedInPageState();
}

class _LoggedInPageState extends State<LoggedInPage> {
  bool _loadingMembers = false;
  String? _memberError;
  List<OrganizationMembership> _members = [];
  bool _loadingReports = false;
  String? _reportsError;
  List<EmergencyReport> _reports = [];
  int _selectedIndex = 0;
  int _reportStep = 0;
  String _reportType = 'fire';
  bool _submittingReport = false;
  String? _reportError;
  String? _reportSuccess;
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _detailsController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.user.organizationRole == 'administrator') {
      _loadMembers();
      _loadReports();
    }
  }

  @override
  void dispose() {
    _locationController.dispose();
    _detailsController.dispose();
    super.dispose();
  }

  Future<void> _loadMembers() async {
    if (widget.user.organizationRole != 'administrator') {
      return;
    }

    setState(() {
      _loadingMembers = true;
      _memberError = null;
    });

    try {
      final members = await ApiClient(token: widget.token).fetchOrganizationMembers();
      if (mounted) {
        setState(() => _members = members);
      }
    } on ApiException catch (error) {
      if (mounted) {
        setState(() => _memberError = error.message);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _memberError = 'Could not load organization members.');
      }
    } finally {
      if (mounted) {
        setState(() => _loadingMembers = false);
      }
    }
  }

  Future<void> _loadReports() async {
    if (widget.user.organizationRole != 'administrator') {
      return;
    }

    setState(() {
      _loadingReports = true;
      _reportsError = null;
    });

    try {
      final reports = await ApiClient(token: widget.token).fetchEmergencyReports();
      if (mounted) {
        setState(() => _reports = reports);
      }
    } on ApiException catch (error) {
      if (mounted) {
        setState(() => _reportsError = error.message);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _reportsError = 'Could not load emergency reports.');
      }
    } finally {
      if (mounted) {
        setState(() => _loadingReports = false);
      }
    }
  }

  Future<void> _changeRole(OrganizationMembership membership, String role) async {
    try {
      await ApiClient(token: widget.token).updateOrganizationMemberRole(
        userId: membership.userId,
        role: role,
      );
      await _loadMembers();
    } on ApiException catch (error) {
      if (mounted) {
        setState(() => _memberError = error.message);
      }
    }
  }

  Future<void> _submitReport() async {
    setState(() {
      _submittingReport = true;
      _reportError = null;
      _reportSuccess = null;
    });

    try {
      await ApiClient(token: widget.token).submitEmergencyReport(
        emergencyType: _reportType,
        location: _locationController.text.trim(),
        details: _detailsController.text.trim(),
      );

      if (mounted) {
        setState(() {
          _reportStep = 0;
          _reportType = 'fire';
          _locationController.clear();
          _detailsController.clear();
          _reportSuccess = 'Emergency report submitted.';
        });
        if (widget.user.organizationRole == 'administrator') {
          _loadReports();
        }
      }
    } on ApiException catch (error) {
      if (mounted) {
        setState(() => _reportError = error.message);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _reportError = 'Could not submit the report.');
      }
    } finally {
      if (mounted) {
        setState(() => _submittingReport = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = widget.user.organizationRole == 'administrator';

    return Scaffold(
      appBar: AppBar(
        title: const Text('CAC 2026'),
        actions: [
          IconButton(
            tooltip: 'Organization info',
            icon: const Icon(Icons.info_outline),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Organization Information'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      InfoRow(
                        label: 'User',
                        value: widget.user.username,
                      ),
                      InfoRow(
                        label: 'Organization',
                        value: widget.organization.name,
                      ),
                      InfoRow(
                        label: 'Join code',
                        value: widget.organization.joinCode,
                      ),
                      InfoRow(
                        label: 'Members',
                        value: widget.organization.memberCount.toString(),
                      ),
                      InfoRow(
                        label: 'Role',
                        value: widget.user.organizationRole ?? 'None',
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Close'),
                    ),
                  ],
                ),
              );
            },
          ),
          IconButton(
            tooltip: 'Log out',
            onPressed: widget.onLogout,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Report an incident',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 8),
                        const SizedBox(height: 24),
                        if (_reportSuccess != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Text(
                              _reportSuccess!,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ),
                        if (_reportError != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Text(
                              _reportError!,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                          ),
                        Text('Step ${_reportStep + 1} of 3'),
                        const SizedBox(height: 12),
                        if (_reportStep == 0) ...[
                          const Text('What type of emergency is this?'),
                          const SizedBox(height: 12),
                          RadioListTile<String>(
                            title: const Text('Fire'),
                            value: 'fire',
                            groupValue: _reportType,
                            onChanged: (value) => setState(() => _reportType = value ?? 'fire'),
                          ),
                          RadioListTile<String>(
                            title: const Text('Medical'),
                            value: 'medical',
                            groupValue: _reportType,
                            onChanged: (value) => setState(() => _reportType = value ?? 'medical'),
                          ),
                          RadioListTile<String>(
                            title: const Text('Intruder'),
                            value: 'intruder',
                            groupValue: _reportType,
                            onChanged: (value) => setState(() => _reportType = value ?? 'intruder'),
                          ),
                        ] else if (_reportStep == 1) ...[
                          const Text('Where are you right now?'),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _locationController,
                            decoration: const InputDecoration(
                              labelText: 'Location',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ] else ...[
                          const Text('Any extra details?'),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _detailsController,
                            maxLines: 4,
                            decoration: const InputDecoration(
                              labelText: 'Details (optional)',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ],
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            if (_reportStep > 0)
                              OutlinedButton(
                                onPressed: () {
                                  setState(() {
                                    _reportStep -= 1;
                                    _reportError = null;
                                    _reportSuccess = null;
                                  });
                                },
                                child: const Text('Back'),
                              ),
                            const Spacer(),
                            if (_reportStep < 2)
                              ElevatedButton(
                                onPressed: () {
                                  if (_reportStep == 1 && _locationController.text.trim().isEmpty) {
                                    setState(() => _reportError = 'Location is required.');
                                    return;
                                  }

                                  setState(() {
                                    _reportStep += 1;
                                    _reportError = null;
                                  });
                                },
                                child: const Text('Next'),
                              )
                            else
                              ElevatedButton(
                                onPressed: _submittingReport ? null : _submitReport,
                                child: _submittingReport
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      )
                                    : const Text('Submit report'),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Alerts',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 16),
                        const ListTile(
                          leading: Icon(Icons.notifications),
                          title: Text('Competition starts tomorrow'),
                          subtitle: Text(
                            'Be sure to arrive by 8:30 AM for check-in.',
                          ),
                        ),
                        const Divider(),
                        const ListTile(
                          leading: Icon(Icons.info),
                          title: Text('Lunch information'),
                          subtitle: Text(
                            'Lunch will be provided to all participants.',
                          ),
                        ),
                        const Divider(),
                        const ListTile(
                          leading: Icon(Icons.warning_amber),
                          title: Text('Bring your laptop charger'),
                          subtitle: Text(
                            'Power outlets may be limited.',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (isAdmin)
            SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Emergency reports',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Administrators can review reports submitted by organization members.',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 16),
                          if (_loadingReports)
                            const Center(child: CircularProgressIndicator())
                          else if (_reportsError != null)
                            Text(
                              _reportsError!,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                              ),
                            )
                          else if (_reports.isEmpty)
                            const Text('No emergency reports yet.')
                          else
                            ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _reports.length,
                              separatorBuilder: (_, __) => const Divider(),
                              itemBuilder: (context, index) {
                                final report = _reports[index];
                                return ListTile(
                                  leading: const Icon(Icons.warning_amber_rounded),
                                  title: Text(report.emergencyTypeLabel),
                                  subtitle: Text(
                                    '${report.location}\n${report.details.isEmpty ? 'No additional details provided.' : report.details}',
                                  ),
                                  trailing: Text(report.reportedByUsername),
                                );
                              },
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            _selectedIndex = index;
          });
          if (index == 2 && isAdmin) {
            _loadReports();
          }
        },
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.report_outlined),
            selectedIcon: Icon(Icons.report),
            label: 'Report',
          ),
          const NavigationDestination(
            icon: Icon(Icons.crisis_alert_outlined),
            selectedIcon: Icon(Icons.crisis_alert),
            label: 'Alerts',
          ),
          if (isAdmin)
            const NavigationDestination(
              icon: Icon(Icons.admin_panel_settings_outlined),
              selectedIcon: Icon(Icons.admin_panel_settings),
              label: 'Manage',
            ),
        ],
      ),
    );
  }
}
