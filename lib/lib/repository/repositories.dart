/// repository/repositories.dart
///
/// Couche d'accès réseau vers le serveur PC exposé par `main.py` /
/// `api/transfertapi.py` (backend Flask + Flask-SocketIO).
///
/// Ce fichier regroupe :
/// - les modèles de données (`TransferFile`, `TransferDirection`,
///   évènements temps réel)
/// - les exceptions réseau (`ApiException`, `AuthException`,
///   `PairingException`)
/// - `TransfertRepository` : le client unique qui parle au serveur PC
///   (pairing, upload, download, liste, suppression, et flux temps réel
///   Socket.IO sur le namespace `/api/ws`)
///
/// Aucune dépendance Flutter ici (pas de `BuildContext`, pas de
/// `ChangeNotifier`) : ce fichier est testable indépendamment de l'UI.
/// La couche de présentation se trouve dans `controller/controllers.dart`.
///
/// ⚠️ Note : `service/transfertservice.py` (qui construit les
/// `metadata.to_dict()` renvoyés par `/api/upload` et `/api/files`) n'a pas
/// été fourni. Les noms de champs JSON ci-dessous (id, name, size,
/// mime_type, direction, created_at) sont déduits du contexte de
/// `transfertapi.py`. `TransferFile.fromJson` est volontairement tolérant
/// (plusieurs alias par champ) ; ajustez la liste de clés dans `_pick(...)`
/// si le service réel utilise d'autres noms.
library;

import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:socket_io_client/socket_io_client.dart' as sio;

// ---------------------------------------------------------------------------
// Exceptions
// ---------------------------------------------------------------------------

/// Erreur générique renvoyée par le serveur (corps `{"detail": "..."}`,
/// voir les routes de `transfertapi.py`).
class ApiException implements Exception {
  ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => 'ApiException(${statusCode ?? '-'}): $message';
}

/// 401 — token manquant, invalide ou expiré (`require_valid_token`).
class AuthException extends ApiException {
  AuthException(super.message, {super.statusCode = 401});
}

/// Échec spécifique à l'étape d'appairage (QR scanné ou saisie manuelle).
class PairingException extends ApiException {
  PairingException(super.message, {super.statusCode});
}

// ---------------------------------------------------------------------------
// Modèles
// ---------------------------------------------------------------------------

/// Sens d'un transfert, voir le champ `direction` du formulaire
/// `POST /api/upload` côté backend (défaut serveur : `mobile-to-pc`).
enum TransferDirection {
  mobileToPc,
  pcToMobile;

  String get apiValue => switch (this) {
    TransferDirection.mobileToPc => 'mobile-to-pc',
    TransferDirection.pcToMobile => 'pc-to-mobile',
  };

  static TransferDirection fromApi(String? value) {
    return value == 'pc-to-mobile'
        ? TransferDirection.pcToMobile
        : TransferDirection.mobileToPc;
  }
}

/// Représente un fichier transféré, tel que renvoyé par `/api/upload`,
/// `/api/files` ou diffusé via WebSocket (`transfer:complete`,
/// `files:updated`).
class TransferFile {
  TransferFile({
    required this.id,
    required this.name,
    required this.sizeBytes,
    required this.mimeType,
    required this.direction,
    this.createdAt,
  });

  final String id;
  final String name;
  final int sizeBytes;
  final String mimeType;
  final TransferDirection direction;
  final DateTime? createdAt;

  /// Libellé lisible, ex. "1.2 Mo" (utilisé par FtsFileItem.meta côté UI).
  String get sizeLabel {
    const units = ['o', 'Ko', 'Mo', 'Go'];
    double size = sizeBytes.toDouble();
    var unitIndex = 0;
    while (size >= 1024 && unitIndex < units.length - 1) {
      size /= 1024;
      unitIndex++;
    }
    final precision = unitIndex == 0 ? 0 : 1;
    return '${size.toStringAsFixed(precision)} ${units[unitIndex]}';
  }

