// Realtime Architecture Correction — Phase 3, amended Gate 2 (2026-08-16),
// founder-directed reconciliation. Dart mirror of aura-backend's
// session-cancelled-reachability-doctrine.spec.ts — see that file's header
// for the full mechanical proof (production RealtimeSession rows are
// created already ACTIVE, host auto-accepted, so canonical `created` is
// never actually reached; the original `created -> cancelled`-only edge
// made `cancelled` unreachable for any real session).

import 'package:flutter_test/flutter_test.dart';
import 'package:aura/core/realtime_canonical/session_lifecycle.dart';

void main() {
  group('SESSION_CANCELLED reachability doctrine (amended 2026-08-16)', () {
    test('active -> cancelled is now legal — the production-reachable path', () {
      final result = applySessionTransition(CanonicalSessionStatus.active, CanonicalSessionStatus.cancelled);
      expect(result.ok, true);
      expect(result.status, CanonicalSessionStatus.cancelled);
    });

    test('created -> cancelled remains legal (unchanged, additive amendment)', () {
      final result = applySessionTransition(CanonicalSessionStatus.created, CanonicalSessionStatus.cancelled);
      expect(result.ok, true);
    });

    test('does not broaden active -> anything else — active still cannot go directly to created', () {
      final result = applySessionTransition(CanonicalSessionStatus.active, CanonicalSessionStatus.created);
      expect(result.ok, false);
    });

    test('terminal-absorbing still holds — cancelled cannot un-cancel back to active via stale delivery', () {
      final result = applySessionTransition(CanonicalSessionStatus.cancelled, CanonicalSessionStatus.active);
      expect(result.ok, false);
      expect(result.error, contains('already terminal'));
    });

    test('cancelled cannot un-cancel back to ended either — terminal is terminal, not just "not active"', () {
      final result = applySessionTransition(CanonicalSessionStatus.cancelled, CanonicalSessionStatus.ended);
      expect(result.ok, false);
    });

    test('ending -> cancelled remains illegal — cancelled is reserved for pre-participation withdrawal, not mid-teardown', () {
      final result = applySessionTransition(CanonicalSessionStatus.ending, CanonicalSessionStatus.cancelled);
      expect(result.ok, false);
    });
  });
}
