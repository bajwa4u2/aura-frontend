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
    // Collect the card titles. The widget was renamed `_CreateActionData` ->
    // `_CreateCard` in the 2026-08-25 reconstruction; the frozen VOCABULARY
    // this gate exists for did not change, so the gate follows the rename
    // rather than the vocabulary bending to the gate.
    final titles = RegExp(r"_CreateCard\(\s*title:\s*'([^']+)'")
        .allMatches(src)
        .map((m) => m.group(1)!)
        .toList()
      ..sort();
    return titles.join('·');
  }

  test('visible Create cards are exactly Share · Message · Post · Announcement',
      () {
    // SHARE ADDED 2026-08-29 BY FOUNDER RULING, not by drift.
    //
    // The frozen vocabulary was Message · Post · Article-when-real ·
    // contextual Announcement, and this gate exists so a card cannot appear
    // because some feature wanted a doorway. Share is a new CREATION
    // INTENTION rather than a new tenant: "I have something I want to share"
    // sits beside "I want to say something", and the ruling that added it
    // also fixed its placement (first) and its name (Share, not "Photo or
    // video" -- photo and video are today's acquisition capabilities, not the
    // product boundary).
    //
    // The bans below are unchanged and still hold: Invitation, Institution,
    // Conversation and Write remain out.
    expect(cardTitles(), 'Announcement·Article·Message·Post·Share');
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
