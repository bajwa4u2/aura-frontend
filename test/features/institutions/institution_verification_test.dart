import 'dart:typed_data';

import 'package:aura/features/institutions/verification/data/institution_verification_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// WHAT THE CLIENT IS ALLOWED TO SAY ABOUT AN INSTITUTION'S VERIFICATION.
///
/// The governed distinctions are easy to lose on the way to a screen, and two
/// of them would be lost silently:
///
///   Folding LEGACY_UNVERIFIED into "verified" launders a relationship nobody
///   evidenced into one somebody did — the exact thing §5.19 forbids, and it
///   would look like a tidy UI.
///
///   Rendering an unknown state as a decision tells somebody they are verified,
///   or refused, on the strength of a string this build has never seen.
///
/// These pin the parsing and projection layers, where both would happen first.
void main() {
  group('existence state parsing', () {
    test('maps every governed state', () {
      expect(ExistenceState.parse('NOT_STARTED'), ExistenceState.notStarted);
      expect(ExistenceState.parse('SUBMITTED'), ExistenceState.submitted);
      expect(ExistenceState.parse('AUTOMATED_CHECK'), ExistenceState.automatedCheck);
      expect(ExistenceState.parse('MANUAL_REVIEW'), ExistenceState.manualReview);
      expect(ExistenceState.parse('CONFIRMED'), ExistenceState.confirmed);
      expect(ExistenceState.parse('REJECTED'), ExistenceState.rejected);
      expect(ExistenceState.parse('NEEDS_INFO'), ExistenceState.needsInfo);
    });

    test('an unrecognised state is unknown, and never a decision', () {
      for (final raw in ['SOMETHING_NEW', '', null]) {
        final state = ExistenceState.parse(raw);
        expect(state, ExistenceState.unknown);
        expect(state, isNot(ExistenceState.confirmed));
        expect(state, isNot(ExistenceState.rejected));
      }
    });
  });

  group('authority state parsing', () {
    test('maps every governed state', () {
      expect(AuthorityState.parse('NOT_STARTED'), AuthorityState.notStarted);
      expect(AuthorityState.parse('SUBMITTED'), AuthorityState.submitted);
      expect(AuthorityState.parse('UNDER_REVIEW'), AuthorityState.underReview);
      expect(AuthorityState.parse('NEEDS_INFO'), AuthorityState.needsInfo);
      expect(AuthorityState.parse('CONFIRMED'), AuthorityState.confirmed);
      expect(AuthorityState.parse('REJECTED'), AuthorityState.rejected);
      expect(AuthorityState.parse('LEGACY_UNVERIFIED'), AuthorityState.legacyUnverified);
      expect(AuthorityState.parse('SUSPENDED'), AuthorityState.suspended);
      expect(AuthorityState.parse('REVOKED'), AuthorityState.revoked);
    });

    test('LEGACY_UNVERIFIED IS ITS OWN STATE, never confirmed', () {
      // §5.19 -- "a distinct, honestly-labeled state, never folded into any
      // newly-defined evidenced category." Folding it into CONFIRMED would
      // launder a carried-over relationship into an evidenced one, and it
      // would look like a tidier UI while doing it.
      final state = AuthorityState.parse('LEGACY_UNVERIFIED');
      expect(state, AuthorityState.legacyUnverified);
      expect(state, isNot(AuthorityState.confirmed));
      expect(state, isNot(AuthorityState.unknown));
    });

    test('SUSPENDED is not REVOKED', () {
      // A pause and a severance are different things to be told.
      expect(AuthorityState.parse('SUSPENDED'), isNot(AuthorityState.revoked));
    });
  });

  group('confidence is graduated, and DOMAIN_ONLY is an answer', () {
    test('every tier reads as what was checked, not as a shortfall', () {
      expect(ExistenceConfidence.parse('DOMAIN_ONLY').label, 'Confirmed by domain');
      expect(ExistenceConfidence.parse('DOCUMENT_REVIEWED').label, 'Confirmed by document');
      expect(
        ExistenceConfidence.parse('REGISTRY_CONFIRMED').label,
        'Confirmed against a register',
      );
    });

    test('no tier is worded as incomplete', () {
      // §1.4 -- DOMAIN_ONLY is "a legitimate, permanent state", so nothing may
      // suggest the person still owes us something.
      for (final raw in ['DOMAIN_ONLY', 'DOCUMENT_REVIEWED', 'REGISTRY_CONFIRMED']) {
        final label = ExistenceConfidence.parse(raw).label.toLowerCase();
        expect(label, isNot(contains('partial')));
        expect(label, isNot(contains('only ')));
        expect(label, isNot(contains('incomplete')));
        expect(label, startsWith('confirmed'));
      }
    });
  });

  group('the standing is read from the server, not inferred', () {
    Map<String, dynamic> payload({
      String existenceState = 'NEEDS_INFO',
      List<String> existenceAvailable = const ['SUBMITTED'],
      String? infoRequested,
      List<String> menu = const ['APPOINTMENT_LETTER', 'REGISTRY_OFFICER_LISTING'],
    }) =>
        {
          'institutionId': 'inst_1',
          'category': 'CORPORATE_BUSINESS',
          'requiresManualReview': false,
          'existence': {
            'state': existenceState,
            'available': existenceAvailable,
            'infoRequested': infoRequested,
            'acceptsEvidence': true,
            'confidence': null,
            'accepted': ['A company registry number'],
            'requirementNotEnumerated': false,
          },
          'authority': {
            'state': 'LEGACY_UNVERIFIED',
            'available': ['SUBMITTED'],
            'infoRequested': null,
            'acceptsEvidence': true,
            'evidenceKind': null,
            'menu': menu,
          },
        };

    test('AVAILABLE ACTIONS COME FROM THE WIRE', () {
      final s = InstitutionVerificationStanding.fromJson(payload());
      expect(s.existence.canSubmit('SUBMITTED'), isTrue);
      expect(s.existence.canSubmit('CONFIRMED'), isFalse);
    });

    test('AN EMPTY AVAILABLE LIST OFFERS NOTHING', () {
      // "Wait" and "stuck" look the same to a person; the difference is that
      // one of them is correct. A client that inferred a button from the state
      // would offer a step the server refuses.
      final s = InstitutionVerificationStanding.fromJson(
        payload(existenceState: 'MANUAL_REVIEW', existenceAvailable: const []),
      );
      expect(s.existence.canSubmit('SUBMITTED'), isFalse);
    });

    test('WHAT WAS ASKED FOR SURVIVES THE PARSE', () {
      // This is the field that stops NEEDS_INFO being a dead end.
      final s = InstitutionVerificationStanding.fromJson(
        payload(infoRequested: 'A registration certificate showing the address.'),
      );
      expect(
        s.existence.infoRequested,
        'A registration certificate showing the address.',
      );
    });

    test('THE WHOLE MENU SURVIVES, not just a suggestion', () {
      final s = InstitutionVerificationStanding.fromJson(payload());
      expect(s.menu, contains(AuthorityEvidenceKind.appointmentLetter));
      expect(s.menu, contains(AuthorityEvidenceKind.registryOfficerListing));
    });

    test('AN UNKNOWN MENU ITEM IS DROPPED, not shown as "Something else"', () {
      // Offering a kind this build cannot spell would produce a submission the
      // server rejects, after the person gathered the document.
      final s = InstitutionVerificationStanding.fromJson(
        payload(menu: const ['APPOINTMENT_LETTER', 'A_KIND_FROM_THE_FUTURE']),
      );
      expect(s.menu, [AuthorityEvidenceKind.appointmentLetter]);
      expect(s.menu, isNot(contains(AuthorityEvidenceKind.unknown)));
    });

    test('A MISSING PAYLOAD DOES NOT CRASH THE SCREEN', () {
      final s = InstitutionVerificationStanding.fromJson(const {});
      expect(s.existence.state, ExistenceState.unknown);
      expect(s.authority.state, AuthorityState.unknown);
      expect(s.menu, isEmpty);
      expect(s.accepted, isEmpty);
    });
  });

  group('evidence carries no submitter', () {
    test('THE BODY CANNOT NAME WHO SUPPLIED IT', () {
      // Provenance comes from the authenticated caller or it is not
      // provenance. The server sets it from the token; a client that could
      // claim it would be able to attribute somebody else's document.
      const evidence = SuppliedEvidence(reference: 'Companies House 09876543');
      expect(evidence.toJson().keys, isNot(contains('submittedByUserId')));
      expect(evidence.toJson(), {'reference': 'Companies House 09876543'});
    });

    test('an absent field is omitted rather than sent as null', () {
      const evidence = SuppliedEvidence(mediaId: 'media_1');
      expect(evidence.toJson(), {'mediaId': 'media_1'});
    });
  });

  group('a refusal keeps the words the server chose', () {
    Dio dioThatFails(Object? data, {int status = 409}) {
      final dio = Dio();
      dio.httpClientAdapter = _FailingAdapter(data: data, status: status);
      return dio;
    }

    test('THE SERVER MESSAGE REACHES THE PERSON INTACT', () async {
      // Two correct mappers in series already cost this release one reason:
      // the repository turned a specific sentence into a generic one and the
      // screen re-mapped it again, so the person read "Please try again".
      // THE REAL ENVELOPE. The API nests under `error`; a double that put the
      // fields at the top level is exactly what hid a defect where every
      // refusal reached the person as the offline sentence.
      final repo = InstitutionVerificationRepository(dioThatFails({
        'ok': false,
        'error': {
          'code': 'VERIFICATION_EVIDENCE_REQUIRED',
          'message': 'That step needs supporting evidence, and none has been supplied.',
          'details': null,
        },
      }));

      await expectLater(
        repo.standing('inst_1'),
        throwsA(
          isA<InstitutionVerificationException>()
              .having((e) => e.message, 'message',
                  'That step needs supporting evidence, and none has been supplied.')
              .having((e) => e.code, 'code', 'VERIFICATION_EVIDENCE_REQUIRED'),
        ),
      );
    });

    test('ONLY A SILENT SERVER GETS A GENERIC SENTENCE', () async {
      final repo = InstitutionVerificationRepository(dioThatFails(null, status: 502));
      await expectLater(
        repo.standing('inst_1'),
        throwsA(
          isA<InstitutionVerificationException>().having(
            (e) => e.message,
            'message',
            contains('Your progress is saved'),
          ),
        ),
      );
    });
  });

  group('the 120-day deadline is shown only when one is running', () {
    MigrationPosture posture(Map<String, dynamic>? json) =>
        MigrationPosture.fromJson(json);

    test('NOT_ANCHORED IS NOT A COUNTDOWN', () {
      // No notice has been DELIVERED, so nothing runs. A card that appeared as
      // soon as a migration record existed would show a deadline to somebody
      // who was never told anything.
      final p = posture({
        'reason': 'NOT_ANCHORED',
        'deadlineAt': null,
        'daysRemaining': null,
        'authorityGovernanceBlocked': false,
        'institutionVoiceBlocked': false,
      });
      expect(p.running, isFalse);
      expect(p.deadlineAt, isNull);
    });

    test('IN_WINDOW RUNS, AND CARRIES THE DATE', () {
      final p = posture({
        'reason': 'IN_WINDOW',
        'deadlineAt': '2027-01-08T09:00:00.000Z',
        'daysRemaining': 110,
        'authorityGovernanceBlocked': true,
        'institutionVoiceBlocked': false,
      });
      expect(p.running, isTrue);
      // §6 -- the specific date, which the client can only show if given it.
      expect(p.deadlineAt, DateTime.parse('2027-01-08T09:00:00.000Z'));
      // §3.2/§3.3 -- two blocks at two different moments, never collapsed.
      expect(p.authorityGovernanceBlocked, isTrue);
      expect(p.institutionVoiceBlocked, isFalse);
    });

    test('SATISFIED IS NOT RUNNING, whatever the date says', () {
      final p = posture({
        'reason': 'SATISFIED',
        'deadlineAt': '2026-01-01T00:00:00.000Z',
        'authorityGovernanceBlocked': false,
        'institutionVoiceBlocked': false,
      });
      // §3.4 -- restoration is immediate on verification. A person who has
      // finished must not still be shown a deadline that has passed.
      expect(p.running, isFalse);
    });

    test('AN UNREADABLE POSTURE IS NOT A DEADLINE', () {
      // Failing towards "no deadline" is the safe direction: the alternative
      // is telling somebody they are out of time on the strength of a payload
      // this build could not read.
      for (final raw in [null, <String, dynamic>{}]) {
        final p = posture(raw);
        expect(p.running, isFalse);
        expect(p.reason, 'NOT_ANCHORED');
        expect(p.authorityGovernanceBlocked, isFalse);
        expect(p.institutionVoiceBlocked, isFalse);
      }
    });
  });
}

/// Answers every request with a failure, so refusal mapping can be driven
/// without a server.
class _FailingAdapter implements HttpClientAdapter {
  _FailingAdapter({required this.data, required this.status});

  final Object? data;
  final int status;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    throw DioException(
      requestOptions: options,
      response: Response<dynamic>(
        requestOptions: options,
        statusCode: status,
        data: data,
      ),
      type: DioExceptionType.badResponse,
    );
  }
}
