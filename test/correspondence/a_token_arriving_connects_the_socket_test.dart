import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// C-6 — A TOKEN ARRIVING IS THE MOMENT TO CONNECT.
///
/// Founder-observed (Film A, capture 6): a web conversation did not show
/// messages sent from the other device until the page was reloaded.
///
/// The server was not at fault. `conversation:message.created` has been
/// emitted to every party's user room since 2026-08-23, and the conversation
/// screen listens for it and re-reads the canonical projection. The socket
/// carrying it was simply never connected.
///
/// Three facts had to line up, and each is individually sensible:
///
///   1. `ensureConnected()` returns immediately while the token is empty —
///      correct, an unauthenticated app must not open an authenticated socket;
///   2. the only boot-time call is `RealtimeReconciliationController`, which
///      initialises BEFORE the session is restored, so it makes exactly that
///      empty-token no-op — and never tries again;
///   3. `updateAccessToken`, the one thing that HEARS the token arrive, only
///      refreshed the credentials of an existing socket and returned when
///      there was none.
///
/// So nothing in the system connected on the transition from "no token" to
/// "token". Every remaining caller is incidental — app RESUME, opening
/// Invitations, starting a thread call — and on the web none of them happen:
/// a page load restores the session asynchronously, and a tab that was never
/// hidden never fires `resumed`.
///
/// The blast radius is wider than messages. Feed convergence, invitations and
/// the Messages badge all ride this one socket, so all of them were silent on
/// the same clients for the same reason.
void main() {
  final src = File(
    'lib/features/correspondence/data/correspondence_live_service.dart',
  ).readAsStringSync();

  /// `updateAccessToken`, from its signature to the start of the next method.
  final updateToken = (() {
    final start = src.indexOf('void updateAccessToken(String token) {');
    if (start < 0) throw StateError('updateAccessToken is gone');
    final end = src.indexOf('Future<void> joinSpace(', start);
    if (end < 0) throw StateError('could not bound updateAccessToken');
    return src.substring(start, end);
  })();

  group('the transition from no-token to token opens the socket', () {
    test('a token with no socket connects instead of returning', () {
      expect(updateToken, contains('ensureConnected()'),
          reason: 'nothing else in the app watches for a token to appear');
    });

    test('it does not simply return when there is no socket', () {
      expect(updateToken, isNot(contains('if (socket == null) return;')),
          reason: 'this is the exact line that left web permanently silent');
    });

    test('a socket that exists but is disconnected also reconnects', () {
      expect(updateToken, contains('socket == null || !socket.connected'));
    });

    test('an empty token still connects nothing', () {
      // The guard that keeps an unauthenticated app from opening an
      // authenticated socket has to survive the repair.
      expect(updateToken, contains('if (normalized.isEmpty) return;'));
      expect(
        updateToken.indexOf('if (normalized.isEmpty) return;'),
        lessThan(updateToken.indexOf('ensureConnected()')),
        reason: 'the empty-token guard must come first',
      );
    });

    test('the credential refresh for a LIVE socket is unchanged', () {
      // The method's original job — keeping an existing socket's auth fresh so
      // its own reconnects carry a valid token — must still happen.
      expect(updateToken, contains('socket.auth = auth;'));
      expect(updateToken, contains("extraHeaders['Authorization'] = 'Bearer"));
    });

    test('the reason is kept where the early return was', () {
      expect(updateToken, contains('A TOKEN ARRIVING IS THE MOMENT TO CONNECT'));
    });
  });

  final ensure = (() {
    final start = src.indexOf('Future<void> ensureConnected() async {');
    if (start < 0) throw StateError('ensureConnected is gone');
    final end = src.indexOf('void updateAccessToken(', start);
    if (end < 0) throw StateError('could not bound ensureConnected');
    return src.substring(start, end);
  })();

  group('ensureConnected still refuses an unauthenticated boot', () {
    test('it reads the token and returns when empty', () {
      expect(ensure, contains("accessToken?.trim() ?? ''"));
      expect(ensure, contains('if (token.isEmpty) return;'));
    });

    test('an already-connected socket on the same token is left alone', () {
      expect(
        ensure,
        contains('if (_socket != null && _socket!.connected && '
            '_activeToken == token) return;'),
      );
    });
  });

  group('overlapping callers share one attempt', () {
    test('there is a single-flight slot', () {
      // `_connect` opens with `await disconnect()`, so two concurrent attempts
      // tear each other's socket down mid-setup. Harmless while connecting was
      // rare and incidental; not once a token arriving connects too, because a
      // token refresh landing during a reconnect is exactly that overlap.
      expect(src, contains('Future<void>? _connecting;'));
      expect(ensure, contains('final inFlight = _connecting;'));
      expect(ensure, contains('if (inFlight != null) return inFlight;'));
    });

    test('the slot is released, and only by the attempt that owns it', () {
      expect(ensure, contains('if (identical(_connecting, attempt))'),
          reason: 'a superseded attempt clearing the slot would let the next '
              'overlap through unguarded');
      expect(ensure, contains('} finally {'),
          reason: 'a failed connect must not wedge the slot forever');
    });
  });
}
