import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api/api_client.dart';
import '../app_info.dart';

/// Finestra "Informazioni su PostinoVip": versione di app e core, copyright e note legali
/// richieste dalla AGPL (sezione 5d: copyright, assenza di garanzia, licenza e come leggerla).
/// "Visualizza licenze" apre l'elenco: PostinoVip, librerie del core e pacchetti Dart.
void showPostinoVipAbout(BuildContext context) {
  final api = context.read<ApiClient>();
  showAboutDialog(
    context: context,
    applicationName: appName,
    applicationVersion: 'Versione $appVersion',
    applicationIcon: Image.asset('assets/icon.png', width: 64, height: 64),
    applicationLegalese: appCopyright,
    children: [
      const SizedBox(height: 16),
      const Text('Client di posta desktop: interfaccia in Flutter, core in C# con MailKit.'),
      const SizedBox(height: 12),
      _CoreVersion(api: api),
      const SizedBox(height: 12),
      const Text(
        'Questo programma è software libero: puoi ridistribuirlo e/o modificarlo secondo i termini della '
        '$appLicenseName, pubblicata dalla Free Software Foundation.\n\n'
        'È distribuito nella speranza che sia utile, ma SENZA ALCUNA GARANZIA, nemmeno quella implicita di '
        'COMMERCIABILITÀ o di IDONEITÀ A UN PARTICOLARE SCOPO. Il testo completo della licenza è in '
        '"Visualizza licenze" → PostinoVip.',
      ),
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
    return FutureBuilder(
      future: api.getVersion(),
      builder: (context, snap) {
        if (snap.hasError) return Text('Core: versione non disponibile (${snap.error})', style: style);
        final v = snap.data;
        if (v == null) return Text('Core: …', style: style);
        final mismatch = v.version != appVersion;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Core: versione ${v.version}', style: style),
            if (mismatch)
              Text(
                'Attenzione: app e core hanno versioni diverse (ricompilare il core).',
                style: style?.copyWith(color: Theme.of(context).colorScheme.error),
              ),
            Text('${v.runtime} · ${v.os}', style: style),
          ],
        );
      },
    );
  }
}
