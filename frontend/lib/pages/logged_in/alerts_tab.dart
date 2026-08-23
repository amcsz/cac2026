import 'package:flutter/material.dart';

import '../../models/organization.dart';
import '../../utils/time_format.dart';
import '../../widgets/markdown_text.dart';

class AlertsTab extends StatelessWidget {
  const AlertsTab({
    required this.isAdmin,
    required this.globalAlert,
    required this.loadingAlertSummary,
    required this.alertSummaryError,
    required this.alertSummary,
    required this.verifyingIncident,
    required this.broadcastHeadlineController,
    required this.broadcastMessageController,
    required this.publishingGlobalAlert,
    required this.publishAdminsOnly,
    required this.clearingGlobalAlert,
    required this.todayReportCount,
    required this.onOpenReportsSidebar,
    required this.onVerifyIncident,
    required this.onPublishGlobalAlert,
    required this.onPublishAdminsOnlyChanged,
    required this.onClearGlobalAlert,
    super.key,
  });

  final bool isAdmin;
  final GlobalAlert? globalAlert;
  final bool loadingAlertSummary;
  final String? alertSummaryError;
  final AlertSummary? alertSummary;
  final bool verifyingIncident;
  final TextEditingController broadcastHeadlineController;
  final TextEditingController broadcastMessageController;
  final bool publishingGlobalAlert;
  final bool publishAdminsOnly;
  final bool clearingGlobalAlert;
  final int todayReportCount;
  final VoidCallback onOpenReportsSidebar;
  final VoidCallback onVerifyIncident;
  final VoidCallback onPublishGlobalAlert;
  final ValueChanged<bool> onPublishAdminsOnlyChanged;
  final VoidCallback onClearGlobalAlert;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Alerts',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 16),
              if (isAdmin && globalAlert != null)
                _ClearGlobalMessageButton(
                  clearingGlobalAlert: clearingGlobalAlert,
                  onClearGlobalAlert: onClearGlobalAlert,
                ),
              if (globalAlert != null && isAdmin) const SizedBox(height: 24),
              _EmergencySummarySection(
                isAdmin: isAdmin,
                loadingAlertSummary: loadingAlertSummary,
                alertSummaryError: alertSummaryError,
                alertSummary: alertSummary,
                verifyingIncident: verifyingIncident,
                todayReportCount: todayReportCount,
                onOpenReportsSidebar: onOpenReportsSidebar,
                onVerifyIncident: onVerifyIncident,
              ),
              if (isAdmin) ...[
                const SizedBox(height: 24),
                _RelayGlobalMessageSection(
                  broadcastHeadlineController: broadcastHeadlineController,
                  broadcastMessageController: broadcastMessageController,
                  publishingGlobalAlert: publishingGlobalAlert,
                  publishAdminsOnly: publishAdminsOnly,
                  onPublishGlobalAlert: onPublishGlobalAlert,
                  onPublishAdminsOnlyChanged: onPublishAdminsOnlyChanged,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ClearGlobalMessageButton extends StatelessWidget {
  const _ClearGlobalMessageButton({
    required this.clearingGlobalAlert,
    required this.onClearGlobalAlert,
  });

  final bool clearingGlobalAlert;
  final VoidCallback onClearGlobalAlert;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: OutlinedButton.icon(
        onPressed: clearingGlobalAlert ? null : onClearGlobalAlert,
        icon: clearingGlobalAlert
            ? const SizedBox.square(
                dimension: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.clear),
        label: Text(clearingGlobalAlert ? 'Clearing' : 'Clear global alert'),
      ),
    );
  }
}

class _EmergencySummarySection extends StatelessWidget {
  const _EmergencySummarySection({
    required this.isAdmin,
    required this.loadingAlertSummary,
    required this.alertSummaryError,
    required this.alertSummary,
    required this.verifyingIncident,
    required this.todayReportCount,
    required this.onOpenReportsSidebar,
    required this.onVerifyIncident,
  });

  final bool isAdmin;
  final bool loadingAlertSummary;
  final String? alertSummaryError;
  final AlertSummary? alertSummary;
  final bool verifyingIncident;
  final int todayReportCount;
  final VoidCallback onOpenReportsSidebar;
  final VoidCallback onVerifyIncident;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Emergency summary',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        if (loadingAlertSummary)
          const Center(child: CircularProgressIndicator())
        else if (alertSummaryError != null)
          Text(
            alertSummaryError!,
            style: TextStyle(
              color: Theme.of(context).colorScheme.error,
            ),
          )
        else if (alertSummary == null)
          const Text('No summary loaded.')
        else ...[
          Text(
            alertSummary!.headline,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          MarkdownText(alertSummary!.summary),
          const SizedBox(height: 12),
          Text(
            'Based on ${alertSummary!.reportCount} report(s) from today.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (isAdmin && alertSummary!.needsVerification) ...[
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: verifyingIncident ? null : onVerifyIncident,
              icon: verifyingIncident
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.verified_outlined),
              label: Text(
                verifyingIncident ? 'Verifying' : 'Verify incident',
              ),
            ),
          ],
          if (isAdmin) ...[
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onOpenReportsSidebar,
              icon: const Icon(Icons.article_outlined),
              label: Text('Report(s) today ($todayReportCount)'),
            ),
          ],
        ],
      ],
    );
  }
}

