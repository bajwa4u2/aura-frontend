// CH-02 S1 — SINGLE-CHOKE-POINT SESSION ESTABLISHMENT
//
// Founder-frozen doctrine (RC1 / F065): AUTHENTICATION UNKNOWN/RESTORING IS
// NOT UNAUTHENTICATED. The device-local session hint gates the cold-load
// `/auth/refresh` that restores a session after a browser refresh.
//
// The register records the shape of the original defect precisely: the hint
// was "written at 2 of N call sites" — password login and code verification —
// while sessions are in fact established by many paths. Every session born on
// another path left the hint unwritten, so the NEXT reload skipped the
// refresh, the app declared the person unauthenticated, and the router
// discarded their destination. That is the refresh-loses-my-place defect.
//
// The correction is STRUCTURAL, not another call site: session establishment
// writes the hint at ONE choke point, so no future authentication path can
// forget it. This gate is what keeps that true — a contract nothing enforces
// is a comment.
//
// These are static source assertions on purpose. A widget test could prove
// that one path writes the hint; only a source assertion can prove that no
// OTHER path does.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The one file permitted to ESTABLISH a session hint.
const String kChokePoint = 'lib/core/auth/auth_providers.dart';

/// Files permitted to CLEAR the hint, each with the reason it is governed.
///
/// Clearing is deliberately not single-sited. The frozen comment in
/// `TokenStore.clearTokens` blesses redundant clears: "the duplicate write is
/// harmless and keeps the invariant true even for paths that don't". Losing a
/// session twice is safe; gaining one silently is not.
const Map<String, String> kGovernedClearSites = {
  'lib/core/auth/auth_providers.dart':
      'TokenStore.clearTokens — the symmetric clear at the choke point.',
  'lib/core/auth/session_bootstrap.dart':
      'GOVERNED EXCEPTION: on a cold load the refresh cookie can be proven '
          'gone (401/403) when there is no session to clear at all. This '
          'forgets a hint rather than losing a session, so it cannot route '
          'through clearTokens.',
  'lib/app/aura_app.dart':
      'Defensive clear after clearTokens() in the auth-drop teardown; each '
          'call is separately try/caught so the hint is still forgotten if '
          'clearTokens throws.',
  'lib/features/auth/auth_controller.dart':
      'Defensive clear on the explicit sign-out path, same rationale.',
};

List<File> _libFiles() => Directory('lib')
    .listSync(recursive: true)
    .whereType<File>()
    .where((f) => f.path.endsWith('.dart'))
    .toList();

String _rel(File f) => f.path.replaceAll('\\', '/');

