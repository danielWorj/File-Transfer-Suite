import 'package:flutter/material.dart';

import '../app/app_controllers.dart';
import '../composants/composants.dart';
import '../controller/bundle_controller.dart';
import '../controller/controllers.dart';
import '../repository/repositories.dart';
import '../theme/fts_theme.dart';
import '../utils/format.dart';

/// Écran de réception : affiche l'état de connexion au PC, la liste des
/// fichiers reçus (`pc-to-mobile`) et permet de les télécharger un par un
/// ou de tout exporter dans une archive `.zip` partageable.
class ReceptionView extends StatefulWidget {
  const ReceptionView({super.key, required this.onOpenScan});

  /// Ouvre l'écran de scan QR (passé par `main.dart`) lorsqu'aucun appareil
  /// n'est encore apparié.
  final VoidCallback onOpenScan;

  @override
  State<ReceptionView> createState() => _ReceptionViewState();
}

class _ReceptionViewState extends State<ReceptionView> {
  bool _didInitialLoad = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Premier chargement de la liste si déjà apparié au montage.
    if (!_didInitialLoad) {
      _didInitialLoad = true;
      final c = FtsControllers.of(context);
      if (c.transfer.repository.isPaired) {
        WidgetsBinding.instance.addPostFrameCallback(
            (_) => c.transfer.refreshFiles());
      }
    }
  }

  Future<void> _downloadOne(
      TransferController transfer, TransferFile file) async {
    final saved = await transfer.download(file);
    if (!mounted) return;
    if (saved != null) {
      FtsToastHost.of(context)
          ?.show('« ${file.name} » enregistré.', type: FtsToastType.success);
    } else if (transfer.errorMessage.isNotEmpty) {
      FtsToastHost.of(context)
          ?.show(transfer.errorMessage, type: FtsToastType.error);
      transfer.clearError();
    }
  }

  Future<void> _exportZip(
      BundleController bundle, List<TransferFile> files) async {
    if (files.isEmpty) {
      FtsToastHost.of(context)
          ?.show('Aucun fichier reçu à exporter.', type: FtsToastType.warning);
      return;
    }
    final ok = await bundle.exportAndShare(files, zipName: 'fts_recus');
    if (!mounted) return;
    if (ok) {
      FtsToastHost.of(context)
          ?.show('Archive ZIP prête à être partagée.',
              type: FtsToastType.success);
    } else if (bundle.errorMessage.isNotEmpty) {
      FtsToastHost.of(context)
          ?.show(bundle.errorMessage, type: FtsToastType.error);
      bundle.clearError();
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = FtsControllers.of(context);

    return ListenableBuilder(
      listenable: Listenable.merge([c.pairing, c.transfer, c.bundle]),
      builder: (context, _) {
        final paired = c.pairing.isPaired;
        final received = c.transfer.receivedFiles;

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 110),
          children: [
            const FtsPageHead(
              eyebrow: 'Recevoir',
              title: 'Recevoir des fichiers',
              subtitle:
                  'Fichiers envoyés depuis le PC connecté vers ce téléphone.',
            ),

            // --- Carte connexion ---
            _ConnectionCard(
              pairing: c.pairing,
              onOpenScan: widget.onOpenScan,
              onRefresh:
                  paired ? () => c.transfer.refreshFiles() : null,
              loading: c.transfer.isLoadingFiles,
            ),

            // --- Progression d'export ZIP ---
            if (c.bundle.isBundling)
              _BundleProgress(
                label: c.bundle.statusLabel,
                progress: c.bundle.progress,
              ),

            // --- Fichiers reçus ---
            FtsCard(
              title: 'Fichiers reçus',
              meta: '${received.length} fichier'
                  '${received.length > 1 ? 's' : ''}',
              padBody: received.isNotEmpty,
              footer: received.isEmpty
                  ? const Text(
                      'Les fichiers reçus apparaissent ici en temps réel.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 11.5, color: FtsColors.muted),
                    )
                  : FtsButton(
                      label: c.bundle.isBundling
                          ? 'Export en cours…'
                          : 'Tout télécharger (ZIP)',
                      icon: Icons.folder_zip_outlined,
                      expand: true,
                      onPressed: c.bundle.isBundling
                          ? null
                          : () => _exportZip(c.bundle, received),
                    ),
              child: received.isEmpty
                  ? const FtsEmptyState(
                      message: 'Aucun fichier reçu pour l\'instant.',
                      subMessage:
                          'En attente d\'un envoi depuis le PC connecté.',
                      compact: true,
                    )
                  : Column(
                      children: received.map((f) {
                        final downloading =
                            c.transfer.downloadingFileId == f.id;
                        return FtsFileItem(
                          name: f.name,
                          meta:
                              '${f.sizeLabel} · ${formatDateTime(f.createdAt)}',
                          icon: Icons.south_west_rounded,
                          trailing: downloading
                              ? _MiniProgress(
                                  value: c.transfer.downloadProgress)
                              : _DownloadButton(
                                  onTap: () =>
                                      _downloadOne(c.transfer, f),
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

class _ConnectionCard extends StatelessWidget {
  const _ConnectionCard({
    required this.pairing,
    required this.onOpenScan,
    required this.onRefresh,
    required this.loading,
  });

  final PairingController pairing;
  final VoidCallback onOpenScan;
  final VoidCallback? onRefresh;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final paired = pairing.isPaired;
    final realtime = pairing.realtimeStatus;

    final (statusLabel, status) = switch (realtime) {
      RealtimeConnectionState.connected => ('Connecté en temps réel', FtsStatus.success),
      RealtimeConnectionState.connecting => ('Connexion…', FtsStatus.pending),
      RealtimeConnectionState.error => ('Erreur de connexion', FtsStatus.danger),
      RealtimeConnectionState.disconnected =>
        paired ? ('Apparié', FtsStatus.info) : ('Non connecté', FtsStatus.danger),
    };

    return FtsCard(
      title: 'Connexion',
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            decoration: BoxDecoration(
              color: FtsColors.blue050,
              borderRadius: FtsRadius.cardRadius,
              border: Border.all(color: FtsColors.border),
            ),
            child: Column(
              children: [
                Icon(
                  paired
                      ? Icons.link_rounded
                      : Icons.link_off_rounded,
                  size: 40,
                  color: paired ? FtsColors.blue700 : FtsColors.borderStrong,
                ),
                const SizedBox(height: 12),
                Text(
                  paired ? (pairing.pairedHost ?? 'PC apparié') : 'Aucun appareil',
                  textAlign: TextAlign.center,
                  style: FtsText.mono,
                ),
                const SizedBox(height: 10),
                FtsBadge(
                  label: statusLabel,
                  status: status,
                  pulse: realtime == RealtimeConnectionState.connecting ||
                      realtime == RealtimeConnectionState.connected,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          if (!paired)
            FtsButton(
              label: 'Scanner pour connecter',
              icon: Icons.qr_code_scanner_rounded,
              expand: true,
              onPressed: onOpenScan,
            )
          else
            FtsButton(
              label: loading ? 'Actualisation…' : 'Actualiser la liste',
              icon: Icons.refresh_rounded,
              variant: FtsButtonVariant.outline,
              expand: true,
              onPressed: loading ? null : onRefresh,
            ),
        ],
      ),
    );
  }
}

class _BundleProgress extends StatelessWidget {
  const _BundleProgress({required this.label, required this.progress});

  final String label;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final pct = (progress * 100).clamp(0, 100).toStringAsFixed(0);
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: FtsColors.surface,
        borderRadius: FtsRadius.cardRadius,
        border: Border.all(color: FtsColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.folder_zip_outlined,
                  size: 16, color: FtsColors.blue700),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label.isEmpty ? 'Préparation de l\'archive…' : label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: FtsText.mono.copyWith(fontSize: 11.5),
                ),
              ),
              Text('$pct %', style: FtsText.mono.copyWith(fontSize: 11.5)),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: FtsRadius.smRadius,
            child: LinearProgressIndicator(
              value: progress == 0 ? null : progress,
              minHeight: 6,
              backgroundColor: FtsColors.border,
              valueColor:
                  const AlwaysStoppedAnimation<Color>(FtsColors.blue500),
            ),
          ),
        ],
      ),
    );
  }
}

class _DownloadButton extends StatelessWidget {
  const _DownloadButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: FtsColors.blue100,
      borderRadius: FtsRadius.smRadius,
      child: InkWell(
        borderRadius: FtsRadius.smRadius,
        onTap: onTap,
        child: const Padding(
          padding: EdgeInsets.all(7),
          child: Icon(Icons.download_rounded,
              size: 17, color: FtsColors.blue700),
        ),
      ),
    );
  }
}

class _MiniProgress extends StatelessWidget {
  const _MiniProgress({required this.value});
  final double value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 22,
      height: 22,
      child: CircularProgressIndicator(
        value: value == 0 ? null : value,
        strokeWidth: 2.4,
        color: FtsColors.blue700,
        backgroundColor: FtsColors.border,
      ),
    );
  }
}