  factory TransferFile.fromJson(Map<String, dynamic> json) {
    return TransferFile(
      id: _pick(json, ['id', 'file_id', 'fileId']) ?? '',
      name: _pick(json, ['name', 'filename', 'file_name']) ?? 'fichier',
      sizeBytes: int.tryParse(
        _pick(json, ['size', 'size_bytes', 'sizeBytes']) ?? '',
      ) ??
          0,
      mimeType: _pick(json, ['mime_type', 'mimeType', 'content_type']) ??
          'application/octet-stream',
      direction: TransferDirection.fromApi(_pick(json, ['direction'])),
      createdAt: DateTime.tryParse(
        _pick(json, ['created_at', 'createdAt', 'timestamp']) ?? '',
      ),
    );
  }

  static String? _pick(Map<String, dynamic> json, List<String> keys) {
    for (final k in keys) {
      final v = json[k];
      if (v != null) return v.toString();
    }
    return null;
  }
}

/// Évènements diffusés par le serveur sur le namespace WebSocket `/api/ws`
/// (voir `ConnectionManager.broadcast` dans `transfertapi.py`).
sealed class RealtimeEvent {}

class TransferCompleteEvent extends RealtimeEvent {
  TransferCompleteEvent(this.file);
  final TransferFile file;
}

class FilesUpdatedEvent extends RealtimeEvent {
  FilesUpdatedEvent(this.files);
  final List<TransferFile> files;
}

enum RealtimeConnectionState { disconnected, connecting, connected, error }

// ---------------------------------------------------------------------------
// Repository principal
// ---------------------------------------------------------------------------

/// Client unique du serveur PC : pairing, opérations REST sur les fichiers
/// et flux temps réel WebSocket.
///
/// Usage typique :
/// ```dart
/// final repo = TransfertRepository();
/// await repo.pairFromScannedUrl(scannedQrText);
/// await repo.connectRealtime();
/// final files = await repo.listFiles();
/// ```
class TransfertRepository {
  TransfertRepository({Dio? dio}) : _dio = dio ?? Dio();

  final Dio _dio;
  sio.Socket? _socket;

  String? _baseUrl;
  String? _token;

  final _filesController = StreamController<List<TransferFile>>.broadcast();
  final _eventsController = StreamController<RealtimeEvent>.broadcast();
  final _connectionController =
  StreamController<RealtimeConnectionState>.broadcast();

  /// Adresse du serveur PC actuellement apparié
  /// (ex. `https://192.168.1.20:8443`).
  String? get baseUrl => _baseUrl;

  /// Token de pairing courant, envoyé en `Authorization: Bearer <token>`.
  String? get token => _token;

  bool get isPaired => _baseUrl != null && _token != null;

  /// Dernière liste connue des fichiers, rafraîchie par [listFiles] et par
  /// chaque évènement `files:updated` reçu en temps réel.
  Stream<List<TransferFile>> get filesUpdates => _filesController.stream;

  /// Tous les évènements temps réel bruts (utile pour toasts, badges, etc.).
  Stream<RealtimeEvent> get events => _eventsController.stream;

  Stream<RealtimeConnectionState> get connectionState =>
      _connectionController.stream;

  // --------------------------- Pairing --------------------------------

  /// Analyse l'URL contenue dans le QR code affiché par l'application web
  /// du PC (ex. `http://10.50.1.158:8443/app/reception.html?token=XXXX`,
  /// voir `print_pairing_qr_code` / `/api/qrcode` côté backend). Le token
  /// est lu directement dans la query string si présent ; sinon
  /// [pairWithHost] ira le chercher lui-même via `GET /api/session`.
  Future<void> pairFromScannedUrl(String scannedUrl) async {
    final uri = Uri.tryParse(scannedUrl.trim());

    if (uri == null || uri.host.isEmpty) {
      throw PairingException('QR code invalide : adresse introuvable.');
    }

    final token = uri.queryParameters['token'] ?? '';
    await pairWithHost(host: scannedUrl, token: token);
  }

