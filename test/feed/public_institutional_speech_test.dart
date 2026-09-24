import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:aura/features/feed/domain/feed_item.dart';

/// C-11 — PUBLIC INSTITUTIONAL SPEECH MUST NOT NEED AN ACCOUNT.
///
/// The server's canonical destination for an institution post is
/// `/institution/<slug>/posts/<id>` — the WORKSPACE address. That path is
/// classified `member` and therefore sits behind `requiresAuth`, so a
/// signed-out visitor reading the public discourse feed tapped an OFFICIAL
/// post and landed on `/login`.
///
/// An institution speaking publicly is precisely the speech that most needs to
/// be readable by somebody who has no account yet.
///
/// The public address already existed in two senses and was usable in neither:
/// `route_classification.dart` classifies `/institutions/...` (plural) as
/// PUBLIC, and the product already PUBLISHES this address — the share link
/// `/p/i/<inst>/<post>` maps to `/institutions/<slug>/posts/<id>`. It simply
/// had no route registered, so a shared link resolved to nothing.
void main() {
  group('signed out, an institution post resolves publicly', () {
    test('THE DEFECT: the workspace address becomes the public one', () {
      expect(
        FeedRouting.publicInstitutionPostRoute(
          '/institution/aura-platform/posts/abc123',
          signedIn: false,
        ),
        '/institutions/aura-platform/posts/abc123',
      );
    });

    test('adaptTargetRoute applies it', () {
      expect(
        FeedRouting.adaptTargetRoute(
          '/institution/aura-platform/posts/abc123',
          currentPath: '/discover',
          signedIn: false,
        ),
        '/institutions/aura-platform/posts/abc123',
      );
    });
  });

  group('signed in, nothing changes', () {
    test('a member keeps the workspace address', () {
      expect(
        FeedRouting.publicInstitutionPostRoute(
          '/institution/aura-platform/posts/abc123',
          signedIn: true,
        ),
        '/institution/aura-platform/posts/abc123',
      );
    });

    test('the institution-shell adaptation still works', () {
      // The existing rule: inside a shell, a canonical route is re-homed into
      // that shell. It must survive the new rewrite sitting in front of it.
      expect(
        FeedRouting.adaptTargetRoute(
          '/posts/xyz',
          currentPath: '/institution/aura-platform/explore',
          signedIn: true,
        ),
        '/institution/aura-platform/posts/xyz',
      );
    });
  });

  group('it rewrites only what it recognises', () {
    test('other institution routes are untouched', () {
      for (final path in [
        '/institution/aura-platform/posts/new',
        '/institution/aura-platform/posts/abc/edit',
        '/institution/aura-platform/explore',
        '/institution/aura-platform',
      ]) {
        expect(
          FeedRouting.publicInstitutionPostRoute(path, signedIn: false),
          path,
          reason: path,
        );
      }
    });

    test('a non-institution route is untouched', () {
      expect(
        FeedRouting.publicInstitutionPostRoute('/posts/abc', signedIn: false),
        '/posts/abc',
      );
    });
  });

  group('the public route is actually registered', () {
    // The whole defect was an address that existed everywhere except the
    // router. Rewriting the link without registering it would only move the
    // dead end.
    final router = File('lib/router.dart').readAsStringSync();

    test('/institutions/:slug/posts/:postId exists', () {
      expect(router, contains("path: '/institutions/:slug/posts/:postId'"));
    });

    test('it does NOT sit behind the member boundary', () {
      final start = router.indexOf("path: '/institutions/:slug/posts/:postId'");
      final region = router.substring(start, start + 400);
      expect(region, isNot(contains('InstitutionRouteScope')),
          reason: 'that boundary resolves membership, which is exactly what a '
              'signed-out reader does not have');
      expect(region, contains('InstitutionPostDetailScreen'));
    });
  });
}
