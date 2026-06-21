import 'package:flutter/material.dart';
import '../theme/fts_theme.dart';

/// Onglets disponibles dans la barre de navigation basse.
enum FtsNavTab { accueil, envoi, reception, historique }

/// Barre de navigation inférieure avec bouton flottant central
/// (`.fts-mbottomnav` + `.fts-mfab`) menant à l'écran de scan QR.
class FtsBottomNav extends StatelessWidget {
  const FtsBottomNav({
    super.key,
    required this.current,
    required this.onTabSelected,
    required this.onScanTap,
  });

  final FtsNavTab current;
  final ValueChanged<FtsNavTab> onTabSelected;
  final VoidCallback onScanTap;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(6, 6, 6, 6 + bottomInset),
      decoration: const BoxDecoration(
        color: FtsColors.surface,
        border: Border(top: BorderSide(color: FtsColors.border)),
      ),
      child: SizedBox(
        height: 52,
        child: Row(
          children: [
            _NavItem(
              icon: Icons.home_rounded,
              label: 'Accueil',
              active: current == FtsNavTab.accueil,
              onTap: () => onTabSelected(FtsNavTab.accueil),
            ),
            _NavItem(
              icon: Icons.send_rounded,
              label: 'Envoi',
              active: current == FtsNavTab.envoi,
              onTap: () => onTabSelected(FtsNavTab.envoi),
            ),
            _FabSlot(onTap: onScanTap),
            _NavItem(
              icon: Icons.inbox_rounded,
              label: 'Réception',
              active: current == FtsNavTab.reception,
              onTap: () => onTabSelected(FtsNavTab.reception),
            ),
            _NavItem(
              icon: Icons.history_rounded,
              label: 'Historique',
              active: current == FtsNavTab.historique,
              onTap: () => onTabSelected(FtsNavTab.historique),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = active ? FtsColors.blue700 : FtsColors.muted;
    return Expanded(
      child: InkWell(
        borderRadius: FtsRadius.smRadius,
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 21, color: color),
            const SizedBox(height: 3),
            Text(label, style: FtsText.navLabel.copyWith(color: color)),
          ],
        ),
      ),
    );
  }
}

class _FabSlot extends StatelessWidget {
  const _FabSlot({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 64,
      child: Center(
        child: Transform.translate(
          offset: const Offset(0, -22),
          child: GestureDetector(
            onTap: onTap,
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: FtsColors.blue700,
                border: Border.all(color: FtsColors.blue050, width: 4),
                boxShadow: [
                  BoxShadow(
                    color: FtsColors.blue900.withValues(alpha: 0.32),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: const Icon(Icons.qr_code_scanner_rounded, color: Colors.white, size: 24),
            ),
          ),
        ),
      ),
    );
  }
}
