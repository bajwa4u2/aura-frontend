import 'dart:convert';
import 'dart:typed_data';

import 'package:aura/core/institutions/institution_access_provider.dart';
import 'package:aura/core/net/dio_provider.dart';
import 'package:aura/features/identity/data/identity_verification_repository.dart';
import 'package:aura/features/institutions/verification/data/institution_verification_repository.dart';
import 'package:aura/features/institutions/verification/presentation/institution_verification_screen.dart';
import 'package:aura/features/institutions/verification/presentation/speaking_authority_notice.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// ONE EVIDENCE FLOW, NOT TWO JOURNEYS (founder, 2026-09-19).
///
/// The model keeps two determinations — the institution exists, and this
/// person may speak for it — and the backend still records both. What the
/// PERSON walks through is one: confirm the role Aura already holds, say what
/// the document is, send it. The institution's own upload appears only where
/// a reviewer has actually asked for it, and once the claim is sent the form
/// is replaced by where it stands.
void main() {
  Map<String, dynamic> standing({
    String authorityState = 'NOT_STARTED',
    String existenceState = 'NOT_STARTED',
    bool existenceAcceptsEvidence = true,
    String? existenceInfoRequested,
    String? authorityInfoRequested,
    String? category = 'CORPORATE_BUSINESS',
    Map<String, dynamic>? roleOnRecord = const {
      'role': 'OWNER',
      'title': 'Founder and managing member',
    },
    int evidenceCount = 0,
    String? evidenceKind,
    String? claimedRole,
  }) =>
      {
        'institutionId': 'inst_1',
        'category': category,
        'requiresManualReview': false,
        'institution': {'categoryRecorded': category != null},
        'existence': {
          'state': existenceState,
          'available': const ['SUBMITTED'],
          'infoRequested': existenceInfoRequested,
          'acceptsEvidence': existenceAcceptsEvidence,
          'accepted': const ['A company registry number'],
          'requirementNotEnumerated': false,
        },
        'authority': {
          'state': authorityState,
          'available': const ['SUBMITTED'],
          'infoRequested': authorityInfoRequested,
          'acceptsEvidence': authorityState != 'CONFIRMED',
          'evidenceKind': evidenceKind,
          'menu': const [
            'INSTITUTIONAL_RECORD_NAMING_PERSON',
            'APPOINTMENT_LETTER',
            'REGISTRY_OFFICER_LISTING',
          ],
          'evidenceCount': evidenceCount,
          'claimedRole': claimedRole,
          'roleOnRecord': roleOnRecord,
        },
        'actorAssurance': {
          'meetsActionRequirement': true,
          'requiredTier': 'BASE',
          'identity': {
            'verified': true,
            'expiresAt': '2029-09-19T00:00:00.000Z',
          },
        },
        'migration': null,
      };

  Widget host(Widget child, List<Override> overrides, {Key? key}) =>
      ProviderScope(
        key: key,
        overrides: overrides,
        child: MaterialApp(home: Material(child: child)),
      );

  Future<void> pumpScreen(WidgetTester tester, Map<String, dynamic> json) async {
    // The whole page is one scroll view, so a tall surface keeps every
    // affordance hit-testable without scrolling mid-assertion.
    tester.view.physicalSize = const Size(1200, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(host(
      const InstitutionVerificationScreen(institutionId: 'inst_1'),
      [
        institutionVerificationStandingProvider('inst_1').overrideWith(
          (ref) async => InstitutionVerificationStanding.fromJson(json),
        ),
      ],
      // A fresh tree per pump: a reused State would carry the previous
      // standing's local choices into the next case.
      key: UniqueKey(),
    ));
    await tester.pumpAndSettle();
  }

  Future<void> tapText(WidgetTester tester, String label) async {
    final finder = find.text(label);
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  group('the verified owner sees ONE evidence flow', () {
    testWidgets('the role on record is proposed, not asked for again',
        (tester) async {
      await pumpScreen(tester, standing());

      expect(find.text('Verify your authority for this institution'),
          findsOneWidget);
      expect(find.textContaining('Aura has you here as Founder and managing member'),
          findsOneWidget);
      // The empty box under a line that already states the answer is gone.
      expect(find.text('Your role at this institution'), findsNothing);
      expect(find.text('Use a different role'), findsOneWidget);
    });

    testWidgets('and a different role can still be claimed', (tester) async {
      await pumpScreen(tester, standing());
      await tapText(tester, 'Use a different role');

      expect(find.text('Your role at this institution'), findsOneWidget);
      // The way back to the recorded role is offered, not lost.
      expect(find.textContaining('Use my role on record'), findsOneWidget);
    });

    testWidgets('THE SEPARATE "does this institution exist?" STEP IS GONE',
        (tester) async {
      await pumpScreen(tester, standing());

      // Not a second journey, and not a gate in front of the first one.
      expect(find.text('Does this institution exist?'), findsNothing);
      expect(find.text('May you speak for it?'), findsNothing);
      expect(find.text('Start here'), findsNothing);
      expect(find.text('Start verification'), findsNothing);
      // It remains visible as context: it is still a separate determination.
      expect(find.textContaining('Institution record:'), findsOneWidget);
    });

    testWidgets('one document is the default, with an opt-out', (tester) async {
      await pumpScreen(tester, standing());

      expect(
        find.textContaining('answers both questions and you will not need another one'),
        findsOneWidget,
      );
      await tapText(tester, 'My document does not show the institution');
      expect(find.textContaining('This will be used for your authority only'),
          findsOneWidget);
    });

    testWidgets('the primary evidence path leads; the rest stay one tap away',
        (tester) async {
      await pumpScreen(tester, standing());

      expect(
        find.text(
            'A registration, formation or governing document that names you in your role'),
        findsOneWidget,
      );
      // Five legal pathways are not put in front of an ordinary founder…
      expect(find.text('An appointment or authorisation letter'), findsNothing);
      await tapText(tester, 'My evidence is something else');
      // …and none of them is removed.
      expect(find.text('An appointment or authorisation letter'), findsOneWidget);
      expect(find.text('A register listing you as an officer'), findsOneWidget);
    });

    testWidgets('the organisation kind is asked INSIDE the form, only when unknown',
        (tester) async {
      await pumpScreen(tester, standing(category: null));
      expect(find.text('What kind of organisation is this?'), findsOneWidget);
      // Still one flow: the evidence is asked for on the same screen.
      expect(find.text('Add a document (PDF or image)'), findsWidgets);
      expect(find.text('Start verification'), findsNothing);

      await pumpScreen(tester, standing());
      expect(find.text('What kind of organisation is this?'), findsNothing);
    });
  });

  group('after submission the form is replaced by where it stands', () {
    testWidgets('a claim with a reviewer says so, with what was sent',
        (tester) async {
      await pumpScreen(
        tester,
        standing(
          authorityState: 'SUBMITTED',
          evidenceCount: 1,
          evidenceKind: 'INSTITUTIONAL_RECORD_NAMING_PERSON',
          claimedRole: 'Founder and managing member',
        ),
      );

      expect(find.text('With a reviewer'), findsOneWidget);
      expect(find.textContaining('There is nothing for you to do'), findsOneWidget);
      expect(find.text('Role claimed'), findsOneWidget);
      expect(find.text('Evidence received'), findsOneWidget);
      expect(find.textContaining('1 item'), findsOneWidget);
      // THE DEFECT THIS CLOSES: an upload form shown after the document was
      // sent reads as nothing having happened, and gets sent twice.
      expect(find.text('Submit for review'), findsNothing);
      expect(find.text('Add a document (PDF or image)'), findsNothing);
      // Who decides it is said, so nobody is left wondering.
      expect(find.textContaining('Another authorised reviewer'), findsWidgets);
    });

    testWidgets('being read by a person is a different sentence', (tester) async {
      await pumpScreen(tester, standing(authorityState: 'UNDER_REVIEW'));
      expect(find.text('Being reviewed by a person'), findsOneWidget);
      expect(find.textContaining('A reviewer is looking at this now'), findsOneWidget);
    });

    testWidgets('NEEDS_INFO shows exactly what was asked, and reopens the form',
        (tester) async {
      await pumpScreen(
        tester,
        standing(
          authorityState: 'NEEDS_INFO',
          authorityInfoRequested: 'A page of the operating agreement naming you.',
        ),
      );

      expect(find.text('A page of the operating agreement naming you.'),
          findsOneWidget);
      expect(find.text('Send this back for review'), findsOneWidget);
    });

    testWidgets('confirmed says the person may speak, and asks for nothing',
        (tester) async {
      await pumpScreen(tester, standing(authorityState: 'CONFIRMED'));

      expect(find.text('Confirmed'), findsOneWidget);
      expect(find.textContaining('You can speak for this institution'),
          findsOneWidget);
      expect(find.text('Submit for review'), findsNothing);
    });
  });

  group('the institution is asked about only when a reviewer asks', () {
    testWidgets('its own upload appears on NEEDS_INFO, with the ask verbatim',
        (tester) async {
      await pumpScreen(
        tester,
        standing(
          existenceState: 'NEEDS_INFO',
          existenceInfoRequested: 'A certificate of formation showing the address.',
        ),
      );

      expect(find.text('About the institution itself'), findsOneWidget);
      expect(find.text('A certificate of formation showing the address.'),
          findsOneWidget);
      expect(find.text('Send this back for review'), findsOneWidget);
    });

    testWidgets('a confirmed institution is context, never a step',
        (tester) async {
      await pumpScreen(
        tester,
        standing(existenceState: 'CONFIRMED', existenceAcceptsEvidence: false),
      );

      expect(find.text('About the institution itself'), findsNothing);
      expect(find.textContaining('Institution record:'), findsOneWidget);
      // Nothing offers a second document for a question already answered.
      expect(find.textContaining('answers both questions'), findsNothing);
    });
  });

  group('the submission is ONE request', () {
    test('it carries the recorded role and the kind, and never calls start', () async {
      final adapter = _CaptureAdapter();
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test/v1'))
        ..httpClientAdapter = adapter;
      final container = ProviderContainer(
        overrides: [dioProvider.overrideWithValue(dio)],
      );
      addTearDown(container.dispose);

      await container.read(institutionVerificationRepositoryProvider).submitAuthority(
            'inst_1',
            evidenceKind: AuthorityEvidenceKind.institutionalRecordNamingPerson,
            claimedRole: 'Founder and managing member',
            category: 'CORPORATE_BUSINESS',
            alsoEstablishesInstitution: true,
            evidence: const [SuppliedEvidence(mediaId: 'media_1')],
          );

      expect(adapter.paths, ['/institutions/inst_1/verification/authority']);
      expect(adapter.lastBody['claimedRole'], 'Founder and managing member');
      expect(adapter.lastBody['category'], 'CORPORATE_BUSINESS');
      expect(adapter.lastBody['alsoEstablishesInstitution'], isTrue);
      expect(adapter.lastBody['evidenceKind'], 'INSTITUTIONAL_RECORD_NAMING_PERSON');
    });

    test('the category is omitted once the institution has one', () async {
      final adapter = _CaptureAdapter();
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test/v1'))
        ..httpClientAdapter = adapter;
      final container = ProviderContainer(
        overrides: [dioProvider.overrideWithValue(dio)],
      );
      addTearDown(container.dispose);

      await container.read(institutionVerificationRepositoryProvider).submitAuthority(
            'inst_1',
            evidenceKind: AuthorityEvidenceKind.institutionalRecordNamingPerson,
            evidence: const [SuppliedEvidence(mediaId: 'media_1')],
          );

      expect(adapter.lastBody.containsKey('category'), isFalse);
    });
  });

  group('being held back by authority is not a refusal', () {
    test('an owner with every voice capability withheld is offered the step', () {
      // The server withholds PUBLISH_OFFICIAL and OFFICIAL_REPRESENTATION
      // until authority is confirmed, so this person holds NO capability at
      // all — the case that used to reach a generic "Not allowed" (founder
      // item 13). Governance standing is what answers it.
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
      expect(owner.canCreatePosts, isFalse);
    });

    test('a non-governing member whose ROLE carries the voice is offered it too', () {
      // An editor or representative is recognised by the server's own
      // statement about their role — this client does not re-derive the
      // role-capability table (C1), so `canSpeakOfficiallyByRole` is the
      // only honest source for a role below admin.
      const editor = InstitutionIdentity(
        id: 'inst_1',
        name: 'Aura Platform LLC',
        slug: 'aura-platform-llc',
        isAuthorizedSpeaker: false,
        capabilities: {},
        role: 'EDITOR',
        canSpeakByRole: true,
        speakingAuthorityConfirmed: false,
        speakingAuthorityState: 'NOT_STARTED',
      );
      expect(editor.awaitsSpeakingAuthority, isTrue);
      expect(editor.canCreatePosts, isFalse);
    });

    test('a plain member keeps the true refusal', () {
      const member = InstitutionIdentity(
        id: 'inst_1',
        name: 'Aura Platform LLC',
        slug: 'aura-platform-llc',
        isAuthorizedSpeaker: false,
        capabilities: {},
        role: 'MEMBER',
        speakingAuthorityConfirmed: false,
        speakingAuthorityState: 'NOT_STARTED',
      );
      expect(member.awaitsSpeakingAuthority, isFalse);
    });
  });

  group('a claim already sent is not told to send it again', () {
    IdentityVerificationStatus verifiedStatus() =>
        IdentityVerificationStatus.fromJson(const {
          'canSubmit': false,
          'verified': {
            'status': 'VERIFIED',
            'verifiedAt': '2026-09-19T03:52:00.000Z',
            'expiresAt': '2029-09-19T00:00:00.000Z',
          },
        });

    testWidgets('the notice says it is with a reviewer', (tester) async {
      await tester.pumpWidget(host(
        const Scaffold(
          body: SpeakingAuthorityNotice(
            institutionAddress: 'aura-platform-llc',
            authorityState: 'SUBMITTED',
          ),
        ),
        [
          identityVerificationStatusProvider
              .overrideWith((ref) async => verifiedStatus()),
        ],
      ));
      await tester.pumpAndSettle();

      expect(find.text(SpeakingAuthorityNotice.pendingSentence), findsOneWidget);
      expect(find.text('See where it stands'), findsOneWidget);
      expect(find.text('Provide evidence'), findsNothing);
    });

    testWidgets('and names what was asked for when more is needed',
        (tester) async {
      await tester.pumpWidget(host(
        const Scaffold(
          body: SpeakingAuthorityNotice(
            institutionAddress: 'aura-platform-llc',
            authorityState: 'NEEDS_INFO',
          ),
        ),
        [
          identityVerificationStatusProvider
              .overrideWith((ref) async => verifiedStatus()),
        ],
      ));
      await tester.pumpAndSettle();

      expect(find.text(SpeakingAuthorityNotice.needsInfoSentence), findsOneWidget);
      expect(find.text('Add what was asked for'), findsOneWidget);
    });
  });
}

class _CaptureAdapter implements HttpClientAdapter {
  final List<String> paths = [];
  Map<String, dynamic> lastBody = const {};

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    paths.add(options.path);
    lastBody = Map<String, dynamic>.from(options.data as Map);
    return ResponseBody.fromString(
      jsonEncode({
        'ok': true,
        'data': {
          'institutionId': 'inst_1',
          'authority': {'state': 'SUBMITTED', 'available': [], 'menu': []},
          'existence': {'state': 'SUBMITTED', 'available': []},
        },
      }),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
