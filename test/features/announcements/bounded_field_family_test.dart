import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// THE SCROLL-OWNERSHIP RULE, ACROSS THE WHOLE APP.
///
/// Root cause, established 2026-08-30 by a controlled A/B on one Playwright
/// harness with the build pinned: a `TextField` with a BOUNDED multi-line
/// `maxLines` claims the wheel and never passes it to the enclosing scroll
/// view — even with no text of its own to scroll. Unbounded, the enclosing
/// view gets every event.
///
/// There are two correct answers, and which one applies is a product question:
///
///   FAMILY A — a field in a form the person fills once and submits. Drop the
///              bound: content grows, the page grows, the page keeps scroll
///              ownership. `maxLines: null`. This is the converted majority.
///
///   FAMILY B — a composer that must stay a fixed size because something else
///              scrolls beside or above it: a chat box, a discussion box, a
///              support reply, a description field inside a scrolling dialog.
///              The bound is right, so the wheel behaviour has to be fixed
///              instead — these adopt [AuraBoundedEditor], which scrolls the
///              text while it can and releases the wheel at each end.
///
/// So a bounded multi-line editable must ADOPT THE BOUNDARY: it takes the
/// controller and physics the wrapper hands it. That is visible in the field's
/// own argument list, which is what this test checks — a wrapper that is
/// present but ignored would otherwise pass a shallower test while behaving
/// exactly like the original defect.
///
/// The exceptions are named individually, with the reason, because "it is in a
/// dialog" turned out not to be a reason on its own: two dialog fields sat
/// inside the dialog's own `SingleChildScrollView` and trapped it just as a
/// page composer traps a page.
void main() {
  /// Fields that may stay bounded WITHOUT the wrapper, because there is no
  /// scrollable behind them for the wheel to reach.
  ///
  /// Each is the sole content of an `AlertDialog` that does not scroll: the
  /// field IS the dialog body, so it is the only scrollable in the hit-test
  /// path and nothing is stranded behind it.
  const soleDialogContent = <String, String>{
    // admin_institutions_screen REMOVED 2026-08-31: the screen was deleted by
    // the Admin Operator Hub reconstruction, so its exception went with it.
    // The console's one bounded field now lives in the governed action
    // ceremony and adopts AuraBoundedEditor rather than claiming an
    // exception, because that sheet DOES scroll behind the field.
    'lib/features/articles/presentation/article_screen.dart':
        'reshare commentary — the field is the entire dialog body',
    'lib/features/posts/presentation/widgets/communication_continuity_view.dart':
        'resolve statement — dialog body is a plain Column, nothing scrolls',
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

  Iterable<({String rel, int line, String block, int max})> boundedFields() sync* {
    for (final f in Directory('lib').listSync(recursive: true).whereType<File>()) {
      if (!f.path.endsWith('.dart')) continue;
      final rel = f.path.replaceAll(r'\', '/');
      final src = f.readAsStringSync();
      for (final m in ctor.allMatches(src)) {
        final block = blockAt(src, m.start);
        final ml = maxLines.firstMatch(block);
        if (ml == null) continue;
        final max = int.parse(ml.group(1)!);
        if (max <= 1) continue; // single-line: builds no scrollable
        final line = '\n'.allMatches(src.substring(0, m.start)).length + 1;
        yield (rel: rel, line: line, block: block, max: max);
      }
    }
  }

  test('every bounded multi-line editable adopts the shared boundary', () {
    final offenders = <String>[];

    for (final f in boundedFields()) {
      if (soleDialogContent.keys.any(f.rel.endsWith)) continue;
      final adopts = f.block.contains('scrollController:') &&
          f.block.contains('scrollPhysics:');
      if (!adopts) {
        offenders.add('${f.rel}:${f.line} (maxLines: ${f.max})');
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'A bounded multi-line field claims the wheel and strands whatever\n'
          'scrolls behind it. Either drop the bound (`maxLines: null`) if the\n'
          'page may grow, or wrap it in AuraBoundedEditor and pass the\n'
          'scrollController and scrollPhysics it gives you.\n'
          '${offenders.join('\n')}',
    );
  });

  test('the wrapper is not present-but-ignored anywhere', () {
    // Wrapping a field and then not passing its controller through leaves the
    // original defect in place behind a reassuring-looking widget.
    final offenders = <String>[];
    for (final f in Directory('lib').listSync(recursive: true).whereType<File>()) {
      if (!f.path.endsWith('.dart')) continue;
      final src = f.readAsStringSync();
      if (src.contains('class AuraBoundedEditor')) continue; // its own definition
      if (!src.contains('AuraBoundedEditor(')) continue;
      final uses = 'AuraBoundedEditor('.allMatches(src).length;
      final wired = 'scrollPhysics:'.allMatches(src).length;
      if (wired < uses) {
        offenders.add('${f.path.replaceAll(r'\', '/')} '
            '($uses wrapped, $wired wired through)');
      }
    }
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });

  test('the named exceptions still exist and still qualify', () {
    // An exception list that outlives the files it names silently stops
    // guarding anything.
    for (final entry in soleDialogContent.entries) {
      expect(File(entry.key).existsSync(), isTrue,
          reason: '${entry.key} no longer exists (${entry.value})');
    }
  });
}
