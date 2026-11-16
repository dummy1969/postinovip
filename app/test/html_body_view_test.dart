import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:postinovip/ui/html_body_view.dart';

void main() {
  test('immagini remote bloccate finché non consentite', () {
    expect(SafeWidgetFactory(allowRemoteImages: false).imageProviderFromNetwork('https://t.example/p.gif'), isNull);
    expect(SafeWidgetFactory(allowRemoteImages: true).imageProviderFromNetwork('https://t.example/p.gif'), isNotNull);
  });

  test('file locali e asset mai caricati', () {
    final f = SafeWidgetFactory(allowRemoteImages: true);
    expect(f.imageProviderFromFileUri('file:///etc/passwd'), isNull);
    expect(f.imageProviderFromAsset('asset:foo.png'), isNull);
  });

  test('solo link http, https e mailto sono apribili', () {
    expect(isOpenableLink('https://example.com'), isTrue);
    expect(isOpenableLink('HTTP://example.com'), isTrue);
    expect(isOpenableLink('mailto:a@example.com'), isTrue);
    expect(isOpenableLink('file:///etc/passwd'), isFalse);
    expect(isOpenableLink('javascript:alert(1)'), isFalse);
    expect(isOpenableLink('data:text/html,ciao'), isFalse);
  });

  // Avvisi di sicurezza di Google (come arrivano dal core, già senza min-width): tabella con max-width e colonnine
  // vuote da 8 px ai lati. Dentro una Column con stretch (riquadro di lettura) il testo finiva in una colonna di
  // 130 px; prima della correzione del core, con min-width, di 33 px.
  testWidgets('tabella con max-width e colonnine ai lati: il testo usa la larghezza (mail di Google)', (tester) async {
    const html = '''
<table width="100%" border="0" cellspacing="0" cellpadding="0"><tbody>
<tr height="32" style="height: 32px"><td></td></tr>
<tr align="center"><td>
<table border="0" cellspacing="0" cellpadding="0" style="padding-bottom: 20px; max-width: 516px"><tbody><tr>
<td width="8" style="width: 8px"></td>
<td><div style="border: thin solid #dadce0; padding: 40px 20px" align="center">
<div style="font-size: 24px">Avviso di prova con un testo abbastanza lungo da andare a capo più volte</div>
</div></td>
<td width="8" style="width: 8px"></td>
</tr></tbody></table>
</td></tr></tbody></table>''';
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [HtmlBodyView(html: html, allowRemoteImages: false, buildAsync: false)],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final text = find.byWidgetPredicate((w) => w is RichText && w.text.toPlainText().contains('Avviso di prova'));
    expect(tester.getSize(text.first).width, greaterThan(400)); // 516 - spaziatori - padding; prima 130
  });
}