class _RelayGlobalMessageSection extends StatelessWidget {
  const _RelayGlobalMessageSection({
    required this.broadcastHeadlineController,
    required this.broadcastMessageController,
    required this.publishingGlobalAlert,
    required this.publishAdminsOnly,
    required this.onPublishGlobalAlert,
    required this.onPublishAdminsOnlyChanged,
  });

  final TextEditingController broadcastHeadlineController;
  final TextEditingController broadcastMessageController;
  final bool publishingGlobalAlert;
  final bool publishAdminsOnly;
  final VoidCallback onPublishGlobalAlert;
  final ValueChanged<bool> onPublishAdminsOnlyChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Review emergency message',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        TextField(
          controller: broadcastHeadlineController,
          decoration: const InputDecoration(
            labelText: 'Headline',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<bool>(
          initialValue: publishAdminsOnly,
          decoration: const InputDecoration(
            labelText: 'Audience',
            border: OutlineInputBorder(),
          ),
          items: const [
            DropdownMenuItem(value: false, child: Text('Everyone')),
            DropdownMenuItem(
              value: true,
              child: Text('Administrators only'),
            ),
          ],
          onChanged: publishingGlobalAlert
              ? null
              : (value) {
                  if (value != null) onPublishAdminsOnlyChanged(value);
                },
        ),
        const SizedBox(height: 12),
        TextField(
          controller: broadcastMessageController,
          minLines: 3,
          maxLines: 6,
          decoration: const InputDecoration(
            labelText: 'Message',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.icon(
            onPressed: publishingGlobalAlert ? null : onPublishGlobalAlert,
            icon: publishingGlobalAlert
                ? const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(Icons.campaign),
            label: Text(
              publishingGlobalAlert
                  ? 'Publishing'
                  : publishAdminsOnly
                      ? 'Publish to administrators'
                      : 'Publish to everyone',
            ),
          ),
        ),
      ],
    );
  }
}

class TodayReportsSidebar extends StatelessWidget {
  const TodayReportsSidebar({
    required this.loadingReports,
    required this.reportsError,
    required this.reports,
    required this.respondingReportId,
    required this.onRefresh,
    required this.onRespondToReport,
    super.key,
  });

  final bool loadingReports;
  final String? reportsError;
  final List<EmergencyReport> reports;
  final int? respondingReportId;
  final VoidCallback onRefresh;
  final ValueChanged<EmergencyReport> onRespondToReport;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;

    return Drawer(
      width: screenWidth,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Close reports',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Reports today',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Refresh reports',
                    onPressed: loadingReports ? null : onRefresh,
                    icon: const Icon(Icons.refresh),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            Expanded(
              child: _TodayReportsList(
                loadingReports: loadingReports,
                reportsError: reportsError,
                reports: reports,
                respondingReportId: respondingReportId,
                onRespondToReport: onRespondToReport,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TodayReportsList extends StatelessWidget {
  const _TodayReportsList({
    required this.loadingReports,
    required this.reportsError,
    required this.reports,
    required this.respondingReportId,
    required this.onRespondToReport,
  });

  final bool loadingReports;
  final String? reportsError;
  final List<EmergencyReport> reports;
  final int? respondingReportId;
  final ValueChanged<EmergencyReport> onRespondToReport;

  @override
  Widget build(BuildContext context) {
    if (loadingReports) {
      return const Center(child: CircularProgressIndicator());
    }

    if (reportsError != null) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          reportsError!,
          style: TextStyle(
            color: Theme.of(context).colorScheme.error,
          ),
        ),
      );
    }

    if (reports.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Text('No emergency reports yet.'),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: reports.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final report = reports[index];
        final responding = respondingReportId == report.id;
        final reportIcon = switch (report.emergencyType) {
          'medical' => Icons.local_hospital_rounded,
          'intruder' => Icons.security_rounded,
          _ => Icons.local_fire_department_rounded,
        };
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(reportIcon),
                  const SizedBox(width: 10),
                  Text(
                    "${report.emergencyTypeLabel} Alert",
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Details: ${report.details.isEmpty ? 'No additional details provided.' : report.details}\nSent ${formatTimestamp(report.createdAt)} by ${report.reportedByUsername}',
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: respondingReportId == null
                    ? () => onRespondToReport(report)
                    : null,
                icon: responding
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.forum_outlined),
                label: Text(responding ? 'Opening' : 'Respond'),
              ),
            ],
          ),
        );
      },
    );
  }
}
