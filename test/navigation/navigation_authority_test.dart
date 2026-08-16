import 'package:flutter_test/flutter_test.dart';

import 'package:aura/core/navigation/navigation_authority.dart';

/// C3 — NAVIGATION AUTHORITY PINS.
///
/// The five authenticated primaries are founder-frozen (destination
/// checkpoint, 2026-08-16). Selected state is destination identity.
/// Shell context is presentation chrome only — never acting authority.
void main() {
  group('founder-frozen primary IA', () {
    test('authenticated primaries are exactly the five, in order', () {
      expect(
        NavigationAuthority.authenticatedPrimaries
            .map((d) => d.label)
            .toList(),
        ['Home', 'Messages', 'Discover', 'Meetings', 'Me'],
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
        ['/home', '/messages', '/discover', '/meetings', '/me'],
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

    test('me depth resolves to Me but correspondence does not', () {
      expect(NavigationAuthority.primaryOf('/me'), PrimaryDestination.me);
      expect(NavigationAuthority.primaryOf('/me/edit'), PrimaryDestination.me);
      expect(NavigationAuthority.primaryOf('/me/correspondence/t1'),
          PrimaryDestination.messages);
    });

    test('detail routes select nothing (truthful no-selection)', () {
      for (final p in ['/u/amina', '/thread/t1', '/posts/p1', '/admin']) {
        expect(NavigationAuthority.primaryOf(p), isNull, reason: p);
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
