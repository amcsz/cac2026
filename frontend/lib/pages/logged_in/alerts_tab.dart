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
    required this.broadcastHeadlineController,
    required this.broadcastMessageController,
    required this.publishingGlobalAlert,
    required this.clearingGlobalAlert,
    required this.todayReportCount,
    required this.onOpenReportsSidebar,
    required this.onPublishGlobalAlert,
    required this.onClearGlobalAlert,
    super.key,
  });

  final bool isAdmin;
  final GlobalAlert? globalAlert;
  final bool loadingAlertSummary;
  final String? alertSummaryError;
  final AlertSummary? alertSummary;
  final TextEditingController broadcastHeadlineController;
  final TextEditingController broadcastMessageController;
  final bool publishingGlobalAlert;
  final bool clearingGlobalAlert;
  final int todayReportCount;
  final VoidCallback onOpenReportsSidebar;
  final VoidCallback onPublishGlobalAlert;
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
                todayReportCount: todayReportCount,
                onOpenReportsSidebar: onOpenReportsSidebar,
              ),
              if (isAdmin) ...[
                const SizedBox(height: 24),
                _RelayGlobalMessageSection(
                  broadcastHeadlineController: broadcastHeadlineController,
                  broadcastMessageController: broadcastMessageController,
                  publishingGlobalAlert: publishingGlobalAlert,
                  onPublishGlobalAlert: onPublishGlobalAlert,
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
      alignment: Alignment.centerRight,
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
    required this.todayReportCount,
    required this.onOpenReportsSidebar,
  });

  final bool isAdmin;
  final bool loadingAlertSummary;
  final String? alertSummaryError;
  final AlertSummary? alertSummary;
  final int todayReportCount;
  final VoidCallback onOpenReportsSidebar;

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
            'Based on ${alertSummary!.reportCount} reports from today.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (isAdmin) ...[
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onOpenReportsSidebar,
              icon: const Icon(Icons.article_outlined),
              label: Text('Reports today ($todayReportCount)'),
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
    required this.onPublishGlobalAlert,
  });

  final TextEditingController broadcastHeadlineController;
  final TextEditingController broadcastMessageController;
  final bool publishingGlobalAlert;
  final VoidCallback onPublishGlobalAlert;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Relay global message',
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
              publishingGlobalAlert ? 'Publishing' : 'Publish to everyone',
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
      width: screenWidth < 520 ? screenWidth * 0.9 : 420,
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
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                'Reports submitted today by organization members.',
                style: Theme.of(context).textTheme.bodyMedium,
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
        return ListTile(
          leading: const Icon(Icons.warning_amber_rounded),
          title: Text(report.emergencyTypeLabel),
          subtitle: Text(
            'Sent ${formatTimestamp(report.createdAt)} by ${report.reportedByUsername}\n${report.location}\n${report.details.isEmpty ? 'No additional details provided.' : report.details}',
          ),
          isThreeLine: true,
          trailing: FilledButton.icon(
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
        );
      },
    );
  }
}
