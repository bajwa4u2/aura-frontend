import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// CREATE — frozen intent vocabulary pin (founder §5 resolution,
/// 2026-08-16): the visible Create domains are MESSAGE · POST · contextual
/// ANNOUNCEMENT (ARTICLE joins when real). "Message" is the human
/// intention; "Conversation" is the object underneath. No Invitation, no
/// Institution onboarding, no Article until real, no generic "Write".
void main() {
  final src = File(
    'lib/features/create/presentation/create_hub_screen.dart',
  ).readAsStringSync();

  String? cardTitles() {
    // Collect _CreateActionData title values.
    final titles = RegExp(r"_CreateActionData\(\s*title:\s*'([^']+)'")
        .allMatches(src)
        .map((m) => m.group(1)!)
        .toList()
      ..sort();
    return titles.join('·');
  }

  test('visible Create cards are exactly Message · Post · Announcement', () {
    expect(cardTitles(), 'Announcement·Article·Message·Post');
  });

  test('banned Create tenants stay out', () {
    for (final banned in [
      "title: 'Invitation'",
      "title: 'Institution'",
      "title: 'Conversation'",
      "title: 'Write'",
    ]) {
      expect(src.contains(banned), isFalse,
          reason: '$banned may not appear as a Create card — frozen intent '
              'vocabulary is Message · Post · Article-when-real · '
              'contextual Announcement.');
    }
    expect(src.contains('institutionOnboardingRoute'), isFalse,
        reason: 'Institution onboarding is an acquisition action, never a '
            'Create domain.');
    expect(src.contains('inviteHubRoute'), isFalse,
        reason: 'Invitation is a participation action, never a Create '
            'domain.');
  });

  test('Message routes into the canonical conversation flow', () {
    expect(src.contains('NavigationAuthority.newConversationRoute'), isTrue);
  });
}
