// CH-02 S4 — EXPLICIT ACTING-CONTEXT IDENTITY CONTRACT GATE.
//
// Canonical obligation CO-RC-C3-006: "correspondence sender experience MUST
// consume institutionContextId + correspondAsInstitution; NO ROUTE-DERIVED
// SENDER MAY SURVIVE C7 CLOSURE."
//
// The founder ruling, already stated verbatim in interaction_service.dart:
//
//     A route may establish the RECIPIENT and the CONTEXT BEING VIEWED.
//     It may never establish ACTING IDENTITY.
//
// WHY THIS GATE EXISTS SEPARATELY FROM THE C1 RATCHET. The C1 anti-drift
// ratchet counts files that mention an `/institution` path near acting-identity
// vocabulary, and freezes that count. It is a drift ratchet: good at stopping
// spread, and deliberately tolerant of one baselined site. It cannot express
// the SPECIFIC contract clause that matters here — that `institutionContextId`
// may travel as VIEWING CONTEXT and may never become SENDER AUTHORITY. A file
// could keep the ratchet green while quietly turning a viewing context into an
// actor. This gate closes that.
//
// It is deliberately ZERO-TOLERANCE where the ratchet is not, because the
// distinction it guards has already caused one production regression: a booked
// meeting attendee redirected to Institution Sign In because an
// institution-namespaced URL was read as an institution-actor claim.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const String kContract = 'docs/governance/CH02_S4_ACTING_CONTEXT_IDENTITY_CONTRACT.md';
const String kActorContext = 'lib/core/interactions/actor_context.dart';
const String kInteractionService = 'lib/core/interactions/interaction_service.dart';

/// Vocabulary that constructs or asserts an ACTING identity.
final _actingIdentity = RegExp(
  r'ActorRef\.institution|ActorType\.institution|ActingIdentityKind\.institution|'
  r'canSpeakAsInstitution\s*[:=]\s*true|actingAs\s*[:=]',
);

/// The explicit viewing-context parameter the contract governs.
final _viewingContext = RegExp(r'\binstitutionContextId\b');

List<File> _libFiles() => Directory('lib')
    .listSync(recursive: true)
    .whereType<File>()
    .where((f) => f.path.endsWith('.dart'))
    .toList();

String _rel(File f) => f.path.replaceAll('\\', '/');

void main() {
  final files = _libFiles();

  group('CH-02 S4 — the contract is published', () {
    test('the contract document exists', () {
      expect(File(kContract).existsSync(), isTrue,
          reason: 'CO-RC-C3-006 is a contract INHERITED by later chapters. An '
              'unpublished contract cannot be inherited.');
    });

    test('it states the governing sentence and the C7 handoff', () {
      final t = File(kContract).readAsStringSync();
      expect(t, contains('may never establish ACTING IDENTITY'));
      expect(t, contains('no route-derived sender may survive'));
      expect(t.toLowerCase(), contains('c7'));
    });
  });

  group('CH-02 S4 — C2: viewing context never becomes sender authority', () {
    test('no file turns institutionContextId into an acting identity', () {
      // The precise defect this contract exists to prevent: a parameter that
      // legitimately says WHERE A PERSON IS LOOKING being used to decide WHO
      // THEY ARE SPEAKING AS.
      final offenders = <String>[];
      for (final f in files) {
        final lines = f.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          if (!_viewingContext.hasMatch(lines[i])) continue;
          if (lines[i].trimLeft().startsWith('//') || lines[i].trimLeft().startsWith('///')) continue;
          // Look at the statement's neighbourhood, not the single line: an
          // assignment and its use are rarely on one line.
          final from = (i - 3).clamp(0, i);
          final to = (i + 4).clamp(0, lines.length);
          final window = lines.sublist(from, to).where((l) {
            final t = l.trimLeft();
            return !t.startsWith('//') && !t.startsWith('///');
          }).join('\n');
          if (_actingIdentity.hasMatch(window)) {
            offenders.add('${_rel(f)}:${i + 1}  ${lines[i].trim()}');
          }
        }
      }
      expect(
        offenders,
        isEmpty,
        reason: '\n[CH-02 S4] VIEWING CONTEXT USED AS SENDER AUTHORITY:\n'
            '${offenders.map((o) => '  $o').join('\n')}\n\n'
            'institutionContextId states WHERE a person is looking. It may '
            'never decide WHO they speak as. Resolve acting identity per act '
            'through ConsequentialAct.correspondAsInstitution.\n',
      );
    });
  });

  group('CH-02 S4 — C4: the shipped default sender is the person', () {
    test('interaction_service still sends as the person', () {
      final src = File(kInteractionService).readAsStringSync();
      expect(
        RegExp(r'ActorRef\.user\(').hasMatch(src),
        isTrue,
        reason: 'With no chooser at message initiation, the only correct '
            'sender is the person. Defaulting to the institution would '
            'silently turn a personal message into institutional '
            'correspondence — the exact defect that was removed.',
      );
    });

    test('it does not construct an institution actor for a direct message', () {
      final src = File(kInteractionService).readAsStringSync();
      final code = src
          .split('\n')
          .where((l) => !l.trimLeft().startsWith('//'))
          .join('\n');
      expect(RegExp(r'ActorRef\.institution\(').hasMatch(code), isFalse,
          reason: 'C7 owns the chooser. Until it exists, no institution '
              'sender may be constructed here.');
    });
  });

  group('CH-02 S4 — the C3 retirement stays retired', () {
    test('the route-inferring resolvers are still deleted', () {
      // Deleted 2026-08-16 because they manufactured an institutional acting
      // context from the URL prefix. A re-introduction under any name that
      // resolves an actor from a path is the same defect.
      final offenders = <String>[];
      for (final f in files) {
        final src = f.readAsStringSync();
        final code = src
            .split('\n')
            .where((l) => !l.trimLeft().startsWith('//') && !l.trimLeft().startsWith('///'))
            .join('\n');
        if (RegExp(r'\b_?pathIsInstitutionShell\b').hasMatch(code) ||
            RegExp(r'\bresolveActorContext\s*\(').hasMatch(code)) {
          offenders.add(_rel(f));
        }
      }
      expect(offenders, isEmpty,
          reason: 'The C3 retirement (2026-08-16) deleted these. They '
              'manufactured acting identity from a URL prefix.');
    });

    test('actor_context records the retirement and the C7 handoff', () {
      final t = File(kActorContext).readAsStringSync();
      expect(t, contains('C3 RETIREMENT'));
      expect(t, contains('No route-derived sender may survive'));
    });
  });

  group('CH-02 S4 — the protected boundary is untouched', () {
    test('Meetings institution-context routes still exist', () {
      // CO-RC-C3-006: "Meetings: protected, its institution-context routes
      // untouched." A gate that silently permitted their removal would be
      // enforcing the contract's letter against its purpose.
      final router = File('lib/router.dart').readAsStringSync();
      for (final p in const [
        "path: '/institution/:institutionId/meetings'",
        "path: '/institution/:institutionId/meetings/:meetingId'",
        "path: '/institution/:institutionId/meetings/:meetingId/room'",
      ]) {
        expect(router, contains(p), reason: 'Protected Meetings route missing: $p');
      }
    });
  });
}
