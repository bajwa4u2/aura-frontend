import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/net/dio_provider.dart';
import 'feed_repository.dart';
import 'post_model.dart';

final feedRepositoryProvider = Provider<FeedRepository>((ref) {
  return FeedRepository(ref.watch(dioProvider));
});

final publicPostsProvider = FutureProvider<List<Post>>((ref) async {
  return ref.watch(feedRepositoryProvider).listPublic(limit: 30);
});
