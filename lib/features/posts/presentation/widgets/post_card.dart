import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/auth/session_providers.dart';
import '../../../../core/institutions/institution_access_provider.dart';
import '../../../../core/media/aura_attachment_image.dart';
import '../../../../core/media/aura_media_viewer.dart';
import '../../../../core/net/dio_provider.dart';
import '../../../../core/ui/aura_card.dart';
import '../../../../core/ui/aura_platform_components.dart';
import '../../../../core/ui/aura_radius.dart';
import '../../../../core/ui/aura_space.dart';
import '../../../../core/ui/aura_surface.dart';
import '../../../../core/ui/aura_text.dart';
import '../../../../core/ui/aura_text_block.dart';
import '../../../feed/data/unified_feed_providers.dart';
import '../../../feed/domain/feed_item.dart' show FeedRouting;
import '../../../feed/domain/post.dart';
import '../../../saves/providers.dart';
import '../../data/reactions_repository.dart';
import 'post_card/post_card_models.dart';
import 'post_card/post_card_parts.dart';
import 'post_card/post_card_utils.dart';

String? _resolveAvatarUrl(WidgetRef ref, String? raw) {
  final url = (raw ?? '').trim();
  if (url.isEmpty) return null;

  if (url.startsWith('http://') || url.startsWith('https://')) return url;

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

String? _cleanNullableText(dynamic value) {
  final text = value?.toString().trim();
  if (text == null || text.isEmpty) return null;
  return text;
}

const Map<String, String> _translationLanguageLabels = {
  'en': 'English',
  'ur': 'Urdu',
  'ar': 'Arabic',
  'es': 'Spanish',
  'fr': 'French',
  'de': 'German',
  'it': 'Italian',
  'pt': 'Portuguese',
  'tr': 'Turkish',
  'fa': 'Persian',
  'hi': 'Hindi',
  'bn': 'Bengali',
  'zh': 'Chinese',
  'ja': 'Japanese',
  'ko': 'Korean',
  'ru': 'Russian',
};

String _languageLabel(String code) {
  final key = code.trim().toLowerCase();
  return _translationLanguageLabels[key] ?? key.toUpperCase();
}

String _defaultTranslationLanguage(BuildContext context) {
  final code = Localizations.localeOf(
    context,
  ).languageCode.trim().toLowerCase();
  if (_translationLanguageLabels.containsKey(code)) return code;
  return 'en';
}

Map<String, dynamic> _asMap(dynamic v) {
  if (v is Map<String, dynamic>) return v;
  if (v is Map) return Map<String, dynamic>.from(v);
  return <String, dynamic>{};
}

String _readString(dynamic v) => (v ?? '').toString().trim();

String _readNestedString(
  Map<String, dynamic> root,
  List<List<String>> candidatePaths,
) {
  for (final path in candidatePaths) {
    dynamic cur = root;
    var ok = true;
    for (final key in path) {
      if (cur is Map && cur.containsKey(key)) {
        cur = cur[key];
      } else {
        ok = false;
        break;
      }
    }
    if (!ok) continue;
    final value = _readString(cur);
    if (value.isNotEmpty) return value;
  }
  return '';
}

String _normalizeVisibilityLabel(String? raw) {
  final v = (raw ?? '').trim().toUpperCase();
  switch (v) {
    case 'FOLLOWERS':
      return 'Followers';
    case 'PRIVATE':
      return 'Private';
    case 'PUBLIC':
      return 'Public';
    default:
      return '';
  }
}

IconData _visibilityIcon(String? raw) {
  final v = (raw ?? '').trim().toUpperCase();
  switch (v) {
    case 'FOLLOWERS':
      return Icons.group_outlined;
    case 'PRIVATE':
      return Icons.lock_outline;
    case 'PUBLIC':
    default:
      return Icons.public_outlined;
  }
}


class _ViewerIdentity {
  const _ViewerIdentity({required this.id, required this.handle});

  final String id;
  final String handle;
}

final viewerIdentityProvider = FutureProvider<_ViewerIdentity?>((ref) async {
  final dio = ref.read(dioProvider);

  try {
    final res = await dio.get('/users/me');
    final root = _asMap(res.data);
    final payload = root['data'] is Map ? _asMap(root['data']) : root;

    final id = _readNestedString(payload, [
      ['id'],
      ['user', 'id'],
      ['profile', 'id'],
    ]);

    final handle = _readNestedString(payload, [
      ['handle'],
      ['user', 'handle'],
      ['profile', 'handle'],
    ]);

    if (id.isEmpty && handle.isEmpty) return null;
    return _ViewerIdentity(id: id, handle: handle);
  } catch (_) {
    return null;
  }
});

/// Returns the reaction actor that should drive Like/Reply on the current
/// route. Determined by the route path so a user with institution-speaker
/// rights still likes as themselves while browsing in member shell. Inside
/// the institution shell (`/institution/...`) the active institution acts
/// as the actor.
///
/// Falls back to the personal user actor whenever institution identity is
/// not loaded or the route is not within the institution shell.
ReactionActor activeReactionActor(BuildContext context, WidgetRef ref) {
  final path = GoRouterState.of(context).uri.path;
  if (!path.startsWith('/institution/') && path != '/institution') {
    return const ReactionActor.user();
  }
  final identity = ref.watch(institutionIdentityProvider);
  if (identity == null || identity.id.isEmpty) {
    return const ReactionActor.user();
  }
  return ReactionActor.institution(identity.id);
}

final isSavedProvider = FutureProvider.family<bool, String>((
  ref,
  postId,
) async {
  // /saves/for/:pid is auth-only. Signed-out visitors cannot have saves —
  // short-circuit instead of firing a guaranteed 401 on every card render.
  final authed = ref.watch(isAuthedProvider);
  if (!authed) return false;
  final repo = ref.read(savesRepositoryProvider);
  final pid = postId.trim();
  if (pid.isEmpty) return false;

  try {
    return await repo.isSaved(pid);
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
  bool _translationBusy = false;
  bool _showTranslation = false;
  String? _translatedText;
  String? _translationError;
  String? _translationTargetLanguage;

  void _toggleExpanded() => setState(() => _expanded = !_expanded);

  Future<void> _pickTranslationLanguage(BuildContext context) async {
    final current =
        (_translationTargetLanguage ?? _defaultTranslationLanguage(context))
            .toLowerCase();

    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      backgroundColor: AuraSurface.page,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AuraSpace.s16,
              AuraSpace.s8,
              AuraSpace.s16,
              AuraSpace.s20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Translate to',
                  style: AuraText.body.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: AuraSpace.s12),
                Wrap(
                  spacing: AuraSpace.s10,
                  runSpacing: AuraSpace.s10,
                  children: _translationLanguageLabels.entries.map((entry) {
                    final active = entry.key == current;
                    return InkWell(
                      onTap: () => Navigator.of(ctx).pop(entry.key),
                      borderRadius: BorderRadius.circular(AuraRadius.pill),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AuraSpace.s12,
                          vertical: AuraSpace.s8,
                        ),
                        decoration: BoxDecoration(
                          color: active
                              ? AuraSurface.elevated
                              : AuraSurface.page,
                          borderRadius: BorderRadius.circular(AuraRadius.pill),
                          border: Border.all(color: AuraSurface.divider),
                        ),
                        child: Text(
                          entry.value,
                          style: AuraText.small.copyWith(
                            fontWeight: active
                                ? FontWeight.w700
                                : FontWeight.w600,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (!mounted || selected == null || selected.trim().isEmpty) return;
    setState(() {
      _translationTargetLanguage = selected.trim().toLowerCase();
      _translationError = null;
    });
  }

  Future<void> _translatePostText(BuildContext context, String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || _translationBusy) return;

    final target =
        (_translationTargetLanguage ?? _defaultTranslationLanguage(context))
            .toLowerCase();

    setState(() {
      _translationBusy = true;
      _translationError = null;
    });

    try {
      final dio = ref.read(dioProvider);
      final response = await dio.post(
        '/composition/translate',
        data: {'text': trimmed, 'targetLanguage': target},
      );

      final root = _asMap(response.data);
      final data = _asMap(root['data']);

      final translatedText = _readString(
        root['translatedText'] ??
            root['text'] ??
            data['translatedText'] ??
            data['text'],
      );

      if (translatedText.isEmpty) {
        throw Exception('Translation response was empty.');
      }

      if (!mounted) return;

      setState(() {
        _translatedText = translatedText;
        _showTranslation = true;
        _translationTargetLanguage =
            _readString(
              root['targetLanguage'] ?? data['targetLanguage'] ?? target,
            ).toLowerCase().isEmpty
            ? target
            : _readString(
                root['targetLanguage'] ?? data['targetLanguage'] ?? target,
              ).toLowerCase();
      });
    } on DioException catch (e) {
      if (!context.mounted) return;
      final status = e.response?.statusCode;
      final authRequired = status == 401 || status == 403;
      final message = authRequired
          ? 'Sign in to translate this post.'
          : 'Translation could not run right now.';
      setState(() {
        _translationError = message;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(authRequired ? 'Sign in to use translation.' : message),
          action: authRequired
              ? SnackBarAction(
                  label: 'Sign in',
                  onPressed: () => context.go('/login'),
                )
              : null,
        ),
      );
    } catch (_) {
      if (!context.mounted) return;
      const message = 'Translation could not run right now.';
      setState(() {
        _translationError = message;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text(message)));
    } finally {
      if (mounted) {
        setState(() => _translationBusy = false);
      }
    }
  }

  String? _resolveMediaUrl(WidgetRef ref, String? raw) {
    if (raw == null) return null;
    final s = raw.trim();
    if (s.isEmpty) return null;

    if (s.startsWith('http://') || s.startsWith('https://')) return s;
    if (s.startsWith('//')) return 'https:$s';

    const uploadsBase = String.fromEnvironment(
      'UPLOADS_BASE_URL',
      defaultValue: 'https://uploads.auraplatform.org',
    );

    var base = uploadsBase.trim();
    while (base.endsWith('/')) {
      base = base.substring(0, base.length - 1);
    }

    if (s.startsWith('/')) return '$base$s';
    return '$base/$s';
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

  List<PostCardResolvedMediaItem> _extractStructuredMedia(dynamic dyn) {
    final out = <PostCardResolvedMediaItem>[];

    List<dynamic> rawList = const [];
    try {
      final media = dyn.media;
      if (media is List) rawList = media;
    } catch (_) {}

    if (rawList.isEmpty) {
      try {
        final mediaItems = dyn.mediaItems;
        if (mediaItems is List) rawList = mediaItems;
      } catch (_) {}
    }

    for (final item in rawList) {
      if (item is! Map) continue;
      final m = Map<String, dynamic>.from(item);

      final id = (m['id'] ?? '').toString().trim();
      final type = (m['type'] ?? m['kind'] ?? m['mediaType'] ?? 'IMAGE')
          .toString()
          .trim()
          .toUpperCase();

      final url = _resolveMediaUrl(
        ref,
        (m['displayUrl'] ?? m['playbackUrl'] ?? m['url'] ?? m['publicUrl'])
            ?.toString(),
      );

      final thumbUrl = _resolveMediaUrl(
        ref,
        (m['thumbnailUrl'] ?? m['thumbUrl'] ?? m['thumb'])?.toString(),
      );

      final caption = (m['caption'] ?? '').toString().trim();
      final width = m['width'] is int
          ? m['width'] as int
          : int.tryParse('${m['width'] ?? ''}');
      final height = m['height'] is int
          ? m['height'] as int
          : int.tryParse('${m['height'] ?? ''}');
      final duration = m['duration'] is int
          ? m['duration'] as int
          : int.tryParse('${m['duration'] ?? ''}');
      final editDisclosure = m['editDisclosure'] == true;

      if ((url ?? '').isEmpty && (thumbUrl ?? '').isEmpty) continue;

      out.add(
        PostCardResolvedMediaItem(
          id: id.isEmpty ? '${out.length}' : id,
          type: type,
          url: url,
          thumbUrl: thumbUrl,
          caption: caption.isEmpty ? null : caption,
          width: width,
          height: height,
          duration: duration,
          editDisclosure: editDisclosure,
        ),
      );
    }

    if (out.isNotEmpty) return out;

    String? mediaUrl;
    String? mediaThumbUrl;
    String? mediaType;
    int? mediaWidth;
    int? mediaHeight;
    int? mediaDuration;
    String? caption;

    try {
      mediaUrl = (dyn.mediaUrl as String?)?.trim();
      if (mediaUrl != null && mediaUrl.isEmpty) mediaUrl = null;
    } catch (_) {}

    try {
      mediaThumbUrl = (dyn.mediaThumbUrl as String?)?.trim();
      if (mediaThumbUrl != null && mediaThumbUrl.isEmpty) mediaThumbUrl = null;
    } catch (_) {}

    try {
      mediaType = (dyn.mediaType as Object?)?.toString();
    } catch (_) {}

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

    try {
      mediaDuration = dyn.mediaDuration as int?;
    } catch (_) {
      try {
        mediaDuration = int.tryParse((dyn.mediaDuration ?? '').toString());
      } catch (_) {}
    }

    try {
      caption = (dyn.caption as String?)?.trim();
      if (caption != null && caption.isEmpty) caption = null;
    } catch (_) {}

    final resolvedMediaUrl = _resolveMediaUrl(ref, mediaUrl);
    final resolvedMediaThumbUrl = _resolveMediaUrl(ref, mediaThumbUrl);

    if ((resolvedMediaUrl ?? '').isEmpty &&
        (resolvedMediaThumbUrl ?? '').isEmpty) {
      return out;
    }

    out.add(
      PostCardResolvedMediaItem(
        id: 'legacy',
        type: (mediaType ?? 'IMAGE').toUpperCase(),
        url: resolvedMediaUrl,
        thumbUrl: resolvedMediaThumbUrl,
        caption: caption,
        width: mediaWidth,
        height: mediaHeight,
        duration: mediaDuration,
        editDisclosure: false,
      ),
    );

    return out;
  }

  String _authorContextLine(dynamic author) {
    final candidates = <String?>[];

    try {
      candidates.add((author?.contextLine as String?)?.trim());
    } catch (_) {}

    try {
      candidates.add((author?.headline as String?)?.trim());
    } catch (_) {}

    try {
      candidates.add((author?.tagline as String?)?.trim());
    } catch (_) {}

    try {
      candidates.add((author?.bio as String?)?.trim());
    } catch (_) {}

    for (final item in candidates) {
      final s = (item ?? '').trim();
      if (s.isNotEmpty) return s;
    }

    return '';
  }

  String _authorId(dynamic author) {
    try {
      return _readString(author?.id);
    } catch (_) {
      return '';
    }
  }

  bool _isOwnPost(dynamic author, _ViewerIdentity? viewer) {
    if (viewer == null) return false;

    final authorId = _authorId(author);
    if (authorId.isNotEmpty && viewer.id.isNotEmpty && authorId == viewer.id) {
      return true;
    }

    try {
      final authorHandle = _readString(author?.handle).toLowerCase();
      final viewerHandle = viewer.handle.toLowerCase();
      if (authorHandle.isNotEmpty &&
          viewerHandle.isNotEmpty &&
          authorHandle == viewerHandle) {
        return true;
      }
    } catch (_) {}

    return false;
  }

  Future<void> _deletePost(BuildContext context, String postId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Delete work'),
          content: const Text(
            'This will remove the work from the record. This action cannot be undone.',
          ),
          actions: [
            AuraGhostButton(
              label: 'Cancel',
              onPressed: () => Navigator.of(ctx).pop(false),
            ),
            AuraPrimaryButton(
              label: 'Delete',
              onPressed: () => Navigator.of(ctx).pop(true),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !context.mounted) return;

    try {
      final dio = ref.read(dioProvider);
      await dio.delete('/posts/$postId');

      if (!context.mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Work deleted')));

      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/home');
      }
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Could not delete post')));
    }
  }

  Future<void> _showPostMenu(
    BuildContext context, {
    required String postId,
    required String postUrl,
    required String? handle,
    required bool isOwnPost,
  }) async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      backgroundColor: AuraSurface.page,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AuraSpace.s16,
              AuraSpace.s8,
              AuraSpace.s16,
              AuraSpace.s20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Post-content editing isn't shipped yet — we hide the
                // affordance rather than showing it and snack-barring a
                // "not wired yet" message. Re-enable here when the
                // PATCH /v1/posts/:id surface ships.
                if (isOwnPost)
                  PostCardMenuActionTile(
                    icon: Icons.delete_outline,
                    label: 'Delete work',
                    onTap: () => Navigator.of(ctx).pop('delete_post'),
                  ),
                PostCardMenuActionTile(
                  icon: Icons.article_outlined,
                  label: 'Open work',
                  onTap: () => Navigator.of(ctx).pop('open_post'),
                ),
                if ((handle ?? '').trim().isNotEmpty)
                  PostCardMenuActionTile(
                    icon: Icons.person_outline,
                    label: 'Open profile',
                    onTap: () => Navigator.of(ctx).pop('open_profile'),
                  ),
                PostCardMenuActionTile(
                  icon: Icons.link_outlined,
                  label: 'Copy link',
                  onTap: () => Navigator.of(ctx).pop('copy_link'),
                ),
                PostCardMenuActionTile(
                  icon: Icons.work_outline,
                  label: 'Share to LinkedIn',
                  onTap: () => Navigator.of(ctx).pop('share_linkedin'),
                ),
                PostCardMenuActionTile(
                  icon: Icons.email_outlined,
                  label: 'Share to Email',
                  onTap: () => Navigator.of(ctx).pop('share_email'),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (!context.mounted || selected == null) return;

    switch (selected) {
      case 'delete_post':
        await _deletePost(context, postId);
        break;
      case 'open_post':
        context.push(FeedRouting.adaptTargetRoute(
          '/posts/$postId',
          currentPath: GoRouterState.of(context).uri.path,
        ));
        break;
      case 'open_profile':
        if ((handle ?? '').trim().isNotEmpty) {
          context.push(FeedRouting.adaptProfileRoute(
                '/u/${handle!.trim()}',
                currentPath: GoRouterState.of(context).uri.path,
              ) ??
              '/u/${handle.trim()}');
        }
        break;
      case 'copy_link':
        await copyToClipboard(context, postUrl, message: 'Work link copied');
        break;
      case 'share_linkedin':
        await openExternalUrl(
          context,
          linkedInShareUrl(postUrl),
          fallbackCopyMessage: 'LinkedIn share link copied',
        );
        break;
      case 'share_email':
        await openExternalUrl(
          context,
          emailShareUrl(postUrl),
          fallbackCopyMessage: 'Email share link copied',
        );
        break;
    }
  }

  void _openProfile(BuildContext context, String handle) {
    final h = handle.trim();
    if (h.isEmpty) return;
    context.push(FeedRouting.adaptProfileRoute(
          '/u/$h',
          currentPath: GoRouterState.of(context).uri.path,
        ) ??
        '/u/$h');
  }

  Future<void> _openMediaViewer(
    BuildContext context,
    List<PostCardResolvedMediaItem> items,
    int initialIndex,
  ) async {
    await showAuraMediaViewer(
      context,
      initialIndex: initialIndex,
      items: [
        for (final m in items)
          AuraViewerItem(
            originalUrl: m.playableUrl,
            isVideo: m.isVideo,
            caption: m.caption,
            intrinsicWidth: m.width,
            intrinsicHeight: m.height,
            downloadContext: 'post-media',
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    final compact = widget.compact;

    final a = post.author;
    final displayName = (a?.displayName ?? '').trim();
    final handle = (a?.handle ?? '').trim();
    final avatarResolved = _resolveAvatarUrl(ref, a?.avatarUrl);
    final contextLine = _authorContextLine(a);

    final viewerAsync = ref.watch(viewerIdentityProvider);
    final viewer = viewerAsync.valueOrNull;
    final isOwnPost = _isOwnPost(a, viewer);

    final dyn = post as dynamic;

    String? status;
    try {
      status = (dyn.status as Object?)?.toString();
    } catch (_) {}

    String? visibility;
    try {
      visibility = (dyn.visibility as Object?)?.toString();
    } catch (_) {}

    String? linkUrl;
    String? linkTitle;
    String? linkSubtitle;
    String? linkThumbUrl;

    try {
      linkUrl = _cleanNullableText(dyn.linkUrl);
    } catch (_) {
      try {
        linkUrl = _cleanNullableText(dyn.url);
      } catch (_) {}
    }

    try {
      linkTitle = _cleanNullableText(dyn.linkTitle);
    } catch (_) {}

    try {
      linkSubtitle = _cleanNullableText(dyn.linkSubtitle);
    } catch (_) {
      try {
        linkSubtitle = _cleanNullableText(dyn.linkDescription);
      } catch (_) {}
    }

    try {
      linkThumbUrl = _cleanNullableText(dyn.linkThumbUrl);
    } catch (_) {
      try {
        linkThumbUrl = _cleanNullableText(dyn.linkImageUrl);
      } catch (_) {}
    }

    final createdAt = post.createdAt;
    final createdLabel =
        '${createdAt.year.toString().padLeft(4, '0')}-${createdAt.month.toString().padLeft(2, '0')}-${createdAt.day.toString().padLeft(2, '0')}';

    final postId = post.id;
    final postUrl = canonicalPostUrl(postId);
    final text = (post.text).trim();
    _translationTargetLanguage ??= _defaultTranslationLanguage(context);

    final headerName = displayName.isNotEmpty
        ? displayName
        : (handle.isNotEmpty ? '@$handle' : '—');

    final visibilityLabel = _normalizeVisibilityLabel(visibility);
    final visibilityMetaIcon = _visibilityIcon(visibility);

    final bodyTextStyle = AuraText.body.copyWith(height: 1.42);
    final collapsedLines = compact ? 4 : 7;

    final mediaItems = _extractStructuredMedia(dyn);

    return AuraCard(
      child: Padding(
        padding: EdgeInsets.all(compact ? AuraSpace.s12 : AuraSpace.s14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PostCardIdentityHeader(
              displayName: headerName,
              handle: handle,
              contextLine: contextLine,
              avatarUrl: avatarResolved,
              createdLabel: createdLabel,
              visibilityLabel: visibilityLabel,
              visibilityIcon: visibilityMetaIcon,
              compact: compact,
              onProfileTap: handle.trim().isNotEmpty
                  ? () => _openProfile(context, handle)
                  : null,
              onMenuTap: () => _showPostMenu(
                context,
                postId: postId,
                postUrl: postUrl,
                handle: handle,
                isOwnPost: isOwnPost,
              ),
            ),
            if (widget.showAdminBadges) ...[
              const SizedBox(height: AuraSpace.s10),
              Wrap(
                spacing: AuraSpace.s10,
                runSpacing: AuraSpace.s10,
                children: [
                  if ((status ?? '').trim().isNotEmpty)
                    PostCardBadge(
                      text: (status ?? '').toUpperCase(),
                      tone: (status ?? '').toLowerCase().contains('published')
                          ? PostCardBadgeTone.good
                          : PostCardBadgeTone.warn,
                    ),
                  if ((visibility ?? '').trim().isNotEmpty)
                    PostCardBadge(
                      text: (visibility ?? '').toUpperCase(),
                      tone: PostCardBadgeTone.neutral,
                    ),
                ],
              ),
            ],
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
                      AuraTextBlock(
                        text,
                        style: bodyTextStyle,
                        maxLines: maxLines,
                        overflow: maxLines == null
                            ? TextOverflow.visible
                            : TextOverflow.ellipsis,
                        // Discourse body — selectable so the work can be
                        // quoted, cited, and preserved. Safe here: the
                        // PostCard is never wrapped in a tap-to-navigate
                        // target at any of its call sites.
                        selectable: true,
                        semanticsLabel: 'Post body',
                      ),
                      if (showToggle && !_expanded) ...[
                        const SizedBox(height: AuraSpace.s8),
                        InkWell(
                          onTap: _toggleExpanded,
                          borderRadius: BorderRadius.circular(AuraRadius.pill),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AuraSpace.s10,
                              vertical: AuraSpace.s6,
                            ),
                            child: Text(
                              'Open',
                              style: AuraText.small.copyWith(
                                fontWeight: FontWeight.w800,
                                color: AuraSurface.muted,
                              ),
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: AuraSpace.s10),
                      Wrap(
                        spacing: AuraSpace.s10,
                        runSpacing: AuraSpace.s10,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          InkWell(
                            onTap: _translationBusy
                                ? null
                                : () => _translatePostText(context, text),
                            borderRadius: BorderRadius.circular(
                              AuraRadius.pill,
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AuraSpace.s6,
                                vertical: AuraSpace.s6,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (_translationBusy) ...[
                                    const SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    ),
                                    const SizedBox(width: AuraSpace.s8),
                                  ],
                                  Text(
                                    _translationBusy
                                        ? 'Translating...'
                                        : (_showTranslation
                                              ? 'Refresh translation'
                                              : 'Translate'),
                                    style: AuraText.small.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: AuraSurface.muted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          InkWell(
                            onTap: () => _pickTranslationLanguage(context),
                            borderRadius: BorderRadius.circular(
                              AuraRadius.pill,
                            ),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AuraSpace.s10,
                                vertical: AuraSpace.s6,
                              ),
                              decoration: BoxDecoration(
                                color: AuraSurface.elevated,
                                borderRadius: BorderRadius.circular(
                                  AuraRadius.pill,
                                ),
                                border: Border.all(color: AuraSurface.divider),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.translate,
                                    size: 14,
                                    color: AuraSurface.muted,
                                  ),
                                  const SizedBox(width: AuraSpace.s6),
                                  Text(
                                    _languageLabel(
                                      _translationTargetLanguage ??
                                          _defaultTranslationLanguage(context),
                                    ),
                                    style: AuraText.small.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (_showTranslation)
                            InkWell(
                              onTap: () {
                                setState(() {
                                  _showTranslation = false;
                                  _translationError = null;
                                });
                              },
                              borderRadius: BorderRadius.circular(
                                AuraRadius.pill,
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AuraSpace.s6,
                                  vertical: AuraSpace.s6,
                                ),
                                child: Text(
                                  'Hide translation',
                                  style: AuraText.small.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: AuraSurface.muted,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      if ((_translationError ?? '').trim().isNotEmpty) ...[
                        const SizedBox(height: AuraSpace.s8),
                        Text(
                          _translationError!,
                          style: AuraText.small.copyWith(
                            color: AuraSurface.warnInk,
                          ),
                        ),
                      ],
                      if (_showTranslation &&
                          (_translatedText ?? '').trim().isNotEmpty) ...[
                        const SizedBox(height: AuraSpace.s12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(AuraSpace.s12),
                          decoration: BoxDecoration(
                            color: AuraSurface.elevated,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AuraSurface.divider),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Translation · ${_languageLabel(_translationTargetLanguage ?? _defaultTranslationLanguage(context))}',
                                style: AuraText.small.copyWith(
                                  color: AuraSurface.muted,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: AuraSpace.s8),
                              AuraTextBlock(
                                _translatedText!,
                                style: bodyTextStyle,
                                selectable: true,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  );
                },
              ),
            ],
            _finalAttachmentBlock(
              context,
              postId: post.id,
              mediaItems: mediaItems,
              linkUrl: linkUrl,
              linkTitle: linkTitle,
              linkSubtitle: linkSubtitle,
              linkThumbUrl: linkThumbUrl,
              onOpenMediaAt: (index) =>
                  _openMediaViewer(context, mediaItems, index),
            ),
            const SizedBox(height: AuraSpace.s12),
            _ActionRow(postId: post.id),
          ],
        ),
      ),
    );
  }

  Widget _finalAttachmentBlock(
    BuildContext context, {
    required String postId,
    required List<PostCardResolvedMediaItem> mediaItems,
    required String? linkUrl,
    required String? linkTitle,
    required String? linkSubtitle,
    required String? linkThumbUrl,
    required ValueChanged<int> onOpenMediaAt,
  }) {
    final lUrl = (linkUrl ?? '').trim();

    if (mediaItems.isEmpty && lUrl.isEmpty) return const SizedBox.shrink();

    if (mediaItems.isNotEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: AuraSpace.s14),
        child: PostCardMediaBlock(
          items: mediaItems,
          postId: postId,
          maxHeight: _mediaMaxHeight(context),
          onOpenMediaAt: onOpenMediaAt,
        ),
      );
    }

    final border = Border.all(color: AuraSurface.divider);
    final radius = BorderRadius.circular(16);

    final uri = Uri.tryParse(lUrl);
    final host = (uri != null && uri.host.trim().isNotEmpty) ? uri.host : lUrl;

    Widget? thumb;
    final t = (linkThumbUrl ?? '').trim();
    if (t.isNotEmpty) {
      // External-link OG thumbnail. No Aura media id; cache key falls
      // back to URL inside AuraAttachmentImage. Empty error widget
      // matches the previous SizedBox.shrink fallback.
      thumb = ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: AuraAttachmentImage(
          url: t,
          width: 72,
          height: 72,
          fit: BoxFit.cover,
          errorWidget: (_) => const SizedBox.shrink(),
        ),
      );
    }

    final title = (linkTitle ?? '').trim().isNotEmpty
        ? linkTitle!.trim()
        : host;
    final subtitle = (linkSubtitle ?? '').trim();

    return Padding(
      padding: const EdgeInsets.only(top: AuraSpace.s14),
      child: InkWell(
        borderRadius: radius,
        onTap: () => openExternalUrl(
          context,
          lUrl,
          fallbackCopyMessage: 'Could not open link. Link copied instead.',
        ),
        onLongPress: () =>
            copyToClipboard(context, lUrl, message: 'Link copied'),
        child: ClipRRect(
          borderRadius: radius,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: radius,
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
                        style: AuraText.body.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
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
                        style: AuraText.small.copyWith(
                          color: AuraSurface.muted,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: AuraSpace.s6),
                      Row(
                        children: [
                          const Icon(
                            Icons.open_in_new,
                            size: 14,
                            color: AuraSurface.muted,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Tap to open · Hold to copy',
                              style: AuraText.small.copyWith(
                                color: AuraSurface.muted,
                              ),
                            ),
                          ),
                        ],
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

class _ActionRow extends ConsumerStatefulWidget {
  const _ActionRow({required this.postId});

  final String postId;

  @override
  ConsumerState<_ActionRow> createState() => _ActionRowState();
}

class _ActionRowState extends ConsumerState<_ActionRow> {
  bool _likeBusy = false;
  bool _saveBusy = false;
  bool _repostBusy = false;
  bool _replyBusy = false;

  // Optimistic overrides for the Like pill. Set on tap, cleared after the
  // canonical provider re-fetch lands or on backend failure.
  bool? _optimisticLiked;
  int? _optimisticLikeCount;

  // Optimistic Save state — flips immediately on tap so the pill reflects
  // the intended state while the request is in flight. Cleared on success
  // (provider re-fetch is the truth) or on failure (revert).
  bool? _optimisticSaved;

  void _showError(BuildContext context, String message) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final postId = widget.postId;
    final isAuthed = ref.watch(isAuthedProvider);
    final saved = ref.watch(isSavedProvider(postId));
    final actor = activeReactionActor(context, ref);
    final target = PostReactionTarget(postId);
    final reactionKey = ReactionStateKey(target: target, actor: actor);
    final reactionAsync = ref.watch(reactionStateProvider(reactionKey));

    void goSignIn() {
      final redirect = GoRouterState.of(context).uri.toString();
      context.go(
        '/login?redirect=${Uri.encodeComponent(redirect)}',
      );
    }

    Future<void> toggleLike() async {
      if (!isAuthed) {
        goSignIn();
        return;
      }
      if (_likeBusy) return;

      final providerLiked = reactionAsync.maybeWhen(
        data: (s) => s.liked,
        orElse: () => false,
      );
      final providerCount = reactionAsync.maybeWhen(
        data: (s) => s.likeCount,
        orElse: () => 0,
      );
      final nextLiked = !providerLiked;
      final nextCount = (providerCount + (nextLiked ? 1 : -1))
          .clamp(0, 1 << 31)
          .toInt();

      setState(() {
        _likeBusy = true;
        _optimisticLiked = nextLiked;
        _optimisticLikeCount = nextCount;
      });

      try {
        final repo = ref.read(reactionsRepositoryProvider);
        final result = await repo.toggle(target, actor: actor);
        if (!mounted) return;
        setState(() {
          _optimisticLiked = result.liked;
          _optimisticLikeCount = result.likeCount;
        });
        ref.invalidate(reactionStateProvider(reactionKey));
        invalidateUnifiedFeedSurfaces(ref);
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _optimisticLiked = null;
          _optimisticLikeCount = null;
        });
        if (!context.mounted) return;
        if (e is DioException && e.response?.statusCode == 403) {
          _showError(
            context,
            'Only institution speakers can react as institution.',
          );
        } else {
          _showError(context, 'Could not update like');
        }
      } finally {
        if (mounted) setState(() => _likeBusy = false);
      }
    }

    String composeReplyTarget() {
      final base = '/compose?replyTo=$postId&surface=dm';
      if (actor.isInstitution) {
        return '$base&asInstitution=1'
            '&institutionId=${actor.actorInstitutionId}';
      }
      return base;
    }

    Future<void> openReply() async {
      if (!isAuthed) {
        goSignIn();
        return;
      }
      if (_replyBusy) return;
      setState(() => _replyBusy = true);
      try {
        final result = await context.push<dynamic>(composeReplyTarget());
        if (result == true) {
          invalidateUnifiedFeedSurfaces(ref);
        }
      } finally {
        if (mounted) setState(() => _replyBusy = false);
      }
    }

    Future<void> toggleSave() async {
      if (!isAuthed) {
        goSignIn();
        return;
      }
      if (_saveBusy) return;

      final providerSavedNow = saved.maybeWhen<bool>(
        data: (v) => v,
        orElse: () => false,
      );
      final currentSaved = _optimisticSaved ?? providerSavedNow;
      final nextSaved = !currentSaved;

      setState(() {
        _saveBusy = true;
        _optimisticSaved = nextSaved;
      });

      try {
        final repo = ref.read(savesRepositoryProvider);
        await repo.toggle(postId);
        if (!mounted) return;
        // Provider re-fetch is the truth after this point.
        ref.invalidate(isSavedProvider(postId));
        ref.invalidate(savedPostsProvider);
        setState(() => _optimisticSaved = null);
      } catch (_) {
        if (!mounted) return;
        setState(() => _optimisticSaved = null);
        if (!context.mounted) return;
        _showError(context, 'Could not update save');
      } finally {
        if (mounted) setState(() => _saveBusy = false);
      }
    }

    Future<void> repost() async {
      if (!isAuthed) {
        goSignIn();
        return;
      }
      if (_repostBusy) return;
      final controller = TextEditingController();
      setState(() => _repostBusy = true);

      try {
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
                AuraGhostButton(
                  label: 'Cancel',
                  onPressed: () => Navigator.of(ctx).pop(false),
                ),
                AuraPrimaryButton(
                  label: 'Repost',
                  onPressed: () => Navigator.of(ctx).pop(true),
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

        // Phase-3 actor-aware repost: forward asInstitution + institutionId
        // when the active context is the institution shell.
        if (actor.isInstitution) {
          payload['asInstitution'] = true;
          payload['institutionId'] = actor.actorInstitutionId;
        }
        await dio.post('/posts/$postId/repost', data: payload);

        invalidateUnifiedFeedSurfaces(ref);

        if (!context.mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Work reposted')));
      } catch (_) {
        _showError(context, 'Could not repost');
      } finally {
        controller.dispose();
        if (mounted) setState(() => _repostBusy = false);
      }
    }

    Future<void> share() async {
      await showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        isScrollControlled: true,
        builder: (ctx) {
          return SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                16,
                10,
                16,
                24 + MediaQuery.of(ctx).viewInsets.bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Share', style: AuraText.title),
                  const SizedBox(height: AuraSpace.s10),
                  const Text('Share this work.', style: AuraText.body),
                  const SizedBox(height: AuraSpace.s14),
                  Wrap(
                    spacing: AuraSpace.s10,
                    runSpacing: AuraSpace.s10,
                    children: [
                      AuraSecondaryButton(
                        label: 'Copy link',
                        icon: Icons.link_outlined,
                        onPressed: () async {
                          await copyToClipboard(
                            ctx,
                            canonicalPostUrl(postId),
                            message: 'Work link copied',
                          );
                        },
                      ),
                      AuraSecondaryButton(
                        label: 'Share to LinkedIn',
                        icon: Icons.work_outline,
                        onPressed: () async {
                          await openExternalUrl(
                            ctx,
                            linkedInShareUrl(canonicalPostUrl(postId)),
                            fallbackCopyMessage: 'LinkedIn share link copied',
                          );
                        },
                      ),
                      AuraSecondaryButton(
                        label: 'Share to Email',
                        icon: Icons.email_outlined,
                        onPressed: () async {
                          await openExternalUrl(
                            ctx,
                            emailShareUrl(canonicalPostUrl(postId)),
                            fallbackCopyMessage: 'Email share link copied',
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: AuraSpace.s12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: AuraGhostButton(
                      label: 'Done',
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    }

    final providerLiked = reactionAsync.maybeWhen(
      data: (s) => s.liked,
      orElse: () => false,
    );
    final providerLikeCount = reactionAsync.maybeWhen(
      data: (s) => s.likeCount,
      orElse: () => 0,
    );
    final liked = _optimisticLiked ?? providerLiked;
    final likeCount = _optimisticLikeCount ?? providerLikeCount;
    final likeLabel = (() {
      final base = liked ? 'Liked' : 'Like';
      return likeCount > 0 ? '$base · $likeCount' : base;
    })();

    final providerSaved = saved.maybeWhen<bool>(
      data: (v) => v,
      orElse: () => false,
    );
    final saveEffective = _optimisticSaved ?? providerSaved;

    return Wrap(
      spacing: AuraSpace.s8,
      runSpacing: AuraSpace.s8,
      children: [
        AuraActionPill(
          icon: liked ? Icons.favorite : Icons.favorite_border,
          label: likeLabel,
          onTap: toggleLike,
          active: liked,
        ),
        AuraActionPill(
          icon: Icons.reply_outlined,
          label: 'Respond',
          onTap: openReply,
        ),
        AuraActionPill(icon: Icons.repeat, label: 'Repost', onTap: repost),
        AuraActionPill(
          icon: saveEffective ? Icons.bookmark : Icons.bookmark_border,
          label: saveEffective ? 'Saved' : 'Save',
          onTap: toggleSave,
          active: saveEffective,
        ),
        AuraActionPill(
          icon: Icons.share_outlined,
          label: 'Share',
          onTap: share,
        ),
      ],
    );
  }
}
