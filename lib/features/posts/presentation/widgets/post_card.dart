import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/services.dart';

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

  // Backend stores avatarUrl like: /uploads/<file>
  // Must load it from API host, not from the frontend origin.
  final dio = ref.read(dioProvider);
  var base = dio.options.baseUrl; // e.g. https://api.aura.../v1

  // Strip trailing /v1 (or /v1/) reliably
  if (base.endsWith('/v1')) base = base.substring(0, base.length - 3);
  if (base.endsWith('/v1/')) base = base.substring(0, base.length - 4);

  while (base.endsWith('/')) {
    base = base.substring(0, base.length - 1);
  }

  if (!url.startsWith('/')) return '$base/$url';
  return '$base$url';
}

final isLikedProvider = FutureProvider.family<bool, String>((ref, postId) async {
  final dio = ref.watch(dioProvider);

  // Backend route: GET /v1/reactions/:postId
  final res = await dio.get('/reactions/$postId');

  if (res.data is Map) {
    final m = Map<String, dynamic>.from(res.data as Map);
    return (m['liked'] == true) || (m['isLiked'] == true);
  }

  return false;
});

final isSavedProvider = FutureProvider.family<bool, String>((ref, postId) async {
  final dio = ref.watch(dioProvider);

  // Backend route: GET /v1/saves/:postId
  final res = await dio.get('/saves/$postId');

  if (res.data is Map) {
    final m = Map<String, dynamic>.from(res.data as Map);
    return (m['saved'] == true) || (m['isSaved'] == true);
  }

  return false;
});

DateTime? _tryParseDate(Object? v) {
  if (v == null) return null;
  if (v is DateTime) return v.toLocal();
  final s = v.toString().trim();
  if (s.isEmpty) return null;
  return DateTime.tryParse(s)?.toLocal();
}

