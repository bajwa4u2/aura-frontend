import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/session_providers.dart';
import '../net/dio_provider.dart';
import 'actor_context.dart';
import '../identity/person_identity_model.dart';

/// Identifies a follow target (or actor) on the wire.
class ActorRef {
  const ActorRef.user(String id)
      : type = ActorType.user,
        userId = id,
        institutionId = null;
  const ActorRef.institution(String id)
      : type = ActorType.institution,
        userId = null,
        institutionId = id;

  final ActorType type;
  final String? userId;
  final String? institutionId;

  String get id => type == ActorType.user
      ? (userId ?? '')
      : (institutionId ?? '');

  /// Stable cache key that uniquely identifies this actor in family providers.
  String get cacheKey =>
      type == ActorType.user ? 'U:${userId ?? ""}' : 'I:${institutionId ?? ""}';

  Map<String, dynamic> toFields(String prefix) => <String, dynamic>{
        '${prefix}Type': type == ActorType.user ? 'USER' : 'INSTITUTION',
        if (type == ActorType.user) '${prefix}UserId': userId,
        if (type == ActorType.institution)
          '${prefix}InstitutionId': institutionId,
      };

  Map<String, String> toQuery(String prefix) {
    final m = <String, String>{};
    m['${prefix}Type'] = type == ActorType.user ? 'USER' : 'INSTITUTION';
    if (type == ActorType.user && userId != null) {
      m['${prefix}UserId'] = userId!;
    }
    if (type == ActorType.institution && institutionId != null) {
      m['${prefix}InstitutionId'] = institutionId!;
    }
    return m;
  }

  @override
  bool operator ==(Object other) =>
      other is ActorRef &&
      other.type == type &&
      other.userId == userId &&
      other.institutionId == institutionId;

  @override
  int get hashCode => Object.hash(type, userId, institutionId);

  /// Stable, human-readable identifier used by RuntimeTrace and any
  /// `debugPrint` call site. Mirrors `cacheKey` so the trace line and
  /// the family-provider cache key for the same actor are textually
  /// identical — easy to grep across both surfaces.
  @override
  String toString() => cacheKey;
}

/// Wire shape returned by `/v1/follows/...` endpoints.
class FollowState {
  const FollowState({
    required this.following,
    required this.status,
    required this.canMessage,
  });

  final bool following;

  /// 'NONE' | 'FOLLOWING' | 'REQUESTED' | 'BLOCKED'
  final String status;

  final bool canMessage;

  bool get isFollowing => status.toUpperCase() == 'FOLLOWING';
  bool get isPending => status.toUpperCase() == 'REQUESTED';
  bool get isBlocked => status.toUpperCase() == 'BLOCKED';

  static const empty =
      FollowState(following: false, status: 'NONE', canMessage: false);

  factory FollowState.fromJson(dynamic raw) {
    if (raw is! Map) return empty;
    var m = Map<String, dynamic>.from(raw);
    // Backend serves every response through ResponseWrapInterceptor,
    // which produces `{ ok: true, data: <payload> }`. Without this
    // unwrap, top-level reads of `following` / `status` / `canMessage`
    // are all null — the parser collapses to `FollowState.empty`, the
    // button never shows "Following" no matter how many times the user
    // taps, and the state probe never reflects the row that DID get
    // persisted. The unwrap also tolerates a raw (un-wrapped) shape so
    // direct service calls keep working.
    final inner = m['data'];
    if (inner is Map) {
      m = Map<String, dynamic>.from(inner);
    }
    final following = m['following'] == true;
    final status =
        (m['status']?.toString().trim().toUpperCase() ?? 'NONE');
    final canMessage = m['canMessage'] == true;
    return FollowState(
      following: following,
      status: status,
      canMessage: canMessage,
    );
  }
}

class FollowsRepository {
  FollowsRepository(this._dio);

  final Dio _dio;

  Future<FollowState> getState({
    required ActorRef actor,
    required ActorRef target,
  }) async {
    final query = <String, dynamic>{
      ...actor.toQuery('actor'),
      ...target.toQuery('target'),
    };
    final res = await _dio.get('/follows/state', queryParameters: query);
    return FollowState.fromJson(res.data);
  }

  Future<FollowState> follow({
    required ActorRef actor,
    required ActorRef target,
  }) async {
    final body = <String, dynamic>{
      ...actor.toFields('actor'),
      ...target.toFields('target'),
    };
    final res = await _dio.post('/follows', data: body);
    return FollowState.fromJson(res.data);
  }

  Future<FollowState> unfollow({
    required ActorRef actor,
    required ActorRef target,
  }) async {
    // DELETE is sent as query parameters, not a body. HTTP intermediaries
    // (Railway / NGINX edge, some Android HTTP stacks) do not reliably
    // forward bodies on DELETE — RFC 7231 explicitly leaves DELETE-body
    // semantics undefined. The previous body-on-DELETE shape arrived at
    // the backend with `actorType: undefined`, tripping class-validator
    // with 400 VALIDATION_ERROR and locking the Following button on
    // every device. Query parameters bypass every stripper and match
    // the controller's `@Query() FollowStateQueryDto` signature.
    final query = <String, dynamic>{
      ...actor.toQuery('actor'),
      ...target.toQuery('target'),
    };
    final res = await _dio.delete('/follows', queryParameters: query);
    return FollowState.fromJson(res.data);
  }

