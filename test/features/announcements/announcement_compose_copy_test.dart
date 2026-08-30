import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// NOTHING INTERNAL ON A COMPOSE SURFACE.
///
/// The announcement editor was showing a person composing a public notice: a
/// section heading printed twice ("Distribution / Distribution"), and two lines
/// of what read as debug output — `LinkedIn: <name>` and
/// `TikTok: -000Dmtv3qyF_cHtMRR_jpGQv1lk-Q-gMYXt`, the second being a raw
/// platform open-id.
///
/// An opaque identifier tells a person nothing and looks like a leak. These
/// assertions live at the source, because the way this comes back is somebody
/// re-adding a "helpful" debug line while chasing a connection bug.
void main() {
  final editor = File(
    'lib/features/announcements/presentation/announcement_editor_screen.dart',
  ).readAsStringSync();
  final distribution = File(
    'lib/features/announcements/presentation/announcement_distribution.dart',
  ).readAsStringSync();

  /// Source with comments stripped — the prose above and the comments at each
  /// changed site name the very strings being asserted absent.
  String code(String source) => source
      .split('\n')
      .map((line) {
        final i = line.indexOf('//');
        return i < 0 ? line : line.substring(0, i);
      })
      .join('\n');

  group('the distribution section says its name once', () {
    test('the widget renders no heading of its own', () {
      // The editor owns the section title, in the same style as every other
      // section on the surface.
      expect(code(distribution), isNot(contains("'Distribution'")));
    });

    test('the editor still titles the section', () {
      expect(code(editor), contains("Text('Distribution'"));
    });
  });

  group('no raw identifiers reach the screen', () {
    test('the editor prints no LinkedIn: or TikTok: debug lines', () {
      final source = code(editor);
      expect(source, isNot(contains(r"'LinkedIn: $")));
      expect(source, isNot(contains(r"'TikTok: $")));
    });

    test('account labels never fall back to a platform id', () {
      final source = code(editor);
      // These are opaque tokens, not names. Falling back to them is what put
      // an open-id on screen.
      expect(source, isNot(contains("data['platformUserId']")));
      expect(source, isNot(contains("data['linkedinMemberId']")));
    });

    test('the account name is shown as the toggle subtitle instead', () {
      expect(code(distribution), contains('linkedinAccountName'));
      expect(code(distribution), contains('tiktokAccountName'));
      // And degrades to plain truth when there is no name to show.
      expect(code(distribution), contains("'Connected'"));
    });
  });
}
