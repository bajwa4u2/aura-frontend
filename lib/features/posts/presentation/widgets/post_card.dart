import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

import '../../../../core/net/dio_provider.dart';
import '../../../../core/ui/aura_card.dart';
import '../../../../core/ui/aura_platform_components.dart';
import '../../../../core/ui/aura_radius.dart';
import '../../../../core/ui/aura_space.dart';
import '../../../../core/ui/aura_surface.dart';
import '../../../../core/ui/aura_text.dart';
import '../../../../core/ui/aura_text_block.dart';
import '../../../feed/domain/post.dart';
import '../../../saves/providers.dart';

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

const String _kAuraWebBaseUrl = String.fromEnvironment(
  'AURA_WEB_BASE_URL',
  defaultValue: 'https://app.auraplatform.org',
);

String _canonicalPostUrl(String postId) {
  var base = _kAuraWebBaseUrl.trim();
  if (base.endsWith('/')) base = base.substring(0, base.length - 1);
  return '$base/posts/$postId';
}

String? _cleanNullableText(dynamic value) {
  final text = value?.toString().trim();
  if (text == null || text.isEmpty) return null;
  return text;
}

String _linkedInShareUrl(String postUrl) {
  final u = Uri.encodeComponent(postUrl);
  return 'https://www.linkedin.com/sharing/share-offsite/?url=$u';
}

String _emailShareUrl(String postUrl) {
  final subject = Uri.encodeComponent('Aura post');
  final body = Uri.encodeComponent(postUrl);
  return 'mailto:?subject=$subject&body=$body';
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
  final code = Localizations.localeOf(context).languageCode.trim().toLowerCase();
  if (_translationLanguageLabels.containsKey(code)) return code;
  return 'en';
}

bool _extractBool(dynamic data, List<String> keys) {
  if (data is! Map) return false;

  for (final k in keys) {
    final v = data[k];
    if (v is bool) return v;
  }

  final inner = data['data'];
  if (inner is Map) {
    for (final k in keys) {
      final v = inner[k];
      if (v is bool) return v;
    }
  }

  return false;
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

Future<void> _copyToClipboard(
  BuildContext context,
  String value, {
  required String message,
}) async {
  await Clipboard.setData(ClipboardData(text: value));
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message)),
  );
}

Future<void> _openExternalUrl(
  BuildContext context,
  String rawUrl, {
  String fallbackCopyMessage = 'Link copied',
}) async {
  final trimmed = rawUrl.trim();
  if (trimmed.isEmpty) return;

  Uri? uri = Uri.tryParse(trimmed);
  if (uri == null) {
    await _copyToClipboard(
      context,
      trimmed,
      message: fallbackCopyMessage,
    );
    return;
  }

  if (!uri.hasScheme) {
    uri = Uri.tryParse('https://$trimmed');
  }

  if (uri == null) {
    await _copyToClipboard(
      context,
      trimmed,
      message: fallbackCopyMessage,
    );
    return;
  }

  try {
    final launched = await launchUrl(
      uri,
      mode: LaunchMode.platformDefault,
    );

    if (!launched) {
      await _copyToClipboard(
        context,
        trimmed,
        message: fallbackCopyMessage,
      );
    }
  } catch (_) {
    await _copyToClipboard(
      context,
      trimmed,
      message: fallbackCopyMessage,
    );
  }
}

class _ViewerIdentity {
  const _ViewerIdentity({
    required this.id,
    required this.handle,
  });

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

final isLikedProvider = FutureProvider.family<bool, String>((ref, postId) async {
  final dio = ref.read(dioProvider);
  final pid = postId.trim();
  if (pid.isEmpty) return false;

  try {
    final res = await dio.get('/reactions/$pid');
    return _extractBool(res.data, const ['liked', 'isLiked']);
  } on DioException catch (e) {
    if (e.response?.statusCode == 404) return false;
    return false;
  } catch (_) {
    return false;
  }
});

final isSavedProvider = FutureProvider.family<bool, String>((ref, postId) async {
  final repo = ref.read(savesRepositoryProvider);
  final pid = postId.trim();
  if (pid.isEmpty) return false;

  try {
    return await repo.isSaved(pid);
  } catch (_) {
    return false;
  }
});

class _ResolvedMediaItem {
  const _ResolvedMediaItem({
    required this.id,
    required this.type,
    required this.url,
    required this.thumbUrl,
    required this.caption,
    required this.width,
    required this.height,
    required this.duration,
    required this.editDisclosure,
  });

