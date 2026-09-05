import 'package:aura/features/realtime/domain/call_state.dart';
import 'package:aura/features/realtime/domain/realtime_models.dart';
import 'package:flutter_test/flutter_test.dart';

/// THE CLIENT READS THE CALL. IT DOES NOT WORK THE CALL OUT.
///
/// Aura had no client-side call state at all: each surface assembled its own
/// answer from whatever was nearest — a socket being open, a roster having two
/// rows, a local camera having started, a route being mounted — and they
/// disagreed with each other and with the server. The visible cost was a call
/// that showed a green "Live" dot and a running timer while the other phone was
/// still ringing.
///
/// These tests pin the replacement:
///
///   CLIENT_CALL_STATE_AUTHORITIES = 1
///   CLIENT_DERIVES_CONNECTED      = 0
///   TIMER_STARTS_BEFORE_CONNECTED = 0
void main() {
  Map<String, dynamic> callJson({
    String phase = 'INITIATED',
    String? connectedAt,
    String? endedAt,
    String? outcome,
    String? ringPresentedAt,
  }) => {
        'id': 'call-1',
        'phase': phase,
        'kind': 'VOICE',
        'initiatorUserId': 'caller-1',
        'outcome': outcome,
        'initiatedAt': '2026-09-04T10:00:00.000Z',
        'ringPresentedAt': ringPresentedAt,
        'acceptedAt': null,
        'connectedAt': connectedAt,
        'endedAt': endedAt,
        'participants': [
          {'userId': 'caller-1', 'role': 'CALLER'},
          {
            'userId': 'callee-1',
            'role': 'CALLEE',
            'alertedAt': ringPresentedAt,
          },
        ],
      };

  group('duration', () {
    test('TIMER_STARTS_BEFORE_CONNECTED = 0', () {
      final now = DateTime.parse('2026-09-04T10:05:00.000Z');
      for (final phase in ['INITIATED', 'INVITED', 'ALERTING', 'ACCEPTED', 'CONNECTING']) {
        final call = CallState.fromJson(callJson(phase: phase))!;
        expect(
          call.durationAt(now),
          isNull,
          reason: 'a call in $phase has not connected and has no duration',
        );
      }
    });

    test('the clock starts at connectedAt, not at anything earlier', () {
      final call = CallState.fromJson(
        callJson(
          phase: 'CONNECTED',
          connectedAt: '2026-09-04T10:04:00.000Z',
        ),
      )!;
      final now = DateTime.parse('2026-09-04T10:05:00.000Z');
      expect(call.durationAt(now), const Duration(minutes: 1));
    });

    test('a declined call has no duration rather than a fabricated one', () {
      final call = CallState.fromJson(
        callJson(
          phase: 'ENDED',
          outcome: 'DECLINED',
          endedAt: '2026-09-04T10:00:20.000Z',
        ),
      )!;
      expect(call.durationAt(DateTime.now()), isNull);
      expect(call.outcome, CallOutcome.declined);
    });

    test('an ended conversation stops counting at endedAt', () {
      final call = CallState.fromJson(
        callJson(
          phase: 'ENDED',
          outcome: 'CONNECTED_ENDED',
          connectedAt: '2026-09-04T10:01:00.000Z',
          endedAt: '2026-09-04T10:03:30.000Z',
        ),
      )!;
      final later = DateTime.parse('2026-09-04T11:00:00.000Z');
      expect(call.durationAt(later), const Duration(minutes: 2, seconds: 30));
    });
  });

  group('phase events move forward only', () {
    test('a late CONNECTING cannot pull a connected call backwards', () {
      final connected = CallState.fromJson(
        callJson(phase: 'CONNECTED', connectedAt: '2026-09-04T10:04:00.000Z'),
      )!;

      final after = connected.applyPhaseEvent({'phase': 'CONNECTING'});

      expect(after.phase, CallPhase.connected);
      expect(after.connectedAt, connected.connectedAt);
    });

    test('connectedAt is first-write-wins under duplicate events', () {
      final connecting = CallState.fromJson(callJson(phase: 'CONNECTING'))!;

      final first = connecting.applyPhaseEvent({
        'phase': 'CONNECTED',
        'connectedAt': '2026-09-04T10:04:00.000Z',
      });
      final again = first.applyPhaseEvent({
        'phase': 'CONNECTED',
        'connectedAt': '2026-09-04T10:09:00.000Z',
      });

      expect(again.connectedAt, first.connectedAt);
    });

    test('an unrecognised phase is ignored, never guessed at', () {
      final alerting = CallState.fromJson(callJson(phase: 'ALERTING'))!;
      expect(alerting.applyPhaseEvent({'phase': 'SOMETHING_NEW'}).phase,
          CallPhase.alerting);
    });
  });

  group('what each phase means', () {
    test('accepted is not connected', () {
      final accepted = CallState.fromJson(callJson(phase: 'ACCEPTED'))!;
      expect(accepted.isAccepted, isTrue);
      expect(accepted.isConnected, isFalse);
      expect(accepted.durationAt(DateTime.now()), isNull);
    });

    test('ringing means a device actually alerted a person', () {
      final ringing = CallState.fromJson(
        callJson(phase: 'ALERTING', ringPresentedAt: '2026-09-04T10:00:02.000Z'),
      )!;
      expect(ringing.isRinging, isTrue);
      expect(ringing.ringPresentedAt, isNotNull);

      final invited = CallState.fromJson(callJson(phase: 'INVITED'))!;
      expect(invited.isRinging, isFalse);
      expect(invited.ringPresentedAt, isNull);
    });

    test('NOT_PRESENTED is kept distinct from MISSED', () {
      // Telling someone they ignored a call their phone never announced is a
      // lie about them, and the two outcomes must never collapse.
      final notPresented =
          CallState.fromJson(callJson(phase: 'ENDED', outcome: 'NOT_PRESENTED'))!;
      expect(notPresented.outcome, CallOutcome.notPresented);
      expect(notPresented.outcome, isNot(CallOutcome.missed));
    });

    test('which side of the call a person is on comes from the record', () {
      final call = CallState.fromJson(callJson())!;
      expect(call.isCaller('caller-1'), isTrue);
      expect(call.isCaller('callee-1'), isFalse);
      // Never "whoever is asking", and never an empty identity.
      expect(call.isCaller(''), isFalse);
    });
  });

  group('a session carries its call', () {
    Map<String, dynamic> sessionJson(Map<String, dynamic>? call) => {
          'id': 'session-1',
          'surfaceType': 'THREAD',
          'surfaceId': 'thread-1',
          'startedByUserId': 'caller-1',
          'status': 'ACTIVE',
          'kind': 'AUDIO',
          'startedAt': '2026-09-04T10:00:00.000Z',
          'answeredAt': '2026-09-04T10:00:00.000Z',
          'call': call,
        };

    test('a call session exposes the call', () {
      final session = RealtimeSession.fromJson(
        sessionJson(callJson(phase: 'CONNECTED', connectedAt: '2026-09-04T10:04:00.000Z')),
      );
      expect(session.call, isNotNull);
      expect(session.call!.phase, CallPhase.connected);
    });

    test('no call is null, which is not the same as a call that has not connected', () {
      // A meeting or a stage. Collapsing "there is no call here" into "this
      // call has not connected" is how a room that nobody called ends up
      // rendering call-lifecycle words.
      final session = RealtimeSession.fromJson(sessionJson(null));
      expect(session.call, isNull);
      // The legacy room timestamps are still present and still honest for a
      // room; they are simply not a call's clock.
      expect(session.startedAt, isNotNull);
    });

    test('withCall replaces only the call', () {
      final session = RealtimeSession.fromJson(sessionJson(callJson()));
      final advanced = session.withCall(
        session.call!.applyPhaseEvent({'phase': 'ALERTING'}),
      );

      expect(advanced.call!.phase, CallPhase.alerting);
      expect(advanced.id, session.id);
      expect(advanced.status, session.status);
      expect(advanced.startedAt, session.startedAt);
    });
  });
}
