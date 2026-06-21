import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/fts_theme.dart';

enum FtsStatus { success, danger, pending, info }

class _StatusPalette {
  const _StatusPalette(this.fg, this.bg);
  final Color fg;
  final Color bg;
}

_StatusPalette _paletteFor(FtsStatus status) {
  switch (status) {
    case FtsStatus.success:
      return const _StatusPalette(FtsColors.success, FtsColors.successSoft);
    case FtsStatus.danger:
      return const _StatusPalette(FtsColors.danger, FtsColors.dangerSoft);
    case FtsStatus.pending:
      return const _StatusPalette(FtsColors.warning, FtsColors.warningSoft);
    case FtsStatus.info:
      return const _StatusPalette(FtsColors.blue700, FtsColors.blue100);
  }
}

/// Petit point de couleur indiquant un état (`.fts-status-dot`),
/// avec pulsation optionnelle (`.is-pulse`).
class FtsStatusDot extends StatefulWidget {
  const FtsStatusDot({super.key, required this.status, this.pulse = false, this.size = 7});

  final FtsStatus status;
  final bool pulse;
  final double size;

  @override
  State<FtsStatusDot> createState() => _FtsStatusDotState();
}

class _FtsStatusDotState extends State<FtsStatusDot> with SingleTickerProviderStateMixin {
  AnimationController? _controller;

  @override
  void initState() {
    super.initState();
    if (widget.pulse) {
      _controller = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1400),
      )..repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = _paletteFor(widget.status).fg;
    final dot = Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );

    if (_controller == null) return dot;

    return FadeTransition(
      opacity: Tween<double>(begin: 1, end: 0.35).animate(
        CurvedAnimation(parent: _controller!, curve: Curves.easeInOut),
      ),
      child: dot,
    );
  }
}

/// Badge de statut texte + point (`.fts-badge`).
class FtsBadge extends StatelessWidget {
  const FtsBadge({super.key, required this.label, required this.status, this.pulse = false});

  final String label;
  final FtsStatus status;
  final bool pulse;

  @override
  Widget build(BuildContext context) {
    final palette = _paletteFor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: palette.bg,
        borderRadius: FtsRadius.smRadius,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FtsStatusDot(status: status, pulse: pulse, size: 6),
          const SizedBox(width: 6),
          Text(
            label.toUpperCase(),
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w700,
              fontSize: 10.5,
              letterSpacing: 0.4,
              color: palette.fg,
            ),
          ),
        ],
      ),
    );
  }
}
