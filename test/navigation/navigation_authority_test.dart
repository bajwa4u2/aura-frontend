import 'package:flutter_test/flutter_test.dart';

import 'package:aura/core/navigation/navigation_authority.dart';

/// NAVIGATION AUTHORITY PINS.
///
/// The four authenticated primaries are founder-approved (founder-observed
/// correction, 2026-08-16, amending the original C3 five): primary
/// navigation represents fundamental recurring human intentions. Selected
/// state is destination identity. Shell context is presentation chrome
/// only — never acting authority.
void main() {
  group('founder-approved primary IA', () {
    test('authenticated primaries are exactly the four, in order', () {
      expect(
        NavigationAuthority.authenticatedPrimaries
            .map((d) => d.label)
            .toList(),
        ['Home', 'Messages', 'Discover', 'Create'],
      );
    });

    test('public primaries are Home and Discover', () {
      expect(
        NavigationAuthority.publicPrimaries.map((d) => d.label).toList(),
        ['Home', 'Discover'],
      );
    });

    test('every primary has a canonical route', () {
      expect(
        NavigationAuthority.authenticatedPrimaries
            .map((d) => d.route)
            .toList(),
        ['/home', '/messages', '/discover', '/create'],
      );
    });
  });

  group('destination identity resolution (selected state)', () {
    test('discovery facets highlight Discover', () {
      for (final p in ['/discover', '/search', '/institutions', '/spaces']) {
        expect(NavigationAuthority.primaryOf(p), PrimaryDestination.discover,
            reason: p);
      }
    });

    test('institution OBJECT detail is not the directory', () {
      expect(NavigationAuthority.primaryOf('/institutions/acme'), isNull);
    });

    test('messages aliases resolve to Messages', () {
      for (final p in ['/messages', '/conversations', '/me/correspondence']) {
        expect(NavigationAuthority.primaryOf(p), PrimaryDestination.messages,
            reason: p);
      }
    });

    test('create facets highlight Create (composer included)', () {
      for (final p in ['/create', '/compose']) {
        expect(NavigationAuthority.primaryOf(p), PrimaryDestination.create,
            reason: p);
      }
    });

    test(
        'me and meetings are DEPTH, not primaries (founder-observed '
        'correction) — but me correspondence stays Messages', () {
      // Me: personal depth behind the identity/avatar chrome.
      expect(NavigationAuthority.primaryOf('/me'), isNull);
      expect(NavigationAuthority.primaryOf('/me/edit'), isNull);
      // Meetings: an institutional domain; personal relationships to a
      // meeting are contextual (booking, attention, participations).
      expect(NavigationAuthority.primaryOf('/meetings/m1'), isNull);
      expect(NavigationAuthority.primaryOf('/meetings/m1/room'), isNull);
      // Correspondence remains the Messages intention.
      expect(NavigationAuthority.primaryOf('/me/correspondence/t1'),
          PrimaryDestination.messages);
    });

    test('detail routes select nothing (truthful no-selection)', () {
      for (final p in ['/u/amina', '/thread/t1', '/posts/p1', '/admin']) {
        expect(NavigationAuthority.primaryOf(p), isNull, reason: p);
      }
    });
  });

  group('BUILDER OUTPUT INTEGRITY — no unresolved placeholders (live-defect '
      'pin, 2026-08-16)', () {
    // A shipped defect emitted the LITERAL "/messages/c/\$conversationId"
    // because tooling escaped the interpolation. Every typed builder must
    // interpolate its argument for real: output contains the argument and
    // never a dollar/brace placeholder.
    test('every builder interpolates its argument', () {
      final outputs = <String>[
        NavigationAuthority.conversationRoute('c123'),
        NavigationAuthority.personRoute('amina'),
        NavigationAuthority.institutionRoute('acme'),
        NavigationAuthority.threadRoute('t1'),
        NavigationAuthority.directThreadRoute('d1'),
        NavigationAuthority.postRoute('p1'),
        NavigationAuthority.realtimeSessionRoute('s1'),
        NavigationAuthority.articleRoute('my-article'),
        NavigationAuthority.articleEditorRoute('a1'),
      ];
      expect(outputs[0], '/messages/c/c123');
      expect(outputs[6], '/realtime/s1');
      expect(outputs[7], '/articles/my-article');
      expect(outputs[8], '/articles/write/a1');
      for (final out in outputs) {
        expect(out.contains(r'$'), isFalse,
            reason: 'unresolved placeholder in builder output: $out');
        expect(out.contains('{'), isFalse,
            reason: 'unresolved placeholder in builder output: $out');
      }
    });
  });

  group('shell context is PRESENTATION, never authority', () {
    test('classifies chrome contexts', () {
      expect(NavigationAuthority.contextOf('/admin/users', isAuthed: true),
          ShellContext.admin);
      expect(
          NavigationAuthority.contextOf('/institution/i1/members',
              isAuthed: true),
          ShellContext.institution);
      expect(NavigationAuthority.contextOf('/home', isAuthed: true),
          ShellContext.member);
      expect(NavigationAuthority.contextOf('/home', isAuthed: false),
          ShellContext.public);
    });

    test('a retired mirror alias classifies as its CANONICAL destination',
        () {
      // Legacy alias to a Person object must never summon institution
      // chrome; classification follows the canonical target.
      expect(
          NavigationAuthority.contextOf('/institution/i1/u/amina',
              isAuthed: true),
          ShellContext.member);
      expect(
          NavigationAuthority.legacyAliasTarget('/institution/i1/u/amina'),
          '/u/amina');
      expect(
          NavigationAuthority.legacyAliasTarget(
              '/institution/i1/institutions/acme'),
          '/institutions/acme');
      // Canonical institution DEPTH still classifies as institution chrome.
      expect(
          NavigationAuthority.contextOf('/institution/i1/members',
              isAuthed: true),
          ShellContext.institution);
    });

    test('the institutions DIRECTORY and OBJECT are never institution chrome',
        () {
      expect(NavigationAuthority.contextOf('/institutions', isAuthed: true),
          ShellContext.member);
      expect(
          NavigationAuthority.contextOf('/institutions/acme', isAuthed: true),
          ShellContext.member);
    });
  });
}
