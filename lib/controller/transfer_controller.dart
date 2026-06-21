/// controllers/transfer_controller.dart
///
/// Contrôleur d'envoi/réception de fichiers, séparé de
/// `controller/controllers.dart` pour correspondre à l'import déjà présent
/// dans `envoi_view.dart` (`import '../controllers/transfer_controller.dart';`).
///
/// S'appuie sur `TransfertRepository` (voir `repository/repositories.dart`)
/// pour parler à l'API Flask (`transfertapi.py`) et écoute son flux
/// WebSocket pour se mettre à jour automatiquement (`transfer:complete`,
/// `files:updated`).
///
/// Doit recevoir un repository déjà apparié, typiquement celui de
/// `PairingController` :
/// ```dart
/// final transfer = TransferController(repository: pairing.repository);
/// ```
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../repository/repositories.dart';

/// Gère l'envoi, la réception, la liste et la suppression des fichiers
/// échangés avec le PC apparié.
///
/// Expose `isUploading` / `uploadingFileName` / `uploadProgress` /
/// `errorMessage`, consommés tels quels par `EnvoiView` via
/// `ListenableBuilder`.
class TransferController extends ChangeNotifier {
  TransferController({required this.repository}) {
    _eventsSub = repository.events.listen(_onRealtimeEvent);
  }

  final TransfertRepository repository;
  StreamSubscription<RealtimeEvent>? _eventsSub;

  // --------------------------- Envoi (upload) ---------------------------

  bool isUploading = false;
  String uploadingFileName = '';
  double uploadProgress = 0;
  String errorMessage = '';

  /// Envoie [file] vers le PC. Pendant l'appel, `isUploading`,
  /// `uploadingFileName` et `uploadProgress` (0.0 → 1.0) sont tenus à jour
  /// et notifiés à chaque palier de progression.
  Future<void> upload(
    File file, {
    TransferDirection direction = TransferDirection.mobileToPc,
  }) async {
    isUploading = true;
    uploadingFileName = file.path.split(Platform.pathSeparator).last;
    uploadProgress = 0;
    errorMessage = '';
    notifyListeners();

    try {
      final uploaded = await repository.uploadFile(
        file: file,
        direction: direction,
        onProgress: (p) {
          uploadProgress = p;
          notifyListeners();
        },
      );
      _files = [uploaded, ..._files.where((f) => f.id != uploaded.id)];
    } on ApiException catch (e) {
      errorMessage = e.message;
    } catch (e) {
      errorMessage = 'Échec de l\'envoi : $e';
    } finally {
      isUploading = false;
      uploadProgress = 0;
      uploadingFileName = '';
      notifyListeners();
    }
  }

  // --------------------------- Liste / réception -------------------------

  List<TransferFile> _files = [];

  /// Tous les fichiers connus de la session courante (envoyés + reçus).
  List<TransferFile> get files => List.unmodifiable(_files);

  /// Fichiers reçus du PC (onglet Réception).
  List<TransferFile> get receivedFiles => _files
      .where((f) => f.direction == TransferDirection.pcToMobile)
      .toList();

  /// Fichiers envoyés au PC (ex. onglet Historique).
  List<TransferFile> get sentFiles => _files
      .where((f) => f.direction == TransferDirection.mobileToPc)
      .toList();

  bool isLoadingFiles = false;

  /// Recharge la liste depuis `GET /api/files` (premier chargement d'un
  /// écran ; les mises à jour suivantes arrivent automatiquement via
  /// WebSocket).
  Future<void> refreshFiles() async {
    isLoadingFiles = true;
    notifyListeners();
    try {
      _files = await repository.listFiles();
    } on ApiException catch (e) {
      errorMessage = e.message;
    } finally {
      isLoadingFiles = false;
      notifyListeners();
    }
  }

  String? downloadingFileId;
  double downloadProgress = 0;

  /// Télécharge [file] depuis le PC vers le stockage local du téléphone.
  /// Retourne `null` en cas d'échec (voir [errorMessage]).
  Future<File?> download(TransferFile file) async {
    downloadingFileId = file.id;
    downloadProgress = 0;
    notifyListeners();

    try {
      return await repository.downloadFile(
        fileId: file.id,
        fileName: file.name,
        onProgress: (p) {
          downloadProgress = p;
          notifyListeners();
        },
      );
    } on ApiException catch (e) {
      errorMessage = e.message;
      return null;
    } finally {
      downloadingFileId = null;
      downloadProgress = 0;
      notifyListeners();
    }
  }

  /// Supprime un fichier côté serveur et de la liste locale.
  Future<bool> delete(String fileId) async {
    try {
      await repository.deleteFile(fileId);
      _files = _files.where((f) => f.id != fileId).toList();
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      errorMessage = e.message;
      notifyListeners();
      return false;
    }
  }

  void clearError() {
    errorMessage = '';
    notifyListeners();
  }

  // --------------------------- Temps réel ---------------------------------

  void _onRealtimeEvent(RealtimeEvent event) {
    if (event is TransferCompleteEvent) {
      _files = [event.file, ..._files.where((f) => f.id != event.file.id)];
      notifyListeners();
    } else if (event is FilesUpdatedEvent) {
      _files = event.files;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _eventsSub?.cancel();
    super.dispose();
  }
}
