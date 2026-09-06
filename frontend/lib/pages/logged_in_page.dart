import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_user.dart';
import '../models/organization.dart';
import '../services/api_client.dart';
import '../services/notification_service.dart';
import '../utils/time_format.dart';
import '../widgets/global_alert_banner.dart';
import '../widgets/info_row.dart';
import '../widgets/markdown_text.dart';
import 'logged_in/alerts_tab.dart';
import 'logged_in/archive_tab.dart';
import 'logged_in/communication_tab.dart';
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
  static const Duration _globalAlertPollInterval = Duration(seconds: 10);
  static const Duration _alertSummaryPollInterval = Duration(seconds: 10);
  static const Duration _communicationsPollInterval = Duration(seconds: 3);

  bool _loadingMembers = false;
  String? _memberError;
  List<OrganizationMembership> _members = [];
  int? _updatingRoleUserId;

  bool _loadingReports = false;
  String? _reportsError;
  List<EmergencyReport> _reports = [];
  final Set<int> _readReportIds = {};
  final Set<int> _unreadReportIds = {};
  Set<int> _highlightedReportIds = {};
  bool _loadingArchiveDays = false;
  String? _archiveDaysError;
  List<ReportArchiveDay> _archiveDays = [];
  int _archiveDaysPage = 1;
  int _archiveDaysTotalPages = 1;
  bool _archiveDaysHasNext = false;
  bool _archiveDaysHasPrevious = false;
  String? _selectedArchiveDate;
  bool _loadingArchiveReports = false;
  String? _archiveReportsError;
  List<ArchiveEvent> _archiveEvents = [];
  int _archiveEventsPage = 1;
  int _archiveEventsTotalPages = 1;
  bool _archiveEventsHasNext = false;
  bool _archiveEventsHasPrevious = false;

  bool _loadingAlertSummary = false;
  bool _verifyingIncident = false;
  String? _alertSummaryError;
  AlertSummary? _alertSummary;
  String? _lastAlertSummaryGeneratedAt;
  String? _acknowledgedAlertSummaryGeneratedAt;
  bool _urgentSummaryNoticeVisible = false;

  bool _publishingGlobalAlert = false;
  bool _publishAdminsOnly = false;
  bool _clearingGlobalAlert = false;
  GlobalAlert? _globalAlert;
  int? _lastGlobalAlertId;
  bool _hasLoadedGlobalAlert = false;
  bool _showingFullScreenGlobalAlert = false;
  final Set<int> _dismissedFullScreenGlobalAlertIds = {};
  Timer? _globalAlertPoller;
  Timer? _alertSummaryPoller;
  Timer? _communicationsPoller;

  bool _loadingConversations = false;
  String? _conversationsError;
  List<ReportConversation> _conversations = [];
  final Set<int> _unreadConversationIds = {};
  final Set<int> _readMessageIds = {};
  Set<int> _highlightedMessageIds = {};
  int? _selectedConversationId;
  bool _loadingMessages = false;
  String? _messagesError;
  List<ReportChatMessage> _messages = [];
  bool _sendingMessage = false;
  int? _respondingReportId;
  bool _pollingCommunications = false;

  int _selectedIndex = 0;
  bool _showReportForm = false;
  int _reportStep = 0;
  String? _reportType;
  bool _submittingReport = false;
  String? _reportError;
  String? _reportSuccess;
  String? _simulatingScenario;
  String? _simulationError;

  final TextEditingController _broadcastHeadlineController =
      TextEditingController();
  final TextEditingController _broadcastMessageController =
      TextEditingController();
  final TextEditingController _chatMessageController = TextEditingController();
  final TextEditingController _detailsController = TextEditingController();
  final NotificationService _notificationService = createNotificationService();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  bool get _isAdmin => widget.user.organizationRole == 'administrator';

  String get _acknowledgedSummaryKey =>
      'acknowledged_alert_summary_${widget.organization.id}_${widget.user.id}';

  @override
  void initState() {
    super.initState();
    _requestNotificationPermission();
    _loadGlobalAlert(notifyIfChanged: false);
    _loadConversations();
    _startCommunicationsPolling();
    _startGlobalAlertPolling();
    _loadAlertSummary();
    _startAlertSummaryPolling();
    if (_isAdmin) {
      _loadMembers();
      _loadReports();
      _loadArchiveDays();
    }
  }

  @override
  void dispose() {
    _globalAlertPoller?.cancel();
    _alertSummaryPoller?.cancel();
    _communicationsPoller?.cancel();
    _broadcastHeadlineController.dispose();
    _broadcastMessageController.dispose();
    _chatMessageController.dispose();
    _detailsController.dispose();
    super.dispose();
  }

  Future<void> _requestNotificationPermission() async {
    try {
      await _notificationService.requestPermission();
    } catch (_) {}
  }

  void _startGlobalAlertPolling() {
    _globalAlertPoller?.cancel();
    _globalAlertPoller = Timer.periodic(
      _globalAlertPollInterval,
      (_) => _loadGlobalAlert(showLoading: false),
    );
  }

  void _startAlertSummaryPolling() {
    _alertSummaryPoller?.cancel();
    _alertSummaryPoller = Timer.periodic(
      _alertSummaryPollInterval,
      (_) {
        _loadAlertSummary(showLoading: false);
        if (_isAdmin) {
          _loadReports();
        }
      },
    );
  }

  void _startCommunicationsPolling() {
    _communicationsPoller?.cancel();
    _communicationsPoller = Timer.periodic(
      _communicationsPollInterval,
      (_) => _pollCommunications(),
    );
  }

  Future<void> _pollCommunications() async {
    if (_pollingCommunications) {
      return;
    }

    _pollingCommunications = true;
    try {
      await _loadConversations(showLoading: false);
      final conversationId = _selectedConversationId;
      if (_selectedIndex == 2 && conversationId != null) {
        await _loadConversationMessages(conversationId, showLoading: false);
      }
    } finally {
      _pollingCommunications = false;
    }
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
        setState(() {
          _reports = reports;
          _unreadReportIds
            ..clear()
            ..addAll(
              reports
                  .where((report) => !_readReportIds.contains(report.id))
                  .map((report) => report.id),
            );
        });
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

  Future<void> _loadArchiveDays({int page = 1}) async {
    if (!_isAdmin) {
      return;
    }

    setState(() {
      _loadingArchiveDays = true;
      _archiveDaysError = null;
    });

    try {
      final archive = await ApiClient(token: widget.token)
          .fetchReportArchiveDays(page: page);
      if (mounted) {
        setState(() {
          _archiveDays = archive.results;
          _archiveDaysPage = archive.page;
          _archiveDaysTotalPages = archive.totalPages;
          _archiveDaysHasNext = archive.hasNext;
          _archiveDaysHasPrevious = archive.hasPrevious;
        });
      }
    } on ApiException catch (error) {
      if (mounted) {
        setState(() => _archiveDaysError = error.message);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _archiveDaysError = 'Could not load archived days.');
      }
    } finally {
      if (mounted) {
        setState(() => _loadingArchiveDays = false);
      }
    }
  }

  Future<void> _loadArchiveReports(String date, {int page = 1}) async {
    if (!_isAdmin) {
      return;
    }

    setState(() {
      _selectedArchiveDate = date;
      _loadingArchiveReports = true;
      _archiveReportsError = null;
    });

    try {
      final reports = await ApiClient(token: widget.token)
          .fetchArchivedReports(date: date, page: page);
      if (mounted) {
        setState(() {
          _archiveEvents = reports.results;
          _archiveEventsPage = reports.page;
          _archiveEventsTotalPages = reports.totalPages;
          _archiveEventsHasNext = reports.hasNext;
          _archiveEventsHasPrevious = reports.hasPrevious;
        });
      }
    } on ApiException catch (error) {
      if (mounted) {
        setState(() => _archiveReportsError = error.message);
      }
    } catch (_) {
      if (mounted) {
        setState(
            () => _archiveReportsError = 'Could not load archived reports.');
      }
    } finally {
      if (mounted) {
        setState(() => _loadingArchiveReports = false);
      }
    }
  }

  void _showArchiveDays() {
    setState(() {
      _selectedArchiveDate = null;
      _archiveEvents = [];
      _archiveReportsError = null;
      _archiveEventsPage = 1;
      _archiveEventsTotalPages = 1;
      _archiveEventsHasNext = false;
      _archiveEventsHasPrevious = false;
    });
  }

  Future<void> _loadAlertSummary({
    bool showLoading = true,
    bool notifyIfChanged = true,
  }) async {
    if (showLoading) {
      setState(() {
        _loadingAlertSummary = true;
        _alertSummaryError = null;
      });
    }

    try {
      final summary = await ApiClient(token: widget.token).fetchAlertSummary();
      final acknowledgedGeneratedAt =
          await _loadAcknowledgedAlertSummaryGeneratedAt();
      if (mounted) {
        final generatedAt = summary.generatedAt;
        final hasNewGeneratedAt = generatedAt.isNotEmpty &&
            generatedAt != _lastAlertSummaryGeneratedAt;
        final shouldShowNotice = notifyIfChanged &&
            generatedAt.isNotEmpty &&
            generatedAt != acknowledgedGeneratedAt;

        setState(() {
          _alertSummary = summary;
          _acknowledgedAlertSummaryGeneratedAt = acknowledgedGeneratedAt;
          _lastAlertSummaryGeneratedAt =
              generatedAt.isEmpty ? _lastAlertSummaryGeneratedAt : generatedAt;
          _urgentSummaryNoticeVisible = shouldShowNotice;
          if (showLoading || shouldShowNotice || hasNewGeneratedAt) {
            _broadcastHeadlineController.text = summary.headline;
            _broadcastMessageController.text = summary.draftMessage;
          }
          _publishAdminsOnly = summary.incidentType == 'medical';
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
      if (mounted && showLoading) {
        setState(() => _loadingAlertSummary = false);
      }
    }
  }

  Future<String?> _loadAcknowledgedAlertSummaryGeneratedAt() async {
    if (_acknowledgedAlertSummaryGeneratedAt != null) {
      return _acknowledgedAlertSummaryGeneratedAt;
    }

    final preferences = await SharedPreferences.getInstance();
    return preferences.getString(_acknowledgedSummaryKey);
  }

  Future<void> _verifyIncident() async {
    if (!_isAdmin || _verifyingIncident) {
      return;
    }

    setState(() {
      _verifyingIncident = true;
      _alertSummaryError = null;
    });

    try {
      final summary = await ApiClient(token: widget.token).verifyAlertSummary();
      if (mounted) {
        setState(() {
          _alertSummary = summary;
          _lastAlertSummaryGeneratedAt = summary.generatedAt;
          _broadcastHeadlineController.text = summary.headline;
          _broadcastMessageController.text = summary.draftMessage;
          _publishAdminsOnly = summary.incidentType == 'medical';
        });
      }
    } on ApiException catch (error) {
      if (mounted) {
        setState(() => _alertSummaryError = error.message);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _alertSummaryError = 'Could not verify incident.');
      }
    } finally {
      if (mounted) {
        setState(() => _verifyingIncident = false);
      }
    }
  }

  Future<void> _acknowledgeUrgentSummaryNotice() async {
    final generatedAt = _alertSummary?.generatedAt;
    if (generatedAt != null && generatedAt.isNotEmpty) {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(_acknowledgedSummaryKey, generatedAt);
      _acknowledgedAlertSummaryGeneratedAt = generatedAt;
    }

    if (mounted) {
      setState(() => _urgentSummaryNoticeVisible = false);
    }
  }

  Future<void> _loadGlobalAlert({
    bool showLoading = true,
    bool notifyIfChanged = true,
  }) async {
    try {
      final alert = await ApiClient(token: widget.token).fetchGlobalAlert();
      if (mounted) {
        final shouldNotify = notifyIfChanged &&
            _hasLoadedGlobalAlert &&
            alert != null &&
            alert.id != _lastGlobalAlertId;

        setState(() {
          _globalAlert = alert;
          _lastGlobalAlertId = alert?.id;
          _hasLoadedGlobalAlert = true;
        });

        if (alert != null) {
          _showFullScreenGlobalAlertIfNeeded(alert);
        }

        if (shouldNotify) {
          await _showGlobalAlertNotification(alert);
        }
      }
    } on ApiException catch (error) {
      debugPrint('Could not load global alert: ${error.message}');
    } catch (_) {
      debugPrint('Could not load global alert.');
    }
  }

  Future<void> _showGlobalAlertNotification(GlobalAlert alert) async {
    if (!kIsWeb) {
      return;
    }

    try {
      await _notificationService.show(
        title: alert.headline,
        body: alert.message,
      );
    } catch (_) {}
  }

  Future<void> _publishGlobalAlert() async {
    final headline = _broadcastHeadlineController.text.trim();
    final message = _broadcastMessageController.text.trim();
    if (headline.isEmpty || message.isEmpty || _publishingGlobalAlert) {
      return;
    }

    setState(() => _publishingGlobalAlert = true);

    try {
      final alert = await ApiClient(token: widget.token).publishGlobalAlert(
        headline: headline,
        message: message,
        incidentType: switch (_alertSummary?.incidentType) {
          'intruder' => 'intruder',
          'medical' => 'medical',
          _ => 'fire',
        },
        adminsOnly: _publishAdminsOnly,
      );
      if (mounted) {
        setState(() {
          _globalAlert = alert;
          _lastGlobalAlertId = alert.id;
          _hasLoadedGlobalAlert = true;
        });
        _showFullScreenGlobalAlertIfNeeded(alert);
        await _showGlobalAlertNotification(alert);
      }
    } on ApiException catch (error) {
      debugPrint('Could not publish global alert: ${error.message}');
    } catch (_) {
      debugPrint('Could not publish global alert.');
    } finally {
      if (mounted) {
        setState(() => _publishingGlobalAlert = false);
      }
    }
  }

  Future<void> _clearGlobalAlert() async {
    if (!_isAdmin || _globalAlert == null || _clearingGlobalAlert) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear global message?'),
        content: const Text(
          'This will remove the message banner for everyone in your organization.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }

    setState(() => _clearingGlobalAlert = true);

    try {
      await ApiClient(token: widget.token).clearGlobalAlert();
      if (mounted) {
        setState(() {
          if (_globalAlert != null) {
            _dismissedFullScreenGlobalAlertIds.add(_globalAlert!.id);
          }
          _globalAlert = null;
        });
      }
    } on ApiException catch (error) {
      debugPrint('Could not clear global alert: ${error.message}');
    } catch (_) {
      debugPrint('Could not clear global alert.');
    } finally {
      if (mounted) {
        setState(() => _clearingGlobalAlert = false);
      }
    }
  }

  Future<void> _loadConversations({bool showLoading = true}) async {
    if (showLoading) {
      setState(() {
        _loadingConversations = true;
        _conversationsError = null;
      });
    }

    try {
      final conversations =
          await ApiClient(token: widget.token).fetchReportConversations();
      if (mounted) {
        setState(() {
          _conversations = conversations;
          _unreadConversationIds
            ..clear()
            ..addAll(
              conversations
                  .where(
                    (conversation) =>
                        conversation.lastMessageId != null &&
                        conversation.lastMessageSenderId != widget.user.id &&
                        !_readMessageIds.contains(conversation.lastMessageId),
                  )
                  .map((conversation) => conversation.id),
            );
          if (_selectedConversationId != null &&
              !conversations.any((conversation) =>
                  conversation.id == _selectedConversationId)) {
            _selectedConversationId = null;
            _messages = [];
          }
        });
      }
    } on ApiException catch (error) {
      if (mounted) {
        setState(() => _conversationsError = error.message);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _conversationsError = 'Could not load communications.');
      }
    } finally {
      if (mounted && showLoading) {
        setState(() => _loadingConversations = false);
      }
    }
  }

  Future<void> _loadConversationMessages(
    int conversationId, {
    bool showLoading = true,
  }) async {
    if (showLoading) {
      setState(() {
        _selectedConversationId = conversationId;
        _loadingMessages = true;
        _messagesError = null;
      });
    }

    try {
      final messages = await ApiClient(token: widget.token)
          .fetchConversationMessages(conversationId: conversationId);
      if (mounted && _selectedConversationId == conversationId) {
        setState(() => _messages = messages);
      }
    } on ApiException catch (error) {
      if (mounted && showLoading) {
        setState(() => _messagesError = error.message);
      }
    } catch (_) {
      if (mounted && showLoading) {
        setState(() => _messagesError = 'Could not load messages.');
      }
    } finally {
      if (mounted && showLoading) {
        setState(() => _loadingMessages = false);
      }
    }
  }

  Future<void> _openConversation(ReportConversation conversation) async {
    await _loadConversationMessages(conversation.id);
    if (!mounted || _selectedConversationId != conversation.id) {
      return;
    }

    final unreadMessages = _messages
        .where((message) =>
            !message.isMine && !_readMessageIds.contains(message.id))
        .map((message) => message.id)
        .toSet();
    setState(() {
      _highlightedMessageIds = unreadMessages;
      _readMessageIds.addAll(unreadMessages);
      _unreadConversationIds.remove(conversation.id);
    });
  }

  void _backToConversations() {
    setState(() {
      _selectedConversationId = null;
      _messages = [];
      _messagesError = null;
    });
  }

  Future<void> _respondToReport(EmergencyReport report) async {
    if (!_isAdmin || _respondingReportId != null) {
      return;
    }

    setState(() {
      _respondingReportId = report.id;
      _conversationsError = null;
    });

    try {
      final conversation = await ApiClient(token: widget.token)
          .createReportConversation(reportId: report.id);
      await _loadConversations(showLoading: false);
      if (mounted) {
        setState(() => _selectedIndex = 2);
        if (_scaffoldKey.currentState?.isEndDrawerOpen ?? false) {
          Navigator.pop(context);
        }
      }
      await _loadConversationMessages(conversation.id);
    } on ApiException catch (error) {
      if (mounted) {
        setState(() => _reportsError = error.message);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _reportsError = 'Could not open a response chat.');
      }
    } finally {
      if (mounted) {
        setState(() => _respondingReportId = null);
      }
    }
  }

  Future<void> _sendConversationMessage() async {
    final conversationId = _selectedConversationId;
    final body = _chatMessageController.text.trim();
    if (conversationId == null || body.isEmpty || _sendingMessage) {
      return;
    }

    setState(() {
      _sendingMessage = true;
      _messagesError = null;
    });

    try {
      final message = await ApiClient(token: widget.token)
          .sendConversationMessage(conversationId: conversationId, body: body);
      if (mounted) {
        setState(() {
          _chatMessageController.clear();
          _messages = [..._messages, message];
        });
      }
      _loadConversations(showLoading: false);
    } on ApiException catch (error) {
      if (mounted) {
        setState(() => _messagesError = error.message);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _messagesError = 'Could not send the message.');
      }
    } finally {
      if (mounted) {
        setState(() => _sendingMessage = false);
      }
    }
  }

  void _showFullScreenGlobalAlertIfNeeded(GlobalAlert alert) {
    if (_showingFullScreenGlobalAlert ||
        _dismissedFullScreenGlobalAlertIds.contains(alert.id)) {
      return;
    }

    _showingFullScreenGlobalAlert = true;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) {
        _showingFullScreenGlobalAlert = false;
        return;
      }

      await showDialog<void>(
        context: context,
        barrierDismissible: true,
        builder: (context) => _FullScreenGlobalAlertDialog(alert: alert),
      );

      if (mounted) {
        setState(() {
          _dismissedFullScreenGlobalAlertIds.add(alert.id);
          _showingFullScreenGlobalAlert = false;
        });
      } else {
        _showingFullScreenGlobalAlert = false;
      }
    });
  }

  Future<void> _simulateEmergencyScenario(String scenario) async {
    if (!_isAdmin || _simulatingScenario != null) {
      return;
    }

    setState(() {
      _simulatingScenario = scenario;
      _simulationError = null;
    });

    try {
      await ApiClient(token: widget.token).simulateEmergencyScenario(
        scenario: scenario,
      );
      await _loadReports();
      await _loadArchiveDays(page: _archiveDaysPage);
      if (mounted) {
        setState(() => _selectedIndex = 1);
      }
    } on ApiException catch (error) {
      if (mounted) {
        setState(() => _simulationError = error.message);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _simulationError = 'Could not simulate emergency.');
      }
    } finally {
      if (mounted) {
        setState(() => _simulatingScenario = null);
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

  Future<void> _removeMember(OrganizationMembership member) async {
    if (member.isOwner || _updatingRoleUserId != null) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove member'),
        content: Text(
          'Are you sure you want to remove ${member.username} from this organization?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }

    setState(() {
      _updatingRoleUserId = member.userId;
      _memberError = null;
    });

    try {
      await ApiClient(token: widget.token).removeOrganizationMember(
        userId: member.userId,
      );
      await _loadMembers();
    } on ApiException catch (error) {
      if (mounted) {
        setState(() => _memberError = error.message);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _memberError = 'Could not remove that member.');
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
        emergencyType: _reportType!,
        details: _detailsController.text.trim(),
      );

      if (mounted) {
        setState(() {
          _showReportForm = false;
          _reportStep = 0;
          _reportType = null;
          _detailsController.clear();
          _reportSuccess = 'Emergency report submitted.';
        });
        if (_isAdmin) {
          _loadReports();
          _loadAlertSummary(showLoading: false);
        }
        _loadGlobalAlert(showLoading: false);
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

  void _startReport() {
    setState(() {
      _showReportForm = true;
      _reportError = null;
      _reportSuccess = null;
    });
  }

  void _cancelReport() {
    setState(() {
      _showReportForm = false;
      _reportStep = 0;
      _reportType = null;
      _detailsController.clear();
      _reportError = null;
    });
  }

  void _previousReportStep() {
    setState(() {
      _reportStep -= 1;
      _reportError = null;
      _reportSuccess = null;
    });
  }

  void _nextReportStep() {
    setState(() {
      _reportStep += 1;
      _reportError = null;
    });
  }

  void _selectDestination(int index) {
    setState(() => _selectedIndex = index);

    if (index == 1) {
      _loadGlobalAlert(showLoading: false);
      _loadAlertSummary(showLoading: false);
    }
    if (index == 1 && _isAdmin) {
      _loadReports();
    }
    if (index == 2) {
      _loadConversations();
      _startCommunicationsPolling();
    }
    if (index == 3 && _isAdmin) {
      _loadArchiveDays(page: _archiveDaysPage);
    }
    if (index == 4 && _isAdmin) {
      _loadMembers();
    }
  }

  void _openTodayReportsSidebar() {
    if (!_isAdmin) {
      return;
    }

    setState(() {
      _highlightedReportIds = {..._unreadReportIds};
      _readReportIds.addAll(_reports.map((report) => report.id));
      _unreadReportIds.clear();
    });
    _loadReports();
    _scaffoldKey.currentState?.openEndDrawer();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: const Text('SwiftGuard'),
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
          if (_isAdmin && _urgentSummaryNoticeVisible)
            _UrgentSummaryNotice(
              onDismiss: () {
                _acknowledgeUrgentSummaryNotice();
              },
              onViewAlerts: () {
                setState(() {
                  _selectedIndex = 1;
                });
                _acknowledgeUrgentSummaryNotice();
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _openTodayReportsSidebar();
                });
              },
            ),
          if (_globalAlert != null) GlobalAlertBanner(alert: _globalAlert!),
          Expanded(
            child: IndexedStack(
              index: _selectedIndex,
              children: [
                ReportTab(
                  showReportForm: _showReportForm,
                  reportStep: _reportStep,
                  reportType: _reportType,
                  submittingReport: _submittingReport,
                  reportError: _reportError,
                  reportSuccess: _reportSuccess,
                  detailsController: _detailsController,
                  onStartReport: _startReport,
                  onReportTypeChanged: (value) {
                    setState(() => _reportType = value);
                  },
                  onCancel: _cancelReport,
                  onBack: _previousReportStep,
                  onNext: _nextReportStep,
                  onSubmit: _submitReport,
                ),
                AlertsTab(
                  isAdmin: _isAdmin,
                  globalAlert: _globalAlert,
                  loadingAlertSummary: _loadingAlertSummary,
                  alertSummaryError: _alertSummaryError,
                  alertSummary: _alertSummary,
                  verifyingIncident: _verifyingIncident,
                  broadcastHeadlineController: _broadcastHeadlineController,
                  broadcastMessageController: _broadcastMessageController,
                  publishingGlobalAlert: _publishingGlobalAlert,
                  publishAdminsOnly: _publishAdminsOnly,
                  clearingGlobalAlert: _clearingGlobalAlert,
                  todayReportCount: _reports.length,
                  unreadReportCount: _unreadReportIds.length,
                  onOpenReportsSidebar: _openTodayReportsSidebar,
                  onVerifyIncident: _verifyIncident,
                  onPublishGlobalAlert: _publishGlobalAlert,
                  onPublishAdminsOnlyChanged: (value) {
                    setState(() => _publishAdminsOnly = value);
                  },
                  onClearGlobalAlert: _clearGlobalAlert,
                ),
                CommunicationTab(
                  isAdmin: _isAdmin,
                  loadingConversations: _loadingConversations,
                  conversationsError: _conversationsError,
                  conversations: _conversations,
                  unreadConversationCount: _unreadConversationIds.length,
                  unreadConversationIds: _unreadConversationIds,
                  highlightedMessageIds: _highlightedMessageIds,
                  selectedConversationId: _selectedConversationId,
                  loadingMessages: _loadingMessages,
                  messagesError: _messagesError,
                  messages: _messages,
                  sendingMessage: _sendingMessage,
                  messageController: _chatMessageController,
                  onRefreshConversations: _loadConversations,
                  onRefreshMessages: (conversationId) {
                    _loadConversationMessages(conversationId);
                  },
                  onSelectConversation: _openConversation,
                  onBackToConversations: _backToConversations,
                  onSendMessage: _sendConversationMessage,
                ),
                if (_isAdmin)
                  ArchiveTab(
                    loadingDays: _loadingArchiveDays,
                    daysError: _archiveDaysError,
                    days: _archiveDays,
                    daysPage: _archiveDaysPage,
                    daysTotalPages: _archiveDaysTotalPages,
                    daysHasNext: _archiveDaysHasNext,
                    daysHasPrevious: _archiveDaysHasPrevious,
                    selectedDate: _selectedArchiveDate,
                    loadingReports: _loadingArchiveReports,
                    reportsError: _archiveReportsError,
                    events: _archiveEvents,
                    eventsPage: _archiveEventsPage,
                    eventsTotalPages: _archiveEventsTotalPages,
                    eventsHasNext: _archiveEventsHasNext,
                    eventsHasPrevious: _archiveEventsHasPrevious,
                    onRefreshDays: () =>
                        _loadArchiveDays(page: _archiveDaysPage),
                    onSelectDate: (date) => _loadArchiveReports(date),
                    onBackToDays: _showArchiveDays,
                    onDaysPageChanged: (page) => _loadArchiveDays(page: page),
                    onEventsPageChanged: (page) {
                      final date = _selectedArchiveDate;
                      if (date != null) {
                        _loadArchiveReports(date, page: page);
                      }
                    },
                  ),
                if (_isAdmin)
                  ManageTab(
                    loadingMembers: _loadingMembers,
                    memberError: _memberError,
                    members: _members,
                    updatingRoleUserId: _updatingRoleUserId,
                    simulatingScenario: _simulatingScenario,
                    simulationError: _simulationError,
                    onChangeRole: _changeRole,
                    onRemoveMember: _removeMember,
                    onSimulateScenario: _simulateEmergencyScenario,
                  ),
              ],
            ),
          ),
        ],
      ),
      endDrawer: _isAdmin
          ? TodayReportsSidebar(
              loadingReports: _loadingReports,
              reportsError: _reportsError,
              reports: _reports,
              respondingReportId: _respondingReportId,
              highlightedReportIds: _highlightedReportIds,
              onRefresh: _loadReports,
              onRespondToReport: _respondToReport,
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _selectDestination,
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.report_outlined),
            selectedIcon: Icon(Icons.report),
            label: 'Report',
          ),
          NavigationDestination(
            icon: _NavigationBadgeIcon(
              icon: Icons.crisis_alert_outlined,
              count: _unreadReportIds.length,
            ),
            selectedIcon: _NavigationBadgeIcon(
              icon: Icons.crisis_alert,
              count: _unreadReportIds.length,
            ),
            label: 'Alerts',
          ),
          NavigationDestination(
            icon: _NavigationBadgeIcon(
              icon: Icons.forum_outlined,
              count: _unreadConversationIds.length,
            ),
            selectedIcon: _NavigationBadgeIcon(
              icon: Icons.forum,
              count: _unreadConversationIds.length,
            ),
            label: 'Comms',
          ),
          if (_isAdmin)
            const NavigationDestination(
              icon: Icon(Icons.archive_outlined),
              selectedIcon: Icon(Icons.archive),
              label: 'Archive',
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

class _UrgentSummaryNotice extends StatelessWidget {
  const _UrgentSummaryNotice({
    required this.onDismiss,
    required this.onViewAlerts,
  });

  final VoidCallback onDismiss;
  final VoidCallback onViewAlerts;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Material(
      color: colorScheme.errorContainer,
      elevation: 8,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.priority_high,
                color: colorScheme.onErrorContainer,
                size: 34,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Attention',
                      style: textTheme.titleLarge?.copyWith(
                        color: colorScheme.onErrorContainer,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'New emergency information available.',
                      style: textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onErrorContainer,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 10),
                    FilledButton.icon(
                      onPressed: onViewAlerts,
                      icon: const Icon(Icons.crisis_alert),
                      label: const Text('View alerts'),
                      style: FilledButton.styleFrom(
                        backgroundColor: colorScheme.onErrorContainer,
                        foregroundColor: colorScheme.errorContainer,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Dismiss',
                onPressed: onDismiss,
                icon: Icon(
                  Icons.close,
                  color: colorScheme.onErrorContainer,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FullScreenGlobalAlertDialog extends StatelessWidget {
  const _FullScreenGlobalAlertDialog({required this.alert});

  final GlobalAlert alert;

  @override
  Widget build(BuildContext context) {
    final intruderAlert = alert.incidentType == 'intruder';
    final medicalAlert = alert.incidentType == 'medical';
    final backgroundColor = intruderAlert
        ? Colors.black
        : medicalAlert
            ? const Color(0xff1565c0)
            : const Color(0xffc62828);
    const foregroundColor = Colors.white;

    return Dialog.fullscreen(
      backgroundColor: backgroundColor,
      child: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                tooltip: 'Dismiss global alert',
                onPressed: () => Navigator.pop(context),
                icon: const Icon(
                  Icons.close,
                  color: foregroundColor,
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 760),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.campaign,
                          color: foregroundColor,
                          size: 54,
                        ),
                        const SizedBox(height: 18),
                        Text(
                          alert.headline.toUpperCase(),
                          style: Theme.of(context)
                              .textTheme
                              .displayMedium
                              ?.copyWith(
                                color: foregroundColor,
                                fontWeight: FontWeight.w900,
                              ),
                        ),
                        const SizedBox(height: 18),
                        MarkdownText(
                          alert.message,
                          style: const TextStyle(
                            color: foregroundColor,
                            fontSize: 20,
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Announced ${formatTimestamp(alert.createdAt)}',
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(
                                color: foregroundColor.withValues(alpha: 0.82),
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                        const SizedBox(height: 28),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.check),
                            label: const Text('Acknowledge'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavigationBadgeIcon extends StatelessWidget {
  const _NavigationBadgeIcon({required this.icon, required this.count});

  final IconData icon;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(icon),
        if (count > 0)
          Positioned(
            right: -10,
            top: -8,
            child: Container(
              constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
              padding: const EdgeInsets.symmetric(horizontal: 4),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.error,
                shape: BoxShape.circle,
              ),
              child: Text(
                count > 99 ? '99+' : '$count',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
