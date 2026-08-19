import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/net/dio_provider.dart';
import '../../../core/identity/person_identity_model.dart';

/// AURA ARTICLES — canonical client for the durable long-form publication
/// domain (founder addendum 2026-08-16). ARTICLE ≠ POST ≠ ANNOUNCEMENT.

class Article {
  const Article({
    required this.id,
    required this.slug,
    required this.title,
    required this.bodyMarkdown,
    required this.coverMediaId,
    required this.status,
    required this.publishedAt,
    this.author,
    this.revised = false,
  });

  final String id;
  final String? slug;
  final String title;
  final String bodyMarkdown;
  final String? coverMediaId;
  final String status; // DRAFT | PUBLISHED
  final DateTime? publishedAt;
  /// The person who wrote it — the canonical identity, not an
  /// article-local retelling of it. Null when the payload embeds no author.
  final AuraPersonIdentity? author;

  /// True when the published article has been revised (durable history
  /// preserved server-side; presentation shows an honest edited marker).
  final bool revised;

  bool get isPublished => status == 'PUBLISHED';

  factory Article.fromJson(Map<String, dynamic> json) => Article(
        id: _s(json['id']),
        slug: _ns(json['slug']),
        title: _s(json['title']),
        bodyMarkdown: _s(json['bodyMarkdown']),
        coverMediaId: _ns(json['coverMediaId']),
        status: _ns(json['status']) ?? 'PUBLISHED',
        publishedAt: json['publishedAt'] == null
            ? null
            : DateTime.tryParse(json['publishedAt'].toString()),
        author: json['author'] is Map
            ? AuraPersonIdentity.fromJson(json['author'])
            : null,
        revised: json['revised'] == true,
      );
}

class ArticlesRepository {
  ArticlesRepository(this._dio);
  final Dio _dio;

  Future<List<Article>> listPublished() async {
    final res = await _dio.get<dynamic>('/articles');
    return (_unwrap(res.data)['articles'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(Article.fromJson)
        .toList();
  }

  Future<Article> getBySlug(String slug) async {
    final res = await _dio.get<dynamic>('/articles/by-slug/$slug');
    return Article.fromJson(
        _unwrap(res.data)['article'] as Map<String, dynamic>);
  }

  Future<List<Article>> mine() async {
    final res = await _dio.get<dynamic>('/articles/mine');
    return (_unwrap(res.data)['articles'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(Article.fromJson)
        .toList();
  }

  Future<Article> createDraft() async {
    // Explicit fields: an empty map can be dropped from the wire entirely
    // on web, arriving server-side as no body at all.
    final res = await _dio.post<dynamic>('/articles',
        data: const {'title': '', 'bodyMarkdown': ''});
    return Article.fromJson(
        _unwrap(res.data)['article'] as Map<String, dynamic>);
  }

  Future<Article> getOwn(String id) async {
    final res = await _dio.get<dynamic>('/articles/mine/$id');
    return Article.fromJson(
        _unwrap(res.data)['article'] as Map<String, dynamic>);
  }

  Future<void> saveDraft(String id,
      {String? title, String? bodyMarkdown, String? coverMediaId}) async {
    await _dio.patch<dynamic>('/articles/$id', data: {
      if (title != null) 'title': title,
      if (bodyMarkdown != null) 'bodyMarkdown': bodyMarkdown,
      if (coverMediaId != null) 'coverMediaId': coverMediaId,
    });
  }

  Future<Article> publish(String id) async {
    final res = await _dio.post<dynamic>('/articles/$id/publish');
    return Article.fromJson(
        _unwrap(res.data)['article'] as Map<String, dynamic>);
  }
}

dynamic _unwrap(dynamic raw) {
  if (raw is Map<String, dynamic>) {
    if (raw['data'] is Map<String, dynamic>) return raw['data'];
    return raw;
  }
  return raw;
}

String _s(dynamic v) => v == null ? '' : v.toString();
String? _ns(dynamic v) {
  if (v == null) return null;
  final s = v.toString().trim();
  return s.isEmpty ? null : s;
}

final articlesRepositoryProvider =
    Provider<ArticlesRepository>((ref) => ArticlesRepository(ref.watch(dioProvider)));

final publishedArticlesProvider =
    FutureProvider.autoDispose<List<Article>>((ref) async {
  return ref.watch(articlesRepositoryProvider).listPublished();
});

final articleBySlugProvider =
    FutureProvider.autoDispose.family<Article, String>((ref, slug) async {
  return ref.watch(articlesRepositoryProvider).getBySlug(slug);
});
