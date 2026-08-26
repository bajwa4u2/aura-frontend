import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:aura/core/identity/person_identity_model.dart';
import 'package:aura/features/updates/incoming_call_bridge.dart';

/// TWO TRANSPORTS, ONE CANONICAL ACTOR.
///
/// **Measured on a physical Pixel, 2026-08-25.** An incoming call from a fully
/// governed identity announced itself as "Someone". Logging the actual payload
/// showed two different shapes arriving at the same surface:
///
/// ```
/// socket: topKeys=[id, notificationKind, actor, data]
///         actor.displayName="M S Bajwa"
///
/// push:   topKeys=[..., callerDisplayName, callerHandle, callerAvatarUrl,
///                  title, body, ..., data]
///         actorKeys=[]              <- no actor block at all
///         data.callerDisplayName=null
/// ```
///
/// ## Why there are two shapes
///
/// Not two designs — one canonical model with two transport encodings. The FCM
/// adapter's `normalizePayloadData` does `out[key] = String(value)`, because an
/// FCM data message is a `Record<string, string>`. A nested `actor` object
/// cannot survive that channel; it would arrive as `"[object Object]"`. So the
/// push builder flattens the caller to top-level fields, while a socket frame —
/// arbitrary JSON — keeps the structured envelope.
///
/// The defect was that the bridge that exists to reconcile the two shapes
/// reconciled the CALL-STATE keys and not the IDENTITY keys, so a
/// push-delivered ring reached a card reading `item['actor']` with nothing in
/// it.
///
/// The reconciliation now happens once, here, so no surface needs a fallback
/// and no consumer has to know which pipe a call came down.
void main() {
  // The bridge reaches shared_preferences on construction; the in-memory
  // stub keeps this a pure test of payload reconciliation.
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  IncomingCallBridgeNotifier bridge() =>
      ProviderContainer().read(incomingCallBridgeProvider.notifier);

  group('the push shape yields a canonical actor', () {
    test('flat caller fields are folded into the actor envelope', () {
      final b = bridge();
      b.addIncoming(<String, dynamic>{
        'id': 'call:s1',
        'sessionId': 's1',
        'attention': 'INTERRUPT',
        'notificationKind': 'LIVE_CALL_RINGING',
        'callKind': 'VIDEO',
        // Flat, exactly as FCM delivers it — no actor, nothing under `data`.
        'callerUserId': 'u-bajwa',
        'callerDisplayName': 'M S Bajwa',
        'callerHandle': 'bajwawrites',
        'callerAvatarUrl': 'https://example.test/a.jpg',
      });

      final item = b.state.single;
      final person = AuraPersonIdentity.fromJson(item['actor']);

      expect(person.label, 'M S Bajwa',
          reason: 'a push-delivered ring still announces "Someone"');
      expect(person.handle, 'bajwawrites');
      expect(person.avatarUrl, 'https://example.test/a.jpg',
          reason: 'the real photo is replaced by an initial letter');
      expect(person.userId, 'u-bajwa');
    });

    test('the caller also reaches `data`, for consumers that read it there',
        () {
      final b = bridge();
      b.addIncoming(<String, dynamic>{
        'id': 'call:s2',
        'sessionId': 's2',
        'attention': 'INTERRUPT',
        'notificationKind': 'LIVE_CALL_RINGING',
        'callerDisplayName': 'M S Bajwa',
      });
      final data = b.state.single['data'] as Map<String, dynamic>;
      expect(data['callerDisplayName'], 'M S Bajwa');
    });
  });

  group('the socket shape is left exactly as it is', () {
    test('an existing actor is never overwritten', () {
      final b = bridge();
      b.addIncoming(<String, dynamic>{
        'id': 'call:s3',
        'notificationKind': 'LIVE_CALL_RINGING',
        'actor': <String, dynamic>{
          'id': 'u-bajwa',
          'displayName': 'M S Bajwa',
          'handle': 'bajwawrites',
        },
        'data': <String, dynamic>{
          'sessionId': 's3',
          'attention': 'INTERRUPT',
          // A disagreeing flat value must NOT win over the canonical actor.
          'callerDisplayName': 'Someone Else',
        },
      });

      final person = AuraPersonIdentity.fromJson(b.state.single['actor']);
      expect(person.label, 'M S Bajwa',
          reason: 'the flat fallback overrode the canonical actor');
    });
  });

  group('nothing is invented', () {
    test('a payload with no caller at all grows no actor', () {
      final b = bridge();
      b.addIncoming(<String, dynamic>{
        'id': 'call:s4',
        'sessionId': 's4',
        'attention': 'INTERRUPT',
        'notificationKind': 'LIVE_CALL_RINGING',
      });
      final actor = b.state.single['actor'];
      expect(actor == null || (actor as Map).isEmpty, isTrue,
          reason: 'an empty actor envelope was fabricated from nothing');
      // And the honest neutral word is still what renders.
      expect(AuraPersonIdentity.fromJson(actor).label, 'Someone');
    });
  });
}
