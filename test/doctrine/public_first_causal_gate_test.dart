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

    test('the scope list stays honest', () {
      // A surface silently dropped from the list would silently drop the rule.
      expect(_generalSurfaces.length, greaterThanOrEqualTo(6));
      expect(_generalSurfaces, contains('pubspec.yaml'),
          reason: 'pubspec carries source-level product identity metadata');
      expect(_generalSurfaces,
          contains('lib/features/auth/presentation/register_screen.dart'));
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
