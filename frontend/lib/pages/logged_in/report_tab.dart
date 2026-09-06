import 'package:flutter/material.dart';

class ReportTab extends StatelessWidget {
  const ReportTab({
    required this.showReportForm,
    required this.reportStep,
    required this.reportType,
    required this.submittingReport,
    required this.reportError,
    required this.reportSuccess,
    required this.detailsController,
    required this.onStartReport,
    required this.onReportTypeChanged,
    required this.onCancel,
    required this.onBack,
    required this.onNext,
    required this.onSubmit,
    super.key,
  });

  final bool showReportForm;
  final int reportStep;
  final String? reportType;
  final bool submittingReport;
  final String? reportError;
  final String? reportSuccess;
  final TextEditingController detailsController;
  final VoidCallback onStartReport;
  final ValueChanged<String> onReportTypeChanged;
  final VoidCallback onCancel;
  final VoidCallback onBack;
  final VoidCallback onNext;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Report an Incident',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      fontSize: 34,
                    ),
              ),
              const SizedBox(height: 12),
              Text(
                'Click the button below to send a report to your organization\'s administrators',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontSize: 19,
                      height: 1.5,
                    ),
              ),
              const SizedBox(height: 28),
              if (reportSuccess != null)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green),
                  ),
                  child: Text(
                    reportSuccess!,
                    style: const TextStyle(
                      color: Colors.green,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              if (reportError != null)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red),
                  ),
                  child: Text(
                    reportError!,
                    style: const TextStyle(
                      color: Colors.red,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              if (!showReportForm)
                SizedBox(
                  width: double.infinity,
                  height: 90,
                  child: FilledButton.icon(
                    onPressed: onStartReport,
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.red.shade700,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    icon: const Icon(
                      Icons.report_rounded,
                      size: 38,
                    ),
                    label: const Text(
                      'REPORT AN INCIDENT',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                )
              else ...[
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Step ${reportStep + 1} of 2',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: submittingReport ? null : onCancel,
                      icon: const Icon(Icons.close),
                      label: const Text(
                        'Cancel',
                        style: TextStyle(fontSize: 17),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                if (reportStep == 0) ...[
                  const Text(
                    'What type of emergency is this?',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _EmergencyButton(
                    title: 'Fire',
                    subtitle: 'Fire, smoke, or explosion',
                    icon: Icons.local_fire_department_rounded,
                    color: Colors.red,
                    onTap: () {
                      onReportTypeChanged('fire');
                      onNext();
                    },
                  ),
                  const SizedBox(height: 14),
                  _EmergencyButton(
                    title: 'Medical',
                    subtitle: 'Injury or medical emergency',
                    icon: Icons.local_hospital_rounded,
                    color: Colors.blue,
                    onTap: () {
                      onReportTypeChanged('medical');
                      onNext();
                    },
                  ),
                  const SizedBox(height: 14),
                  _EmergencyButton(
                    title: 'Intruder',
                    subtitle: 'Suspicious person or security threat',
                    icon: Icons.security_rounded,
                    color: Colors.black,
                    onTap: () {
                      onReportTypeChanged('intruder');
                      onNext();
                    },
                  ),
                ] else ...[
                  Text(
                    switch (reportType) {
                      'fire' =>
                        'Tell us briefly what happened, where it happened, and your evacuation route if you reached safety.',
                      'medical' =>
                        'Describe how many people are hurt, their current condition, what happened, and any help they need...',
                      'intruder' =>
                        'Share where you think the intruder is, whether anyone is hurt, what they look like, and any other identifying details...',
                      _ =>
                        'Add anything important you know, including what happened, who may be affected, and any immediate hazards...',
                    },
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: detailsController,
                    maxLines: 5,
                    style: const TextStyle(fontSize: 19),
                    decoration: InputDecoration(
                      labelText: 'Details (optional)',
                      labelStyle: const TextStyle(fontSize: 18),
                      hintText: "Write here",
                      hintStyle: const TextStyle(fontSize: 17),
                      alignLabelWithHint: true,
                      contentPadding: const EdgeInsets.all(20),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 30),
                Row(
                  children: [
                    if (reportStep > 0)
                      SizedBox(
                        height: 56,
                        child: OutlinedButton.icon(
                          onPressed: submittingReport ? null : onBack,
                          icon: const Icon(Icons.arrow_back_rounded),
                          label: const Text(
                            'Back',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                            ),
                          ),
                        ),
                      ),
                    const Spacer(),
                    if (reportStep == 1)
                      SizedBox(
                        height: 60,
                        child: FilledButton.icon(
                          onPressed: submittingReport ? null : onSubmit,
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.red.shade700,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 28,
                            ),
                          ),
                          icon: submittingReport
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(
                                  Icons.send_rounded,
                                  size: 26,
                                ),
                          label: Text(
                            submittingReport
                                ? 'Submitting...'
                                : 'Submit Report',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _EmergencyButton extends StatelessWidget {
  const _EmergencyButton({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 20,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: color,
              width: 2,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 62,
                height: 62,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(
                  icon,
                  color: Colors.white,
                  size: 36,
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: color,
                        fontSize: 23,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
