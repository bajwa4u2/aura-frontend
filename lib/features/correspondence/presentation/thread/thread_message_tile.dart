import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/net/dio_provider.dart';
import '../../../../core/ui/aura_platform_components.dart';
import '../../../../core/ui/aura_radius.dart';
import '../../../../core/ui/aura_space.dart';
import '../../../../core/ui/aura_surface.dart';
import '../../../../core/ui/aura_text.dart';
import '../../../../core/ui/aura_text_block.dart';
import 'thread_utils.dart';

// ─────────────────────────────────────────────────────────────────────────────
// MESSAGE TILE
// ─────────────────────────────────────────────────────────────────────────────

class ThreadMessageTile extends ConsumerStatefulWidget {
  const ThreadMessageTile({
    super.key,
    required this.message,
    required this.currentUserId,
    required this.showAuthorHeader,
    required this.onEdit,
    required this.onDelete,
  });

  final Map<String, dynamic> message;
  final String currentUserId;
  final bool showAuthorHeader;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  ConsumerState<ThreadMessageTile> createState() => _MessageTileState();
}

class _MessageTileState extends ConsumerState<ThreadMessageTile> {
  bool _translationBusy = false;
  bool _showTranslation = false;
  String? _translatedText;
  String? _translationError;
  String? _translationTargetLanguage;

