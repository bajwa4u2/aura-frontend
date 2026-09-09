import 'package:flutter_test/flutter_test.dart';
import 'package:aura/core/navigation/navigation_authority.dart';
import 'package:aura/features/activity/presentation/activity_screen.dart';

/// CALL HISTORY MUST DESCRIBE THE CALL THAT HAPPENED, AND MUST NOT TRY TO
/// REJOIN IT.
///
/// Two defects the founder reported on 2026-09-08, both in this screen.
///
/// 1. Tapping a concluded call navigated to the conversation ASKING TO JOIN a
///    session that had ended. `isRealtimeActivity` is true for any row with a
///    `sessionId` — which is every call ever made — and both branches under it
///    passed `shouldJoin: true` unconditionally. The screen already knew
///    better: `_ctaLabel` renders "View", not "Join", for exactly these rows.
///
/// 2. The backend resolves seven outcomes. This screen handled three; the rest
///    fell through to "You cancelled a call", so a call the other person
///    genuinely missed was reported to the caller as something the caller did.
void main() {
  Map<String, dynamic> row({
    String kind = 'CALL_CANCELLED',
    String? outcome,
    String? sessionId = 'sess-1',
  }) =>
      {
        'type': 'LIVE',
        'data': <String, dynamic>{
          'notificationKind': kind,
          if (outcome != null) 'callOutcome': outcome,
          if (sessionId != null) 'sessionId': sessionId,
        },
      };

  group('a concluded call is not joinable', () {
    test('every terminal call kind is terminal', () {
      for (final kind in const [
        'CALL_MISSED',
        'CALL_COMPLETED',
        'CALL_DECLINED',
        'CALL_CANCELLED',
      ]) {
        expect(callRowIsTerminal(row(kind: kind)), isTrue, reason: kind);
      }
    });

    test('an outcome closes a call even when the kind does not say so', () {
      expect(
        callRowIsTerminal(row(kind: 'REALTIME_STARTED', outcome: 'MISSED')),
        isTrue,
      );
    });

    test('a ringing call stays joinable', () {
      expect(callRowIsTerminal(row(kind: 'CALL_RINGING')), isFalse);
      expect(callRowIsTerminal(row(kind: 'REALTIME_INVITE')), isFalse);
    });

    test('a Go Live row is untouched — absence of an outcome closes nothing', () {
      // The conservative half of the rule. A row that says nothing about how
      // it ended keeps exactly the behaviour it has today, so a live broadcast
      // is still something you can walk into.
      expect(callRowIsTerminal(row(kind: 'REALTIME_STARTED')), isFalse);
      expect(callRowIsTerminal(row(kind: '')), isFalse);
    });
  });

  group('a call history item resolves to the call', () {
    test('the destination is the occurrence, not the conversation', () {
      final route = NavigationAuthority.callDetailRoute('sess-1');
      expect(route, '/calls/sess-1');
      expect(route, isNot(contains('messages')),
          reason: 'the conversation is secondary context, not the target');
    });

    test('the fallback return lands on call history, not a conversation', () {
      expect(NavigationAuthority.callHistoryRoute, isNot(contains('messages')));
    });
  });
}
