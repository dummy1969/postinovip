import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:postinovip/core/core_launcher.dart';

/// Script shell che imita il core: annuncia la porta, mostra se ha ricevuto il token, poi resta
/// in attesa sullo stdin ed esce quando viene chiuso (come StdinWatcher).
Future<String> fakeCore(Directory dir, String body) async {
  final f = File('${dir.path}/fake_core.sh');
  await f.writeAsString('#!/bin/sh\n$body\n');
  await Process.run('chmod', ['+x', f.path]);
  return f.path;
}

void main() {
  final unixOnly = !(Platform.isLinux || Platform.isMacOS) ? 'richiede /bin/sh' : null;
  late Directory tmp;

  setUp(() async => tmp = await Directory.systemTemp.createTemp('postinovip_test'));
  tearDown(() async => tmp.delete(recursive: true));

  test('inheritedEnvironment: toglie le variabili Accounts__* rimaste nel terminale', () {
    expect(
      inheritedEnvironment({
        'PATH': '/usr/bin',
        'Accounts__1__Imap__Password': 'x',
        'ACCOUNTS__0__ID': 'y',
        'Imap__Host': 'h', // formato a un account: ignorato dal core quando ci sono Accounts
      }),
      {'PATH': '/usr/bin', 'Imap__Host': 'h'},
    );
  });

  test('parseReadyLine', () {
    expect(parseReadyLine('POSTINOVIP_READY {"port":42731}'), 42731);
    expect(parseReadyLine('info: avvio...'), isNull);
    expect(parseReadyLine('POSTINOVIP_READY non-json'), isNull);
  });

  test('generateToken: 64 caratteri esadecimali, diverso ogni volta', () {
    final a = generateToken();
    expect(a, matches(RegExp(r'^[0-9a-f]{64}$')));
    expect(generateToken(), isNot(a));
  });

  test('modalità collegata: nessun processo avviato', () async {
    final h = await CoreLauncher.start(
      environment: {'POSTINOVIP_CORE_URL': 'http://127.0.0.1:5080', 'POSTINOVIP_TOKEN': 'x'},
    );
    expect(h.process, isNull);
    expect(h.connection.baseUrl, 'http://127.0.0.1:5080');
  });

  test('avvio: porta dalla riga READY, token passato in ambiente, stop chiude lo stdin', () async {
    final exe = await fakeCore(tmp, r'''
echo "info: avvio"
echo "TOKENLEN ${#POSTINOVIP_TOKEN} MANAGED $POSTINOVIP_MANAGED PORT $Api__Port"
echo 'POSTINOVIP_READY {"port":45678}'
cat > /dev/null
echo "stdin chiuso"
''');

    final h = await CoreLauncher.start(executable: exe, environment: const {});
    expect(h.connection.baseUrl, 'http://127.0.0.1:45678');
    expect(h.connection.token, hasLength(64));
    expect(h.recentOutput, contains('TOKENLEN 64 MANAGED 1 PORT 0'));
    // Il token non compare negli argomenti del processo.
    expect(h.recentOutput.join('\n'), isNot(contains(h.connection.token)));

    await h.stop();
    expect(await h.process!.exitCode, 0); // uscito da solo, non ucciso
  }, skip: unixOnly);

  test('core che termina subito: errore con le ultime righe di output', () async {
    final exe = await fakeCore(tmp, 'echo "Avvio non possibile: POSTINOVIP_TOKEN mancante" >&2\nexit 2');

    await expectLater(
      CoreLauncher.start(executable: exe, environment: const {}),
      throwsA(
        isA<CoreStartException>()
            .having((e) => e.message, 'message', contains('codice 2'))
            .having((e) => e.log, 'log', contains('Avvio non possibile: POSTINOVIP_TOKEN mancante')),
      ),
    );
  }, skip: unixOnly);

  test('core che non risponde: timeout e processo terminato', () async {
    final exe = await fakeCore(tmp, 'sleep 30');

    await expectLater(
      CoreLauncher.start(executable: exe, environment: const {}, timeout: const Duration(seconds: 1)),
      throwsA(isA<CoreStartException>().having((e) => e.message, 'message', contains('non ha risposto'))),
    );
  }, skip: unixOnly);

  test('eseguibile inesistente: messaggio con istruzioni', () async {
    await expectLater(
      CoreLauncher.start(executable: '${tmp.path}/non_esiste', environment: const {}),
      throwsA(isA<CoreStartException>()),
    );
  });
}
