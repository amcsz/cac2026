import 'package:flutter/material.dart';

import '../../models/organization.dart';
import '../../utils/time_format.dart';
import '../../widgets/markdown_text.dart';

class AlertsTab extends StatelessWidget {
  const AlertsTab({
    required this.isAdmin,
    required this.loadingGlobalAlert,
    required this.globalAlertError,
    required this.globalAlert,
    required this.loadingAlertSummary,
    required this.alertSummaryError,
    required this.alertSummary,
    required this.broadcastHeadlineController,
    required this.broadcastMessageController,
    required this.publishingGlobalAlert,
    required this.clearingGlobalAlert,
    required this.loadingReports,
    required this.reportsError,
    required this.reports,
    required this.onRefreshSummary,
    required this.onPublishGlobalAlert,
    required this.onClearGlobalAlert,
    super.key,
  });

  final bool isAdmin;
  final bool loadingGlobalAlert;
  final String? globalAlertError;
  final GlobalAlert? globalAlert;
  final bool loadingAlertSummary;
  final String? alertSummaryError;
  final AlertSummary? alertSummary;
  final TextEditingController broadcastHeadlineController;
  final TextEditingController broadcastMessageController;
  final bool publishingGlobalAlert;
  final bool clearingGlobalAlert;
  final bool loadingReports;
  final String? reportsError;
  final List<EmergencyReport> reports;
  final VoidCallback onRefreshSummary;
  final VoidCallback onPublishGlobalAlert;
  final VoidCallback onClearGlobalAlert;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
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
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Alerts',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                      ),
                      if (isAdmin)
                        IconButton(
                          tooltip: 'Refresh summary',
                          onPressed:
                              loadingAlertSummary ? null : onRefreshSummary,
                          icon: const Icon(Icons.refresh),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _GlobalMessageSection(
                    isAdmin: isAdmin,
                    loadingGlobalAlert: loadingGlobalAlert,
                    clearingGlobalAlert: clearingGlobalAlert,
                    globalAlertError: globalAlertError,
                    globalAlert: globalAlert,
                    onClearGlobalAlert: onClearGlobalAlert,
                  ),
                  if (isAdmin) ...[
                    const SizedBox(height: 24),
                    const Divider(),
                    const SizedBox(height: 24),
                    _EmergencySummarySection(
                      loadingAlertSummary: loadingAlertSummary,
                      alertSummaryError: alertSummaryError,
                      alertSummary: alertSummary,
                    ),
                    const SizedBox(height: 24),
                    _RelayGlobalMessageSection(
                      broadcastHeadlineController:
                          broadcastHeadlineController,
                      broadcastMessageController: broadcastMessageController,
                      publishingGlobalAlert: publishingGlobalAlert,
                      onPublishGlobalAlert: onPublishGlobalAlert,
                    ),
                    const SizedBox(height: 24),
                    const Divider(),
                    const SizedBox(height: 24),
                    _EmergencyReportsSection(
                      loadingReports: loadingReports,
                      reportsError: reportsError,
                      reports: reports,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GlobalMessageSection extends StatelessWidget {
  const _GlobalMessageSection({
    required this.isAdmin,
    required this.loadingGlobalAlert,
    required this.clearingGlobalAlert,
    required this.globalAlertError,
    required this.globalAlert,
    required this.onClearGlobalAlert,
  });

  final bool isAdmin;
  final bool loadingGlobalAlert;
  final bool clearingGlobalAlert;
  final String? globalAlertError;
  final GlobalAlert? globalAlert;
  final VoidCallback onClearGlobalAlert;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Global message',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        if (loadingGlobalAlert)
          const Center(child: CircularProgressIndicator())
        else if (globalAlertError != null)
          Text(
            globalAlertError!,
            style: TextStyle(
              color: Theme.of(context).colorScheme.error,
            ),
          )
        else if (globalAlert == null)
          const Text('No global message has been published.')
        else ...[
          Text(
            globalAlert!.headline,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          MarkdownText(globalAlert!.message),
          const SizedBox(height: 8),
          Text(
            'Published ${formatTimestamp(globalAlert!.createdAt)} by ${globalAlert!.createdByUsername.isEmpty ? 'an administrator' : globalAlert!.createdByUsername}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (isAdmin) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                onPressed: clearingGlobalAlert ? null : onClearGlobalAlert,
                icon: clearingGlobalAlert
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.clear),
                label: Text(clearingGlobalAlert ? 'Clearing' : 'Clear message'),
              ),
            ),
          ],
        ],
      ],
    );
  }
}

class _EmergencySummarySection extends StatelessWidget {
  const _EmergencySummarySection({
    required this.loadingAlertSummary,
    required this.alertSummaryError,
    required this.alertSummary,
  });

  final bool loadingAlertSummary;
  final String? alertSummaryError;
  final AlertSummary? alertSummary;

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
            'Based on ${alertSummary!.reportCount} reports from the last ${alertSummary!.windowHours} hours.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
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

class _EmergencyReportsSection extends StatelessWidget {
  const _EmergencyReportsSection({
    required this.loadingReports,
    required this.reportsError,
    required this.reports,
  });

  final bool loadingReports;
  final String? reportsError;
  final List<EmergencyReport> reports;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Reports today',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Text(
          'Reports submitted today by organization members.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 16),
        if (loadingReports)
          const Center(child: CircularProgressIndicator())
        else if (reportsError != null)
          Text(
            reportsError!,
            style: TextStyle(
              color: Theme.of(context).colorScheme.error,
            ),
          )
        else if (reports.isEmpty)
          const Text('No emergency reports yet.')
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: reports.length,
            separatorBuilder: (_, __) => const Divider(),
            itemBuilder: (context, index) {
              final report = reports[index];
              return ListTile(
                leading: const Icon(Icons.warning_amber_rounded),
                title: Text(report.emergencyTypeLabel),
                subtitle: Text(
                  'Sent ${formatTimestamp(report.createdAt)} by ${report.reportedByUsername}\n${report.location}\n${report.details.isEmpty ? 'No additional details provided.' : report.details}',
                ),
              );
            },
          ),
      ],
    );
  }
}
