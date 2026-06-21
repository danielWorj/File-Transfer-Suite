import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/fts_theme.dart';

enum FtsToastType { info, success, warning, error }

class _ToastPalette {
  const _ToastPalette(this.bg, this.border, this.accent, this.icon);
  final Color bg;
  final Color border;
  final Color accent;
  final IconData icon;
}

_ToastPalette _paletteFor(FtsToastType type) {
  switch (type) {
    case FtsToastType.info:
      return const _ToastPalette(
        Color(0xFFF4F7FD), Color(0xFFD2DEF5), FtsColors.blue500, Icons.info_outline,
      );
    case FtsToastType.success:
      return const _ToastPalette(
        FtsColors.successSoft, Color(0xFFCBE7DA), FtsColors.success, Icons.check_circle_outline,
      );
    case FtsToastType.warning:
      return const _ToastPalette(
        FtsColors.warningSoft, Color(0xFFF1E2C3), FtsColors.warning, Icons.warning_amber_rounded,
      );
    case FtsToastType.error:
      return const _ToastPalette(
        FtsColors.dangerSoft, Color(0xFFF5D2D2), FtsColors.danger, Icons.error_outline,
      );
  }
}

class _ToastData {
  _ToastData({required this.id, required this.message, required this.type});
  final int id;
  final String message;
  final FtsToastType type;
}

/// Gestionnaire global de toasts, équivalent de `.fts-toast-stack`.
///
/// Usage :
/// ```dart
/// final toastKey = GlobalKey<FtsToastHostState>();
/// // en haut de l'arbre, au-dessus du Navigator :
/// FtsToastHost(key: toastKey, child: MaterialApp(...));
/// // n'importe où dans le code :
/// FtsToastHost.of(context)?.show('Transfert terminé', type: FtsToastType.success);
/// ```
class FtsToastHost extends StatefulWidget {
  const FtsToastHost({super.key, required this.child});

  final Widget child;

  static FtsToastHostState? of(BuildContext context) {
    return context.findAncestorStateOfType<FtsToastHostState>();
  }

  @override
  State<FtsToastHost> createState() => FtsToastHostState();
}

class FtsToastHostState extends State<FtsToastHost> {
  final List<_ToastData> _toasts = [];
  int _nextId = 0;

  void show(
    String message, {
    FtsToastType type = FtsToastType.info,
    Duration duration = const Duration(seconds: 3),
  }) {
    final id = _nextId++;
    setState(() => _toasts.add(_ToastData(id: id, message: message, type: type)));
    Timer(duration, () => _dismiss(id));
  }

  void _dismiss(int id) {
    if (!mounted) return;
    setState(() => _toasts.removeWhere((t) => t.id == id));
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        Positioned(
          top: MediaQuery.of(context).padding.top + 12,
          right: 16,
          left: 16,
          child: IgnorePointer(
            ignoring: _toasts.isEmpty,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: _toasts
                  .map((t) => _FtsToastTile(
                        key: ValueKey(t.id),
                        data: t,
                        onDismiss: () => _dismiss(t.id),
                      ))
                  .toList(growable: false),
            ),
          ),
        ),
      ],
    );
  }
}

class _FtsToastTile extends StatelessWidget {
  const _FtsToastTile({super.key, required this.data, required this.onDismiss});

  final _ToastData data;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final palette = _paletteFor(data.type);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Dismissible(
        key: ValueKey('dismiss-${data.id}'),
        direction: DismissDirection.horizontal,
        onDismissed: (_) => onDismiss(),
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: FtsRadius.cardRadius,
              border: Border.all(color: palette.border),
              boxShadow: [
                BoxShadow(
                  color: FtsColors.blue900.withValues(alpha: 0.08),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 3,
                  height: 18,
                  margin: const EdgeInsets.only(right: 10, top: 1),
                  decoration: BoxDecoration(
                    color: palette.accent,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Icon(palette.icon, size: 18, color: palette.accent),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    data.message,
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w500,
                      fontSize: 13,
                      color: FtsColors.ink,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: onDismiss,
                  child: const Icon(Icons.close, size: 15, color: FtsColors.muted),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
