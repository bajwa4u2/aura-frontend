// CH-02 S3 — DESTINATION RECONSTRUCTION CONTRACT GATE
//
// The contract lives at docs/governance/CH02_DESTINATION_RECONSTRUCTION_CONTRACT.md
// and carries the PD-2 seam enumeration required by the founder ruling of
// 2026-08-18. This gate binds each clause to the code that satisfies it.
//
// WHY A GATE AND NOT JUST A DOCUMENT. A published contract that nothing checks
// decays into a description of what the code used to do. The register already
// records that failure mode: the non-shrinking rule existed only in transcript
// evidence until it was given a governed home. This gate is the difference
// between publishing a boundary and holding one.
//
// It deliberately tests BOTH directions:
//   - the code still satisfies the contract, and
//   - the contract still describes the code (every route it enumerates exists
//     and classifies as the document claims).
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:aura/app/route_classification.dart';

const String kContract = 'docs/governance/CH02_DESTINATION_RECONSTRUCTION_CONTRACT.md';
const String kChokePoint = 'lib/core/auth/auth_providers.dart';
const String kClassifier = 'lib/app/route_classification.dart';
const String kRouter = 'lib/router.dart';

String _read(String p) {
  final f = File(p);
  if (!f.existsSync()) throw StateError('missing: $p');
  return f.readAsStringSync();
}

