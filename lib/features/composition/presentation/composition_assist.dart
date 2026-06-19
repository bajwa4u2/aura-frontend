import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/net/dio_provider.dart';
import '../../../core/ui/aura_card.dart';
import '../../../core/ui/aura_platform_components.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';
import '../domain/composition_models.dart';

/// Single, reusable composition-assist panel.
///
/// Consolidates what used to be re-implemented per surface (post composer,
/// space creation, thread composer): "Writing support" (machine review +
/// apply) and "Translation" (preview + apply), including RTL handling and all
/// the busy/error/dismiss state. The host owns the text; this widget reads it
/// via [text] and writes revisions back through [onApply].
///
/// Endpoints (unchanged contract):
///   POST /composition/review     { text, surface }
///   POST /composition/apply      { sessionId, findingId, currentText }
///   POST /composition/translate  { text, targetLanguage }
class CompositionAssist extends ConsumerStatefulWidget {
  const CompositionAssist({
    super.key,
    required this.text,
    required this.surface,
    required this.onApply,
    this.enabled = true,
    this.note,
  });

  /// Current text the host is editing (post body, or title+description).
  final String text;

  /// Drives the `surface` hint sent to the review endpoint.
  final CompositionSurface surface;

  /// Called with revised text when the user applies a suggestion or a
  /// translation. The host writes it back into its own controller(s).
  final void Function(String newText) onApply;

  /// When false, all actions are disabled (e.g., while the host is posting).
  final bool enabled;

  /// Optional one-line note rendered under the heading (e.g., "Writing stays
  /// here.").
  final String? note;

  @override
  ConsumerState<CompositionAssist> createState() => _CompositionAssistState();
}

class _CompositionAssistState extends ConsumerState<CompositionAssist> {
  static const List<({String code, String label})> _languages = [
    (code: 'en', label: 'English'),
    (code: 'ur', label: 'Urdu'),
    (code: 'ar', label: 'Arabic'),
    (code: 'tr', label: 'Turkish'),
    (code: 'fa', label: 'Persian'),
    (code: 'fr', label: 'French'),
    (code: 'es', label: 'Spanish'),
    (code: 'de', label: 'German'),
    (code: 'hi', label: 'Hindi'),
    (code: 'bn', label: 'Bengali'),
    (code: 'pa', label: 'Punjabi'),
  ];

  bool _reviewBusy = false;
  String? _reviewError;
  CompositionReviewResult? _review;
  String? _reviewSnapshot;
  final Set<String> _applyingIds = <String>{};
  final Set<String> _dismissedIds = <String>{};

  bool _translateBusy = false;
  String? _translateError;
  String _targetLanguage = 'ur';
  CompositionTranslationResult? _translation;
  String? _translationSnapshot;

  @override
  void didUpdateWidget(covariant CompositionAssist oldWidget) {
    super.didUpdateWidget(oldWidget);
    final current = widget.text.trim();
    // Invalidate stale results when the host text moves away from what they
    // were computed against (but not when WE just applied them).
    if (_reviewSnapshot != null && _reviewSnapshot!.trim() != current) {
      _review = null;
      _reviewError = null;
      _reviewSnapshot = null;
      _dismissedIds.clear();
    }
    if (_translationSnapshot != null && _translationSnapshot!.trim() != current) {
      _translation = null;
      _translateError = null;
      _translationSnapshot = null;
    }
  }

  Dio get _dio => ref.read(dioProvider);

  List<CompositionSuggestion> get _visible {
    final r = _review;
    if (r == null) return const [];
    final out = <CompositionSuggestion>[];
    for (final s in r.suggestions) {
      if (_dismissedIds.contains(s.id)) continue;
      if (s.message.trim().isEmpty && s.replacement.trim().isEmpty) continue;
      out.add(s);
      if (out.length >= 2) break;
    }
    return out;
  }

