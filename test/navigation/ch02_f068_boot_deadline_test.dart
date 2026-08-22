// CH-02 / F068 + CH-14 CONTINUITY — BOOT IS MACHINERY, NOT A DESTINATION.
//
// F068 fixed a real defect: a hung bootstrap left the person on a bare
// spinner with no explanation and no recovery. Its fix was a BOUNDED, HONEST
// wait that never ends by GUESSING an unknown session, because F065's frozen
// doctrine is that UNKNOWN/RESTORING IS NOT UNAUTHENTICATED.
//
// F068 also asserted WHERE that wait happened: the router parked cold loads on
// `/_boot?redirect=…`. A later founder ruling supersedes that clause, and only
// that clause:
//
//   "Aura must not expose an avoidable intermediate/transit experience, lose
//    the destination, or move the person backward merely because the
//    application cold-started, refreshed, or crossed a release boundary."
//
// Parking navigated Aura's own machinery into the address bar
// (`/_boot?redirect=/articles/…` instead of the article), pushed a transit
// page into history, and made a reload during restore re-enter `_boot`.
//
// So the WAIT MOVED and its PROPERTIES DID NOT. These tests now hold both:
// F068's guarantees, at the new location, plus the continuity guarantee that
// the location is never left at all.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const String kRouter = 'lib/router.dart';
const String kBootGate = 'lib/core/navigation/boot_gate.dart';

String _bootGateSource() => File(kBootGate).readAsStringSync();

void main() {
  group('F068 — the wait is bounded, honest and recoverable', () {
    test('it still ends, rather than spinning forever', () {
      final src = _bootGateSource();
      expect(src.contains('Duration _deadline'), isTrue);
      expect(RegExp(r'_overdue\s*=\s*true').hasMatch(src), isTrue,
          reason: 'A wait with no end is the defect F068 exists to remove.');
    });

    test('recovery re-runs the bootstrap rather than merely redrawing', () {
      final src = _bootGateSource();
      expect(src.contains('ref.invalidate(sessionBootstrapProvider)'), isTrue);
    });

    test('it uses the canonical product-state authority, not a bespoke screen', () {
      final src = _bootGateSource();
      expect(src.contains('AuraProductState'), isTrue);
      expect(src.contains('ProductState.loading'), isTrue);
    });

    test('it NEVER redirects or decides authentication', () {
      // The critical F065 property, unchanged. Resolving a still-restoring
      // session to signed-out is exactly the defect F065 exists to prevent.
      final src = _bootGateSource();
      for (final forbidden in const [
        'context.go(',
        'context.push(',
        'context.replace(',
        'Navigator.',
        'AuthStatus.',
        'isLoggedIn',
      ]) {
        expect(src.contains(forbidden), isFalse,
            reason: 'The boot gate must not $forbidden — resolving an unknown '
                'session or navigating from here reintroduces F065.');
      }
    });
  });

  group('CONTINUITY — the destination is the URL, and it is never left', () {
    test('the router STAYS PUT while bootstrapping', () {
      final src = File(kRouter).readAsStringSync();
      expect(
        RegExp(r'if \(isBootstrapping\)\s*\{[\s\S]{0,2000}?return null;\s*\}')
            .hasMatch(src),
        isTrue,
        reason: 'Restoring a session is not navigation. Staying at the '
            'intended location is what preserves the URL, history and refresh.',
      );
    });

    test('nothing in the router navigates TO the boot path any more', () {
      final src = File(kRouter).readAsStringSync();
      // The transit page is the thing being removed; an address that is never
      // emitted cannot become a visible destination.
      expect(src.contains(r'$kRouterBootRoute?redirect='), isFalse,
          reason: 'Emitting /_boot?redirect= is what put machinery in the '
              'address bar and a transit page into history.');
      expect(src.contains('bootRedirectFor'), isFalse,
          reason: 'The helper that produced those addresses is retired, not '
              'merely unused.');
    });

    test('the boot gate renders INSTEAD of the child, not on top of it', () {
      // This is why staying put is safe: a destination that never mounts
      // cannot fire requests while authentication is still unknown, which is
      // the real work the old redirect was doing.
      final src = _bootGateSource();
      expect(src.contains('return widget.child;'), isTrue);
      expect(RegExp(r'Stack\s*\(').hasMatch(src), isFalse,
          reason: 'An overlay would leave the destination mounted.');
    });

    test('/_boot still RESOLVES, so an address already in the wild survives', () {
      final src = File(kRouter).readAsStringSync();
      expect(src.contains('if (isBootPath(path))'), isTrue,
          reason: 'A stale /_boot?redirect= in history or a cached bundle must '
              'still reach its destination rather than dead-end.');
    });
  });
}
