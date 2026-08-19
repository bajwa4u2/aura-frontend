// CH-02 / F068 — `/_boot` MUST NOT BE A PERMANENT SPINNER (root cause RC5).
//
// `/_boot` is the destination-resolution decision point. The router parks a
// cold load there, holds the destination in `?redirect=`, and returns null for
// that path while bootstrap settles — deliberately, so nothing moves the
// person off it.
//
// That is correct while bootstrap is progressing and wrong the moment it is
// not. A hung bootstrap left the person on a bare spinner with no explanation,
// no recovery and no way back. The destination was not lost, but it was
// unreachable, which for the person is the same thing.
//
// THE FIX IS A BOUNDED, HONEST WAIT — NOT A TIMEOUT REDIRECT. A redirect would
// have to decide the person's authentication state at the exact moment it is
// genuinely UNKNOWN, and F065's frozen doctrine is that UNKNOWN/RESTORING IS
// NOT UNAUTHENTICATED. These tests hold both properties at once: the wait ends,
// and it never ends by guessing.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const String kRouter = 'lib/router.dart';

String _bootScreenSource() {
  final src = File(kRouter).readAsStringSync();
  final start = src.indexOf('class _RouterBootScreen');
  expect(start, isNot(-1), reason: 'the boot screen must exist');
  final end = src.indexOf('class GoRouterRefreshStream', start);
  expect(end, isNot(-1), reason: 'could not bound the boot screen');
  return src.substring(start, end);
}

void main() {
  group('F068 — the wait is BOUNDED', () {
    test('the boot screen arms a deadline', () {
      final src = _bootScreenSource();
      expect(RegExp(r'Timer\(').hasMatch(src), isTrue,
          reason: 'Without a deadline the boot screen spins forever whenever '
              'bootstrap hangs. That is RC5.');
      expect(RegExp(r'Duration\(seconds:\s*\d+\)').hasMatch(src), isTrue,
          reason: 'The deadline must be an explicit, readable duration.');
    });

    test('the deadline is cancelled on dispose', () {
      final src = _bootScreenSource();
      expect(src.contains('dispose'), isTrue);
      expect(RegExp(r'_timer\?\.cancel\(\)').hasMatch(src), isTrue,
          reason: 'A timer that outlives its screen calls setState after '
              'dispose.');
    });
  });

  group('F068 — the wait ends HONESTLY, never by guessing', () {
    test('the overdue state offers recovery', () {
      final src = _bootScreenSource();
      expect(src.contains('onRecover'), isTrue,
          reason: 'An overdue boot with no way forward is the same dead end '
              'in different words.');
      expect(RegExp(r'ref\.invalidate\(\s*sessionBootstrapProvider\s*\)').hasMatch(src), isTrue,
          reason: 'Recovery must actually re-run the bootstrap, not merely '
              'redraw the screen.');
    });

    test('it uses the canonical product-state authority, not a bespoke screen', () {
      final src = _bootScreenSource();
      expect(src.contains('AuraProductState'), isTrue);
      expect(src.contains('ProductState.loading'), isTrue);
    });

    test('the boot screen NEVER redirects or decides authentication', () {
      // The critical property. A timeout redirect would have to resolve an
      // UNKNOWN/RESTORING session, and F065's founder-frozen doctrine forbids
      // treating that as unauthenticated. It would also discard the
      // destination the boot route is holding.
      final src = _bootScreenSource();
      for (final forbidden in const [
        'context.go(',
        'context.push(',
        'context.replace(',
        'Navigator.',
        'AuthStatus.',
        'isLoggedIn',
      ]) {
        expect(src.contains(forbidden), isFalse,
            reason: 'The boot screen must not $forbidden — resolving an '
                'unknown session or navigating from here reintroduces F065 '
                'or discards the preserved destination.');
      }
    });
  });

  group('F068 — the destination contract is untouched', () {
    test('the router still parks cold loads on /_boot while bootstrapping', () {
      final src = File(kRouter).readAsStringSync();
      expect(RegExp(r'if \(isBootstrapping\)[\s\S]{0,120}isBootPath\(path\)\)\s*return null')
          .hasMatch(src), isTrue,
          reason: 'The bounded wait must not change WHERE the router waits, '
              'only how long and how honestly.');
    });

    test('the boot route still carries the redirect destination', () {
      final src = File(kRouter).readAsStringSync();
      expect(src.contains(r'$kRouterBootRoute?redirect='), isTrue,
          reason: 'A retry is only useful if the destination survived the wait.');
    });
  });
}
