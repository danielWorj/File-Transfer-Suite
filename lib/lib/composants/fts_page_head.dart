import 'package:flutter/material.dart';
import '../theme/fts_theme.dart';

/// En-tête de page standard (`.fts-eyebrow` + `.fts-mtitle` + `.fts-msubtitle`).
class FtsPageHead extends StatelessWidget {
  const FtsPageHead({
    super.key,
    required this.eyebrow,
    required this.title,
    this.subtitle,
  });

  final String eyebrow;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 14, height: 1.5, color: FtsColors.blue500),
              const SizedBox(width: 6),
              Text(eyebrow.toUpperCase(), style: FtsText.eyebrow),
            ],
          ),
          const SizedBox(height: 8),
          Text(title, style: FtsText.title),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(subtitle!, style: FtsText.subtitle),
          ],
        ],
      ),
    );
  }
}
