import 'package:dio/dio.dart';

/// SEARCH ACROSS THE FOUR DISCOVERY DOMAINS.
///
/// The backend has answered for People, Institutions, Spaces and Articles for
/// some time, and this client parsed three keys: users, institutions and
/// posts. Two whole domains were discarded on arrival — a person could not
/// find a Space or an Article by searching, and the Posts they got instead
/// are not a Discover domain at all.
///
/// So the shape here is the four domains, and Posts is deliberately absent.
/// Home owns ongoing discourse; Discover owns finding people, participation
/// contexts, institutions and knowledge. A fifth category on this surface
/// would put the feed back inside Discover through the search box.
class SearchResult {
  const SearchResult({
    required this.people,
    required this.institutions,
    required this.spaces,
    required this.articles,
  });

  const SearchResult.empty()
      : people = const [],
        institutions = const [],
        spaces = const [],
        articles = const [];

  final List<Map<String, dynamic>> people;
  final List<Map<String, dynamic>> institutions;
  final List<Map<String, dynamic>> spaces;
  final List<Map<String, dynamic>> articles;

  /// COMPATIBILITY ALIAS — deliberately kept, and deliberately narrow.
  ///
  /// `users` was the old name for this list. Its remaining callers are the
  /// conversation participant pickers, the realtime room and the tag
  /// suggester — all of which belong to chapters that are frozen while
  /// Discover is reconstructed. Renaming their call sites would be exactly
  /// the silent scope widening the founder ruled against, so the old name
  /// stays as a getter until those chapters are opened.
  List<Map<String, dynamic>> get users => people;

  bool get isEmpty =>
      people.isEmpty &&
      institutions.isEmpty &&
      spaces.isEmpty &&
      articles.isEmpty;

  int get total =>
      people.length + institutions.length + spaces.length + articles.length;

  /// The domains that actually answered. A domain with no hits is absent from
  /// the result rather than present-and-empty, so surfaces can render only
  /// what exists instead of four headings with three "no results" rows.
  List<SearchDomain> get answeringDomains => [
        if (people.isNotEmpty) SearchDomain.people,
        if (spaces.isNotEmpty) SearchDomain.spaces,
        if (institutions.isNotEmpty) SearchDomain.institutions,
        if (articles.isNotEmpty) SearchDomain.articles,
      ];

  List<Map<String, dynamic>> forDomain(SearchDomain domain) {
    switch (domain) {
      case SearchDomain.people:
        return people;
      case SearchDomain.spaces:
        return spaces;
      case SearchDomain.institutions:
        return institutions;
      case SearchDomain.articles:
        return articles;
    }
  }
}

/// The four domains, in Aura's public-first causal order: people first,
/// then the contexts they participate in, then institutions, then the durable
/// knowledge layer.
enum SearchDomain { people, spaces, institutions, articles }

extension SearchDomainLabel on SearchDomain {
  String get label {
    switch (this) {
      case SearchDomain.people:
        return 'People';
      case SearchDomain.spaces:
        return 'Spaces';
      case SearchDomain.institutions:
        return 'Institutions';
      case SearchDomain.articles:
        return 'Articles';
    }
  }
}

class SearchRepository {
  SearchRepository(this._dio);
  final Dio _dio;

  Future<SearchResult> search(String q, {int limit = 12}) async {
    final query = q.trim();
    if (query.isEmpty) return const SearchResult.empty();

    final res = await _dio.get(
      '/search',
      queryParameters: {'q': query, 'limit': limit},
    );

    // The envelope has been both `{...}` and `{data: {...}}` across versions;
    // read either rather than depending on which one this deploy returns.
    final root = res.data;
    Map<String, dynamic> body = const {};
    if (root is Map) {
      body = Map<String, dynamic>.from(root);
      final data = body['data'];
      if (data is Map) {
        body = {...Map<String, dynamic>.from(data), ...body};
      }
    }

    List<Map<String, dynamic>> listOf(String key) {
      final raw = body[key];
      if (raw is! List) return const [];
      return raw
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }

    return SearchResult(
      people: listOf('users'),
      institutions: listOf('institutions'),
      spaces: listOf('spaces'),
      articles: listOf('articles'),
    );
  }
}
