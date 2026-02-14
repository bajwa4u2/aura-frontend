import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/net/dio_provider.dart';
import 'data/profile_repository.dart';
import 'domain/profile.dart';

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  final dio = ref.watch(dioProvider);
  return ProfileRepository(dio);
});

final profileControllerProvider =
    StateNotifierProvider.family<ProfileController, ProfileState, String>(
  (ref, handle) {
    final repo = ref.watch(profileRepositoryProvider);
    return ProfileController(repo, handle);
  },
);

class ProfileState {
  ProfileState({
    required this.profile,
    required this.loading,
    required this.error,
  });

  final Profile? profile;
  final bool loading;
  final Object? error;

  factory ProfileState.loading() =>
      ProfileState(profile: null, loading: true, error: null);

  ProfileState copyWith({
    Profile? profile,
    bool? loading,
    Object? error,
  }) {
    return ProfileState(
      profile: profile ?? this.profile,
      loading: loading ?? this.loading,
      error: error,
    );
  }
}

class ProfileController extends StateNotifier<ProfileState> {
  ProfileController(this._repo, this.handle)
      : super(ProfileState.loading()) {
    load();
  }

  final ProfileRepository _repo;
  final String handle;

  Future<void> load() async {
    state = ProfileState.loading();
    try {
      final p = await _repo.fetchProfile(handle);
      state = state.copyWith(profile: p, loading: false);
    } catch (e) {
      state = state.copyWith(loading: false, error: e);
    }
  }

  Future<void> toggleFollow() async {
    final p = state.profile;
    if (p == null) return;

    try {
      if (p.isFollowing) {
        await _repo.unfollow(handle);
        state = state.copyWith(
          profile: Profile(
            id: p.id,
            handle: p.handle,
            displayName: p.displayName,
            bio: p.bio,
            avatarUrl: p.avatarUrl,
            followersCount: p.followersCount - 1,
            followingCount: p.followingCount,
            isFollowing: false,
          ),
        );
      } else {
        await _repo.follow(handle);
        state = state.copyWith(
          profile: Profile(
            id: p.id,
            handle: p.handle,
            displayName: p.displayName,
            bio: p.bio,
            avatarUrl: p.avatarUrl,
            followersCount: p.followersCount + 1,
            followingCount: p.followingCount,
            isFollowing: true,
          ),
        );
      }
    } catch (e) {
      // leave state unchanged on failure
    }
  }
}