  Future<void> _runReview() async {
    final text = widget.text.trim();
    if (text.isEmpty) return;
    if (_reviewBusy) return;
    setState(() {
      _reviewBusy = true;
      _reviewError = null;
    });
    try {
      final res = await _dio.post(
        '/composition/review',
        data: {'text': text, 'surface': widget.surface.name},
      );
      if (!mounted) return;
      setState(() {
        _review = CompositionReviewResult.fromJson(_asMap(res.data));
        _reviewSnapshot = text;
        _dismissedIds.clear();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _reviewError = 'Writing review could not run: $e');
    } finally {
      if (mounted) setState(() => _reviewBusy = false);
    }
  }

  Future<void> _applySuggestion(CompositionSuggestion s) async {
    final r = _review;
    if (r == null || s.id.trim().isEmpty) return;
    setState(() {
      _applyingIds.add(s.id);
      _reviewError = null;
    });
    try {
      final res = await _dio.post(
        '/composition/apply',
        data: {
          'sessionId': r.sessionId,
          'findingId': s.id,
          'currentText': widget.text,
        },
      );
      if (!mounted) return;
      final root = _asMap(res.data);
      final next = _firstNonEmpty([
        _str(root['text']),
        _str(root['updatedText']),
        _str(root['resultText']),
        _str(_asMap(root['data'])['text']),
        _str(_asMap(root['data'])['updatedText']),
      ], fallback: widget.text);

      if (next.trim().isNotEmpty && next != widget.text) {
        widget.onApply(next);
      }
      // Keep snapshots aligned with the applied text so didUpdateWidget on the
      // resulting rebuild doesn't wipe the refreshed review.
      _reviewSnapshot = next.trim();
      CompositionReviewResult? refreshed;
      try {
        refreshed = CompositionReviewResult.fromJson(root);
      } catch (_) {
        refreshed = null;
      }
      setState(() {
        if (refreshed != null && refreshed.suggestions.isNotEmpty) {
          _review = refreshed;
          _dismissedIds.clear();
        } else {
          _dismissedIds.add(s.id);
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _reviewError = 'Could not apply suggestion: $e');
    } finally {
      if (mounted) setState(() => _applyingIds.remove(s.id));
    }
  }

  Future<void> _translate() async {
    final text = widget.text.trim();
    if (text.isEmpty || _translateBusy) return;
    setState(() {
      _translateBusy = true;
      _translateError = null;
    });
    try {
      final res = await _dio.post(
        '/composition/translate',
        data: {'text': text, 'targetLanguage': _targetLanguage},
      );
      if (!mounted) return;
      final root = _asMap(res.data);
      final translated = _firstNonEmpty([
        _str(root['translatedText']),
        _str(root['text']),
        _str(_asMap(root['data'])['translatedText']),
        _str(_asMap(root['data'])['text']),
      ]);
      if (translated.isEmpty) throw Exception('Translation was empty.');
      setState(() {
        _translation = CompositionTranslationResult(
          translatedText: translated,
          targetLanguage: _targetLanguage,
        );
        _translationSnapshot = text;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _translateError = 'Translation could not run: $e');
    } finally {
      if (mounted) setState(() => _translateBusy = false);
    }
  }

  void _useTranslation() {
    final t = _translation;
    if (t == null || t.translatedText.trim().isEmpty) return;
    widget.onApply(t.translatedText);
    _translationSnapshot = t.translatedText.trim();
    setState(() {
      _translation = null;
      _review = null;
      _reviewSnapshot = null;
      _dismissedIds.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final hasText = widget.text.trim().isNotEmpty;
    final on = widget.enabled;
    final suggestions = _visible;

    return AuraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Writing support',
                  style: AuraText.body.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              AuraSecondaryButton(
                label: _reviewBusy ? 'Checking…' : 'Check',
                icon: Icons.auto_fix_high_outlined,
                onPressed: on && hasText && !_reviewBusy ? _runReview : null,
              ),
            ],
          ),
          if (widget.note != null) ...[
            const SizedBox(height: AuraSpace.s6),
            Text(
              widget.note!,
              style: AuraText.small.copyWith(color: AuraSurface.muted),
            ),
          ],
          if ((_reviewError ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: AuraSpace.s10),
            Text(
              _reviewError!,
              style: AuraText.small.copyWith(color: AuraSurface.coSun),
            ),
          ],
          if (suggestions.isNotEmpty) ...[
            const SizedBox(height: AuraSpace.s12),
            for (final s in suggestions) ...[
              _SuggestionTile(
                suggestion: s,
                applying: _applyingIds.contains(s.id),
                onApply: on && s.canApply ? () => _applySuggestion(s) : null,
                onDismiss: () => setState(() => _dismissedIds.add(s.id)),
              ),
              if (s != suggestions.last) const SizedBox(height: AuraSpace.s10),
            ],
          ] else if (!_reviewBusy &&
              hasText &&
              _reviewSnapshot != null) ...[
            const SizedBox(height: AuraSpace.s10),
            Text(
              'No suggestions right now.',
              style: AuraText.small.copyWith(color: AuraSurface.muted),
            ),
          ],
          const SizedBox(height: AuraSpace.s14),
          Container(height: 1, color: AuraSurface.divider),
          const SizedBox(height: AuraSpace.s14),
          // ── Translation ──────────────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _targetLanguage,
                  decoration: const InputDecoration(labelText: 'Translate to'),
                  items: [
                    for (final l in _languages)
                      DropdownMenuItem(value: l.code, child: Text(l.label)),
                  ],
                  onChanged: !on || _translateBusy
                      ? null
                      : (v) {
                          if (v == null) return;
                          setState(() {
                            _targetLanguage = v;
                            _translation = null;
                            _translateError = null;
                          });
                        },
                ),
              ),
              const SizedBox(width: AuraSpace.s12),
              AuraSecondaryButton(
                label: _translateBusy ? 'Preparing…' : 'Preview',
                icon: Icons.translate_outlined,
                onPressed: on && hasText && !_translateBusy ? _translate : null,
              ),
            ],
          ),
          if ((_translateError ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: AuraSpace.s10),
            Text(
              _translateError!,
              style: AuraText.small.copyWith(color: AuraSurface.coSun),
            ),
          ],
          if (_translation != null) ...[
            const SizedBox(height: AuraSpace.s12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AuraSpace.s12),
              decoration: BoxDecoration(
                color: AuraSurface.elevated,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AuraSurface.divider),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Preview',
                    style:
                        AuraText.small.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: AuraSpace.s8),
                  Directionality(
                    textDirection: _previewDirection(),
                    child: Text(
                      _translation!.translatedText,
                      style: AuraText.body,
                      textAlign: _previewDirection() == TextDirection.rtl
                          ? TextAlign.right
                          : TextAlign.left,
                    ),
                  ),
                  const SizedBox(height: AuraSpace.s10),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: AuraPrimaryButton(
                      label: 'Use translation',
                      icon: Icons.check_rounded,
                      onPressed: on ? _useTranslation : null,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  TextDirection _previewDirection() {
    final t = _translation;
    if (t != null && _isRtlCode(t.targetLanguage)) return TextDirection.rtl;
    final text = t?.translatedText ?? '';
    return RegExp(r'[֐-ࣿ]').hasMatch(text)
        ? TextDirection.rtl
        : TextDirection.ltr;
  }

  bool _isRtlCode(String? code) {
    final c = (code ?? '').trim().toLowerCase();
    return c == 'ur' || c == 'ar' || c == 'fa' || c == 'he' || c == 'ps' || c == 'sd';
  }

  // ── tolerant parsing helpers ───────────────────────────────────────────
  Map<String, dynamic> _asMap(dynamic v) {
    if (v is Map<String, dynamic>) return v;
    if (v is Map) return Map<String, dynamic>.from(v);
    return <String, dynamic>{};
  }

  String _str(dynamic v) => (v ?? '').toString().trim();

  String _firstNonEmpty(List<String?> values, {String fallback = ''}) {
    for (final v in values) {
      final s = (v ?? '').trim();
      if (s.isNotEmpty) return s;
    }
    return fallback;
  }
}

class _SuggestionTile extends StatelessWidget {
  const _SuggestionTile({
    required this.suggestion,
    required this.applying,
    required this.onApply,
    required this.onDismiss,
  });

  final CompositionSuggestion suggestion;
  final bool applying;
  final VoidCallback? onApply;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AuraSpace.s12),
      decoration: BoxDecoration(
        color: AuraSurface.page,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AuraSurface.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  suggestion.message.trim().isEmpty
                      ? 'Suggested refinement'
                      : suggestion.message,
                  style: AuraText.body.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              IconButton(
                tooltip: 'Dismiss',
                onPressed: onDismiss,
                icon: const Icon(Icons.close, size: 18),
              ),
            ],
          ),
          if (suggestion.replacement.trim().isNotEmpty) ...[
            const SizedBox(height: AuraSpace.s8),
            Text(
              suggestion.replacement,
              style: AuraText.body.copyWith(color: AuraSurface.muted),
            ),
          ],
          if (onApply != null) ...[
            const SizedBox(height: AuraSpace.s10),
            Align(
              alignment: Alignment.centerLeft,
              child: AuraSecondaryButton(
                label: applying ? 'Applying…' : 'Apply',
                icon: Icons.check_circle_outline,
                onPressed: applying ? null : onApply,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
