import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/net/dio_provider.dart';
import 'search_repository.dart';

final searchRepositoryProvider = Provider<SearchRepository>((ref) {
  return SearchRepository(ref.watch(dioProvider));
});

final searchQueryProvider = StateProvider<String>((ref) => '');
