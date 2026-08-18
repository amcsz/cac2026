import 'package:flutter/material.dart';

class ReportTab extends StatelessWidget {
  const ReportTab({
    required this.reportStep,
    required this.reportType,
    required this.submittingReport,
    required this.reportError,
    required this.reportSuccess,
    required this.locationController,
    required this.detailsController,
    required this.onReportTypeChanged,
    required this.onBack,
    required this.onNext,
    required this.onSubmit,
    super.key,
  });

  final int reportStep;
  final String reportType;
  final bool submittingReport;
  final String? reportError;
  final String? reportSuccess;
  final TextEditingController locationController;
  final TextEditingController detailsController;
  final ValueChanged<String> onReportTypeChanged;
  final VoidCallback onBack;
  final VoidCallback onNext;
  final VoidCallback onSubmit;

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
                  Text(
                    'Report an incident',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 24),
                  if (reportSuccess != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        reportSuccess!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                  if (reportError != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        reportError!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  Text('Step ${reportStep + 1} of 3'),
                  const SizedBox(height: 12),
                  if (reportStep == 0) ...[
                    const Text('What type of emergency is this?'),
                    const SizedBox(height: 12),
                    RadioGroup<String>(
                      groupValue: reportType,
                      onChanged: (value) =>
                          onReportTypeChanged(value ?? 'fire'),
                      child: const Column(
                        children: [
                          RadioListTile<String>(
                            title: Text('Fire'),
                            value: 'fire',
                          ),
                          RadioListTile<String>(
                            title: Text('Medical'),
                            value: 'medical',
                          ),
                          RadioListTile<String>(
                            title: Text('Intruder'),
                            value: 'intruder',
                          ),
                        ],
                      ),
                    ),
                  ] else if (reportStep == 1) ...[
                    const Text('Where are you right now?'),
                    const SizedBox(height: 12),
                    TextField(
                      controller: locationController,
                      decoration: const InputDecoration(
                        labelText: 'Location',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ] else ...[
                    const Text('Any extra details?'),
                    const SizedBox(height: 12),
                    TextField(
                      controller: detailsController,
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
                      if (reportStep > 0)
                        OutlinedButton(
                          onPressed: onBack,
                          child: const Text('Back'),
                        ),
                      const Spacer(),
                      if (reportStep < 2)
                        ElevatedButton(
                          onPressed: onNext,
                          child: const Text('Next'),
                        )
                      else
                        ElevatedButton(
                          onPressed: submittingReport ? null : onSubmit,
                          child: submittingReport
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
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
    );
  }
}
