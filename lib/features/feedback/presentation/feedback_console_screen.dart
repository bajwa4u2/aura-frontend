import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_error_mapper.dart';
import '../../../core/net/dio_provider.dart';
import '../../../core/product/product_language.dart';
import '../../../core/product/product_state.dart';
import '../../../core/product/product_state_view.dart';
import '../../../core/ui/aura_bounded_editor.dart';
import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';

/// THE OPERATOR'S SIDE OF THE LOOP.
///
/// A feedback form whose submissions land in a table nobody opens is worse
/// than no form: it teaches people that telling us things is pointless while
/// letting us believe we are listening. So this is the smallest surface that
/// lets someone actually work the queue — read it, say what was done, and say
/// where it shipped.
///
/// Deliberately not a dashboard. No charts, no sentiment, no volume trends.
/// The unit of work is one person's message.
class FeedbackConsoleScreen extends ConsumerStatefulWidget {
  const FeedbackConsoleScreen({super.key});

  @override
  ConsumerState<FeedbackConsoleScreen> createState() =>
      _FeedbackConsoleScreenState();
}

final _queueProvider =
    FutureProvider.autoDispose.family<List<dynamic>, String>((ref, state) async {
  final res = await ref.watch(dioProvider).get(
        '/admin/feedback',
        queryParameters: state.isEmpty ? null : {'state': state},
      );
  final data = res.data;
  final body = data is Map<String, dynamic> ? (data['data'] ?? data) : data;
  return body is List ? body : const [];
});

class _FeedbackConsoleScreenState extends ConsumerState<FeedbackConsoleScreen> {
  // Open work first. An operator arriving at this screen is here to work the
  // queue, not to browse what has already been dealt with.
  String _state = 'RECEIVED';

  static const _states = <String, String>{
    'RECEIVED': 'New',
    'REVIEWED': 'Read',
    'ACTIONED': 'Acted on',
    'CLOSED': 'Closed',
    '': 'All',
  };

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(_queueProvider(_state));

    return AuraScaffold(
      title: 'Product feedback',
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AuraSpace.s12),
            child: Wrap(
              spacing: AuraSpace.s8,
              children: [
                for (final entry in _states.entries)
                  ChoiceChip(
                    label: Text(entry.value),
                    selected: _state == entry.key,
                    onSelected: (_) => setState(() => _state = entry.key),
                  ),
              ],
            ),
          ),
          Expanded(
            child: async.when(
              loading: () => const AuraProductState(
                state: ProductState.loading,
                subject: ProductNoun.feedback,
              ),
              error: (e, _) => AuraProductState(
                state: ProductState.error,
                subject: ProductNoun.feedback,
                detail:
                    AppErrorMapper.from(e, feature: 'load the feedback queue')
                        .message,
                onRecover: () => ref.invalidate(_queueProvider(_state)),
              ),
              data: (items) => items.isEmpty
                  ? const AuraProductState(
                      state: ProductState.empty,
                      subject: ProductNoun.feedback,
                      headline: 'Nothing in this state',
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(AuraSpace.s16),
                      itemCount: items.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: AuraSpace.s10),
                      itemBuilder: (_, i) => _QueueRow(
                        row: items[i] as Map<String, dynamic>,
                        onChanged: () => ref.invalidate(_queueProvider(_state)),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QueueRow extends ConsumerWidget {
  const _QueueRow({required this.row, required this.onChanged});

  final Map<String, dynamic> row;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final from = row['from'] as Map<String, dynamic>?;
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
              Text('${row['intent']}',
                  style: AuraText.small.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(width: AuraSpace.s8),
              Text('${row['state']}',
                  style: AuraText.micro.copyWith(color: AuraSurface.muted)),
              const Spacer(),
              SelectableText('${row['ref']}',
                  style: AuraText.micro.copyWith(color: AuraSurface.muted)),
            ],
          ),
          const SizedBox(height: AuraSpace.s6),
          // Build and platform, because that is what makes a report actionable
          // and it is the whole reason the context is collected at all.
          Text(
            [
              row['product'],
              row['platform'],
              if ((row['appVersion'] ?? '').toString().isNotEmpty)
                row['appVersion'],
              if (from != null) '@${from['handle'] ?? from['id']}',
            ].join(' · '),
            style: AuraText.micro.copyWith(color: AuraSurface.muted),
          ),
          const SizedBox(height: AuraSpace.s8),
          Text('${row['excerpt'] ?? ''}', style: AuraText.body),
          const SizedBox(height: AuraSpace.s10),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => _openTriage(context, ref, row, onChanged),
              child: const Text('Triage'),
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> _openTriage(
  BuildContext context,
  WidgetRef ref,
  Map<String, dynamic> row,
  VoidCallback onChanged,
) async {
  final outcome = TextEditingController();
  final note = TextEditingController();
  final release = TextEditingController();
  String state = 'REVIEWED';

  final sent = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialogState) => AlertDialog(
        backgroundColor: AuraSurface.card,
        title: Text('Triage ${row['ref']}'),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: state,
                  decoration: const InputDecoration(labelText: 'Move to'),
                  items: const [
                    DropdownMenuItem(value: 'REVIEWED', child: Text('Read')),
                    DropdownMenuItem(value: 'ACTIONED', child: Text('Acted on')),
                    DropdownMenuItem(value: 'CLOSED', child: Text('Closed')),
                  ],
                  onChanged: (v) => setDialogState(() => state = v ?? state),
                ),
                const SizedBox(height: AuraSpace.s12),
                // Shown to the person. This is the only operator-written field
                // they ever see, and ACTIONED is refused without it.
                AuraBoundedEditor(
                  builder: (context, scrollController, physics) => TextField(
                    scrollController: scrollController,
                    scrollPhysics: physics,
                    controller: outcome,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'What was done (the person sees this)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(height: AuraSpace.s12),
                TextField(
                  controller: release,
                  decoration: const InputDecoration(
                    labelText: 'Where it shipped — version, build or commit',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: AuraSpace.s12),
                AuraBoundedEditor(
                  builder: (context, scrollController, physics) => TextField(
                    scrollController: scrollController,
                    scrollPhysics: physics,
                    controller: note,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Internal note (never shown)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Save'),
          ),
        ],
      ),
    ),
  );

  if (sent != true) return;
  try {
    await ref.read(dioProvider).post(
      '/admin/feedback/${row['id']}/triage',
      data: {
        'state': state,
        if (outcome.text.trim().isNotEmpty) 'outcome': outcome.text.trim(),
        if (note.text.trim().isNotEmpty) 'operatorNote': note.text.trim(),
        if (release.text.trim().isNotEmpty) 'releaseRef': release.text.trim(),
      },
    );
    onChanged();
  } catch (e) {
    if (!context.mounted) return;
    // The server refuses for real reasons — ACTIONED without an outcome is
    // one of them — so the refusal is surfaced as written.
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppErrorMapper.from(e, feature: 'save that').message),
      ),
    );
  }
}
