import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../correspondence/data/correspondence_live_service.dart';
import '../realtime/application/incoming_call_projection.dart';
import '../realtime/application/realtime_providers.dart';

final incomingCallBridgeProvider =
    StateNotifierProvider<
      IncomingCallBridgeNotifier,
      List<Map<String, dynamic>>
    >((ref) {
      final notifier = IncomingCallBridgeNotifier();

      // C4+C6: listen on BOTH the correspondence-namespace socket AND the
      // /realtime-namespace socket. Either transport can deliver an incoming
      // call or a terminal event; subscribing to both means the overlay never
      // misses a session end while a poll item lingers, and removes the
      // split-state hazard where one socket fires `call:terminal` and the
      // other doesn't. The notifier already dedupes by sessionId, so both
      // sources can fire without producing duplicate cards.
      final correspondenceService = ref.watch(
        correspondenceLiveServiceProvider,
      );
      final correspondenceSub = correspondenceService.events.listen((event) {
        // Realtime Architecture Correction — Phase 4. Both socket sources'
        // event names are routed through the ONE projection authority
        // (incoming_call_projection.dart) instead of each maintaining its
        // own ad-hoc name list — a duplicate-delivery-safe, canonical- and
        // legacy-name-aware mapping.
        final intent = projectCallPresentationEvent(event.name);
        if (intent == CallPresentationIntent.show) {
          notifier.addIncoming(event.payload);
        } else if (intent == CallPresentationIntent.clear) {
          final sid = _str(event.payload['sessionId']);
          if (sid.isNotEmpty) notifier.removeBySession(sid);
        } else if (event.name == 'socket:connected') {
          // R4 — Socket reconnect fallback. Terminal events fired while
          // this socket was disconnected are not replayed, so a ringing
          // card can linger up to the 90s TTL. Sweeping expired entries
          // on every reconnect closes that window without waiting for
          // app-resume. Idempotent — re-running the sweep on a clean
          // bridge is a no-op.
          notifier.evictExpired();
        }
      });

      final realtimeSocket = ref.watch(realtimeSocketServiceProvider);
      final realtimeSub = realtimeSocket.events.listen((event) {
        final intent = projectCallPresentationEvent(event.name);
        if (intent == CallPresentationIntent.show) {
          notifier.addIncoming(event.payload);
        } else if (intent == CallPresentationIntent.clear) {
          final sid = _str(event.payload['sessionId']);
          if (sid.isNotEmpty) notifier.removeBySession(sid);
        }
      });

      ref.onDispose(() {
        correspondenceSub.cancel();
        realtimeSub.cancel();
      });
      return notifier;
    });

