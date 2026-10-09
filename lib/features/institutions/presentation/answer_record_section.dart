import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/navigation/navigation_authority.dart';
import '../../../core/net/dio_provider.dart';
import '../../../core/product/temporal.dart';
import '../../../core/ui/aura_radius.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';

/// How an institution has answered public questions and issues over the last
/// twelve months (2026-10-09).
class AnswerRecord {
  const AnswerRecord({
    required this.received,
    required this.waiting,
    required this.answered,
    required this.committed,
    required this.resolved,
    required this.recentResolutions,
  });

  final int received;
  final int waiting;
  final int answered;
  final int committed;
  final int resolved;
  final List<({String postId, String issue, String statement, DateTime? at})> recentResolutions;

  factory AnswerRecord.fromJson(Map<String, dynamic> j) {
    int n(dynamic v) => v is num ? v.toInt() : int.tryParse('${v ?? ''}') ?? 0;
    return AnswerRecord(
      received: n(j['received']),
      waiting: n(j['waiting']),
      answered: n(j['answered']),
      committed: n(j['committed']),
      resolved: n(j['resolved']),
      recentResolutions: [
        if (j['recentResolutions'] is List)
          for (final r in (j['recentResolutions'] as List).whereType<Map>())
            (
              postId: '${r['postId'] ?? ''}',
              issue: '${r['issue'] ?? ''}',
              statement: '${r['statement'] ?? ''}',
              at: DateTime.tryParse('${r['resolvedAt'] ?? ''}'),
            ),
      ],
    );
  }
}

final answerRecordProvider = FutureProvider.autoDispose.family<AnswerRecord, String>((ref, slug) async {
  final res = await ref.watch(dioProvider).get('/public/institutions/$slug/answer-record');
  final body = res.data is Map ? Map<String, dynamic>.from(res.data as Map) : <String, dynamic>{};
  final data = body['data'] is Map ? Map<String, dynamic>.from(body['data'] as Map) : body;
  return AnswerRecord.fromJson(data);
});

/// ANSWERING THE PUBLIC — on the institution's public page. The topic setup
/// promised that responses and resolutions are visible on the public profile;
/// this is where. It hides itself when nothing has reached the institution.
class AnswerRecordSection extends ConsumerWidget {
  const AnswerRecordSection({super.key, required this.slug});

  final String slug;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (slug.trim().isEmpty) return const SizedBox.shrink();
    final record = ref.watch(answerRecordProvider(slug)).valueOrNull;
    if (record == null || record.received == 0) return const SizedBox.shrink();

    Widget stat(String label, int count, Color color) => Expanded(
          child: Column(
            children: [
              Text('$count', style: AuraText.title.copyWith(color: color, fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text(label, style: AuraText.micro.copyWith(color: AuraSurface.muted), textAlign: TextAlign.center),
            ],
          ),
        );

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: AuraSpace.s14),
      padding: const EdgeInsets.all(AuraSpace.s16),
      decoration: BoxDecoration(
        color: AuraSurface.card,
        borderRadius: BorderRadius.circular(AuraRadius.card),
        border: Border.all(color: AuraSurface.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Answering the public', style: AuraText.body.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: AuraSpace.s4),
          Text(
            record.received == 1
                ? 'In the last 12 months, 1 public question or issue reached it.'
                : 'In the last 12 months, ${record.received} public questions and issues reached it.',
            style: AuraText.small.copyWith(color: AuraSurface.muted),
          ),
          const SizedBox(height: AuraSpace.s12),
          Row(
            children: [
              stat('Waiting', record.waiting, AuraSurface.coSun),
              stat('Answered', record.answered, AuraSurface.ink),
              stat('Committed', record.committed, AuraSurface.accent),
              stat('Resolved', record.resolved, AuraSurface.coVerdant),
            ],
          ),
          if (record.recentResolutions.isNotEmpty) ...[
            const SizedBox(height: AuraSpace.s14),
            Text('Recently resolved', style: AuraText.small.copyWith(fontWeight: FontWeight.w700)),
            for (final r in record.recentResolutions)
              InkWell(
                onTap: r.postId.isEmpty ? null : () => context.push(NavigationAuthority.postRoute(r.postId)),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: AuraSpace.s8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(r.issue, maxLines: 2, overflow: TextOverflow.ellipsis, style: AuraText.body.copyWith(height: 1.4)),
                      const SizedBox(height: 2),
                      Text(
                        r.statement,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: AuraText.small.copyWith(color: AuraSurface.coVerdant, height: 1.4),
                      ),
                      if (r.at != null)
                        Text(AuraTemporal.fullShort(r.at!), style: AuraText.micro.copyWith(color: AuraSurface.faint)),
                    ],
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}
