import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/net/dio_provider.dart';
import '../../../core/ui/aura_card.dart';
import '../../../core/ui/aura_platform_components.dart';
import '../../../core/ui/aura_radius.dart';
import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';
import '../../../core/ui/aura_text_block.dart';
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

Map<String, dynamic> _announcementAsMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return <String, dynamic>{};
}

String _announcementReadString(dynamic value) =>
    (value ?? '').toString().trim();

String _announcementDeepString(
  Map<String, dynamic> root,
  List<List<String>> candidatePaths,
) {
  for (final path in candidatePaths) {
    dynamic current = root;
    var ok = true;
    for (final key in path) {
      if (current is Map && current.containsKey(key)) {
        current = current[key];
      } else {
        ok = false;
        break;
      }
    }
    if (!ok) continue;
    final value = _announcementReadString(current);
    if (value.isNotEmpty) return value;
  }
  return '';
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

      if (trimmedSummary.isNotEmpty) {
        final res = await dio.post(
          '/composition/translate',
          data: {'text': trimmedSummary, 'targetLanguage': target},
        );
        final root = _announcementAsMap(res.data);
        translatedSummary = _announcementDeepString(root, const [
          ['translatedText'],
          ['translation', 'text'],
          ['data', 'translatedText'],
          ['data', 'text'],
        ]);
      }

      if (trimmedBody.isNotEmpty) {
        final res = await dio.post(
          '/composition/translate',
          data: {'text': trimmedBody, 'targetLanguage': target},
        );
        final root = _announcementAsMap(res.data);
        translatedBody = _announcementDeepString(root, const [
          ['translatedText'],
          ['translation', 'text'],
          ['data', 'translatedText'],
          ['data', 'text'],
        ]);
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
      setState(() {
        _translationError = 'Could not translate this announcement right now.';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not translate this announcement right now.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _translationBusy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(announcementBySlugProvider(widget.slug));

    return AuraScaffold(
      title: 'Announcement',
      showHomeAction: true,
      body: async.when(
        loading: () =>
            const Center(child: AuraLoadingState(message: 'Loading…')),
        error: (e, _) => Center(child: Text(e.toString())),
        data: (a) {
          if (a == null) {
            return const Center(child: Text('Not found'));
          }

          final title = a.title.isEmpty ? a.slug : a.title;
          final summary = a.summary.trim();
          final body = a.bodyMarkdown.trim();
          _targetLanguage ??= _defaultAnnouncementTranslationLanguage(context);

          return ListView(
            padding: const EdgeInsets.all(AuraSpace.s16),
            children: [
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
                        ],
                      ),
                    ],
                    if ((_translationError ?? '').trim().isNotEmpty) ...[
                      const SizedBox(height: AuraSpace.s10),
                      Text(
                        _translationError!,
                        style: AuraText.small.copyWith(color: Colors.redAccent),
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
                                ),
                              ),
                            ],
                            if ((_translatedBody ?? '').trim().isNotEmpty) ...[
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
    );
  }
}
