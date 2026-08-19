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
    final colorScheme = Theme.of(context).colorScheme;
    final alert = widget.alert;

    return Material(
      color: colorScheme.errorContainer,
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
                  color: colorScheme.error.withValues(alpha: 0.35),
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
                        Icon(
                          Icons.campaign,
                          color: colorScheme.onErrorContainer,
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
                                  color: colorScheme.onErrorContainer,
                                  fontWeight: FontWeight.w900,
                                ),
                          ),
                        ),
                        Icon(
                          _expanded ? Icons.expand_less : Icons.expand_more,
                          color: colorScheme.onErrorContainer,
                        ),
                      ],
                    ),
                    AnimatedCrossFade(
                      firstChild: Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: MarkdownText(
                          alert.message,
                          style: TextStyle(
                            color: colorScheme.onErrorContainer,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      secondChild: Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: MarkdownText(
                          alert.message,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: colorScheme.onErrorContainer,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      crossFadeState: _expanded
                          ? CrossFadeState.showFirst
                          : CrossFadeState.showSecond,
                      duration: const Duration(milliseconds: 180),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Announced ${formatTimestamp(alert.createdAt)}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: colorScheme.onErrorContainer
                                .withValues(alpha: 0.82),
                            fontWeight: FontWeight.w600,
                          ),
                    ),
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
