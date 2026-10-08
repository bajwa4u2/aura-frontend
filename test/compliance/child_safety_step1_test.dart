import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:aura/core/compliance/report_repository.dart';

/// Child safety, step 1 (founder decision 2026-10-08).
void main() {
  test('a reply is reported as the Post it is — the server never knew REPLY', () {
    expect(ReportTargetType.reply.wire, 'POST');
  });

  test('institution posts and announcements can be reported', () {
    expect(ReportTargetType.institutionPost.wire, 'INSTITUTION_POST');
    expect(ReportTargetType.announcement.wire, 'ANNOUNCEMENT');
  });

  test('child safety is a reason, and the first one offered', () {
    expect(ReportReason.values.first, ReportReason.childSafety);
    expect(ReportReason.childSafety.wire, 'CHILD_SAFETY');
    expect(ReportReason.childSafety.label, 'Child safety or exploitation');
  });

  test('the main feed card and the top of a discussion offer Report and Block', () {
    final card = File('lib/features/feed/presentation/unified_feed_card.dart')
        .readAsStringSync();
    final thread = File('lib/features/public/presentation/thread_screen.dart')
        .readAsStringSync();
    expect(card, contains('showReportBlockMenu('));
    expect(thread, contains('showReportBlockMenu('));
  });

  test('the Child Safety page no longer claims what does not exist', () {
    final page =
        File('lib/screens/child_safety_screen.dart').readAsStringSync();
    expect(page, isNot(contains('built for accountable adult communication')));
    expect(page, isNot(contains('combines automated detection signals')));
    expect(page, isNot(contains('Anonymous reports are accepted')));
    expect(page, isNot(contains('profile, institution, or space')));
    expect(page, contains('Child safety or exploitation'));
  });
}
