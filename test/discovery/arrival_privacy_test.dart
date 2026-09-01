import 'package:aura/core/discovery/arrival_report.dart';
import 'package:flutter_test/flutter_test.dart';

/// THE DISCLOSURE BOUNDARY, TESTED WITHOUT A BROWSER.
///
/// `referrerOriginOf` is the point where a complete referring URL becomes a
/// bare origin. A referring URL carries a query string and a query string
/// carries people, so this reduction is the whole privacy design of
/// AURA_REFERRAL — and a boundary that can only be checked by running a
/// browser is a boundary nobody checks.
void main() {
  group('a referrer is reduced to an origin before it leaves the device', () {
    test('scheme and host survive; path, query and fragment do not', () {
      expect(
        referrerOriginOf('https://www.google.com/search?q=someone%40example.com'),
        'https://www.google.com',
      );
      expect(
        referrerOriginOf('https://x.com/user/status/123#reply'),
        'https://x.com',
      );
    });

    test('a query string that carries a person is discarded entirely', () {
      // The case this exists for. Nothing of the query may survive.
      final origin = referrerOriginOf(
        'https://mail.example.com/inbox?to=ada%40example.test&token=abc123',
      );
      expect(origin, 'https://mail.example.com');
      expect(origin, isNot(contains('ada')));
      expect(origin, isNot(contains('token')));
      expect(origin, isNot(contains('@')));
      expect(origin, isNot(contains('?')));
    });

    test('a non-default port is kept — it is part of the origin', () {
      expect(referrerOriginOf('https://host.test:8443/x'), 'https://host.test:8443');
    });

    test('credentials in the URL never survive', () {
      final origin = referrerOriginOf('https://user:secret@host.test/path');
      expect(origin, isNot(contains('secret')));
      expect(origin, isNot(contains('user:')));
    });

    test('absent, empty and unparseable referrers yield null', () {
      expect(referrerOriginOf(null), isNull);
      expect(referrerOriginOf(''), isNull);
      expect(referrerOriginOf('   '), isNull);
      expect(referrerOriginOf('not a url'), isNull);
    });

    test('non-http schemes are refused rather than passed through', () {
      // `javascript:` and `data:` referrers are not arrivals, and echoing one
      // back to the server would be forwarding attacker-controlled text.
      expect(referrerOriginOf('javascript:alert(1)'), isNull);
      expect(referrerOriginOf('data:text/html,hi'), isNull);
      expect(referrerOriginOf('file:///C:/secret.txt'), isNull);
    });
  });

  group('only published public addresses are observable', () {
    test('canonical share paths are', () {
      expect(isObservableArrival('/p/art/how-aura-works'), isTrue);
      expect(isObservableArrival('/p/inst/northgate'), isTrue);
    });

    test('internal routes are NOT — that is a person already inside Aura', () {
      for (final path in const [
        '/home',
        '/messages/c/abc',
        '/admin/work',
        '/settings',
        '/u/rowan',
      ]) {
        expect(isObservableArrival(path), isFalse, reason: path);
      }
    });
  });
}
