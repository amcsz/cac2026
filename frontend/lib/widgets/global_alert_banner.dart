import 'package:flutter/material.dart';

import '../models/organization.dart';
import '../utils/time_format.dart';
import 'markdown_text.dart';

class GlobalAlertBanner extends StatefulWidget {
  const GlobalAlertBanner({required this.alert, super.key});

  final GlobalAlert alert;

  @override
  State<GlobalAlertBanner> createState() => _GlobalAlertBannerState();
}

class _GlobalAlertBannerState extends State<GlobalAlertBanner> {
  bool _expanded = false;

  @override
  void didUpdateWidget(GlobalAlertBanner oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.alert.id != widget.alert.id) {
      _expanded = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final alert = widget.alert;
    final intruderAlert = alert.incidentType == 'intruder';
    final medicalAlert = alert.incidentType == 'medical';
    final backgroundColor = intruderAlert
        ? Colors.black
        : medicalAlert
            ? const Color(0xff1565c0)
            : const Color(0xffc62828);
    const foregroundColor = Colors.white;

    return Material(
      color: backgroundColor,
      child: SafeArea(
        bottom: false,
        child: InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: foregroundColor.withValues(alpha: 0.35),
                  width: 2,
                ),
              ),
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 980),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.campaign,
                          color: foregroundColor,
                          size: 34,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            alert.headline.toUpperCase(),
                            maxLines: _expanded ? 3 : 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .displaySmall
                                ?.copyWith(
                                  color: foregroundColor,
                                  fontWeight: FontWeight.w900,
                                ),
                          ),
                        ),
                        Icon(
                          _expanded ? Icons.expand_less : Icons.expand_more,
                          color: foregroundColor,
                        ),
                      ],
                    ),
                    if (_expanded) ...[
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: MarkdownText(
                          alert.message,
                          style: const TextStyle(
                            color: foregroundColor,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Announced ${formatTimestamp(alert.createdAt)}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: foregroundColor.withValues(alpha: 0.82),
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