String _formatDateAbsolute(DateTime dt) {
  const months = <String>[
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  final m = months[(dt.month - 1).clamp(0, 11)];
  return '$m ${dt.day}, ${dt.year}';
}

class PostCard extends ConsumerWidget {
  const PostCard({super.key, required this.post, this.compact = false});
  final Post post;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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

    // Intentionally not used for UI: Aura rule is no public counts.
    // We keep the reads to avoid breaking any upstream logic, but we never display them.
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

    bool isOwner = false;
    try {
      isOwner = dyn.viewerIsOwner == true || dyn.isOwner == true;
    } catch (_) {}

    final showRepostTag =
        post.repostOfPostId != null && post.repostOfPostId!.trim().isNotEmpty;

    final text = (post.text).trim();

    DateTime? createdAt;
    try {
      createdAt = _tryParseDate(dyn.createdAt);
    } catch (_) {
      createdAt = null;
    }

    final titleText = displayName.isNotEmpty
        ? displayName
        : (handle.isNotEmpty ? '@$handle' : 'Member');

    final metaParts = <String>[];
    if (handle.isNotEmpty) metaParts.add('@$handle');
    if (createdAt != null) metaParts.add(_formatDateAbsolute(createdAt!));
    final metaLine = metaParts.join(' • ');

    return AuraCard(
      padding: EdgeInsets.all(compact ? AuraSpace.s14 : AuraSpace.s18),
      onTap: () => context.push('/posts/${post.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ---------- HEADER ----------
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (a != null)
                CircleAvatar(
                  radius: compact ? 15 : 16,
                  backgroundColor: const Color(0x332E2A26),
                  backgroundImage:
                      (avatarResolved != null) ? NetworkImage(avatarResolved) : null,
                  child: (avatarResolved == null)
                      ? Text(
                          titleText.isNotEmpty ? titleText[0].toUpperCase() : 'A',
                          style: AuraText.body,
                        )
                      : null,
                )
              else
                Container(
                  width: compact ? 30 : 32,
                  height: compact ? 30 : 32,
                  decoration: BoxDecoration(
                    color: AuraSurface.elevated,
                    shape: BoxShape.circle,
                    border: Border.all(color: AuraSurface.divider),
                  ),
                ),
              SizedBox(width: AuraSpace.s10),

              Expanded(
                child: InkWell(
                  onTap: () {
                    if (handle.isNotEmpty) context.push('/u/$handle');
                  },
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        titleText,
                        style: AuraText.body.copyWith(fontWeight: FontWeight.w700),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (metaLine.isNotEmpty)
                        Text(
                          metaLine,
                          style: AuraText.small.copyWith(color: AuraSurface.muted),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
              ),

              // Badges (status + visibility) + owner menu
              if ((status ?? '').isNotEmpty || (visibility ?? '').isNotEmpty) ...[
                const SizedBox(width: AuraSpace.s8),
                Wrap(
                  spacing: AuraSpace.s6,
                  children: [
                    if ((status ?? '').isNotEmpty)
                      _Badge(
                        text: _prettyEnum(status!),
                        tone: status!.toUpperCase().contains('DRAFT')
                            ? _BadgeTone.warn
                            : _BadgeTone.neutral,
                      ),
                    if ((visibility ?? '').isNotEmpty)
                      _Badge(
                        text: _prettyEnum(visibility!),
                        tone: (visibility ?? '').toLowerCase().contains('public')
                            ? _BadgeTone.good
                            : _BadgeTone.neutral,
                      ),
                  ],
                ),
              ],

              if (isOwner) ...[
                const SizedBox(width: AuraSpace.s6),
                PopupMenuButton<String>(
                  tooltip: 'Post options',
                  onSelected: (v) async {
                    if (v == 'edit') {
                      context.push('/compose?edit=${post.id}');
                      return;
                    }
                    if (v == 'delete') {
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Delete post?'),
                          content: const Text('This will remove the post.'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(ctx).pop(false),
                              child: const Text('Cancel'),
                            ),
                            FilledButton(
                              onPressed: () => Navigator.of(ctx).pop(true),
                              child: const Text('Delete'),
                            ),
                          ],
                        ),
                      );
                      if (ok == true) {
                        final dio = ref.read(dioProvider);
                        await dio.delete('/posts/${post.id}');
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Deleted')),
                          );
                        }
                      }
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'edit', child: Text('Edit')),
                    PopupMenuItem(value: 'delete', child: Text('Delete')),
                  ],
                  icon: const Icon(Icons.more_horiz, color: AuraSurface.muted),
                ),
              ],
            ],
          ),

          if (showRepostTag) ...[
            SizedBox(height: AuraSpace.s12),
            Text(
              'Repost',
              style: AuraText.small.copyWith(
                fontWeight: FontWeight.w700,
                color: AuraSurface.muted,
              ),
            ),
          ],

          // ---------- BODY ----------
          if (text.isNotEmpty) ...[
            SizedBox(height: AuraSpace.s12),
            Text(
              text,
              maxLines: compact ? 4 : null,
              overflow: compact ? TextOverflow.ellipsis : TextOverflow.visible,
              style: AuraText.body.copyWith(height: 1.55),
            ),
          ],

          // ---------- ATTACHMENT (MEDIA or LINK) ----------
          _finalAttachmentBlock(
            context,
            postId: post.id,
            mediaUrl: mediaUrl,
            mediaThumbUrl: mediaThumbUrl,
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

      Widget inner;

      if (isSvg) {
        inner = SvgPicture.network(
          mUrl,
          fit: BoxFit.contain,
          placeholderBuilder: (_) => const _MediaLoading(),
        );
      } else if (isVideo) {
        final thumb = (mediaThumbUrl ?? '').trim();

        final poster = (thumb.isNotEmpty)
            ? Image.network(
                thumb,
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
                errorBuilder: (_, __, ___) => const _MediaLoading(),
              )
            : Container(
                color: AuraSurface.elevated,
                alignment: Alignment.center,
                child: Text('Video', style: AuraText.muted),
              );

        final play = Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            color: const Color(0x66000000),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: AuraSurface.divider),
          ),
          child: const Icon(Icons.play_arrow, color: AuraSurface.ink),
        );

        inner = Stack(
          alignment: Alignment.center,
          children: [
            Positioned.fill(child: poster),
            play,
          ],
        );
      } else {
        // Images: prefer contain inside a calm frame to avoid hard crops.
        inner = Image.network(
          mUrl,
          fit: BoxFit.contain,
          width: double.infinity,
          height: double.infinity,
          loadingBuilder: (context, w, prog) {
            if (prog == null) return w;
            return const _MediaLoading();
          },
          errorBuilder: (_, __, ___) => const _MediaLoading(),
        );
      }

      final framed = ClipRRect(
        borderRadius: r,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: r,
            border: border,
            color: AuraSurface.elevated,
          ),
          child: ratio == null
              ? SizedBox(
                  height: isVideo ? 240 : 260,
                  child: inner,
                )
              : AspectRatio(
                  aspectRatio: ratio!,
                  child: inner,
                ),
        ),
      );

      // Hook point: later we can route to a dedicated viewer without changing
      // the post structure. For now, tap keeps the existing behavior (open post).
      return Padding(
        padding: const EdgeInsets.only(top: AuraSpace.s14),
        child: InkWell(
          borderRadius: r,
          onTap: () => context.push('/posts/$postId'),
          child: framed,
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
                      const SizedBox(height: AuraSpace.s10),
                      Text(
                        host,
                        style: AuraText.small.copyWith(color: AuraSurface.muted),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: AuraSpace.s10),
                      Text(
                        'Tap to copy link',
                        style: AuraText.small.copyWith(fontWeight: FontWeight.w700),
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
        bg = const Color(0x1F5B6CFF);
        fg = AuraSurface.ink;
        break;
      case _BadgeTone.warn:
        bg = const Color(0x22FFB020);
        fg = AuraSurface.ink;
        break;
      case _BadgeTone.neutral:
      default:
        bg = AuraSurface.elevated;
        fg = AuraSurface.muted;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AuraSpace.s10,
        vertical: AuraSpace.s6,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AuraSurface.divider),
      ),
      child: Text(
        text,
        style: AuraText.small.copyWith(color: fg, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _MediaLoading extends StatelessWidget {
  const _MediaLoading();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 220,
      alignment: Alignment.center,
      color: AuraSurface.elevated,
      child: const SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    );
  }
}

String _prettyEnum(String raw) {
  final s = raw
      .replaceAll('PostStatus.', '')
      .replaceAll('Visibility.', '')
      .replaceAll('_', ' ')
      .trim();
  if (s.isEmpty) return raw;
  return s.split(' ').map((w) {
    if (w.isEmpty) return w;
    return w[0].toUpperCase() + w.substring(1).toLowerCase();
  }).join(' ');
}