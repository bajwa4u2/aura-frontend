import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/net/dio_provider.dart';

/// The signed-in person's own choice about being listed in Aura's sitemap.
///
/// `GET|PUT /users/me/search-listing` — backed by UserSearchListingConsent
/// (founder ruling 2026-09-26: a person profile is advertised to search
/// engines only with that person's consent). There is no way to read or set
/// anyone else's.
class SearchListingRepository {
  SearchListingRepository(this._dio);
  final Dio _dio;

  Future<SearchListing> get() async {
    final res = await _dio.get('/users/me/search-listing');
    return SearchListing.fromJson(res.data);
  }

  Future<SearchListing> set({required bool listed}) async {
    final res = await _dio.put(
      '/users/me/search-listing',
      data: {'listed': listed},
    );
    return SearchListing.fromJson(res.data);
  }
}

class SearchListing {
  const SearchListing({required this.listed, this.since});

  final bool listed;
  final DateTime? since;

  factory SearchListing.fromJson(Object? raw) {
    final j = raw is Map ? raw : const {};
    // Only an explicit true is a yes. Anything the server did not clearly say
    // is read as "not listed", which is the safe default for a privacy choice.
    final listed = j['listed'] == true;
    final since = j['since'];
    return SearchListing(
      listed: listed,
      since: listed && since is String ? DateTime.tryParse(since) : null,
    );
  }
}

final searchListingRepositoryProvider = Provider<SearchListingRepository>(
  (ref) => SearchListingRepository(ref.watch(dioProvider)),
);

final searchListingProvider = FutureProvider.autoDispose<SearchListing>(
  (ref) => ref.watch(searchListingRepositoryProvider).get(),
);
