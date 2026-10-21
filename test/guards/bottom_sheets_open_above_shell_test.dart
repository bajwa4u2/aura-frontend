import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Every bottom sheet opens on the ROOT navigator.
///
/// The member, institution, operator and public shells draw their bottom
/// navigation around the routed page. A sheet opened on the nearest (shell)
/// navigator is laid out inside that page, so on a phone the navigation bar
/// covers its lowest actions — found 21 Oct 2026 on the Invite to Aura sheet,
/// and true of all 42 sheets, including Report and Block. One rule for all of
/// them, checked here, rather than a fix per sheet.
void main() {
  test('every showModalBottomSheet call passes useRootNavigator: true', () {
    final offenders = <String>[];
    final call = RegExp(r'showModalBottomSheet(<[^>]*>)?\(');
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final source = entity.readAsStringSync();
      for (final match in call.allMatches(source)) {
        // Read the call's own arguments, up to its closing parenthesis.
        var depth = 1;
        var i = match.end;
        while (i < source.length && depth > 0) {
          final c = source[i];
          if (c == '(') depth++;
          if (c == ')') depth--;
          i++;
        }
        final args = source.substring(match.end, i);
        if (!args.contains('useRootNavigator: true')) {
          final line = '\n'.allMatches(source.substring(0, match.start)).length + 1;
          offenders.add('${entity.path}:$line');
        }
      }
    }
    expect(offenders, isEmpty,
        reason: 'These sheets would open under the shell navigation bar');
  });
}
