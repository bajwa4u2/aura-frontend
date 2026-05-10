import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../net/dio_provider.dart';

/// Visibility mirrors the backend `MediaVisibility` enum. Treated as a
/// raw string on the wire to stay tolerant of additions without forcing
/// a frontend release.
class MediaVisibility {
  static const public = 'PUBLIC';
  static const restricted = 'RESTRICTED';
  static const private = 'PRIVATE';

  const MediaVisibility._();
}

/// One render-ready URL plus the metadata the renderer needs.
class MediaUrlResult {
  MediaUrlResult({
    required this.id,
    required this.url,
    required this.visibility,
    this.expiresAt,
    this.mimeType,
    this.mediaType,
    this.width,
    this.height,
    this.duration,
  });

  final String id;
  final String url;
  final String visibility;
  final DateTime? expiresAt;
  final String? mimeType;
  final String? mediaType;
  final int? width;
  final int? height;
  final int? duration;

  bool get isPublic => visibility.toUpperCase() == MediaVisibility.public;

  /// True if the URL has expired or will expire within [skew]. Public
  /// URLs (no expiry) are always considered fresh.
  bool isStale({Duration skew = const Duration(seconds: 30)}) {
    final exp = expiresAt;
    if (exp == null) return false;
    return DateTime.now().add(skew).isAfter(exp);
  }
}

class _CacheEntry {
  _CacheEntry({required this.future, required this.fetchedAt});
  final Future<MediaUrlResult> future;
  final DateTime fetchedAt;
  MediaUrlResult? value;
  Object? error;
}

/// Canonical resolver for any media id. PUBLIC media short-circuits to
/// the permanent URL (one round-trip on first call, cached forever).
/// RESTRICTED / PRIVATE media re-fetches before each `expiresAt` to
/// keep the rendered URL valid.
///
/// Single source of truth — every screen that needs to display a
/// possibly-restricted media should consume this through
/// `mediaUrlProvider`. Direct DioClient calls for `/media/:id/url` are
/// intentionally NOT supported; the cache + invalidation contract only
/// holds when every reader goes through this class.
class MediaUrlResolver {
  MediaUrlResolver(this._dio);

  final Dio _dio;
  final Map<String, _CacheEntry> _cache = {};

  /// Resolve once. Returns the cached result while it's still fresh;
  /// otherwise issues a single `/media/:id/url` call and dedupes
  /// concurrent requests for the same id.
  Future<MediaUrlResult> resolve(String mediaId) {
    final id = mediaId.trim();
    if (id.isEmpty) {
      return Future.error(StateError('Empty mediaId'));
    }

    final existing = _cache[id];
    if (existing != null) {
      final value = existing.value;
      // Reuse a non-stale resolved value.
      if (value != null && !value.isStale()) return Future.value(value);
      // Reuse an in-flight request even if the previous one failed —
      // the in-flight future will surface its outcome to all listeners.
      if (value == null && existing.error == null) return existing.future;
    }

    final future = _fetch(id);
    final entry = _CacheEntry(future: future, fetchedAt: DateTime.now());
    _cache[id] = entry;

    future.then((v) {
      entry.value = v;
    }, onError: (Object e) {
      entry.error = e;
      // Drop failed entries after a short cooldown so a transient error
      // doesn't poison the cache forever; subsequent reads will retry.
      Timer(const Duration(seconds: 10), () {
        if (identical(_cache[id], entry)) _cache.remove(id);
      });
    });

    return future;
  }

  /// Force-evict a single entry. Use when the caller knows the
  /// underlying media has changed (e.g. an admin replaced the file).
  void invalidate(String mediaId) {
    _cache.remove(mediaId.trim());
  }

  /// Drop every cached entry. Wire this into the auth-state-cleared
  /// path so signed URLs do not leak across user sessions.
  void clearAll() {
    _cache.clear();
  }

  Future<MediaUrlResult> _fetch(String id) async {
    final res = await _dio.get('/media/$id/url');
    final body = res.data;
    final payload = _unwrap(body);
    final url = (payload['url'] ?? '').toString().trim();
    if (url.isEmpty) {
      throw StateError('Media URL missing');
    }
    final expiresRaw = payload['expiresAt'];
    final expiresAt = expiresRaw == null
        ? null
        : DateTime.tryParse(expiresRaw.toString())?.toUtc();
    return MediaUrlResult(
      id: (payload['id'] ?? id).toString(),
      url: url,
      visibility: (payload['visibility'] ?? MediaVisibility.public).toString(),
      expiresAt: expiresAt,
      mimeType: payload['mimeType']?.toString(),
      mediaType: payload['mediaType']?.toString(),
      width: _asInt(payload['width']),
      height: _asInt(payload['height']),
      duration: _asInt(payload['duration']),
    );
  }

  Map<String, dynamic> _unwrap(dynamic raw) {
    if (raw is Map) {
      final root = Map<String, dynamic>.from(raw);
      final inner = root['data'];
      if (inner is Map) return Map<String, dynamic>.from(inner);
      return root;
    }
    return const <String, dynamic>{};
  }

  static int? _asInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    final n = num.tryParse(v.toString());
    return n?.toInt();
  }
}

/// Riverpod accessor for the singleton resolver. The resolver is NOT
/// auto-disposed because we want the cache to survive widget rebuilds;
/// the `clearAll()` hook is wired into the auth-cleared path so signed
/// URLs do not leak across sessions.
final mediaUrlResolverProvider = Provider<MediaUrlResolver>(
  (ref) => MediaUrlResolver(ref.watch(dioProvider)),
);

/// One-shot future provider for a specific media id. Re-watch this to
/// refresh after expiry; AuraResolvableAttachmentImage does that
/// automatically when [MediaUrlResult.isStale] returns true.
final mediaUrlProvider = FutureProvider.family<MediaUrlResult, String>(
  (ref, mediaId) {
    return ref.watch(mediaUrlResolverProvider).resolve(mediaId);
  },
);
