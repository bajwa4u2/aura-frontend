import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:integration_test/integration_test.dart';

import 'package:aura/features/institutions/verification/data/institution_verification_repository.dart';
import 'package:aura/features/institutions/verification/presentation/institution_verification_screen.dart';

// NATIVE ANDROID CERTIFICATION — THE 120-DAY LEGACY MIGRATION.
//
//     adb reverse tcp:34999 tcp:34999
//     node scripts/identity-certification/institution-verification-journey-proof.mjs
//     flutter test integration_test/android_institution_migration_certification_test.dart -d <device>
//
// THREE HISTORICAL INSTITUTIONS THAT DIFFER IN EXACTLY ONE THING.
//
// All three are VERIFIED with a verifiedAt 400 days old, all owned by the same
// person, all carrying a governed migration notice. The only difference is
// whether — and when — a channel actually delivered. So any difference this
// lane observes between them has one possible cause, and an assertion here
// cannot pass for an accidental reason.
//
//   cert-legacy-undelivered   attempted, never delivered
//   cert-legacy-delivered     delivered 10 days ago
//   cert-legacy-elapsed       delivered 121 days ago
//
// The founder asked for two things in these words, and they are the first two
// tests below:
//
//     NOTICE_NOT_DELIVERED -> CLOCK_NOT_STARTED
//     FIRST_DELIVERY       -> CLOCK_STARTS
//
// NO MODERN PROOF IS FABRICATED for any of them. Not one evidence row exists,
// and the lane asserts that rather than assuming it: their historical verified
// fact is preserved and is never dressed up as a present-day verification.
//
// THE DEAD END THIS LANE FOUND. The read route used to require the elevated
// identity tier — which this population does not hold, by definition, because
// obtaining it is the thing being asked of them. The notice arrived, the
// person tapped it, and the only screen showing their deadline refused to
// load. They would have been silently expired without ever seeing a date.

// 127.0.0.1, NOT `localhost`. `adb reverse` binds the device's loopback, and
// a literal address needs no resolution; `localhost` goes through Android's
// DNS resolver, which intermittently answers 'No address associated with
// hostname' on a device with no active network. That failure looks exactly
// like the certification stack being down, and it is not.
const String _api = 'http://127.0.0.1:34999/v1';
const String _password = 'certification_only_pw_1';
const String _owner = 'migcert@certification.invalid';

