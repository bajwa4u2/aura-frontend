import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../net/dio_provider.dart';
import 'actor_context.dart';

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
    final m = Map<String, dynamic>.from(raw);
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
    final body = <String, dynamic>{
      ...actor.toFields('actor'),
      ...target.toFields('target'),
    };
    final res = await _dio.delete('/follows', data: body);
    return FollowState.fromJson(res.data);
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
  final repo = ref.read(followsRepositoryProvider);
  return repo.getState(actor: key.actor, target: key.target);
});
