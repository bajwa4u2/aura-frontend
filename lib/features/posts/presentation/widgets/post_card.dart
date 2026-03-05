import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/services.dart';
import 'package:dio/dio.dart';

import '../../../../core/net/dio_provider.dart';
import '../../../../core/ui/aura_card.dart';
import '../../../../core/ui/aura_space.dart';
import '../../../../core/ui/aura_surface.dart';
import '../../../../core/ui/aura_text.dart';
import '../../../feed/domain/post.dart';

String? _resolveAvatarUrl(WidgetRef ref, String? raw) {
  final url = (raw ?? '').trim();
  if (url.isEmpty) return null;

  // Already absolute
  if (url.startsWith('http://') || url.startsWith('https://')) return url;

  // Serve relative paths from uploads domain
  const uploadsBase = String.fromEnvironment(
    'UPLOADS_BASE_URL',
    defaultValue: 'https://uploads.auraplatform.org',
  );

  var base = uploadsBase.trim();
  while (base.endsWith('/')) {
    base = base.substring(0, base.length - 1);
  }

  if (!url.startsWith('/')) return '$base/$url';
  return '$base$url';
}

const String _kAuraWebBaseUrl = String.fromEnvironment(
  'AURA_WEB_BASE_URL',
  defaultValue: 'https://app.auraplatform.org',
);

String _canonicalPostUrl(String postId) {
  var base = _kAuraWebBaseUrl.trim();
  if (base.endsWith('/')) base = base.substring(0, base.length - 1);
  return '$base/posts/$postId';
}

String _linkedInShareUrl(String postUrl) {
  final u = Uri.encodeComponent(postUrl);
  return 'https://www.linkedin.com/sharing/share-offsite/?url=$u';
}

bool _extractBool(dynamic data, List<String> keys) {
  if (data is! Map) return false;
  for (final k in keys) {
    final v = data[k];
    if (v is bool) return v;
  }
  // tolerate nested "data" wrappers if older servers are hit
  final inner = data['data'];
  if (inner is Map) {
    for (final k in keys) {
      final v = inner[k];
      if (v is bool) return v;
    }
  }
  return false;
}

final isLikedProvider = FutureProvider.family<bool, String>((ref, postId) async {
  final dio = ref.watch(dioProvider);
  final pid = (postId).trim();
  if (pid.isEmpty) return false;

  try {
    final res = await dio.get('/reactions/$pid');
    final data = res.data;
    // New contract: { liked: true/false }
    // Back-compat: { ok:true, data:{ liked/isLiked } }
    return _extractBool(data, const ['liked', 'isLiked']);
  } on DioException catch (e) {
    // Visibility contract: non-visible post returns 404; treat as not liked
    if (e.response?.statusCode == 404) return false;
    return false;
  } catch (_) {
    return false;
  }
});

final isSavedProvider = FutureProvider.family<bool, String>((ref, postId) async {
  final dio = ref.watch(dioProvider);
  final pid = (postId).trim();
  if (pid.isEmpty) return false;

  try {
    final res = await dio.get('/saves/$pid');
    final data = res.data;
    // Expected: { saved: true/false } or { isSaved: true/false } depending on backend version
    // Back-compat: { ok:true, data:{ saved/isSaved } }
    return _extractBool(data, const ['saved', 'isSaved']);
  } on DioException catch (e) {
    if (e.response?.statusCode == 404) return false;
    return false;
  } catch (_) {
    return false;
  }
});

class PostCard extends ConsumerStatefulWidget {
  const PostCard({
    super.key,
    required this.post,
    this.compact = false,
    this.showAdminBadges = false,
  });

  final Post post;
  final bool compact;
  final bool showAdminBadges;

  @override
  ConsumerState<PostCard> createState() => _PostCardState();
}

class _PostCardState extends ConsumerState<PostCard> {
  bool _expanded = false;

  void _toggleExpanded() => setState(() => _expanded = !_expanded);

