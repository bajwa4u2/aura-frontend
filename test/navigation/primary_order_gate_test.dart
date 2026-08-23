import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:aura/core/navigation/navigation_authority.dart';

// PRIMARY NAVIGATION ORDER IS ONE ANSWER, NOT ONE PER SHELL.
//
// Founder ruling 2026-08-22: Home · Create · Messages · Discover. Create is a
// primary product action, not a trailing destination parked after the browsing
// surfaces.
//
// The order previously lived in a private static list inside MemberShell. It
// happened to feed that shell's rail, bottom bar and drawer, so those three
// agreed by construction — but nothing enforced that a second shell or a
// platform-specific presentation would agree, and no test would have noticed,
// because each list would be internally consistent on its own. That is exactly
// how ten notification resolvers came to disagree.
void main() {
  test('the canonical order is Home, Create, Messages, Discover', () {
    expect(
      PrimaryDestination.values.map((d) => d.label).toList(),
      ['Home', 'Create', 'Messages', 'Discover'],
    );
  });

  test('Create is immediately after Home', () {
    final order = PrimaryDestination.values;
    expect(order.indexOf(PrimaryDestination.create),
        order.indexOf(PrimaryDestination.home) + 1,
        reason: 'the ruling is about standing, not about being present');
  });

  test('no shell declares its own ordered list of the four primaries', () {
    // Structural: a shell may decide how a destination LOOKS on its form
    // factor. It may not decide what the destinations are or what order they
    // come in.
    final offenders = <String>[];

    for (final entity in Directory('lib/app').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final path = entity.path.replaceAll(String.fromCharCode(92), '/');
      final code = entity
          .readAsLinesSync()
          .where((l) => !l.trimLeft().startsWith('//'))
          .join('\n');

      // A shell that names three or more primaries as literal labels is
      // re-declaring the set rather than consuming it.
      final named = ['Home', 'Create', 'Messages', 'Discover']
          .where((label) => code.contains("label: '$label'"))
          .length;
      if (named >= 3) offenders.add('$path (names $named primaries literally)');
    }

    expect(offenders, isEmpty,
        reason: 'primary destinations and their order come from '
            'PrimaryDestination.values');
  });

  test('every primary address is one the Navigation Authority owns', () {
    for (final d in PrimaryDestination.values) {
      expect(d.route.startsWith('/'), isTrue);
      expect(d.route.trim(), isNotEmpty);
    }
    expect(PrimaryDestination.create.route, NavigationAuthority.createRoute);
    expect(PrimaryDestination.messages.route, NavigationAuthority.messagesRoute);
  });
}
