import 'dart:convert';

import 'package:http/http.dart' as http;

/// Adatta un core finto scritto per i percorsi senza account (/folders, /messages/...) all'app
/// multi-account: risponde a GET /accounts con un solo account e toglie il prefisso
/// /accounts/{id} dagli altri percorsi prima di passarli al core finto.
class SingleAccountCore extends http.BaseClient {
  SingleAccountCore(this._inner, {this.id = 'main', this.address = 'me@example.com'});

  final http.Client _inner;
  final String id;
  final String address;

  /// Percorsi ricevuti dall'app, prima della riscrittura (per verificare il prefisso).
  final requestedPaths = <String>[];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    requestedPaths.add(request.url.path);
    if (request.url.path == '/accounts') {
      final body = jsonEncode([
        {'id': id, 'name': address, 'address': address, 'configured': true},
      ]);
      return http.StreamedResponse(Stream.value(utf8.encode(body)), 200,
          headers: {'content-type': 'application/json; charset=utf-8'});
    }
    final prefix = '/accounts/$id/';
    if (!request.url.path.startsWith(prefix)) return _inner.send(request);

    final url = Uri.parse(request.url.toString().replaceFirst(prefix, '/'));
    final copy = http.Request(request.method, url)..headers.addAll(request.headers);
    if (request is http.Request) copy.bodyBytes = request.bodyBytes;
    return _inner.send(copy);
  }
}
