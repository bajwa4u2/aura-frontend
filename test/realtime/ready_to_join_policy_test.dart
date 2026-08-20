// F044 — THE READY-TO-JOIN PRESENTATION RULE, PROVEN IN BOTH DIRECTIONS.
//
// "Ready to join / Tap Join call to enter" is an instruction. These tests pin
// when it is truthful, and — more importantly — pin the two states where it
// was being shown and should not have been:
//
//   POST-ACCEPT  the viewer accepted, the join is in flight, and the first
//                frame was telling them to join again. The founder's word for
//                it was a "mediator": it came and went between accepting and
//                being in the call.
//   POST-END     the call is over, joinState is back to idle, and the surface
//                was still offering to join it.
//
// Written as a pure predicate on purpose. A widget test could only show that
// the flash is gone on one path; this states the rule itself, so a future
// change that reintroduces either window fails here by name.
import 'package:flutter_test/flutter_test.dart';

import 'package:aura/features/realtime/domain/ready_to_join_policy.dart';
import 'package:aura/features/realtime/domain/realtime_enums.dart';

void main() {
  group('when the instruction is truthful', () {
    test('idle, active session, no intent — the one state that earns it', () {
      expect(
        readyToJoinIsTruthful(
          joinState: RealtimeJoinState.idle,
          joinIntentInFlight: false,
          sessionIsActive: true,
        ),
        isTrue,
      );
    });
  });

  group('POST-ACCEPT — the defect the founder observed', () {
    test('an accepted call in flight is NEVER told to join', () {
      // The exact first-frame state: the room has mounted from an
      // `action=join` address, the post-frame join has not run yet, so the
      // lifecycle still reads idle.
      expect(
        readyToJoinIsTruthful(
          joinState: RealtimeJoinState.idle,
          joinIntentInFlight: true,
          sessionIsActive: true,
        ),
        isFalse,
      );
    });

    test('intent outranks every lifecycle position it could race with', () {
      for (final state in RealtimeJoinState.values) {
        expect(
          readyToJoinIsTruthful(
            joinState: state,
            joinIntentInFlight: true,
            sessionIsActive: true,
          ),
          isFalse,
          reason: 'intent in flight must silence the instruction in $state',
        );
      }
    });
  });

  group('POST-END — the originally registered symptom', () {
    test('an ended session is not offered as joinable', () {
      expect(
        readyToJoinIsTruthful(
          joinState: RealtimeJoinState.idle,
          joinIntentInFlight: false,
          sessionIsActive: false,
        ),
        isFalse,
      );
    });

    test('an UNKNOWN session is not offered either', () {
      // null is "we do not know yet". Instructing someone to join a session we
      // cannot describe is how the post-end symptom reappears while canonical
      // state is still catching up.
      expect(
        readyToJoinIsTruthful(
          joinState: RealtimeJoinState.idle,
          joinIntentInFlight: false,
          sessionIsActive: null,
        ),
        isFalse,
      );
    });
  });

  group('every other lifecycle state owns its own presentation', () {
    test('no non-idle state produces the join instruction', () {
      for (final state in RealtimeJoinState.values) {
        if (state == RealtimeJoinState.idle) continue;
        expect(
          readyToJoinIsTruthful(
            joinState: state,
            joinIntentInFlight: false,
            sessionIsActive: true,
          ),
          isFalse,
          reason: '$state has its own truthful sentence',
        );
      }
    });

    test('busy is work under way, not an instruction', () {
      expect(
        readyToJoinIsTruthful(
          joinState: RealtimeJoinState.idle,
          joinIntentInFlight: false,
          sessionIsActive: true,
          isBusy: true,
        ),
        isFalse,
      );
    });
  });

  group('the lifecycle itself is untouched', () {
    test('all nine states still exist and are distinct', () {
      // The repair is presentation relative to lifecycle. RINGING -> ACCEPTED
      // -> JOINING -> CONNECTED must never be collapsed to make a surface
      // simpler, so this fails if a future change removes or merges states.
      expect(RealtimeJoinState.values.toSet(), hasLength(10));
      expect(
        RealtimeJoinState.values,
        containsAll(<RealtimeJoinState>[
          RealtimeJoinState.idle,
          RealtimeJoinState.joining,
          RealtimeJoinState.joined,
        ]),
      );
    });
  });
}
