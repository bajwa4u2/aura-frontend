import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
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
    this.distribution,
    this.servedVariant,
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

  /// WHAT THE SERVER WILL ACTUALLY HAND OVER — `ORIGINAL`, `AURA_EXPORT`,
  /// `PRESENTATION` or `NONE`.
  ///
  /// Read so a label can say what the action will really produce. Offering
  /// "Download original" to somebody the distribution authority will answer
  /// with a governed copy is a promise the backend then quietly breaks, and the
  /// person only discovers it in their downloads folder.
  ///
  /// Null from a server that predates the authority. Callers treat null as
  /// "unknown" and fall back to neutral wording rather than guessing the
  /// permissive answer.
  final String? distribution;

  /// WHICH REPRESENTATION THE URL IS — `thumb`, `display` or `primary`.
  ///
  /// A `v=thumb` request falls through to the film itself when no poster
  /// exists yet, and a video file is never a poster. Null from a server that
  /// predates the field; callers treat null as "not a poster".
  final String? servedVariant;

  /// True when this viewer is entitled to the untouched source object.
  bool get deliversOriginal => (distribution ?? '').toUpperCase() == 'ORIGINAL';

  /// True when the server will produce a governed Aura copy instead.
  bool get deliversGovernedExport =>
      (distribution ?? '').toUpperCase() == 'AURA_EXPORT';

  bool get isPublic => visibility.toUpperCase() == MediaVisibility.public;

  /// True if the URL has expired or will expire within [skew]. Public
  /// URLs (no expiry) are always considered fresh.
  bool isStale({Duration skew = const Duration(seconds: 30)}) {
    final exp = expiresAt;
    if (exp == null) return false;
    return DateTime.now().add(skew).isAfter(exp);
  }
}

/// WHY A MEDIA URL COULD NOT BE PRODUCED.
///
/// The delivery door answers four materially different things, each with its
/// own status and code (`media.service.ts`):
///
///   202 MEDIA_NOT_READY      still uploading or processing — it WILL arrive
///   403 MEDIA_QUARANTINED    under review; reversible, and appealable
///   410 MEDIA_GONE           deleted or archived
///   404 MEDIA_NOT_AVAILABLE  orphaned or failed
///
/// The client collapsed all four. A 202 is a SUCCESS to Dio, so the fetch
/// sailed past the status, found no `url`, threw a bare `StateError`, and the
/// renderer drew the same broken-image frame it draws for genuinely destroyed
/// media — permanently, because nothing re-asked. A picture that was thirty
/// seconds from being ready looked identical to one that no longer existed,
/// and the person was told neither.
class MediaUnavailableException implements Exception {
  const MediaUnavailableException({
    required this.status,
    required this.code,
    required this.message,
  });

  /// HTTP status from the delivery door, or null when the call never landed.
  final int? status;

  /// The door's own code, verbatim. Never re-mapped: the server names the
  /// situation and this carries that name.
  final String? code;

  /// What the server said, where it said anything a person may read.
  final String? message;

  /// The bytes are coming. Worth waiting for and worth re-asking.
  bool get isPending => status == 202 || code == 'MEDIA_NOT_READY';

  /// Withheld under review, not destroyed — reversible, and the owner has
  /// something to appeal against.
  bool get isQuarantined => code == 'MEDIA_QUARANTINED' || status == 403;

  @override
  String toString() =>
      'MediaUnavailableException(status: $status, code: $code)';
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
  Future<MediaUrlResult> resolve(String mediaId, {String? variant}) {
    final id = mediaId.trim();
    if (id.isEmpty) {
      return Future.error(StateError('Empty mediaId'));
    }
    // A variant is a different URL for the same object, so it is cached apart.
    final cacheKey = variant == null ? id : '$id?v=$variant';

    final existing = _cache[cacheKey];
    if (existing != null) {
      final value = existing.value;
      // Reuse a non-stale resolved value.
      if (value != null && !value.isStale()) return Future.value(value);
      // Reuse an in-flight request even if the previous one failed —
      // the in-flight future will surface its outcome to all listeners.
      if (value == null && existing.error == null) return existing.future;
    }

    final future = _fetch(id, variant);
    final entry = _CacheEntry(future: future, fetchedAt: DateTime.now());
    _cache[cacheKey] = entry;

    future.then(
      (v) {
        entry.value = v;
      },
      onError: (Object e) {
        entry.error = e;
        // Drop failed entries after a short cooldown so a transient error
        // doesn't poison the cache forever; subsequent reads will retry.
        Timer(const Duration(seconds: 10), () {
          if (identical(_cache[cacheKey], entry)) _cache.remove(cacheKey);
        });
      },
    );

    return future;
  }

