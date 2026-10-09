import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/server_refusal.dart';
import '../../../core/navigation/navigation_authority.dart';
import '../../../core/net/dio_provider.dart';
import '../../../core/product/product_state.dart';
import '../../../core/product/product_state_view.dart';
import '../../../core/product/temporal.dart';
import '../../../core/ui/aura_radius.dart';
import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';
import '../../posts/domain/communication_continuity.dart';

/// One of my questions or issues, with what became of it.
class MyPublicRecord {
  const MyPublicRecord({
    required this.postId,
    required this.isIssue,
    required this.text,
    required this.createdAt,
    required this.continuity,
  });

  final String postId;
  final bool isIssue;
  final String text;
  final DateTime? createdAt;
  final ContinuityResult? continuity;

  factory MyPublicRecord.fromJson(Map<String, dynamic> j) => MyPublicRecord(
        postId: (j['postId'] ?? '').toString(),
        isIssue: (j['intent'] ?? '').toString().toUpperCase() == 'ISSUE',
        text: (j['text'] ?? '').toString(),
        createdAt: DateTime.tryParse((j['createdAt'] ?? '').toString()),
        continuity: ContinuityResult.fromJson(j['continuity']),
      );
}

final myPublicRecordsProvider = FutureProvider.autoDispose<List<MyPublicRecord>>((ref) async {
  final res = await ref.watch(dioProvider).get('/me/public-records');
  final body = res.data is Map ? res.data as Map : const {};
  final list = body['records'] is List ? body['records'] as List : const [];
  return [
    for (final r in list)
      if (r is Map) MyPublicRecord.fromJson(Map<String, dynamic>.from(r)),
  ];
});

String _lifecycleWords(AccountabilityLifecycle l) {
  switch (l.status) {
    case AccountabilityStatus.pending:
      return l.overdue ? 'waiting for a response, overdue' : 'waiting for a response';
    case AccountabilityStatus.responded:
      return 'responded';
    case AccountabilityStatus.committed:
      return 'committed to act';
    case AccountabilityStatus.resolved:
      return 'resolved';
    case AccountabilityStatus.reopened:
      return 'reopened';
    case AccountabilityStatus.stale:
    case AccountabilityStatus.dormant:
      return 'no response for a while';
    case AccountabilityStatus.institutionNoLongerActive:
      return 'no longer active on Aura';
    case AccountabilityStatus.unknown:
      return 'in progress';
  }
}

/// What became of one record, in a sentence.
String myRecordOutcome(MyPublicRecord r) {
  final c = r.continuity;
  if (c is RaiseIssueContinuity) {
    if (c.unrouted || c.accountabilityLifecycles.isEmpty) {
      return 'No institution answers for this topic yet, so it has not been sent to anyone.';
    }
    return c.accountabilityLifecycles
        .map((l) => '${l.institutionName.isEmpty ? 'An institution' : l.institutionName}: ${_lifecycleWords(l)}')
        .join(' · ');
  }
  if (c is AskContinuity) {
    switch (c.status) {
      case AskContinuityStatus.answered:
        return c.answeredBy.isEmpty ? 'Answered.' : 'Answered by ${c.answeredBy.join(', ')}.';
      case AskContinuityStatus.stale:
        return 'No answers yet.';
      case AskContinuityStatus.pending:
      case AskContinuityStatus.unknown:
        return c.routedTo.isEmpty ? 'Waiting for answers.' : 'Sent to ${c.routedTo.join(', ')}. Waiting for an answer.';
    }
  }
  return '';
}

/// MY QUESTIONS AND ISSUES (2026-10-09): there was nowhere for a person to see
/// what became of what they asked or raised.
class MyQuestionsScreen extends ConsumerWidget {
  const MyQuestionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(myPublicRecordsProvider);
    return AuraScaffold(
      title: 'My questions and issues',
      body: async.when(
        loading: () => const AuraProductState(state: ProductState.loading),
        error: (e, _) => AuraProductState(
          state: ProductState.retryableError,
          headline: 'Your questions could not be loaded',
          detail: ServerRefusal.of(e).message,
          onRecover: () => ref.invalidate(myPublicRecordsProvider),
        ),
        data: (records) {
          if (records.isEmpty) {
            return const AuraProductState(
              state: ProductState.empty,
              headline: 'Nothing asked or raised yet',
              detail: 'When you ask a question or raise an issue, you can follow here what each institution does with it.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(AuraSpace.s16),
            itemCount: records.length,
            separatorBuilder: (_, __) => const SizedBox(height: AuraSpace.s10),
            itemBuilder: (context, i) {
              final r = records[i];
              return InkWell(
                onTap: () => context.push(NavigationAuthority.postRoute(r.postId)),
                borderRadius: BorderRadius.circular(AuraRadius.card),
                child: Container(
                  padding: const EdgeInsets.all(AuraSpace.s14),
                  decoration: BoxDecoration(
                    color: AuraSurface.card,
                    borderRadius: BorderRadius.circular(AuraRadius.card),
                    border: Border.all(color: AuraSurface.divider),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        [r.isIssue ? 'Raised issue' : 'Question', if (r.createdAt != null) AuraTemporal.fullShort(r.createdAt!)]
                            .join(' · '),
                        style: AuraText.small.copyWith(color: AuraSurface.muted),
                      ),
                      const SizedBox(height: AuraSpace.s6),
                      Text(r.text, maxLines: 3, overflow: TextOverflow.ellipsis, style: AuraText.body.copyWith(height: 1.45)),
                      const SizedBox(height: AuraSpace.s8),
                      Text(myRecordOutcome(r), style: AuraText.small.copyWith(fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
