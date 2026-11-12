/// Dati locali (mail scaricate, indice di ricerca) di un account non più configurato nell'app.
class OrphanCache {
  const OrphanCache({
    required this.id,
    this.name,
    this.address,
    required this.sizeBytes,
    this.localOnly = false,
    this.contacts = 0,
  });

  final String id;
  final String? name;

  /// Indirizzo della casella; null per i dati salvati prima che il core lo annotasse.
  final String? address;
  final int sizeBytes;

  /// Mail di un account POP3: sono l'unica copia (eliminarle le perde per sempre).
  final bool localOnly;

  /// Contatti della rubrica dell'account (C2): anche questi sono solo su questo computer.
  final int contacts;

  /// Cosa mostrare: indirizzo, altrimenti l'identificativo interno.
  String get label => address ?? 'account $id';

  factory OrphanCache.fromJson(Map<String, dynamic> json) => OrphanCache(
    id: json['id'] as String,
    name: json['name'] as String?,
    address: json['address'] as String?,
    sizeBytes: (json['sizeBytes'] as num).toInt(),
    localOnly: json['localOnly'] as bool? ?? false,
    contacts: (json['contacts'] as num?)?.toInt() ?? 0,
  );
}

/// Dimensione leggibile: "350 KB", "12,4 MB".
String formatSize(int bytes) {
  if (bytes < 1024 * 1024) return '${(bytes / 1024).ceil()} KB';
  return '${(bytes / 1024 / 1024).toStringAsFixed(1).replaceAll('.', ',')} MB';
}
