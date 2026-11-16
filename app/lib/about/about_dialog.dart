import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/api_client.dart';
import '../app_info.dart';
import '../l10n/language.dart';

/// Finestra "Informazioni su PostinoVip": versione di app e core, copyright e note legali
/// richieste dalla AGPL (sezione 5d: copyright, assenza di garanzia, licenza e come leggerla).
/// "Visualizza licenze" apre l'elenco: PostinoVip, librerie del core e pacchetti Dart.
void showPostinoVipAbout(BuildContext context) {
  final api = context.read<ApiClient>();
  final l = context.l10n;
  showAboutDialog(
    context: context,
    applicationName: appName,
    applicationVersion: l.aboutVersion(appVersion),
    applicationIcon: Image.asset('assets/icon.png', width: 64, height: 64),
    applicationLegalese: appCopyright,
    children: [
      const SizedBox(height: 16),
      Text(l.aboutDescription),
      const SizedBox(height: 12),
      _CoreVersion(api: api),
      const SizedBox(height: 12),
      Text(l.aboutLegal(appLicenseName)),
    ],
  );
}

/// Versione del core e ambiente: se differisce da quella dell'app, app e core non sono allineati.
class _CoreVersion extends StatelessWidget {
  const _CoreVersion({required this.api});

  final ApiClient api;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodySmall;
    final l = context.l10n;
    return FutureBuilder(
      future: api.getVersion(),
      builder: (context, snap) {
        if (snap.hasError) return Text(l.coreVersionUnavailable('${snap.error}'), style: style);
        final v = snap.data;
        if (v == null) return Text('Core: …', style: style);
        final mismatch = v.version != appVersion;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l.coreVersion(v.version), style: style),
            if (mismatch)
              Text(
                l.coreVersionMismatch,
                style: style?.copyWith(color: Theme.of(context).colorScheme.error),
              ),
            Text('${v.runtime} · ${v.os}', style: style),
          ],
        );
      },
    );
  }
}
