
import 'package:dio/dio.dart';

import '../domain/announcement.dart';

class AnnouncementsRepository {
  AnnouncementsRepository(this._dio);

  final Dio _dio;

  List<Announcement>? _cachedList;
  List<Announcement>? _cachedPinned;

  DateTime? _listFetchedAt;
  DateTime? _pinnedFetchedAt;

  Future<List<Announcement>>? _listInFlight;
  Future<List<Announcement>>? _pinnedInFlight;

  static const _ttl = Duration(seconds: 30);

  bool _isFresh(DateTime? t) {
    if (t == null) return false;
    return DateTime.now().difference(t) < _ttl;
  }

  Map<String, dynamic> _asMap(dynamic v) {
    if (v is Map<String, dynamic>) return v;
    if (v is Map) return Map<String, dynamic>.from(v);
    return {};
  }

  List<Map<String, dynamic>> _asList(dynamic v) {
    if (v is List) {
      return v.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    }
    return [];
  }

  Map<String, dynamic> _unwrapMap(dynamic raw) {
    final root = _asMap(raw);

    dynamic inner = root;

    if (inner.containsKey('ok') && inner.containsKey('data')) {
      inner = inner['data'];
    }

    if (inner is Map && inner['data'] is Map) {
      inner = inner['data'];
    }

    if (inner is Map && inner['item'] is Map) {
      inner = inner['item'];
    }

    if (inner is Map) {
      return Map<String, dynamic>.from(inner);
    }

    return {};
  }

  List<Map<String, dynamic>> _unwrapList(dynamic raw) {
    final root = _asMap(raw);

    if (root.containsKey('ok') && root.containsKey('data')) {
      return _unwrapList(root['data']);
    }

    if (root['items'] is List) {
      return _asList(root['items']);
    }

    if (root['data'] is List) {
      return _asList(root['data']);
    }

    if (root['item'] is Map) {
      return [_asMap(root['item'])];
    }

    return [];
  }

  Future<List<Announcement>> list() {
    if (_cachedList != null && _isFresh(_listFetchedAt)) {
      return Future.value(_cachedList);
    }

    if (_listInFlight != null) return _listInFlight!;

    _listInFlight = _fetchList();
    return _listInFlight!;
  }

  Future<List<Announcement>> _fetchList() async {
    final res = await _dio.get('/announcements');

    final items = _unwrapList(res.data).map((e) => Announcement.fromJson(e)).toList();

    _cachedList = items;
    _listFetchedAt = DateTime.now();
    _listInFlight = null;

    return items;
  }

  Future<List<Announcement>> pinned() {
    if (_cachedPinned != null && _isFresh(_pinnedFetchedAt)) {
      return Future.value(_cachedPinned);
    }

    if (_pinnedInFlight != null) return _pinnedInFlight!;

    _pinnedInFlight = _fetchPinned();
    return _pinnedInFlight!;
  }

  Future<List<Announcement>> _fetchPinned() async {
    final res = await _dio.get('/announcements/pinned');

    final items = _unwrapList(res.data).map((e) => Announcement.fromJson(e)).toList();

    _cachedPinned = items;
    _pinnedFetchedAt = DateTime.now();
    _pinnedInFlight = null;

    return items;
  }

  Future<Announcement?> getBySlug(String slug) async {
    final s = slug.trim();
    if (s.isEmpty) return null;

    final res = await _dio.get('/announcements/$s');
    final m = _unwrapMap(res.data);

    if (m.isEmpty) return null;

    return Announcement.fromJson(m);
  }

  Future<Announcement> createDraft({
    required String title,
    required String summary,
    required String excerpt,
    required String bodyMarkdown,
    List<String> mediaIds = const [],
  }) async {
    final cleanedMediaIds =
        mediaIds.map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

    final res = await _dio.post(
      '/admin/announcements',
      data: {
        'title': title,
        'summary': summary,
        'excerpt': excerpt,
        'bodyMarkdown': bodyMarkdown,
        if (cleanedMediaIds.isNotEmpty) 'mediaIds': cleanedMediaIds,
      },
    );

    final m = _unwrapMap(res.data);
    return Announcement.fromJson(m);
  }

