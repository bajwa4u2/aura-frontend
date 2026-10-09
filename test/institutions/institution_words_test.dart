import 'dart:io';

import 'package:aura/features/institutions/institution_words.dart';
import 'package:flutter_test/flutter_test.dart';

/// PLAIN WORDS (phase 2, 2026-10-09): the workspace showed the server's codes
/// to people. Every code now has words, and an unknown one never shows as
/// itself.
void main() {
  test('codes become words', () {
    expect(institutionRoleWord('ADMIN'), 'admin');
    expect(institutionCapabilityWords('HOST_MEETINGS'), 'host meetings');
    expect(institutionCapabilityWords('OFFICIAL_REPRESENTATION'), 'speak officially for the institution');
    expect(spaceVisibilityWords('INVITE_ONLY'), 'Invite only');
    expect(domainStatusWords('CHALLENGE_ISSUED'), 'Waiting for the record');
    expect(domainTrustWords('ADMIN_CONFIRMED'), 'Confirmed by Aura');
    expect(institutionStandingWords('authorizedSpeaker'), 'You may speak for this institution.');
    expect(institutionStandingWords('AUTHORIZED_SPEAKER'), 'You may speak for this institution.');
    expect(announcementKindWords('POLICY_UPDATE'), 'Policy update');
    expect(unitAddressFromName("St. Mary's North Branch"), 'st-marys-north-branch');
  });

  test('an unknown code never reaches the screen as itself', () {
    for (final word in [
      institutionCapabilityWords('SOMETHING_NEW'),
      domainStatusWords('SOMETHING_NEW'),
      spaceVisibilityWords('SOMETHING_NEW'),
    ]) {
      expect(word.contains('_'), isFalse, reason: word);
      expect(word, isNot('SOMETHING_NEW'));
    }
  });

  test('the screens no longer print codes, slugs or raw times', () {
    final activity = File('lib/features/institutions/activity/institution_activity_screen.dart').readAsStringSync();
    expect(activity.contains('return e.kind;'), isFalse);
    expect(RegExp(r'Text\(\s*event\.kind').hasMatch(activity), isFalse);
    expect(activity.contains("case 'INSTITUTION_APPROVED':"), isTrue);

    final domains = File('lib/features/institutions/domain/institution_domains_screen.dart').readAsStringSync();
    for (final raw in ["'Slug: \$slug'", "'Trust: \$trustLevel'", "'Verified: \$verifiedAt'", "status.replaceAll('_', ' ')", "'DNS challenge'"]) {
      expect(domains.contains(raw), isFalse, reason: raw);
    }

    final units = File('lib/features/institutions/units/institution_units_screen.dart').readAsStringSync();
    expect(units.contains("'Slug *'"), isFalse);
    expect(units.contains("'Enter a slug.'"), isFalse);
  });
}
