/// The one reader of Aura's response envelope.
///
/// The backend wraps every JSON answer once, in `ResponseWrapInterceptor`:
/// `{ ok: true, data: <value>, meta?: {...} }`. Screens used to unwrap it by
/// hand with chains such as `root['data'] ?? root['items'] ?? root`, which
/// turned a changed or broken answer into an empty list instead of an error.
/// [unwrapEnvelope] accepts exactly the envelope and throws
/// [ApiEnvelopeException] for anything else, so a contract break is seen.
class ApiEnvelopeException implements Exception {
  const ApiEnvelopeException(this.reason, {this.code});

  /// What was wrong with the answer, for logs (never shown to people).
  final String reason;

  /// The server's error code when the envelope carried `ok: false`.
  final String? code;

  @override
  String toString() =>
      'ApiEnvelopeException($reason${code == null ? '' : ', $code'})';
}

/// The `data` of a successful envelope. Throws on `ok: false` or any other shape.
Object? unwrapEnvelope(Object? body) {
  if (body is! Map) {
    throw ApiEnvelopeException('not an envelope: ${body.runtimeType}');
  }
  final ok = body['ok'];
  if (ok == true) {
    if (!body.containsKey('data')) {
      throw const ApiEnvelopeException('envelope without data');
    }
    return body['data'];
  }
  if (ok == false) {
    final error = body['error'];
    final code = error is Map ? error['code']?.toString() : null;
    throw ApiEnvelopeException('envelope reports failure', code: code);
  }
  throw const ApiEnvelopeException('envelope without ok');
}

/// [unwrapEnvelope] whose `data` must be a JSON object.
Map<String, dynamic> unwrapEnvelopeMap(Object? body) {
  final data = unwrapEnvelope(body);
  if (data is Map) return Map<String, dynamic>.from(data);
  throw ApiEnvelopeException('data is ${data.runtimeType}, expected an object');
}

/// [unwrapEnvelope] whose `data` must be a list of JSON objects, either the
/// list itself or under [key] in an object.
List<Map<String, dynamic>> unwrapEnvelopeList(Object? body, {String? key}) {
  final data = unwrapEnvelope(body);
  final list = key == null ? data : (data is Map ? data[key] : null);
  if (list is! List) {
    throw ApiEnvelopeException(
      key == null ? 'data is not a list' : 'data.$key is not a list',
    );
  }
  return list
      .whereType<Map>()
      .map((e) => Map<String, dynamic>.from(e))
      .toList();
}