  // ── Person→Person consent lifecycle ────────────────────────────────────
  //
  // C2 closeout — the canonical Follow client boundary now carries the
  // consent operations too, so no screen owns Follow transport directly.
  // Semantics are the backend CanonicalFollowService's frozen model:
  // request → accept/decline, REJECTED persists (cooldown anchor),
  // BLOCK > CONSENT > FOLLOW, rejection stays silent.

  static List<PersonFollowRequest> _parseRequestList(dynamic raw) {
    Map<String, dynamic> asMap(dynamic v) {
      if (v is Map<String, dynamic>) return v;
      if (v is Map) return Map<String, dynamic>.from(v);
      return <String, dynamic>{};
    }

    final root = asMap(raw);
    dynamic items = root['items'];
    if (items == null && root['data'] is Map) {
      items = asMap(root['data'])['items'];
    }
    if (items is! List) return const [];
    return items
        .whereType<Map>()
        .map((e) => PersonFollowRequest.fromJson(Map<String, dynamic>.from(e)))
        .where((e) => e.id.isNotEmpty)
        .toList(growable: false);
  }

  /// Pending requests addressed to the signed-in person.
  Future<List<PersonFollowRequest>> incomingFollowRequests() async {
    final res = await _dio.get('/users/me/follow/requests/inbox');
    return _parseRequestList(res.data);
  }

  /// Pending requests the signed-in person has sent.
  Future<List<PersonFollowRequest>> outgoingFollowRequests() async {
    final res = await _dio.get('/users/me/follow/requests/outbox');
    return _parseRequestList(res.data);
  }

  Future<void> acceptFollowRequest(String requestId) async {
    await _dio.post('/users/me/follow/requests/$requestId/accept');
  }

  Future<void> declineFollowRequest(String requestId) async {
    await _dio.post('/users/me/follow/requests/$requestId/decline');
  }

  /// Canonical person follower/following counts, as the profile authority
  /// reports them (D4 — emitted from the canonical person-follow stores).
  /// Never derived client-side by fetching and counting whole lists.
  Future<({int followers, int following})> personFollowCounts(
    String handle,
  ) async {
    final res = await _dio.get('/users/$handle');
    final data = res.data is Map
        ? Map<String, dynamic>.from(res.data as Map)
        : const <String, dynamic>{};
    int asInt(dynamic v) =>
        v is num ? v.toInt() : int.tryParse((v ?? '').toString()) ?? 0;
    return (
      followers: asInt(data['followersCount']),
      following: asInt(data['followingCount']),
    );
  }
}

/// A pending Person→Person follow request (consent lifecycle item).
/// F116 — a follow REQUEST is relationship state that contains a requesting
/// person. The request is this model's own; the person is delegated.
class PersonFollowRequest {
  const PersonFollowRequest({
    required this.id,
    required this.createdAt,
    required this.requester,
  });

  final String id;
  final DateTime? createdAt;
  final AuraPersonIdentity requester;

  String get requesterId => requester.userId;
  String get handle => requester.handle;
  String get displayName => requester.displayName;
  String get avatarUrl => requester.avatarUrl ?? '';

  factory PersonFollowRequest.fromJson(Map<String, dynamic> json) {
    final requesterRaw = json['requester'];
    final requester = requesterRaw is Map<String, dynamic>
        ? requesterRaw
        : requesterRaw is Map
            ? Map<String, dynamic>.from(requesterRaw)
            : <String, dynamic>{};
    DateTime? createdAt;
    final createdAtRaw = (json['createdAt'] ?? '').toString().trim();
    if (createdAtRaw.isNotEmpty) createdAt = DateTime.tryParse(createdAtRaw);
    return PersonFollowRequest(
      id: (json['id'] ?? '').toString().trim(),
      createdAt: createdAt,
      requester: AuraPersonIdentity.fromJson(requester),
    );
  }
}

final followsRepositoryProvider = Provider<FollowsRepository>(
  (ref) => FollowsRepository(ref.read(dioProvider)),
);

class FollowStateKey {
  const FollowStateKey({required this.actor, required this.target});

  final ActorRef actor;
  final ActorRef target;

  @override
  bool operator ==(Object other) =>
      other is FollowStateKey &&
      other.actor == actor &&
      other.target == target;

  @override
  int get hashCode => Object.hash(actor, target);
}

final followStateProvider = FutureProvider.autoDispose
    .family<FollowState, FollowStateKey>((ref, key) async {
  // /follows/state is auth-only. On public surfaces (e.g. an unauth'd
  // visitor opening an institution detail page) we MUST short-circuit
  // to a neutral "not following / cannot message" state instead of
  // firing a guaranteed 401.
  final authed = ref.watch(isAuthedProvider);
  if (!authed) {
    return FollowState.empty;
  }
  final repo = ref.read(followsRepositoryProvider);
  return repo.getState(actor: key.actor, target: key.target);
});
