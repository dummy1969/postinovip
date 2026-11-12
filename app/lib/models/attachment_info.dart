/// Allegato elencato nel dettaglio messaggio; [index] lo identifica nell'endpoint degli allegati.
class AttachmentInfo {
  const AttachmentInfo({required this.index, required this.fileName, required this.contentType});

  final int index;
  final String fileName;
  final String contentType;

  factory AttachmentInfo.fromJson(Map<String, dynamic> json) => AttachmentInfo(
        index: json['index'] as int,
        fileName: json['fileName'] as String,
        contentType: json['contentType'] as String,
      );

  // Formati che il decoder di immagini di Flutter gestisce su tutte le piattaforme.
  static const _previewable = {'image/jpeg', 'image/png', 'image/gif', 'image/webp', 'image/bmp'};

  bool get isPreviewableImage => _previewable.contains(contentType.toLowerCase());
}
