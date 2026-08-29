/// PUBLISHING A DRAFT MEANS PUBLISHING *THAT* DRAFT.
///
/// THE DEFECT THIS EXISTS TO PREVENT. The feed's convenience path is keyed by
/// author alone — `getLatestHeld(userId)`, `saveLatestHeld(userId)`,
/// `publishLatestHeld(userId)`, `clearLatestHeld(userId)`. One draft per
/// person, by construction. Share's first implementation used it:
///
///     PUT  /posts/draft          // overwrite whatever is held
///     POST /posts/draft/publish  // publish whatever is held
///
/// So somebody with an unfinished post in Compose, who then shared a
/// photograph, would have had their unfinished post REPLACED by the
/// photograph and published in its place. Two creation intentions were
/// collapsed into one row because the endpoint's key was the author rather
/// than the draft.
///
/// AND IT RUNS BOTH WAYS. `getLatestHeld` selects the most recently updated
/// DRAFT, so a Share draft left behind would be what Compose resumed the next
/// time it opened — Share silently inheriting Compose's chair.
///
/// ## THE FIX IS IDENTITY, NOT A SECOND MODEL
///
/// The same service already exposes an identity-addressed path, and it needed
/// no schema change, no migration and no `ShareDraft`:
///
///     POST /posts/held        -> creates a NEW row, returns its id
///     PUT  /posts/:id         -> updates THAT draft
///     POST /posts/:id/publish -> publishes THAT post
///
/// Every call here names the draft it means. Nothing in this file asks for
/// "the current user's draft", which is the property the tests assert.
library;

import 'package:dio/dio.dart';

/// What one feed publication produced.
class FeedPublication {
  const FeedPublication({required this.draftId, required this.postId});

  /// The draft this publication owned throughout. Kept so a retry targets the
  /// same row rather than discovering somebody else's.
  final String draftId;
  final String? postId;
}

/// Publishes a composition to the feed as its own draft.
///
/// Stateless except for the draft id the caller holds: the caller keeps it so
/// a retry after a failure continues with the SAME draft instead of creating
/// a second one and leaving the first as a stray DRAFT that Compose would
/// later resume.
class FeedDraftPublisher {
  const FeedDraftPublisher(this._dio);

  final Dio _dio;

  /// Create a draft that belongs to this composition and nothing else.
  Future<String> createDraft() async {
    final res = await _dio.post<dynamic>('/posts/held');
    final id = _extractId(res.data);
    if (id == null || id.isEmpty) {
      // Without an id there is no identity, and without identity the only
      // remaining way to publish would be the singleton path this class
      // exists to avoid. Failing here is correct.
      throw StateError('The draft could not be created [share:no_draft_id]');
    }
    return id;
  }

  /// Write this composition into [draftId], then publish that draft.
  ///
  /// [draftId] is required rather than resolved. A method that could look up
  /// the caller's draft would be able to publish the wrong one, and no amount
  /// of care at the call site would remove that possibility.
  Future<FeedPublication> publish({
    required String draftId,
    required String text,
    required List<String> mediaIds,
    required String primaryTopic,
  }) async {
    final id = draftId.trim();
    if (id.isEmpty) {
      throw ArgumentError('A draft id is required to publish [share:no_id]');
    }
    // A TOP-LEVEL POST IS A PUBLIC RECORD, AND A RECORD IS FILED UNDER
    // SOMETHING. The backend refuses one without a primary topic --
    // "A primary topic is required to publish a public record" -- and that is
    // classification doctrine, not a validation quirk to route around. Share
    // asks for the topic rather than bypassing the rule, and the parameter is
    // required so a caller cannot forget it and discover the refusal only in
    // production, which is exactly how it was found.
    final topic = primaryTopic.trim();
    if (topic.isEmpty) {
      throw ArgumentError('A primary topic is required [share:no_topic]');
    }

    await _dio.put<dynamic>('/posts/$id', data: <String, dynamic>{
      'text': text,
      'primaryTopic': topic,
      'media': <Map<String, dynamic>>[
        for (var i = 0; i < mediaIds.length; i++)
          {'mediaId': mediaIds[i], 'position': i, 'caption': null},
      ],
    });

    final res = await _dio.post<dynamic>('/posts/$id/publish');
    return FeedPublication(draftId: id, postId: _extractId(res.data) ?? id);
  }

  /// Remove a draft this composition created and never published.
  ///
  /// BEST EFFORT, AND DELIBERATELY NARROW. It names one id — there is no
  /// "clear my draft" here, because a broad clear is exactly how one creation
  /// context destroys another's. A failure to tidy is not worth surfacing:
  /// the person has already left, and the row is theirs either way.
  Future<void> discardDraft(String draftId) async {
    final id = draftId.trim();
    if (id.isEmpty) return;
    try {
      await _dio.delete<dynamic>('/posts/$id');
    } catch (_) {
      // Leaving a stray draft is bad; throwing on the way out is worse.
    }
  }

  static String? _extractId(dynamic raw) {
    if (raw is Map) {
      for (final key in const ['id', 'postId', 'draftId']) {
        final v = raw[key];
        if (v is String && v.trim().isNotEmpty) return v.trim();
      }
      for (final nest in const ['data', 'post', 'draft']) {
        final inner = raw[nest];
        if (inner != null) {
          final found = _extractId(inner);
          if (found != null) return found;
        }
      }
    }
    return null;
  }
}
