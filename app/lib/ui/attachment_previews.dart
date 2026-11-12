import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';

import '../models/attachment_info.dart';
import 'theme.dart';

/// Allegato come scheda (tappa «Aspetto», V5), come il riquadro di lettura dell'Outlook di oggi: icona del tipo,
/// nome (accorciato con «…») e sotto il tipo di file. Clic: [onPressed] (salva, o apre una mail allegata).
class AttachmentCard extends StatelessWidget {
  const AttachmentCard({super.key, required this.attachment, required this.tooltip, required this.onPressed});

  final AttachmentInfo attachment;
  final String tooltip;
  final VoidCallback onPressed;

  static const width = 220.0;

  /// Tipo mostrato sotto il nome: «Mail» per una mail allegata, altrimenti l'estensione in maiuscolo («PDF»), o
  /// «File» se non ce n'è una.
  static String kindOf(AttachmentInfo a) {
    if (a.contentType == 'message/rfc822') return 'Mail';
    final dot = a.fileName.lastIndexOf('.');
    if (dot <= 0 || dot == a.fileName.length - 1) return 'File';
    final ext = a.fileName.substring(dot + 1);
    return ext.length > 5 || ext.contains('/') ? 'File' : ext.toUpperCase();
  }

  static IconData iconOf(AttachmentInfo a) {
    final kind = kindOf(a);
    if (kind == 'Mail') return FluentIcons.mail_24_regular;
    if (a.contentType.startsWith('image/')) return FluentIcons.image_24_regular;
    return switch (kind) {
      'PDF' => FluentIcons.document_pdf_24_regular,
      'ZIP' || '7Z' || 'RAR' || 'GZ' || 'TAR' => FluentIcons.folder_zip_24_regular,
      'TXT' || 'DOC' || 'DOCX' || 'ODT' || 'RTF' => FluentIcons.document_text_24_regular,
      'XLS' || 'XLSX' || 'ODS' || 'CSV' => FluentIcons.document_table_24_regular,
      _ => FluentIcons.document_24_regular,
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    const radius = BorderRadius.all(Radius.circular(OfficeTheme.radius));
    return Tooltip(
      message: tooltip,
      child: Material(
        color: scheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(color: scheme.outline),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: SizedBox(
            width: width,
            height: 44,
            child: Row(
              children: [
                const SizedBox(width: 10),
                Icon(iconOf(attachment), size: 24, color: scheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        attachment.fileName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium!.copyWith(fontSize: 13),
                      ),
                      Text(
                        kindOf(attachment),
                        maxLines: 1,
                        style: theme.textTheme.bodySmall!.copyWith(fontSize: 11, color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Miniature delle immagini allegate; clic = immagine a tutta finestra con zoom.
/// Le immagini arrivano dal core locale (127.0.0.1), non da Internet.
class AttachmentPreviews extends StatelessWidget {
  const AttachmentPreviews({super.key, required this.images, required this.urlFor, this.headers = const {}});

  final List<AttachmentInfo> images;
  final String Function(AttachmentInfo) urlFor;

  /// Header di autenticazione verso il core.
  final Map<String, String> headers;

  static const _thumbHeight = 120.0;

  @override
  Widget build(BuildContext context) {
    // Decodifica alla risoluzione della miniatura: evita di tenere in memoria foto da molti megapixel.
    final cacheHeight = (_thumbHeight * MediaQuery.devicePixelRatioOf(context)).round();

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final a in images)
          Tooltip(
            message: a.fileName,
            child: InkWell(
              onTap: () => _openFull(context, a),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.network(
                  urlFor(a),
                  headers: headers,
                  height: _thumbHeight,
                  cacheHeight: cacheHeight,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, progress) => progress == null
                      ? child
                      : const SizedBox(
                          width: _thumbHeight,
                          height: _thumbHeight,
                          child: Center(child: CircularProgressIndicator()),
                        ),
                  errorBuilder: (context, error, stack) => const SizedBox(
                    width: _thumbHeight,
                    height: _thumbHeight,
                    child: Center(child: Icon(Icons.broken_image)),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  void _openFull(BuildContext context, AttachmentInfo a) {
    showDialog<void>(
      context: context,
      builder: (context) => Dialog.fullscreen(
        child: Scaffold(
          appBar: AppBar(title: Text(a.fileName)),
          body: InteractiveViewer(
            maxScale: 8,
            child: Center(child: Image.network(urlFor(a), headers: headers)),
          ),
        ),
      ),
    );
  }
}
