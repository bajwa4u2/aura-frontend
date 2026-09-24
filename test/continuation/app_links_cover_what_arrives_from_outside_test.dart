import 'dart:io';
import 'package:xml/xml.dart';

import 'package:flutter_test/flutter_test.dart';

/// WHICH LINKS OPEN THE APP — AND WHICH DELIBERATELY DO NOT.
///
/// C-18 was filed as *"Android App Links: `https://auraplatform.org/me` doesn't
/// open the app"*. Measured on a Pixel 9a running the **Play** build of
/// 1.4.4 (39) on 2026-09-24 (`pm get-app-links`, `cmd package
/// query-activities`), the picture was more interesting than the report:
///
///   * both domains report `verified`, so nothing is wrong with the
///     assetlinks ceremony;
///   * `/meetings/join/…`, `/u/…`, `/p/…`, `/posts/…`, `/articles/…`,
///     `/spaces/…`, `/institutions/…`, `/invite/…` all resolved to
///     `org.auraplatform.app/.MainActivity`;
///   * `/me`, `/home`, `/messages`, `/activity`, `/settings`,
///     `/institution/…` (singular) all resolved to the BROWSER;
///   * so did every `/i/…` link.
///
/// The manifest states its own rule in its comments: the declared set is the
/// links that ARRIVE FROM OUTSIDE — the public share family, the destinations
/// those shares resolve to, guest-reachable entry, and the invitation and auth
/// ceremonies that complete a destination. Personal in-app surfaces are
/// deliberately absent, and `/institution/…` singular is the AUTHENTICATED
/// institution workspace (`/institution/dashboard`, `/institution/create`, …),
/// not a public destination.
///
/// By that rule `/me` is working as designed, and "fixing" it would hand every
/// personal surface to an app the recipient may not be signed into.
///
/// The one genuine gap was `/i/`, which carries the public booking family and
/// an invitation ceremony — including cancel and reschedule links that arrive
/// BY EMAIL, and are therefore invisible to in-app testing. `/i/:token` claims
/// an invitation while `/invite/…` next door was always declared: two
/// invitation paths, one of them reachable.
void main() {
  final manifest = XmlDocument.parse(
    File('android/app/src/main/AndroidManifest.xml').readAsStringSync(),
  );

  const android = 'android:';

  /// Every path or prefix declared on the auto-verified App Links filter.
  final declared = (() {
    for (final filter in manifest.findAllElements('intent-filter')) {
      if (filter.getAttribute('${android}autoVerify') != 'true') continue;
      return filter
          .findAllElements('data')
          .map((d) =>
              d.getAttribute('${android}pathPrefix') ??
              d.getAttribute('${android}path'))
          .whereType<String>()
          .toList();
    }
    throw StateError('no autoVerify App Links intent-filter in the manifest');
  })();

  final hosts = (() {
    for (final filter in manifest.findAllElements('intent-filter')) {
      if (filter.getAttribute('${android}autoVerify') != 'true') continue;
      return filter
          .findAllElements('data')
          .map((d) => d.getAttribute('${android}host'))
          .whereType<String>()
          .toList();
    }
    return <String>[];
  })();

  bool covers(String path) =>
      declared.any((d) => d.endsWith('/') ? path.startsWith(d) : path == d);

  group('the ceremony itself is intact', () {
    test('both hosts are claimed', () {
      expect(hosts, containsAll(['auraplatform.org', 'app.auraplatform.org']));
    });
  });

  group('links that arrive from outside reach the app', () {
    const mustOpen = <String, String>{
      '/meetings/join/warm-cove-461': 'guest-reachable meeting entry',
      '/u/msbajwa': 'a shared profile',
      '/p/abc': 'the canonical public share family',
      '/posts/abc': 'a shared post',
      '/articles/abc': 'a shared article',
      '/announcements/abc': 'a shared announcement',
      '/spaces/abc': 'a shared space',
      '/institutions/abc': 'a public institution page',
      '/invite/abc': 'an invitation',
      '/verify-email': 'an auth ceremony, from email',
      '/reset-password': 'an auth ceremony, from email',
      // THE C-18 REPAIR. Every one of these arrived by email or was handed to
      // a guest, and every one of them opened the browser instead.
      '/i/aura/meet/intro': 'a public booking page',
      '/i/aura/meet/intro/book': 'booking it',
      '/i/aura/meet/cancel/tok123': 'cancelling, from a confirmation email',
      '/i/aura/meet/reschedule/tok123': 'rescheduling, from an email',
      '/i/tok123': 'claiming an invitation',
    };

    mustOpen.forEach((path, why) {
      test('$path — $why', () {
        expect(covers(path), isTrue, reason: '$path would open the browser');
      });
    });
  });

  group('personal in-app surfaces stay OUT, by design', () {
    // Declaring these would hand a personal surface to an app the recipient may
    // not be signed into, and would capture company pages on the apex domain —
    // the two hosts share one filter. C-18's literal report was `/me`; this is
    // the assertion that says why it was not simply added.
    const mustNotOpen = <String>[
      '/me',
      '/home',
      '/messages',
      '/discover',
      '/activity',
      '/notifications',
      '/settings',
      '/saved',
      '/compose',
      '/create',
      // The AUTHENTICATED institution workspace, not a public destination.
      '/institution/dashboard',
      '/institution/create',
      '/institution/correspondence',
    ];

    for (final path in mustNotOpen) {
      test('$path is not claimed', () {
        expect(covers(path), isFalse,
            reason: '$path is an in-app surface; claiming it hands a personal '
                'destination to an app the recipient may not be signed into');
      });
    }
  });

  group('the distinction between the two institution routes is preserved', () {
    test('plural is public and claimed, singular is workspace and is not', () {
      expect(covers('/institutions/some-slug'), isTrue);
      expect(covers('/institution/dashboard'), isFalse);
    });
  });
}
