import 'dart:typed_data';

import 'package:aura/features/admin/data/institution_verification_review_repository.dart';
import 'package:aura/features/institutions/verification/data/institution_verification_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// WHAT A REVIEWER IS GIVEN TO DECIDE WITH.
///
/// The reviewer's copy of the vocabulary is the dangerous one: it is the copy
/// used to make a decision about somebody. So these pin that it IS the same
/// vocabulary — a second parser that drifted would eventually let a reviewer
/// act on a state the owner's screen calls something else.
void main() {
  group('the queue is parsed as cases, not as rows', () {
    final payload = {
      'existence': [
        {
          'id': 'exp_1',
          'institutionId': 'inst_1',
          'state': 'MANUAL_REVIEW',
          'category': 'HEALTHCARE',
          'categoryNeedsReview': false,
          'priority': true,
          'submittedAt': '2026-09-01T10:00:00.000Z',
        },
        {
          'id': 'exp_2',
          'institutionId': 'inst_2',
          'state': 'SUBMITTED',
          'category': null,
          'categoryNeedsReview': true,
          'priority': true,
          'submittedAt': '2026-09-02T10:00:00.000Z',
        },
      ],
      'authority': [
        {
          'id': 'aup_1',
          'institutionId': 'inst_1',
          'userId': 'u_claimant',
          'state': 'UNDER_REVIEW',
          'evidenceKind': 'APPOINTMENT_LETTER',
          'submittedAt': '2026-09-03T10:00:00.000Z',
        },
      ],
    };

    test('both proof kinds arrive, and are kept apart', () {
      final q = VerificationQueue.fromJson(payload);

      // Two queues, not one list of "verifications". A reviewer confirming an
      // institution exists and a reviewer confirming a person may speak for it
      // are answering different questions with different evidence.
      expect(q.existence, hasLength(2));
      expect(q.authority, hasLength(1));
      expect(q.isEmpty, isFalse);
    });

    test('AN AUTHORITY CASE NAMES WHOSE IT IS', () {
      final q = VerificationQueue.fromJson(payload);
      // A decision about one person's authority must show which person.
      expect(q.authority.first.userId, 'u_claimant');
      expect(q.authority.first.evidenceKind, AuthorityEvidenceKind.appointmentLetter);
    });

    test('AN UNMAPPED CATEGORY IS FLAGGED, not silently blank', () {
      final q = VerificationQueue.fromJson(payload);
      final unmapped = q.existence.firstWhere((c) => c.proofId == 'exp_2');

      // §5.19 asks for a one-time admin pass for anything that did not map
      // cleanly. A blank category with no flag would read as "no category
      // needed" rather than "somebody has to decide this".
      expect(unmapped.category, isNull);
      expect(unmapped.categoryNeedsReview, isTrue);
    });

    test('PRIORITY COMES FROM THE SERVER, not from the client re-deciding it', () {
      final q = VerificationQueue.fromJson(payload);
      expect(q.existence.every((c) => c.priority), isTrue);
    });

    test('an empty queue is empty, not an error', () {
      final q = VerificationQueue.fromJson(const {'existence': [], 'authority': []});
      expect(q.isEmpty, isTrue);
    });

    test('a malformed payload does not crash the console', () {
      final q = VerificationQueue.fromJson(const {});
      expect(q.isEmpty, isTrue);
    });

    test('THE REVIEWER SHARES THE OWNER VOCABULARY', () {
      final q = VerificationQueue.fromJson(payload);
      // Same enums, one definition. Two parsers would eventually disagree
      // about what LEGACY_UNVERIFIED means, and this is the copy used to
      // decide something about a person.
      expect(q.existence.first.state, ExistenceState.manualReview);
      expect(q.authority.first.state, AuthorityState.underReview);
    });
  });

  group('a refusal reaches the reviewer in the words the server chose', () {
    Dio failing(Object? data) {
      final dio = Dio();
      dio.httpClientAdapter = _FailingAdapter(data: data);
      return dio;
    }

    test('THE SERVER MESSAGE SURVIVES', () async {
      final repo = InstitutionVerificationReviewRepository(failing({
        'code': 'VERIFICATION_ACTOR_NOT_PERMITTED',
        'message': 'That step is part of this process, but not one you can take.',
      }));

      await expectLater(
        repo.confirmAuthority('aup_1'),
        throwsA(
          isA<InstitutionVerificationException>()
              .having((e) => e.message, 'message',
                  'That step is part of this process, but not one you can take.')
              .having((e) => e.code, 'code', 'VERIFICATION_ACTOR_NOT_PERMITTED'),
        ),
      );
    });

    test('A SILENT SERVER SAYS NOTHING WAS DECIDED', () async {
      // The important half: a reviewer who does not know whether their
      // decision landed will take it again.
      final repo = InstitutionVerificationReviewRepository(failing(null));
      await expectLater(
        repo.rejectExistence('exp_1', 'The certificate named a different entity.'),
        throwsA(
          isA<InstitutionVerificationException>().having(
            (e) => e.message,
            'message',
            contains('Nothing was decided'),
          ),
        ),
      );
    });
  });
}

class _FailingAdapter implements HttpClientAdapter {
  _FailingAdapter({required this.data});

  final Object? data;

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
        statusCode: 403,
        data: data,
      ),
      type: DioExceptionType.badResponse,
    );
  }
}