class IncomingCallBridgeNotifier
    extends StateNotifier<List<Map<String, dynamic>>> {
  IncomingCallBridgeNotifier() : super(const <Map<String, dynamic>>[]);

  // Realtime Architecture Correction — Phase 4, Part G. Session-scoped
  // precedence: once a session has been authoritatively cleared, a late or
  // reordered SHOW delivery for that exact session must not resurrect it —
  // see incoming_call_projection.dart's doc comment.
  final IncomingCallPrecedenceGuard _guard = IncomingCallPrecedenceGuard();

  void addIncoming(Map<String, dynamic> payload) {
    final normalized = _normalizeIncomingPayload(payload);
    final id = _str(normalized['id']);
    if (id.isEmpty) return;

    // Suppress stale invites: if expiresAt is in the past, don't add to state.
    final data = normalized['data'];
    if (data is Map) {
      final expiresAtStr = _str(data['expiresAt']);
      if (expiresAtStr.isNotEmpty) {
        final expiresAt = DateTime.tryParse(expiresAtStr);
        if (expiresAt != null && expiresAt.isBefore(DateTime.now().toUtc())) {
          return;
        }
      }
    }

    final sessionId = data is Map ? _str(data['sessionId']) : '';
    if (sessionId.isNotEmpty && !_guard.shouldShow(sessionId)) {
      // A terminal/non-actionable truth already arrived for this exact
      // session — this SHOW is a late/reordered/duplicate delivery.
      return;
    }

    // Dedup by both notification ID and session ID so two pushes for the same
    // session (e.g. delivery retry on a different notification ID) don't produce
    // two ring cards stacked on top of each other.
    state = [
      normalized,
      ...state.where((item) {
        if (_str(item['id']) == id) return false;
        if (sessionId.isNotEmpty) {
          final itemData = item['data'];
          if (itemData is Map && _str(itemData['sessionId']) == sessionId) {
            return false;
          }
        }
        return true;
      }),
    ];
  }

  void _onSessionTerminated(String sessionId) {
    _guard.recordClear(sessionId);
    final next = state.where((item) {
      final data = item['data'];
      final sid = data is Map ? _str(data['sessionId']) : '';
      return sid != sessionId;
    }).toList();
    if (next.length != state.length) state = next;
  }

  void remove(String id) {
    if (id.isEmpty) return;
    // Local-timeout/accept/decline/dismiss removal — tombstone the
    // associated session too (Part G), so this presentation-side decision
    // gets the same precedence protection as a remote terminal event.
    for (final item in state) {
      if (_str(item['id']) != id) continue;
      final data = item['data'];
      final sid = data is Map ? _str(data['sessionId']) : '';
      if (sid.isNotEmpty) _guard.recordClear(sid);
      break;
    }
    state = state.where((item) => _str(item['id']) != id).toList();
  }

  /// Public alias for [_onSessionTerminated] — used by app-resume
  /// reconciliation to evict entries whose session has been resolved
  /// (accepted on another device, expired, or ended) while this client was
  /// backgrounded and missed the corresponding socket terminal event.
  ///
  /// Without this, a ringing card would remain on screen for up to ~90s
  /// after a peer device answered, because the socket [call:terminal] was
  /// emitted while this client's socket was disconnected and is not
  /// replayed on reconnect.
  void removeBySession(String sessionId) {
    final trimmed = sessionId.trim();
    if (trimmed.isEmpty) return;
    _onSessionTerminated(trimmed);
  }

  /// Snapshot of the current ringing sessionIds. Used by resume
  /// reconciliation to know which sessions to query, without forcing the
  /// caller to walk the payload shape themselves.
  Set<String> currentSessionIds() {
    final ids = <String>{};
    for (final item in state) {
      final data = item['data'];
      final sid = data is Map ? _str(data['sessionId']) : '';
      if (sid.isNotEmpty) ids.add(sid);
    }
    return ids;
  }

  /// R4 — Evict every card whose `data.expiresAt` is in the past. The
  /// overlay also gates rendering by `expiresAt`, but the underlying
  /// state still holds the entry until [_onSessionTerminated] fires or
  /// the user manually dismisses. On socket reconnect a terminal event
  /// may have been missed; rather than waiting for the local TTL we
  /// drop any entry whose ring window already closed. Items with no
  /// `expiresAt` are left alone — we have no time signal to evict them
  /// on.
  void evictExpired() {
    if (state.isEmpty) return;
    final now = DateTime.now().toUtc();
    final next = state.where((item) {
      final data = item['data'];
      if (data is! Map) return true;
      final expiresAtStr = _str(data['expiresAt']);
      if (expiresAtStr.isEmpty) return true;
      final expiresAt = DateTime.tryParse(expiresAtStr);
      if (expiresAt == null) return true;
      final stillValid = expiresAt.isAfter(now);
      if (!stillValid) {
        final sid = _str(data['sessionId']);
        if (sid.isNotEmpty) _guard.recordClear(sid);
      }
      return stillValid;
    }).toList();
    if (next.length != state.length) state = next;
  }

  /// Drop every pending incoming-call card and reset the notifier.
  ///
  /// The provider is a long-lived `StateNotifierProvider` (no
  /// auto-dispose), so without this method any ring payloads that were
  /// in flight when the user signed out would remain in memory and could
  /// surface as a stale ring for the next user signing in on the same
  /// tab. Called from the auth-drop teardown in `aura_app.dart` so each
  /// identity gets a clean slate.
  void clear() {
    _guard.reset();
    if (state.isEmpty) return;
    state = const <Map<String, dynamic>>[];
  }

  Map<String, dynamic> _normalizeIncomingPayload(Map<String, dynamic> payload) {
    final next = Map<String, dynamic>.from(payload);
    final rawData = next['data'];
    final data = rawData is Map
        ? Map<String, dynamic>.from(rawData)
        : <String, dynamic>{};

    for (final key in const <String>[
      'sessionId',
      'realtimeSessionId',
      'threadId',
      'spaceId',
      'attention',
      'notificationKind',
      'canonicalNotificationKind',
      'callKind',
      'mediaMode',
      'expiresAt',
      'deeplink',
      'route',
      // CALLER IDENTITY — measured, 2026-08-25.
      //
      // Two payload shapes reach the incoming-call surface and they disagree
      // about where the caller lives. Logged from a physical Pixel:
      //
      //   socket: topKeys=[id, notificationKind, actor, data]
      //           actor.displayName="M S Bajwa"
      //
      //   push:   topKeys=[..., callerDisplayName, callerHandle,
      //                    callerAvatarUrl, title, body, ..., data]
      //           actorKeys=[]            <- no actor block at all
      //           data.callerDisplayName=null
      //
      // The push payload DOES carry the caller — flat, at the top level,
      // beside `title` and `body` — but it has no `actor` block and nothing
      // under `data`. So a push-delivered ring reached a card that reads
      // `item['actor']` with nothing to read, and announced "Someone".
      'callerUserId',
      'callerDisplayName',
      'callerHandle',
      'callerAvatarUrl',
    ]) {
      final value = next[key];
      if (_str(data[key]).isEmpty && _str(value).isNotEmpty) {
        data[key] = value;
      }
    }

    // ONE CANONICAL ACTOR, WHICHEVER PIPE THE CALL CAME DOWN.
    //
    // Rather than teach every consumer to check two places, the flat caller
    // fields are folded back into the canonical `actor` envelope that
    // `AuraPersonIdentity.fromJson` already understands. Consumers keep asking
    // one question and get one answer, and no surface needs a fallback.
    //
    // The existing actor always wins — this only fills an absence.
    final existingActor = next['actor'];
    final hasActor = existingActor is Map &&
        (_str(existingActor['displayName']).isNotEmpty ||
            _str(existingActor['handle']).isNotEmpty);
    if (!hasActor) {
      final displayName = _str(data['callerDisplayName']);
      final handle = _str(data['callerHandle']);
      if (displayName.isNotEmpty || handle.isNotEmpty) {
        next['actor'] = <String, dynamic>{
          'id': _str(data['callerUserId']),
          'displayName': displayName,
          'handle': handle,
          'avatarUrl': _str(data['callerAvatarUrl']),
        };
      }
    }

    final sessionId = _str(data['sessionId']).isNotEmpty
        ? _str(data['sessionId'])
        : _str(data['realtimeSessionId']);
    if (sessionId.isNotEmpty) {
      data['sessionId'] ??= sessionId;
      data['realtimeSessionId'] ??= sessionId;
    }

    final id = _str(next['id']).isNotEmpty
        ? _str(next['id'])
        : _str(next['notificationId']).isNotEmpty
        ? _str(next['notificationId'])
        : sessionId.isNotEmpty
        ? 'call:$sessionId'
        : '';
    if (id.isNotEmpty) next['id'] = id;
    next['data'] = data;
    return next;
  }
}

String _str(dynamic value) => value == null ? '' : value.toString().trim();