  String? _resolveMediaUrl(WidgetRef ref, String? raw) {
    if (raw == null) return null;
    final s = raw.trim();
    if (s.isEmpty) return null;

    // Already absolute
    if (s.startsWith('http://') || s.startsWith('https://')) return s;

    // Protocol-relative
    if (s.startsWith('//')) return 'https:$s';

    // Build absolute from API_BASE_URL origin (strip /v1 etc)
    final apiBase = const String.fromEnvironment('API_BASE_URL', defaultValue: '');
    if (apiBase.isNotEmpty) {
      final uri = Uri.tryParse(apiBase);
      if (uri != null && uri.hasScheme && uri.host.isNotEmpty) {
        final origin = uri.origin;

        // If backend returns "/uploads/..." or "/media/..." etc.
        if (s.startsWith('/')) return '$origin$s';

        // If backend returns "uploads/..." (rare but happens)
        return '$origin/$s';
      }
    }

    // Fallback: if we cannot determine origin, return as-is
    return s;
  }

  double _mediaMaxHeight(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    if (w >= 1200) return 520;
    if (w >= 900) return 460;
    if (w >= 600) return 420;
    return 360;
  }

  bool _willOverflow({
    required String text,
    required TextStyle style,
    required double maxWidth,
    required int maxLines,
  }) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      maxLines: maxLines,
      ellipsis: '…',
    )..layout(maxWidth: maxWidth);

    return tp.didExceedMaxLines;
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    final compact = widget.compact;

    final a = post.author;
    final displayName = (a?.displayName ?? '').trim();
    final handle = (a?.handle ?? '').trim();

    final avatarResolved = _resolveAvatarUrl(ref, a?.avatarUrl);

    // Optional fields (do NOT assume they exist in the model).
    final dyn = post as dynamic;

    String? status;
    try {
      status = (dyn.status as Object?)?.toString();
    } catch (_) {}

    String? visibility;
    try {
      visibility = (dyn.visibility as Object?)?.toString();
    } catch (_) {}

    String? mediaUrl;
    try {
      mediaUrl = (dyn.mediaUrl as String?)?.trim();
      if (mediaUrl != null && mediaUrl!.isEmpty) mediaUrl = null;
    } catch (_) {}

    String? mediaThumbUrl;
    try {
      mediaThumbUrl = (dyn.mediaThumbUrl as String?)?.trim();
      if (mediaThumbUrl != null && mediaThumbUrl!.isEmpty) mediaThumbUrl = null;
    } catch (_) {}

    String? mediaType;
    try {
      mediaType = (dyn.mediaType as Object?)?.toString();
    } catch (_) {}

    int? mediaWidth;
    int? mediaHeight;
    try {
      mediaWidth = dyn.mediaWidth as int?;
    } catch (_) {
      try {
        mediaWidth = int.tryParse((dyn.mediaWidth ?? '').toString());
      } catch (_) {}
    }
    try {
      mediaHeight = dyn.mediaHeight as int?;
    } catch (_) {
      try {
        mediaHeight = int.tryParse((dyn.mediaHeight ?? '').toString());
      } catch (_) {}
    }

    // Fallback: if the backend returns a media array instead of flattened fields,
    // use the first item as the primary medium.
    try {
      if (mediaUrl == null || mediaUrl!.trim().isEmpty) {
        final list = (dyn.media as Object?);
        if (list is List && list.isNotEmpty) {
          final first = list.first;
          if (first is Map) {
            final fm = Map<String, dynamic>.from(first);
            final u = (fm['url'] ?? fm['publicUrl'] ?? '').toString().trim();
            if (u.isNotEmpty) mediaUrl = u;

            final tu = (fm['thumbUrl'] ?? fm['thumbnailUrl'] ?? fm['thumb'] ?? '').toString().trim();
            if (tu.isNotEmpty) mediaThumbUrl ??= tu;

            final t = (fm['type'] ?? fm['kind'] ?? fm['mediaType']);
            if (t != null && t.toString().trim().isNotEmpty) mediaType ??= t.toString();

            final w = fm['width'];
            final h = fm['height'];
            if (mediaWidth == null) mediaWidth = (w is int) ? w : int.tryParse((w ?? '').toString());
            if (mediaHeight == null) mediaHeight = (h is int) ? h : int.tryParse((h ?? '').toString());
          }
        }
      }
    } catch (_) {}

    // Also tolerate other common field names: mediaItems, mediaAttachments.
    try {
      if (mediaUrl == null || mediaUrl!.trim().isEmpty) {
        final list = (dyn.mediaItems as Object?);
        if (list is List && list.isNotEmpty) {
          final first = list.first;
          if (first is Map) {
            final fm = Map<String, dynamic>.from(first);
            final u = (fm['url'] ?? fm['publicUrl'] ?? '').toString().trim();
            if (u.isNotEmpty) mediaUrl = u;

            final tu = (fm['thumbUrl'] ?? fm['thumbnailUrl'] ?? fm['thumb'] ?? '').toString().trim();
            if (tu.isNotEmpty) mediaThumbUrl ??= tu;

            final t = (fm['type'] ?? fm['kind'] ?? fm['mediaType']);
            if (t != null && t.toString().trim().isNotEmpty) mediaType ??= t.toString();

            final w = fm['width'];
            final h = fm['height'];
            if (mediaWidth == null) mediaWidth = (w is int) ? w : int.tryParse((w ?? '').toString());
            if (mediaHeight == null) mediaHeight = (h is int) ? h : int.tryParse((h ?? '').toString());
          }
        }
      }
    } catch (_) {}

    // Optional link attachment (treated as its own primary medium when present)
    String? linkUrl;
    String? linkTitle;
    String? linkSubtitle;
    String? linkThumbUrl;
    try {
      linkUrl = (dyn.linkUrl as String?)?.trim();
      if (linkUrl != null && linkUrl!.isEmpty) linkUrl = null;
    } catch (_) {
      try {
        linkUrl = (dyn.url as String?)?.trim();
        if (linkUrl != null && linkUrl!.isEmpty) linkUrl = null;
      } catch (_) {}
    }
    try {
      linkTitle = (dyn.linkTitle as String?)?.trim();
      if (linkTitle != null && linkTitle!.isEmpty) linkTitle = null;
    } catch (_) {}
    try {
      linkSubtitle = (dyn.linkSubtitle as String?)?.trim();
      if (linkSubtitle != null && linkSubtitle!.isEmpty) linkSubtitle = null;
    } catch (_) {
      try {
        linkSubtitle = (dyn.linkDescription as String?)?.trim();
        if (linkSubtitle != null && linkSubtitle!.isEmpty) linkSubtitle = null;
      } catch (_) {}
    }
    try {
      linkThumbUrl = (dyn.linkThumbUrl as String?)?.trim();
      if (linkThumbUrl != null && linkThumbUrl!.isEmpty) linkThumbUrl = null;
    } catch (_) {
      try {
        linkThumbUrl = (dyn.linkImageUrl as String?)?.trim();
        if (linkThumbUrl != null && linkThumbUrl!.isEmpty) linkThumbUrl = null;
      } catch (_) {}
    }

    final resolvedMediaUrl = _resolveMediaUrl(ref, mediaUrl);
    final resolvedMediaThumbUrl = _resolveMediaUrl(ref, mediaThumbUrl);

    // Intentionally not used for UI: Aura rule is no public counts.
    int? _asInt(Object? v) {
      if (v == null) return null;
      if (v is int) return v;
      final s = v.toString().trim();
      return int.tryParse(s);
    }

    int? likeCount;
    int? replyCount;
    int? repostCount;
    int? saveCount;

    try {
      likeCount = _asInt(dyn.likeCount);
    } catch (_) {}
    try {
      replyCount = _asInt(dyn.replyCount);
    } catch (_) {}
    try {
      repostCount = _asInt(dyn.repostCount);
    } catch (_) {}
    try {
      saveCount = _asInt(dyn.saveCount);
    } catch (_) {}

    final createdAt = post.createdAt;
    final createdLabel = (createdAt == null)
        ? ''
        : '${createdAt.year.toString().padLeft(4, '0')}-${createdAt.month.toString().padLeft(2, '0')}-${createdAt.day.toString().padLeft(2, '0')}';

    final postId = post.id;
    final text = (post.text ?? '').trim();

    final headerName = displayName.isNotEmpty ? displayName : (handle.isNotEmpty ? '@$handle' : '—');
    final headerSub = handle.isNotEmpty ? '@$handle' : '';

    final bodyTextStyle = AuraText.body.copyWith(height: 1.42);

    final collapsedLines = compact ? 4 : 7;

    return AuraCard(
      child: Padding(
        padding: EdgeInsets.all(compact ? AuraSpace.s12 : AuraSpace.s14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ---------- HEADER ----------
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                CircleAvatar(
                  radius: compact ? 18 : 20,
                  backgroundImage: avatarResolved != null ? NetworkImage(avatarResolved) : null,
                  child: avatarResolved == null ? const Icon(Icons.person, size: 18) : null,
                ),
                const SizedBox(width: AuraSpace.s10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        headerName,
                        style: AuraText.body.copyWith(fontWeight: FontWeight.w800),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (headerSub.isNotEmpty || createdLabel.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            [headerSub, createdLabel].where((e) => e.trim().isNotEmpty).join(' · '),
                            style: AuraText.small.copyWith(color: AuraSurface.muted),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: AuraSpace.s10),
                IconButton(
                  tooltip: 'Open',
                  onPressed: () => context.push('/posts/$postId'),
                  icon: const Icon(Icons.open_in_new, size: 18),
                ),
              ],
            ),

            // ---------- BADGES ----------
            if (widget.showAdminBadges) ...[
              const SizedBox(height: AuraSpace.s10),
              Wrap(
                spacing: AuraSpace.s10,
                runSpacing: AuraSpace.s10,
                children: [
                  if ((status ?? '').trim().isNotEmpty)
                    _Badge(
                      text: (status ?? '').toUpperCase(),
                      tone: (status ?? '').toLowerCase().contains('published')
                          ? _BadgeTone.good
                          : _BadgeTone.warn,
                    ),
                  if ((visibility ?? '').trim().isNotEmpty)
                    _Badge(
                      text: (visibility ?? '').toUpperCase(),
                      tone: _BadgeTone.neutral,
                    ),
                ],
              ),
            ],

            // ---------- BODY ----------
            if (text.isNotEmpty) ...[
              const SizedBox(height: AuraSpace.s12),
              LayoutBuilder(
                builder: (context, c) {
                  final showToggle = _willOverflow(
                    text: text,
                    style: bodyTextStyle,
                    maxWidth: c.maxWidth,
                    maxLines: collapsedLines,
                  );

                  final maxLines = _expanded ? null : collapsedLines;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        text,
                        maxLines: maxLines,
                        overflow: (maxLines == null) ? TextOverflow.visible : TextOverflow.ellipsis,
                        style: bodyTextStyle,
                      ),
                      if (showToggle) ...[
                        const SizedBox(height: AuraSpace.s8),
                        InkWell(
                          onTap: _toggleExpanded,
                          borderRadius: BorderRadius.circular(999),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AuraSpace.s10,
                              vertical: AuraSpace.s6,
                            ),
                            child: Text(
                              _expanded ? 'Collapse' : 'Open',
                              style: AuraText.small.copyWith(
                                fontWeight: FontWeight.w800,
                                color: AuraSurface.muted,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  );
                },
              ),
            ],

            // ---------- ATTACHMENT (MEDIA or LINK) ----------
            _finalAttachmentBlock(
              context,
              postId: post.id,
              mediaUrl: resolvedMediaUrl,
              mediaThumbUrl: resolvedMediaThumbUrl,
              mediaType: mediaType,
              mediaWidth: mediaWidth,
              mediaHeight: mediaHeight,
              linkUrl: linkUrl,
              linkTitle: linkTitle,
              linkSubtitle: linkSubtitle,
              linkThumbUrl: linkThumbUrl,
            ),

            SizedBox(height: AuraSpace.s12),

            // ---------- ACTIONS ----------
            _ActionRow(
              postId: post.id,
              likeCount: likeCount,
              repostCount: repostCount,
              saveCount: saveCount,
              replyCount: replyCount,
            ),
          ],
        ),
      ),
    );
  }

  Widget _finalAttachmentBlock(
    BuildContext context, {
    required String postId,
    required String? mediaUrl,
    required String? mediaThumbUrl,
    required String? mediaType,
    required int? mediaWidth,
    required int? mediaHeight,
    required String? linkUrl,
    required String? linkTitle,
    required String? linkSubtitle,
    required String? linkThumbUrl,
  }) {
    // Primary medium priority: MEDIA first, then LINK.
    final mUrl = (mediaUrl ?? '').trim();
    final lUrl = (linkUrl ?? '').trim();

    if (mUrl.isEmpty && lUrl.isEmpty) return const SizedBox.shrink();

    final border = Border.all(color: AuraSurface.divider);
    final r = BorderRadius.circular(16);

    if (mUrl.isNotEmpty) {
      final lower = mUrl.toLowerCase();
      final mt = (mediaType ?? '').toLowerCase();

      final isSvg = lower.endsWith('.svg') || mt.contains('svg');
      final isVideo = mt.contains('video') ||
          lower.endsWith('.mp4') ||
          lower.endsWith('.webm') ||
          lower.endsWith('.mov');

      // Use media dimensions when available to avoid awkward crops.
      double? ratio;
      if (mediaWidth != null &&
          mediaHeight != null &&
          mediaWidth! > 0 &&
          mediaHeight! > 0) {
        ratio = mediaWidth! / mediaHeight!;
      }

      // Clamp extreme ratios (keeps layout stable across devices).
      if (ratio != null) {
        if (ratio! < 0.6) ratio = 0.6;
        if (ratio! > 1.9) ratio = 1.9;
      }

      final maxH = _mediaMaxHeight(context);

      Widget inner;

      if (isSvg) {
        inner = SvgPicture.network(
          mUrl,
          fit: BoxFit.cover,
          placeholderBuilder: (_) => const SizedBox(
            height: 140,
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          ),
        );
      } else {
        // Video: show a thumbnail if available, else show an image placeholder.
        final thumb = (mediaThumbUrl ?? '').trim();
        final show = (isVideo && thumb.isNotEmpty) ? thumb : mUrl;

        inner = Image.network(
          show,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            height: 200,
            alignment: Alignment.center,
            child: Text(
              isVideo ? 'Video attached' : 'Media unavailable',
              style: AuraText.small,
            ),
          ),
          loadingBuilder: (c, child, p) {
            if (p == null) return child;
            return SizedBox(
              height: 220,
              child: Center(
                child: CircularProgressIndicator(
                  value: (p.expectedTotalBytes != null)
                      ? (p.cumulativeBytesLoaded / (p.expectedTotalBytes ?? 1))
                      : null,
                  strokeWidth: 2,
                ),
              ),
            );
          },
        );
      }

      final content = ClipRRect(
        borderRadius: r,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: r,
            border: border,
            color: AuraSurface.elevated,
          ),
          child: ratio == null
              ? ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: maxH),
                  child: inner,
                )
              : AspectRatio(
                  aspectRatio: ratio!,
                  child: inner,
                ),
        ),
      );

      return Padding(
        padding: const EdgeInsets.only(top: AuraSpace.s14),
        child: InkWell(
          borderRadius: r,
          onTap: () {
            // Open post detail (media can be expanded there later)
            context.push('/posts/$postId');
          },
          child: content,
        ),
      );
    }

    // LINK attachment (primary medium when present and no mediaUrl).
    final uri = Uri.tryParse(lUrl);
    final host = (uri != null && (uri.host).trim().isNotEmpty) ? uri.host : lUrl;

    Widget? thumb;
    final t = (linkThumbUrl ?? '').trim();
    if (t.isNotEmpty) {
      thumb = ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(
          t,
          width: 72,
          height: 72,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
        ),
      );
    }

    final title = (linkTitle ?? '').trim().isNotEmpty ? linkTitle!.trim() : host;
    final subtitle = (linkSubtitle ?? '').trim();

    return Padding(
      padding: const EdgeInsets.only(top: AuraSpace.s14),
      child: InkWell(
        borderRadius: r,
        onTap: () async {
          // No url_launcher dependency. Tap copies the link.
          await Clipboard.setData(ClipboardData(text: lUrl));
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Link copied')),
            );
          }
        },
        child: ClipRRect(
          borderRadius: r,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: r,
              border: border,
              color: AuraSurface.elevated,
            ),
            padding: const EdgeInsets.all(AuraSpace.s12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (thumb != null) ...[
                  thumb,
                  const SizedBox(width: AuraSpace.s12),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: AuraText.body.copyWith(fontWeight: FontWeight.w700),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (subtitle.isNotEmpty) ...[
                        const SizedBox(height: AuraSpace.s6),
                        Text(
                          subtitle,
                          style: AuraText.body.copyWith(height: 1.35),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: AuraSpace.s8),
                      Text(
                        host,
                        style: AuraText.small.copyWith(color: AuraSurface.muted),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: AuraSpace.s6),
                      Text(
                        'Tap to copy link',
                        style: AuraText.small.copyWith(color: AuraSurface.muted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionRow extends ConsumerWidget {
  const _ActionRow({
    required this.postId,
    this.likeCount,
    this.repostCount,
    this.saveCount,
    this.replyCount,
  });

  final String postId;

  // Kept for compatibility, but never displayed (Aura rule: no public counts)
  final int? likeCount;
  final int? repostCount;
  final int? saveCount;
  final int? replyCount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final liked = ref.watch(isLikedProvider(postId));
    final saved = ref.watch(isSavedProvider(postId));

    Future<void> toggleLike() async {
      final dio = ref.read(dioProvider);
      await dio.post('/reactions/$postId/toggle');
      ref.invalidate(isLikedProvider(postId));
    }

    Future<void> toggleSave() async {
      final dio = ref.read(dioProvider);
      await dio.post('/saves/$postId/toggle');
      ref.invalidate(isSavedProvider(postId));
    }

    Future<void> repost() async {
      final controller = TextEditingController();

      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) {
          return AlertDialog(
            title: const Text('Repost'),
            content: TextField(
              controller: controller,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: 'Add a short line (optional)…',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Repost'),
              ),
            ],
          );
        },
      );

      if (ok != true) return;

      final text = controller.text.trim();
      final dio = ref.read(dioProvider);

      final payload = <String, dynamic>{};
      if (text.isNotEmpty) payload['text'] = text;

      await dio.post('/posts/$postId/repost', data: payload);

      ref.invalidate(isLikedProvider(postId));
      ref.invalidate(isSavedProvider(postId));

      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Reposted')));
      }
    }

    Future<void> share() async {
      final postUrl = _canonicalPostUrl(postId);
      final linkedInUrl = _linkedInShareUrl(postUrl);

      // No url_launcher dependency (keeps builds stable). We copy links instead.
      await Clipboard.setData(ClipboardData(text: postUrl));

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Post link copied')),
      );

      await showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        builder: (ctx) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Share', style: AuraText.title),
                const SizedBox(height: AuraSpace.s10),
                Text(
                  'Aura does not auto-post on your behalf. We keep it clean: you copy a link and share intentionally.',
                  style: AuraText.body,
                ),
                const SizedBox(height: AuraSpace.s12),
                AuraCard(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Post URL', style: AuraText.small.copyWith(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 6),
                        SelectableText(postUrl, style: AuraText.small),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: AuraSpace.s10,
                          runSpacing: AuraSpace.s10,
                          children: [
                            OutlinedButton(
                              onPressed: () async {
                                await Clipboard.setData(ClipboardData(text: postUrl));
                                if (ctx.mounted) {
                                  ScaffoldMessenger.of(ctx).showSnackBar(
                                    const SnackBar(content: Text('Post link copied')),
                                  );
                                }
                              },
                              child: const Text('Copy link'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AuraSpace.s12),
                AuraCard(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('LinkedIn share URL', style: AuraText.small.copyWith(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 6),
                        SelectableText(linkedInUrl, style: AuraText.small),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: AuraSpace.s10,
                          runSpacing: AuraSpace.s10,
                          children: [
                            OutlinedButton(
                              onPressed: () async {
                                await Clipboard.setData(ClipboardData(text: linkedInUrl));
                                if (ctx.mounted) {
                                  ScaffoldMessenger.of(ctx).showSnackBar(
                                    const SnackBar(content: Text('LinkedIn share URL copied')),
                                  );
                                }
                              },
                              child: const Text('Copy LinkedIn share URL'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AuraSpace.s12),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text('Done'),
                  ),
                ),
              ],
            ),
          );
        },
      );
    }

    Widget pill({
      required IconData icon,
      required String label,
      required VoidCallback onTap,
      bool active = false,
    }) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AuraSpace.s12,
            vertical: AuraSpace.s8,
          ),
          decoration: BoxDecoration(
            color: AuraSurface.elevated,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: AuraSurface.divider),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: active ? AuraSurface.ink : AuraSurface.muted),
              const SizedBox(width: AuraSpace.s6),
              Text(
                label,
                style: AuraText.small.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      );
    }

    return Wrap(
      spacing: AuraSpace.s10,
      runSpacing: AuraSpace.s10,
      children: [
        pill(
          icon: Icons.repeat,
          label: 'Repost',
          onTap: repost,
        ),
        liked.when(
          data: (v) => pill(
            icon: v ? Icons.favorite : Icons.favorite_border,
            label: 'Like',
            onTap: toggleLike,
            active: v,
          ),
          loading: () => pill(
            icon: Icons.favorite_border,
            label: 'Like',
            onTap: toggleLike,
          ),
          error: (_, __) => pill(
            icon: Icons.favorite_border,
            label: 'Like',
            onTap: toggleLike,
          ),
        ),
        saved.when(
          data: (v) => pill(
            icon: v ? Icons.bookmark : Icons.bookmark_border,
            label: 'Save',
            onTap: toggleSave,
            active: v,
          ),
          loading: () => pill(
            icon: Icons.bookmark_border,
            label: 'Save',
            onTap: toggleSave,
          ),
          error: (_, __) => pill(
            icon: Icons.bookmark_border,
            label: 'Save',
            onTap: toggleSave,
          ),
        ),
        pill(
          icon: Icons.reply_outlined,
          label: 'Reply',
          onTap: () => context.push('/compose?replyTo=$postId'),
        ),
        pill(
          icon: Icons.share_outlined,
          label: 'Share',
          onTap: () => share(),
        ),
      ],
    );
  }
}

enum _BadgeTone { neutral, good, warn }

class _Badge extends StatelessWidget {
  const _Badge({required this.text, required this.tone});
  final String text;
  final _BadgeTone tone;

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;

    switch (tone) {
      case _BadgeTone.good:
        bg = AuraSurface.goodBg;
        fg = AuraSurface.goodInk;
        break;
      case _BadgeTone.warn:
        bg = AuraSurface.warnBg;
        fg = AuraSurface.warnInk;
        break;
      case _BadgeTone.neutral:
      default:
        bg = AuraSurface.elevated;
        fg = AuraSurface.ink;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AuraSurface.divider),
      ),
      child: Text(
        text,
        style: AuraText.small.copyWith(color: fg, fontWeight: FontWeight.w800),
      ),
    );
  }
}