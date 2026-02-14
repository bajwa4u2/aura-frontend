import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/net/dio_provider.dart';
import '../../core/auth/session_providers.dart';
import 'saves_repository.dart';
import '../feed/domain/post.dart';

final savesRepositoryProvider = Provider<SavesRepository>((ref) {
  return SavesRepository(ref.watch(dioProvider));
});

final savedPostsProvider = FutureProvider<List<Post>>((ref) async {
  final authed = ref.watch(isAuthedProvider);
  if (!authed) return const <Post>[];

  final repo = ref.watch(savesRepositoryProvider);
  return repo.listSaved(limit: 12);
});
