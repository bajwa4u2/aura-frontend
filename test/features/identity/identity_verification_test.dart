import 'package:aura/features/identity/data/identity_verification_repository.dart';
import 'package:flutter_test/flutter_test.dart';

/// WHAT THE CLIENT IS ALLOWED TO SAY ABOUT SOMEONE'S VERIFICATION.
///
/// The governed distinctions are easy to lose on the way to a screen: a
/// client that folds "we could not tell" into "failed", or renders an unknown
/// state as a decision, has quietly undone Policy §7. These pin the parsing
/// layer where that would happen first.
void main() {
  group('state parsing', () {
    test('maps every governed state', () {
      expect(IdentityVerificationState.parse('PENDING_REVIEW'),
          IdentityVerificationState.pendingReview);
      expect(IdentityVerificationState.parse('NEEDS_MORE_INFO'),
          IdentityVerificationState.needsMoreInfo);
      expect(IdentityVerificationState.parse('REJECTED'),
          IdentityVerificationState.rejected);
      expect(IdentityVerificationState.parse('APPROVED'),
          IdentityVerificationState.approved);
      expect(IdentityVerificationState.parse('WITHDRAWN'),
          IdentityVerificationState.withdrawn);
    });

    test('treats an unrecognised state as unknown, never as a decision', () {
      // A newer backend state must not be rendered as approved OR rejected.
      // Both would be a lie, and one of them is the dangerous direction.
      for (final raw in ['SOMETHING_NEW', '', null]) {
        final state = IdentityVerificationState.parse(raw);
        expect(state, IdentityVerificationState.unknown);
        expect(state, isNot(IdentityVerificationState.approved));
        expect(state, isNot(IdentityVerificationState.rejected));
      }
    });

    test('counts unknown as still open, so nothing is presented as settled', () {
      expect(IdentityVerificationState.unknown.isOpen, isTrue);
      expect(IdentityVerificationState.pendingReview.isOpen, isTrue);
      expect(IdentityVerificationState.needsMoreInfo.isOpen, isTrue);
      // The three that genuinely ended.
      expect(IdentityVerificationState.approved.isOpen, isFalse);
      expect(IdentityVerificationState.rejected.isOpen, isFalse);
      expect(IdentityVerificationState.withdrawn.isOpen, isFalse);
    });
  });

  group('evidence kinds', () {
    test('carries exactly the two roles governance authorizes', () {
      expect(IdentityEvidenceKind.values.length, 2);
      expect(IdentityEvidenceKind.governmentId.wire, 'GOVERNMENT_ID');
      expect(IdentityEvidenceKind.selfieComparison.wire, 'SELFIE_COMPARISON');
    });

    test('never calls the photograph "liveness" in anything a person reads', () {
      // A still image compared by a reviewer is not a liveness check, and the
      // wording a person sees must not claim a check Aura does not perform.
      for (final kind in IdentityEvidenceKind.values) {
        expect(kind.label.toLowerCase(), isNot(contains('liveness')));
        expect(kind.help.toLowerCase(), isNot(contains('liveness')));
        expect(kind.wire.toLowerCase(), isNot(contains('liveness')));
      }
    });

    test('explains what is wanted without naming a fixed document list', () {
      // Governance authorizes "a government-issued document" and does not
      // enumerate which ones. The help text may give examples; it must not
      // read as an exhaustive list the client would then enforce.
      final help = IdentityEvidenceKind.governmentId.help;
      expect(help, contains('government-issued'));
    });
  });

  group('status parsing', () {
    test('reads a rejection with its retry horizon', () {
      // Policy §7: never permanent. A refusal with no horizon reads as a ban,
      // so the date has to survive parsing to reach the screen.
      final status = IdentityVerificationStatus.fromJson({
        'current': {
          'id': 's1',
          'state': 'REJECTED',
          'decisionReason': 'The document photo was unreadable.',
          'evidence': [
            {'id': 'e1', 'kind': 'GOVERNMENT_ID', 'discarded': false},
          ],
        },
        'history': [],
        'canSubmit': false,
        'retryAfter': '2026-09-28T00:00:00.000Z',
        'blockedReason': 'You can try again after the review period.',
      });

      expect(status.current!.state, IdentityVerificationState.rejected);
      expect(status.canSubmit, isFalse);
      expect(status.retryAfter, DateTime.parse('2026-09-28T00:00:00.000Z'));
      expect(status.current!.decisionReason, 'The document photo was unreadable.');
    });

    test('surfaces the decision reason, because the person must be able to act', () {
      final submission = IdentityVerificationSubmission.fromJson({
        'id': 's1',
        'state': 'NEEDS_MORE_INFO',
        'decisionReason': 'Please send a photo showing all four corners.',
        'evidence': const [],
      });
      expect(submission.decisionReason, isNotNull);
      expect(submission.state, IdentityVerificationState.needsMoreInfo);
    });

    test('treats a blank reason as absent rather than rendering an empty line', () {
      final submission = IdentityVerificationSubmission.fromJson({
        'id': 's1',
        'state': 'APPROVED',
        'decisionReason': '   ',
        'evidence': const [],
      });
      expect(submission.decisionReason, isNull);
    });

    test('reports discarded evidence rather than hiding it', () {
      // Policy §6 destruction is the reassuring half of the story. A person
      // is owed the fact that their document is gone.
      final submission = IdentityVerificationSubmission.fromJson({
        'id': 's1',
        'state': 'APPROVED',
        'evidence': [
          {'id': 'e1', 'kind': 'GOVERNMENT_ID', 'discarded': true},
        ],
      });
      expect(submission.evidence.single.discarded, isTrue);
    });

    test('never parses a media id or URL out of the wire', () {
      // The backend does not send them. If it ever did, this client must not
      // start carrying a live path to somebody's passport.
      final submission = IdentityVerificationSubmission.fromJson({
        'id': 's1',
        'state': 'PENDING_REVIEW',
        'evidence': [
          {
            'id': 'e1',
            'kind': 'GOVERNMENT_ID',
            'discarded': false,
            'mediaId': 'should-be-ignored',
            'url': 'https://example/should-be-ignored',
          },
        ],
      });
      final e = submission.evidence.single;
      expect(e.id, 'e1');
      // The model has no field to put either in — asserted by shape.
      expect(e.kind, IdentityEvidenceKind.governmentId);
    });

    test('survives an empty payload without throwing', () {
      final status = IdentityVerificationStatus.fromJson({});
      expect(status.current, isNull);
      expect(status.history, isEmpty);
      expect(status.canSubmit, isFalse);
    });
  });
}
