import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:url_launcher/url_launcher.dart';

/// WidgetFactory che decide quali immagini caricare: le remote solo se consentite
/// (evita i "pixel di tracciamento"), file locali e asset mai. Le data: (immagini inline) sì.
class SafeWidgetFactory extends WidgetFactory {
  SafeWidgetFactory({required this.allowRemoteImages});

  final bool allowRemoteImages;

  @override
  ImageProvider<Object>? imageProviderFromNetwork(String url) =>
      allowRemoteImages ? super.imageProviderFromNetwork(url) : null;

  @override
  ImageProvider<Object>? imageProviderFromFileUri(String url) => null;

  @override
  ImageProvider<Object>? imageProviderFromAsset(String url) => null;
}

/// Schemi che è sensato aprire fuori dall'app; tutto il resto viene ignorato.
const _allowedLinkSchemes = {'http', 'https', 'mailto'};

bool isOpenableLink(String url) {
  final uri = Uri.tryParse(url);
  return uri != null && _allowedLinkSchemes.contains(uri.scheme.toLowerCase());
}

/// Corpo HTML (già sanificato dal core) reso come widget Flutter, senza webview né JavaScript.
class HtmlBodyView extends StatelessWidget {
  const HtmlBodyView({
    super.key,
    required this.html,
    required this.allowRemoteImages,
    this.buildAsync,
    this.linksEnabled = true,
  });

  final String html;
  final bool allowRemoteImages;

  /// Falso nella posta indesiderata (J2, 4a, come Outlook): un clic su un collegamento non apre niente.
  final bool linksEnabled;

  /// null = scelta del pacchetto (in un isolate sopra 10 000 caratteri); falso nella stampa (P3), disegnata
  /// fuori schermo tutta subito.
  final bool? buildAsync;

  @override
  Widget build(BuildContext context) {
    return HtmlWidget(
      html,
      buildAsync: buildAsync,
      // factoryBuilder deve restituire un'istanza nuova a ogni chiamata.
      factoryBuilder: () => SafeWidgetFactory(allowRemoteImages: allowRemoteImages),
      onTapUrl: linksEnabled ? _openLink : (_) => true,
      textStyle: const TextStyle(height: 1.4),
    );
  }

  /// Apre i link nel browser/client di sistema. Restituisce sempre true: nessuna navigazione interna.
  static Future<bool> _openLink(String url) async {
    if (isOpenableLink(url)) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    }
    return true;
  }
}
