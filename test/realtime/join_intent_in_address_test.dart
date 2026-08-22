import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:aura/core/navigation/navigation_authority.dart';

// THE CLASSICAL STALL: "Ready to join — Tap Join call to enter".
//
// Measured live on 2026-08-22 with two authenticated participants. The caller
// pressed the video-call button; the callee's client rang, joined, and showed a
// two-participant call — while the caller sat on "Ready to join", never in the
// room. From the other side that is indistinguishable from one-way media, and
// it is the shape the founder has reported on the callee side.
//
// Mechanism: `readyToJoinIsTruthful` decides the instruction is honest when the
// viewer has expressed no join intent. Intent is expressed by accepting, or by
// arriving on an `action=join` address. Both real paths navigated to an address
// that carried NO intent — the initiator to a bare `/realtime/<id>`, and the
// accept path to `/realtime/<id>?returnTo=…`. So a person who had just asked
// for the call was instructed to ask again.
//
// F044 already named this state and repaired the in-frame flash. What it could
// not repair was an address that says nothing: whenever the join did not
// survive the navigation, the instruction stopped being a flash and became a
// dead end. Hence this gate is about the ADDRESS, which is where the
// NavigationAuthority doc comment already says intent belongs.

void main() {
  group('the join address carries intent', () {
    test('the join route states action=join', () {
      expect(
        NavigationAuthority.realtimeSessionJoinRoute('s1'),
        '/realtime/s1?action=join',
      );
    });

    test('a return address travels WITH the intent, never instead of it', () {
      final route = NavigationAuthority.realtimeSessionJoinRoute(
        's1',
        returnTo: '/home',
      );

      expect(route, contains('action=join'),
          reason: 'returnTo alone is what caused the stall');
      expect(Uri.parse(route).queryParameters['returnTo'], '/home');
    });

    test('a return address with its own query survives encoding', () {
      final route = NavigationAuthority.realtimeSessionJoinRoute(
        's1',
        returnTo: '/messages/c/abc?tab=files',
      );

      final q = Uri.parse(route).queryParameters;
      expect(q['action'], 'join');
      expect(q['returnTo'], '/messages/c/abc?tab=files');
    });

    test('an empty return address does not emit a dangling parameter', () {
      expect(
        NavigationAuthority.realtimeSessionJoinRoute('s1', returnTo: '   '),
        '/realtime/s1?action=join',
      );
    });
  });

  group('no realtime address carries a return without the intent', () {
    // Structural, deliberately: enumerating call sites rots, the rule does not.
    //
    // The rule is about MEANING, not style. Several surfaces legitimately
    // compose a realtime address with extra session metadata, and those are
    // fine — they all state `action=join`. The defect was an address that
    // carried only where to go BACK to, and nothing about why the person had
    // arrived. That is the shape this refuses.
    test('a realtime address with returnTo also states action=join', () {
      final offenders = <String>[];

      for (final entity in Directory('lib').listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final path = entity.path.replaceAll(String.fromCharCode(92), '/');
        if (path.endsWith('core/navigation/navigation_authority.dart')) continue;

        final lines = entity.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          if (!lines[i].contains('/realtime/')) continue;
          final lo = (i - 3).clamp(0, lines.length);
          final hi = (i + 4).clamp(0, lines.length);
          final window = lines.sublist(lo, hi).join(String.fromCharCode(10));
          if (!window.contains('returnTo=') && !window.contains("'returnTo'")) continue;
          if (window.contains('action=join') || window.contains("'join'")) {
            continue;
          }
          offenders.add('$path:${i + 1}');
        }
      }

      expect(offenders, isEmpty,
          reason: 'an address that says where to go back to, but not that the '
              'person asked to join, is what strands them on "Ready to join"');
    });
  });
}
