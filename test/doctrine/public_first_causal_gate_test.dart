// PUBLIC-FIRST CAUSAL GATE — hard build failure.
//
// Canonical doctrine (never restated here):
//   representation/inventory/AURA_PUBLIC_FIRST_CAUSAL_DOCTRINE.md
//
// ── WHAT THIS PROTECTS ───────────────────────────────────────────────────────
// Aura's GENERAL identity. People and their communication needs are the
// originating force; institutional identity is accountability infrastructure
// inside a public environment whose value already exists — not the premise by
// which people arrive.
//
// ── WHAT THIS DELIBERATELY DOES NOT DO ───────────────────────────────────────
// It does NOT ban the word "institution". The problem is reversed product
// causality, not institutional vocabulary. Institution-specific surfaces —
// governance, membership administration, official communication, institution
// operations — are legitimately institution-focused and are NOT scanned.
//
// The scope below is a named list of GENERAL/SHARED/AUTH surfaces, kept narrow
// on purpose. A global regex over lib/ would be brittle and would punish
// legitimate institution language.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// General / shared / authentication surfaces: these speak for Aura itself.
const _generalSurfaces = <String>[
  // The entry surfaces speak for Aura before anything else does. Their
  // absence from this list is how an institution-first hero shipped on
  // '/' — found and corrected in the C2 Public Home reconstruction.
  'lib/features/home/presentation/public_home_screen.dart',
  'lib/features/home/presentation/member_home_screen.dart',
  'lib/app/shell/shell_shared.dart',
  'lib/features/auth/presentation/auth_screen.dart',
  'lib/features/auth/presentation/register_screen.dart',
  'lib/screens/founder_message_screen.dart',
  'lib/screens/supporters_hub_screen.dart',
  'pubspec.yaml',

  // Publication and company surfaces speak for Aura itself just as loudly as
  // the entry surfaces do, and they were outside the 2026-08-15 boundary. The
  // white paper hero and the investors architecture block both still asserted
  // the institution-first identity on 2026-09-04, three weeks after the app
  // had been corrected around them.
  'lib/screens/white_paper_screen.dart',
  'lib/screens/investors_hub_screen.dart',
  'lib/screens/mission_screen.dart',
  'lib/screens/patrons_hub_screen.dart',

  // A shared publication component teaches the next author by example. Its doc
  // comment cited the institution-first white-paper title as the exemplar.
  'lib/core/ui/publication/aura_publication_hero.dart',

  // The web metadata layer speaks for Aura to every crawler, every social
  // preview and every PWA install prompt — before a single Flutter frame
  // renders. The 2026-08-15 reconciliation corrected the Dart surfaces and
  // pubspec but never reached here, so institution-first framing survived on
  // the shell defaults that EVERY public route inherits. Scoped in so the
  // same layer cannot drift again.
  'web/index.html',
  'web/manifest.json',

  // The social cards are the same layer one step further out: they are what a
  // person sees on Facebook, LinkedIn or Slack BEFORE they reach any Aura
  // surface at all, and the default card is what every share without a cover
  // image unfurls as. The generator is scoped rather than the PNGs because a
  // gate cannot read text out of an image, so the source of the words is what
  // gets guarded.
  //
  // This file carried the first prohibited phrase in the map below --
  // verbatim, as the default card's headline -- for as long as the gate has
  // existed. Nothing caught it because nothing looked here. Found 2026-09-05
  // while correcting the card the founder called legacy. It is not quoted
  // here: a scan this blunt would flag the comment describing the fix, and
  // the right answer to that is to say less, not to soften the scan.
  'tool/web/generate_og_images.ps1',
  'tool/web/generate_route_metadata.dart',
];

/// Phrases that assert the prohibited reverse causal model, or claim a
/// capability Aura does not have. Each entry names why it fails.
const _prohibited = <String, String>{
  'institution operating infrastructure':
      'States Aura\'s GENERAL identity as institution-operating infrastructure. '
          'PRODUCT_IDENTITY_CANON defines Aura as serving institutions AND the '
          'public they serve, in both directions.',
  'trusted institutions':
      'PUBLIC_REPRESENTATION_CANON B.5 — trust is the visible effect of '
          'accountable behaviour, never claimed as an attribute.',
  'trusted discovery':
      'PUBLIC_REPRESENTATION_CANON B.5 — superseded and banned.',
  'trusted home':
      'PUBLIC_REPRESENTATION_CANON B.5 — trust claimed as an attribute.',
  'connect with institutions':
      'No Connect relationship capability exists anywhere in Aura (C0 found '
          'zero Relationship/Connection model; gate-enforced absent from '
          'Product Language).',
  'build credentials':
      'Implies portable/verifiable credentials. Aura issues nothing portable — '
          'ROLE_OR_CREDENTIAL is an internal governed attestation only.',
  'verified public presence':
      'Institution-first acquisition premise — verification sold as the '
          'reason to arrive. Public Home shipped this hero until the C2 '
          'reconstruction; the causal doctrine prohibits it on general '
          'surfaces.',
  'verified institutional communication':
      'Verification-as-value-proposition framing on a general surface; '
          'verification is a governed fact, not the product premise.',
};

