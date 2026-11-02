import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aura/features/realtime/application/realtime_controller.dart';

/// A CALL THE SERVER ENDED MUST END ON THIS SIDE TOO.
///
/// 2026-11-02, session cmvzgmxur: declined on the Android call screen, ended on
/// the server, and the caller's browser re-opened the stage every 10 s for
/// 51 s, refused each time with `stage:session_not_active`.
void main() {
  group('the refusal is recognised', () {
    test('the stage refusal, as the browser received it', () {
      final e = DioException(
        requestOptions: RequestOptions(path: '/stage/transport'),
        message: 'This session is not active [stage:session_not_active]',
      );
      expect(isStageSessionNotActive(e), isTrue);
    });

    test('other failures are not read as an ended call', () {
      expect(isStageSessionNotActive(StateError('ice timeout [sfu:ice_timeout]')),
          isFalse);
    });

    test('only a status no call returns from counts as over', () {
      for (final s in ['ENDED', 'CANCELLED', 'FAILED', 'ended']) {
        expect(isEndedSessionStatus(s), isTrue, reason: s);
      }
      for (final s in ['ACTIVE', 'SCHEDULED', '']) {
        expect(isEndedSessionStatus(s), isFalse, reason: s);
      }
    });
  });

  test('the refusal is checked against the session before ending', () {
    final source = File(
      'lib/features/realtime/application/realtime_controller.dart',
    ).readAsStringSync();
    final start = source.indexOf('Future<void> _endIfSessionOver(');
    expect(start, greaterThan(-1));
    final body = source.substring(start, source.indexOf('catch (_) {}', start));
    expect(body, contains('forceRefresh: true'),
        reason: 'a cached ACTIVE snapshot must not decide');
    expect(body, contains('isEndedSessionStatus(bundle.session.status)'));
    expect(source, contains('if (isStageSessionNotActive(e)) {'));
  });
}
