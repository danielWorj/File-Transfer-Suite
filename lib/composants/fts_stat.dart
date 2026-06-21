import 'package:flutter/material.dart';
import '../theme/fts_theme.dart';

/// Carte chiffrée (`.fts-stat` / `.fts-mstat`) : libellé + valeur mono.
class FtsStat extends StatelessWidget {
  const FtsStat({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: FtsColors.surface,
        borderRadius: FtsRadius.cardRadius,
        border: Border.all(color: FtsColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(), style: FtsText.statLabel),
          const SizedBox(height: 4),
          Text(value, style: FtsText.statValue),
        ],
      ),
    );
  }
}

/// Grille 2x2 de [FtsStat], utilisée sur Accueil et Historique.
class FtsStatGrid extends StatelessWidget {
  const FtsStatGrid({super.key, required this.stats});

  /// Liste de paires (libellé, valeur), 4 éléments attendus.
  final List<(String, String)> stats;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 2.4,
      children: stats
          .map((s) => FtsStat(label: s.$1, value: s.$2))
          .toList(growable: false),
    );
  }
}
