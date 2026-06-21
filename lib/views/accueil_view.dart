import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../app/app_controllers.dart';
import '../composants/composants.dart';
import '../repository/repositories.dart';
import '../theme/fts_theme.dart';
import '../utils/format.dart';

/// Écran d'accueil : statistiques globales (alimentées par le
/// TransferController), actions rapides et activité récente.
class AccueilView extends StatelessWidget {
  const AccueilView({
    super.key,
    required this.onNavigateToSend,
    required this.onNavigateToReceive,
    required this.onNavigateToScan,
    required this.onNavigateToHistory,
  });

  final VoidCallback onNavigateToSend;
  final VoidCallback onNavigateToReceive;
  final VoidCallback onNavigateToScan;
  final VoidCallback onNavigateToHistory;

  @override
  Widget build(BuildContext context) {
    final transfer = FtsControllers.of(context).transfer;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 110),
      children: [
        const FtsPageHead(
          eyebrow: 'Accueil',
          title: 'Bonjour 👋',
          subtitle:
              'Transférez vos fichiers entre vos appareils en toute simplicité.',
        ),

        // --- Statistiques temps réel ---
        ListenableBuilder(
          listenable: transfer,
          builder: (context, _) {
            final files = transfer.files;
            final sent = transfer.sentFiles.length;
            final received = transfer.receivedFiles.length;
            final volume =
                files.fold<int>(0, (sum, f) => sum + f.sizeBytes);
            return FtsStatGrid(stats: [
              ('Total transferts', '${files.length}'),
              ('Envoyés', '$sent'),
              ('Reçus', '$received'),
              ('Volume total', formatBytes(volume)),
            ]);
          },
        ),

        const SizedBox(height: 22),

        Text('ACTIONS RAPIDES',
            style: FtsText.eyebrow.copyWith(color: FtsColors.muted)),
        const SizedBox(height: 10),

        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.35,
          children: [
            _QuickActionCard(
              icon: Icons.send_rounded,
              iconBg: FtsColors.blue100,
              iconFg: FtsColors.blue700,
              label: 'Envoyer',
              description: 'Choisir des fichiers à transférer',
              onTap: onNavigateToSend,
            ),
            _QuickActionCard(
              icon: Icons.inbox_rounded,
              iconBg: FtsColors.successSoft,
              iconFg: FtsColors.success,
              label: 'Recevoir',
              description: 'Voir et exporter les fichiers reçus',
              onTap: onNavigateToReceive,
            ),
            _QuickActionCard(
              icon: Icons.qr_code_scanner_rounded,
              iconBg: FtsColors.warningSoft,
              iconFg: FtsColors.warning,
              label: 'Scanner',
              description: 'Connecter un autre appareil',
              onTap: onNavigateToScan,
            ),
            _QuickActionCard(
              icon: Icons.history_rounded,
              iconBg: FtsColors.blue050,
              iconFg: FtsColors.ink,
              label: 'Historique',
              description: 'Voir les transferts précédents',
              onTap: onNavigateToHistory,
              bordered: true,
            ),
          ],
        ),

        const SizedBox(height: 22),

        // --- Activité récente temps réel ---
        ListenableBuilder(
          listenable: transfer,
          builder: (context, _) {
            final recent = transfer.files.take(5).toList();
            return FtsCard(
              title: 'Activité récente',
              meta: '${transfer.files.length} fichier'
                  '${transfer.files.length > 1 ? 's' : ''}',
              padBody: recent.isNotEmpty,
              child: recent.isEmpty
                  ? const FtsEmptyState(
                      message: 'Aucun transfert pour l\'instant.',
                      subMessage: 'Vos envois et réceptions apparaîtront ici.',
                    )
                  : Column(
                      children: recent.map((f) {
                        final sent =
                            f.direction == TransferDirection.mobileToPc;
                        return FtsFileItem(
                          name: f.name,
                          meta:
                              '${f.sizeLabel} · ${formatDateTime(f.createdAt)}',
                          icon: sent
                              ? Icons.north_east_rounded
                              : Icons.south_west_rounded,
                          trailing: FtsBadge(
                            label: sent ? 'Envoyé' : 'Reçu',
                            status: sent ? FtsStatus.info : FtsStatus.success,
                          ),
                        );
                      }).toList(),
                    ),
            );
          },
        ),
      ],
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  const _QuickActionCard({
    required this.icon,
    required this.iconBg,
    required this.iconFg,
    required this.label,
    required this.description,
    required this.onTap,
    this.bordered = false,
  });

  final IconData icon;
  final Color iconBg;
  final Color iconFg;
  final String label;
  final String description;
  final VoidCallback onTap;
  final bool bordered;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: FtsColors.surface,
      borderRadius: FtsRadius.cardRadius,
      child: InkWell(
        borderRadius: FtsRadius.cardRadius,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: FtsRadius.cardRadius,
            border: Border.all(color: FtsColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: FtsRadius.smRadius,
                  border:
                      bordered ? Border.all(color: FtsColors.border) : null,
                ),
                child: Icon(icon, size: 16, color: iconFg),
              ),
              const Spacer(),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: FtsColors.ink,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                    fontSize: 11, color: FtsColors.muted, height: 1.3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
