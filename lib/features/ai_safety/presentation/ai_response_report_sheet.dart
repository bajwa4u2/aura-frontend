// Bottom-sheet report flow for AI responses.
//
// Microsoft Store §11.16 (Live Generative AI Content) compliance: every
// surface that renders generative-AI text must give the end user a way
// to report inappropriate output. The sheet is intentionally calm and
// product-grade — categories on top, optional note, single submit
// button. No social-media-style noise. Success state is a quiet
// confirmation that the report was filed.
//
// Surfaces that adopt this sheet should call `showAiResponseReportSheet`
// from an overflow menu on the assistant message. The required
// arguments are the AI text the user is reporting (snapshot) and the
// originating surface name (e.g. 'support_agent'); conversation and
// message ids are optional but recommended so operator triage can
// group reports.

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ui/aura_radius.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';
import '../data/ai_reports_repository.dart';

Future<bool?> showAiResponseReportSheet(
  BuildContext context, {
  required String contentSnapshot,
  required String surface,
  String? conversationId,
  String? messageId,
  Map<String, dynamic>? metadata,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: AuraSurface.page,
    builder: (ctx) => _AiResponseReportSheet(
      contentSnapshot: contentSnapshot,
      surface: surface,
      conversationId: conversationId,
      messageId: messageId,
      metadata: metadata,
    ),
  );
}

class _AiResponseReportSheet extends ConsumerStatefulWidget {
  const _AiResponseReportSheet({
    required this.contentSnapshot,
    required this.surface,
    this.conversationId,
    this.messageId,
    this.metadata,
  });

  final String contentSnapshot;
  final String surface;
  final String? conversationId;
  final String? messageId;
  final Map<String, dynamic>? metadata;

  @override
  ConsumerState<_AiResponseReportSheet> createState() =>
      _AiResponseReportSheetState();
}

