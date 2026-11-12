import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:postinovip/about/licenses.dart';
import 'package:postinovip/api/api_client.dart';
import 'package:postinovip/app_info.dart';
import 'package:postinovip/main.dart';

import 'single_account_core.dart';

MockClient core(String coreVersion) => MockClient((request) async {
  http.Response json(Object body) =>
      http.Response(jsonEncode(body), 200, headers: {'content-type': 'application/json; charset=utf-8'});
  switch (request.url.path) {
    case '/version':
      return json({'version': coreVersion, 'runtime': '.NET 10.0.13', 'os': 'Linux 7.0'});
    case '/folders':
      return json([]);
  }
  return http.Response('{}', 404);
});

Future<void> openAbout(WidgetTester tester, String coreVersion) async {
  tester.view.physicalSize = const Size(1400, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(PostinoVipApp(api: ApiClient(httpClient: SingleAccountCore(core(coreVersion)))));
  await tester.pumpAndSettle();
  await tester.tap(find.text('File'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Informazioni su PostinoVip'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Informazioni: versione, copyright, assenza di garanzia, versione del core', (tester) async {
    await openAbout(tester, appVersion);

    expect(find.text('Versione $appVersion'), findsOneWidget);
    expect(find.text('© 2026 Marcello Anderlini'), findsOneWidget);
    expect(find.textContaining('SENZA ALCUNA GARANZIA'), findsOneWidget);
    expect(find.textContaining('AGPL-3.0-or-later'), findsOneWidget);
    expect(find.text('Core: versione $appVersion'), findsOneWidget);
    expect(find.textContaining('versioni diverse'), findsNothing);
    expect(find.text('Visualizza licenze'), findsOneWidget); // testi di Flutter in italiano
  });

  testWidgets('core di un\'altra versione: avviso', (tester) async {
    await openAbout(tester, '0.0.1');

    expect(find.textContaining('app e core hanno versioni diverse'), findsOneWidget);
  });

  test('licenze registrate: PostinoVip (AGPL) e librerie del core', () async {
    registerLicenses();
    final entries = await LicenseRegistry.licenses.toList();
    final packages = entries.expand((e) => e.packages).toSet();

    expect(packages, containsAll(['PostinoVip', 'MailKit', 'MimeKit', 'HtmlSanitizer', 'AngleSharp', '.NET runtime',
        'Microsoft.Data.Sqlite', 'SQLitePCLRaw', 'SQLite']));
    final agpl = entries.firstWhere((e) => e.packages.contains('PostinoVip'));
    expect(agpl.paragraphs.first.text, contains('GNU AFFERO GENERAL PUBLIC LICENSE'));
    // Il carattere Inter incluso nell'app (tappa «Aspetto», V1): SIL OFL 1.1.
    final inter = entries.firstWhere((e) => e.packages.contains('Inter (carattere)'));
    expect(inter.paragraphs.map((p) => p.text).join(' '), contains('SIL Open Font License, Version 1.1'));
  });
}
