/// service/zip_service.dart
///
/// Service pur (sans Flutter) qui regroupe des fichiers locaux dans une
/// archive `.zip` puis la propose au partage / téléchargement via la
/// feuille de partage du système (`share_plus`).
///
/// Utilisé par `controller/bundle_controller.dart`, qui s'occupe d'abord
/// de télécharger les fichiers depuis le PC (API `/api/download`) avant de
/// les passer ici.
///
/// Dépendances pubspec requises :
///   archive: ^3.6.1
///   path_provider: ^2.1.4
///   share_plus: ^10.1.2
library;

import 'dart:io';

import 'package:archive/archive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class ZipService {
  ZipService._();

  /// Crée une archive ZIP contenant [files] dans le dossier temporaire de
  /// l'application et retourne le fichier `.zip` produit.
  ///
  /// Les noms en double sont automatiquement suffixés (`rapport.pdf`,
  /// `rapport_1.pdf`, …) pour éviter l'écrasement à l'intérieur de l'archive.
  /// Les fichiers introuvables sur le disque sont ignorés silencieusement.
  static Future<File> createZip(
    List<File> files, {
    String baseName = 'fts_export',
  }) async {
    final archive = Archive();
    final usedNames = <String>{};

    for (final file in files) {
      if (!await file.exists()) continue;

      final bytes = await file.readAsBytes();
      final entryName = _uniqueName(_fileName(file), usedNames);
      usedNames.add(entryName);

      archive.addFile(ArchiveFile(entryName, bytes.length, bytes));
    }

    if (archive.files.isEmpty) {
      throw const ZipException('Aucun fichier valide à compresser.');
    }

    final encoded = ZipEncoder().encode(archive);
    if (encoded == null) {
      throw const ZipException('Échec de la compression de l\'archive.');
    }

    final dir = await getTemporaryDirectory();
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final zipPath =
        '${dir.path}${Platform.pathSeparator}${baseName}_$stamp.zip';

    final zipFile = File(zipPath);
    await zipFile.writeAsBytes(encoded, flush: true);
    return zipFile;
  }

  /// Ouvre la feuille de partage du système pour [zip] : l'utilisateur peut
  /// alors l'enregistrer dans Fichiers, l'envoyer par mail, etc. C'est
  /// l'équivalent mobile d'un « téléchargement ».
  ///
  /// ⚠️ API de share_plus 10.x. Sur share_plus ≥ 11, remplacez par :
  ///   await SharePlus.instance.share(ShareParams(files: [XFile(zip.path)]));
  static Future<void> shareZip(File zip, {String? text}) async {
    await Share.shareXFiles(
      [XFile(zip.path, mimeType: 'application/zip')],
      text: text ?? 'Fichiers FTS',
      subject: 'Export FTS',
    );
  }

  // --------------------------- Helpers ---------------------------

  static String _fileName(File file) {
    final segments = file.uri.pathSegments;
    if (segments.isNotEmpty && segments.last.isNotEmpty) return segments.last;
    return file.path.split(Platform.pathSeparator).last;
  }

  static String _uniqueName(String name, Set<String> used) {
    if (!used.contains(name)) return name;
    final dot = name.lastIndexOf('.');
    final stem = dot > 0 ? name.substring(0, dot) : name;
    final ext = dot > 0 ? name.substring(dot) : '';
    var counter = 1;
    var candidate = '${stem}_$counter$ext';
    while (used.contains(candidate)) {
      counter++;
      candidate = '${stem}_$counter$ext';
    }
    return candidate;
  }
}

/// Erreur émise par [ZipService] lors de la création de l'archive.
class ZipException implements Exception {
  const ZipException(this.message);
  final String message;

  @override
  String toString() => 'ZipException: $message';
}
