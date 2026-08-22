import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../errors/app_error_mapper.dart';
import '../net/dio_provider.dart';
import '../ui/aura_radius.dart';
import '../ui/aura_space.dart';
import '../ui/aura_surface.dart';
import '../ui/aura_text.dart';
import '../ui/aura_text_block.dart';
import 'communication_translation.dart';
import 'communication_translation_repository.dart';

/// Canonical "Translate" action for any publishable communication surface.
///
/// Drop this next to the body text of a personal post/reply/reshare,
/// institution post/reply/reshare, or announcement. It owns its own
/// language picker, original/translation toggle, RTL rendering, and error
/// handling — every surface gets the exact same on-demand, non-destructive
/// translation behavior instead of a bespoke per-screen implementation.
class CommunicationTranslateAction extends ConsumerStatefulWidget {
  const CommunicationTranslateAction({
    super.key,
    required this.objectType,
    required this.objectId,
    required this.sourceText,
    this.sourceLanguage,
    this.bodyStyle,
    this.translatedBodyBuilder,
    this.inline = false,
    this.onResultChanged,
  });

  final CommunicationObjectType objectType;
  final String objectId;
  final String sourceText;
  final String? sourceLanguage;
  final TextStyle? bodyStyle;

  /// Optional renderer for the translated text.
  ///
  /// The default renders plain text, which is right for a post, a reply or an
  /// announcement. It is wrong for a surface whose source is structured: an
  /// article body is Markdown, and rendering a translated article as plain
  /// text would show the reader raw `##` and `**` where the original showed
  /// headings and emphasis — a translation visibly poorer than the thing it
  /// translated.
  ///
  /// This exists so that surface can pass its OWN renderer instead of growing
  /// a parallel translate widget. Translation stays one capability; only the
  /// final rendering step is delegated to the surface that already knows how
  /// its body is written.
  final Widget Function(BuildContext context, String translatedText)?
      translatedBodyBuilder;

  /// Renders the CONTROL only, leaving the translation to appear beneath
  /// whatever row the control was placed in.
  ///
  /// Translate belongs to the thing being read, so on a surface with an action
  /// row it should sit beside React and Save rather than below the discussion —
  /// where it silently reads as translating the discussion. But a translated
  /// article is full-width prose and cannot live inside a horizontal row, so
  /// the two halves are separated rather than the control being wedged in.
  ///
  /// The result is still rendered by this widget, immediately below the row,
  /// using the same presentation as the default layout — separating them must
  /// not mean maintaining two of them.
  final bool inline;

  /// Reports the currently-shown translation, or null when the reader has
  /// switched back to the original. Only meaningful with [inline]; the host
  /// renders [AuraTranslationResult] wherever the translation belongs.
  final void Function(String? translatedText, String targetLanguage)?
      onResultChanged;

  @override
  ConsumerState<CommunicationTranslateAction> createState() =>
      _CommunicationTranslateActionState();
}

