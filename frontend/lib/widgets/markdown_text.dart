import 'package:flutter/material.dart';

class MarkdownText extends StatelessWidget {
  const MarkdownText(
    this.text, {
    this.style,
    this.maxLines,
    this.overflow,
    super.key,
  });

  final String text;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow? overflow;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        style: style ?? Theme.of(context).textTheme.bodyMedium,
        children: _spans(),
      ),
      maxLines: maxLines,
      overflow: overflow ?? TextOverflow.clip,
    );
  }

  List<TextSpan> _spans() {
    final spans = <TextSpan>[];
    var remaining = text;
    var bold = false;

    while (remaining.isNotEmpty) {
      final marker = remaining.indexOf('**');
      if (marker == -1) {
        spans.add(_span(remaining, bold));
        break;
      }

      if (marker > 0) {
        spans.add(_span(remaining.substring(0, marker), bold));
      }
      bold = !bold;
      remaining = remaining.substring(marker + 2);
    }

    return spans;
  }

  TextSpan _span(String value, bool bold) {
    return TextSpan(
      text: value,
      style: bold ? const TextStyle(fontWeight: FontWeight.w700) : null,
    );
  }
}
