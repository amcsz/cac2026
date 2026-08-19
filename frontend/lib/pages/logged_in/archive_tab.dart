import 'package:flutter/material.dart';

import '../../models/organization.dart';
import '../../utils/time_format.dart';

class ArchiveTab extends StatelessWidget {
  const ArchiveTab({
    required this.loadingDays,
    required this.daysError,
    required this.days,
    required this.daysPage,
    required this.daysTotalPages,
    required this.daysHasNext,
    required this.daysHasPrevious,
    required this.selectedDate,
    required this.loadingReports,
    required this.reportsError,
    required this.events,
    required this.eventsPage,
    required this.eventsTotalPages,
    required this.eventsHasNext,
    required this.eventsHasPrevious,
    required this.onRefreshDays,
    required this.onSelectDate,
    required this.onBackToDays,
    required this.onDaysPageChanged,
    required this.onEventsPageChanged,
    super.key,
  });

  final bool loadingDays;
  final String? daysError;
  final List<ReportArchiveDay> days;
  final int daysPage;
  final int daysTotalPages;
  final bool daysHasNext;
  final bool daysHasPrevious;
  final String? selectedDate;
  final bool loadingReports;
  final String? reportsError;
  final List<ArchiveEvent> events;
  final int eventsPage;
  final int eventsTotalPages;
  final bool eventsHasNext;
  final bool eventsHasPrevious;
  final VoidCallback onRefreshDays;
  final ValueChanged<String> onSelectDate;
  final VoidCallback onBackToDays;
  final ValueChanged<int> onDaysPageChanged;
  final ValueChanged<int> onEventsPageChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            transitionBuilder: (child, animation) {
              final offsetAnimation = Tween<Offset>(
                begin: const Offset(1, 0),
                end: Offset.zero,
              ).animate(
                CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
              );

              return SlideTransition(
                position: offsetAnimation,
                child: FadeTransition(opacity: animation, child: child),
              );
            },
            child: selectedDate == null
                ? _ArchiveDaysView(
                    key: const ValueKey('archive-days'),
                    loadingDays: loadingDays,
                    daysError: daysError,
                    days: days,
                    daysPage: daysPage,
                    daysTotalPages: daysTotalPages,
                    daysHasNext: daysHasNext,
                    daysHasPrevious: daysHasPrevious,
                    onRefreshDays: onRefreshDays,
                    onSelectDate: onSelectDate,
                    onDaysPageChanged: onDaysPageChanged,
                  )
                : _ArchiveReportsView(
                    key: ValueKey('archive-reports-$selectedDate'),
                    selectedDate: selectedDate!,
                    loadingReports: loadingReports,
                    reportsError: reportsError,
                    events: events,
                    eventsPage: eventsPage,
                    eventsTotalPages: eventsTotalPages,
                    eventsHasNext: eventsHasNext,
                    eventsHasPrevious: eventsHasPrevious,
                    onBackToDays: onBackToDays,
                    onEventsPageChanged: onEventsPageChanged,
                  ),
          ),
        ),
      ),
    );
  }
}

class _ArchiveDaysView extends StatelessWidget {
  const _ArchiveDaysView({
    super.key,
    required this.loadingDays,
    required this.daysError,
    required this.days,
    required this.daysPage,
    required this.daysTotalPages,
    required this.daysHasNext,
    required this.daysHasPrevious,
    required this.onRefreshDays,
    required this.onSelectDate,
    required this.onDaysPageChanged,
  });

