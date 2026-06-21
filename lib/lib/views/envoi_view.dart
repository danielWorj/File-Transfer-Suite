import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../app/app_controllers.dart';
import '../composants/composants.dart';
import '../controller/controllers.dart';
import '../theme/fts_theme.dart';
import '../utils/format.dart';

/// Fichier sélectionné localement, en attente d'envoi.
class _SelectedFile {
  _SelectedFile({required this.path, required this.name, required this.size});
  final String path;
  final String name;
  final int size;

  String get sizeLabel => formatBytes(size);
}

/// Écran d'envoi : sélection réelle de fichiers/dossiers via `file_picker`,
/// puis envoi vers le PC apparié via `TransferController.upload`
/// (API `POST /api/upload`) avec progression.
class EnvoiView extends StatefulWidget {
  const EnvoiView({super.key});

  @override
  State<EnvoiView> createState() => _EnvoiViewState();
}

class _EnvoiViewState extends State<EnvoiView> {
  final List<_SelectedFile> _files = [];

  Future<void> _pickFiles() async {
    try {
      final result = await FilePicker.platform.pickFiles(allowMultiple: true);
      if (result == null) return;
      setState(() {
        for (final f in result.files) {
          if (f.path != null) {
            _files.add(_SelectedFile(path: f.path!, name: f.name, size: f.size));
          }
        }
      });
    } catch (e) {
      _toast('Sélection impossible : $e', FtsToastType.error);
    }
  }

  Future<void> _pickFolder() async {
    try {
      final dirPath = await FilePicker.platform.getDirectoryPath();
      if (dirPath == null) return;
      final dir = Directory(dirPath);
      final entries = await dir
          .list(recursive: true, followLinks: false)
          .where((e) => e is File)
          .cast<File>()
          .toList();
      if (entries.isEmpty) {
        _toast('Ce dossier ne contient aucun fichier.', FtsToastType.warning);
        return;
      }
      setState(() {
        for (final file in entries) {
          final stat = file.statSync();
          _files.add(_SelectedFile(
            path: file.path,
            name: file.uri.pathSegments.last,
            size: stat.size,
          ));
        }
      });
    } catch (e) {
      _toast('Lecture du dossier impossible : $e', FtsToastType.error);
    }
  }

  void _removeFile(int index) => setState(() => _files.removeAt(index));

  void _clearAll() => setState(() => _files.clear());

  Future<void> _transfer(TransferController transfer) async {
    if (_files.isEmpty) return;

    if (!transfer.repository.isPaired) {
      _toast('Connectez d\'abord un appareil via le Scan.',
          FtsToastType.warning);
      return;
    }

    final toSend = List<_SelectedFile>.from(_files);
    var success = 0;

    for (final f in toSend) {
      await transfer.upload(File(f.path));
      if (transfer.errorMessage.isNotEmpty) {
        _toast(transfer.errorMessage, FtsToastType.error);
        transfer.clearError();
        break;
      }
      success++;
      // Retire de la liste au fur et à mesure des envois réussis.
      setState(() => _files.removeWhere((e) => e.path == f.path));
    }

    if (success > 0) {
      _toast('$success fichier${success > 1 ? 's' : ''} envoyé'
          '${success > 1 ? 's' : ''} avec succès.', FtsToastType.success);
    }
  }

  void _toast(String message, FtsToastType type) {
    FtsToastHost.of(context)?.show(message, type: type);
  }