  /// Force-evict a single entry. Use when the caller knows the
  /// underlying media has changed (e.g. an admin replaced the file).
  void invalidate(String mediaId) {
    final id = mediaId.trim();
    _cache.removeWhere((key, _) => key == id || key.startsWith('$id?v='));
  }

  /// Drop every cached entry. Wire this into the auth-state-cleared
  /// path so signed URLs do not leak across user sessions.
  void clearAll() {
    _cache.clear();
  }

  Future<MediaUrlResult> _fetch(String id, String? variant) async {
    late final Response<dynamic> res;
    try {
      res = await _dio.get(
        '/media/$id/url',
        queryParameters: variant == null ? null : {'v': variant},
      );
    } on DioException catch (e) {
      // 403 / 404 / 410 arrive here. The door already chose a status and a
      // code for each; carry both rather than flattening them into "failed".
      final payload = _unwrap(e.response?.data);
      throw MediaUnavailableException(
        status: e.response?.statusCode,
        code: payload['code']?.toString(),
        message: payload['message']?.toString(),
      );
    }

    final body = res.data;
    final payload = _unwrap(body);

    // 202 IS NOT A SUCCESS. Dio treats every 2xx as one, so this has to be
    // read explicitly or the empty `url` below becomes the only symptom.
    if (res.statusCode == 202) {
      throw MediaUnavailableException(
        status: 202,
        code: payload['code']?.toString() ?? 'MEDIA_NOT_READY',
        message: payload['message']?.toString(),
      );
    }

    final url = (payload['url'] ?? '').toString().trim();
    if (url.isEmpty) {
      // A 200 with no URL is a contract breach, not a state the door names.
      throw MediaUnavailableException(
        status: res.statusCode,
        code: payload['code']?.toString(),
        message: payload['message']?.toString(),
      );
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
      distribution: payload['distribution']?.toString(),
      servedVariant: payload['servedVariant']?.toString(),
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

/// A SIGNED LINK HELD PAST ITS EXPIRY.
///
/// The resolver checks [MediaUrlResult.isStale] only when it is asked, and
/// these providers are kept alive and never re-asked: a feed card that
/// scrolled away and back after ten minutes was rebuilt from the same answer,
/// its poster and its video both pointing at a link storage now refuses
/// (founder, 2026-10-10: "it show broken image after one another refresh
/// scrole"). So each answer re-asks itself once it turns stale. A surface
/// already playing keeps its controller; only the next build uses the new
/// link.
@visibleForTesting
Duration? mediaLinkRefreshDelay(DateTime? expiresAt, {DateTime? now}) {
  if (expiresAt == null) return null;
  // One second past the point isStale() turns true, or the resolver would
  // hand back the same link.
  final staleAt = expiresAt.subtract(const Duration(seconds: 29));
  final delay = staleAt.difference(now ?? DateTime.now());
  return delay.isNegative ? Duration.zero : delay;
}

void _refreshWhenStale(Ref ref, MediaUrlResult result) {
  final delay = mediaLinkRefreshDelay(result.expiresAt);
  if (delay == null) return;
  final timer = Timer(delay, ref.invalidateSelf);
  ref.onDispose(timer.cancel);
}

/// The current link for a specific media id, re-asked before it expires.
final mediaUrlProvider = FutureProvider.family<MediaUrlResult, String>((
  ref,
  mediaId,
) async {
  final result = await ref.watch(mediaUrlResolverProvider).resolve(mediaId);
  _refreshWhenStale(ref, result);
  return result;
});

/// THE SERVER POSTER OF A VIDEO THE FEED COULD NOT NAME.
///
/// The feed ships no poster URL for non-public media (`media-redaction.ts`):
/// the poster is a capability, asked of the door with the viewer's identity.
/// Without this ask, a restricted film decoded its own frames — black on
/// some films, and nothing at all where the platform cannot decode.
///
/// Null when the door has no poster yet (it answers with the film itself,
/// which is never a poster) or cannot be reached: the card falls back to its
/// own frame, never to an error.
final mediaPosterUrlProvider = FutureProvider.family<String?, String>((
  ref,
  mediaId,
) async {
  try {
    final result = await ref
        .watch(mediaUrlResolverProvider)
        .resolve(mediaId, variant: 'thumb');
    _refreshWhenStale(ref, result);
    final url = result.url.trim();
    return result.servedVariant == 'thumb' && url.isNotEmpty ? url : null;
  } catch (_) {
    return null;
  }
});
