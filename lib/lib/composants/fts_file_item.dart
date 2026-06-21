import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/fts_theme.dart';

/// Ligne de fichier réutilisable (`.fts-file-item`), utilisée dans
/// la liste de sélection (Envoi) et l'historique des transferts.
class FtsFileItem extends StatelessWidget {
  const FtsFileItem({
    super.key,
    required this.name,
    required this.meta,
    this.icon = Icons.insert_drive_file_outlined,
    this.onRemove,
    this.trailing,
  });

  final String name;
  final String meta;
  final IconData icon;
  final VoidCallback? onRemove;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: FtsColors.border)),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: FtsColors.blue100,
              borderRadius: FtsRadius.smRadius,
            ),
            child: Icon(icon, size: 15, color: FtsColors.blue700),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w500,
                    fontSize: 13.5,
                    color: FtsColors.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(meta, style: FtsText.mono.copyWith(fontSize: 11.5)),
              ],
            ),
          ),
          if (trailing != null) trailing!,
          if (onRemove != null)
            InkWell(
              onTap: onRemove,
              borderRadius: FtsRadius.smRadius,
              child: const Padding(
                padding: EdgeInsets.all(6),
                child: Icon(Icons.close_rounded, size: 16, color: FtsColors.muted),
              ),
            ),
        ],
      ),
    );
  }
}
