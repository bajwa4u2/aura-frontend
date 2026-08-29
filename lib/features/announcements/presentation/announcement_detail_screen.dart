import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/shell/rail/rail_composition.dart';
import '../../../core/auth/admin_access_provider.dart';
import '../../../core/navigation/canonical_destinations.dart';
import '../../../core/errors/app_error_mapper.dart';
import '../../../core/link_preview/display_link_preview.dart';
import '../../../core/media/aura_media_frame.dart';
import '../../../core/media/canonical_media_thumb.dart';
import '../../../core/net/dio_provider.dart';
import '../../../core/translation/communication_translation.dart'
    show CommunicationObjectType;
import '../../../core/translation/communication_translation_repository.dart';
import '../../../core/ui/aura_card.dart';
import '../../../core/ui/aura_platform_components.dart';
import '../../../core/ui/aura_radius.dart';
import '../../../core/ui/aura_responsive.dart';
import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';
import '../../../core/ui/aura_text_block.dart';
import '../../../core/ui/surface/aura_discourse_surface.dart';
import '../../feed/domain/feed_media.dart';
import '../../posts/presentation/widgets/post_card/post_card_utils.dart';
import '../../share/aura_share_sheet.dart';
import '../../updates/providers.dart';
import '../domain/announcement.dart';
import '../providers.dart';