void main() {
  final files = _libFiles();

  group('CH-02 S1 — session establishment has exactly one call site', () {
    test('setSessionHint(true) is written ONLY at the choke point', () {
      final offenders = <String>[];
      for (final f in files) {
        final path = _rel(f);
        if (path == kChokePoint) continue;
        final lines = f.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          final line = lines[i];
          if (line.trimLeft().startsWith('//')) continue;
          if (RegExp(r'setSessionHint\(\s*true\s*\)').hasMatch(line)) {
            offenders.add('$path:${i + 1}  ${line.trim()}');
          }
        }
      }
      expect(
        offenders,
        isEmpty,
        reason: '\n[CH-02 S1] SESSION ESTABLISHED OUTSIDE THE CHOKE POINT:\n'
            '${offenders.map((o) => '  $o').join('\n')}\n\n'
            'A session hint is a CONSEQUENCE of holding a member session, not '
            'an act an authentication path performs. Call '
            'TokenStore.setSession() and let the choke point record it. '
            'Adding a call site here is the exact defect F065 names.\n',
      );
    });

    test('the choke point actually writes the hint', () {
      final src = File(kChokePoint).readAsStringSync();
      expect(
        RegExp(r'setSessionHint\(\s*true\s*\)').hasMatch(src),
        isTrue,
        reason: 'The choke point must establish the hint, or the previous '
            'test passes vacuously — nobody writes it at all.',
      );
    });

    test('the choke point writes the hint from inside setSession', () {
      // Guards against the write drifting out of setSession into some other
      // member of the same file, which would satisfy the file-level check
      // while breaking the contract.
      final lines = File(kChokePoint).readAsLinesSync();
      final start = lines.indexWhere((l) => l.contains('Future<void> setSession('));
      expect(start, isNot(-1), reason: 'setSession not found at the choke point');
      final end = lines.indexWhere(
        (l) => l.startsWith('  Future<void> clear(') || l.startsWith('  Future<void> clearTokens('),
        start,
      );
      expect(end, isNot(-1), reason: 'could not bound setSession');
      final body = lines.sublist(start, end).join('\n');
      expect(
        RegExp(r'setSessionHint\(\s*true\s*\)').hasMatch(body),
        isTrue,
        reason: 'The hint write must live INSIDE setSession.',
      );
    });
  });

  group('CH-02 S1 — the guest boundary is preserved', () {
    test('the choke point excludes guest tokens from establishing a hint', () {
      final src = File(kChokePoint).readAsStringSync();
      // A meeting guest holds no member refresh cookie. Recording a hint for
      // one would make every later cold load ask blindly for a cookie that
      // cannot exist — and PB-01 guest/booker entry is a protected boundary.
      expect(
        RegExp(r"_jwtType\(\s*token\s*\)\s*!=\s*'guest'").hasMatch(src),
        isTrue,
        reason: 'The guest exclusion must remain at the choke point. Without '
            'it, guest/booker meeting entry would write a member session '
            'hint and every later cold load would ask for a cookie that '
            'never existed.',
      );
    });

    test('no path establishes a hint for a guest token', () {
      // Structural consequence of the two tests above: if establishment only
      // happens at the choke point, and the choke point excludes guests, then
      // no guest path can establish one. Asserted explicitly so the reasoning
      // is recorded rather than assumed.
      final guestSetSession = <String>[];
      for (final f in files) {
        final path = _rel(f);
        if (!path.contains('guest')) continue;
        final lines = f.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          if (RegExp(r'setSessionHint\(').hasMatch(lines[i])) {
            guestSetSession.add('$path:${i + 1}');
          }
        }
      }
      expect(guestSetSession, isEmpty,
          reason: 'A guest surface must never touch the session hint '
              'directly:\n${guestSetSession.join('\n')}');
    });
  });

  group('CH-02 S1 — hint clearing stays governed', () {
    test('setSessionHint(false) appears only at governed clear sites', () {
      final offenders = <String>[];
      for (final f in files) {
        final path = _rel(f);
        if (kGovernedClearSites.containsKey(path)) continue;
        final lines = f.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          final line = lines[i];
          if (line.trimLeft().startsWith('//')) continue;
          if (RegExp(r'setSessionHint\(\s*false\s*\)').hasMatch(line)) {
            offenders.add('$path:${i + 1}  ${line.trim()}');
          }
        }
      }
      expect(
        offenders,
        isEmpty,
        reason: '\n[CH-02 S1] UNGOVERNED SESSION-HINT CLEAR:\n'
            '${offenders.map((o) => '  $o').join('\n')}\n\n'
            'Clearing is permitted at more than one site — losing a session '
            'twice is safe — but each site is listed with its reason in '
            'kGovernedClearSites. Add the site AND its justification, or '
            'route through TokenStore.clearTokens().\n',
      );
    });

    test('every governed clear site still exists and still clears', () {
      kGovernedClearSites.forEach((path, reason) {
        final file = File(path);
        expect(file.existsSync(), isTrue, reason: '$path is missing');
        expect(
          RegExp(r'setSessionHint\(\s*false\s*\)').hasMatch(file.readAsStringSync()),
          isTrue,
          reason: '$path no longer clears the hint. If that is deliberate, '
              'remove it from kGovernedClearSites so the list stays honest '
              'rather than aspirational.\n  Recorded reason: $reason',
        );
      });
    });
  });
}
