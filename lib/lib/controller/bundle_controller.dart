/// controller/bundle_controller.dart
///
/// Orchestration de l'export ZIP, par-dessus `TransferController`.
///
/// Rôle : pour une liste de [TransferFile], télécharge chacun depuis le PC
/// (API `GET /api/download/<id>`, via `TransferController.download`), puis
/// regroupe les fichiers locaux obtenus dans une archive `.zip`
/// (`service/zip_service.dart`) et la propose au partage / téléchargement.
///
/// Les controllers de base (`PairingController`, `TransferController`) ne
/// sont pas modifiés : cette classe se contente de les réutiliser.
library;

import 'dart:io';

import 'package:flutter/foundation.dart';

import '../repository/repositories.dart';
import '../service/zip_service.dart';
import 'controllers.dart';

/// Gère la génération d'une archive ZIP téléchargeable à partir des
/// fichiers échangés. Expose une progression globale consommable par l'UI
/// via `ListenableBuilder`.
class BundleController extends ChangeNotifier {
  BundleController({required this.transfer});

  final TransferController transfer;

  /// Vrai pendant tout le cycle téléchargement → compression.
  bool isBundling = false;

  /// Progression globale de 0.0 à 1.0 (téléchargements + étape de
  /// compression finale).
  double progress = 0;

  /// Libellé de l'étape courante, ex. « Téléchargement 2/5 : rapport.pdf ».
  String statusLabel = '';

  String errorMessage = '';

  /// Dernière archive générée (utile pour re-partager sans tout refaire).
  File? lastZip;

  bool get _busyGuard => isBundling;

  /// Télécharge [files] puis les compresse en un seul `.zip`.
  /// Retourne le fichier ZIP, ou `null` en cas d'échec (voir [errorMessage]).
  Future<File?> exportAsZip(
    List<TransferFile> files, {
    String zipName = 'fts_export',
  }) async {
    if (_busyGuard) return null;
    if (files.isEmpty) {
      errorMessage = 'Aucun fichier à exporter.';
      notifyListeners();
      return null;
    }

    isBundling = true;
    progress = 0;
    errorMessage = '';
    statusLabel = 'Préparation…';
    notifyListeners();

    final localFiles = <File>[];

    try {
      // +1 « palier » pour l'étape de compression finale.
      final totalSteps = files.length + 1;

      for (var i = 0; i < files.length; i++) {
        final file = files[i];
        statusLabel = 'Téléchargement ${i + 1}/${files.length} : ${file.name}';
        notifyListeners();

        final local = await transfer.download(file);
        if (local != null) localFiles.add(local);

        progress = (i + 1) / totalSteps;
        notifyListeners();
      }

      if (localFiles.isEmpty) {
        errorMessage = transfer.errorMessage.isNotEmpty
            ? transfer.errorMessage
            : 'Aucun fichier n\'a pu être téléchargé.';
        return null;
      }

      statusLabel = 'Compression de l\'archive…';
      notifyListeners();

      final zip = await ZipService.createZip(localFiles, baseName: zipName);
      lastZip = zip;
      progress = 1;
      notifyListeners();
      return zip;
    } on ZipException catch (e) {
      errorMessage = e.message;
      return null;
    } catch (e) {
      errorMessage = 'Échec de l\'export ZIP : $e';
      return null;
    } finally {
      isBundling = false;
      statusLabel = '';
      notifyListeners();
    }
  }

  /// Variante pratique : génère le ZIP puis ouvre la feuille de partage.
  /// Retourne `true` si l'archive a été générée et le partage déclenché.
  Future<bool> exportAndShare(
    List<TransferFile> files, {
    String zipName = 'fts_export',
  }) async {
    final zip = await exportAsZip(files, zipName: zipName);
    if (zip == null) return false;
    await ZipService.shareZip(zip);
    return true;
  }

  /// Re-partage la dernière archive générée, sans re-télécharger.
  Future<bool> shareLast() async {
    final zip = lastZip;
    if (zip == null || !await zip.exists()) return false;
    await ZipService.shareZip(zip);
    return true;
  }

  void clearError() {
    errorMessage = '';
    notifyListeners();
  }
}
