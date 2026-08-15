// C1 ANTI-DRIFT ARCHITECTURE GATE — FD-13 enforcement.
//
// Follows the C0 precedent exactly: hard build failure, architecture-aware,
// truthful measured baseline, narrow named exceptions, never warning-only.
//
// What C1 must prevent coming back:
//   * acting identity derived from a route
//   * a second ambient "current actor"
//   * capabilities fabricated on the client
//   * role checks standing in for capability questions
//
// Deliberately NOT a general lint. Each rule below names a concrete pattern
// that was measured in this repository.

import 'dart:io';

import 'package:aura/core/authority/acting_context.dart';
import 'package:aura/core/authority/capability_projection.dart';
import 'package:flutter_test/flutter_test.dart';

/// Files that legitimately own the behaviour a rule governs.
const _authorityOwners = <String>{
  'lib/core/authority/acting_context.dart',
  'lib/core/authority/capability_projection.dart',
  'lib/core/authority/authority_providers.dart',
  // The retired model. Kept, deprecated, zero consumers of its provider; its
  // remaining `resolveActorContext` callers belong to C4/C7 surfaces.
  'lib/core/interactions/actor_context.dart',
};

String _strip(String src) {
  final out = StringBuffer();
  var i = 0;
  String? quote;
  while (i < src.length) {
    final c = src[i];
    if (quote != null) {
      out.write(c);
      if (c == r'\' && i + 1 < src.length) {
        out.write(src[i + 1]);
        i += 2;
        continue;
      }
      if (c == quote) quote = null;
      i++;
      continue;
    }
    if (c == "'" || c == '"') {
      quote = c;
      out.write(c);
      i++;
      continue;
    }
    if (c == '/' && i + 1 < src.length && src[i + 1] == '/') {
      while (i < src.length && src[i] != '\n') {
        out.write(' ');
        i++;
      }
      continue;
    }
    if (c == '/' && i + 1 < src.length && src[i + 1] == '*') {
      while (i < src.length - 1 && !(src[i] == '*' && src[i + 1] == '/')) {
        out.write(src[i] == '\n' ? '\n' : ' ');
        i++;
      }
      out.write('  ');
      i += 2;
      continue;
    }
    out.write(c);
    i++;
  }
  return out.toString();
}

class _Src {
  _Src(this.path, this.text);
  final String path;
  final String text;
}

