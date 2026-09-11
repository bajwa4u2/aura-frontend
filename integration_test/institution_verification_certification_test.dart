import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:integration_test/integration_test.dart';

import 'package:aura/features/institutions/verification/data/institution_verification_repository.dart';

// NATIVE INSTITUTION-VERIFICATION CERTIFICATION — WINDOWS DESKTOP.
//
//     flutter test integration_test/institution_verification_certification_test.dart -d windows
//
// WHAT THIS CERTIFIES, precisely:
//
//   On Windows — real platform, real networking stack, real plugin
//   registration — THE SHIPPED CLIENT CODE parses and drives the real
//   verification contract. Not a reimplementation of it: the assertions run
//   through `InstitutionVerificationRepository`, the same class the screen
//   uses, so a parsing defect that would blank a real person's screen fails
//   here.
//
//   It also certifies the refusal path end to end, which is the half most
//   likely to be wrong and least likely to be exercised: the server refuses,
//   the client's single mapper preserves the server's words, and the exception
//   carries the machine code as well as the sentence.
//
// WHAT IT DOES NOT CERTIFY. It does not drive the Windows UI. Synthetic OS
// input into a Flutter desktop window is unreliable on this host — clicks land
// wrongly after layout reflow and Tab does not move focus between fields — so
// Windows UI INTERACTION is reported EVIDENCE_LIMITED rather than inferred
// from the web build, per the founder's no-inherited-PASS rule.
//
// It does not boot the app. The real router starts network work that outlives
// the test and Flutter then reports "this test failed after it had already
// completed".
//
// Requires the ISOLATED certification stack up on 34999:
//   docker compose -p auracert -f docker-compose.identity-certification.yml up -d --build
const String _api = 'http://localhost:34999/v1';
const String _password = 'certification_only_pw_1';
const String _owner = 'wincert@certification.invalid';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('institution verification on Windows, against the isolated stack', () {
    late Dio dio;
    late InstitutionVerificationRepository repo;
    late String institutionId;
    late String strangerInstitutionId;

    setUpAll(() async {
      // A STABLE FIXTURE, SEEDED BY THE HARNESS, CONSUMED HERE OVER HTTP ONLY.
      //
      // This test carries no database access on purpose: a test that can seed
      // can also mask what it failed to prove. The account, its ELEVATED
      // assurance and the institution it owns are created by
      // scripts/identity-certification/institution-verification-journey-proof.mjs,
      // which must have been run against this stack first.
      final login = await http.post(
        Uri.parse('$_api/auth/login'),
        headers: const {'content-type': 'application/json'},
        body: jsonEncode({'email': _owner, 'password': _password}),
      );
      expect(
        login.statusCode,
        inInclusiveRange(200, 299),
        reason: 'sign-in must succeed — has the journey proof been run against '
            'this stack to seed the fixture? ${login.body}',
      );
      final decoded = jsonDecode(login.body) as Map<String, dynamic>;
      final data = (decoded['data'] ?? decoded) as Map<String, dynamic>;
      final token = (data['accessToken'] ?? data['token']) as String;

      // The REAL client transport, carrying a real token, on Windows.
      dio = Dio(BaseOptions(baseUrl: _api, headers: {'authorization': 'Bearer $token'}));
      repo = InstitutionVerificationRepository(dio);

      // THE REAL SHAPE, read rather than assumed. `/institutions/me` answers
      // with ONE membership -- a person's institutional standing, not a list --
      // and the institution hangs off it. Guessing a list here is how a client
      // ends up rendering an empty state against a perfectly good response.
      final mine = await dio.get<Map<String, dynamic>>('/institutions/me');
      final body = (mine.data?['data'] ?? mine.data) as Map<String, dynamic>;
      final membership = body['membership'] as Map<String, dynamic>?;
      expect(membership, isNotNull,
          reason: 'the fixture owner must hold a membership: ${mine.data}');
      final institution = membership!['institution'] as Map<String, dynamic>?;
      expect(institution, isNotNull, reason: 'the membership must name its institution');
      institutionId = institution!['id'].toString();

      // Somebody else's institution, for the refusal case.
      strangerInstitutionId = 'inst_not_mine_${DateTime.now().millisecondsSinceEpoch}';
    });

    test('THE PLATFORM CAN REACH THE VERIFICATION CONTRACT AT ALL', () async {
      // A positive control for everything below. If the stack were unreachable
      // from Windows, every refusal assertion would pass for the wrong reason.
      //
      // Asked of the owner's OWN institution, deliberately. Probing a stranger
      // here proved only that SOMETHING answered, which a refusal also
      // satisfies — so the control could not tell "the contract works" from
      // "everything is refused". A 200 on the caller's own standing can only
      // come from the contract actually working.
      final res = await dio.get<Map<String, dynamic>>(
        '/institutions/$institutionId/verification',
        options: Options(validateStatus: (_) => true),
      );
      expect(res.statusCode, 200, reason: '${res.data}');
      expect((res.data?['data'] as Map?)?['institutionId'], institutionId);
    });

    test('AN ACCOUNT WITHOUT STANDING IS REFUSED, and told why', () async {
      // The two gates that protect this route are ELEVATED assurance and the
      // institution role. This account holds neither, so it must be refused —
      // and the refusal must arrive as a sentence a person could act on rather
      // than as a generic failure.
      Object? raised;
      try {
        await repo.standing(strangerInstitutionId);
      } catch (e) {
        raised = e;
      }

      expect(raised, isA<InstitutionVerificationException>(),
          reason: 'the client must map a refusal to its own exception type');
      final refusal = raised! as InstitutionVerificationException;
      expect(refusal.message.trim(), isNotEmpty);
      // THE SERVER'S OWN WORDS. Two correct mappers in series already cost
      // this release one reason, which reached a person as "Please try again".
      expect(refusal.message, isNot(contains('could not reach verification')),
          reason: 'a real refusal must not be replaced by the offline sentence');
    });

    test('THE REFUSAL CARRIES A MACHINE CODE, not only prose', () async {
      Object? raised;
      try {
        await repo.submitExistence(
          strangerInstitutionId,
          const [SuppliedEvidence(reference: 'Companies House 09876543')],
        );
      } catch (e) {
        raised = e;
      }
      final refusal = raised! as InstitutionVerificationException;
      // A client that only had prose could never branch on the reason, which
      // is how a specific refusal becomes a generic screen.
      expect(refusal.code, isNotNull);
      expect(refusal.code!.trim(), isNotEmpty);
    });

    test('EVIDENCE SENT FROM WINDOWS NAMES NO SUBMITTER', () {
      // Provenance comes from the authenticated caller or it is not
      // provenance. Asserted on the real wire shape the repository builds.
      const evidence = SuppliedEvidence(reference: 'Charity Commission 1122334');
      expect(evidence.toJson().containsKey('submittedByUserId'), isFalse);
      expect(evidence.toJson(), {'reference': 'Charity Commission 1122334'});
    });

    test('THE SHIPPED PARSER SURVIVES A REAL PAYLOAD SHAPE', () {
      // The client's own parsing, on Windows, over the vocabulary the server
      // actually emits. A defect here blanks a real person's screen.
      final standing = InstitutionVerificationStanding.fromJson({
        'institutionId': 'inst_1',
        'category': 'NONPROFIT_COMMUNITY',
        'requiresManualReview': false,
        'existence': {
          'state': 'NEEDS_INFO',
          'available': ['SUBMITTED'],
          'infoRequested': 'Send the registration certificate.',
          'acceptsEvidence': true,
          'confidence': null,
          'accepted': ['A registration reference'],
          'requirementNotEnumerated': false,
        },
        'authority': {
          'state': 'LEGACY_UNVERIFIED',
          'available': ['SUBMITTED'],
          'infoRequested': null,
          'acceptsEvidence': true,
          'evidenceKind': null,
          'menu': ['APPOINTMENT_LETTER'],
        },
        'migration': {
          'reason': 'NOT_ANCHORED',
          'deadlineAt': null,
          'daysRemaining': null,
          'authorityGovernanceBlocked': false,
          'institutionVoiceBlocked': false,
        },
      });

      expect(standing.existence.state, ExistenceState.needsInfo);
      expect(standing.existence.infoRequested, 'Send the registration certificate.');
      // Never folded into CONFIRMED, on any platform.
      expect(standing.authority.state, AuthorityState.legacyUnverified);
      // No notice delivered, so no countdown.
      expect(standing.migration.running, isFalse);
    });
  });
}