void main() {
  group('CH-02 S3 — the contract exists and is governed', () {
    test('the published contract is present', () {
      expect(File(kContract).existsSync(), isTrue,
          reason: 'CH-02 S3 requires the contract to be PUBLISHED, not drafted.');
    });

    test('it carries all six required seam-enumeration elements', () {
      final t = _read(kContract);
      const required = {
        'structural auth/destination routes': 'Structural auth/destination routes',
        'account-entry experience surfaces': 'Account-entry experience surfaces',
        'redirect/destination reconstruction contract': 'redirect/destination reconstruction contract',
        'ownership boundary at each crossing': 'ownership boundary at each crossing',
        'shared dependencies': 'Shared dependencies',
        'fail-closed behaviour': 'Fail-closed behaviour where destination reconstruction cannot be proven',
      };
      final missing = <String>[];
      required.forEach((label, needle) {
        if (!t.contains(needle)) missing.add(label);
      });
      expect(missing, isEmpty,
          reason: 'The founder ruling requires the enumeration to identify, at '
              'minimum, these elements. Missing: ${missing.join(', ')}');
    });
  });

  group('CH-02 S3 — clause C1/C2: session establishment', () {
    test('C1 — establishment lives at the choke point', () {
      expect(RegExp(r'setSessionHint\(\s*true\s*\)').hasMatch(_read(kChokePoint)), isTrue,
          reason: 'Contract clause C1 names TokenStore.setSession as the single '
              'establishment site.');
    });

    test('C2 — guest tokens are excluded at that choke point', () {
      expect(RegExp(r"_jwtType\(\s*token\s*\)\s*!=\s*'guest'").hasMatch(_read(kChokePoint)), isTrue,
          reason: 'Contract clause C2.');
    });
  });

  group('CH-02 S3 — clause C3: classification is total and fails closed', () {
    test('unknown paths classify as member, never public', () {
      for (final p in const [
        '/definitely-not-a-declared-route',
        '/admin/../public',
        '/zzz/deep/unknown',
      ]) {
        expect(classifyRoute(p), RouteClass.member,
            reason: 'Contract clause C3: unknown paths fail CLOSED. "$p" did not.');
        expect(routeAllowsUnauthenticatedEntry(p), isFalse,
            reason: 'An unknown path must never allow unauthenticated entry.');
      }
    });

    test('/admin remains classified despite PD-1 scope exclusion', () {
      // Founder ruling 2026-08-18: PD-1 places Platform Administration OUT OF
      // CURRENT RECONSTRUCTION SCOPE, and states explicitly that this "does not
      // exempt Platform Administration from shared runtime/security
      // authorities" — CH-02 S2 fail-closed classification of /admin remains
      // applicable. Scope exclusion must never become a security bypass, so
      // that is asserted here rather than assumed.
      for (final p in const ['/admin', '/admin/users', '/admin/audit-logs']) {
        expect(classifyRoute(p), RouteClass.member,
            reason: 'PD-1 scope exclusion must not create a routing bypass.');
        expect(routeAllowsUnauthenticatedEntry(p), isFalse,
            reason: '$p must not allow unauthenticated entry.');
      }
    });
  });

  group('CH-02 S3 — clause C4: fail-closed destination normalization', () {
    test('the normalizer rejects empty, relative and boot destinations', () {
      final src = _read(kRouter);
      final start = src.indexOf('String _normalizeRedirectDest(');
      expect(start, isNot(-1), reason: 'Contract clause C4 names _normalizeRedirectDest.');
      final body = src.substring(start, start + 600);
      // Each guard the contract claims, checked individually so a partial
      // regression names the specific clause it broke.
      expect(body.contains("trimmed.isEmpty"), isTrue, reason: 'C4: empty destination guard');
      expect(body.contains("trimmed == '/'"), isTrue, reason: 'C4: bare-root guard');
      expect(body.contains("!trimmed.startsWith('/')"), isTrue,
          reason: 'C4: absolute-path guard — a relative or external destination must fall back');
      expect(body.contains('kRouterBootRoute'), isTrue,
          reason: 'C4: the boot path must never be a redirect destination (loop guard)');
      expect(body.contains('fallback'), isTrue, reason: 'C4: a declared fallback must be returned');
    });
  });

  group('CH-02 S3 — the seam enumeration still matches the code', () {
    test('every CH-02 structural route the contract names is an authAction or boot path', () {
      // If a route the contract assigns to CH-02 silently changes class, the
      // published boundary is describing something that no longer exists.
      const structural = ['/complete-identity', '/verify-pending', '/verify-email', '/institution/sign-in'];
      for (final p in structural) {
        expect(isAuthActionPath(p), isTrue,
            reason: 'Contract 3.1 lists $p as a structural authAction route.');
      }
      expect(isBootPath(kRouterBootPath), isTrue, reason: 'Contract 3.1 lists the boot path.');
    });

    test('every CH-10 experience surface the contract names is still an auth page', () {
      const experience = ['/login', '/register', '/forgot-password', '/reset-password'];
      for (final p in experience) {
        final isEntry = isPlainAuthPage(p) || isAuthActionPath(p);
        expect(isEntry, isTrue,
            reason: 'Contract 3.2 lists $p as a CH-10 account-entry surface.');
        expect(routeAllowsUnauthenticatedEntry(p), isTrue,
            reason: '$p must remain reachable without a session, or account '
                'entry is impossible.');
      }
    });

    test('the retired /auth mirror stays alias-resolvable, never buildable', () {
      // DR4, restated in contract 3.1.
      expect(isPlainAuthPage('/auth'), isTrue,
          reason: 'The retired mirror must still resolve.');
    });

    test('institution sign-in is an auth ceremony, not a member surface', () {
      // Contract 3.5 fail-closed behaviour 5, and the 2026-08-14 Meetings
      // regression: institution path does not imply institution actor.
      expect(isAuthActionPath('/institution/sign-in'), isTrue);
      expect(classifyRoute('/institution/sign-in'), RouteClass.authAction,
          reason: 'Classifying it as member would lock a person out of '
              'establishing institution authority at all.');
    });
  });

  group('CH-02 S3 — what the contract does not claim', () {
    test('the contract states F103/F104/F065 are not closed by publication', () {
      final t = _read(kContract);
      expect(t.contains('F103') && t.contains('F104'), isTrue);
      expect(t.contains('IMPLEMENTED_NOT_LIVE_CERTIFIED'), isTrue,
          reason: 'F065 must remain declared as not live-certified. A contract '
              'that quietly implies its own certification is the exact '
              'promotion this programme forbids.');
    });
  });
}
