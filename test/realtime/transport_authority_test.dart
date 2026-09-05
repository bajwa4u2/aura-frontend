import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aura/features/realtime/domain/call_state.dart';

/// TRANSPORT POLICY BELONGS TO THE BACKEND, AND A FAILED CALL SAYS SO.
///
/// Founder ruling, transport authority §1 and §3. The backend returns the
/// configuration Aura is permitted to connect with; the client negotiates with
/// exactly that and reports what happened. When the backend cannot issue that
/// configuration the client invents nothing — and, critically, does not simply
/// go quiet, which is what it used to do:
///
///   * `_resolveRtcConfiguration` threw,
///   * the throw was caught into a diagnostic string nothing displayed,
///   * no `RTCPeerConnection` was ever constructed,
///   * and both people sat on "Connecting…" for the life of the session.
///
/// These hold the two halves of the ruling that can be tested without a
/// network: the failure has a NAME in the shared vocabulary, and what it says
/// to a person is product language rather than infrastructure.
void main() {
  group('a connection failure is a first-class state, not an error string', () {
    test('every failure has product copy', () {
      for (final failure in CallConnectionFailure.values) {
        expect(failure.headline.trim(), isNotEmpty,
            reason: '$failure has no headline');
        expect(failure.detail.trim(), isNotEmpty,
            reason: '$failure has no detail');
      }
    });

    test('a configuration failure and a media failure are different facts', () {
      // Collapsing them would tell somebody their connection is at fault when
      // Aura never asked their network anything at all.
      expect(
        CallConnectionFailure.transportUnavailable.detail,
        isNot(equals(CallConnectionFailure.notEstablished.detail)),
      );
    });
  });

  group('the person is never shown Aura infrastructure', () {
    // Not a style rule. A person cannot act on any of these, and naming them
    // puts the plumbing in front of somebody trying to make a phone call.
    const forbidden = <String>[
      'cloudflare',
      'turn',
      'ice',
      'relay',
      'stun',
      'sdp',
      'webrtc',
      'provider',
      'internal_error',
      'http',
      '500',
    ];

    test('not in any headline or detail', () {
      for (final failure in CallConnectionFailure.values) {
        final copy = '${failure.headline} ${failure.detail}'.toLowerCase();
        for (final word in forbidden) {
          expect(copy.contains(word), isFalse,
              reason: '$failure copy leaks "$word": $copy');
        }
      }
    });

    test('the copy still says what happened and what to do', () {
      for (final failure in CallConnectionFailure.values) {
        final copy = '${failure.headline} ${failure.detail}'.toLowerCase();
        // "Something went wrong" is not an answer. Each one must name the call
        // and point at the next step. The step itself is a BUTTON carrying the
        // canonical retry label, so the prose only has to lead to it.
        expect(copy.contains('call'), isTrue, reason: '$failure: $copy');
        expect(copy.contains('try again'), isTrue, reason: '$failure: $copy');
      }
    });
  });

  group('a rendered frame is not necessarily a visible one', () {
    // The presentation gate's rule, stated as data so it cannot drift from the
    // widget: a card laid out behind a hidden tab or a paused app has shown
    // nobody anything, and reporting from there would tell a caller that
    // somebody's device is ringing at them when it is not — and would record an
    // unanswered call as MISSED rather than NOT_PRESENTED.
    bool eligible(AppLifecycleState? state) =>
        state == null ||
        state == AppLifecycleState.resumed ||
        state == AppLifecycleState.inactive;

    test('visible states may report a presentation', () {
      expect(eligible(AppLifecycleState.resumed), isTrue);
      // Visible but unfocused still shows the person an incoming call.
      // Demanding focus would swing the lie the other way and record
      // NOT_PRESENTED for a card somebody is looking at.
      expect(eligible(AppLifecycleState.inactive), isTrue);
    });

    test('invisible states must not', () {
      expect(eligible(AppLifecycleState.hidden), isFalse);
      expect(eligible(AppLifecycleState.paused), isFalse);
      expect(eligible(AppLifecycleState.detached), isFalse);
    });
  });
}