  Future<Announcement> updateDraft({
    required String id,
    String? title,
    String? summary,
    String? excerpt,
    String? bodyMarkdown,
    List<String>? mediaIds,
  }) async {
    final payload = <String, dynamic>{};

    if (title != null) payload['title'] = title;
    if (summary != null) payload['summary'] = summary;
    if (excerpt != null) payload['excerpt'] = excerpt;
    if (bodyMarkdown != null) payload['bodyMarkdown'] = bodyMarkdown;
    if (mediaIds != null) {
      payload['mediaIds'] =
          mediaIds.map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    }

    final res = await _dio.patch('/admin/announcements/$id', data: payload);
    final m = _unwrapMap(res.data);
    return Announcement.fromJson(m);
  }

  Future<void> publish(String id) async {
    await _dio.post('/admin/announcements/$id/publish');
    _invalidateCache();
  }

  /// WHAT THE SERVER ACTUALLY DID, when the client did not find out.
  ///
  /// `TIMEOUT != FAILURE` (founder freeze, 2026-09-10). A publish request that
  /// times out has an UNKNOWN outcome, not a failed one — on 2026-09-10 the
  /// founder's client gave up after the server had already published AND
  /// notified 32 people, was told publishing failed, retried, and produced a
  /// duplicate plus a second round of notifications.
  ///
  /// `GET /announcements/:slug` filters to `status: PUBLISHED`, so it answers
  /// this question exactly: a hit means published, a 404 means not. Nothing new
  /// had to be built on the server to reconcile.
  Future<PublicationOutcome> reconcilePublication(String slug) async {
    final s = slug.trim();
    if (s.isEmpty) return PublicationOutcome.unknown;
    try {
      final res = await _dio.get('/announcements/$s');
      return _unwrapMap(res.data).isEmpty
          ? PublicationOutcome.notPublished
          : PublicationOutcome.published;
    } on DioException catch (e) {
      final code = e.response?.statusCode;
      // A 404 is an ANSWER: the row is not published. Anything else leaves the
      // question open, and an open question must never be reported as a no.
      if (code == 404) return PublicationOutcome.notPublished;
      return PublicationOutcome.unknown;
    } catch (_) {
      return PublicationOutcome.unknown;
    }
  }

  Future<void> unpublish(String id) async {
    await _dio.post('/admin/announcements/$id/unpublish');
    _invalidateCache();
  }

  Future<void> pin(String id) async {
    await _dio.post(
      '/admin/announcements/$id/pin',
      data: {'pinned': true},
    );
    _invalidateCache();
  }

  Future<void> unpin(String id) async {
    await _dio.post(
      '/admin/announcements/$id/pin',
      data: {'pinned': false},
    );
    _invalidateCache();
  }

  Future<void> remove(String id) async {
    await _dio.delete('/admin/announcements/$id');
    _invalidateCache();
  }

  void _invalidateCache() {
    _cachedList = null;
    _cachedPinned = null;
    _listFetchedAt = null;
    _pinnedFetchedAt = null;
    _listInFlight = null;
    _pinnedInFlight = null;
  }
}

/// The three answers a publish attempt can have. UNKNOWN is not a failure.
enum PublicationOutcome { published, notPublished, unknown }

/// Did this error leave the outcome UNKNOWN?
///
/// No response at all — timeout, connection error — obviously did. So did a
/// 5xx: the publish path commits the row and THEN fans out, so a server error
/// can be raised after the announcement is already public. Only a 4xx is a
/// definite pre-commit refusal, and only that is safely retryable as a failure.
bool publishOutcomeIsUnknown(Object error) {
  if (error is! DioException) return true;
  final code = error.response?.statusCode;
  if (code == null) return true;
  return code >= 500;
}
