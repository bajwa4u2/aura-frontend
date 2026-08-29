import 'package:flutter_test/flutter_test.dart';

import 'package:aura/core/distribution/destination_capability.dart';

/// The defect these pin: a destination that vanished because one GET failed.
///
/// The old composer read both providers through a helper that returned null on
/// ANY failure, reduced that to `connected = false`, and then hid the row. A
/// dropped request, an expired token, a 500 and a genuinely unconnected
/// account produced one answer, so visibility depended on whether a transient
/// request happened to succeed.
///
/// Every test below is written against that behaviour: what the old model got
/// wrong is named in the test, so a regression reads as a restatement of the
/// bug rather than a failing assertion nobody can interpret.
void main() {
  group('destinationStateFromProbe — what an outcome MEANS', () {
    test('reachable, connected, authorised → available', () {
      expect(
        destinationStateFromProbe(
          reachable: true,
          connected: true,
          authorisationValid: true,
        ),
        DestinationState.available,
      );
    });

    test('a real absence is CONNECT_REQUIRED, not invisibility', () {
      expect(
        destinationStateFromProbe(
          reachable: true,
          connected: false,
          authorisationValid: true,
        ),
        DestinationState.connectRequired,
      );
    });

    test('an expired authorisation is RECONNECT_REQUIRED, not disconnection',
        () {
      // THE CASE THE OLD MODEL HANDLED WORST. A 401 made a destination the
      // person had deliberately connected disappear, with nothing to act on.
      expect(
        destinationStateFromProbe(
          reachable: true,
          connected: true,
          authorisationValid: false,
        ),
        DestinationState.reconnectRequired,
      );
    });

    test('UNREACHABLE IS NOT "NOT CONNECTED"', () {
      // The whole defect in one assertion: failing to ask must never be
      // reported as the provider having answered no.
      expect(
        destinationStateFromProbe(
          reachable: false,
          connected: true,
          authorisationValid: true,
        ),
        DestinationState.temporarilyUnavailable,
      );
    });

    test('unreachable outranks every downstream judgement', () {
      // We cannot know whether content or account is acceptable when we could
      // not reach the provider, so we must not claim to.
      expect(
        destinationStateFromProbe(
          reachable: false,
          connected: false,
          authorisationValid: false,
          contentSupported: false,
          accountEligible: false,
        ),
        DestinationState.temporarilyUnavailable,
      );
    });

    test('content that cannot go there is UNSUPPORTED_CONTENT', () {
      expect(
        destinationStateFromProbe(
          reachable: true,
          connected: true,
          authorisationValid: true,
          contentSupported: false,
        ),
        DestinationState.unsupportedContent,
      );
    });

    test('a platform that cannot publish is UNSUPPORTED_PLATFORM', () {
      expect(
        destinationStateFromProbe(
          reachable: true,
          connected: true,
          authorisationValid: true,
          platformSupported: false,
        ),
        DestinationState.unsupportedPlatform,
      );
    });

    test('an ineligible account is ACCOUNT_NOT_ELIGIBLE', () {
      expect(
        destinationStateFromProbe(
          reachable: true,
          connected: true,
          authorisationValid: true,
          accountEligible: false,
        ),
        DestinationState.accountNotEligible,
      );
    });
  });

  group('visibility — silence is reserved for exactly one state', () {
    const label = 'LinkedIn';

    DestinationCapability at(DestinationState s) =>
        DestinationCapability(id: 'linkedin', label: label, state: s);

    test('NO FAILURE STATE HIDES A DESTINATION', () {
      // The regression guard that matters most. If any of these ever returns
      // false again, LinkedIn has started disappearing again.
      for (final s in [
        DestinationState.available,
        DestinationState.connectRequired,
        DestinationState.reconnectRequired,
        DestinationState.temporarilyUnavailable,
        DestinationState.unsupportedContent,
        DestinationState.unsupportedPlatform,
        DestinationState.accountNotEligible,
      ]) {
        expect(at(s).isVisible, isTrue, reason: '$s must remain visible');
      }
    });

    test('only notOffered may be invisible', () {
      expect(at(DestinationState.notOffered).isVisible, isFalse);
    });

    test('only available may publish', () {
      for (final s in DestinationState.values) {
        expect(
          at(s).isPublishable,
          s == DestinationState.available,
          reason: '$s publishable must be ${s == DestinationState.available}',
        );
      }
    });
  });

  group('actions follow state', () {
    DestinationCapability at(DestinationState s) =>
        DestinationCapability(id: 'tiktok', label: 'TikTok', state: s);

    test('connect and reconnect each offer their own action', () {
      expect(at(DestinationState.connectRequired).actionLabel, 'Connect');
      expect(at(DestinationState.reconnectRequired).actionLabel, 'Reconnect');
      expect(at(DestinationState.connectRequired).hasRecoveryAction, isTrue);
      expect(at(DestinationState.reconnectRequired).hasRecoveryAction, isTrue);
    });

    test('a failure we caused offers Retry', () {
      expect(at(DestinationState.temporarilyUnavailable).actionLabel, 'Retry');
    });

    test('an impossible action is never offered', () {
      // Nothing the person does fixes an unsupported platform or unsuitable
      // content, so offering a button would be a lie.
      expect(at(DestinationState.unsupportedPlatform).actionLabel, isNull);
      expect(at(DestinationState.unsupportedContent).actionLabel, isNull);
      expect(at(DestinationState.available).actionLabel, isNull);
      expect(at(DestinationState.unsupportedPlatform).hasRecoveryAction, isFalse);
    });
  });

  group('what a person is told', () {
    test('no state renders an empty line except notOffered', () {
      for (final s in DestinationState.values) {
        final line = DestinationCapability(
          id: 'x',
          label: 'X',
          state: s,
        ).statusLine;
        if (s == DestinationState.notOffered) {
          expect(line, isEmpty);
        } else {
          expect(line, isNotEmpty, reason: '$s must say something');
        }
      }
    });

    test('a connected account is named when known', () {
      const cap = DestinationCapability(
        id: 'linkedin',
        label: 'LinkedIn',
        state: DestinationState.available,
        accountLabel: 'M S Bajwa',
      );
      expect(cap.statusLine, 'M S Bajwa');
    });

    test('reconnect explains itself without naming a token or an errno', () {
      const cap = DestinationCapability(
        id: 'linkedin',
        label: 'LinkedIn',
        state: DestinationState.reconnectRequired,
      );
      expect(cap.statusLine, contains('again'));
      expect(cap.statusLine.toLowerCase(), isNot(contains('token')));
      expect(cap.statusLine.toLowerCase(), isNot(contains('401')));
    });

    test('unsupported content may carry a specific reason', () {
      const cap = DestinationCapability(
        id: 'tiktok',
        label: 'TikTok',
        state: DestinationState.unsupportedContent,
        detail: 'TikTok needs a video in this post',
      );
      expect(cap.statusLine, 'TikTok needs a video in this post');
    });
  });
}