const String _undelivered = 'cert-legacy-undelivered';
const String _delivered = 'cert-legacy-delivered';
const String _elapsed = 'cert-legacy-elapsed';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late InstitutionVerificationRepository repo;
  final idBySlug = <String, String>{};
  final standing = <String, InstitutionVerificationStanding>{};

  setUpAll(() async {
    final login = await http.post(
      Uri.parse('$_api/auth/login'),
      headers: const {'content-type': 'application/json'},
      body: jsonEncode({'email': _owner, 'password': _password}),
    );
    expect(
      login.statusCode,
      inInclusiveRange(200, 299),
      reason: 'the phone must reach the isolated stack through the adb reverse '
          'tunnel, and the migration fixtures must be seeded: ${login.body}',
    );
    final token = jsonDecode(login.body)['accessToken'] as String;

    final dio = Dio(BaseOptions(
      baseUrl: _api,
      headers: {'authorization': 'Bearer $token'},
    ));
    repo = InstitutionVerificationRepository(dio);

    final mine = await dio.get<Map<String, dynamic>>('/institutions/me');
    for (final m in (mine.data?['memberships'] as List? ?? const [])) {
      final inst = (m as Map)['institution'] as Map;
      idBySlug[inst['slug'].toString()] = inst['id'].toString();
    }

    for (final slug in const [_undelivered, _delivered, _elapsed]) {
      expect(
        idBySlug[slug],
        isNotNull,
        reason: 'the migration fixture $slug is missing. Re-seed before '
            'certifying:\n  node scripts/identity-certification/'
            'institution-verification-journey-proof.mjs',
      );
      standing[slug] = await repo.standing(idBySlug[slug]!);
    }
  });

  group('the clock is anchored on delivery and on nothing else', () {
    test('NOTICE_NOT_DELIVERED -> CLOCK_NOT_STARTED', () async {
      final s = standing[_undelivered]!;

      expect(s.migration.reason, 'NOT_ANCHORED');
      expect(s.migration.deadlineAt, isNull);
      expect(s.migration.daysRemaining, isNull);
      expect(s.migration.running, isFalse);

      // AND NOTHING IS TAKEN AWAY. A notice the platform failed to deliver
      // must not cost the person anything: the first they would hear of it is
      // a capability that had quietly stopped working.
      expect(s.migration.authorityGovernanceBlocked, isFalse);
      expect(s.migration.institutionVoiceBlocked, isFalse);
    });

    test('FIRST_DELIVERY -> CLOCK_STARTS', () async {
      final s = standing[_delivered]!;

      expect(s.migration.reason, 'IN_WINDOW');
      expect(s.migration.running, isTrue);
      // §6 — the specific date, always, so the client is given something it can
      // show rather than a number it must phrase.
      expect(s.migration.deadlineAt, isNotNull);
      expect(s.migration.daysRemaining, isNotNull);

      // Delivered 10 days ago against a 120-day window. Floored, so 109 or 110.
      expect(s.migration.daysRemaining, inInclusiveRange(108, 110));
    });

    test('AND DELIVERY IS THE ONLY DIFFERENCE BETWEEN THEM', () async {
      // The two institutions above are identical in every other respect —
      // same owner, same historical verified status, same notice. This is what
      // makes the pair a cause and not a coincidence.
      final a = standing[_undelivered]!;
      final b = standing[_delivered]!;

      expect(a.migration.reason, isNot(b.migration.reason));
      expect(a.existence.state, b.existence.state);
      expect(a.authority.state, b.authority.state);
    });
  });

  group('what the window costs, and when', () {
    test('DURING THE WINDOW, EVERYDAY WORK CARRIES ON', () async {
      final s = standing[_delivered]!;

      // §3.2 — authority governance stops the moment the notice lands.
      expect(s.migration.authorityGovernanceBlocked, isTrue);
      // §3.3 — institution voice does NOT, for the whole window. Deliberately
      // non-punitive: the institution keeps running while its representative
      // sorts out their own verification.
      expect(s.migration.institutionVoiceBlocked, isFalse);
    });

    test('ONLY WHEN IT RUNS OUT DOES THE VOICE STOP', () async {
      final s = standing[_elapsed]!;

      expect(s.migration.reason, 'WINDOW_ELAPSED');
      expect(s.migration.institutionVoiceBlocked, isTrue);
      // Past, so negative. The date is still shown — a deadline that has gone
      // is still the fact the person needs.
      expect(s.migration.deadlineAt, isNotNull);
      expect(s.migration.daysRemaining, lessThanOrEqualTo(0));
    });
  });

  group('the person the migration is about can act on it', () {
    test('THEY CAN READ THEIR OWN STANDING AT ALL', () async {
      // THE DEAD END. This population does not hold the elevated tier —
      // acquiring it is what is being asked of them — and the read route used
      // to require it. Every notice in the family deep-links to the screen
      // that calls this. If this refuses, the notice leads nowhere.
      for (final slug in const [_undelivered, _delivered, _elapsed]) {
        expect(standing[slug], isNotNull);
        expect(standing[slug]!.institutionId, idBySlug[slug]);
      }
    });

    test('AND ARE TOLD THEY MUST VERIFY THEMSELVES FIRST', () async {
      final s = standing[_delivered]!;

      // Half a loop is a deadline with no way forward. The standing says
      // whether the ACTIONS are open and names what they need, so the screen
      // can state the requirement instead of offering a refusing button.
      expect(s.mayAct, isFalse);
      expect(s.actionRequiredTier, 'ELEVATED');
    });
  });

  group('their history is preserved, and no modern proof is invented', () {
    test('NO PROOF WAS FABRICATED FOR A HISTORICAL INSTITUTION', () async {
      for (final slug in const [_undelivered, _delivered, _elapsed]) {
        final s = standing[slug]!;
        // Never CONFIRMED by the migration. An institution handed a confirmed
        // proof it never earned is afterwards indistinguishable from one that
        // did, which is the one thing that can never be undone.
        expect(s.existence.state, isNot(ExistenceState.confirmed));
        expect(s.existenceConfidence, isNull);
      }
    });
  });

  group('and it renders on a real phone', () {
    testWidgets('THE DEADLINE IS A DATE, and the way forward is offered',
        (tester) async {
      final id = idBySlug[_delivered]!;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            institutionVerificationStandingProvider(id)
                .overrideWith((ref) async => standing[_delivered]!),
          ],
          child: MaterialApp(
            // The real tree: MemberShell wraps every routed screen in a
            // Scaffold, and that is what supplies the Material ancestor.
            home: Scaffold(
              body: InstitutionVerificationScreen(institutionId: id),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // §6 — an absolute date, never "in 109 days".
      expect(find.textContaining('109 days'), findsNothing);
      expect(find.textContaining('Please complete this by'), findsOneWidget);

      // And the way out of it, rather than a button that would refuse.
      expect(find.text('Verify my identity'), findsWidgets);

      expect(tester.takeException(), isNull);
    });
  });
}