  final String id;
  final String type;
  final String? url;
  final String? thumbUrl;
  final String? caption;
  final int? width;
  final int? height;
  final int? duration;
  final bool editDisclosure;

  bool get isVideo => type.toUpperCase().contains('VIDEO');
  bool get isSvg =>
      type.toUpperCase().contains('SVG') ||
      ((url ?? '').toLowerCase().endsWith('.svg'));

  String get playableUrl => (url ?? '').trim();
  String get previewUrl {
    if (isVideo) {
      final thumb = (thumbUrl ?? '').trim();
      if (thumb.isNotEmpty) return thumb;
      return playableUrl;
    }
    return playableUrl;
  }
}

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
    final current = (_translationTargetLanguage ?? _defaultTranslationLanguage(context)).toLowerCase();

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
                          color: active ? AuraSurface.elevated : AuraSurface.page,
                          borderRadius: BorderRadius.circular(AuraRadius.pill),
                          border: Border.all(color: AuraSurface.divider),
                        ),
                        child: Text(
                          entry.value,
                          style: AuraText.small.copyWith(
                            fontWeight: active ? FontWeight.w700 : FontWeight.w600,
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

    final target = (_translationTargetLanguage ?? _defaultTranslationLanguage(context)).toLowerCase();

    setState(() {
      _translationBusy = true;
      _translationError = null;
    });

    try {
      final dio = ref.read(dioProvider);
      final response = await dio.post(
        '/composition/translate',
        data: {
          'text': trimmed,
          'targetLanguage': target,
        },
      );

      final root = _asMap(response.data);
      final data = _asMap(root['data']);

      final translatedText = _readString(
        root['translatedText'] ?? root['text'] ?? data['translatedText'] ?? data['text'],
      );

      if (translatedText.isEmpty) {
        throw Exception('Translation response was empty.');
      }

      if (!mounted) return;

      setState(() {
        _translatedText = translatedText;
        _showTranslation = true;
        _translationTargetLanguage = _readString(
          root['targetLanguage'] ?? data['targetLanguage'] ?? target,
        ).toLowerCase().isEmpty
            ? target
            : _readString(root['targetLanguage'] ?? data['targetLanguage'] ?? target).toLowerCase();
      });
    } on DioException catch (e) {
      if (!mounted) return;
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
          content: Text(
            authRequired ? 'Sign in to use translation.' : message,
          ),
          action: authRequired
              ? SnackBarAction(
                  label: 'Sign in',
                  onPressed: () => context.go('/login'),
                )
              : null,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      const message = 'Translation could not run right now.';
      setState(() {
        _translationError = message;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(message)),
      );
    } finally {
      if (!mounted) return;
      setState(() => _translationBusy = false);
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

  List<_ResolvedMediaItem> _extractStructuredMedia(dynamic dyn) {
    final out = <_ResolvedMediaItem>[];

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
        _ResolvedMediaItem(
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
      _ResolvedMediaItem(
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

    if (confirmed != true || !mounted) return;

    try {
      final dio = ref.read(dioProvider);
      await dio.delete('/posts/$postId');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Work deleted')),
      );

      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/home');
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not delete post')),
      );
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
                if (isOwnPost)
                  _MenuActionTile(
                    icon: Icons.edit_outlined,
                    label: 'Edit work',
                    onTap: () => Navigator.of(ctx).pop('edit_post'),
                  ),
                if (isOwnPost)
                  _MenuActionTile(
                    icon: Icons.delete_outline,
                    label: 'Delete work',
                    onTap: () => Navigator.of(ctx).pop('delete_post'),
                  ),
                _MenuActionTile(
                  icon: Icons.article_outlined,
                  label: 'Open work',
                  onTap: () => Navigator.of(ctx).pop('open_post'),
                ),
                if ((handle ?? '').trim().isNotEmpty)
                  _MenuActionTile(
                    icon: Icons.person_outline,
                    label: 'Open profile',
                    onTap: () => Navigator.of(ctx).pop('open_profile'),
                  ),
                _MenuActionTile(
                  icon: Icons.link_outlined,
                  label: 'Copy link',
                  onTap: () => Navigator.of(ctx).pop('copy_link'),
                ),
                _MenuActionTile(
                  icon: Icons.work_outline,
                  label: 'Share to LinkedIn',
                  onTap: () => Navigator.of(ctx).pop('share_linkedin'),
                ),
                _MenuActionTile(
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

    if (!mounted || selected == null) return;

    switch (selected) {
      case 'edit_post':
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Work editing is not wired yet.')),
        );
        break;
      case 'delete_post':
        await _deletePost(context, postId);
        break;
      case 'open_post':
        context.push('/posts/$postId');
        break;
      case 'open_profile':
        if ((handle ?? '').trim().isNotEmpty) {
          context.push('/u/${handle!.trim()}');
        }
        break;
      case 'copy_link':
        await _copyToClipboard(
          context,
          postUrl,
          message: 'Work link copied',
        );
        break;
      case 'share_linkedin':
        await _openExternalUrl(
          context,
          _linkedInShareUrl(postUrl),
          fallbackCopyMessage: 'LinkedIn share link copied',
        );
        break;
      case 'share_email':
        await _openExternalUrl(
          context,
          _emailShareUrl(postUrl),
          fallbackCopyMessage: 'Email share link copied',
        );
        break;
    }
  }

  Future<void> _showShareSheet(
    BuildContext context, {
    required String postId,
  }) async {
    final postUrl = _canonicalPostUrl(postId);
    final linkedInUrl = _linkedInShareUrl(postUrl);
    final emailUrl = _emailShareUrl(postUrl);

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
                Text('Share', style: AuraText.title),
                const SizedBox(height: AuraSpace.s10),
                Text(
                  'Share this work.',
                  style: AuraText.body,
                ),
                const SizedBox(height: AuraSpace.s14),
                Wrap(
                  spacing: AuraSpace.s10,
                  runSpacing: AuraSpace.s10,
                  children: [
                    AuraSecondaryButton(
                      label: 'Copy link',
                      icon: Icons.link_outlined,
                      onPressed: () async {
                        await _copyToClipboard(
                          ctx,
                          postUrl,
                          message: 'Work link copied',
                        );
                      },
                    ),
                    AuraSecondaryButton(
                      label: 'Share to LinkedIn',
                      icon: Icons.work_outline,
                      onPressed: () async {
                        await _openExternalUrl(
                          ctx,
                          linkedInUrl,
                          fallbackCopyMessage: 'LinkedIn share link copied',
                        );
                      },
                    ),
                    AuraSecondaryButton(
                      label: 'Share to Email',
                      icon: Icons.email_outlined,
                      onPressed: () async {
                        await _openExternalUrl(
                          ctx,
                          emailUrl,
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

  void _openProfile(BuildContext context, String handle) {
    final h = handle.trim();
    if (h.isEmpty) return;
    context.push('/u/$h');
  }

  Future<void> _openMediaViewer(
    BuildContext context,
    List<_ResolvedMediaItem> items,
    int initialIndex,
  ) async {
    await showDialog<void>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.88),
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: _MediaViewerDialog(
          items: items,
          initialIndex: initialIndex,
        ),
      ),
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
    final createdLabel = (createdAt == null)
        ? ''
        : '${createdAt.year.toString().padLeft(4, '0')}-${createdAt.month.toString().padLeft(2, '0')}-${createdAt.day.toString().padLeft(2, '0')}';

    final postId = post.id;
    final postUrl = _canonicalPostUrl(postId);
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
            _IdentityHeader(
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
                            borderRadius: BorderRadius.circular(AuraRadius.pill),
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
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    ),
                                    const SizedBox(width: AuraSpace.s8),
                                  ],
                                  Text(
                                    _translationBusy
                                        ? 'Translating...'
                                        : (_showTranslation ? 'Refresh translation' : 'Translate'),
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
                            borderRadius: BorderRadius.circular(AuraRadius.pill),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AuraSpace.s10,
                                vertical: AuraSpace.s6,
                              ),
                              decoration: BoxDecoration(
                                color: AuraSurface.elevated,
                                borderRadius: BorderRadius.circular(AuraRadius.pill),
                                border: Border.all(color: AuraSurface.divider),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.translate, size: 14, color: AuraSurface.muted),
                                  const SizedBox(width: AuraSpace.s6),
                                  Text(
                                    _languageLabel(_translationTargetLanguage ?? _defaultTranslationLanguage(context)),
                                    style: AuraText.small.copyWith(fontWeight: FontWeight.w700),
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
                              borderRadius: BorderRadius.circular(AuraRadius.pill),
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
                          style: AuraText.small.copyWith(color: AuraSurface.warnInk),
                        ),
                      ],
                      if (_showTranslation && (_translatedText ?? '').trim().isNotEmpty) ...[
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
              onOpenMediaAt: (index) => _openMediaViewer(
                context,
                mediaItems,
                index,
              ),
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
    required List<_ResolvedMediaItem> mediaItems,
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
        child: _PostMediaBlock(
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
        borderRadius: radius,
        onTap: () => _openExternalUrl(
          context,
          lUrl,
          fallbackCopyMessage: 'Could not open link. Link copied instead.',
        ),
        onLongPress: () => _copyToClipboard(
          context,
          lUrl,
          message: 'Link copied',
        ),
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
                      Row(
                        children: [
                          Icon(
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

class _IdentityHeader extends StatelessWidget {
  const _IdentityHeader({
    required this.displayName,
    required this.handle,
    required this.contextLine,
    required this.avatarUrl,
    required this.createdLabel,
    required this.visibilityLabel,
    required this.visibilityIcon,
    required this.compact,
    required this.onMenuTap,
    this.onProfileTap,
  });

  final String displayName;
  final String handle;
  final String contextLine;
  final String? avatarUrl;
  final String createdLabel;
  final String visibilityLabel;
  final IconData visibilityIcon;
  final bool compact;
  final VoidCallback? onProfileTap;
  final VoidCallback onMenuTap;

  @override
  Widget build(BuildContext context) {
    final metaParts = <String>[
      if (handle.trim().isNotEmpty) '@${handle.trim()}',
      if (createdLabel.trim().isNotEmpty) createdLabel.trim(),
    ];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onProfileTap,
            child: Padding(
              padding: const EdgeInsets.only(
                right: AuraSpace.s8,
                top: 2,
                bottom: 2,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AuraAvatar(
                    name: displayName,
                    imageUrl: avatarUrl,
                    size: compact ? 36.0 : 40.0,
                  ),
                  const SizedBox(width: AuraSpace.s10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayName,
                          style: AuraText.body.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (metaParts.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              metaParts.join(' · '),
                              style: AuraText.small.copyWith(
                                color: AuraSurface.muted,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        if (!compact && contextLine.trim().isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              contextLine.trim(),
                              style: AuraText.small.copyWith(
                                color: AuraSurface.muted,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        if (visibilityLabel.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: _VisibilityMeta(
                              icon: visibilityIcon,
                              label: visibilityLabel,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        GestureDetector(
          onTap: onMenuTap,
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AuraSurface.subtle,
              borderRadius: BorderRadius.circular(AuraRadius.pill),
              border: Border.all(color: AuraSurface.divider),
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.more_horiz,
              size: 18,
              color: AuraSurface.muted,
            ),
          ),
        ),
      ],
    );
  }
}

class _PostMediaBlock extends StatelessWidget {
  const _PostMediaBlock({
    required this.items,
    required this.postId,
    required this.maxHeight,
    required this.onOpenMediaAt,
  });

  final List<_ResolvedMediaItem> items;
  final String postId;
  final double maxHeight;
  final ValueChanged<int> onOpenMediaAt;

  @override
  Widget build(BuildContext context) {
    if (items.length == 1) {
      return _SingleMediaCard(
        item: items.first,
        maxHeight: maxHeight,
        onTap: () => onOpenMediaAt(0),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final spacing = AuraSpace.s12;
        final totalWidth = constraints.maxWidth;
        final columns = totalWidth >= 760 ? 2 : 1;
        final cardWidth = columns == 1
            ? totalWidth
            : (totalWidth - spacing) / 2;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: List.generate(items.length, (index) {
            final item = items[index];
            return SizedBox(
              width: cardWidth,
              child: _SingleMediaCard(
                item: item,
                maxHeight: columns == 1 ? maxHeight : 260,
                onTap: () => onOpenMediaAt(index),
              ),
            );
          }),
        );
      },
    );
  }
}

class _SingleMediaCard extends StatelessWidget {
  const _SingleMediaCard({
    required this.item,
    required this.maxHeight,
    required this.onTap,
  });

  final _ResolvedMediaItem item;
  final double maxHeight;
  final VoidCallback onTap;

  double? _ratio() {
    final w = item.width;
    final h = item.height;
    if (w != null && h != null && w > 0 && h > 0) {
      var ratio = w / h;
      if (ratio < 0.6) ratio = 0.6;
      if (ratio > 1.9) ratio = 1.9;
      return ratio;
    }
    return item.isVideo ? (16 / 9) : null;
  }

  String _durationLabel() {
    final ms = item.duration;
    if (ms == null || ms <= 0) return '';
    final totalSeconds = (ms / 1000).round();
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final border = Border.all(color: AuraSurface.divider);
    final radius = BorderRadius.circular(16);
    final ratio = _ratio();

    final imageUrl = item.previewUrl;

    Widget mediaWidget;

    if (item.isSvg && imageUrl.isNotEmpty) {
      mediaWidget = SvgPicture.network(
        imageUrl,
        fit: BoxFit.cover,
        placeholderBuilder: (_) => const SizedBox(
          height: 140,
          child: Center(
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    } else if (imageUrl.isNotEmpty) {
      mediaWidget = Image.network(
        imageUrl,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          constraints: const BoxConstraints(minHeight: 180),
          alignment: Alignment.center,
          child: Text(
            item.isVideo ? 'Video unavailable' : 'Media unavailable',
            style: AuraText.small,
            textAlign: TextAlign.center,
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
    } else {
      mediaWidget = Container(
        constraints: const BoxConstraints(minHeight: 180),
        alignment: Alignment.center,
        child: Text(
          item.isVideo ? 'Video unavailable' : 'Media unavailable',
          style: AuraText.small,
          textAlign: TextAlign.center,
        ),
      );
    }

    Widget content = Stack(
      children: [
        Positioned.fill(child: mediaWidget),
        if (item.isVideo)
          Positioned.fill(
            child: Center(
              child: Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.58),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.play_arrow_rounded,
                  size: 38,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        if (item.isVideo)
          Positioned(
            top: 12,
            right: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                borderRadius: BorderRadius.circular(AuraRadius.pill),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.videocam, size: 14, color: Colors.white),
                  if (_durationLabel().isNotEmpty) ...[
                    const SizedBox(width: 4),
                    Text(
                      _durationLabel(),
                      style: AuraText.small.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
      ],
    );

    Widget mediaBox = ClipRRect(
      borderRadius: radius,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: radius,
          border: border,
          color: AuraSurface.elevated,
        ),
        child: ratio == null
            ? ConstrainedBox(
                constraints: BoxConstraints(maxHeight: maxHeight),
                child: content,
              )
            : AspectRatio(
                aspectRatio: ratio,
                child: content,
              ),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: mediaBox,
        ),
        if ((item.caption ?? '').trim().isNotEmpty) ...[
          const SizedBox(height: AuraSpace.s8),
          Text(
            item.caption!.trim(),
            style: AuraText.small.copyWith(height: 1.35),
          ),
        ],
        if (item.editDisclosure) ...[
          const SizedBox(height: AuraSpace.s6),
          Text(
            'Edited for clarity or privacy',
            style: AuraText.small.copyWith(
              color: AuraSurface.muted,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }
}

class _MediaViewerDialog extends StatefulWidget {
  const _MediaViewerDialog({
    required this.items,
    required this.initialIndex,
  });

  final List<_ResolvedMediaItem> items;
  final int initialIndex;

  @override
  State<_MediaViewerDialog> createState() => _MediaViewerDialogState();
}

class _MediaViewerDialogState extends State<_MediaViewerDialog> {
  late final PageController _pageController;
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex.clamp(0, widget.items.length - 1);
    _pageController = PageController(initialPage: _index);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _jump(int next) {
    if (next < 0 || next >= widget.items.length) return;
    _pageController.animateToPage(
      next,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.items[_index];

    return ConstrainedBox(
      constraints: const BoxConstraints(
        maxWidth: 1100,
        maxHeight: 820,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white12),
        ),
        child: Stack(
          children: [
            Column(
              children: [
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: widget.items.length,
                    onPageChanged: (value) {
                      setState(() {
                        _index = value;
                      });
                    },
                    itemBuilder: (context, index) {
                      final media = widget.items[index];
                      return Padding(
                        padding: const EdgeInsets.all(16),
                        child: Center(
                          child: media.isVideo
                              ? _VideoViewer(url: media.playableUrl)
                              : _ImageViewer(url: media.previewUrl),
                        ),
                      );
                    },
                  ),
                ),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                  decoration: const BoxDecoration(
                    border: Border(
                      top: BorderSide(color: Colors.white12),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if ((item.caption ?? '').trim().isNotEmpty)
                        Text(
                          item.caption!.trim(),
                          style: AuraText.body.copyWith(color: Colors.white),
                        ),
                      if ((item.caption ?? '').trim().isNotEmpty)
                        const SizedBox(height: 10),
                      Row(
                        children: [
                          Text(
                            '${_index + 1} / ${widget.items.length}',
                            style: AuraText.small.copyWith(
                              color: Colors.white70,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const Spacer(),
                          if (item.playableUrl.isNotEmpty)
                            AuraGhostButton(
                              label: item.isVideo ? 'Open video' : 'Open image',
                              icon: Icons.open_in_new,
                              onPressed: () => _openExternalUrl(
                                context,
                                item.playableUrl,
                                fallbackCopyMessage: 'Media link copied',
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            Positioned(
              top: 10,
              right: 10,
              child: IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close, color: Colors.white),
              ),
            ),
            if (_index > 0)
              Positioned(
                left: 8,
                top: 0,
                bottom: 0,
                child: Center(
                  child: _ViewerArrowButton(
                    icon: Icons.chevron_left,
                    onTap: () => _jump(_index - 1),
                  ),
                ),
              ),
            if (_index < widget.items.length - 1)
              Positioned(
                right: 8,
                top: 0,
                bottom: 0,
                child: Center(
                  child: _ViewerArrowButton(
                    icon: Icons.chevron_right,
                    onTap: () => _jump(_index + 1),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ViewerArrowButton extends StatelessWidget {
  const _ViewerArrowButton({
    required this.icon,
    required this.onTap,
  });

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withOpacity(0.45),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 46,
          height: 46,
          child: Icon(icon, color: Colors.white),
        ),
      ),
    );
  }
}

class _ImageViewer extends StatelessWidget {
  const _ImageViewer({
    required this.url,
  });

  final String url;

  @override
  Widget build(BuildContext context) {
    if (url.trim().isEmpty) {
      return Text(
        'Image unavailable',
        style: AuraText.body.copyWith(color: Colors.white),
      );
    }

    return InteractiveViewer(
      minScale: 0.8,
      maxScale: 4.0,
      child: Image.network(
        url,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => Text(
          'Image unavailable',
          style: AuraText.body.copyWith(color: Colors.white),
        ),
      ),
    );
  }
}

class _VideoViewer extends StatefulWidget {
  const _VideoViewer({
    required this.url,
  });

  final String url;

  @override
  State<_VideoViewer> createState() => _VideoViewerState();
}

class _VideoViewerState extends State<_VideoViewer> {
  VideoPlayerController? _controller;
  Future<void>? _initializeFuture;
  String? _error;

  @override
  void initState() {
    super.initState();
    _setup();
  }

  void _setup() {
    final url = widget.url.trim();
    if (url.isEmpty) {
      _error = 'Video URL is missing';
      return;
    }

    try {
      final controller = VideoPlayerController.networkUrl(Uri.parse(url));
      _controller = controller;
      _initializeFuture = controller.initialize().then((_) async {
        await controller.setLooping(true);
        if (mounted) {
          setState(() {});
        }
      }).catchError((_) {
        _error = 'Could not load video';
        if (mounted) {
          setState(() {});
        }
      });
    } catch (_) {
      _error = 'Could not open video';
    }
  }

  @override
  void dispose() {
    final controller = _controller;
    _controller = null;
    controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if ((_error ?? '').trim().isNotEmpty) {
      return _VideoFallback(
        message: _error!,
        url: widget.url,
      );
    }

    final controller = _controller;
    final initializeFuture = _initializeFuture;

    if (controller == null || initializeFuture == null) {
      return _VideoFallback(
        message: 'Video unavailable',
        url: widget.url,
      );
    }

    return FutureBuilder<void>(
      future: initializeFuture,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _VideoFallback(
            message: 'Could not load video',
            url: widget.url,
          );
        }

        if (snapshot.connectionState != ConnectionState.done ||
            !controller.value.isInitialized) {
          return const Center(
            child: CircularProgressIndicator(strokeWidth: 2),
          );
        }

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: AspectRatio(
                aspectRatio: controller.value.aspectRatio > 0
                    ? controller.value.aspectRatio
                    : (16 / 9),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: VideoPlayer(controller),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              children: [
                AuraPrimaryButton(
                  label: controller.value.isPlaying ? 'Pause' : 'Play',
                  icon: controller.value.isPlaying ? Icons.pause : Icons.play_arrow,
                  onPressed: () async {
                    if (controller.value.isPlaying) {
                      await controller.pause();
                    } else {
                      await controller.play();
                    }
                    if (mounted) {
                      setState(() {});
                    }
                  },
                ),
                AuraSecondaryButton(
                  label: 'Restart',
                  icon: Icons.replay,
                  onPressed: () async {
                    await controller.seekTo(Duration.zero);
                    if (!controller.value.isPlaying) {
                      await controller.play();
                    }
                    if (mounted) {
                      setState(() {});
                    }
                  },
                ),
                AuraSecondaryButton(
                  label: 'Open externally',
                  icon: Icons.open_in_new,
                  onPressed: () => _openExternalUrl(
                    context,
                    widget.url,
                    fallbackCopyMessage: 'Video link copied',
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _VideoFallback extends StatelessWidget {
  const _VideoFallback({
    required this.message,
    required this.url,
  });

  final String message;
  final String url;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 220, minWidth: 320),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.videocam_outlined,
            size: 40,
            color: Colors.white70,
          ),
          const SizedBox(height: 12),
          Text(
            message,
            style: AuraText.body.copyWith(color: Colors.white),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 14),
          AuraSecondaryButton(
            label: 'Open video',
            icon: Icons.open_in_new,
            onPressed: () => _openExternalUrl(
              context,
              url,
              fallbackCopyMessage: 'Video link copied',
            ),
          ),
        ],
      ),
    );
  }
}

class _VisibilityMeta extends StatelessWidget {
  const _VisibilityMeta({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AuraSurface.muted),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            label,
            style: AuraText.small.copyWith(
              color: AuraSurface.muted,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _ActionRow extends ConsumerWidget {
  const _ActionRow({
    required this.postId,
  });

  final String postId;

  void _showError(BuildContext context, String message) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final saved = ref.watch(isSavedProvider(postId));

    Future<void> toggleSave() async {
      try {
        final repo = ref.read(savesRepositoryProvider);
        await repo.toggle(postId);
        ref.invalidate(isSavedProvider(postId));
        ref.invalidate(savedPostsProvider);
      } catch (_) {
        _showError(context, 'Could not update save');
      }
    }

    Future<void> repost() async {
      final controller = TextEditingController();

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

        await dio.post('/posts/$postId/repost', data: payload);

        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Work reposted')),
        );
      } catch (_) {
        _showError(context, 'Could not repost');
      } finally {
        controller.dispose();
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
                  Text('Share', style: AuraText.title),
                  const SizedBox(height: AuraSpace.s10),
                  Text(
                    'Share this work.',
                    style: AuraText.body,
                  ),
                  const SizedBox(height: AuraSpace.s14),
                  Wrap(
                    spacing: AuraSpace.s10,
                    runSpacing: AuraSpace.s10,
                    children: [
                      AuraSecondaryButton(
                        label: 'Copy link',
                        icon: Icons.link_outlined,
                        onPressed: () async {
                          await _copyToClipboard(
                            ctx,
                            _canonicalPostUrl(postId),
                            message: 'Work link copied',
                          );
                        },
                      ),
                      AuraSecondaryButton(
                        label: 'Share to LinkedIn',
                        icon: Icons.work_outline,
                        onPressed: () async {
                          await _openExternalUrl(
                            ctx,
                            _linkedInShareUrl(_canonicalPostUrl(postId)),
                            fallbackCopyMessage: 'LinkedIn share link copied',
                          );
                        },
                      ),
                      AuraSecondaryButton(
                        label: 'Share to Email',
                        icon: Icons.email_outlined,
                        onPressed: () async {
                          await _openExternalUrl(
                            ctx,
                            _emailShareUrl(_canonicalPostUrl(postId)),
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

    return Wrap(
      spacing: AuraSpace.s8,
      runSpacing: AuraSpace.s8,
      children: [
        AuraActionPill(
          icon: Icons.reply_outlined,
          label: 'Respond',
          onTap: () => context.push('/compose?replyTo=$postId&surface=dm'),
        ),
        AuraActionPill(
          icon: Icons.repeat,
          label: 'Repost',
          onTap: repost,
        ),
        saved.when(
          data: (v) => AuraActionPill(
            icon: v ? Icons.bookmark : Icons.bookmark_border,
            label: v ? 'Saved' : 'Save',
            onTap: toggleSave,
            active: v,
          ),
          loading: () => AuraActionPill(
            icon: Icons.bookmark_border,
            label: 'Save',
            onTap: toggleSave,
          ),
          error: (_, __) => AuraActionPill(
            icon: Icons.bookmark_border,
            label: 'Save',
            onTap: toggleSave,
          ),
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

class _MenuActionTile extends StatelessWidget {
  const _MenuActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon),
      title: Text(label, style: AuraText.body),
      onTap: onTap,
    );
  }
}

enum _BadgeTone { neutral, good, warn }

class _Badge extends StatelessWidget {
  const _Badge({
    required this.text,
    required this.tone,
  });

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
        bg = AuraSurface.elevated;
        fg = AuraSurface.ink;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AuraRadius.pill),
        border: Border.all(color: AuraSurface.divider),
      ),
      child: Text(
        text,
        style: AuraText.small.copyWith(
          color: fg,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
