import 'package:flutter/material.dart';

import '../models/app_user.dart';
import '../models/organization.dart';
import '../services/api_client.dart';
import '../widgets/global_alert_banner.dart';
import '../widgets/info_row.dart';
import 'logged_in/alerts_tab.dart';
import 'logged_in/manage_tab.dart';
import 'logged_in/report_tab.dart';

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
  int? _updatingRoleUserId;

  bool _loadingReports = false;
  String? _reportsError;
  List<EmergencyReport> _reports = [];

  bool _loadingAlertSummary = false;
  String? _alertSummaryError;
  AlertSummary? _alertSummary;

  bool _loadingGlobalAlert = false;
  bool _publishingGlobalAlert = false;
  String? _globalAlertError;
  GlobalAlert? _globalAlert;

  int _selectedIndex = 0;
  int _reportStep = 0;
  String _reportType = 'fire';
  bool _submittingReport = false;
  String? _reportError;
  String? _reportSuccess;

  final TextEditingController _broadcastHeadlineController =
      TextEditingController();
  final TextEditingController _broadcastMessageController =
      TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _detailsController = TextEditingController();

  bool get _isAdmin => widget.user.organizationRole == 'administrator';

  @override
  void initState() {
    super.initState();
    _loadGlobalAlert();
    if (_isAdmin) {
      _loadMembers();
      _loadReports();
      _loadAlertSummary();
    }
  }

  @override
  void dispose() {
    _broadcastHeadlineController.dispose();
    _broadcastMessageController.dispose();
    _locationController.dispose();
    _detailsController.dispose();
    super.dispose();
  }

  Future<void> _loadMembers() async {
    if (!_isAdmin) {
      return;
    }

    setState(() {
      _loadingMembers = true;
      _memberError = null;
    });

    try {
      final members =
          await ApiClient(token: widget.token).fetchOrganizationMembers();
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
    if (!_isAdmin) {
      return;
    }

    setState(() {
      _loadingReports = true;
      _reportsError = null;
    });

    try {
      final reports =
          await ApiClient(token: widget.token).fetchEmergencyReports();
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

  Future<void> _loadAlertSummary() async {
    if (!_isAdmin) {
      return;
    }

    setState(() {
      _loadingAlertSummary = true;
      _alertSummaryError = null;
    });

    try {
      final summary = await ApiClient(token: widget.token).fetchAlertSummary();
      if (mounted) {
        setState(() {
          _alertSummary = summary;
          _broadcastHeadlineController.text = summary.headline;
          _broadcastMessageController.text = summary.draftMessage;
        });
      }
    } on ApiException catch (error) {
      if (mounted) {
        setState(() => _alertSummaryError = error.message);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _alertSummaryError = 'Could not load alert summary.');
      }
    } finally {
      if (mounted) {
        setState(() => _loadingAlertSummary = false);
      }
    }
  }

  Future<void> _loadGlobalAlert() async {
    setState(() {
      _loadingGlobalAlert = true;
      _globalAlertError = null;
    });

    try {
      final alert = await ApiClient(token: widget.token).fetchGlobalAlert();
      if (mounted) {
        setState(() => _globalAlert = alert);
      }
    } on ApiException catch (error) {
      if (mounted) {
        setState(() => _globalAlertError = error.message);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _globalAlertError = 'Could not load global alert.');
      }
    } finally {
      if (mounted) {
        setState(() => _loadingGlobalAlert = false);
      }
    }
  }

  Future<void> _publishGlobalAlert() async {
    final headline = _broadcastHeadlineController.text.trim();
    final message = _broadcastMessageController.text.trim();
    if (headline.isEmpty || message.isEmpty || _publishingGlobalAlert) {
      setState(() => _globalAlertError = 'Headline and message are required.');
      return;
    }

    setState(() {
      _publishingGlobalAlert = true;
      _globalAlertError = null;
    });

    try {
      final alert = await ApiClient(token: widget.token).publishGlobalAlert(
        headline: headline,
        message: message,
      );
      if (mounted) {
        setState(() => _globalAlert = alert);
      }
    } on ApiException catch (error) {
      if (mounted) {
        setState(() => _globalAlertError = error.message);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _globalAlertError = 'Could not publish global alert.');
      }
    } finally {
      if (mounted) {
        setState(() => _publishingGlobalAlert = false);
      }
    }
  }

  Future<void> _changeRole(
      OrganizationMembership membership, String role) async {
    if (membership.isOwner ||
        membership.role == role ||
        _updatingRoleUserId != null) {
      return;
    }

    setState(() {
      _updatingRoleUserId = membership.userId;
      _memberError = null;
    });

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
    } catch (_) {
      if (mounted) {
        setState(() => _memberError = 'Could not update that role.');
      }
    } finally {
      if (mounted) {
        setState(() => _updatingRoleUserId = null);
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
        if (_isAdmin) {
          _loadReports();
          _loadAlertSummary();
        }
        _loadGlobalAlert();
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

  void _previousReportStep() {
    setState(() {
      _reportStep -= 1;
      _reportError = null;
      _reportSuccess = null;
    });
  }

  void _nextReportStep() {
    if (_reportStep == 1 && _locationController.text.trim().isEmpty) {
      setState(() => _reportError = 'Location is required.');
      return;
    }

    setState(() {
      _reportStep += 1;
      _reportError = null;
    });
  }

  void _selectDestination(int index) {
    setState(() => _selectedIndex = index);

    if (index == 1) {
      _loadGlobalAlert();
    }
    if (index == 1 && _isAdmin) {
      _loadAlertSummary();
      _loadReports();
    }
    if (index == 2 && _isAdmin) {
      _loadMembers();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('CAC 2026'),
        actions: [
          IconButton(
            tooltip: 'Organization info',
            icon: const Icon(Icons.info_outline),
            onPressed: _showOrganizationInfo,
          ),
          IconButton(
            tooltip: 'Log out',
            onPressed: widget.onLogout,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_globalAlert != null) GlobalAlertBanner(alert: _globalAlert!),
          Expanded(
            child: IndexedStack(
              index: _selectedIndex,
              children: [
                ReportTab(
                  reportStep: _reportStep,
                  reportType: _reportType,
                  submittingReport: _submittingReport,
                  reportError: _reportError,
                  reportSuccess: _reportSuccess,
                  locationController: _locationController,
                  detailsController: _detailsController,
                  onReportTypeChanged: (value) {
                    setState(() => _reportType = value);
                  },
                  onBack: _previousReportStep,
                  onNext: _nextReportStep,
                  onSubmit: _submitReport,
                ),
                AlertsTab(
                  isAdmin: _isAdmin,
                  loadingGlobalAlert: _loadingGlobalAlert,
                  globalAlertError: _globalAlertError,
                  globalAlert: _globalAlert,
                  loadingAlertSummary: _loadingAlertSummary,
                  alertSummaryError: _alertSummaryError,
                  alertSummary: _alertSummary,
                  broadcastHeadlineController: _broadcastHeadlineController,
                  broadcastMessageController: _broadcastMessageController,
                  publishingGlobalAlert: _publishingGlobalAlert,
                  loadingReports: _loadingReports,
                  reportsError: _reportsError,
                  reports: _reports,
                  onRefreshSummary: _loadAlertSummary,
                  onPublishGlobalAlert: _publishGlobalAlert,
                ),
                if (_isAdmin)
                  ManageTab(
                    loadingMembers: _loadingMembers,
                    memberError: _memberError,
                    members: _members,
                    updatingRoleUserId: _updatingRoleUserId,
                    onChangeRole: _changeRole,
                  ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _selectDestination,
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
          if (_isAdmin)
            const NavigationDestination(
              icon: Icon(Icons.admin_panel_settings_outlined),
              selectedIcon: Icon(Icons.admin_panel_settings),
              label: 'Manage',
            ),
        ],
      ),
    );
  }

  void _showOrganizationInfo() {
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
  }
}
