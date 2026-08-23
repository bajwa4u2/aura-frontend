import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// A UNIT THAT IS SHOWN MUST SAY WHAT IT IS FOR.
///
/// Founder validation (2026-08-23): a Unit description saved successfully and
/// never appeared in Institution Profile. It was not a failed write and not a
/// missing projection — the backend carried it the whole way. Profile had
/// grown its OWN unit row instead of consuming an existing one, and that
/// private copy rendered the description in micro text, muted, clipped to a
/// single line. To the author that is indistinguishable from "it did not
/// save".
///
/// The defect class is therefore NOT "one wrong font size". It is: a unit
/// renderer can be added anywhere, and a renderer that omits the unit's
/// purpose looks perfectly healthy in review. Five surfaces render a unit
/// today; this fails if any of them stops carrying the description, or if a
/// sixth appears without it.
///
/// This is a source gate rather than a widget test on purpose — it binds the
/// whole consumer set, including consumers that do not exist yet, which is the
/// part a per-widget test cannot reach.
void main() {
  /// Rendering a unit's NAME — the marker of "this surface presents a unit".
  final rendersUnitName = RegExp(
    r"""\bunit\.name\b|\b(?:unit|u)\['name'\]""",
  );

  /// Rendering a unit's DESCRIPTION.
  final rendersUnitDescription = RegExp(
    r"""\bunit\.description\b|\b(?:unit|u|e)\['description'\]""",
  );

  /// NOT PRESENTATION. These carry a unit's name through parsing or routing
  /// and display nothing, so requiring a description of them would be
  /// meaningless. Kept explicit and short so the exemption cannot quietly
  /// widen.
  const notRenderers = <String>{
    // Parses the API payload into the model. It must map description, which
    // the model's own contract covers — but it renders nothing.
    'lib/features/public/data/public_institutions_repository.dart',
    // Route definitions and redirects.
    'lib/router.dart',
  };

  test('every surface that renders a unit renders its purpose', () {
    final silent = <String>[];
    final renderers = <String>[];

    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final rel = entity.path.replaceAll(r'\', '/');
      if (notRenderers.any(rel.endsWith)) continue;

      final source = entity.readAsStringSync();
      if (!rendersUnitName.hasMatch(source)) continue;

      renderers.add(rel);
      if (!rendersUnitDescription.hasMatch(source)) silent.add(rel);
    }

    // The gate is worthless if the discovery pattern silently matches nothing.
    expect(
      renderers,
      isNotEmpty,
      reason: 'No unit renderer was found at all — the detection pattern has '
          'drifted and this gate is no longer guarding anything.',
    );

    expect(
      silent,
      isEmpty,
      reason:
          'These present a Unit without its description. A saved description '
          'that never reaches a consumer is indistinguishable from a failed '
          'save, which is exactly the defect this gate exists for. Render the '
          'unit description, or — if the surface genuinely presents no unit — '
          'record why in notRenderers:\n  ${silent.join('\n  ')}',
    );
  });

  test('the non-renderer exemption stays small and real', () {
    for (final path in notRenderers) {
      expect(File(path).existsSync(), isTrue, reason: '$path no longer exists');
    }
    expect(notRenderers.length, lessThanOrEqualTo(3));
  });
}