class _AiResponseReportSheetState
    extends ConsumerState<_AiResponseReportSheet> {
  AiReportCategory? _category;
  final TextEditingController _noteCtrl = TextEditingController();
  bool _submitting = false;
  bool _submitted = false;
  String? _error;

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  bool get _canSubmit => _category != null && !_submitting;

  Future<void> _submit() async {
    if (!_canSubmit) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ref.read(aiReportsRepositoryProvider).submit(
            category: _category!,
            contentSnapshot: widget.contentSnapshot,
            note: _noteCtrl.text,
            conversationId: widget.conversationId,
            messageId: widget.messageId,
            surface: widget.surface,
            metadata: widget.metadata,
          );
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _submitted = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = _readError(e);
      });
    }
  }

  String _readError(Object e) {
    if (e is DioException) {
      if (e.response?.statusCode == 401 || e.response?.statusCode == 403) {
        return 'You need to be signed in to submit a report.';
      }
      if (e.response?.statusCode == 429) {
        return 'Too many reports right now. Please try again shortly.';
      }
    }
    return 'Could not submit your report. Please try again.';
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final viewInsets = mediaQuery.viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        AuraSpace.s20,
        0,
        AuraSpace.s20,
        AuraSpace.s20 + viewInsets,
      ),
      child: SingleChildScrollView(
        child: _submitted ? _buildSuccess(context) : _buildForm(context),
      ),
    );
  }

  Widget _buildForm(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: AuraSpace.s4),
        const Text('Report AI response', style: AuraText.title),
        const SizedBox(height: AuraSpace.s6),
        Text(
          'AI responses can occasionally be inaccurate or inappropriate. '
          'Reports help us tune the system and catch unsafe output.',
          style: AuraText.small.copyWith(color: AuraSurface.muted, height: 1.5),
        ),
        const SizedBox(height: AuraSpace.s18),
        Text(
          'WHAT\'S WRONG?',
          style: AuraText.micro.copyWith(
            color: AuraSurface.muted,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: AuraSpace.s8),
        ...AiReportCategory.values.map(
          (c) => _CategoryRow(
            category: c,
            selected: _category == c,
            onTap: _submitting
                ? null
                : () => setState(() => _category = c),
          ),
        ),
        const SizedBox(height: AuraSpace.s16),
        Text(
          'ADDITIONAL DETAILS (OPTIONAL)',
          style: AuraText.micro.copyWith(
            color: AuraSurface.muted,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: AuraSpace.s8),
        Container(
          decoration: BoxDecoration(
            color: AuraSurface.card,
            borderRadius: BorderRadius.circular(AuraRadius.md),
            border: Border.all(color: AuraSurface.divider),
          ),
          child: TextField(
            controller: _noteCtrl,
            enabled: !_submitting,
            maxLines: 4,
            maxLength: 2000,
            style: AuraText.body,
            decoration: const InputDecoration(
              hintText: 'What went wrong with this response?',
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(
                horizontal: AuraSpace.s12,
                vertical: AuraSpace.s10,
              ),
            ),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: AuraSpace.s10),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AuraSpace.s12,
              vertical: AuraSpace.s8,
            ),
            decoration: BoxDecoration(
              color: AuraSurface.coRose.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(AuraRadius.md),
              border:
                  Border.all(color: AuraSurface.coRose.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline_rounded,
                    size: 14, color: AuraSurface.coRose),
                const SizedBox(width: AuraSpace.s6),
                Expanded(
                  child: Text(
                    _error!,
                    style:
                        AuraText.small.copyWith(color: AuraSurface.coRose),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: AuraSpace.s16),
        Row(
          children: [
            Expanded(child: _SubmitButton(active: _canSubmit, submitting: _submitting, onTap: _submit)),
            const SizedBox(width: AuraSpace.s10),
            TextButton(
              onPressed: _submitting ? null : () => Navigator.of(context).pop(false),
              child: Text(
                'Cancel',
                style:
                    AuraText.small.copyWith(color: AuraSurface.muted),
              ),
            ),
          ],
        ),
        const SizedBox(height: AuraSpace.s4),
        Text(
          'Reports are reviewed by the Aura team. We never share the report or your account information with the AI provider.',
          style: AuraText.micro.copyWith(color: AuraSurface.faint, height: 1.5),
        ),
      ],
    );
  }

  Widget _buildSuccess(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: AuraSpace.s4),
        Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AuraSurface.coVerdant.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(AuraRadius.pill),
                border: Border.all(
                  color: AuraSurface.coVerdant.withValues(alpha: 0.35),
                ),
              ),
              child: const Icon(
                Icons.check_rounded,
                size: 18,
                color: AuraSurface.coVerdant,
              ),
            ),
            const SizedBox(width: AuraSpace.s10),
            const Text('Report submitted', style: AuraText.title),
          ],
        ),
        const SizedBox(height: AuraSpace.s10),
        Text(
          'Thanks for flagging this response. The Aura team will review it. '
          'Your account stays private — this report is internal only.',
          style: AuraText.body.copyWith(color: AuraSurface.muted, height: 1.5),
        ),
        const SizedBox(height: AuraSpace.s18),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Close'),
          ),
        ),
      ],
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    required this.category,
    required this.selected,
    required this.onTap,
  });

  final AiReportCategory category;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AuraRadius.md),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AuraSpace.s12,
            vertical: AuraSpace.s10,
          ),
          decoration: BoxDecoration(
            color: selected ? AuraSurface.accentSoft : AuraSurface.card,
            borderRadius: BorderRadius.circular(AuraRadius.md),
            border: Border.all(
              color: selected
                  ? AuraSurface.accent.withValues(alpha: 0.6)
                  : AuraSurface.divider,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    width: 2,
                    color: selected ? AuraSurface.accent : AuraSurface.muted,
                  ),
                  color: selected ? AuraSurface.accent : Colors.transparent,
                ),
                child: selected
                    ? const Icon(Icons.check_rounded, size: 12, color: Colors.white)
                    : null,
              ),
              const SizedBox(width: AuraSpace.s10),
              Expanded(
                child: Text(
                  category.label,
                  style: AuraText.body.copyWith(
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SubmitButton extends StatelessWidget {
  const _SubmitButton({
    required this.active,
    required this.submitting,
    required this.onTap,
  });

  final bool active;
  final bool submitting;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: active ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(
          horizontal: AuraSpace.s14,
          vertical: AuraSpace.s12,
        ),
        decoration: BoxDecoration(
          color: active ? AuraSurface.accent : AuraSurface.card,
          borderRadius: BorderRadius.circular(AuraRadius.pill),
          border: Border.all(
            color: active
                ? AuraSurface.accent.withValues(alpha: 0.6)
                : AuraSurface.divider,
          ),
        ),
        child: Center(
          child: submitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(
                  'Submit report',
                  style: AuraText.small.copyWith(
                    color: active ? Colors.white : AuraSurface.muted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
        ),
      ),
    );
  }
}
