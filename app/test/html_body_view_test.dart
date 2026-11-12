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
}
