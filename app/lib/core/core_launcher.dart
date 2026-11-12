import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';

/// Dove raggiungere il core e con quale token.
class CoreConnection {
  const CoreConnection({required this.baseUrl, required this.token});

  final String baseUrl;
  final String token;
}

/// Il core non è partito; [log] contiene le ultime righe di output utili alla diagnosi.
class CoreStartException implements Exception {
  const CoreStartException(this.message, {this.log = const []});

  final String message;
  final List<String> log;

  @override
  String toString() => message;
}

/// Core in esecuzione (o, in modalità "collegata", avviato a mano: [process] è null).
class CoreHandle {
  CoreHandle._(this.connection, this.process, this._output);

  /// Core non avviato da noi (avvio manuale o test): stop() non fa nulla.
  factory CoreHandle.external(CoreConnection connection) => CoreHandle._(connection, null, _OutputTail());

  final CoreConnection connection;
  final Process? process;
  final _OutputTail _output;

  List<String> get recentOutput => _output.lines;

  /// Chiude lo stdin: il core (StdinWatcher) si ferma da solo. Se non esce entro [grace], viene terminato.
  Future<void> stop({Duration grace = const Duration(seconds: 5)}) async {
    final p = process;
    if (p == null) return;
    await p.stdin.close();
    try {
      await p.exitCode.timeout(grace);
    } on TimeoutException {
      p.kill();
    }
  }
}

/// Estrae la porta dalla riga `POSTINOVIP_READY {"port":N}` stampata dal core all'avvio.
int? parseReadyLine(String line) {
  const prefix = 'POSTINOVIP_READY ';
  final i = line.indexOf(prefix);
  if (i < 0) return null;
  try {
    final json = jsonDecode(line.substring(i + prefix.length)) as Map<String, dynamic>;
    return json['port'] as int?;
  } on Object {
    return null;
  }
}

/// Ambiente del processo padre senza le variabili Accounts__*: gli account del core li decide solo
/// l'app. Altrimenti variabili rimaste in un terminale (es. da prove manuali del core) verrebbero
/// unite a quelle dell'app e il core vedrebbe account incompleti. Il confronto ignora le maiuscole,
/// come la configurazione di .NET.
Map<String, String> inheritedEnvironment(Map<String, String> env) => {
  for (final e in env.entries)
    if (!e.key.toLowerCase().startsWith('accounts__')) e.key: e.value,
};

/// Token casuale da 32 byte (64 caratteri esadecimali), generato a ogni avvio.
String generateToken() {
  final random = Random.secure();
  return List.generate(32, (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
}

class CoreLauncher {
  /// Avvia il core e attende che sia pronto.
  ///
  /// - Se sono impostate POSTINOVIP_CORE_URL e POSTINOVIP_TOKEN, non avvia nulla e si collega
  ///   a un core avviato a mano (utile per provare con curl in parallelo).
  /// - Altrimenti avvia [executable] (o quello trovato da [findExecutable]) con porta 0.
  /// [extraEnvironment]: variabili aggiuntive per il core (es. dati dell'account).
  static Future<CoreHandle> start({
    String? executable,
    Map<String, String>? environment,
    Map<String, String> extraEnvironment = const {},
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final env = environment ?? Platform.environment;

    final manualUrl = env['POSTINOVIP_CORE_URL'];
    final manualToken = env['POSTINOVIP_TOKEN'];
    if (manualUrl != null && manualToken != null) {
      return CoreHandle._(CoreConnection(baseUrl: manualUrl, token: manualToken), null, _OutputTail());
    }

    final exe = executable ?? findExecutable(env);
    if (exe == null) {
      throw const CoreStartException(
        'Eseguibile del core non trovato. Compilarlo con "cd core && dotnet build" '
        'oppure indicarne il percorso in POSTINOVIP_CORE.',
      );
    }

    final token = generateToken();
    final Process process;
    try {
      process = await Process.start(
        exe,
        const [],
        // Cartella dell'eseguibile: il core vi trova appsettings.json.
        workingDirectory: File(exe).parent.path,
        // Ambiente costruito per intero qui (niente unione automatica con quello del padre).
        includeParentEnvironment: false,
        environment: {
          ...inheritedEnvironment(env),
          ...extraEnvironment,
          'POSTINOVIP_TOKEN': token, // variabile d'ambiente: non visibile con "ps"
          'POSTINOVIP_MANAGED': '1',
          'Api__Port': '0',
          // In sviluppo le credenziali arrivano da user-secrets, caricati solo in Development.
          if (!kReleaseMode) 'ASPNETCORE_ENVIRONMENT': 'Development',
        },
      );
    } on ProcessException catch (e) {
      throw CoreStartException('Impossibile avviare il core ($exe): ${e.message}');
    }

    final output = _OutputTail();
    final ready = Completer<int>();

    // Stdout e stderr vanno letti sempre, anche dopo l'avvio: se nessuno li legge
    // il buffer della pipe si riempie e il core si blocca alla prima scrittura di log.
    void onLine(String line) {
      output.add(line);
      final port = parseReadyLine(line);
      if (port != null && !ready.isCompleted) ready.complete(port);
    }

    final stdoutDone = process.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(onLine)
        .asFuture<void>();
    final stderrDone = process.stderr
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(onLine)
        .asFuture<void>();
    unawaited(
      process.exitCode.then((code) async {
        // Prima si finiscono di leggere le ultime righe (spesso il motivo dell'errore è lì).
        await Future.wait([stdoutDone, stderrDone]).catchError((_) => <void>[]);
        if (!ready.isCompleted) {
          ready.completeError(
            CoreStartException('Il core è terminato durante l\'avvio (codice $code).', log: output.lines),
          );
        }
      }),
    );

    try {
      final port = await ready.future.timeout(timeout);
      return CoreHandle._(CoreConnection(baseUrl: 'http://127.0.0.1:$port', token: token), process, output);
    } on TimeoutException {
      process.kill();
      throw CoreStartException('Il core non ha risposto entro ${timeout.inSeconds} s.', log: output.lines);
    }
  }

  /// Cerca l'eseguibile: POSTINOVIP_CORE, poi accanto all'app (installazione), poi la build di sviluppo.
  static String? findExecutable(Map<String, String> env) {
    final name = Platform.isWindows ? 'PostinoVip.Api.exe' : 'PostinoVip.Api';
    final candidates = [
      ?env['POSTINOVIP_CORE'],
      '${File(Platform.resolvedExecutable).parent.path}/core/$name',
      // "flutter run" parte dalla cartella app/.
      '${Directory.current.path}/../core/src/PostinoVip.Api/bin/Debug/net10.0/$name',
    ];
    for (final c in candidates) {
      if (File(c).existsSync()) return File(c).absolute.path;
    }
    return null;
  }
}

/// Ultime righe di output del core, per mostrarle in caso di errore.
class _OutputTail {
  static const _max = 40;
  final _lines = <String>[];

  List<String> get lines => List.unmodifiable(_lines);

  void add(String line) {
    _lines.add(line);
    if (_lines.length > _max) _lines.removeAt(0);
  }
}
