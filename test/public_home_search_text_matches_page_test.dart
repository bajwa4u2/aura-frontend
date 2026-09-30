import 'dart:io';

import 'package:flutter_test/flutter_test.dart';


/// What search engines and link previews read must be what visitors see
/// (founder approval F3, 2026-09-29: Google was reading a different headline
/// and links to a business case the landing page never showed).
void main() {
  final generator = File('tool/web/generate_route_metadata.dart').readAsStringSync();
  final page = File('lib/features/home/presentation/public_home_screen.dart').readAsStringSync();

  test('the crawler block is built from the page constants', () {
    final root = generator.substring(generator.indexOf('String _buildRootCrawlerVisibleBlock()'));
    final block = root.substring(0, root.indexOf('\n}\n') + 2);
    for (final name in [
      'publicHomeHeadline',
      'publicHomeLede',
      'publicHomeJoinLabel',
      'publicHomeExploreLabel',
      'publicHomeInstitutionsLabel',
    ]) {
      expect(block, contains(name));
    }
    expect(block, isNot(contains('Business case')));
    expect(block, isNot(contains('accountable answers')));
  });

  test('the page renders the same constants, not its own copies', () {
    expect(page, contains('publicHomeHeadline'));
    expect(page, contains('publicHomeLede'));
    expect(page, isNot(contains("'Explore discussions'")));
  });

  // The <meta> description is not tested here: its wording is held by the
  // canon (test/doctrine/public_first_causal_gate_test.dart).
}
