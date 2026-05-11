import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/session_providers.dart';
import '../../../core/net/dio_provider.dart';

/// Identifies the actor that is performing a Like / asking for like-state.
///
/// This mirrors the backend `ReactionActor`: `actorInstitutionId` is set when
/// the user is interacting on behalf of an institution they speak for; left
/// null for personal-user actor.
class ReactionActor {
  const ReactionActor.user() : actorInstitutionId = null;
  const ReactionActor.institution(String id) : actorInstitutionId = id;

  final String? actorInstitutionId;

  bool get isInstitution =>
      actorInstitutionId != null && actorInstitutionId!.trim().isNotEmpty;

  @override
  bool operator ==(Object other) =>
      other is ReactionActor &&
      other.actorInstitutionId == actorInstitutionId;

  @override
  int get hashCode => actorInstitutionId.hashCode;
}

/// Identifies what the reaction is being applied to.
///
/// `Post` (the global content table) and `InstitutionPost` (the institution
/// workspace content table) are different storage so the API path differs.
/// Wrapping them in one type keeps the widget code uniform.
sealed class ReactionTarget {
  const ReactionTarget();

  String get postId;

  /// Optional feed-institution context. Required for institution-post
  /// targets (the path includes the feed's institution id) and ignored for
  /// regular posts.
  String? get feedInstitutionId => null;

  String get cacheKey;

  @override
  bool operator ==(Object other) =>
      other is ReactionTarget && other.cacheKey == cacheKey;

  @override
  int get hashCode => cacheKey.hashCode;
}

class PostReactionTarget extends ReactionTarget {
  const PostReactionTarget(this._postId);
  final String _postId;
  @override
  String get postId => _postId;
  @override
  String get cacheKey => 'post:$_postId';
}

class InstitutionPostReactionTarget extends ReactionTarget {
  const InstitutionPostReactionTarget({
    required this.institutionId,
    required String postId,
  }) : _postId = postId;
  final String institutionId;
  final String _postId;
  @override
  String get postId => _postId;
  @override
  String? get feedInstitutionId => institutionId;
  @override
  String get cacheKey => 'inst:$institutionId/post:$_postId';
}

/// Snapshot of an actor's like state for a target + total like count.
class ReactionState {
  const ReactionState({required this.liked, required this.likeCount});

  final bool liked;
  final int likeCount;

  ReactionState copyWith({bool? liked, int? likeCount}) => ReactionState(
        liked: liked ?? this.liked,
        likeCount: likeCount ?? this.likeCount,
      );
}

class ReactionsRepository {
  ReactionsRepository(this._dio);

  final Dio _dio;

  String _statePath(ReactionTarget target) {
    if (target is InstitutionPostReactionTarget) {
      return '/institutions/${target.institutionId}'
          '/posts/${target.postId}/reactions/state';
    }
    return '/reactions/${target.postId}/state';
  }

  String _togglePath(ReactionTarget target) {
    if (target is InstitutionPostReactionTarget) {
      return '/institutions/${target.institutionId}'
          '/posts/${target.postId}/reactions/toggle';
    }
    return '/reactions/${target.postId}/toggle';
  }

  /// Reads the actor's like state and the total like count.
  /// `actor` defaults to the personal user.
  Future<ReactionState> getState(
    ReactionTarget target, {
    ReactionActor actor = const ReactionActor.user(),
  }) async {
    final pid = target.postId.trim();
    if (pid.isEmpty) {
      return const ReactionState(liked: false, likeCount: 0);
    }
    final query = <String, dynamic>{};
    if (actor.isInstitution) {
      query['actor'] = 'institution';
      query['institutionId'] = actor.actorInstitutionId;
    }
    final res = await _dio.get(
      _statePath(target),
      queryParameters: query.isEmpty ? null : query,
    );
    return _decode(res.data);
  }

  /// Toggles the actor's Like and returns the new state + count.
  Future<ReactionState> toggle(
    ReactionTarget target, {
    ReactionActor actor = const ReactionActor.user(),
  }) async {
    final pid = target.postId.trim();
    if (pid.isEmpty) {
      return const ReactionState(liked: false, likeCount: 0);
    }
    final body = <String, dynamic>{
      'actorType': actor.isInstitution ? 'INSTITUTION' : 'USER',
      if (actor.isInstitution)
        'actorInstitutionId': actor.actorInstitutionId,
    };
    final res = await _dio.post(
      _togglePath(target),
      data: body,
    );
    return _decode(res.data);
  }

  ReactionState _decode(dynamic raw) {
    if (raw is! Map) return const ReactionState(liked: false, likeCount: 0);
    final m = Map<String, dynamic>.from(raw);
    bool liked = false;
    final l = m['liked'];
    if (l is bool) {
      liked = l;
    } else if (l is num) {
      liked = l != 0;
    } else if (l is String) {
      liked = l.toLowerCase() == 'true' || l == '1';
    }
    int likeCount = 0;
    final c = m['likeCount'];
    if (c is num) {
      likeCount = c.toInt();
    } else if (c is String) {
      likeCount = int.tryParse(c) ?? 0;
    }
    return ReactionState(liked: liked, likeCount: likeCount);
  }
}

final reactionsRepositoryProvider = Provider<ReactionsRepository>(
  (ref) => ReactionsRepository(ref.read(dioProvider)),
);

/// Family key combining target + actor so user-state and institution-state
/// are cached separately, and Post vs InstitutionPost lookups don't collide.
class ReactionStateKey {
  const ReactionStateKey({required this.target, required this.actor});

  final ReactionTarget target;
  final ReactionActor actor;

  @override
  bool operator ==(Object other) =>
      other is ReactionStateKey &&
      other.target == target &&
      other.actor == actor;

  @override
  int get hashCode => Object.hash(target, actor);
}

final reactionStateProvider = FutureProvider.autoDispose
    .family<ReactionState, ReactionStateKey>((ref, key) async {
  // Viewer-state endpoint is auth-gated. For signed-out visitors on public
  // surfaces (homepage, public feed, institution detail) we MUST NOT call
  // /reactions/.../state — it returns 401 noisily. The public payload still
  // carries the global like count via FeedInteraction.likeCount, which the
  // interaction bar reads when no per-actor state is available. The boolean
  // "liked" is correct as `false` for a signed-out viewer.
  final authed = ref.watch(isAuthedProvider);
  if (!authed) {
    return const ReactionState(liked: false, likeCount: 0);
  }
  final repo = ref.read(reactionsRepositoryProvider);
  return repo.getState(key.target, actor: key.actor);
});
