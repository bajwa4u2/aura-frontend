import 'dart:convert';
import 'dart:typed_data';

import 'package:aura/features/auth/auth_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// SIGN-UP READS THE SERVER'S ONE ENVELOPE (2026-10-27).
///
/// The server's register result carries its own `ok: true`; the response
/// wrapper used to take that for a finished envelope and send it with no
/// `data`. This reader requires `data`, so every sign-up from 21 Oct 2026
/// showed "We could not create your account" after the account had been
/// created (two accounts on a Galaxy S24, 27 Oct). The server now wraps it;
/// these tests hold the reply it sends.
class _Reply implements HttpClientAdapter {
  _Reply(this.body);
  final Object body;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString(jsonEncode(body), 201, headers: {
      Headers.contentTypeHeader: ['application/json; charset=utf-8'],
    });
  }

  @override
  void close({bool force = false}) {}
}

Future<Map<String, dynamic>> _register(Object reply) {
  final dio = Dio(BaseOptions(baseUrl: 'https://api.test'))
    ..httpClientAdapter = _Reply(reply);
  return AuthRepository(dio).register(
    email: 'person@example.com',
    password: 'password123',
    handle: 'person',
    displayName: 'Person',
    firstName: 'P',
    lastName: 'S',
    dateOfBirth: '1980-01-01',
    jurisdiction: 'US',
    termsAccepted: true,
    termsAcceptedVersion: 'v1',
  );
}

void main() {
  const result = {
    'ok': true,
    'user': {'id': 'u1', 'handle': 'person', 'emailVerifiedAt': null},
    'emailSent': true,
    'requiresEmailVerification': true,
  };

  test('the reply the server sends for a new account is a success', () async {
    final out = await _register({'ok': true, 'data': result});
    expect(out['emailSent'], isTrue);
    expect(out['requiresEmailVerification'], isTrue);
    expect((out['user'] as Map)['id'], 'u1');
  });

  test('an account created without its email still reaches the next step', () async {
    final out = await _register({
      'ok': true,
      'data': {...result, 'emailSent': false},
    });
    expect(out['emailSent'], isFalse);
  });
}