  Future<void> _pickTranslationLanguage(BuildContext context) async {
    final current =
        (_translationTargetLanguage ?? defaultTranslationLanguage(context))
            .toLowerCase();

    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
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
                  children: kTranslationLanguageLabels.entries.map((entry) {
                    final active = entry.key == current;
                    return MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: InkWell(
                        onTap: () => Navigator.of(ctx).pop(entry.key),
                        borderRadius: BorderRadius.circular(AuraRadius.pill),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AuraSpace.s12,
                            vertical: AuraSpace.s8,
                          ),
                          decoration: BoxDecoration(
                            color: active
                                ? AuraSurface.overlay
                                : Colors.transparent,
                            border: Border.all(color: AuraSurface.divider),
                            borderRadius:
                                BorderRadius.circular(AuraRadius.pill),
                          ),
                          child: Text(
                            entry.value,
                            style: AuraText.small.copyWith(
                              fontWeight: FontWeight.w700,
                              color: active ? AuraSurface.ink : AuraSurface.muted,
                            ),
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

  Future<void> _translateMessage(BuildContext context, String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || _translationBusy) return;

    final target =
        (_translationTargetLanguage ?? defaultTranslationLanguage(context))
            .toLowerCase();

    setState(() {
      _translationBusy = true;
      _translationError = null;
    });

    try {
      final dio = ref.read(dioProvider);
      final res = await dio.post(
        '/composition/translate',
        data: {'text': trimmed, 'targetLanguage': target},
      );

      final root = unwrapDataMap(res.data);
      final translatedText = pickDeepString(root, const [
        ['translatedText'],
        ['translation', 'text'],
        ['data', 'translatedText'],
        ['data', 'text'],
      ]);

      if (!mounted) return;

      if (translatedText.trim().isEmpty) {
        setState(() {
          _translationError = 'Translation was empty.';
          _translationBusy = false;
        });
        return;
      }

      setState(() {
        _translatedText = translatedText;
        _showTranslation = true;
        _translationTargetLanguage = target;
        _translationBusy = false;
      });
    } catch (e) {
      if (!context.mounted) return;
      setState(() {
        _translationBusy = false;
        _translationError = 'Could not translate this message right now.';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not translate this message right now.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final message = widget.message;
    final currentUserId = widget.currentUserId;
    final showAuthorHeader = widget.showAuthorHeader;
    final onEdit = widget.onEdit;
    final onDelete = widget.onDelete;

    final body = pickString(message, const ['body', 'text', 'content']);
    final authorMap = extractAuthorMap(message);
    final src = authorMap.isNotEmpty ? authorMap : message;
    final author = pickString(src, const [
      'displayName', 'authorName', 'senderName', 'name', 'userName',
    ]);
    final handle = pickString(src, const [
      'handle', 'authorHandle', 'senderHandle', 'username',
    ]);
    final avatarUrl = pickString(src, const ['avatarUrl', 'imageUrl', 'photoUrl']);
    final createdAt = pickString(message, const [
      'createdAt', 'sentAt', 'timestamp',
    ]);
    final attachments = listOfMap(message['attachments']);
    final senderId = extractSenderId(message);
    final isMine =
        currentUserId.trim().isNotEmpty &&
        senderId.trim() == currentUserId.trim();

    const textColor = AuraSurface.ink;
    const metaColor = AuraSurface.muted;
    const translatedTextColor = AuraSurface.ink;
    const translatedSurfaceColor = AuraSurface.subtle;

    _translationTargetLanguage ??= defaultTranslationLanguage(context);

    // ── Bubble decoration ────────────────────────────────────────────────────
    final bubbleDecoration = isMine
        ? BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF1E2756),
                AuraSurface.overlay,
              ],
            ),
            border: Border.all(
              color: AuraSurface.accent.withValues(alpha: 0.22),
            ),
            borderRadius: BorderRadius.circular(20),
          )
        : BoxDecoration(
            color: AuraSurface.elevated,
            border: Border.all(color: AuraSurface.divider),
            borderRadius: BorderRadius.circular(20),
            boxShadow: const [
              BoxShadow(
                blurRadius: 8,
                offset: Offset(0, 2),
                color: Color(0x08000000),
              ),
            ],
          );

    // ── Bubble body ──────────────────────────────────────────────────────────
    final bubble = Container(
      decoration: bubbleDecoration,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (body.isNotEmpty) ...[
            Directionality(
              textDirection: directionForText(body),
              child: AuraTextBlock(
                body,
                textAlign: alignForText(body),
                style: AuraText.body.copyWith(color: textColor),
              ),
            ),
            const SizedBox(height: AuraSpace.s8),
            Wrap(
              spacing: AuraSpace.s10,
              runSpacing: AuraSpace.s8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                MouseRegion(
                  cursor: _translationBusy
                      ? SystemMouseCursors.basic
                      : SystemMouseCursors.click,
                  child: InkWell(
                    onTap: _translationBusy
                        ? null
                        : () => _translateMessage(context, body),
                    borderRadius:
                        BorderRadius.circular(AuraRadius.pill),
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
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  AuraSurface.muted,
                                ),
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
                              color: metaColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: InkWell(
                    onTap: () => _pickTranslationLanguage(context),
                    borderRadius: BorderRadius.circular(AuraRadius.pill),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AuraSpace.s10,
                        vertical: AuraSpace.s6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(AuraRadius.pill),
                        border: Border.all(color: AuraSurface.divider),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.translate, size: 14, color: metaColor),
                          const SizedBox(width: AuraSpace.s6),
                          Text(
                            languageLabel(
                              _translationTargetLanguage ??
                                  defaultTranslationLanguage(context),
                            ),
                            style: AuraText.small.copyWith(
                              fontWeight: FontWeight.w700,
                              color: AuraSurface.ink,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (_showTranslation)
                  MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: InkWell(
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
                            color: metaColor,
                          ),
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
                style: AuraText.small.copyWith(color: AuraSurface.dangerInk),
              ),
            ],
            if (_showTranslation &&
                (_translatedText ?? '').trim().isNotEmpty) ...[
              const SizedBox(height: AuraSpace.s10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AuraSpace.s10),
                decoration: BoxDecoration(
                  color: translatedSurfaceColor,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AuraSurface.divider),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Translation · ${languageLabel(_translationTargetLanguage ?? defaultTranslationLanguage(context))}',
                      style: AuraText.small.copyWith(
                        color: metaColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AuraSpace.s6),
                    Directionality(
                      textDirection: directionForText(_translatedText!),
                      child: AuraTextBlock(
                        _translatedText!,
                        textAlign: alignForText(_translatedText!),
                        style: AuraText.body.copyWith(
                          color: translatedTextColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (attachments.isNotEmpty) const SizedBox(height: AuraSpace.s10),
          ],
          if (attachments.isNotEmpty) ...[
            _MessageAttachmentList(attachments: attachments, isMine: isMine),
            const SizedBox(height: AuraSpace.s10),
          ] else if (body.isEmpty) ...[
            Text(
              '(empty message)',
              style: AuraText.body.copyWith(color: textColor),
            ),
            const SizedBox(height: AuraSpace.s10),
          ],
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (formatMessageTimestamp(createdAt).isNotEmpty)
                Flexible(
                  child: Text(
                    formatMessageTimestamp(createdAt),
                    overflow: TextOverflow.ellipsis,
                    style: AuraText.small.copyWith(color: metaColor),
                  ),
                ),
              if (isMine) ...[
                const SizedBox(width: AuraSpace.s8),
                PopupMenuButton<String>(
                  padding: EdgeInsets.zero,
                  icon: const Icon(Icons.more_horiz, size: 18, color: metaColor),
                  onSelected: (value) {
                    if (value == 'edit') {
                      onEdit();
                    } else if (value == 'delete') {
                      onDelete();
                    }
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem<String>(value: 'edit', child: Text('Edit')),
                    PopupMenuItem<String>(value: 'delete', child: Text('Delete')),
                  ],
                ),
              ],
            ],
          ),
        ],
      ),
    );

    // ── Layout ────────────────────────────────────────────────────────────────
    final maxW = MediaQuery.of(context).size.width > 900.0 ? 620.0 : 500.0;

    if (isMine) {
      return Align(
        alignment: Alignment.centerRight,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxW),
          child: bubble,
        ),
      );
    }

    // Received: avatar column + bubble
    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxW + 38.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            SizedBox(
              width: 32,
              child: (showAuthorHeader && author.isNotEmpty)
                  ? AuraAvatar(name: author, imageUrl: avatarUrl, size: 28)
                  : null,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (showAuthorHeader && author.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 4),
                      child: MouseRegion(
                        cursor: handle.isEmpty
                            ? SystemMouseCursors.basic
                            : SystemMouseCursors.click,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(6),
                          onTap: handle.isEmpty
                              ? null
                              : () => context.push('/u/$handle'),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 2,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  author,
                                  style: AuraText.small.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                if (handle.isNotEmpty) ...[
                                  const SizedBox(width: 4),
                                  Text('@$handle', style: AuraText.small),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  bubble,
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ATTACHMENT LIST
// ─────────────────────────────────────────────────────────────────────────────

class _MessageAttachmentList extends StatelessWidget {
  const _MessageAttachmentList({
    required this.attachments,
    required this.isMine,
  });

  final List<Map<String, dynamic>> attachments;
  final bool isMine;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < attachments.length; i++) ...[
          _MessageAttachmentCard(attachment: attachments[i], isMine: isMine),
          if (i != attachments.length - 1) const SizedBox(height: AuraSpace.s8),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ATTACHMENT CARD
// ─────────────────────────────────────────────────────────────────────────────

class _MessageAttachmentCard extends StatefulWidget {
  const _MessageAttachmentCard({
    required this.attachment,
    required this.isMine,
  });

  final Map<String, dynamic> attachment;
  final bool isMine;

  @override
  State<_MessageAttachmentCard> createState() => _MessageAttachmentCardState();
}

class _MessageAttachmentCardState extends State<_MessageAttachmentCard> {
  bool _hovering = false;

  Future<void> _openUrl(BuildContext context, String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open this attachment.')),
      );
      return;
    }

    final ok = await launchUrl(
      uri,
      mode: kIsWeb
          ? LaunchMode.platformDefault
          : LaunchMode.externalApplication,
      webOnlyWindowName: '_blank',
    );

    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open this attachment.')),
      );
    }
  }

  void _openImageViewer(BuildContext context, String imageUrl, String title) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(20),
        child: LayoutBuilder(
          builder: (ctx, constraints) {
            final maxW = constraints.maxWidth;
            final maxH = constraints.maxHeight;
        return Stack(
          children: [
            Center(
              child: InteractiveViewer(
                minScale: 0.8,
                maxScale: 4,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: ColoredBox(
                    color: Colors.black,
                    child: Image.network(
                      imageUrl,
                      fit: BoxFit.contain,
                      loadingBuilder: (context, child, progress) {
                        if (progress == null) return child;
                        return SizedBox(
                          height: maxH.clamp(200, 320),
                          width: maxW.clamp(200, 520),
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white70,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'Loading image…',
                                  style: AuraText.small.copyWith(
                                    color: Colors.white70,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                      errorBuilder: (_, __, ___) => Container(
                        height: maxH.clamp(200, 320),
                        width: maxW.clamp(200, 520),
                        decoration: BoxDecoration(
                          color: AuraSurface.overlay,
                          borderRadius: BorderRadius.circular(AuraRadius.card),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'Could not load image.',
                          style: AuraText.body.copyWith(
                            color: AuraSurface.muted,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                style: IconButton.styleFrom(
                  backgroundColor: AuraSurface.overlay,
                  foregroundColor: AuraSurface.ink,
                ),
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close),
              ),
            ),
            if (title.isNotEmpty)
              Positioned(
                left: 16,
                right: 72,
                top: 16,
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
              ),
          ],
        );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final attachment = widget.attachment;
    final fileName = pickString(attachment, const ['fileName', 'name']);
    final mimeType = pickString(attachment, const ['mimeType', 'mime']);
    final sizeBytes = pickInt(attachment, const ['sizeBytes', 'size']);
    final kind = kindFromMime(mimeType);
    final url = resolveAttachmentUrl(attachment);
    final thumbUrl = resolveAttachmentThumbUrl(attachment);

    const borderColor = AuraSurface.divider;
    const surfaceColor = AuraSurface.subtle;
    const primaryTextColor = AuraSurface.ink;
    const secondaryTextColor = AuraSurface.muted;

    void handleTap() {
      if (url.isEmpty) return;

      if (kind == ThreadAttachmentKind.image) {
        _openImageViewer(
          context,
          thumbUrl.isNotEmpty ? thumbUrl : url,
          fileName,
        );
        return;
      }

      _openUrl(context, url);
    }

    Widget mediaSurface;
    switch (kind) {
      case ThreadAttachmentKind.image:
        mediaSurface = _ImageAttachmentSurface(
          thumbUrl: thumbUrl,
          url: url,
          borderColor: borderColor,
          surfaceColor: surfaceColor,
          primaryTextColor: primaryTextColor,
          secondaryTextColor: secondaryTextColor,
          fileName: fileName,
          sizeBytes: sizeBytes,
          hovering: _hovering,
        );
        break;
      case ThreadAttachmentKind.video:
        mediaSurface = _VideoAttachmentSurface(
          thumbUrl: thumbUrl,
          url: url,
          borderColor: borderColor,
          surfaceColor: surfaceColor,
          primaryTextColor: primaryTextColor,
          secondaryTextColor: secondaryTextColor,
          fileName: fileName,
          sizeBytes: sizeBytes,
          hovering: _hovering,
        );
        break;
      case ThreadAttachmentKind.audio:
        mediaSurface = _AudioAttachmentSurface(
          url: url,
          borderColor: borderColor,
          surfaceColor: surfaceColor,
          primaryTextColor: primaryTextColor,
          secondaryTextColor: secondaryTextColor,
          fileName: fileName,
          sizeBytes: sizeBytes,
          mimeType: mimeType,
          hovering: _hovering,
        );
        break;
    }

    if (url.isEmpty) return mediaSurface;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(onTap: handleTap, child: mediaSurface),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MEDIA SURFACES
// ─────────────────────────────────────────────────────────────────────────────

class _ImageAttachmentSurface extends StatelessWidget {
  const _ImageAttachmentSurface({
    required this.thumbUrl,
    required this.url,
    required this.borderColor,
    required this.surfaceColor,
    required this.primaryTextColor,
    required this.secondaryTextColor,
    required this.fileName,
    required this.sizeBytes,
    required this.hovering,
  });

  final String thumbUrl;
  final String url;
  final Color borderColor;
  final Color surfaceColor;
  final Color primaryTextColor;
  final Color secondaryTextColor;
  final String fileName;
  final int? sizeBytes;
  final bool hovering;

  @override
  Widget build(BuildContext context) {
    final imageUrl = thumbUrl.isNotEmpty ? thumbUrl : url;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      transform: Matrix4.identity()
        ..scaleByDouble(
          hovering ? 1.01 : 1.0,
          hovering ? 1.01 : 1.0,
          hovering ? 1.01 : 1.0,
          1,
        ),
      decoration: BoxDecoration(
        color: surfaceColor,
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(14),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 16 / 10,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (imageUrl.isNotEmpty)
                  Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) return child;
                      return const _MediaLoadingPlaceholder(
                        icon: Icons.image_outlined,
                        label: 'Loading image…',
                      );
                    },
                    errorBuilder: (_, __, ___) => _BrokenMediaFallback(
                      icon: Icons.image_outlined,
                      text: 'Image preview unavailable',
                      textColor: secondaryTextColor,
                    ),
                  )
                else
                  _BrokenMediaFallback(
                    icon: Icons.image_outlined,
                    text: 'Image unavailable',
                    textColor: secondaryTextColor,
                  ),
                AnimatedOpacity(
                  duration: const Duration(milliseconds: 140),
                  opacity: hovering ? 1 : 0.92,
                  child: Container(
                    color: Colors.black.withValues(
                      alpha: hovering ? 0.18 : 0.08,
                    ),
                  ),
                ),
                const Center(child: _CenterOpenIcon()),
                const Positioned(
                  right: 10,
                  bottom: 10,
                  child: _OpenBadge(label: 'Open', dark: true),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AuraSpace.s10),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    fileName.isEmpty ? 'Image' : fileName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AuraText.small.copyWith(
                      fontWeight: FontWeight.w700,
                      color: primaryTextColor,
                    ),
                  ),
                ),
                if (sizeBytes != null)
                  Text(
                    formatBytes(sizeBytes!),
                    style: AuraText.small.copyWith(color: secondaryTextColor),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _VideoAttachmentSurface extends StatelessWidget {
  const _VideoAttachmentSurface({
    required this.thumbUrl,
    required this.url,
    required this.borderColor,
    required this.surfaceColor,
    required this.primaryTextColor,
    required this.secondaryTextColor,
    required this.fileName,
    required this.sizeBytes,
    required this.hovering,
  });

  final String thumbUrl;
  final String url;
  final Color borderColor;
  final Color surfaceColor;
  final Color primaryTextColor;
  final Color secondaryTextColor;
  final String fileName;
  final int? sizeBytes;
  final bool hovering;

  @override
  Widget build(BuildContext context) {
    final previewUrl = thumbUrl.isNotEmpty ? thumbUrl : url;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      transform: Matrix4.identity()
        ..scaleByDouble(
          hovering ? 1.01 : 1.0,
          hovering ? 1.01 : 1.0,
          hovering ? 1.01 : 1.0,
          1,
        ),
      decoration: BoxDecoration(
        color: surfaceColor,
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(14),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 16 / 10,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (previewUrl.isNotEmpty)
                  Image.network(
                    previewUrl,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) return child;
                      return const _MediaLoadingPlaceholder(
                        icon: Icons.videocam_outlined,
                        label: 'Loading video preview…',
                      );
                    },
                    errorBuilder: (_, __, ___) => const _BrokenMediaFallback(
                      icon: Icons.videocam_outlined,
                      text: 'Video preview unavailable',
                      textColor: Colors.white70,
                      dark: true,
                    ),
                  )
                else
                  const _BrokenMediaFallback(
                    icon: Icons.videocam_outlined,
                    text: 'Video ready to open',
                    textColor: Colors.white70,
                    dark: true,
                  ),
                Container(
                  color: Colors.black.withValues(alpha: hovering ? 0.34 : 0.26),
                ),
                const Center(child: _CenterPlayIcon()),
                const Positioned(
                  right: 10,
                  bottom: 10,
                  child: _OpenBadge(label: 'Open', dark: true),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AuraSpace.s10),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    fileName.isEmpty ? 'Video' : fileName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AuraText.small.copyWith(
                      fontWeight: FontWeight.w700,
                      color: primaryTextColor,
                    ),
                  ),
                ),
                if (sizeBytes != null)
                  Text(
                    formatBytes(sizeBytes!),
                    style: AuraText.small.copyWith(color: secondaryTextColor),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AudioAttachmentSurface extends StatelessWidget {
  const _AudioAttachmentSurface({
    required this.url,
    required this.borderColor,
    required this.surfaceColor,
    required this.primaryTextColor,
    required this.secondaryTextColor,
    required this.fileName,
    required this.sizeBytes,
    required this.mimeType,
    required this.hovering,
  });

  final String url;
  final Color borderColor;
  final Color surfaceColor;
  final Color primaryTextColor;
  final Color secondaryTextColor;
  final String fileName;
  final int? sizeBytes;
  final String mimeType;
  final bool hovering;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      transform: Matrix4.identity()
        ..scaleByDouble(
          hovering ? 1.01 : 1.0,
          hovering ? 1.01 : 1.0,
          hovering ? 1.01 : 1.0,
          1,
        ),
      padding: const EdgeInsets.all(AuraSpace.s12),
      decoration: BoxDecoration(
        color: surfaceColor,
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            height: 48,
                width: 48,
                decoration: BoxDecoration(
                  color: hovering
                      ? Colors.white.withValues(alpha: 0.06)
                      : Colors.transparent,
              border: Border.all(color: borderColor),
              borderRadius: BorderRadius.circular(14),
            ),
                child: Icon(Icons.graphic_eq_outlined, color: secondaryTextColor),
              ),
          const SizedBox(width: AuraSpace.s10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fileName.isEmpty ? 'Audio' : fileName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AuraText.body.copyWith(
                    fontWeight: FontWeight.w700,
                    color: primaryTextColor,
                  ),
                ),
                const SizedBox(height: AuraSpace.s4),
                Text(
                  [
                    if (mimeType.isNotEmpty) mimeType,
                    if (sizeBytes != null) formatBytes(sizeBytes!),
                  ].join(' • '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AuraText.small.copyWith(color: secondaryTextColor),
                ),
                const SizedBox(height: AuraSpace.s6),
                Row(
                  children: [
                    Icon(
                      Icons.open_in_new,
                      size: 14,
                      color: secondaryTextColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      url.isNotEmpty ? 'Open audio' : 'Audio unavailable',
                      style: AuraText.small.copyWith(color: secondaryTextColor),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SMALL ATOMS
// ─────────────────────────────────────────────────────────────────────────────

class _BrokenMediaFallback extends StatelessWidget {
  const _BrokenMediaFallback({
    required this.icon,
    required this.text,
    required this.textColor,
    this.dark = false,
  });

  final IconData icon;
  final String text;
  final Color textColor;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: dark ? AuraSurface.overlay : AuraSurface.subtle,
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 36, color: textColor),
          const SizedBox(height: 8),
          Text(text, style: AuraText.small.copyWith(color: textColor)),
        ],
      ),
    );
  }
}

class _CenterOpenIcon extends StatelessWidget {
  const _CenterOpenIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      width: 52,
      decoration: BoxDecoration(
        color: AuraSurface.overlay,
        borderRadius: BorderRadius.circular(AuraRadius.pill),
      ),
      child: const Icon(Icons.open_in_full, size: 24, color: AuraSurface.ink),
    );
  }
}

class _CenterPlayIcon extends StatelessWidget {
  const _CenterPlayIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      width: 56,
      decoration: BoxDecoration(
        color: AuraSurface.overlay,
        borderRadius: BorderRadius.circular(AuraRadius.pill),
      ),
      child: const Icon(
        Icons.play_arrow_rounded,
        color: AuraSurface.ink,
        size: 32,
      ),
    );
  }
}

class _MediaLoadingPlaceholder extends StatelessWidget {
  const _MediaLoadingPlaceholder({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AuraSurface.overlay,
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 28, color: Colors.white70),
          const SizedBox(height: 10),
          Text(label, style: AuraText.small.copyWith(color: Colors.white70)),
        ],
      ),
    );
  }
}

class _OpenBadge extends StatelessWidget {
  const _OpenBadge({required this.label, this.dark = false});

  final String label;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: AuraSurface.overlay,
        borderRadius: BorderRadius.circular(AuraRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.open_in_new, size: 12, color: AuraSurface.ink),
          const SizedBox(width: 4),
          Text(label, style: AuraText.small.copyWith(color: AuraSurface.ink)),
        ],
      ),
    );
  }
}
