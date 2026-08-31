/// RECORD — the governed account of what operators did.
///
/// Audit answers WHO did WHAT, UNDER WHAT AUTHORITY, WHY, and WHAT CHANGED. A
/// list that answers only the first two is a log, and reading a log is not the
/// same as understanding a decision.
///
/// This is the estate-wide index. The contextual half lives on the subject —
/// a person's own history sits on that person — because an operator
/// investigating someone should not have to search the whole estate to find
/// out what happened to them.
///
/// The record is READ-ONLY here and nowhere is it editable. History that can
/// be revised is not history.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ui/aura_radius.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../data/admin_providers.dart';
import '../domain/operator_authority_provider.dart';
import '../domain/operator_capability.dart';
import '../ui/operator_kit.dart';

/// Free-text filter over the record.
final recordFilterProvider = StateProvider<String>((_) => '');

class RecordArea extends ConsumerWidget {
  const RecordArea({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authority = ref.watch(operatorAuthorityProvider).valueOrNull ??
        const OperatorAuthority.none();

    if (!authority.can(OperatorCapability.auditRead)) {
      return const Padding(
        padding: EdgeInsets.all(AuraSpace.s20),
        child: OperatorInsufficientCapability(needs: 'audit'),
      );
    }

    final logs = ref.watch(adminAuditLogsProvider);
    final filter = ref.watch(recordFilterProvider).toLowerCase();

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 900;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                wide ? AuraSpace.s20 : AuraSpace.s12,
                wide ? AuraSpace.s20 : AuraSpace.s12,
                wide ? AuraSpace.s20 : AuraSpace.s12,
                AuraSpace.s12,
              ),
              child: _RecordFilter(),
            ),
            Expanded(
              child: logs.when(
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(horizontal: AuraSpace.s16),
                  child: OperatorLoading(lines: 6),
                ),
                error: (e, _) => Padding(
                  padding: const EdgeInsets.all(AuraSpace.s16),
                  child: OperatorFailure(
                    title: 'The record could not be read',
                    detail: 'Nothing is missing from the record — this is a '
                        'read failure.',
                    onRetry: () => ref.invalidate(adminAuditLogsProvider),
                  ),
                ),
                data: (all) {
                  final entries = filter.isEmpty
                      ? all
                      : all
                          .where((e) =>
                              e.action.toLowerCase().contains(filter) ||
                              e.actorEmail.toLowerCase().contains(filter) ||
                              e.targetType.toLowerCase().contains(filter) ||
                              (e.targetId ?? '')
                                  .toLowerCase()
                                  .contains(filter))
                          .toList();

                  if (entries.isEmpty) {
                    return OperatorClear(
                      title: filter.isEmpty
                          ? 'No operator actions recorded'
                          : 'Nothing in the record matches "$filter"',
                      icon: Icons.history_rounded,
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(
                        AuraSpace.s16, 0, AuraSpace.s16, AuraSpace.s24),
                    itemCount: entries.length,
                    itemBuilder: (context, i) {
                      final entry = entries[i];
                      final previous = i == 0 ? null : entries[i - 1];
                      final newDay = previous == null ||
                          !_sameDay(previous.createdAt, entry.createdAt);
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (newDay)
                            Padding(
                              padding: EdgeInsets.only(
                                top: i == 0 ? 0 : AuraSpace.s16,
                                bottom: AuraSpace.s8,
                              ),
                              child: Text(
                                _dayLabel(entry.createdAt),
                                style: const TextStyle(
                                  color: AuraSurface.faint,
                                  fontSize: 11,
                                  letterSpacing: 0.8,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          _RecordRow(entry: entry, wide: wide),
                        ],
                      );
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static String _dayLabel(DateTime when) {
    final now = DateTime.now();
    if (_sameDay(now, when)) return 'TODAY';
    if (_sameDay(now.subtract(const Duration(days: 1)), when)) {
      return 'YESTERDAY';
    }
    return '${when.year}-${when.month.toString().padLeft(2, '0')}-'
        '${when.day.toString().padLeft(2, '0')}';
  }
}

class _RecordFilter extends ConsumerStatefulWidget {
  @override
  ConsumerState<_RecordFilter> createState() => _RecordFilterState();
}

class _RecordFilterState extends ConsumerState<_RecordFilter> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      style: const TextStyle(color: AuraSurface.ink, fontSize: 13.5),
      onChanged: (v) =>
          ref.read(recordFilterProvider.notifier).state = v.trim(),
      decoration: InputDecoration(
        isDense: true,
        hintText: 'Filter by action, operator or subject',
        hintStyle: const TextStyle(color: AuraSurface.faint, fontSize: 13.5),
        prefixIcon: const Icon(Icons.search_rounded,
            size: 18, color: AuraSurface.faint),
        filled: true,
        fillColor: AuraSurface.card,
        contentPadding: const EdgeInsets.symmetric(vertical: AuraSpace.s12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AuraRadius.pill),
          borderSide: const BorderSide(color: AuraSurface.divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AuraRadius.pill),
          borderSide: const BorderSide(color: AuraSurface.divider),
        ),
      ),
    );
  }
}

class _RecordRow extends StatelessWidget {
  const _RecordRow({required this.entry, required this.wide});

  final AdminAuditLogEntry entry;
  final bool wide;

  String get _time =>
      '${entry.createdAt.hour.toString().padLeft(2, '0')}:'
      '${entry.createdAt.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    // The action, the actor, and the subject — in that order, because
    // "what happened" is what an operator scans for and "who did it" is what
    // they check next.
    final actor = entry.actorEmail.isEmpty ? entry.actorId : entry.actorEmail;
    final subject = entry.targetId == null || entry.targetId!.isEmpty
        ? entry.targetType
        : '${entry.targetType} · ${entry.targetId}';

    return Padding(
      padding: const EdgeInsets.only(bottom: AuraSpace.s8),
      child: Container(
        decoration: BoxDecoration(
          color: AuraSurface.card,
          borderRadius: BorderRadius.circular(AuraRadius.card),
          border: Border.all(color: AuraSurface.divider),
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AuraSpace.s14,
          vertical: AuraSpace.s12,
        ),
        child: wide
            ? Row(
                children: [
                  SizedBox(
                    width: 52,
                    child: Text(
                      _time,
                      style: const TextStyle(
                        color: AuraSurface.faint,
                        fontSize: 12,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text(
                      entry.action.replaceAll('.', ' · '),
                      style: const TextStyle(
                        color: AuraSurface.ink,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      actor,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: AuraSurface.muted, fontSize: 12.5),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      subject,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                          color: AuraSurface.faint, fontSize: 12),
                    ),
                  ),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          entry.action.replaceAll('.', ' · '),
                          style: const TextStyle(
                            color: AuraSurface.ink,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Text(
                        _time,
                        style: const TextStyle(
                          color: AuraSurface.faint,
                          fontSize: 11.5,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    actor,
                    style: const TextStyle(
                        color: AuraSurface.muted, fontSize: 12),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    subject,
                    style: const TextStyle(
                        color: AuraSurface.faint, fontSize: 11.5),
                  ),
                ],
              ),
      ),
    );
  }
}
