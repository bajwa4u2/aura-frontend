import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// ONE MISSION SENTENCE — hard build failure.
///
/// ── WHAT WENT WRONG ─────────────────────────────────────────────────────────
///
/// Aura had two mission sentences in production at once, and the `/mission`
/// route served BOTH: one in its metadata and a different one in its social
/// card picture. A third lived in the page hero, and the committed card had
/// been rendered from that one, so the page and its own preview agreed with
/// each other while both disagreed with the metadata beside them.
///
/// Nothing caught it because a mission sentence is prose. It lives in a Dart
/// string, a PowerShell string, an image, and a governance document — four
/// files no single check ever read together.
///
/// ── THE DECISION ────────────────────────────────────────────────────────────
///
/// Founder ruling, 2026-09-05: both circulating wordings rejected. The
/// generic-technology one ("durable systems for communication, coordination,
/// and execution") expressed no product identity at all. The institution-first
/// one ("the durable substrate institutions run on") contradicted the
/// public-first causal doctrine. One sentence was frozen in its place:
///
///   representation/inventory/PRODUCT_IDENTITY_CANON.md → Company Mission
///
/// ── WHAT THIS GUARDS ────────────────────────────────────────────────────────
///
/// That every surface stating a mission states THAT sentence, verbatim. Not
/// paraphrased, not shortened for a card, not expanded for a meta description.
/// A paraphrase is how a second wording begins, and this file exists because
/// two of them shipped.
void main() {
  /// The frozen sentence. Kept here as the assertion's subject; the canon is
  /// the authority, and the last test checks this against it when the canon is
  /// reachable.
  const sentence =
      'Build durable public communication where people participate '
      'purposefully and institutions remain accountable.';

  /// Every in-repository surface that states a mission.
  ///
  /// The card PNG is absent on purpose: no test can read a sentence out of an
  /// image. What is guarded instead is the generator that draws it, and the
  /// generated file is kept honest by the rule that all four cards are
  /// rendered from that one script — verified by regenerating and comparing.
  const surfaces = <String, String>{
    'lib/screens/mission_screen.dart': 'the mission page hero',
    'tool/web/generate_route_metadata.dart': 'the /mission route metadata',
    'tool/web/generate_og_images.ps1': 'the mission social card generator',
  };

  /// Source wraps a long string across lines. Compare on words, not layout.
  String flat(String s) => s
      .replaceAll(RegExp(r"'\s*\n\s*'"), '')
      .replaceAll(RegExp(r'\s+'), ' ');

  group('mission sentence', () {
    for (final entry in surfaces.entries) {
      test('${entry.value} states it verbatim', () {
        final file = File(entry.key);
        expect(file.existsSync(), isTrue,
            reason: '${entry.key} is missing. If it moved, update this gate '
                'rather than deleting the rule.');
        expect(
          flat(file.readAsStringSync()),
          contains(sentence),
          reason: '\n[MISSION] ${entry.value} (${entry.key}) does not state '
              'the frozen mission sentence.\n\n  $sentence\n\n'
              'Authority: representation/inventory/PRODUCT_IDENTITY_CANON.md, '
              'Company Mission, frozen by founder decision 2026-09-05. Do not '
              'paraphrase it to fit — that is how the two rejected wordings '
              'came to exist.',
        );
      });
    }

    test('neither rejected wording survives anywhere', () {
      // Both were real, shipped, and each looked reasonable on its own page.
      // Named here so a copy-paste from an old draft, a screenshot, or a
      // git history read cannot quietly restore one.
      const rejected = <String, String>{
        'durable systems for communication':
            'generic technology framing; expresses no product identity',
        'the durable substrate institutions run on':
            'institution-first; contradicts the public-first causal doctrine',
      };

      final violations = <String>[];
      for (final dir in const ['lib', 'tool', 'web', 'test']) {
        final root = Directory(dir);
        if (!root.existsSync()) continue;
        for (final f in root.listSync(recursive: true).whereType<File>()) {
          if (f.path.endsWith('mission_sentence_gate_test.dart')) continue;
          if (!const ['.dart', '.ps1', '.html', '.json', '.md']
              .any(f.path.endsWith)) {
            continue;
          }
          final lower = flat(f.readAsStringSync()).toLowerCase();
          for (final bad in rejected.entries) {
            if (lower.contains(bad.key)) {
              violations.add('  ${f.path}\n      "${bad.key}" — ${bad.value}');
            }
          }
        }
      }

      expect(violations..sort(), isEmpty,
          reason: '\n[MISSION] A superseded mission wording is back:\n'
              '${violations.join('\n')}\n\nThere is one mission sentence:\n'
              '  $sentence\n');
    });

    test('the canon says the same thing, where the canon can be read', () {
      // The authority is a governance document in a SEPARATE repository, which
      // is present when this runs beside its siblings and absent inside the
      // web image's build context. So it is checked when reachable and
      // reported plainly when not, rather than being asserted conditionally in
      // silence or breaking a build that legitimately cannot see it.
      final canon = File(
        '../../representation/inventory/PRODUCT_IDENTITY_CANON.md',
      );
      if (!canon.existsSync()) {
        printOnFailure('canon not reachable from this checkout');
        return;
      }
      expect(
        flat(canon.readAsStringSync()),
        contains(sentence),
        reason: 'The canon no longer carries the sentence this gate enforces. '
            'The canon wins: change the sentence here to match it, and every '
            'surface with it.',
      );
    });
  });
}
