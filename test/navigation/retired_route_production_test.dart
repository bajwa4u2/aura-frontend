import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:aura/core/navigation/canonical_destinations.dart';

/// RATCHET — client source must not mint retired routes.
///
/// Phase 5 retired the `/me/correspondence/...` family, and `lib/router.dart`
/// declares no `errorBuilder`, so anything still pointing there lands on
/// GoRouter's default not-found page.
///
/// Two kinds of reference are not the same thing, and this gate separates them:
///
///   * PRODUCING the address — building it into a destination. Banned.
///   * RECOGNISING it — spotting a stale address that a server row or an old
///     notification may still carry, and doing something honest with it.
///     Allowed, but only in the files named below, so the list stays reviewable
///     rather than growing quietly.
///
/// Comments are stripped before matching. A retirement record that names what
/// it retired is evidence, not a producer, and erasing that prose to make a
/// gate pass would be the wrong trade.
void main() {
  /// Files permitted to name the retired family, each because it recognises a
  /// stale address rather than creating one.
  const recognitionSites = <String, String>{
    'lib/app/route_normalizer.dart':
        'rewrites the bare stale hub address onto canonical messages',
    'lib/features/activity/presentation/activity_screen.dart':
        'a persisted activity row may still carry one; opens the live session '
            'if there is one, otherwise the row is simply no longer actionable',
    'lib/core/navigation/canonical_destinations.dart':
        'the authority itself, which owns the prefix constant',
  };

  String stripComments(String source) => source
      .replaceAll(RegExp(r'/\*[\s\S]*?\*/'), '')
      .replaceAll(RegExp(r'^\s*///.*$', multiLine: true), '')
      .replaceAll(RegExp(r'(^|[^:])//.*$', multiLine: true), r'$1');

  List<File> dartFiles() => Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList();

  test('finds the client source tree it is supposed to be guarding', () {
    // A gate that silently scans nothing passes forever.
    expect(dartFiles().length, greaterThan(300));
  });

  test('no client file mints the retired correspondence family', () {
    final offenders = <String>[];

    for (final file in dartFiles()) {
      final normalized = file.path.replaceAll(r'\', '/');
      if (recognitionSites.containsKey(normalized)) continue;
      if (stripComments(file.readAsStringSync())
          .contains(kRetiredCorrespondenceRoutePrefix)) {
        offenders.add(normalized);
      }
    }

    expect(offenders, isEmpty);
  });

  test('every allowed recognition site still exists and still recognises', () {
    // If one stops needing the exemption, it should leave the list rather than
    // sit there making the allowlist look larger than the debt.
    for (final entry in recognitionSites.entries) {
      final file = File(entry.key);
      expect(file.existsSync(), isTrue, reason: '${entry.key} is gone');
      expect(
        file.readAsStringSync().contains(kRetiredCorrespondenceRoutePrefix),
        isTrue,
        reason: '${entry.key} no longer needs its exemption (${entry.value})',
      );
    }
  });

  group('canonical destination authority', () {
    test('addresses a canonical Conversation', () {
      expect(conversationDestination('conv-1'), '/messages/c/conv-1');
    });

    test('addresses a reconstructed Institution Space', () {
      expect(
        institutionSpaceDestination('inst-1', 'space-1'),
        '/institution/inst-1/spaces/space-1',
      );
    });

    test('refuses a Space with no institution — a legacy space has no surface',
        () {
      expect(institutionSpaceDestination(null, 'space-1'), isNull);
      expect(canonicalContextDestination(spaceId: 'space-1'), isNull);
    });

    test('prefers the Institution Space surface for Space events', () {
      expect(
        canonicalContextDestination(
          conversationId: 'conv-1',
          institutionId: 'inst-1',
          spaceId: 'space-1',
        ),
        '/institution/inst-1/spaces/space-1',
      );
    });

    test('sends a live event to its session, else the owning context', () {
      expect(
        canonicalLiveDestination(sessionId: 's-1', conversationId: 'c-1'),
        '/realtime/s-1?action=join',
      );
      expect(
        canonicalLiveDestination(conversationId: 'c-1'),
        '/messages/c/c-1',
      );
    });

    test('does not guess when nothing canonical is known', () {
      expect(canonicalContextDestination(), isNull);
      expect(canonicalLiveDestination(), isNull);
      expect(conversationDestination('   '), isNull);
    });
  });
}