List<_Src> _lib() => Directory('lib')
    .listSync(recursive: true)
    .whereType<File>()
    .where((f) => f.path.endsWith('.dart'))
    .map((f) => _Src(f.path.replaceAll(r'\', '/'), _strip(f.readAsStringSync())))
    .toList()
  ..sort((a, b) => a.path.compareTo(b.path));

Map<String, Map<String, int>> _baseline() {
  final file = File('test/authority/c1_drift_baseline.txt');
  if (!file.existsSync()) {
    throw StateError('The frozen C1 drift baseline is missing: ${file.path}');
  }
  final out = <String, Map<String, int>>{};
  for (final raw in file.readAsLinesSync()) {
    final line = raw.trim();
    if (line.isEmpty || line.startsWith('#')) continue;
    final p = line.split(RegExp(r'\s+'));
    out.putIfAbsent(p[0], () => {})[p[2]] = int.parse(p[1]);
  }
  return out;
}

void _ratchet(String rule, Map<String, int> actual, Map<String, int> baseline,
    String remedy) {
  final appeared = actual.keys.where((p) => !baseline.containsKey(p)).toList()
    ..sort();
  expect(appeared, isEmpty,
      reason: '\n[$rule] NEW DRIFT in:\n${appeared.map((p) => '  $p').join('\n')}'
          '\n\n$remedy\n');

  final rose = actual.entries
      .where((e) => baseline.containsKey(e.key) && e.value > baseline[e.key]!)
      .map((e) => '  ${e.key}: ${baseline[e.key]} -> ${e.value}')
      .toList()
    ..sort();
  expect(rose, isEmpty,
      reason: '\n[$rule] drift INCREASED:\n${rose.join('\n')}\n\n$remedy\n');

  final fell = baseline.entries
      .where((e) => (actual[e.key] ?? 0) < e.value)
      .map((e) => '  ${e.key}: ${e.value} -> ${actual[e.key] ?? 0}')
      .toList()
    ..sort();
  expect(fell, isEmpty,
      reason: '\n[$rule] drift was REDUCED (good) but the baseline now '
          'overstates it:\n${fell.join('\n')}\n\n'
          'Update test/authority/c1_drift_baseline.txt.\n');
}

void main() {
  final sources = _lib();
  final governed =
      sources.where((s) => !_authorityOwners.contains(s.path)).toList();
  final baseline = _baseline();

  group('C1 gate — acting identity (ZERO TOLERANCE)', () {
    test('acting identity is never derived from a route', () {
      // The defect: deciding someone speaks AS an institution because the URL
      // began with /institution/. institutionId-in-path is navigation, not
      // authority — the frozen ruling from the Meetings router regression.
      final pathish = RegExp(
          r"(?:startsWith|contains)\s*\(\s*'/institution");
      final offenders = <String>[];
      for (final s in governed) {
        if (!pathish.hasMatch(s.text)) continue;
        // Only a violation when the same file also decides actor/acting
        // identity from it. Routing files legitimately match paths.
        if (RegExp(r'ActorType\.institution|ActingIdentityKind\.institution|'
                r'canSpeakAsInstitution|actingAs')
            .hasMatch(s.text)) {
          offenders.add('  ${s.path}');
        }
      }
      // RATCHET, not zero-tolerance, for one honest reason: the single
      // remaining site (`interaction_service.dart`, the "tap Message" path)
      // cannot be corrected without deciding how a person CHOOSES to
      // correspond as an institution — which is the founder checkpoint on
      // consequential-action acting identity. Changing it unilaterally would
      // either remove a real capability or invent an interaction pattern.
      //
      // Frozen here so it cannot be forgotten and cannot spread.
      final actual = {for (final o in offenders) o.trim(): 1};
      _ratchet(
        'ACTING CONTEXT / route-derived acting identity',
        actual,
        baseline['A1'] ?? const {},
        'Resolve per act via ActingContextAuthority.resolve(). A path never '
            'makes someone an institution — institutionId-in-path is '
            'navigation, not authority.',
      );
    });

    test('no second ambient current-actor provider is introduced', () {
      final offenders = <String>[];
      final re = RegExp(
          r'final\s+\w*(?:activeActor|currentActor|actingIdentity|currentActingContext)\w*\s*=\s*Provider');
      for (final s in governed) {
        if (re.hasMatch(s.text)) offenders.add('  ${s.path}');
      }
      expect(offenders..sort(), isEmpty,
          reason: '\n[ACTING CONTEXT] A new ambient actor provider appeared:\n'
              '${offenders.join('\n')}\n\n'
              'Acting identity is per-act, never ambient state to read.\n');
    });

    test('the retired ambient provider has no consumers', () {
      final consumers = governed
          .where((s) => s.text.contains('activeActorContextProvider'))
          .map((s) => '  ${s.path}')
          .toList()
        ..sort();
      expect(consumers, isEmpty,
          reason: '\n[ACTING CONTEXT] activeActorContextProvider is retired — '
              'it returns the INSTITUTION actor for anyone who merely belongs '
              'to one:\n${consumers.join('\n')}\n');
    });
  });

  group('C1 gate — capability truth (ZERO TOLERANCE)', () {
    test('capabilities are never fabricated on the client', () {
      // The measured defect: institution_access_provider injected six invented
      // capability tokens whenever it decided a session was an "authorized
      // speaker". A capability the backend did not report is not a capability.
      final wires = InstitutionCapabilityToken.all.map((c) => c.wire).toSet();
      final addAll = RegExp(r'\.addAll\s*\(|\.add\s*\(');
      final offenders = <String>[];
      for (final s in governed) {
        if (!addAll.hasMatch(s.text)) continue;
        for (final line in s.text.split('\n')) {
          if (!line.contains('add')) continue;
          if (wires.any((w) => line.contains(w))) {
            offenders.add('  ${s.path}: ${line.trim()}');
          }
        }
      }
      expect(offenders..sort(), isEmpty,
          reason: '\n[CAPABILITY] A capability token is being added to a set '
              'client-side:\n${offenders.join('\n')}\n\n'
              'Effective capability is computed by InstitutionAuthorityService '
              'and consumed, never extended here.\n');
    });

    test('the role-capability table is not re-derived on the client', () {
      // ROLE_CAPABILITIES lives in the backend precisely so the client cannot
      // drift from it.
      final offenders = <String>[];
      final re = RegExp(r'ROLE_CAPABILITIES|roleCapabilities\s*[:=]\s*\{');
      for (final s in sources) {
        if (_authorityOwners.contains(s.path)) continue;
        if (re.hasMatch(s.text)) offenders.add('  ${s.path}');
      }
      expect(offenders..sort(), isEmpty,
          reason: '\n[CAPABILITY] The role→capability table is being rebuilt '
              'client-side:\n${offenders.join('\n')}\n');
    });
  });

  group('C1 gate — role-as-permission RATCHET', () {
    test('no new role-derived authority booleans', () {
      // isOwner/isAdmin are legitimate for GOVERNANCE acts and for showing a
      // role that has product meaning. They are drift when they answer a
      // capability question. The count is frozen and may only fall as each
      // owning chapter migrates its surfaces.
      final re = RegExp(r'\b(isOwner|isAdmin|isAdminLike)\b');
      final actual = <String, int>{};
      for (final s in governed) {
        final n = re.allMatches(s.text).length;
        if (n > 0) actual[s.path] = n;
      }
      _ratchet(
        'ROLE-AS-PERMISSION',
        actual,
        baseline['R1'] ?? const {},
        'Ask the capability question: CapabilityProjection.presentationFor(act), '
            'or ActingContextAuthority.resolve(act). Use a role only where ROLE '
            'itself has product meaning (governance acts, or displaying a role).',
      );
    });

    test('no new role-literal comparisons', () {
      final re = RegExp(
          "(?:role|Role)\\s*(?:==|!=)\\s*['\"](?:OWNER|ADMIN|MEMBER|EDITOR|MODERATOR)['\"]");
      final actual = <String, int>{};
      for (final s in governed) {
        final n = re.allMatches(s.text).length;
        if (n > 0) actual[s.path] = n;
      }
      _ratchet(
        'ROLE LITERAL COMPARISON',
        actual,
        baseline['R2'] ?? const {},
        'Compare through InstitutionRole/atLeast for governance, or ask the '
            'capability question instead.',
      );
    });
  });

  group('C1 gate — the model stays coherent', () {
    test('every consequential act declares exactly one requirement', () {
      for (final act in ConsequentialAct.values) {
        final r = act.requirement;
        final n = (r.isPersonal ? 1 : 0) +
            (r.capability != null ? 1 : 0) +
            (r.minimumRole != null ? 1 : 0);
        expect(n, 1, reason: '$act');
      }
    });

    test('governance acts are never expressed as capabilities', () {
      for (final act in [
        ConsequentialAct.transferOwnership,
        ConsequentialAct.appointAdmin,
      ]) {
        expect(act.requirement.capability, isNull, reason: '$act');
        expect(act.requirement.minimumRole, InstitutionRole.owner);
      }
    });

    test('an institutional option always carries the acting person', () {
      final a = ActingContextAuthority(
        personId: 'p',
        personDisplayName: 'P',
        institution: InstitutionStanding(
          institutionId: 'i',
          institutionName: 'I',
          effectiveCapabilities: InstitutionCapabilityToken.all.toSet(),
          role: InstitutionRole.owner,
        ),
      );
      for (final act in ConsequentialAct.values) {
        final r = a.resolve(act)!;
        for (final o in r.options.where((o) => o.isInstitution)) {
          expect(o.personId, 'p', reason: '$act lost the acting person');
          expect(o.institutionId, 'i', reason: '$act');
        }
      }
    });

    test('baselined files still exist', () {
      final missing = <String>[];
      for (final rule in baseline.values) {
        for (final path in rule.keys) {
          if (!File(path).existsSync()) missing.add(path);
        }
      }
      expect(missing.toSet().toList()..sort(), isEmpty);
    });
  });
}
