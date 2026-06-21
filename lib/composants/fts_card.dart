import 'package:flutter/material.dart';
import '../theme/fts_theme.dart';

/// Carte de contenu réutilisable, équivalent de `.fts-card` /
/// `.fts-mcard` (header optionnel, body, footer optionnel).
class FtsCard extends StatelessWidget {
  const FtsCard({
    super.key,
    this.title,
    this.meta,
    this.headerTrailing,
    this.footer,
    required this.child,
    this.padBody = true,
    this.margin,
  });

  final String? title;
  final String? meta;
  final Widget? headerTrailing;
  final Widget? footer;
  final Widget child;
  final bool padBody;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin ?? const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: FtsColors.surface,
        borderRadius: FtsRadius.cardRadius,
        border: Border.all(color: FtsColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: FtsColors.border)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(title!, style: FtsText.cardTitle),
                  ),
                  if (meta != null)
                    Text(meta!, style: FtsText.mono)
                  else if (headerTrailing != null)
                    headerTrailing!,
                ],
              ),
            ),
          Padding(
            padding: padBody ? const EdgeInsets.all(16) : EdgeInsets.zero,
            child: child,
          ),
          if (footer != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: FtsColors.border)),
              ),
              child: footer!,
            ),
        ],
      ),
    );
  }
}
