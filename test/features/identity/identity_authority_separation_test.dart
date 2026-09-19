import 'dart:io';

import 'package:aura/core/institutions/institution_access_provider.dart';
import 'package:aura/features/identity/data/identity_verification_repository.dart';
import 'package:aura/features/identity/presentation/identity_verification_screen.dart';
import 'package:aura/features/institutions/verification/data/institution_verification_repository.dart';
import 'package:aura/features/institutions/verification/presentation/institution_verification_screen.dart';
import 'package:aura/features/institutions/verification/presentation/speaking_authority_notice.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// WHO THE PERSON IS, AND WHETHER THEY MAY SPEAK FOR AN INSTITUTION, ARE TWO
/// DIFFERENT QUESTIONS (founder, 2026-09-19).
///
/// A verified owner opened their institution's Verification page and was told
/// "Verifying your own identity comes first", with a button that led to the
/// empty first-time identity form. These hold the corrected model at the
/// client: a verified person is RECOGNISED, is never asked for identity again,
/// and is asked only for institutional evidence; the document chosen decides
/// which sides of it are asked for.
void main() {
  IdentityVerificationStatus status({
    Map<String, dynamic>? verified,
    bool canSubmit = true,
  }) =>
      IdentityVerificationStatus.fromJson({
        'current': null,
        'history': const [],
        'canSubmit': canSubmit,
        'verified': verified,
        'documentSides': {
          'PASSPORT': {'required': ['PHOTO_PAGE'], 'optional': []},
          'DRIVING_LICENCE': {'required': ['FRONT', 'BACK'], 'optional': []},
          'IDENTITY_CARD': {'required': ['FRONT', 'BACK'], 'optional': []},
          'RESIDENCE_PERMIT': {'required': ['FRONT'], 'optional': ['BACK']},
        },
      });

  const verifiedJson = {
    'status': 'VERIFIED',
    'verifiedAt': '2026-09-19T03:52:00.000Z',
    'expiresAt': '2029-09-19T00:00:00.000Z',
    'documentKind': null,
    'documentType': 'Passport',
    'verifiedLegalName': null,
  };

  Widget host(Widget child, List<Override> overrides) => ProviderScope(
        overrides: overrides,
        // The app shell provides the Material ancestor in production.
        child: MaterialApp(home: Material(child: child)),
      );

  group('the identity status is read as the server states it', () {
    test('a verification in force is recognised, with its dates', () {
      final s = status(verified: verifiedJson, canSubmit: false);
      expect(s.isVerified, isTrue);
      expect(s.verified!.expiresAt, DateTime.parse('2029-09-19T00:00:00.000Z'));
      // Never filled in from anything else when the reviewer recorded none.
      expect(s.verified!.verifiedLegalName, isNull);
      expect(s.verified!.documentLabel, 'Passport');
    });

    test('the sides follow the document, from the server rule', () {
      final s = status();
      expect(s.sidesFor(IdentityDocumentKind.passport).required,
          [IdentityEvidenceSide.photoPage]);
      expect(s.sidesFor(IdentityDocumentKind.drivingLicence).required,
          [IdentityEvidenceSide.front, IdentityEvidenceSide.back]);
      expect(s.sidesFor(IdentityDocumentKind.identityCard).required,
          [IdentityEvidenceSide.front, IdentityEvidenceSide.back]);
      expect(s.sidesFor(IdentityDocumentKind.residencePermit).optional,
          [IdentityEvidenceSide.back]);
    });

    test('an older server with no rule still gets a complete form', () {
      final s = IdentityVerificationStatus.fromJson(const {'canSubmit': true});
      expect(s.sidesFor(IdentityDocumentKind.drivingLicence).required,
          contains(IdentityEvidenceSide.back));
    });

    test('evidence carries its side, and a submission its document', () {
      final sub = IdentityVerificationSubmission.fromJson(const {
        'id': 's1',
        'state': 'PENDING_REVIEW',
        'documentKind': 'DRIVING_LICENCE',
        'evidence': [
          {'id': 'e1', 'kind': 'GOVERNMENT_ID', 'side': 'BACK', 'discarded': false},
        ],
      });
      expect(sub.documentKind, IdentityDocumentKind.drivingLicence);
      expect(sub.evidence.single.side, IdentityEvidenceSide.back);
    });
  });

  group('the identity screen', () {
    testWidgets('RECOGNISES a verified person and offers no form', (tester) async {
      await tester.pumpWidget(host(const IdentityVerificationScreen(), [
        identityVerificationStatusProvider.overrideWith(
          (ref) async => status(verified: verifiedJson, canSubmit: false),
        ),
        personVerificationClassesProvider.overrideWith((ref) async => const []),
      ]));
      await tester.pumpAndSettle();

      expect(find.text('Your identity is verified'), findsOneWidget);
      expect(find.text('Send for review'), findsNothing);
      expect(find.text('Which document are you using?'), findsNothing);
      expect(find.text('Verify your identity'), findsNothing);
    });

    testWidgets('a licence asks for its FRONT and its BACK', (tester) async {
      await tester.pumpWidget(host(const IdentityVerificationScreen(), [
        identityVerificationStatusProvider.overrideWith((ref) async => status()),
        personVerificationClassesProvider.overrideWith((ref) async => const []),
      ]));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Driving licence'));
      await tester.pumpAndSettle();
      expect(find.text('Driving licence — Front'), findsOneWidget);
      expect(find.text('Driving licence — Back'), findsOneWidget);
      expect(find.text('Photo of you'), findsOneWidget);
    });

    testWidgets('an identity card asks for both sides too', (tester) async {
      await tester.pumpWidget(host(const IdentityVerificationScreen(), [
        identityVerificationStatusProvider.overrideWith((ref) async => status()),
        personVerificationClassesProvider.overrideWith((ref) async => const []),
      ]));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Identity card'));
      await tester.pumpAndSettle();
      expect(find.text('Identity card — Front'), findsOneWidget);
      expect(find.text('Identity card — Back'), findsOneWidget);
    });

    testWidgets('a passport asks for its photo page only', (tester) async {
      await tester.pumpWidget(host(const IdentityVerificationScreen(), [
        identityVerificationStatusProvider.overrideWith((ref) async => status()),
        personVerificationClassesProvider.overrideWith((ref) async => const []),
      ]));
      await tester.pumpAndSettle();

      // Nothing about the document is offered before it is named.
      expect(find.textContaining('— Front'), findsNothing);

      await tester.tap(find.text('Passport'));
      await tester.pumpAndSettle();
      expect(find.text('Passport — Photo page'), findsOneWidget);
      expect(find.textContaining('— Back'), findsNothing);
      expect(find.textContaining('— Front'), findsNothing);
    });
  });

  group('the institution Verification page', () {
    Map<String, dynamic> standing({required bool verified}) => {
          'institutionId': 'inst_1',
          'category': 'CORPORATE_BUSINESS',
          'requiresManualReview': false,
          'existence': {
            'state': 'NOT_STARTED',
            'available': ['SUBMITTED'],
            'acceptsEvidence': true,
            'accepted': const [],
            'requirementNotEnumerated': false,
          },
          'authority': {
            'state': 'NOT_STARTED',
            'available': ['SUBMITTED'],
            'acceptsEvidence': true,
            'menu': ['INSTITUTIONAL_RECORD_NAMING_PERSON', 'APPOINTMENT_LETTER'],
            'evidenceCount': 0,
          },
          'actorAssurance': {
            'meetsActionRequirement': verified,
            'requiredTier': 'BASE',
            'identity': {
              'verified': verified,
              'expiresAt': verified ? '2029-09-19T00:00:00.000Z' : null,
            },
          },
          'migration': null,
        };

    testWidgets('A VERIFIED OWNER IS ASKED FOR AUTHORITY, never for identity',
        (tester) async {
      await tester.pumpWidget(host(
        const InstitutionVerificationScreen(institutionId: 'inst_1'),
        [
          institutionVerificationStandingProvider('inst_1').overrideWith(
            (ref) async =>
                InstitutionVerificationStanding.fromJson(standing(verified: true)),
          ),
        ],
      ));
      await tester.pumpAndSettle();

      expect(find.textContaining('Your identity is verified.'), findsOneWidget);
      expect(find.text('Verify my identity'), findsNothing);
      expect(find.textContaining('comes first'), findsNothing);
      expect(
        find.textContaining('provide evidence of your relationship or authority'),
        findsWidgets,
      );
      // One document may be enough: the option is offered. (The page is a
      // single scroll view, so everything on it is built without scrolling.)
      expect(find.text('This document also shows the institution is registered'),
          findsOneWidget);
      expect(find.text('Your role at this institution'), findsOneWidget);
    });

    testWidgets('only an UNVERIFIED person is sent to verify identity first',
        (tester) async {
      await tester.pumpWidget(host(
        const InstitutionVerificationScreen(institutionId: 'inst_1'),
        [
          institutionVerificationStandingProvider('inst_1').overrideWith(
            (ref) async =>
                InstitutionVerificationStanding.fromJson(standing(verified: false)),
          ),
        ],
      ));
      await tester.pumpAndSettle();

      expect(find.text('Verify my identity'), findsWidgets);
      expect(find.textContaining('Your identity is verified.'), findsNothing);
      // Worded as identity first, never as a "higher level".
      expect(find.textContaining('higher level'), findsNothing);
    });
  });

  group('speaking surfaces name the missing step', () {
    test('a role held back by authority is recognised as exactly that', () {
      const owner = InstitutionIdentity(
        id: 'inst_1',
        name: 'Aura Platform LLC',
        slug: 'aura-platform-llc',
        isAuthorizedSpeaker: false,
        capabilities: {},
        role: 'OWNER',
        speakingAuthorityConfirmed: false,
        speakingAuthorityState: 'NOT_STARTED',
      );
      expect(owner.awaitsSpeakingAuthority, isTrue);
      // Role alone does not authorise speech.
      expect(owner.canCreatePosts, isFalse);

      const confirmed = InstitutionIdentity(
        id: 'inst_1',
        name: 'Aura Platform LLC',
        slug: 'aura-platform-llc',
        isAuthorizedSpeaker: true,
        capabilities: {'PUBLISH_OFFICIAL', 'OFFICIAL_REPRESENTATION'},
        role: 'OWNER',
        speakingAuthorityConfirmed: true,
      );
      expect(confirmed.awaitsSpeakingAuthority, isFalse);
      expect(confirmed.canCreatePosts, isTrue);

      // An older server says nothing, and nothing is claimed either way.
      const legacy = InstitutionIdentity(
        id: 'inst_1',
        name: 'X',
        slug: 'x',
        isAuthorizedSpeaker: false,
        capabilities: {},
        role: 'OWNER',
      );
      expect(legacy.awaitsSpeakingAuthority, isFalse);
    });

    testWidgets('a verified person is told their identity is verified',
        (tester) async {
      await tester.pumpWidget(host(
        const Scaffold(
          body: SpeakingAuthorityNotice(institutionAddress: 'aura-platform-llc'),
        ),
        [
          identityVerificationStatusProvider.overrideWith(
            (ref) async => status(verified: verifiedJson, canSubmit: false),
          ),
        ],
      ));
      await tester.pumpAndSettle();
      expect(find.text(SpeakingAuthorityNotice.authoritySentence), findsOneWidget);
      expect(find.text('Provide evidence'), findsOneWidget);
      expect(find.text('Verify my identity'), findsNothing);
    });

    testWidgets('an unverified person is told to verify identity first',
        (tester) async {
      await tester.pumpWidget(host(
        const Scaffold(
          body: SpeakingAuthorityNotice(institutionAddress: 'aura-platform-llc'),
        ),
        [identityVerificationStatusProvider.overrideWith((ref) async => status())],
      ));
      await tester.pumpAndSettle();
      expect(find.text(SpeakingAuthorityNotice.identityFirstSentence), findsOneWidget);
      expect(find.text('Verify my identity'), findsOneWidget);
    });

    test('the composer names the authority step BEFORE "Not allowed"', () {
      // The composer is too wired to pump in isolation, so its branch order is
      // held at source: an owner awaiting authority must reach the authority
      // notice, never the role refusal meant for people with no role at all.
      final src = File(
        'lib/features/institutions/posts/institution_post_composer_screen.dart',
      ).readAsStringSync();
      final authority = src.indexOf('identity?.awaitsSpeakingAuthority');
      final notAllowed = src.indexOf("title: 'Not allowed'");
      expect(authority, greaterThan(0));
      expect(notAllowed, greaterThan(authority));
      expect(src.contains('SpeakingAuthorityNotice('), isTrue);
      expect(src.contains('kInstitutionAuthorityRequired'), isTrue);
    });
  });
}