class _CommunicationTranslateActionState
    extends ConsumerState<CommunicationTranslateAction> {
  bool _busy = false;
  bool _showTranslation = false;
  String? _translatedText;
  String? _resolvedTargetLanguage;
  String? _error;

  Future<void> _pickLanguage() async {
    final current =
        (_resolvedTargetLanguage ?? defaultTranslationLanguage(context))
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
                  children: kTranslationLanguageLabels.entries.map((entry) {
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
      _resolvedTargetLanguage = selected.trim().toLowerCase();
      _error = null;
    });
    await _runTranslate();
  }

  Future<void> _runTranslate() async {
    final text = widget.sourceText.trim();
    if (text.isEmpty || _busy) return;

    final target =
        (_resolvedTargetLanguage ?? defaultTranslationLanguage(context))
            .toLowerCase();

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final dio = ref.read(dioProvider);
      final result = await translateCommunicationObject(
        dio,
        objectType: widget.objectType,
        objectId: widget.objectId,
        sourceText: text,
        sourceLanguage: widget.sourceLanguage,
        targetLanguage: target,
      );

      if (!mounted) return;
      setState(() {
        // A fallback result is the SOURCE text returned unchanged. Presenting
        // it as a translation would quietly mislead the reader, so it is
        // reported as the unavailability it is and nothing is shown as
        // translated.
        if (result.fallback) {
          _translatedText = null;
          _showTranslation = false;
          _error = 'Translation is unavailable right now. Please try again.';
          _publish();
          return;
        }
        _translatedText = result.translatedText;
        _resolvedTargetLanguage = result.targetLanguage;
        _showTranslation = true;
      });
      _publish();
    } catch (e) {
      if (!mounted) return;
      final appError = AppErrorMapper.from(e, feature: 'translate this');
      setState(() => _error = appError.message);

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(appError.message),
          action: appError.isAuthRequired
              ? SnackBarAction(
                  label: 'Sign in',
                  onPressed: () => context.go('/login'),
                )
              : null,
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Tells the host what is currently on show, so an inline control can have
  /// its translation rendered elsewhere on the page.
  void _publish() {
    if (!widget.inline) return;
    widget.onResultChanged?.call(
      _showTranslation ? _translatedText : null,
      _resolvedTargetLanguage ?? '',
    );
  }

  @override
  Widget build(BuildContext context) {
    _resolvedTargetLanguage ??= defaultTranslationLanguage(context);
    final label = translationLanguageLabel(_resolvedTargetLanguage!);
    final inline = widget.inline;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      // Inline, this control is placed INSIDE a horizontal action row, where a
      // max-width Column or Row would demand unbounded width and overflow.
      // Sizing to content is what lets Translate sit beside React and Save.
      mainAxisSize: inline ? MainAxisSize.min : MainAxisSize.max,
      children: [
        Row(
          mainAxisSize: inline ? MainAxisSize.min : MainAxisSize.max,
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(AuraRadius.pill),
              onTap: _busy
                  ? null
                  : (_showTranslation
                        ? () {
                            setState(() => _showTranslation = false);
                            _publish();
                          }
                        : (_translatedText != null ? _runTranslate : _pickLanguage)),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AuraSpace.s4,
                  vertical: AuraSpace.s4,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.translate,
                      size: 15,
                      color: AuraSurface.muted,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _busy
                          ? 'Translating…'
                          : (_showTranslation
                                ? 'Show original'
                                : (_translatedText != null
                                      ? 'Translate to $label'
                                      : 'Translate')),
                      style: AuraText.small.copyWith(
                        color: AuraSurface.muted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (!_busy && !_showTranslation) ...[
              const SizedBox(width: 4),
              InkWell(
                borderRadius: BorderRadius.circular(AuraRadius.pill),
                onTap: _pickLanguage,
                child: const Padding(
                  padding: EdgeInsets.all(AuraSpace.s4),
                  child: Icon(
                    Icons.expand_more,
                    size: 16,
                    color: AuraSurface.muted,
                  ),
                ),
              ),
            ],
          ],
        ),
        if ((_error ?? '').trim().isNotEmpty) ...[
          const SizedBox(height: AuraSpace.s8),
          Text(
            _error!,
            style: AuraText.small.copyWith(color: AuraSurface.coSun),
          ),
        ],
        if (!widget.inline && _showTranslation && (_translatedText ?? '').trim().isNotEmpty) ...[
          const SizedBox(height: AuraSpace.s12),
          AuraTranslationResult(
            translatedText: _translatedText!,
            targetLanguage: _resolvedTargetLanguage!,
            bodyStyle: widget.bodyStyle,
            bodyBuilder: widget.translatedBodyBuilder,
          ),
        ],
      ],
    );
  }
}

/// The translated body, presented.
///
/// Extracted so an inline control can place its result somewhere else on the
/// page WITHOUT a second copy of this presentation existing. Separating the
/// control from the result must not mean maintaining two results.
class AuraTranslationResult extends StatelessWidget {
  const AuraTranslationResult({
    super.key,
    required this.translatedText,
    required this.targetLanguage,
    this.bodyStyle,
    this.bodyBuilder,
  });

  final String translatedText;
  final String targetLanguage;
  final TextStyle? bodyStyle;
  final Widget Function(BuildContext context, String translatedText)?
      bodyBuilder;

  @override
  Widget build(BuildContext context) {
    return Container(
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
          // Names what is being shown and in which language, so a translation
          // is never mistaken for the author's own words.
          Text(
            'Translation · ${translationLanguageLabel(targetLanguage)}',
            style: AuraText.small.copyWith(
              color: AuraSurface.muted,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AuraSpace.s8),
          Directionality(
            textDirection: textDirectionFor(targetLanguage),
            child: bodyBuilder?.call(context, translatedText) ??
                AuraTextBlock(
                  translatedText,
                  style: bodyStyle,
                  selectable: true,
                ),
          ),
        ],
      ),
    );
  }
}
