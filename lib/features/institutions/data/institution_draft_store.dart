import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Local-only persistent draft for the institution post composer.
///
/// Drafts live in `SharedPreferences` (which uses `localStorage` on the web
/// build) and are scoped by `(institutionId, userId, visibility)` so a draft
/// in the Public scope never overwrites a draft in the Member or Internal
/// scope, and so two speakers on the same device do not see each other's
/// drafts.
///
/// This is **not** server-side draft collaboration — it is a per-device
/// persistence fallback only. The backend currently has no endpoint to list
/// the current user's draft posts, so the composer cannot rehydrate a draft
/// from the server. When that endpoint exists, this store should be replaced
/// (or complemented) by the server-side flow.
class InstitutionDraft {
  const InstitutionDraft({
    required this.title,
    required this.body,
    this.mediaUrl,
    this.mediaThumbUrl,
    this.mediaMimeType,
    required this.visibility,
    required this.distribution,
    required this.updatedAt,
  });

  final String title;
  final String body;
  final String? mediaUrl;
  final String? mediaThumbUrl;
  final String? mediaMimeType;

  /// Wire visibility, e.g. `PUBLIC`, `MEMBER_ONLY`, `INTERNAL`.
  final String visibility;

  /// Wire distribution, e.g. `INSTITUTION_ONLY`, `GLOBAL_ELIGIBLE`.
  final String distribution;

  final DateTime updatedAt;

  bool get isEmpty => title.trim().isEmpty && body.trim().isEmpty;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'title': title,
        'body': body,
        if (mediaUrl != null && mediaUrl!.isNotEmpty) 'mediaUrl': mediaUrl,
        if (mediaThumbUrl != null && mediaThumbUrl!.isNotEmpty)
          'mediaThumbUrl': mediaThumbUrl,
        if (mediaMimeType != null && mediaMimeType!.isNotEmpty)
          'mediaMimeType': mediaMimeType,
        'visibility': visibility,
        'distribution': distribution,
        'updatedAt': updatedAt.toUtc().toIso8601String(),
      };

  static InstitutionDraft? fromJson(Map<String, dynamic> m) {
    final title = (m['title'] ?? '').toString();
    final body = (m['body'] ?? '').toString();
    final visibility = (m['visibility'] ?? '').toString();
    final distribution = (m['distribution'] ?? '').toString();
    if (visibility.isEmpty || distribution.isEmpty) return null;
    DateTime updatedAt;
    try {
      updatedAt = DateTime.parse((m['updatedAt'] ?? '').toString()).toLocal();
    } catch (_) {
      updatedAt = DateTime.now();
    }
    return InstitutionDraft(
      title: title,
      body: body,
      mediaUrl: (m['mediaUrl'] ?? '').toString().isEmpty
          ? null
          : m['mediaUrl'].toString(),
      mediaThumbUrl: (m['mediaThumbUrl'] ?? '').toString().isEmpty
          ? null
          : m['mediaThumbUrl'].toString(),
      mediaMimeType: (m['mediaMimeType'] ?? '').toString().isEmpty
          ? null
          : m['mediaMimeType'].toString(),
      visibility: visibility,
      distribution: distribution,
      updatedAt: updatedAt,
    );
  }
}

class InstitutionDraftStore {
  static const _prefix = 'aura_institution_post_draft_v1';

  static String _key({
    required String institutionId,
    required String userId,
    required String visibility,
  }) {
    final iid = institutionId.trim();
    final uid = userId.trim();
    final v = visibility.trim().toUpperCase();
    return '${_prefix}__${iid}__${uid}__$v';
  }

  static Future<InstitutionDraft?> load({
    required String institutionId,
    required String userId,
    required String visibility,
  }) async {
    if (institutionId.trim().isEmpty || userId.trim().isEmpty) return null;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(
      institutionId: institutionId,
      userId: userId,
      visibility: visibility,
    ));
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final decoded = json.decode(raw);
      if (decoded is Map) {
        return InstitutionDraft.fromJson(Map<String, dynamic>.from(decoded));
      }
    } catch (_) {}
    return null;
  }

  static Future<void> save({
    required String institutionId,
    required String userId,
    required InstitutionDraft draft,
  }) async {
    if (institutionId.trim().isEmpty || userId.trim().isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key(
        institutionId: institutionId,
        userId: userId,
        visibility: draft.visibility,
      ),
      json.encode(draft.toJson()),
    );
  }

  static Future<void> remove({
    required String institutionId,
    required String userId,
    required String visibility,
  }) async {
    if (institutionId.trim().isEmpty || userId.trim().isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key(
      institutionId: institutionId,
      userId: userId,
      visibility: visibility,
    ));
  }

  /// Clears every visibility-scoped draft for the given institution+user.
  /// Used after a successful publish so the composer reopens clean regardless
  /// of which scope the user had drafted into.
  static Future<void> clearAllScopes({
    required String institutionId,
    required String userId,
  }) async {
    if (institutionId.trim().isEmpty || userId.trim().isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final base = '${_prefix}__${institutionId.trim()}__${userId.trim()}__';
    for (final k in prefs.getKeys().toList()) {
      if (k.startsWith(base)) {
        await prefs.remove(k);
      }
    }
  }
}
