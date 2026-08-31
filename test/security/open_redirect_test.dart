import 'package:aura/app/route_targets.dart';
import 'package:flutter_test/flutter_test.dart';

/// OPEN REDIRECT AT THE AUTH BOUNDARY.
///
/// `?redirect=` is how a destination survives sign-in, which makes it the most
/// attacker-attractive parameter in the product: a genuine `auraplatform.org`
/// link, a real Aura login, and then wherever the parameter says.
///
/// The guard used to be "must start with '/'". That is not enough, and the two
/// ways past it are both old and both work in real browsers:
///
///   //evil.com/x   protocol-relative — starts with '/', and a browser reads
///                  it as https://evil.com/x
///   /\evil.com/x   a backslash is not a path separator in the URI grammar,
///                  but browsers normalise it to one, which produces the case
///                  above
///
/// Worse, the authority survived `uri.replace(path: ...)`, so the legacy
/// normalisation branches carried it through intact and handed back a fully
/// off-site location.
void main() {
  const backslash = r'/\evil.com/threads/abc';

  group('a preserved destination can never leave the site', () {
    final escapes = <String>[
      '//evil.com',
      '//evil.com/path',
      '//evil.com/threads/abc', // through the legacy normalisation branch
      '//user:pass@evil.com/x',
      backslash,
      r'/\/evil.com/x',
      r'\\evil.com\x',
      'https://evil.com/x',
      'http://evil.com/x',
      'javascript:alert(1)',
      '//evil.com/posts/1?next=/home',
    ];

    for (final hostile in escapes) {
      test('refuses $hostile', () {
        final out = normalizeMemberFacingRoute(hostile);
        expect(out, '/home', reason: '$hostile resolved to $out');
      });
    }

    test('no output ever carries an authority', () {
      // The general property, rather than a list of known tricks: whatever
      // comes back must be a site-relative path.
      for (final hostile in escapes) {
        final out = normalizeMemberFacingRoute(hostile);
        expect(out.startsWith('//'), isFalse);
        expect(Uri.parse(out).hasAuthority, isFalse);
        expect(Uri.parse(out).hasScheme, isFalse);
      }
    });
  });

  group('legitimate destinations still survive', () {
    test('an ordinary member path passes through', () {
      expect(normalizeMemberFacingRoute('/messages'), '/messages');
      expect(normalizeMemberFacingRoute('/posts/abc'), '/posts/abc');
    });

    test('the legacy normalisations still work', () {
      // The fix must not be a blunt rejection that also kills the real cases
      // these branches exist for.
      expect(normalizeMemberFacingRoute('/threads/abc'),
          '/conversations?threadId=abc');
      expect(normalizeMemberFacingRoute('/author/someone'), '/u/someone');
      expect(normalizeMemberFacingRoute('/profile'), '/me');
    });

    test('a query string is preserved', () {
      expect(normalizeMemberFacingRoute('/posts/abc?from=share'),
          contains('from=share'));
    });

    test('empty and root fall back rather than becoming a destination', () {
      expect(normalizeMemberFacingRoute(''), '/home');
      expect(normalizeMemberFacingRoute('/'), '/home');
      expect(normalizeMemberFacingRoute(null), '/home');
    });
  });
}