  final bool loadingDays;
  final String? daysError;
  final List<ReportArchiveDay> days;
  final int daysPage;
  final int daysTotalPages;
  final bool daysHasNext;
  final bool daysHasPrevious;
  final VoidCallback onRefreshDays;
  final ValueChanged<String> onSelectDate;
  final ValueChanged<int> onDaysPageChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Archive',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
            IconButton(
              tooltip: 'Refresh archive',
              onPressed: loadingDays ? null : onRefreshDays,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Past report days. Today stays on the Alerts tab.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 16),
        if (loadingDays)
          const Center(child: CircularProgressIndicator())
        else if (daysError != null)
          Text(
            daysError!,
            style: TextStyle(
              color: Theme.of(context).colorScheme.error,
            ),
          )
        else if (days.isEmpty)
          const Text('No archived report days yet.')
        else ...[
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: days.length,
            separatorBuilder: (_, __) => const Divider(),
            itemBuilder: (context, index) {
              final day = days[index];

              return ListTile(
                leading: const Icon(Icons.calendar_month),
                title: Text(formatDate(day.date)),
                subtitle: Text(
                  '${day.reportCount} report${day.reportCount == 1 ? '' : 's'}; ${day.alertCount} global alert${day.alertCount == 1 ? '' : 's'}',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => onSelectDate(day.date),
              );
            },
          ),
          const SizedBox(height: 12),
          _Pager(
            page: daysPage,
            totalPages: daysTotalPages,
            hasNext: daysHasNext,
            hasPrevious: daysHasPrevious,
            onPageChanged: onDaysPageChanged,
          ),
        ],
      ],
    );
  }
}

class _ArchiveReportsView extends StatelessWidget {
  const _ArchiveReportsView({
    super.key,
    required this.selectedDate,
    required this.loadingReports,
    required this.reportsError,
    required this.events,
    required this.eventsPage,
    required this.eventsTotalPages,
    required this.eventsHasNext,
    required this.eventsHasPrevious,
    required this.onBackToDays,
    required this.onEventsPageChanged,
  });

  final String selectedDate;
  final bool loadingReports;
  final String? reportsError;
  final List<ArchiveEvent> events;
  final int eventsPage;
  final int eventsTotalPages;
  final bool eventsHasNext;
  final bool eventsHasPrevious;
  final VoidCallback onBackToDays;
  final ValueChanged<int> onEventsPageChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            IconButton(
              tooltip: 'Back to archive days',
              onPressed: onBackToDays,
              icon: const Icon(Icons.arrow_back),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                formatDate(selectedDate),
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
          ],
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
        else if (events.isEmpty)
          const Text('No archive events found for this day.')
        else ...[
          _EventList(events: events),
          const SizedBox(height: 12),
          _Pager(
            page: eventsPage,
            totalPages: eventsTotalPages,
            hasNext: eventsHasNext,
            hasPrevious: eventsHasPrevious,
            onPageChanged: onEventsPageChanged,
          ),
        ],
      ],
    );
  }
}

class _EventList extends StatelessWidget {
  const _EventList({required this.events});

  final List<ArchiveEvent> events;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: events.length,
      separatorBuilder: (_, __) => const Divider(),
      itemBuilder: (context, index) {
        final event = events[index];
        final report = event.report;

        if (report != null) {
          return ListTile(
            leading: const Icon(Icons.warning_amber_rounded),
            title: Text(report.emergencyTypeLabel),
            subtitle: Text(
              'Report sent ${formatTimestamp(report.createdAt)} by ${report.reportedByUsername}\n${report.location}\n${report.details.isEmpty ? 'No additional details provided.' : report.details}',
            ),
          );
        }

        final alert = event.globalAlert;

        return ListTile(
          leading: const Icon(Icons.campaign),
          title: Text(alert?.headline ?? 'Global alert'),
          subtitle: Text(
            'Global alert sent ${formatTimestamp(alert?.createdAt ?? event.createdAt)} by ${alert?.createdByUsername.isEmpty ?? true ? 'an administrator' : alert!.createdByUsername}\n${alert?.message ?? ''}',
          ),
        );
      },
    );
  }
}

class _Pager extends StatelessWidget {
  const _Pager({
    required this.page,
    required this.totalPages,
    required this.hasNext,
    required this.hasPrevious,
    required this.onPageChanged,
  });

  final int page;
  final int totalPages;
  final bool hasNext;
  final bool hasPrevious;
  final ValueChanged<int> onPageChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        IconButton(
          tooltip: 'Previous page',
          onPressed: hasPrevious ? () => onPageChanged(page - 1) : null,
          icon: const Icon(Icons.chevron_left),
        ),
        Text('Page $page of $totalPages'),
        IconButton(
          tooltip: 'Next page',
          onPressed: hasNext ? () => onPageChanged(page + 1) : null,
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }
}
