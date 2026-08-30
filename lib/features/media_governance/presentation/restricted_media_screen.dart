import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/media/media_url_resolver.dart';
import '../../../core/product/product_state.dart';
import '../../../core/product/product_state_view.dart';
import '../../../core/ui/aura_radius.dart';
import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';
import '../data/media_governance_repository.dart';
import '../data/media_restriction.dart';

/// CH-12 E6 — the member's route back.
///
/// D3's frozen chain is EXAMINATION → QUARANTINE → NOTICE → APPEAL → FINAL
/// DISPOSITION, and it rejects silent enforcement precisely because a verdict a
/// person cannot see or contest causes irreversible harm. This is where a
/// member sees the restriction and contests it.
///
/// ─────────────────────────────────────────────────────────────────────────────
/// EVERYTHING SHOWN HERE IS SERVER-DECIDED. The screen does not work out
/// whether an appeal is available, does not resolve standing, and does not
/// compose the explanation — it renders what the restriction endpoint returns.
/// A viewer without standing gets the same empty answer as someone looking at
/// an unrestricted file, so there is nothing here to leak.
///
/// It also never says the member did anything wrong. An examiner found a
/// property of a file; a person can forward a document they received in good
/// faith. The copy below talks about the file throughout.
/// ─────────────────────────────────────────────────────────────────────────────
class RestrictedMediaScreen extends ConsumerStatefulWidget {
  const RestrictedMediaScreen({super.key, required this.mediaId});

  final String mediaId;

  @override
  ConsumerState<RestrictedMediaScreen> createState() => _RestrictedMediaScreenState();
}

class _RestrictedMediaScreenState extends ConsumerState<RestrictedMediaScreen> {
  final TextEditingController _statement = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _statement.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final text = _statement.text.trim();
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ref
          .read(mediaGovernanceRepositoryProvider)
          .submitAppeal(widget.mediaId, text);
      if (!mounted) return;
      // Re-read from the server rather than assuming the outcome. The next
      // render shows the appeal the server actually recorded.
      ref.invalidate(mediaRestrictionProvider(widget.mediaId));
    } catch (e) {
      if (!mounted) return;
      // The server's own refusal, not a message invented here — it knows why.
      setState(() => _error = _messageFrom(e));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String _messageFrom(Object e) {
    final text = e.toString();
    if (text.contains('NO_APPEAL_STANDING')) {
      return 'You do not have standing to appeal this attachment.';
    }
    if (text.contains('NOT_QUARANTINED')) {
      return 'This attachment is not currently under review.';
    }
    return 'That could not be submitted just now. Please try again shortly.';
  }

  /// Drop any cached delivery URL for this object.
  ///
  /// `MediaUrlResolver` caches by mediaId, so after a reversal an image can
  /// keep rendering the refusal it cached while quarantined — the member is
  /// told their file is back and still sees it broken. Evicting on the
  /// transition is what makes the lifted notice true on screen.
  void _dropCachedUrl() {
    ref.read(mediaUrlResolverProvider).invalidate(widget.mediaId);
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(mediaRestrictionProvider(widget.mediaId));

    // Observed, not assumed: the eviction happens when the SERVER says the
    // restriction is gone, never because the client thinks it should be.
    ref.listen<AsyncValue<MediaRestriction>>(
      mediaRestrictionProvider(widget.mediaId),
      (previous, next) {
        final wasRestricted = previous?.valueOrNull?.restricted ?? true;
        final nowRestricted = next.valueOrNull?.restricted;
        if (wasRestricted && nowRestricted == false) _dropCachedUrl();
      },
    );

    return AuraScaffold(
      title: 'Attachment under review',
      body: async.when(
        loading: () => const AuraProductState(state: ProductState.loading),
        error: (_, __) => const _Unavailable(),
        data: (r) {
          // No standing, or nothing to say. Deliberately identical to the
          // "not restricted" case so this screen cannot be used to find out
          // whether someone else's file is restricted.
          if (!r.hasStanding || r.isEmpty) return const _Unavailable();
          return ListView(
            padding: const EdgeInsets.all(AuraSpace.s16),
            children: [
              if (r.restricted && r.notice != null) ...[
                _NoticeCard(notice: r.notice!),
                const SizedBox(height: AuraSpace.s16),
              ] else ...[
                const _RestoredCard(),
                const SizedBox(height: AuraSpace.s16),
              ],
              if (r.appeal != null) ...[
                _AppealStatusCard(appeal: r.appeal!),
                const SizedBox(height: AuraSpace.s16),
              ],
              if (r.canAppeal) _AppealForm(
                controller: _statement,
                submitting: _submitting,
                error: _error,
                onSubmit: _submit,
              ),
            ],
          );
        },
      ),
    );
  }
}

/// The shared "nothing to show you" state.
///
/// One widget for both "no standing" and "no restriction", because they must be
/// indistinguishable from the outside.
class _Unavailable extends StatelessWidget {
  const _Unavailable();

  @override
  Widget build(BuildContext context) {
    // `unavailable`, deliberately — not `error` and not `empty`. The Product
    // State Authority is explicit that access denial is neither, and this
    // surface shows the same thing whether the caller lacks standing or the
    // object simply is not restricted.
    return const AuraProductState(state: ProductState.unavailable);
  }
}

class _NoticeCard extends StatelessWidget {
  const _NoticeCard({required this.notice});

  final QuarantineNotice notice;

