import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:aura/features/profile/domain/profile.dart';

/// STORED IS NOT VISIBLE.
///
/// The API has always sent `publications` and `links` on a public profile —
/// `publicSelect` includes both — and the client's `Profile` model never read
/// them, so `AuthorProfileScreen` had nothing to render and showed nothing. A
/// person's declared works were stored perfectly and invisible to every
/// reader.
///
/// Found on 2026-09-09 only because someone scrolled the actual public page to
/// the bottom and reported the section was not there. The write path had
/// already been proven correct against the database, which is exactly why
/// "stored" and "visible" have to be separate claims.
void main() {
  Profile parse(Map<String, dynamic> json) => Profile.fromJson({
        'id': 'u1',
        'handle': 'bajwawrites',
        'displayName': 'M S Bajwa',
        ...json,
      });

  group('a public profile carries the works it was sent', () {
    test('reads the real production payload', () {
      final profile = parse({
        'publications': [
          {
            'url': 'https://bajwawrites.com/books/the-burden-of-knowing',
            'year': null,
            'title': 'The Burden of Knowing',
            'publisher': null,
            'description':
                'A reflection on the distance between knowing and applying.',
          },
        ],
        'links': [
          {'url': 'https://linkedin.com/in/msbajwa', 'label': 'linkedin'},
        ],
      });

      expect(profile.publications, hasLength(1));
      expect(profile.publications.first.title, 'The Burden of Knowing');
      expect(profile.publications.first.url,
          'https://bajwawrites.com/books/the-burden-of-knowing');
      expect(profile.publications.first.description, isNotNull);
      expect(profile.links.single.label, 'linkedin');
    });

    test('reads the legacy aliases too', () {
      // The same tolerance the canonical contract prescribes. A profile must
      // not blank a person's work because an older payload said `link`.
      final profile = parse({
        'publications': [
          {'name': 'Aliased', 'href': 'https://example.org/x', 'summary': 'Desc'},
        ],
        'links': [
          {'link': 'https://example.org', 'title': 'Example'},
        ],
      });
      expect(profile.publications.single.title, 'Aliased');
      expect(profile.publications.single.url, 'https://example.org/x');
      expect(profile.publications.single.description, 'Desc');
      expect(profile.links.single.url, 'https://example.org');
    });

    test('is empty, not broken, when the profile has none', () {
      final profile = parse({});
      expect(profile.publications, isEmpty);
      expect(profile.links, isEmpty);
    });

    test('skips a row nobody filled in', () {
      final profile = parse({
        'publications': [
          {'title': null, 'url': null, 'description': null},
          {'title': 'Real'},
        ],
      });
      expect(profile.publications.map((p) => p.title), ['Real']);
    });

    test('a link with no url is not a link', () {
      final profile = parse({
        'links': [
          {'label': 'nowhere'},
          {'label': 'somewhere', 'url': 'https://example.org'},
        ],
      });
      expect(profile.links.map((l) => l.label), ['somewhere']);
    });
  });

  group('a publication is not a link', () {
    test('only a publication carries a description', () {
      final profile = parse({
        'publications': [
          {'title': 'Work', 'description': "The author's own words"},
        ],
        'links': [
          {'url': 'https://example.org', 'label': 'x', 'description': 'ignored'},
        ],
      });
      // Both may carry a URL. That is not a reason to give a link the
      // semantics of an authored work.
      expect(profile.publications.single.description, "The author's own words");
      expect(profile.links.single.label, 'x');
    });
  });

  group('the screen actually mounts them', () {
    // Reading them into the model is only half of it: the whole defect was a
    // render path that was never reached, with a model that parsed fine.
    final source = File(
      'lib/features/profile/presentation/author_profile_screen.dart',
    ).readAsStringSync();

    test('the published record is on the profile tab', () {
      expect(source, contains('_publishedRecordSection(profile.publications)'));
      expect(source, contains('_elsewhereSection(profile.links)'));
    });

    test('the published record comes before the posts feed', () {
      final record = source.indexOf('_publishedRecordSection(profile.publications)');
      final feed = source.indexOf('_workSection(posts),');
      expect(record, greaterThan(-1));
      expect(feed, greaterThan(-1));
      expect(record, lessThan(feed),
          reason: 'a reader came for the works, not for the feed');
    });

    test('external destinations are scheme-checked on the way out', () {
      // The contract refuses non-http(s) on write; this refuses it again on
      // the way out, so no legacy row can become a `javascript:` navigation.
      expect(source, contains("uri.scheme != 'http' && uri.scheme != 'https'"));
    });
  });

  group('a link hydrates with its own content', () {
    test('a publication carries the cover the destination served', () {
      final profile = parse({
        'publications': [
          {
            'title': 'The Burden of Knowing',
            'url': 'https://bajwawrites.com/books/the-burden-of-knowing',
            'coverUrl': 'https://api.auraplatform.org/v1/link-previews/p1/image',
          },
        ],
      });
      expect(profile.publications.single.coverUrl, contains('link-previews'));
    });

    test('a link carries its site mark, not a cover', () {
      // A favicon, not a banner. A link needs the identity of where it goes;
      // a full-width image would make a bookmark look like an authored work.
      final profile = parse({
        'links': [
          {
            'url': 'https://github.com/bajwa4u2',
            'label': 'github',
            'iconUrl': 'https://api.auraplatform.org/v1/link-previews/l1/favicon',
          },
        ],
      });
      expect(profile.links.single.iconUrl, contains('favicon'));
    });

    test('no cover is an absence, not an error', () {
      final profile = parse({
        'publications': [
          {'title': 'Uncovered', 'url': 'https://example.org/x'},
        ],
      });
      expect(profile.publications.single.coverUrl, isNull);
    });

    test('enrichment never speaks for the person', () {
      // The founder's own words must survive whatever the page says about
      // itself. bajwawrites.com currently answers every book URL with the
      // publishing house's name and blurb; if that were allowed to win, three
      // descriptions would collapse into one sentence.
      final profile = parse({
        'publications': [
          {
            'title': 'The Burden of Knowing',
            'description': 'A reflection on the distance between knowing and applying.',
            'url': 'https://bajwawrites.com/books/the-burden-of-knowing',
            'coverUrl': 'https://api.auraplatform.org/v1/link-previews/p1/image',
          },
        ],
      });
      final publication = profile.publications.single;
      expect(publication.title, 'The Burden of Knowing');
      expect(publication.description, startsWith('A reflection'));
    });
  });

  group('hydration never happens during a render', () {
    final service = File(
      '../aura-backend/src/users/users.service.ts',
    ).readAsStringSync();

    test('the profile read consults the cache and does not fetch', () {
      // A profile render must not make a network call as a side effect, or a
      // slow publisher page becomes a slow profile.
      expect(service, contains('withLinkHydration'));
      expect(service, contains('LinkPreviewStatus.READY'));
      expect(service, isNot(contains('await this.linkIntelligence.resolve')));
    });
  });
}
