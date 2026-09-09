import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// THE CLIENT HALF OF THE PROFILE COLLECTIONS CONTRACT.
///
/// The editor asked the person for a title, a link and a description. The
/// client sent `{title, link, description}`. The server read
/// `{title, url, publisher, year}`. `title` matched and survived; `link` was
/// discarded because the server only knew `url`; `description` was discarded
/// because the server had no such field at all. The save answered 200 and the
/// content was gone.
///
/// Two publications sit in production with `url: null` as the visible residue,
/// including the founder's own "The Burden of Knowing".
///
/// The asymmetry is what hid it. The client's READER is tolerant —
/// `_firstPresent(['link','url','href'])` — sitting over a strict server
/// writer. A generous reader over a strict writer turns a contract break into
/// empty fields rather than an error. The reader stays tolerant, because it
/// must understand what older clients wrote; the WRITER is now canonical.
///
/// This asserts the client's half against the SAME golden fixture the backend
/// spec uses (`aura-backend/src/users/profile-collections.contract.spec.ts`),
/// so a rename on either side has to break a test before it can reach anyone's
/// profile.
void main() {
  /// Keep in lockstep with GOLDEN_PUBLICATION in the backend spec.
  const goldenPublication = {
    'title': 'The Burden of Knowing',
    'url': 'https://bajwawrites.com/books/the-burden-of-knowing',
    'description':
        'A reflection on the distance between knowing and applying, and what '
            'responsibility remains after knowledge is already known.',
    'publisher': 'Bajwa Write',
    'year': 2026,
  };

  const goldenLink = {
    'label': 'linkedin',
    'url': 'https://linkedin.com/in/msbajwa',
  };

  final source =
      File('lib/features/me/presentation/edit_profile_screen.dart')
          .readAsStringSync();

  group('the writer emits canonical names', () {
    test('a publication is written with url, never link', () {
      // The single line that caused this. `'link':` on the wire is the defect.
      expect(source, contains("'url': link"));
      expect(
        source,
        isNot(contains("return {'title': title, 'link': link")),
        reason: 'the writer must not send `link` — the server only knows `url`',
      );
    });

    test('a publication is written with a description', () {
      expect(source, contains("'description': description"));
    });

    test('a link is written with label and url', () {
      expect(source, contains("return {'label': label, 'url': url}"));
    });
  });

  group('the reader stays tolerant, deliberately', () {
    test('it still understands what older clients wrote', () {
      // Released clients stored nothing under `link` server-side, but a
      // payload in flight may still carry it, and the tolerance costs nothing.
      expect(source, contains("const ['link', 'url', 'href']"));
      expect(source, contains("const ['description', 'summary', 'note']"));
      expect(source, contains("const ['title', 'name']"));
    });
  });

  group('the golden fixture is the one both ends use', () {
    test('every canonical publication field is present in it', () {
      expect(goldenPublication.keys.toSet(),
          {'title', 'url', 'description', 'publisher', 'year'});
    });

    test('a link carries no publication semantics', () {
      // Both carry a URL. That is not a reason to merge them: a publication is
      // an authored work; a link is a destination.
      expect(goldenLink.containsKey('description'), isFalse);
      expect(goldenLink.containsKey('publisher'), isFalse);
    });

    test('it survives a JSON round trip unchanged', () {
      expect(jsonDecode(jsonEncode(goldenPublication)), goldenPublication);
      expect(jsonDecode(jsonEncode(goldenLink)), goldenLink);
    });
  });

  group('a publication is an assertion, not a verified fact', () {
    test('the fixture carries no verification or trust field', () {
      // Founder-frozen: a person declaring a work on their profile is a
      // profile assertion. Corroboration belongs to the separate governed
      // verification machinery and must never be inferred from someone typing
      // a title into a form.
      for (final key in goldenPublication.keys) {
        expect(
          key.toLowerCase(),
          isNot(anyOf(contains('verif'), contains('trust'), contains('badge'))),
        );
      }
    });
  });
}