const Map<String, String> _announcementTranslationLanguageLabels = {
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

String _announcementLanguageLabel(String code) {
  final key = code.trim().toLowerCase();
  return _announcementTranslationLanguageLabels[key] ?? key.toUpperCase();
}

String _defaultAnnouncementTranslationLanguage(BuildContext context) {
  final code = Localizations.localeOf(
    context,
  ).languageCode.trim().toLowerCase();
  if (_announcementTranslationLanguageLabels.containsKey(code)) return code;
  return 'en';
}

bool _announcementHasRtlScript(String text) {
  final value = text.trim();
  if (value.isEmpty) return false;
  final rtl = RegExp(
    r'[\u0590-\u05FF\u0600-\u06FF\u0750-\u077F\u08A0-\u08FF\uFB50-\uFDFF\uFE70-\uFEFF]',
  );
  return rtl.hasMatch(value);
}

TextDirection _announcementDirectionFor(String text) {
  return _announcementHasRtlScript(text)
      ? TextDirection.rtl
      : TextDirection.ltr;
}

TextAlign _announcementAlignFor(String text) {
  return _announcementHasRtlScript(text) ? TextAlign.right : TextAlign.left;
}

class AnnouncementDetailScreen extends ConsumerStatefulWidget {
  const AnnouncementDetailScreen({super.key, required this.slug});
  final String slug;

  @override
  ConsumerState<AnnouncementDetailScreen> createState() =>
      _AnnouncementDetailScreenState();
}

class _AnnouncementDetailScreenState
    extends ConsumerState<AnnouncementDetailScreen> {
  bool _translationBusy = false;
  String? _translationError;
  String? _translatedSummary;
  String? _translatedBody;
  bool _showTranslation = false;
  String? _targetLanguage;
  final Set<String> _markedAnnouncementIds = <String>{};

  String _fmtDate(DateTime dt) {
    final d = dt.toLocal();
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')} '
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _pickTranslationLanguage(BuildContext context) async {
    final current =
        (_targetLanguage ?? _defaultAnnouncementTranslationLanguage(context))
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
                  children: _announcementTranslationLanguageLabels.entries.map((
                    entry,
                  ) {
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
      _targetLanguage = selected.trim().toLowerCase();
      _translationError = null;
    });
  }

  Future<void> _translateAnnouncement({
    required BuildContext context,
    required String announcementId,
    required String summary,
    required String body,
  }) async {
    final trimmedSummary = summary.trim();
    final trimmedBody = body.trim();
    if ((trimmedSummary.isEmpty && trimmedBody.isEmpty) || _translationBusy) {
      return;
    }

    final target =
        (_targetLanguage ?? _defaultAnnouncementTranslationLanguage(context))
            .toLowerCase();

    setState(() {
      _translationBusy = true;
      _translationError = null;
    });

    try {
      final dio = ref.read(dioProvider);

      String translatedSummary = '';
      String translatedBody = '';

      // Summary and body are translated as two calls against the same
      // canonical endpoint (each cached independently, keyed by its own
      // content fingerprint) rather than concatenated into one request —
      // preserves the summary/body structural split on the translated side.
      if (trimmedSummary.isNotEmpty) {
        // Same objectId as the body call below — the cache key already
        // disambiguates on content fingerprint, so summary vs. body never
        // collide even though both target the same announcement.
        final result = await translateCommunicationObject(
          dio,
          objectType: CommunicationObjectType.announcement,
          objectId: announcementId,
          sourceText: trimmedSummary,
          targetLanguage: target,
        );
        translatedSummary = result.translatedText;
      }

      if (trimmedBody.isNotEmpty) {
        final result = await translateCommunicationObject(
          dio,
          objectType: CommunicationObjectType.announcement,
          objectId: announcementId,
          sourceText: trimmedBody,
          targetLanguage: target,
        );
        translatedBody = result.translatedText;
      }

      if (!mounted) return;
      setState(() {
        _translatedSummary = translatedSummary;
        _translatedBody = translatedBody;
        _showTranslation = true;
        _targetLanguage = target;
      });
    } catch (e) {
      if (!context.mounted) return;
      final message = AppErrorMapper.from(e, feature: 'translate this').message;
      setState(() => _translationError = message);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) {
        setState(() => _translationBusy = false);
      }
    }
  }

  /// Withdraw / remove, for the authority that publishes announcements.
  Widget _buildAdminActions(Announcement a) {
    return PopupMenuButton<String>(
      tooltip: 'Manage this announcement',
      itemBuilder: (context) => const [
        PopupMenuItem<String>(
          value: 'unpublish',
          child: Text('Unpublish'),
        ),
        PopupMenuItem<String>(
          value: 'remove',
          child: Text('Remove'),
        ),
      ],
      onSelected: (choice) {
        if (choice == 'unpublish') {
          unawaited(_unpublish(a));
        } else if (choice == 'remove') {
          unawaited(_remove(a));
        }
      },
    );
  }

  Future<bool> _confirm({
    required String title,
    required String body,
    required String confirmLabel,
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AuraSurface.page,
        title: Text(title, style: AuraText.subtitle),
        content: Text(body, style: AuraText.body),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return ok ?? false;
  }

  Future<void> _unpublish(Announcement a) async {
    final ok = await _confirm(
      title: 'Unpublish this announcement?',
      body: 'It stops appearing to readers. It is kept, and can be published '
          'again.',
      confirmLabel: 'Unpublish',
    );
    if (!ok || !mounted) return;
    try {
      await ref.read(announcementsRepoProvider).unpublish(a.id);
      if (!mounted) return;
      ref.invalidate(announcementBySlugProvider(widget.slug));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unpublished.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppErrorMapper.from(e, feature: 'unpublish this').message,
          ),
        ),
      );
    }
  }

  Future<void> _remove(Announcement a) async {
    final ok = await _confirm(
      title: 'Remove this announcement?',
      body: 'It is taken down and no longer listed.',
      confirmLabel: 'Remove',
    );
    if (!ok || !mounted) return;
    try {
      await ref.read(announcementsRepoProvider).remove(a.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Removed.')),
      );
      // The address no longer resolves to anything worth standing on.
      if (context.canPop()) {
        context.pop();
      } else {
        context.go(announcementsIndexDestination());
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppErrorMapper.from(e, feature: 'remove this').message,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(announcementBySlugProvider(widget.slug));

    // A PUBLISHED ANNOUNCEMENT MUST BE WITHDRAWABLE.
    //
    // `unpublish` and `remove` existed on the repository, and the backend has
    // carried soft-delete for both admin and institution announcements the
    // whole time -- but nothing in the app ever called any of it. Both ends
    // were built and wired to nothing, so an announcement, once published,
    // could not be taken down from inside Aura at all. On a governance
    // surface that is the worst way for a capability to be missing.
    //
    // The two are kept distinct because they mean different things:
    // unpublishing withdraws it from view and keeps it; removing is the
    // deletion. Neither is offered to anyone who cannot already administer
    // announcements -- the same authority that publishes them.
    final isAdmin =
        ref.watch(appAdminAccessProvider).valueOrNull?.isAdmin ?? false;
    final loaded = async.valueOrNull;

    return AuraScaffold(
      title: 'Announcement',
      showHomeAction: true,
      actions: (isAdmin && loaded != null)
          ? <Widget>[_buildAdminActions(loaded)]
          : null,
      // Discourse detail composition: the page widens to host a
      // contextual rail; AuraDiscourseSurface keeps the announcement
      // body itself at the kReadWidth reading measure and drops the
      // rail at laptop / mobile widths.
      maxWidth: kWorkspaceWidth,
      body: AuraDiscourseSurface(
        railModules: discourseDetailRailModules(),
        reading: async.when(
          loading: () =>
              const Center(child: AuraLoadingState(message: 'Loading…')),
          error: (e, _) => Center(
            child: Text(
              AppErrorMapper.from(e, feature: 'view this announcement').message,
            ),
          ),
          data: (a) {
            if (a == null) {
              return const Center(child: Text('Not found'));
            }
            if (a.id.isNotEmpty && _markedAnnouncementIds.add(a.id)) {
              Future.microtask(() {
                ref
                    .read(notificationsControllerProvider.notifier)
                    .markReadForTarget(announcementId: a.id);
              });
            }

            final title = a.title.isEmpty ? a.slug : a.title;
            final summary = a.summary.trim();
            final body = a.bodyMarkdown.trim();
            _targetLanguage ??= _defaultAnnouncementTranslationLanguage(
              context,
            );

            final media = FeedMedia.listFromJson(a.media);

            return ListView(
              padding: const EdgeInsets.all(AuraSpace.s16),
              children: [
                if (media.isNotEmpty) ...[
                  for (final m in media) ...[
                    CanonicalMediaThumb(
                      media: m,
                      mode: AuraMediaFrameMode.detail,
                      downloadContext: 'announcement-media',
                    ),
                    const SizedBox(height: AuraSpace.s10),
                  ],
                  const SizedBox(height: AuraSpace.s6),
                ] else if (a.linkUrl != null && a.linkUrl!.isNotEmpty) ...[
                  // Compose Link Intelligence / OG Preview -- Phase 1
                  // (Announcement extension); Item 14 extends internal Aura
                  // references to a live-revalidated governed preview.
                  // Mutually exclusive with media, same rendering rule
                  // Post/InstitutionPost already use (one attachment slot:
                  // media or link, not both) -- positioned as its own
                  // top-level block above the AuraCard rather than inside
                  // it, matching this screen's own existing media-placement
                  // layout rather than unified_feed_card.dart's in-card
                  // placement.
                  DisplayLinkPreview(
                    linkUrl: a.linkUrl!,
                    linkTitle: a.linkTitle,
                    linkDescription: a.linkDescription,
                    linkSiteName: a.linkSiteName,
                    linkImageUrl: a.linkImageUrl,
                  ),
                  const SizedBox(height: AuraSpace.s6),
                ],
                AuraCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Directionality(
                        textDirection: _announcementDirectionFor(title),
                        child: AuraTextBlock(
                          title,
                          textAlign: _announcementAlignFor(title),
                          style: AuraText.h1,
                          selectable: true,
                        ),
                      ),
                      const SizedBox(height: AuraSpace.s8),
                      if (a.publishedAt != null)
                        Text(
                          'Published: ${_fmtDate(a.publishedAt!)}',
                          style: AuraText.small,
                        ),
                      if (summary.isNotEmpty) ...[
                        const SizedBox(height: AuraSpace.s12),
                        Directionality(
                          textDirection: _announcementDirectionFor(summary),
                          child: AuraTextBlock(
                            summary,
                            textAlign: _announcementAlignFor(summary),
                            style: AuraText.body.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                            selectable: true,
                          ),
                        ),
                      ],
                      if (body.isNotEmpty) ...[
                        const SizedBox(height: AuraSpace.s16),
                        Directionality(
                          textDirection: _announcementDirectionFor(body),
                          child: AuraTextBlock(
                            body,
                            textAlign: _announcementAlignFor(body),
                            style: AuraText.body,
                            selectable: true,
                          ),
                        ),
                      ],
                      if (summary.isNotEmpty || body.isNotEmpty) ...[
                        const SizedBox(height: AuraSpace.s14),
                        Wrap(
                          spacing: AuraSpace.s10,
                          runSpacing: AuraSpace.s10,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            InkWell(
                              onTap: _translationBusy
                                  ? null
                                  : () => _translateAnnouncement(
                                      context: context,
                                      announcementId: a.id,
                                      summary: summary,
                                      body: body,
                                    ),
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
                                  border: Border.all(
                                    color: AuraSurface.divider,
                                  ),
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
                                      _announcementLanguageLabel(
                                        _targetLanguage ??
                                            _defaultAnnouncementTranslationLanguage(
                                              context,
                                            ),
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
                                    ),
                                  ),
                                ),
                              ),
                            // External share for announcements. The
                            // backend `getPublicBySlug` only resolves
                            // `audience=PUBLIC`+`status=PUBLISHED` rows,
                            // so an announcement that reached this screen
                            // via /announcements/<slug> is always
                            // externally shareable. The URL renders an
                            // OG-rich preview at auraplatform.org/p/a/<slug>.
                            InkWell(
                              onTap: () => showAuraShareSheet(
                                context,
                                shareUrl: canonicalAnnouncementUrl(a.slug),
                                headline: 'Share this announcement',
                                subtitle:
                                    'A public, crawler-friendly link that previews on LinkedIn, X, Discord, Slack, Facebook.',
                                emailSubject: 'Aura announcement',
                              ),
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
                                  border: Border.all(
                                    color: AuraSurface.divider,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.ios_share_rounded,
                                      size: 14,
                                      color: AuraSurface.muted,
                                    ),
                                    const SizedBox(width: AuraSpace.s6),
                                    Text(
                                      'Share',
                                      style: AuraText.small.copyWith(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      if ((_translationError ?? '').trim().isNotEmpty) ...[
                        const SizedBox(height: AuraSpace.s10),
                        Text(
                          _translationError!,
                          style: AuraText.small.copyWith(
                            color: Colors.redAccent,
                          ),
                        ),
                      ],
                      if (_showTranslation &&
                          ((_translatedSummary ?? '').trim().isNotEmpty ||
                              (_translatedBody ?? '').trim().isNotEmpty)) ...[
                        const SizedBox(height: AuraSpace.s14),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(AuraSpace.s14),
                          decoration: BoxDecoration(
                            color: AuraSurface.elevated,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AuraSurface.divider),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Translation · ${_announcementLanguageLabel(_targetLanguage ?? _defaultAnnouncementTranslationLanguage(context))}',
                                style: AuraText.small.copyWith(
                                  color: AuraSurface.muted,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              if ((_translatedSummary ?? '')
                                  .trim()
                                  .isNotEmpty) ...[
                                const SizedBox(height: AuraSpace.s8),
                                Directionality(
                                  textDirection: _announcementDirectionFor(
                                    _translatedSummary!,
                                  ),
                                  child: AuraTextBlock(
                                    _translatedSummary!,
                                    textAlign: _announcementAlignFor(
                                      _translatedSummary!,
                                    ),
                                    style: AuraText.body.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                    selectable: true,
                                  ),
                                ),
                              ],
                              if ((_translatedBody ?? '')
                                  .trim()
                                  .isNotEmpty) ...[
                                const SizedBox(height: AuraSpace.s12),
                                Directionality(
                                  textDirection: _announcementDirectionFor(
                                    _translatedBody!,
                                  ),
                                  child: AuraTextBlock(
                                    _translatedBody!,
                                    textAlign: _announcementAlignFor(
                                      _translatedBody!,
                                    ),
                                    style: AuraText.body,
                                    selectable: true,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
