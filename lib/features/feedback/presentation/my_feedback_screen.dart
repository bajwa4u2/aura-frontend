import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/navigation/navigation_authority.dart';
import '../../../core/product/product_language.dart';
import '../../../core/product/product_state.dart';
import '../../../core/product/product_state_view.dart';
import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';
import '../data/product_feedback_repository.dart';

/// WHAT I SENT, AND WHAT CAME OF IT.
///
/// The half that makes feedback worth giving. A suggestion box you can post
/// into but never see into teaches people that writing to us is pointless,
/// and they are right.
class MyFeedbackScreen extends ConsumerWidget {
  const MyFeedbackScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(myFeedbackProvider);

    return AuraScaffold(
      title: 'Your feedback',
      body: async.when(
        loading: () => const AuraProductState(
          state: ProductState.loading,
          subject: ProductNoun.feedback,
        ),
        // Resolved-but-unavailable, never an eternal spinner.
        error: (_, __) => AuraProductState(
          state: ProductState.error,
          subject: ProductNoun.feedback,
          onRecover: () => ref.invalidate(myFeedbackProvider),
        ),
        data: (items) => items.isEmpty
            ? _Empty(onSend: () => context.go(NavigationAuthority.feedbackRoute))
            : RefreshIndicator(
                onRefresh: () async => ref.invalidate(myFeedbackProvider),
                child: ListView.separated(
                  padding: const EdgeInsets.all(AuraSpace.s16),
                  itemCount: items.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: AuraSpace.s12),
                  itemBuilder: (_, i) => _FeedbackTile(record: items[i]),
                ),
              ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.onSend});

  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AuraSpace.s24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('You have not sent us anything yet.'),
            const SizedBox(height: AuraSpace.s12),
            FilledButton(onPressed: onSend, child: const Text('Send feedback')),
          ],
        ),
      ),
    );
  }
}

class _FeedbackTile extends StatelessWidget {
  const _FeedbackTile({required this.record});

  final FeedbackRecord record;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AuraSpace.s14),
      decoration: BoxDecoration(
        color: AuraSurface.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AuraSurface.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                record.intent.label,
                style: AuraText.small.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(width: AuraSpace.s8),
              _StateChip(state: record.state),
              const Spacer(),
              SelectableText(
                record.ref,
                style: AuraText.micro.copyWith(color: AuraSurface.muted),
              ),
            ],
          ),
          const SizedBox(height: AuraSpace.s8),
          Text(record.message, style: AuraText.body),
          if (record.outcome != null) ...[
            const SizedBox(height: AuraSpace.s12),
            Container(
              padding: const EdgeInsets.all(AuraSpace.s10),
              decoration: BoxDecoration(
                color: AuraSurface.elevated,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'What we did',
                    style:
                        AuraText.micro.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    record.outcome!,
                    style: AuraText.small.copyWith(color: AuraSurface.ink),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StateChip extends StatelessWidget {
  const _StateChip({required this.state});

  final FeedbackState state;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: AuraSurface.elevated,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AuraSurface.divider),
      ),
      child: Text(
        state.label,
        style: AuraText.micro.copyWith(color: AuraSurface.muted),
      ),
    );
  }
}
