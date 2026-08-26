import 'package:flutter/foundation.dart';

import '../identity/person_identity_model.dart';

/// WHO IS IN THIS CALL — one model, every product.
///
/// Founder ruling, *Call Presentation Authority* §7. The measured problem is
/// that a thread room (3,783 lines) and a meeting room (3,685 lines) answer
/// "who is here" independently, sharing almost nothing, and disagree in ways
/// that reached production: one human rendered twice, a caller announced as
/// "Someone", a portrait tile letterboxed beside a landscape one.
///
/// ## What this deliberately separates
///
/// The A/V chapter's defects all came from conflating things that merely
/// travel together. This model keeps them apart:
///
/// * **identity** — which human this is. Stable across devices, transports and
///   reconnects.
/// * **session participation** — their seat in this call: invited, joined,
///   left. Owned by the session, not by a socket.
/// * **transport presence** — which device/connection is currently carrying
///   them. Replaceable without their seat changing.
/// * **media state** — what their microphone and camera are doing.
/// * **product role** — host, organiser, guest. Meaningful only where the
///   enclosing product says it is.
/// * **acting authority** — a person may act as themselves or on behalf of an
///   institution. That is a different question from who they are.
///
/// Conflating identity with transport is what produced a third participant on
/// re-join. Conflating identity with acting authority is what would make an
/// institution look like an anonymous account.
@immutable
class CallParticipant {
  const CallParticipant({
    required this.identity,
    required this.seatId,
    this.transportId,
    this.isSelf = false,
    this.participation = CallParticipation.joined,
    this.media = const CallMediaState(),
    this.role = CallRole.participant,
    this.actingAs,
    this.isGuest = false,
  });

  /// The human. [AuraPersonIdentity.unknown] for a guest with no account.
  final AuraPersonIdentity identity;

  /// THE SEAT — what makes two entries the same participant.
  ///
  /// Derived once, by [callSeatId], from the strongest identifier available:
  /// the canonical user, else the session participant row, else the transport.
  /// A new device for the same person keeps the same seat; two guests never
  /// share one.
  final String seatId;

  /// The connection currently carrying this participant, when known. Changing
  /// this must never create a second seat.
  final String? transportId;

  final bool isSelf;
  final CallParticipation participation;
  final CallMediaState media;
  final CallRole role;

  /// The institution this person is acting for, when they are not acting as
  /// themselves. Presentation must show the person AND the authority — never
  /// replace one with the other.
  final String? actingAs;

  /// A participant with no Aura account. Never collapsed with another guest,
  /// and never given invented identity.
  final bool isGuest;

  /// The name to show. Falls through to the neutral word only when nothing is
  /// known, which is honest rather than a defect — see the A/V chapter, where
  /// the bug was reaching this state with identity still unread upstream.
  String get displayName => identity.label;

  bool get isPresent =>
      participation == CallParticipation.joined ||
      participation == CallParticipation.reconnecting;

  CallParticipant copyWith({
    AuraPersonIdentity? identity,
    String? transportId,
    bool? isSelf,
    CallParticipation? participation,
    CallMediaState? media,
    CallRole? role,
    String? actingAs,
    bool? isGuest,
  }) =>
      CallParticipant(
        identity: identity ?? this.identity,
        seatId: seatId,
        transportId: transportId ?? this.transportId,
        isSelf: isSelf ?? this.isSelf,
        participation: participation ?? this.participation,
        media: media ?? this.media,
        role: role ?? this.role,
        actingAs: actingAs ?? this.actingAs,
        isGuest: isGuest ?? this.isGuest,
      );

  @override
  String toString() =>
      'CallParticipant(seat=$seatId, ${identity.label}, $participation, $media)';
}

/// Where someone is in their relationship to this call.
///
/// Deliberately NOT the transport's connection state: a person is still a
/// participant while their socket is reconnecting, and the room must keep
/// saying who they are rather than blanking them.
enum CallParticipation { invited, ringing, joining, joined, reconnecting, left }

/// What a participant's devices are doing.
@immutable
class CallMediaState {
  const CallMediaState({
    this.microphoneOn = false,
    this.cameraOn = false,
    this.screenSharing = false,
    this.hasVideoFrames = false,
  });

  final bool microphoneOn;
  final bool cameraOn;
  final bool screenSharing;

  /// Whether video is actually arriving, as opposed to merely being enabled.
  /// A tile that trusts `cameraOn` alone shows a black rectangle and calls it
  /// video.
  final bool hasVideoFrames;

  @override
  String toString() =>
      'mic=$microphoneOn cam=$cameraOn screen=$screenSharing frames=$hasVideoFrames';
}

/// Product role. Only meaningful where the enclosing product gives it meaning —
/// a thread call has no organiser.
enum CallRole { host, moderator, participant, guest, observer }

/// THE ONE RULE THAT DECIDES WHETHER TWO ENTRIES ARE THE SAME PARTICIPANT.
///
/// Ordered by how strongly each identifier binds to a *human*:
///
/// 1. **canonical user id** — the same person on any device or transport;
/// 2. **session participant row** — a guest's seat in this session, stable for
///    as long as they are in it;
/// 3. **transport id** — last resort, and the weakest: it changes on
///    reconnect, which is exactly how a re-join grew a third participant.
///
/// Returning an empty string means nothing identifies this entry at all. A
/// caller must then keep it rather than merge it, because merging unidentified
/// entries silently combines strangers.
String callSeatId({
  String? userId,
  String? participantRowId,
  String? transportId,
}) {
  final user = (userId ?? '').trim();
  if (user.isNotEmpty) return 'user:$user';
  final row = (participantRowId ?? '').trim();
  if (row.isNotEmpty) return 'seat:$row';
  final transport = (transportId ?? '').trim();
  if (transport.isNotEmpty) return 'transport:$transport';
  return '';
}
