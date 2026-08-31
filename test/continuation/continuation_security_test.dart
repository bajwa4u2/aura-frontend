import 'package:aura/app/route_classification.dart';
import 'package:aura/core/continuation/native_continuation.dart';
import 'package:aura/core/continuation/windows_activation.dart';
import 'package:flutter_test/flutter_test.dart';

/// NATIVE CONTINUATION MUST NEVER CONVERT KNOWLEDGE OF A URL INTO AUTHORIZATION.
///
/// Continuation widens the number of doors into the product, so it is exactly
/// the kind of change that quietly turns "you can name it" into "you can see
/// it". These tests hold that line at the two places untrusted input enters:
/// a link handed over by the OS, and a command-line argument on Windows.
void main() {
  group('a resolved destination is still only a destination', () {
    test('resolution does not classify, and cannot promote a private route',
        () {
      // The resolver maps names. If it could ever be persuaded to emit a
      // member path, the router would still gate it -- but it must not be
      // able to emit one at all from a public share url.
      const hostile = [
        '/p/../home',
        '/p/../../admin',
        '/p/a/../../messages',
        '/p/u/../../me',
        '/p/i/../../../settings/x',
      ];
      for (final path in hostile) {
        final target = resolveCanonicalShare(path);
        expect(target, isNull, reason: '$path must not resolve at all');
      }
    });

    test('no share url resolves onto a member surface', () {
      const probes = [
        '/p/home',
        '/p/messages',
        '/p/admin',
        '/p/settings',
        '/p/me',
      ];
      for (final path in probes) {
        final target = resolveCanonicalShare(path);
        // These DO resolve -- as USER_POST ids, which is correct: "home" is a
        // legitimate post id. What matters is where they land.
        expect(target, isNotNull);
        expect(target!.appPath, startsWith('/posts/'),
            reason: 'a post id must land on a post, whatever it spells');
        expect(classifyRoute(target.appPath), RouteClass.public);
      }
    });

    test('an id that looks like a traversal is refused, not normalised', () {
      // '/posts/..' would normalise to '/posts' -- a different screen reached
      // from a url that named a post.
      expect(resolveCanonicalShare('/p/..'), isNull);
      expect(resolveCanonicalShare('/p/%2e%2e'), isNotNull,
          reason: 'percent-encoded text is an opaque id, not a traversal: it '
              'is never decoded into a path separator here');
      expect(resolveCanonicalShare('/p/%2e%2e')!.appPath, '/posts/%2e%2e');
    });
  });

  group('Windows activation arguments are untrusted input', () {
    test('a foreign host is refused', () {
      // The danger is concrete: a shortcut, a script or another app can pass
      // any argument. Accepting an arbitrary host would let it choose a
      // destination inside Aura.
      for (final url in const [
        'https://evil.example/p/art/x',
        'https://auraplatform.org.evil.example/p/art/x',
        'https://notauraplatform.org/p/art/x',
        'http://auraplatform.org/p/art/x',
      ]) {
        expect(destinationFromActivationUrl(url), isNull, reason: url);
      }
    });

    test('an associated host resolves to the in-app destination', () {
      expect(
        destinationFromActivationUrl('https://auraplatform.org/p/art/my-essay'),
        '/articles/my-essay',
      );
      expect(
        destinationFromActivationUrl('https://app.auraplatform.org/p/u/someone'),
        '/u/someone',
      );
    });

    test('the app scheme folds its authority back into the path', () {
      // `aura://p/art/x` parses with host 'p'. Losing that segment would
      // resolve the wrong object.
      expect(destinationFromActivationUrl('aura://p/art/x'), '/articles/x');
      expect(destinationFromActivationUrl('aura:///p/art/x'), '/articles/x');
      expect(destinationFromActivationUrl('aura://articles/x'), '/articles/x');
    });

    test('unsupported and malformed schemes are refused', () {
      for (final url in const [
        'file:///C:/Windows/System32',
        'javascript:alert(1)',
        'data:text/html,<script>',
        'ftp://auraplatform.org/p/art/x',
        '',
        '   ',
        'not a url at all',
        '://',
      ]) {
        expect(destinationFromActivationUrl(url), isNull,
            reason: url.isEmpty ? '(empty)' : url);
      }
    });

    test('a query string is preserved but the destination is not rewritten',
        () {
      // Query is how the auth boundary carries a preserved destination, so it
      // must survive. It must not be able to change WHICH object is opened.
      final out = destinationFromActivationUrl(
          'https://auraplatform.org/p/art/x?utm=1');
      expect(out, '/articles/x?utm=1');
    });

    test('an open-redirect attempt in the query does not become the destination',
        () {
      final out = destinationFromActivationUrl(
          'https://auraplatform.org/p/art/x?redirect=https://evil.example');
      // The path is still the article. Whether the router honours `redirect`
      // is the router's own guarded decision, and it rejects absolute urls.
      expect(out, startsWith('/articles/x?'));
      expect(out, isNot(startsWith('http')));
    });

    test('the first activation argument wins and the rest are ignored', () {
      final out = initialPathFromActivationArgs([
        'C:\\Program Files\\Aura\\aura.exe',
        'https://auraplatform.org/p/art/first',
        'https://auraplatform.org/p/art/second',
      ]);
      expect(out, '/articles/first');
    });

    test('a normal launch yields no destination', () {
      expect(initialPathFromActivationArgs(const []), isNull);
      expect(
        initialPathFromActivationArgs(const ['--verbose', 'C:\\x\\aura.exe']),
        isNull,
      );
    });

    test('a member path from an associated host is passed through, not blocked',
        () {
      // Deliberate: continuation does not decide authority. Opening
      // /messages from a real Aura url is legitimate for the person who owns
      // that session, and the router's redirect is what requires the session.
      // Swallowing it here would break a signed-in person's own deep link.
      final out = destinationFromActivationUrl(
          'https://app.auraplatform.org/messages');
      expect(out, '/messages');
      expect(classifyRoute(out!), RouteClass.member,
          reason: 'and MEMBER is what makes the router demand a session');
    });
  });

  group('unknown families degrade honestly', () {
    test('a newer share family lands on public, never on home', () {
      // Home is where a lost destination goes. The distinction matters: this
      // is a real object, and the person should see Aura is a real place
      // rather than silently arrive somewhere unrelated.
      expect(destinationFromActivationUrl('https://auraplatform.org/p/zz/thing'),
          '/public');
      expect(isCanonicalSharePath('/p/zz/thing'), isTrue);
    });
  });
}
