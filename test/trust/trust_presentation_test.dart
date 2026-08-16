import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aura/core/trust/trust_marks.dart';
import 'package:aura/core/trust/verification.dart';
import 'package:aura/features/profile/domain/profile.dart';

/// C2 — semantic trust presentation, not just widget rendering.
///
/// Pins the frozen presentation doctrine:
///  - layered classes never collapse into "Verified person";
///  - absence renders nothing (absence is not suspicion);
///  - every visible mark is subject-explicit — no bare generic "Verified"
///    person claim survives;
///  - unknown/malformed wire data yields the empty set, never an invented
///    meaning;
///  - ROLE_OR_CREDENTIAL is presented as an Aura record, not a portable
///    credential.
void main() {
  group('PersonVerification (domain authority)', () {
    test('parses the canonical wire shape', () {
      final v = PersonVerification.fromJson({
        'classes': ['IDENTITY', 'ROLE_OR_CREDENTIAL'],
      });
      expect(v.classes, [
        PersonVerificationClass.identity,
        PersonVerificationClass.roleOrCredential,
      ]);
      expect(v.hasAny, isTrue);
    });

    test('unknown classes are dropped, never guessed at', () {
      final v = PersonVerification.fromJson({
        'classes': ['IDENTITY', 'SOME_FUTURE_CLASS'],
      });
      expect(v.classes, [PersonVerificationClass.identity]);
    });

    test('malformed payloads are absence, not error', () {
      expect(PersonVerification.fromJson(null).hasAny, isFalse);
      expect(PersonVerification.fromJson('verified').hasAny, isFalse);
      expect(PersonVerification.fromJson({'classes': 'yes'}).hasAny, isFalse);
      expect(PersonVerification.fromJson(true).hasAny, isFalse);
    });

    test('duplicate wire entries do not duplicate marks', () {
      final v = PersonVerification.fromJson({
        'classes': ['IDENTITY', 'IDENTITY'],
      });
      expect(v.classes.length, 1);
    });
  });

  group('Profile (release-client wire adoption)', () {
    test('consumes verification.classes from the profile wire', () {
      final p = Profile.fromJson({
        'id': 'u1',
        'handle': 'amina',
        'displayName': 'Amina',
        'bio': null,
        'avatarUrl': null,
        'followersCount': 0,
        'followingCount': 0,
        'verification': {
          'classes': ['INSTITUTION_AFFILIATION'],
        },
      });
      expect(
        p.verification.has(PersonVerificationClass.institutionAffiliation),
        isTrue,
      );
      expect(p.verification.has(PersonVerificationClass.identity), isFalse);
    });

    test('legacy flattened keys no longer manufacture a trust claim', () {
      // The old model parsed isVerified/verified/verificationStatus — fields
      // no profile endpoint ever sent. They must be dead.
      final p = Profile.fromJson({
        'id': 'u1',
        'handle': 'amina',
        'displayName': 'Amina',
        'bio': null,
        'avatarUrl': null,
        'followersCount': 0,
        'followingCount': 0,
        'isVerified': true,
        'verified': true,
        'verificationStatus': 'VERIFIED',
      });
      expect(p.verification.hasAny, isFalse);
    });
  });

  group('TrustFact (canonical wording)', () {
    test('every fact label is subject-explicit — never bare "Verified"', () {
      for (final fact in TrustFact.values) {
        expect(fact.label.trim(), isNot('Verified'));
        expect(fact.label.trim().toLowerCase(), isNot('verified'));
      }
    });

    test('ROLE_OR_CREDENTIAL presents as governed attestation, not credential', () {
      // Founder ruling: 'Role attested' — an Aura-governed record, with the
      // portability boundary stated in the meaning itself.
      expect(TrustFact.roleAttested.label, 'Role attested');
      expect(
        TrustFact.roleAttested.meaning,
        contains('not a portable credential'),
      );
      expect(TrustFact.roleAttested.label.toLowerCase(),
          isNot(contains('credential')));
    });

    test('institution verification is not endorsement', () {
      expect(
        TrustFact.institutionVerified.meaning,
        contains('not an endorsement'),
      );
    });

    test('each person class maps to its own distinct fact', () {
      final facts = PersonVerificationClass.values
          .map(TrustFact.ofPersonClass)
          .toSet();
      expect(facts.length, PersonVerificationClass.values.length);
    });
  });

  group('PersonVerificationMarks (layered presentation)', () {
    Future<void> pump(WidgetTester tester, PersonVerification v) {
      return tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PersonVerificationMarks(verification: v),
          ),
        ),
      );
    }

    testWidgets('no verification renders nothing at all', (tester) async {
      await pump(tester, const PersonVerification.none());
      expect(find.byType(TrustMark), findsNothing);
      expect(find.textContaining('Verified'), findsNothing);
      expect(find.textContaining('verified'), findsNothing);
    });

    testWidgets('one mark per class, each with its own meaning', (tester) async {
      await pump(
        tester,
        const PersonVerification([
          PersonVerificationClass.identity,
          PersonVerificationClass.institutionAffiliation,
          PersonVerificationClass.roleOrCredential,
        ]),
      );
      expect(find.byType(TrustMark), findsNWidgets(3));
      expect(find.text('Identity verified'), findsOneWidget);
      expect(find.text('Affiliation verified'), findsOneWidget);
      expect(find.text('Role attested'), findsOneWidget);
      // Never a collapsed generic person claim.
      expect(find.text('Verified'), findsNothing);
    });

    testWidgets('identity alone claims identity alone', (tester) async {
      await pump(
        tester,
        const PersonVerification([PersonVerificationClass.identity]),
      );
      expect(find.text('Identity verified'), findsOneWidget);
      expect(find.text('Affiliation verified'), findsNothing);
      expect(find.text('Role attested'), findsNothing);
    });
  });

  group('InstitutionVerifiedMark', () {
    testWidgets(
        'compact label is permitted only with full semantics behind it',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: InstitutionVerifiedMark()),
        ),
      );
      // Visible compact label (adjacent-to-name layouts)…
      expect(find.text('Verified'), findsOneWidget);
      // …but assistive technology always receives the subject + meaning.
      expect(
        find.bySemanticsLabel(RegExp('Verified institution')),
        findsOneWidget,
      );
      final tooltip = tester.widget<Tooltip>(find.byType(Tooltip));
      expect(tooltip.message, contains('not an endorsement'));
    });

    testWidgets('icon-only mark still carries the full meaning',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: InstitutionVerifiedIcon()),
        ),
      );
      expect(
        find.bySemanticsLabel(RegExp('Verified institution')),
        findsOneWidget,
      );
    });
  });
}
