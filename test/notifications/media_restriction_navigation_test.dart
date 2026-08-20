import 'package:flutter_test/flutter_test.dart';

import 'package:aura/core/navigation/canonical_destinations.dart';
import 'package:aura/features/feed/domain/feed_item.dart';

/// CH-12 E6 — the tap that did nothing.
///
/// The live walkthrough failed at member step 2: a real MEDIA_QUARANTINED
/// notification rendered, and tapping it went nowhere. The cause was that the
/// destination was expected to arrive in a stored `deeplink`, and the notice in
/// production had been written before that field existed — so the resolver
/// found no target, returned null, and the tap handler silently returned.
///
/// The fixture below is the ACTUAL production payload shape, copied from the
/// row that failed. A test built from an idealised payload would have passed
/// while the product stayed broken, which is precisely how this shipped.
void main() {
  // The real row: notice data with NO deeplink key at all.
  const productionQuarantinedPayload = <String, dynamic>{
    'appeal': {'available': true, 'route': 'media.quarantine.appeal'},
    'context': 'Automated examination identified malicious content in this file.',
    'subject': {
      'mediaId': 'cmt22wk140001rn951l9a1wno',
      'fileName': 'ch12-e6-certification-fixture.txt',
      'mimeType': 'text/plain',
    },
    'category': 'MALICIOUS_CONTENT',
    'disposition': 'PRELIMINARY',
    'appealStatus': null,
    'useRestricted': true,
    'automatedVerdict': true,
  };

  // The lifted notice carries the id FLAT, not nested under `subject`.
  const liftedPayload = <String, dynamic>{
    'mediaId': 'cmt22wk140001rn951l9a1wno',
    'fileName': 'ch12-e6-certification-fixture.txt',
    'available': true,
  };

  group('the destination resolves from the notice itself', () {
    test('resolves the REAL production quarantine payload, which has no deeplink', () {
      final id = mediaIdFromRestrictionNotice(productionQuarantinedPayload);
      expect(id, 'cmt22wk140001rn951l9a1wno');
      expect(
        restrictedMediaDestination(id),
        '/media/cmt22wk140001rn951l9a1wno/restricted',
      );
    });

    test('resolves the lifted payload, whose id is flat rather than nested', () {
      // One reader for both shapes, so the paired lifecycle notifications
      // cannot drift apart — the failure that would have left QUARANTINED
      // navigable and LIFTED not.
      final id = mediaIdFromRestrictionNotice(liftedPayload);
      expect(id, 'cmt22wk140001rn951l9a1wno');
      expect(
        restrictedMediaDestination(id),
        '/media/cmt22wk140001rn951l9a1wno/restricted',
      );
    });

    test('both notices resolve to the SAME surface', () {
      expect(
        restrictedMediaDestination(
            mediaIdFromRestrictionNotice(productionQuarantinedPayload)),
        restrictedMediaDestination(mediaIdFromRestrictionNotice(liftedPayload)),
      );
    });

    test('does not depend on a stored deeplink being present', () {
      // The regression in one line: the payload has no `deeplink`, and the
      // destination must still be minted.
      expect(productionQuarantinedPayload.containsKey('deeplink'), isFalse);
      expect(
        restrictedMediaDestination(
            mediaIdFromRestrictionNotice(productionQuarantinedPayload)),
        isNotNull,
      );
    });

    test('resolves a newer notice that DOES carry a deeplink identically', () {
      final withDeeplink = <String, dynamic>{
        ...productionQuarantinedPayload,
        'deeplink': '/media/cmt22wk140001rn951l9a1wno/restricted',
      };
      expect(
        restrictedMediaDestination(mediaIdFromRestrictionNotice(withDeeplink)),
        '/media/cmt22wk140001rn951l9a1wno/restricted',
      );
    });
  });

  group('no destination is invented', () {
    test('returns null when the notice names no media', () {
      expect(mediaIdFromRestrictionNotice(const {}), isNull);
      expect(restrictedMediaDestination(null), isNull);
    });

    test('returns null for a blank or whitespace id', () {
      expect(restrictedMediaDestination(''), isNull);
      expect(restrictedMediaDestination('   '), isNull);
      expect(
        mediaIdFromRestrictionNotice(const {
          'subject': {'mediaId': '  '}
        }),
        isNull,
      );
    });

    test('falls back to the flat id when subject carries none', () {
      expect(
        mediaIdFromRestrictionNotice(const {
          'subject': {'fileName': 'x.txt'},
          'mediaId': 'm2',
        }),
        'm2',
      );
    });
  });

  group('the shell adapter does not mangle the destination', () {
    test('leaves it untouched from the member notifications surface', () {
      // /notifications is a member-shell route, so currentPath never starts
      // with /institution/ and the adapter is a no-op. Pinned rather than
      // assumed, because the adapter prefixes ANY route it is given inside an
      // institution shell.
      const canonical = '/media/cmt22wk140001rn951l9a1wno/restricted';
      expect(
        FeedRouting.adaptTargetRoute(canonical, currentPath: '/notifications'),
        canonical,
      );
    });

    test('documents what WOULD happen inside an institution shell', () {
      // Recorded, not endorsed: if this surface were ever hosted inside the
      // institution shell, the adapter would produce a route that does not
      // exist. It is a no-op today only because of where /notifications lives.
      const canonical = '/media/m1/restricted';
      expect(
        FeedRouting.adaptTargetRoute(canonical, currentPath: '/institution/i1/posts'),
        '/institution/i1/media/m1/restricted',
      );
    });
  });
}
