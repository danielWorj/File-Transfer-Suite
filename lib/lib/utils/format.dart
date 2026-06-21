/// utils/format.dart
///
/// Petits utilitaires de formatage partagés par les vues (taille de
/// fichiers, dates) afin d'éviter toute logique dupliquée dans l'UI.
library;

/// Formate un nombre d'octets en libellé lisible : `0 o`, `12 Ko`,
/// `1.2 Mo`, `3.4 Go`… Même logique que `TransferFile.sizeLabel`, mais
/// utilisable sur un total agrégé (somme de plusieurs fichiers).
String formatBytes(int bytes) {
  const units = ['o', 'Ko', 'Mo', 'Go', 'To'];
  if (bytes <= 0) return '0 o';
  double size = bytes.toDouble();
  var unitIndex = 0;
  while (size >= 1024 && unitIndex < units.length - 1) {
    size /= 1024;
    unitIndex++;
  }
  final precision = unitIndex == 0 ? 0 : 1;
  return '${size.toStringAsFixed(precision)} ${units[unitIndex]}';
}

/// Formate une date en `jj/mm/aaaa hh:mm` sans dépendre du package `intl`.
/// Retourne `'—'` si la date est nulle.
String formatDateTime(DateTime? date) {
  if (date == null) return '—';
  final d = date.toLocal();
  String two(int v) => v.toString().padLeft(2, '0');
  return '${two(d.day)}/${two(d.month)}/${d.year} ${two(d.hour)}:${two(d.minute)}';
}
