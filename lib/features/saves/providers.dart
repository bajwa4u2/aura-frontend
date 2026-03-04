import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/net/dio_provider.dart';
import '../feed/domain/post.dart';
import 'saves_repository.dart';

final savesRepositoryProvider = Provider<SavesRepository>((ref) {
  return SavesRepository(ref, ref.watch(dioProvider));
});

final savedPostsProvider = FutureProvider<List<Post>>((ref) async {
  final repo = ref.watch(savesRepositoryProvider);
  return repo.listSaved(limit: 24);
});