  /// Réduit n'importe quelle chaîne (URL complète avec chemin et query, ou
  /// simple `host:port`) à son origine `scheme://host:port`. Accepte aussi
  /// bien `http://10.50.1.158:8443/app/reception.html?token=...` que
  /// `10.50.1.158:8443` (auquel cas `http://` est ajouté par défaut).
  String _originOf(String input) {
    var raw = input.trim();
    if (!raw.contains('://')) raw = 'http://$raw';

    final uri = Uri.tryParse(raw);
    if (uri == null || uri.host.isEmpty) {
      // Repli : on retire juste un éventuel slash final.
      return raw.endsWith('/') ? raw.substring(0, raw.length - 1) : raw;
    }

    return uri.hasPort
        ? '${uri.scheme}://${uri.host}:${uri.port}'
        : '${uri.scheme}://${uri.host}';
  }

  /// Appairage avec l'adresse du serveur PC.
  ///
  /// 1. `GET /api/ping` : vérifie que le serveur est joignable sur le
  ///    réseau local.
  /// 2. Si aucun [token] n'est fourni (saisie manuelle de l'IP, ou scan
  ///    QR ne contenant pas le paramètre `token`), on le récupère
  ///    automatiquement via `GET /api/session` — route volontairement non
  ///    authentifiée côté serveur (voir `transfertapi.py`), prévue pour ce
  ///    cas d'auto-appairage sans avoir à retaper le jeton à la main.
  /// 3. `POST /api/pair` : confirme le token auprès du serveur avant de le
  ///    considérer comme valide.
  Future<void> pairWithHost({
    required String host,
    String token = '',
  }) async {
    final normalizedHost = _originOf(host);

    try {
      final ping = await _dio.get<dynamic>(
        '$normalizedHost/api/ping',
        options: Options(validateStatus: (_) => true),
      );
      if (ping.statusCode == null || ping.statusCode! >= 500) {
        throw PairingException(
          'Le serveur ne répond pas à cette adresse (${ping.statusCode ?? '-'}).',
        );
      }
    } on DioException catch (e) {
      throw PairingException(_describeDioError(e));
    }

    var effectiveToken = token;

    if (effectiveToken.isEmpty) {
      try {
        final session = await _dio.get<Map<String, dynamic>>(
          '$normalizedHost/api/session',
          options: Options(validateStatus: (_) => true),
        );
        if (session.statusCode == 200) {
          effectiveToken = (session.data?['token'] as String?) ?? '';
        }
      } on DioException {
        // On retentera la suite ; l'absence de token sera détectée juste
        // après par l'appel à /api/pair.
      }
    }

    if (effectiveToken.isEmpty) {
      throw PairingException(
        'Aucune session active sur le serveur. Redémarrez le serveur sur '
        'le PC puis réessayez.',
      );
    }

    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '$normalizedHost/api/pair',
        data: {'token': effectiveToken},
        // Depuis Dio 5.0, le content-type n'est plus déduit automatiquement
        // du type du payload : sans ce header, Flask `request.get_json()`
        // peut renvoyer None côté serveur et faire échouer le pairing.
        options: Options(
          contentType: Headers.jsonContentType,
          validateStatus: (_) => true,
        ),
      );

      if (response.statusCode == 200) {
        _baseUrl = normalizedHost;
        _token = effectiveToken;
        return;
      }

      if (response.statusCode == 401) {
        throw PairingException(
          'Token invalide ou expiré. Redémarrez le serveur sur le PC pour '
          'en générer un nouveau.',
          statusCode: 401,
        );
      }

