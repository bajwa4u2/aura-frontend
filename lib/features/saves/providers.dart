import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/session_providers.dart';
import '../../core/net/dio_provider.dart';

final savedPostsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final authed = ref.watch(isAuthedProvider);
  if (!authed) return const <Map<String, dynamic>>[];

  final dio = ref.watch(dioProvider);
  final res = await dio.get('/saves');

  final data = res.data;
  if (data is Map) {
    final m = Map<String, dynamic>.from(data);
    final items = (m['data'] ?? m['items']);
    if (items is List) {
      return items
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
  }

  if (data is List) {
    return data
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  return const <Map<String, dynamic>>[];
});