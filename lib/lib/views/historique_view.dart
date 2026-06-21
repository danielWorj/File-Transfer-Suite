import 'package:flutter/material.dart';

import '../app/app_controllers.dart';
import '../composants/composants.dart';
import '../controller/bundle_controller.dart';
import '../controller/controllers.dart';
import '../repository/repositories.dart';
import '../theme/fts_theme.dart';
import '../utils/format.dart';

enum _Sens { tous, envoyes, recus }

/// Écran d'historique : statistiques réelles, recherche/filtre et liste
/// des transferts envoyés/reçus, alimentés par le TransferController.
/// Permet aussi d'exporter la sélection courante en archive `.zip`.
class HistoriqueView extends StatefulWidget {
  const HistoriqueView({super.key});

  @override
  State<HistoriqueView> createState() => _HistoriqueViewState();
}

class _HistoriqueViewState extends State<HistoriqueView> {
  final _searchController = TextEditingController();
  _Sens _sens = _Sens.tous;
  bool _didInitialLoad = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didInitialLoad) {
      _didInitialLoad = true;
      final c = FtsControllers.of(context);
      if (c.transfer.repository.isPaired) {
        WidgetsBinding.instance
            .addPostFrameCallback((_) => c.transfer.refreshFiles());
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refresh(TransferController transfer) async {
    if (!transfer.repository.isPaired) {
      FtsToastHost.of(context)?.show(
        'Connectez un appareil pour charger l\'historique.',
        type: FtsToastType.warning,
      );
      return;
    }
    await transfer.refreshFiles();
    if (mounted) {
      FtsToastHost.of(context)
          ?.show('Historique actualisé', type: FtsToastType.success);
    }
  }

  Future<void> _exportZip(
      BundleController bundle, List<TransferFile> files) async {
    if (files.isEmpty) {
      FtsToastHost.of(context)
          ?.show('Aucun transfert à exporter.', type: FtsToastType.warning);
      return;
    }
    final ok = await bundle.exportAndShare(files, zipName: 'fts_historique');
    if (!mounted) return;
    if (ok) {
      FtsToastHost.of(context)
          ?.show('Archive ZIP prête.', type: FtsToastType.success);
    } else if (bundle.errorMessage.isNotEmpty) {
      FtsToastHost.of(context)
          ?.show(bundle.errorMessage, type: FtsToastType.error);
      bundle.clearError();
    }
  }

  List<TransferFile> _filtered(List<TransferFile> entries) {
    final query = _searchController.text.toLowerCase();
    return entries.where((e) {
      final matchesQuery =
          query.isEmpty || e.name.toLowerCase().contains(query);
      final sent = e.direction == TransferDirection.mobileToPc;
      final matchesSens = switch (_sens) {
        _Sens.tous => true,
        _Sens.envoyes => sent,
        _Sens.recus => !sent,
      };
      return matchesQuery && matchesSens;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final c = FtsControllers.of(context);

    return ListenableBuilder(
      listenable: Listenable.merge([c.transfer, c.bundle]),
      builder: (context, _) {
        final entries = c.transfer.files;
        final visible = _filtered(entries);
        final sentCount = entries
            .where((e) => e.direction == TransferDirection.mobileToPc)
            .length;
        final volume = entries.fold<int>(0, (sum, f) => sum + f.sizeBytes);

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 110),
          children: [
            const FtsPageHead(
              eyebrow: 'Historique',
              title: 'Historique des transferts',
              subtitle:
                  'Retrouvez l\'ensemble des fichiers envoyés et reçus depuis cet appareil.',
            ),

            FtsStatGrid(stats: [
              ('Total', '${entries.length}'),
              ('Envoyés', '$sentCount'),
              ('Reçus', '${entries.length - sentCount}'),
              ('Volume', formatBytes(volume)),
            ]),

            const SizedBox(height: 18),

            FtsTextField(
              hint: 'Rechercher un fichier…',
              icon: Icons.search_rounded,
              controller: _searchController,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 10),

            Row(
              children: [
                Expanded(
                  child: FtsSelect<_Sens>(
                    value: _sens,
                    items: const [
                      DropdownMenuItem(
                          value: _Sens.tous, child: Text('Tous les sens')),
                      DropdownMenuItem(
                          value: _Sens.envoyes, child: Text('Envoyés')),
                      DropdownMenuItem(
                          value: _Sens.recus, child: Text('Reçus')),
                    ],
                    onChanged: (v) => setState(() => _sens = v ?? _Sens.tous),
                  ),
                ),
                const SizedBox(width: 8),
                FtsIconAction(
                  icon: Icons.refresh_rounded,
                  onTap: c.transfer.isLoadingFiles
                      ? null
                      : () => _refresh(c.transfer),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Bouton d'export ZIP de la sélection visible.
            if (visible.isNotEmpty) ...[
              FtsButton(
                label: c.bundle.isBundling
                    ? 'Export en cours…'
                    : 'Exporter en ZIP (${visible.length})',
                icon: Icons.folder_zip_outlined,
                variant: FtsButtonVariant.outline,
                expand: true,
                onPressed: c.bundle.isBundling
                    ? null
                    : () => _exportZip(c.bundle, visible),
              ),
              const SizedBox(height: 16),
            ],

            FtsCard(
              padBody: visible.isNotEmpty,
              child: visible.isEmpty
                  ? FtsEmptyState(
                      message: entries.isEmpty
                          ? 'Aucun transfert pour l\'instant.'
                          : 'Aucun résultat pour ce filtre.',
                      subMessage: entries.isEmpty
                          ? 'Vos transferts envoyés et reçus s\'afficheront ici.'
                          : 'Modifiez la recherche ou le filtre.',
                    )
                  : Column(
                      children: visible.map((e) {
                        final sent =
                            e.direction == TransferDirection.mobileToPc;
                        return FtsFileItem(
                          name: e.name,
                          meta:
                              '${e.sizeLabel} · ${formatDateTime(e.createdAt)}',
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
            ),
          ],
        );
      },
    );
  }
}
