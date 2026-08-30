import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// MODAL AND FLOW EXITS — founder ruling §6 and §7.
///
/// The audit counted 86 navigable surfaces with no registered route: 51
/// dialogs, 29 modal sheets (15 of them full-height), 3 `MaterialPageRoute`,
/// 2 `Navigator.push`, 1 `OverlayEntry`. A route-only audit would have claimed
/// coverage it did not have.
///
/// §6 is explicit that a full-height sheet is not a route just because it is
/// tall: promote only where the product semantics genuinely require
/// addressability. All 15 were classified individually and none does — they are
/// "act on the thing I am looking at" interactions (report, review, verify, add
/// people, integrity, participation, members, units, panels). They keep modal
/// semantics.
///
/// What they must have is a reliable way out, which is what these assert.
void main() {
  List<File> dartFiles() => Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList();

  test('no sheet traps the person', () {
    // A bottom sheet is dismissible by drag and by barrier tap UNLESS it opts
    // out. Nothing does, and nothing should without a stated reason.
    final offenders = <String>[];
    for (final f in dartFiles()) {
      final src = f.readAsStringSync();
      if (src.contains('isDismissible: false') ||
          src.contains('enableDrag: false')) {
        offenders.add(f.path);
      }
    }
    expect(offenders, isEmpty,
        reason: 'a sheet opted out of dismissal — state why, or restore it');
  });

  test('the ONE undismissable dialog is a terminal acknowledgement', () {
    // barrierDismissible: false is right exactly once: after the account has
    // already been deleted, where "did you mean to dismiss that" is not a
    // question worth asking. It still has an explicit way out.
    final blocking = <String>[];
    for (final f in dartFiles()) {
      if (f.readAsStringSync().contains('barrierDismissible: false')) {
        blocking.add(f.path.replaceAll(r'\', '/'));
      }
    }
    expect(blocking.length, 1,
        reason: 'a new blocking dialog appeared: $blocking');
    expect(blocking.single, endsWith('account_deletion_screen.dart'));

    final src = File(blocking.single).readAsStringSync();
    expect(src, contains('Navigator.of(ctx).pop()'),
        reason: 'the blocking dialog lost its acknowledgement action');
  });

  test('every surface pushed OUTSIDE go_router can still be left', () {
    // These have no URL, so a web refresh loses them — accepted under §6
    // because none requires addressability. What they may not do is trap.
    const outside = {
      'lib/core/ui/pdf_viewer_screen.dart': 'AppBar(',
      'lib/shared/media/profile_media_editor.dart': 'pop(',
    };
    for (final entry in outside.entries) {
      final src = File(entry.key).readAsStringSync();
      expect(src, contains(entry.value),
          reason: '${entry.key} lost its exit');
    }
  });

  test('full-height sheets stayed sheets', () {
    // The count is frozen so a future promotion to a route is a deliberate,
    // reviewed IA decision rather than a drift nobody noticed.
    var full = 0;
    for (final f in dartFiles()) {
      final src = f.readAsStringSync();
      final lines = src.split('\n');
      for (var i = 0; i < lines.length; i++) {
        if (!lines[i].contains('showModalBottomSheet')) continue;
        final window = lines.sublist(i, (i + 45).clamp(0, lines.length));
        if (window.any((l) => l.contains('isScrollControlled: true'))) full++;
      }
    }
    // 16th member added 2026-08-25 by the A/V chapter:
    // `core/media/call_preflight_sheet.dart`. Reclassified against §6 rather
    // than having the number bumped: it BEHAVES as a sheet — transient,
    // dismissible via "Not now", returns a value to its caller, and traps
    // nothing. It is deliberately not a route, because a permission preflight
    // has no addressable identity: a URL that reopened it would be asking for
    // devices with no call behind the request.
    // 17th member added 2026-08-27 by the Trace chapter:
    // `core/media/trace/aura_trace_surface.dart`. Reclassified against §6
    // rather than having the number bumped: it BEHAVES as a sheet — transient,
    // dismissed by dragging down or tapping the barrier, returns no value, and
    // traps nothing. It is deliberately not a route because Trace has no
    // addressable identity of its own: it is an inspection OF an object the
    // person is already looking at, so a URL that reopened it would be asking
    // for a disclosure with no object behind the request.
    // 18th member RETIRED 2026-08-29, same day it was added, by the Share
    // chapter itself: `features/share/presentation/share_screen.dart`. It was
    // the destination picker (Feed or Conversation), then briefly the topic
    // picker that replaced it. Both are gone because Share stopped asking
    // questions: a share goes to the person's followers, and a post addressed
    // to followers is not a public record, so it needs no classification
    // either. The population falls to 17 — recorded here rather than left to
    // drift, because a census that only ever rises stops being a census.
    // 18th and 19th members added 2026-08-30 by the eligibility chapter:
    // `core/eligibility/jurisdiction_confirm_sheet.dart`, which presents ONE
    // surface through two entry points — `showJurisdictionConfirmSheet`
    // (confirms and writes) and `showJurisdictionPicker` (returns the choice
    // to a caller who will write it as part of a larger submission). The
    // census counts call sites, so one surface is honestly two entries here.
    // Reclassified against §6 rather than having the number bumped: it
    // BEHAVES as a sheet — transient, dismissible by the barrier or a drag,
    // returns a value to its caller, and traps nothing. It is deliberately
    // not a route for the reason it exists at all: it interrupts someone who
    // is holding an unpublished draft, and a route would take them off the
    // surface holding it. A country confirmation also has no addressable
    // identity — a URL that reopened it would be asking a question with no
    // refused act behind it.
    expect(full, 19,
        reason: 'the full-height sheet population changed — reclassify it '
            'against §6 (behaviour, not dimensions) rather than adjusting '
            'this number');
  });
}
