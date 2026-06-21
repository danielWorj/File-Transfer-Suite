/// controller/controllers.dart
///
/// Couche de présentation (`ChangeNotifier`) au-dessus de
/// `repository/repositories.dart`. Les vues s'abonnent à ces contrôleurs
/// via `ListenableBuilder` / `AnimatedBuilder` et n'appellent jamais
/// directement `TransfertRepository`.
///
/// - [PairingController] : scan / saisie manuelle du code, état de
///   connexion au PC, ouverture du flux temps réel.
/// - `TransferController` : envoi, réception, liste et suppression des
///   fichiers. Vit dans son propre fichier, `controllers/transfer_controller.dart`
///   (pour coller à l'import déjà utilisé par `envoi_view.dart`), et est
///   réexporté ci-dessous pour rester accessible depuis ce fichier aussi.
///
/// Exemple de câblage dans `main.dart` :
/// ```dart
/// final pairing = PairingController();
/// // ... après un scan réussi (pairing.status == PairingStatus.paired) :
/// final transfer = TransferController(repository: pairing.repository);
/// ```
library;

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../repository/repositories.dart';

export '../controller/transfer_controller.dart';

// ---------------------------------------------------------------------------
// PairingController
// ---------------------------------------------------------------------------

enum PairingStatus { disconnected, pairing, paired, error }

/// Gère l'appairage avec le PC (scan QR ou saisie manuelle) ainsi que la
/// connexion/déconnexion du flux temps réel une fois apparié.
///
/// Utilisé par `ScanView` (résultat de scan → [pairFromScannedUrl]) et par
/// la saisie manuelle du code (→ [pairManually]).
class PairingController extends ChangeNotifier {
  PairingController({TransfertRepository? repository})
      : repository = repository ?? TransfertRepository();

  /// Repository partagé : à transmettre à [TransferController] une fois
  /// l'appairage réussi, pour qu'il opère sur le même serveur/token.
  final TransfertRepository repository;

  PairingStatus status = PairingStatus.disconnected;
  String errorMessage = '';
  RealtimeConnectionState realtimeStatus =
      RealtimeConnectionState.disconnected;

  StreamSubscription<RealtimeConnectionState>? _realtimeSub;

  bool get isPaired => repository.isPaired;

  /// Adresse du PC connecté, ex. `https://192.168.1.20:8443`.
  String? get pairedHost => repository.baseUrl;

  /// À appeler avec le contenu brut lu par la caméra (ex. via
  /// `mobile_scanner`), correspondant à l'URL imprimée dans le QR code par
  /// `print_pairing_qr_code` côté serveur.
  Future<bool> pairFromScannedUrl(String scannedUrl) {
    return _runPairing(() => repository.pairFromScannedUrl(scannedUrl));
  }

  /// Appairage manuel (adresse seule, sans jeton) — ex. saisie directe de
  /// `http://10.50.1.158:8443` lue sur l'ordinateur.
  Future<bool> pairManually({required String host, String token = ''}) {
    return _runPairing(
          () => repository.pairWithHost(host: host, token: token),
    );
  }

  Future<bool> _runPairing(Future<void> Function() action) async {
    status = PairingStatus.pairing;
    errorMessage = '';
    notifyListeners();

    try {
      await action();
      status = PairingStatus.paired;
      notifyListeners();
      await _startRealtime();
      return true;
    } on ApiException catch (e) {
      status = PairingStatus.error;
      errorMessage = e.message;
      notifyListeners();
      return false;
    } catch (e) {
      status = PairingStatus.error;
      errorMessage = 'Erreur inattendue : $e';
      notifyListeners();
      return false;
    }
  }

  Future<void> _startRealtime() async {
    await _realtimeSub?.cancel();
    _realtimeSub = repository.connectionState.listen((s) {
      realtimeStatus = s;
      notifyListeners();
    });
    await repository.connectRealtime();
  }

  /// Coupe le WebSocket et oublie l'appairage courant.
  Future<void> disconnect() async {
    await _realtimeSub?.cancel();
    _realtimeSub = null;
    await repository.unpair();
    status = PairingStatus.disconnected;
    realtimeStatus = RealtimeConnectionState.disconnected;
    errorMessage = '';
    notifyListeners();
  }

  @override
  void dispose() {
    _realtimeSub?.cancel();
    repository.dispose();
    super.dispose();
  }
}