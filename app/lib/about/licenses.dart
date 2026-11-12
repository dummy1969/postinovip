import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Licenze mostrate nella pagina "Licenze": quella di PostinoVip e quelle delle librerie del core
/// (C#, incluse nel pacchetto) e del carattere Inter. Le licenze dei pacchetti Dart le aggiunge Flutter da solo.
/// (xclip, incluso da quill_native_bridge_linux, viene tolto dai pacchetti: vedi build-bundle.sh.)
const _entries = [
  (['PostinoVip'], 'assets/licenses/AGPL-3.0.txt'),
  (['Inter (carattere)'], 'assets/licenses/inter.txt'),
  (['MailKit', 'MimeKit'], 'assets/licenses/mailkit-mimekit.txt'),
  (['HtmlSanitizer'], 'assets/licenses/htmlsanitizer.txt'),
  (['AngleSharp'], 'assets/licenses/anglesharp.txt'),
  (['AngleSharp.Css'], 'assets/licenses/anglesharp-css.txt'),
  (['BouncyCastle.Cryptography'], 'assets/licenses/bouncycastle.txt'),
  (['Ical.Net'], 'assets/licenses/ical-net.txt'),
  (['NodaTime'], 'assets/licenses/nodatime.txt'),
  (['SQLitePCLRaw'], 'assets/licenses/sqlitepclraw.txt'),
  (['SQLite'], 'assets/licenses/sqlite.txt'),
  (['.NET runtime', 'ASP.NET Core'], 'assets/licenses/dotnet.txt'),
  (
    ['Microsoft.AspNetCore.OpenApi', 'Microsoft.OpenApi', 'System.Security.Cryptography.Pkcs', 'Microsoft.Data.Sqlite'],
    'assets/licenses/microsoft-packages.txt',
  ),
];

/// Da chiamare una volta all'avvio, prima di runApp: i testi vengono letti solo quando si apre la pagina.
void registerLicenses() {
  LicenseRegistry.addLicense(() async* {
    for (final (packages, asset) in _entries) {
      yield LicenseEntryWithLineBreaks(packages, await rootBundle.loadString(asset));
    }
  });
}