      throw PairingException(
        'Appairage refusé par le serveur (${response.statusCode}).',
        statusCode: response.statusCode,
      );
    } on DioException catch (e) {
      throw PairingException(_describeDioError(e));
    }
  }

  /// Conservé pour compatibilité avec l'ancien flux (jeton obligatoire).
  Future<void> pairWithTokenAndHost({
    required String host,
    required String token,
  }) =>
      pairWithHost(host: host, token: token);

  /// Vérifie que le serveur précédemment apparié répond toujours
  /// (`GET /api/ping`).
  Future<bool> ping() async {
    if (_baseUrl == null) return false;
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '$_baseUrl/api/ping',
        options: Options(validateStatus: (_) => true),
      );
      return response.statusCode == 200;
    } on DioException {
      return false;
    }
  }

  /// Réinitialise l'état d'appairage et coupe le WebSocket.
  Future<void> unpair() async {
    await disconnectRealtime();
    _baseUrl = null;
    _token = null;
  }

  // --------------------------- Fichiers --------------------------------

  /// `GET /api/files`.
  Future<List<TransferFile>> listFiles() async {
    final response = await _authorizedRequest(
          (dio, headers) => dio.get<Map<String, dynamic>>(
        '$_baseUrl/api/files',
        options: Options(headers: headers, validateStatus: (_) => true),
      ),
    );

    final list = (response.data?['files'] as List?) ?? const [];
    final files = list
        .map((e) => TransferFile.fromJson(e as Map<String, dynamic>))
        .toList();

    _filesController.add(files);
    return files;
  }

  /// Envoie [file] vers le PC (`POST /api/upload`, multipart).
  /// [onProgress] reçoit une valeur de 0.0 à 1.0.
  Future<TransferFile> uploadFile({
    required File file,
    TransferDirection direction = TransferDirection.mobileToPc,
    void Function(double progress)? onProgress,
  }) async {
    _ensurePaired();

    final fileName = file.path.split(Platform.pathSeparator).last;
    final formData = FormData.fromMap({
      'direction': direction.apiValue,
      'file': await MultipartFile.fromFile(file.path, filename: fileName),
    });

    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '$_baseUrl/api/upload',
        data: formData,
        options: Options(
          headers: _authHeaders(),
          validateStatus: (_) => true,
        ),
        onSendProgress: (sent, total) {
          if (total > 0) onProgress?.call(sent / total);
        },
      );

      _throwIfError(response);
      return TransferFile.fromJson(response.data!);
    } on DioException catch (e) {
      throw ApiException(_describeDioError(e));
    }
  }

  /// Télécharge le fichier [fileId] et l'enregistre dans le dossier de
  /// documents de l'application. Retourne le fichier local. [onProgress]
  /// reçoit une valeur de 0.0 à 1.0.
  Future<File> downloadFile({
    required String fileId,
    required String fileName,
    void Function(double progress)? onProgress,
  }) async {
    _ensurePaired();

    final dir = await getApplicationDocumentsDirectory();
    final savePath = '${dir.path}${Platform.pathSeparator}$fileName';

    try {
      final response = await _dio.download(
        '$_baseUrl/api/download/$fileId',
        savePath,
        options: Options(
          headers: _authHeaders(),
          validateStatus: (_) => true,
        ),
        onReceiveProgress: (received, total) {
          if (total > 0) onProgress?.call(received / total);
        },
      );

      _throwIfError(response);
      return File(savePath);
    } on DioException catch (e) {
      throw ApiException(_describeDioError(e));
    }
  }

  /// `DELETE /api/files/<id>`.
  Future<void> deleteFile(String fileId) async {
    await _authorizedRequest(
          (dio, headers) => dio.delete<Map<String, dynamic>>(
        '$_baseUrl/api/files/$fileId',
        options: Options(headers: headers, validateStatus: (_) => true),
      ),
    );
  }

  // --------------------------- Temps réel (Socket.IO) -------------------

  /// Ouvre la connexion WebSocket vers le namespace `/api/ws`
  /// (`flask_socketio`), authentifiée par le token de pairing.
  Future<void> connectRealtime() async {
    _ensurePaired();
    await disconnectRealtime();

    _connectionController.add(RealtimeConnectionState.connecting);

    final socket = sio.io(
      '$_baseUrl/api/ws',
      sio.OptionBuilder()
          .setTransports(['websocket'])
          .setAuth((_token == null || _token!.isEmpty) ? {} : {'token': _token})
          .disableAutoConnect()
          .build(),
    );

    socket
      ..onConnect((_) {
        _connectionController.add(RealtimeConnectionState.connected);
      })
      ..onDisconnect((_) {
        _connectionController.add(RealtimeConnectionState.disconnected);
      })
      ..onConnectError((_) {
        _connectionController.add(RealtimeConnectionState.error);
      })
      ..onError((_) {
        _connectionController.add(RealtimeConnectionState.error);
      })
      ..on('transfer:complete', (data) {
        final payload = _unwrap(data);
        if (payload != null) {
          _eventsController.add(
            TransferCompleteEvent(TransferFile.fromJson(payload)),
          );
        }
      })
      ..on('files:updated', (data) {
        final payload = _unwrap(data);
        final list = payload?['files'] as List?;
        if (list != null) {
          final files = list
              .map((e) => TransferFile.fromJson(e as Map<String, dynamic>))
              .toList();
          _eventsController.add(FilesUpdatedEvent(files));
          _filesController.add(files);
        }
      });

    _socket = socket;
    socket.connect();
  }

  Future<void> disconnectRealtime() async {
    _socket?.dispose();
    _socket = null;
  }

  /// Le serveur enveloppe chaque évènement dans `{"event":..., "data":...}`
  /// (voir `ConnectionManager.broadcast`) : cette aide retourne directement
  /// le contenu de `"data"`.
  Map<String, dynamic>? _unwrap(dynamic raw) {
    var value = raw;
    if (value is List && value.isNotEmpty) value = value.first;
    if (value is Map && value['data'] is Map) {
      return Map<String, dynamic>.from(value['data'] as Map);
    }
    if (value is Map) return Map<String, dynamic>.from(value);
    return null;
  }

  // --------------------------- Aides internes ----------------------------

  Future<Response<Map<String, dynamic>>> _authorizedRequest(
      Future<Response<Map<String, dynamic>>> Function(
          Dio dio,
          Map<String, String> headers,
          ) request,
      ) async {
    _ensurePaired();
    try {
      final response =
      await request(_dio, _authHeaders());
      _throwIfError(response);
      return response;
    } on DioException catch (e) {
      throw ApiException(_describeDioError(e));
    }
  }

  /// En-têtes d'authentification : absents si l'appairage s'est fait sans
  /// jeton (cas du QR pointant simplement vers la page web du serveur).
  Map<String, String> _authHeaders() {
    final token = _token;
    if (token == null || token.isEmpty) return {};
    return {'Authorization': 'Bearer $token'};
  }

  void _ensurePaired() {
    if (!isPaired) {
      throw PairingException(
        'Aucun appareil apparié. Scannez un code QR d\'abord.',
      );
    }
  }

  void _throwIfError(Response response) {
    final status = response.statusCode ?? 0;
    if (status >= 200 && status < 300) return;

    final data = response.data;
    final detail =
    (data is Map && data['detail'] != null) ? data['detail'].toString() : 'Erreur serveur ($status)';

    if (status == 401) {
      throw AuthException(detail, statusCode: status);
    }
    throw ApiException(detail, statusCode: status);
  }

  String _describeDioError(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'Le serveur ne répond pas (délai dépassé).';
      case DioExceptionType.connectionError:
        return 'Connexion impossible. Vérifiez que le PC et le téléphone '
            'sont sur le même réseau Wi-Fi.';
      default:
        return e.message ?? 'Erreur réseau inconnue.';
    }
  }

  void dispose() {
    _socket?.dispose();
    _filesController.close();
    _eventsController.close();
    _connectionController.close();
  }
}