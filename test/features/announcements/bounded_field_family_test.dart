import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// THE SCROLL-OWNERSHIP RULE, ACROSS THE WHOLE APP.
///
/// Root cause, established 2026-08-30 by a controlled A/B on one Playwright
/// harness with the build pinned: a `TextField` with a BOUNDED multi-line
/// `maxLines` claims the wheel and never passes it to the enclosing scroll
/// view — even with no text to scroll. Unbounded, the enclosing view gets
/// every gesture.
///
/// The rule is therefore a COMPOSITION rule, not a pointer handler, and it is
/// not universal — which is the whole reason this test names exceptions
/// instead of banning the pattern outright:
///
///   FAMILY A — a field in a form the person fills once and submits. Content
///              grows, the page grows, the page keeps scroll ownership.
///              `maxLines: null`. This is the converted majority.
///
///   FAMILY B — a PERSISTENT composer that stays on screen while the content
///              it addresses scrolls beside or above it. Unbounded growth
///              would eat the surface, so bounded height is correct and these
///              keep it. They still trap the wheel over themselves; that is a
///              known, recorded limitation needing real nested-scroll
///              fall-through, not a reason to make a chat box grow forever.
///
///   FAMILY C — inside a dialog. Its content area is its own constrained,
///              scrollable region; there is no enclosing page to fall through
///              to, so nothing to fix.
///
/// A new bounded multi-line field that is NOT on this list fails here, which
/// is the point: adding one should require saying which family it is in.
void main() {
  /// Family B — persistent composers. Bounded on purpose.
  const composers = <String>{
    'lib/core/engagement/aura_publication_discussion.dart',
    'lib/features/conversation/presentation/conversation_screen.dart',
    'lib/features/meetings/presentation/widgets/meeting_conversation_panel.dart',
    'lib/features/support/presentation/admin_support_console_screen.dart',
    'lib/features/support/presentation/support_agent_screen.dart',
  };

  /// Family C — dialog-contained.
  const dialogs = <String>{
    'lib/features/admin/presentation/admin_institutions_screen.dart',
    'lib/features/articles/presentation/article_screen.dart',
    'lib/features/meetings/presentation/institution_availability_screen.dart',
    'lib/features/meetings/presentation/meeting_detail_screen.dart',
    'lib/features/posts/presentation/widgets/communication_continuity_view.dart',
  };

  final ctor = RegExp(r'\b(TextField|TextFormField)\s*\(');
  final maxLines = RegExp(r'maxLines:\s*(\d+)');

  /// The constructor's own argument list, by brace depth — a fixed line window
  /// would miss a long declaration and quietly under-report.
  String blockAt(String src, int start) {
    var depth = 0;
    var i = src.indexOf('(', start);
    final open = i;
    while (i < src.length) {
      if (src[i] == '(') depth++;
      if (src[i] == ')') {
        depth--;
        if (depth == 0) break;
      }
      i++;
    }
    return src.substring(open, i + 1);
  }

  test('every bounded multi-line editable field is a named exception', () {
    final offenders = <String>[];
    final dir = Directory('lib');

    for (final f in dir.listSync(recursive: true).whereType<File>()) {
      if (!f.path.endsWith('.dart')) continue;
      final rel = f.path.replaceAll(r'\', '/');
      final src = f.readAsStringSync();

      for (final m in ctor.allMatches(src)) {
        final block = blockAt(src, m.start);
        final ml = maxLines.firstMatch(block);
        if (ml == null) continue;
        if (int.parse(ml.group(1)!) <= 1) continue; // single-line: no scrollable

        final known = composers.any(rel.endsWith) || dialogs.any(rel.endsWith);
        if (!known) {
          final line = '\n'.allMatches(src.substring(0, m.start)).length + 1;
          offenders.add('$rel:$line (maxLines: ${ml.group(1)})');
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'A bounded multi-line field claims the wheel and strands the page.\n'
          'Use `maxLines: null` for a form field (Family A), or add the file to '
          'the composer/dialog exception set above and say why it must stay '
          'bounded.\n${offenders.join('\n')}',
    );
  });

  test('the named exceptions still exist and still qualify', () {
    // An exception list that outlives the files it names silently stops
    // guarding anything.
    for (final rel in {...composers, ...dialogs}) {
      expect(File(rel).existsSync(), isTrue, reason: '$rel no longer exists');
    }
  });
}