  @override
  Widget build(BuildContext context) {
    final transfer = FtsControllers.of(context).transfer;

    return ListenableBuilder(
      listenable: transfer,
      builder: (context, _) {
        final totalBytes =
            _files.fold<int>(0, (sum, f) => sum + f.size);
        final totalLabel = _files.isEmpty
            ? '0 fichier · 0 o'
            : '${_files.length} fichier${_files.length > 1 ? 's' : ''} · '
                '${formatBytes(totalBytes)}';
        final busy = transfer.isUploading;

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 110),
          children: [
            const FtsPageHead(
              eyebrow: 'Envoyer',
              title: 'Envoyer des fichiers',
              subtitle:
                  'Ajoutez les fichiers à transférer, puis lancez l\'envoi.',
            ),

            FtsCard(
              title: 'Fichiers sélectionnés',
              meta: totalLabel,
              padBody: false,
              footer: Row(
                children: [
                  FtsButton(
                    label: 'Vider',
                    icon: Icons.delete_outline_rounded,
                    variant: FtsButtonVariant.ghost,
                    onPressed:
                        (_files.isEmpty || busy) ? null : _clearAll,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FtsButton(
                      label: busy ? 'Envoi en cours…' : 'Transférer',
                      icon: Icons.send_rounded,
                      expand: true,
                      onPressed: (_files.isEmpty || busy)
                          ? null
                          : () => _transfer(transfer),
                    ),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _AddTile(
                            icon: Icons.note_add_outlined,
                            label: 'Ajouter des fichiers',
                            onTap: busy ? null : _pickFiles,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _AddTile(
                            icon: Icons.create_new_folder_outlined,
                            label: 'Ajouter un dossier',
                            onTap: busy ? null : _pickFolder,
                          ),
                        ),
                      ],
                    ),

                    // Progression d'envoi.
                    if (busy) ...[
                      const SizedBox(height: 14),
                      _UploadProgress(
                        fileName: transfer.uploadingFileName,
                        progress: transfer.uploadProgress,
                      ),
                    ],

                    if (_files.isEmpty && !busy)
                      const FtsEmptyState(
                        message: 'Aucun fichier sélectionné.',
                        subMessage:
                            'Ajoutez des fichiers ou un dossier ci-dessus.',
                        compact: true,
                      )
                    else if (_files.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Column(
                          children: List.generate(_files.length, (i) {
                            final f = _files[i];
                            return FtsFileItem(
                              name: f.name,
                              meta: f.sizeLabel,
                              onRemove: busy ? null : () => _removeFile(i),
                            );
                          }),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // Bandeau d'état de connexion.
            _ConnectionHint(paired: transfer.repository.isPaired),
          ],
        );
      },
    );
  }
}

class _UploadProgress extends StatelessWidget {
  const _UploadProgress({required this.fileName, required this.progress});

  final String fileName;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final pct = (progress * 100).clamp(0, 100).toStringAsFixed(0);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: FtsColors.blue050,
        borderRadius: FtsRadius.cardRadius,
        border: Border.all(color: FtsColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Envoi : $fileName',
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

class _ConnectionHint extends StatelessWidget {
  const _ConnectionHint({required this.paired});
  final bool paired;

  @override
  Widget build(BuildContext context) {
    if (paired) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: FtsColors.successSoft,
          borderRadius: FtsRadius.cardRadius,
        ),
        child: Row(
          children: const [
            Icon(Icons.check_circle_outline,
                size: 17, color: FtsColors.success),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Appareil connecté. Vos fichiers seront envoyés au PC apparié.',
                style: TextStyle(
                    fontSize: 12.5, color: FtsColors.success, height: 1.45),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: FtsColors.blue100,
        borderRadius: FtsRadius.cardRadius,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded,
              size: 17, color: FtsColors.blue700),
          const SizedBox(width: 10),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: GoogleFonts.inter(
                    fontSize: 12.5, color: FtsColors.blue700, height: 1.45),
                children: const [
                  TextSpan(text: 'Connectez d\'abord un appareil via '),
                  TextSpan(
                      text: 'Scan',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                  TextSpan(text: ' avant de lancer un transfert.'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AddTile extends StatelessWidget {
  const _AddTile({required this.icon, required this.label, this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    return Opacity(
      opacity: disabled ? 0.5 : 1,
      child: Material(
        color: FtsColors.blue050,
        borderRadius: FtsRadius.cardRadius,
        child: InkWell(
          borderRadius: FtsRadius.cardRadius,
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
            decoration: BoxDecoration(
              borderRadius: FtsRadius.cardRadius,
              border: Border.all(
                  color: FtsColors.borderStrong,
                  width: 1.4,
                  style: BorderStyle.solid),
            ),
            child: Column(
              children: [
                Icon(icon, size: 20, color: FtsColors.blue500),
                const SizedBox(height: 8),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    fontSize: 11.5,
                    color: FtsColors.blue700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
