import 'package:flutter_test/flutter_test.dart';
import 'package:postinovip/ui/html_to_text.dart';

void main() {
  test('rimuove tag, style e script e decodifica le entità', () {
    const html = '<html><head><style>p{color:red}</style></head><body>'
        '<script>alert(1)</script><p>Ciao&nbsp;Mario,</p><p>il prezzo &egrave; 10&euro; &amp; IVA</p>'
        'riga1<br>riga2 &#8364; &#x41;</body></html>';

    expect(htmlToText(html), 'Ciao Mario,\nil prezzo è 10€ & IVA\nriga1\nriga2 € A');
  });

  test('comprime le righe vuote ripetute', () {
    expect(htmlToText('<div>a</div><div></div><div></div><div></div><div>b</div>'), 'a\n\nb');
  });
}
