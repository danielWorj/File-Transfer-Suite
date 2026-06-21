import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/fts_theme.dart';
import 'fts_status.dart';

/// Barre supérieure commune à tous les écrans (`.fts-mtopbar`).
class FtsTopbar extends StatelessWidget implements PreferredSizeWidget {
  const FtsTopbar({
    super.key,
    this.connected = true,
  });

  final bool connected;

  @override
  Size get preferredSize => const Size.fromHeight(60);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: preferredSize.height,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        color: FtsColors.surface,
        border: Border(bottom: BorderSide(color: FtsColors.border)),
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: FtsColors.blue700,
              borderRadius: FtsRadius.smRadius,
            ),
            child: const Icon(Icons.ios_share_rounded, size: 15, color: Colors.white),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'FTS',
                style: GoogleFonts.sora(
                  fontWeight: FontWeight.w600,
                  fontSize: 14.5,
                  color: FtsColors.blue900,
                  height: 1.1,
                ),
              ),
              Text(
                'File Transfer Suite',
                style: GoogleFonts.ibmPlexMono(
                  fontSize: 9.5,
                  color: FtsColors.muted,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
          const Spacer(),
          FtsStatusDot(
            status: connected ? FtsStatus.success : FtsStatus.danger,
            pulse: connected,
          ),
          const SizedBox(width: 6),
          Text(
            connected ? 'Connecté' : 'Hors ligne',
            style: GoogleFonts.ibmPlexMono(
              fontSize: 11,
              color: FtsColors.muted,
            ),
          ),
        ],
      ),
    );
  }
}
