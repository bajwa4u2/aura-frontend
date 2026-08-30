import 'package:flutter_test/flutter_test.dart';

import 'package:aura/features/conversation/presentation/conversation_incoming_call.dart';
import 'package:aura/features/updates/incoming_call_bridge.dart';

/// ONE INVITATION, THREE SURFACES.
///
/// CallKit, the app-root card and the thread projection must all be drawing
/// the same canonical invitation. These tests exercise the two pieces that
/// decide that: the bridge that holds the invitation, and the pure rule that
/// decides which conversation it belongs to.
Map<String, dynamic> invite({
  required String id,
  required String sessionId,
  String? correspondenceId,
  String? threadId,
  String source = 'socket',
  String? expiresAt,
  String caller = 'Zakria',
  String mediaMode = 'audio',
}) {
  return <String, dynamic>{
    'id': id,
    'notificationKind': 'CALL_RINGING',
    '_auraLifecycleSource': source,
    'data': <String, dynamic>{
      'sessionId': sessionId,
      'attention': 'INTERRUPT',
      'callState': 'RINGING',
      'mediaMode': mediaMode,
      'callerDisplayName': caller,
      if (correspondenceId != null) 'correspondenceId': correspondenceId,
      if (threadId != null) 'threadId': threadId,
      if (expiresAt != null) 'expiresAt': expiresAt,
    },
  };
}

void main() {
  group('the bridge is the one invitation store', () {
    test('a natively-delivered arrival enters the bridge', () {
      final bridge = IncomingCallBridgeNotifier();
      bridge.addIncoming(
        invite(id: 'inv-1', sessionId: 's-1', source: 'nativeCall'),
      );
      expect(bridge.state, hasLength(1));
      expect(bridge.currentSessionIds(), contains('s-1'));
    });

    test('a socket arrival for the same session does not duplicate it', () {
      // PushKit and the socket both deliver the same call. Whichever lands
      // first wins; the second must be absorbed, not stacked into a second
      // ringing card.
      final bridge = IncomingCallBridgeNotifier();
      bridge.addIncoming(
        invite(id: 'inv-native', sessionId: 's-1', source: 'nativeCall'),
      );
      bridge.addIncoming(
        invite(id: 'inv-socket', sessionId: 's-1', source: 'socket'),
      );
      expect(bridge.state, hasLength(1));
    });

    test('order does not matter — socket first, PushKit second', () {
      final bridge = IncomingCallBridgeNotifier();
      bridge.addIncoming(invite(id: 'inv-socket', sessionId: 's-9'));
      bridge.addIncoming(
        invite(id: 'inv-native', sessionId: 's-9', source: 'nativeCall'),
      );
      expect(bridge.state, hasLength(1));
    });

    test('accepting clears every ringing projection for that session', () {
      final bridge = IncomingCallBridgeNotifier();
      bridge.addIncoming(invite(id: 'inv-1', sessionId: 's-1'));
      bridge.clearAccepted('s-1');
      expect(bridge.state, isEmpty);
    });

    test('a terminal event clears the projection', () {
      final bridge = IncomingCallBridgeNotifier();
      bridge.addIncoming(invite(id: 'inv-1', sessionId: 's-1'));
      bridge.removeBySession('s-1', reason: 'ended');
      expect(bridge.state, isEmpty);
    });

    test('a resolved invitation is not resurrected by a late delivery', () {
      // The other transport's copy can arrive after the call is already over.
      final bridge = IncomingCallBridgeNotifier();
      bridge.addIncoming(invite(id: 'inv-1', sessionId: 's-1'));
      bridge.removeBySession('s-1', reason: 'ended');
      bridge.addIncoming(
        invite(id: 'inv-late', sessionId: 's-1', source: 'nativeCall'),
      );
      expect(bridge.state, isEmpty);
    });

    test('a tombstone never suppresses a genuinely new session', () {
      // The one thing the precedence guard must not do: silence the NEXT call
      // because the previous one was answered.
      final bridge = IncomingCallBridgeNotifier();
      bridge.addIncoming(invite(id: 'inv-1', sessionId: 's-1'));
      bridge.clearAccepted('s-1');
      bridge.addIncoming(invite(id: 'inv-2', sessionId: 's-2'));
      expect(bridge.state, hasLength(1));
      expect(bridge.currentSessionIds(), contains('s-2'));
    });
  });

  group('which conversation the call belongs to', () {
    test('projects into the conversation it belongs to', () {
      final item = invite(id: 'i', sessionId: 's', correspondenceId: 'conv-1');
      expect(conversationIncomingCall([item], 'conv-1'), isNotNull);
    });

    test('does not project into any other conversation', () {
      final item = invite(id: 'i', sessionId: 's', correspondenceId: 'conv-1');
      expect(conversationIncomingCall([item], 'conv-2'), isNull);
    });

    test('the legacy threadId identifier still matches', () {
      final item = invite(id: 'i', sessionId: 's', threadId: 'conv-7');
      expect(conversationIncomingCall([item], 'conv-7'), isNotNull);
    });

    test('an invitation with no conversation identity projects nowhere', () {
      // A call that cannot name its conversation must not be guessed into one.
      final item = invite(id: 'i', sessionId: 's');
      expect(conversationIncomingCall([item], 'conv-1'), isNull);
    });

    test('the caller name is never used to match a conversation', () {
      final item = invite(
        id: 'i',
        sessionId: 's',
        correspondenceId: 'conv-1',
        caller: 'conv-2',
      );
      expect(conversationIncomingCall([item], 'conv-2'), isNull);
    });

    test('an expired invitation is not projected', () {
      final item = invite(
        id: 'i',
        sessionId: 's',
        correspondenceId: 'conv-1',
        expiresAt: '2020-01-01T00:00:00Z',
      );
      expect(conversationIncomingCall([item], 'conv-1'), isNull);
    });

    test('the call you are already in is not re-offered', () {
      final item = invite(id: 'i', sessionId: 's-1', correspondenceId: 'c-1');
      expect(
        conversationIncomingCall([item], 'c-1', joinedSessionId: 's-1'),
        isNull,
      );
      // A DIFFERENT session still surfaces — switching calls is the person's
      // decision to make, not one to hide from them.
      expect(
        conversationIncomingCall([item], 'c-1', joinedSessionId: 's-other'),
        isNotNull,
      );
    });
  });
}
