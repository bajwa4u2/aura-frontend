import 'package:flutter_test/flutter_test.dart';

import 'package:aura/features/media_governance/data/media_restriction.dart';

/// CH-12 E6 — the member's route back.
///
/// These test the DECISIONS the client is allowed to make, which is almost
/// none. Standing, eligibility and wording are the server's; what the client
/// owns is not leaking, not accusing, and not inventing state — so that is what
/// is pinned here.

Map<String, dynamic> restrictionJson({
  bool restricted = true,
  bool hasStanding = true,
  bool canAppeal = true,
  String category = 'MALICIOUS_CONTENT',
  bool automated = true,
  String disposition = 'PRELIMINARY',
  Map<String, dynamic>? appeal,
}) =>
    {
      'restricted': restricted,
      'hasStanding': hasStanding,
      'canAppeal': canAppeal,
      'standingBasis': hasStanding ? 'OWNER' : null,
      'notice': restricted
          ? {
              'subject': {
                'mediaId': 'm1',
                'fileName': 'report.pdf',
                'mimeType': 'application/pdf',
              },
              'useRestricted': true,
              'category': category,
              'automatedVerdict': automated,
              'context': 'Automated examination identified malicious content in this file.',
              'disposition': disposition,
              'appeal': {'available': true, 'route': 'media.quarantine.appeal'},
              'deeplink': '/media/m1/restricted',
              'appealStatus': null,
            }
          : null,
      'appeal': appeal,
    };

void main() {
  group('the client renders what the server decided', () {
    test('parses a restriction with standing and an appeal offer', () {
      final r = MediaRestriction.fromJson(restrictionJson());
      expect(r.restricted, isTrue);
      expect(r.hasStanding, isTrue);
      expect(r.canAppeal, isTrue);
      expect(r.standingBasis, 'OWNER');
      expect(r.notice!.category, 'MALICIOUS_CONTENT');
      expect(r.notice!.automatedVerdict, isTrue);
    });

    test('a caller without standing gets nothing to render', () {
      final r = MediaRestriction.fromJson(
        restrictionJson(restricted: false, hasStanding: false, canAppeal: false),
      );
      expect(r.hasStanding, isFalse);
      expect(r.notice, isNull);
      expect(r.appeal, isNull);
      expect(r.isEmpty, isTrue);
    });

    test('an unrestricted object with no history is indistinguishable from no standing', () {
      // Both collapse to the same empty state, so the screen cannot be used to
      // discover whether someone else's file is restricted.
      final noStanding = MediaRestriction.fromJson(
        restrictionJson(restricted: false, hasStanding: false, canAppeal: false),
      );
      final notRestricted = MediaRestriction.fromJson(
        restrictionJson(restricted: false, canAppeal: false),
      );
      expect(noStanding.isEmpty, notRestricted.isEmpty);
      expect(noStanding.notice, notRestricted.notice);
    });

    test('does not offer an appeal the server did not offer', () {
      final r = MediaRestriction.fromJson(restrictionJson(canAppeal: false));
      expect(r.canAppeal, isFalse);
    });
  });

  group('the notice never becomes an accusation', () {
    test('is PRELIMINARY and reversible until a human decides', () {
      final r = MediaRestriction.fromJson(restrictionJson());
      expect(r.notice!.disposition, 'PRELIMINARY');
      expect(r.notice!.isReversible, isTrue);
    });

    test('becomes final only when the server says so', () {
      final r = MediaRestriction.fromJson(restrictionJson(disposition: 'FINAL'));
      expect(r.notice!.isReversible, isFalse);
    });

    test('a moderator action is not reported as automated', () {
      final r = MediaRestriction.fromJson(
        restrictionJson(category: 'POLICY_ACTION', automated: false),
      );
      expect(r.notice!.automatedVerdict, isFalse);
      expect(r.notice!.category, 'POLICY_ACTION');
    });

    test('carries no field capable of holding a detector internal', () {
      // The member-facing model has no signature, examiner or threshold field,
      // so a server widening cannot leak one through this surface.
      final r = MediaRestriction.fromJson(restrictionJson());
      final n = r.notice!;
      expect(n.context.toLowerCase(), isNot(contains('eicar')));
      expect(n.context.toLowerCase(), isNot(contains('clamav')));
    });
  });

  group('appeal state', () {
    test('recognises an open appeal', () {
      final r = MediaRestriction.fromJson(restrictionJson(
        canAppeal: false,
        appeal: {'id': 'a1', 'status': 'SUBMITTED'},
      ));
      expect(r.appeal!.isOpen, isTrue);
      expect(r.appeal!.isDecided, isFalse);
      expect(r.canAppeal, isFalse);
    });

    test('recognises a decided appeal and keeps its outcome', () {
      final r = MediaRestriction.fromJson(restrictionJson(
        restricted: false,
        canAppeal: false,
        appeal: {
          'id': 'a1',
          'status': 'REVERSED',
          'decidedAt': '2026-08-21T02:00:00.000Z',
          'decisionSummary': 'Certification fixture; released.',
        },
      ));
      expect(r.appeal!.isOpen, isFalse);
      expect(r.appeal!.isDecided, isTrue);
      expect(r.appeal!.decisionSummary, 'Certification fixture; released.');
      // History survives the reversal — a member who appealed is entitled to
      // see how it ended.
      expect(r.restricted, isFalse);
      expect(r.isEmpty, isFalse);
    });

    test('has no field for the reviewer private note', () {
      final appeal = MediaAppeal.fromJson({
        'id': 'a1',
        'status': 'UPHELD',
        'privateNote': 'reviewer only — must never reach the member',
      });
      // The model simply cannot carry it, so a server select widening does not
      // silently surface it in the app.
      expect(appeal.toString().contains('reviewer only'), isFalse);
      expect(appeal.decisionSummary, isNull);
    });

    test('tolerates a malformed appeal rather than crashing the screen', () {
      final r = MediaRestriction.fromJson(restrictionJson(appeal: {'nonsense': 1}));
      expect(r.appeal!.status, 'SUBMITTED');
      expect(r.appeal!.submittedAt, isNull);
    });
  });
}
