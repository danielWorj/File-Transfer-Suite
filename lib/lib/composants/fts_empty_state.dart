import 'package:flutter/material.dart';
import '../theme/fts_theme.dart';

/// État vide réutilisable (`.fts-empty` / `.fts-mempty`).
class FtsEmptyState extends StatelessWidget {
  const FtsEmptyState({
    super.key,
    required this.message,
    this.subMessage,
    this.icon = Icons.folder_open_outlined,
    this.compact = false,
  });

  final String message;
  final String? subMessage;
  final IconData icon;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: compact ? 24 : 36, horizontal: 16),
      child: Column(
        children: [
          Icon(icon, size: 26, color: FtsColors.borderStrong),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13.5, color: FtsColors.muted),
          ),
          if (subMessage != null) ...[
            const SizedBox(height: 3),
            Text(
              subMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11.5, color: FtsColors.borderStrong),
            ),
          ],
        ],
      ),
    );
  }
}