  /// A short heading per governed category.
  ///
  /// Describes the FILE, never the member. "This file contains…" is a
  /// statement about bytes; "you uploaded malware" would be an accusation the
  /// examination never made.
  String get _heading {
    switch (notice.category) {
      case 'MALICIOUS_CONTENT':
        return 'This file was found to contain malicious content';
      case 'EXECUTABLE_CONTENT':
        return 'This file can run content when opened';
      case 'POLICY_ACTION':
        return 'This file was restricted under Aura’s content policy';
      case 'UNSAFE_STRUCTURE':
      default:
        return 'This file could not be processed safely';
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = (notice.fileName ?? '').trim();
    return Container(
      padding: const EdgeInsets.all(AuraSpace.s16),
      decoration: BoxDecoration(
        color: AuraSurface.subtle,
        borderRadius: BorderRadius.circular(AuraRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_heading, style: AuraText.title),
          if (name.isNotEmpty) ...[
            const SizedBox(height: AuraSpace.s4),
            Text(name, style: AuraText.small.copyWith(color: AuraSurface.muted)),
          ],
          const SizedBox(height: AuraSpace.s12),

          // Element 5 — the governed, non-sensitive explanation, exactly as the
          // server composed it. Never re-worded here.
          Text(notice.context, style: AuraText.body),
          const SizedBox(height: AuraSpace.s12),

          // Element 2 — use is restricted, AND the file still exists. Members
          // reasonably assume "unavailable" means "deleted"; saying so plainly
          // is the difference between a restriction and a loss.
          const _Line('It is not shown to anyone while it is under review.'),
          const _Line('Your file has not been deleted.'),

          // Element 4 + 6 — automated, and preliminary.
          if (notice.automatedVerdict)
            const _Line('This was an automated check. No one has reviewed it yet.'),
          if (notice.isReversible)
            const _Line('This can be reversed if the check was wrong.'),
        ],
      ),
    );
  }
}

class _RestoredCard extends StatelessWidget {
  const _RestoredCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AuraSpace.s16),
      decoration: BoxDecoration(
        color: AuraSurface.subtle,
        borderRadius: BorderRadius.circular(AuraRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('This attachment is available again', style: AuraText.title),
          const SizedBox(height: AuraSpace.s8),
          Text(
            'The restriction has been lifted and the file is no longer under review.',
            style: AuraText.body,
          ),
        ],
      ),
    );
  }
}

class _AppealStatusCard extends StatelessWidget {
  const _AppealStatusCard({required this.appeal});

  final MediaAppeal appeal;

  /// Wording per status.
  ///
  /// No SLA is promised, because the governing policy deliberately declines to
  /// invent one — telling a member "within 48 hours" would be a commitment
  /// nobody has made.
  String get _label {
    switch (appeal.status) {
      case 'SUBMITTED':
        return 'Your review request has been received.';
      case 'UNDER_REVIEW':
        return 'Your review request is being looked at.';
      case 'REVERSED':
        return 'Your review request was accepted.';
      case 'UPHELD':
        return 'The restriction was confirmed after review.';
      case 'WITHDRAWN':
        return 'You withdrew this review request.';
      default:
        return 'Your review request has been recorded.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final summary = (appeal.decisionSummary ?? '').trim();
    final statement = (appeal.statement ?? '').trim();
    return Container(
      padding: const EdgeInsets.all(AuraSpace.s16),
      decoration: BoxDecoration(
        color: AuraSurface.subtle,
        borderRadius: BorderRadius.circular(AuraRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Review request', style: AuraText.title),
          const SizedBox(height: AuraSpace.s8),
          Text(_label, style: AuraText.body),
          if (statement.isNotEmpty) ...[
            const SizedBox(height: AuraSpace.s12),
            Text('What you told us',
                style: AuraText.small.copyWith(color: AuraSurface.muted)),
            const SizedBox(height: AuraSpace.s4),
            Text(statement, style: AuraText.body),
          ],
          if (summary.isNotEmpty) ...[
            const SizedBox(height: AuraSpace.s12),
            Text('Outcome', style: AuraText.small.copyWith(color: AuraSurface.muted)),
            const SizedBox(height: AuraSpace.s4),
            Text(summary, style: AuraText.body),
          ],
        ],
      ),
    );
  }
}

class _AppealForm extends StatelessWidget {
  const _AppealForm({
    required this.controller,
    required this.submitting,
    required this.error,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final bool submitting;
  final String? error;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Ask for a review', style: AuraText.title),
        const SizedBox(height: AuraSpace.s8),
        Text(
          'If you think this check was wrong, tell us what this file is. '
          'A person will look at it.',
          style: AuraText.body,
        ),
        const SizedBox(height: AuraSpace.s12),
        Semantics(
          label: 'Explain what this file is',
          textField: true,
          child: TextField(
            controller: controller,
            maxLines: null,
            maxLength: 2000,
            enabled: !submitting,
            decoration: const InputDecoration(
              hintText: 'What is this file?',
              border: OutlineInputBorder(),
            ),
          ),
        ),
        if (error != null) ...[
          const SizedBox(height: AuraSpace.s8),
          Text(error!, style: AuraText.small.copyWith(color: Colors.red)),
        ],
        const SizedBox(height: AuraSpace.s12),
        Semantics(
          button: true,
          enabled: !submitting,
          label: 'Send review request',
          child: FilledButton(
            onPressed: submitting ? null : onSubmit,
            child: submitting
                ? const SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Send review request'),
          ),
        ),
      ],
    );
  }
}

class _Line extends StatelessWidget {
  const _Line(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AuraSpace.s4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('•  ', style: AuraText.body.copyWith(color: AuraSurface.muted)),
          Expanded(child: Text(text, style: AuraText.body)),
        ],
      ),
    );
  }
}