void main() {
  group('Public-first causal gate — general surfaces only', () {
    test('no general surface asserts the reversed causal model', () {
      final violations = <String>[];

      for (final path in _generalSurfaces) {
        final file = File(path);
        expect(file.existsSync(), isTrue,
            reason: 'Scoped general surface is missing: $path. If it moved, '
                'update this gate rather than deleting the rule.');

        final lower = file.readAsStringSync().toLowerCase();
        for (final entry in _prohibited.entries) {
          if (lower.contains(entry.key)) {
            violations.add('  $path\n      "${entry.key}" — ${entry.value}');
          }
        }
      }

      expect(
        violations..sort(),
        isEmpty,
        reason: '\n[PUBLIC-FIRST] Reversed causal framing on a general Aura '
            'surface:\n${violations.join('\n')}\n\n'
            'Aura is public-first: people and their communication needs are the '
            'originating force. Institutional identity is accountability '
            'infrastructure, not the reason people participate.\n\n'
            'This gate does NOT prohibit institution language — institution-'
            'specific surfaces are not scanned. Fix the causality, not the '
            'vocabulary.\n',
      );
    });

    test('the default social card says what the canon says', () {
      // THE NEGATIVE GATE ABOVE IS NOT ENOUGH FOR THIS ONE FILE.
      //
      // Banning a phrase stops the known-wrong headline coming back. It does
      // not stop a fourth wording being invented, which is what actually
      // happened here: the committed card, this generator and web/index.html
      // each carried a different statement of what Aura is, and the card that
      // reached Facebook and LinkedIn was the oldest of the three.
      //
      // So the default card's copy is tied to the metadata layer that already
      // carries the founder-approved public-first correction. Fragments, not
      // whole strings: a headline is not a sentence and a card is not a page,
      // but every claim the card makes must be traceable to one that ships.
      final generator =
          File('tool/web/generate_og_images.ps1').readAsStringSync();
      final index = File('web/index.html').readAsStringSync().toLowerCase();

      final defaultCard = generator.substring(
        generator.indexOf("-OutFile (Join-Path \$assetsDir 'og-default.png')"),
        generator.indexOf("-OutFile (Join-Path \$assetsDir 'og-investors.png')"),
      ).toLowerCase();
      expect(defaultCard, isNotEmpty,
          reason: 'the default card block moved; re-anchor this rather than '
              'deleting the rule');

      for (final claim in const [
        'public-first',
        'civic discourse',
        'people take part in purposeful communication that keeps its context',
        'accountable for what they say officially',
      ]) {
        expect(defaultCard, contains(claim),
            reason: 'the default social card dropped a canonical claim: '
                '"\$claim"');
        expect(index, contains(claim),
            reason: 'the default social card claims "\$claim", which '
                'web/index.html does not. One of them is drifting, and the '
                'card is the one nobody can read without rendering it.');
      }
    });

    test('one place decides the social artwork version', () {
      // A platform caches a scraped image against its URL, so correcting a
      // card under its existing file name changes nothing anyone can see:
      // Facebook keeps its copy until re-scraped, LinkedIn for about a week
      // with no purge reachable from outside. Both the default and mission
      // cards were replaced under their existing names on 2026-09-05, so the
      // version suffix is what makes those corrections visible at all.
      //
      // The hazard is that the suffix is trivial to write by hand, and it was
      // written by hand in three files before this. Three copies of a value
      // whose whole job is to change together is three chances to bump two.
      // So the shell carries the bare file name, the build stamps it, and
      // this is what stops a hand-written one creeping back onto the page the
      // product serves most.
      final shell = File('web/index.html').readAsStringSync();
      final social = RegExp(r'/social/[A-Za-z0-9._-]+\.png(\?[^"\s]*)?')
          .allMatches(shell)
          .map((m) => m.group(0)!)
          .toList();

      expect(social, isNotEmpty,
          reason: 'the shell stopped naming a social card at all');
      for (final url in social) {
        expect(url.contains('?'), isFalse,
            reason: '\n[SOCIAL VERSION] web/index.html writes a version into '
                '"$url" by hand. The authority is _socialAssetVersion in '
                'tool/web/generate_route_metadata.dart, which stamps this file '
                'and every route variant at build time. A version here is a '
                'second authority for the same value.');
      }

      final generator =
          File('tool/web/generate_route_metadata.dart').readAsStringSync();
      expect(generator, contains('_socialAssetVersion'));
      // And it must actually be applied to the root, not only to variants.
      // Stamping only the variants would leave the most-served document in
      // the product pointing at an unversioned image.
      expect(generator, contains('_stampSocialAssets(canonical)'));
    });

    test('the scope list stays honest', () {
      // A surface silently dropped from the list would silently drop the rule.
      expect(_generalSurfaces.length, greaterThanOrEqualTo(15));
      expect(_generalSurfaces, contains('pubspec.yaml'),
          reason: 'pubspec carries source-level product identity metadata');
      expect(_generalSurfaces,
          contains('lib/features/auth/presentation/register_screen.dart'));
      expect(_generalSurfaces, contains('web/index.html'),
          reason: 'the web shell carries the general metadata every public '
              'route inherits');
      expect(_generalSurfaces, contains('web/manifest.json'),
          reason: 'the PWA install description is a general surface');
      expect(_generalSurfaces, contains('lib/screens/white_paper_screen.dart'),
          reason: 'a publication hero states Aura general identity');
      expect(_generalSurfaces, contains('lib/screens/investors_hub_screen.dart'),
          reason: 'the investors architecture block states Aura general '
              'identity to the audience most likely to repeat it');
    });

    test('the route generator declares no general default of its own', () {
      // `tool/web/generate_route_metadata.dart` is deliberately NOT scanned as
      // a general surface: it legitimately carries institution-SPECIFIC route
      // copy for '/institutions'. What it must never carry is a *general*
      // fallback, because a second default is a second authority — and that is
      // precisely how 'Aura Platform — institution operating infrastructure'
      // stayed on every route's social card after the 2026-08-15 pass.
      // The shell (`web/index.html`) owns the general defaults; the generator
      // inherits by omitting the key.
      final gen = File('tool/web/generate_route_metadata.dart');
      expect(gen.existsSync(), isTrue);
      final src = gen.readAsStringSync();

      expect(
        RegExp(r'imageAlt\s*\?\?').hasMatch(src),
        isFalse,
        reason: 'The generator reintroduced a hardcoded general imageAlt '
            'default. Route alt text must inherit from web/index.html; make '
            'imageAlt nullable and omit the substitution key instead.',
      );
      expect(
        src.contains("if (r.imageAlt != null) 'og:image:alt'"),
        isTrue,
        reason: 'The inherit-when-null substitution was removed; general alt '
            'text would stop inheriting from the shell.',
      );
    });

    test('deck source cannot reseed the superseded identity', () {
      // `docs/business_deck/` is deck SOURCE, not an identity source, and it
      // carried the institution-first Aura identity for three weeks after the
      // canon was corrected. It is not phrase-scanned, because its supersession
      // notice must quote the retired wording to retire it. What is enforced is
      // that the notice is there and still points at the canon.
      const deckSources = <String>[
        'docs/business_deck/README.md',
        'docs/business_deck/source/aura_platform_business_deck_master.md',
      ];
      for (final path in deckSources) {
        final file = File(path);
        expect(file.existsSync(), isTrue, reason: 'missing deck source: \$path');
        final text = file.readAsStringSync();
        expect(
          text.contains('IDENTITY IS NOT AUTHORED HERE'),
          isTrue,
          reason: '\$path lost its identity-supersession notice. Deck source '
              'must never read as positioning authority: Identity is authored '
              'only in representation/inventory/PRODUCT_IDENTITY_CANON.md.',
        );
        expect(
          text.contains('PRODUCT_IDENTITY_CANON.md'),
          isTrue,
          reason: '\$path no longer names the canon it defers to.',
        );
      }
    });

    test('institution-owned surfaces are deliberately out of scope', () {
      // Proves the gate is scoped rather than global: this file legitimately
      // contains institution framing and must never be flagged.
      const institutionOwned =
          'lib/features/institutions/posts/institution_post_composer_screen.dart';
      expect(File(institutionOwned).existsSync(), isTrue);
      expect(_generalSurfaces, isNot(contains(institutionOwned)));
    });
  });
}
