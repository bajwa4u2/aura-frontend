import 'dart:convert';
import 'dart:typed_data';

import 'package:aura/features/admin/data/admin_models.dart';
import 'package:aura/features/admin/data/admin_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// CLOSING AN ACCOUNT FROM THE CONSOLE (2026-10-27).
///
/// An operator could disable an account but never end one; only the person
/// could, with their password, so an abandoned sign-up stayed forever.
class _Capture implements HttpClientAdapter {
  RequestOptions? last;
  Object? body;
  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<Uint8List>? s, Future<void>? c) async {
    last = o;
    body = o.data;
    return ResponseBody.fromString(
      jsonEncode({'ok': true, 'data': {'ok': true, 'userId': 'u-1'}}),
      200,
      headers: {Headers.contentTypeHeader: ['application/json']},
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  test('closing posts the reason to the operator route', () async {
    final cap = _Capture();
    final dio = Dio(BaseOptions(baseUrl: 'https://api.test'))..httpClientAdapter = cap;
    await AdminRepository(dio).closeAccount('u-1', reason: 'Duplicate sign-up');
    expect(cap.last!.method, 'POST');
    expect(cap.last!.path, '/v1/admin/users/u-1/close');
    expect(cap.body, {'reason': 'Duplicate sign-up'});
  });

  test('a closed account reads as ended, with its recovery date', () {
    final p = AdminPersonDetail.fromJson({
      'id': 'u-1',
      'handle': 'deleted',
      'displayName': 'Deleted user',
      'email': 'deleted_u-1@deleted.aura.invalid',
      'status': 'DISABLED',
      'accountEnded': true,
      'recoverableUntil': '2026-11-27T02:40:00.000Z',
      'createdAt': '2026-10-28T00:34:19.000Z',
    });
    expect(p.accountEnded, isTrue);
    expect(p.isDisabled, isTrue);
    expect(p.recoverableUntil, DateTime.parse('2026-11-27T02:40:00.000Z'));
  });

  test('an account the server says nothing about is not ended', () {
    final p = AdminPersonDetail.fromJson({
      'id': 'u-2',
      'handle': 'p',
      'displayName': 'P',
      'email': 'p@example.test',
      'status': 'DISABLED',
      'createdAt': '2026-10-28T00:34:19.000Z',
    });
    expect(p.accountEnded, isFalse);
    expect(p.recoverableUntil, isNull);
  });
}
