import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/fts_theme.dart';

enum FtsButtonVariant { primary, outline, ghost }

/// Bouton réutilisable reprenant `.fts-btn`, `.fts-btn-primary`,
/// `.fts-btn-outline` et `.fts-btn-ghost` du design system web.
class FtsButton extends StatelessWidget {
  const FtsButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.variant = FtsButtonVariant.primary,
    this.expand = false,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final FtsButtonVariant variant;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null;

    Color bg;
    Color fg;
    Color borderColor;

    switch (variant) {
      case FtsButtonVariant.primary:
        bg = FtsColors.blue700;
        fg = Colors.white;
        borderColor = FtsColors.blue700;
        break;
      case FtsButtonVariant.outline:
        bg = FtsColors.surface;
        fg = FtsColors.ink;
        borderColor = FtsColors.borderStrong;
        break;
      case FtsButtonVariant.ghost:
        bg = Colors.transparent;
        fg = FtsColors.muted;
        borderColor = Colors.transparent;
        break;
    }

    final child = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 16, color: disabled ? fg.withValues(alpha: 0.5) : fg),
          const SizedBox(width: 8),
        ],
        Text(
          label,
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            fontSize: 13.5,
            color: disabled ? fg.withValues(alpha: 0.5) : fg,
          ),
        ),
      ],
    );

    return Opacity(
      opacity: disabled ? 0.5 : 1,
      child: Material(
        color: bg,
        borderRadius: FtsRadius.smRadius,
        child: InkWell(
          borderRadius: FtsRadius.smRadius,
          onTap: onPressed,
          child: Container(
            width: expand ? double.infinity : null,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
            decoration: BoxDecoration(
              borderRadius: FtsRadius.smRadius,
              border: Border.all(color: borderColor),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
