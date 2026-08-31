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
import 'package:go_router/go_router.dart';

import '../../../core/ui/aura_radius.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../data/admin_providers.dart';
import '../domain/operator_authority_provider.dart';
import '../domain/operator_capability.dart';
import '../domain/operator_routes.dart';
import '../ui/operator_kit.dart';
import 'now_area.dart' show readableAction;

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
                              e.actorLabel.toLowerCase().contains(filter) ||
                              e.reason.toLowerCase().contains(filter) ||
                              e.targetType.toLowerCase().contains(filter) ||
                              // Searchable BY NAME. An operator looking for
                              // what was done to a person types the person's
                              // name, not their cuid.
                              e.subject.display
                                  .toLowerCase()
                                  .contains(filter) ||
                              (e.subject.handle ?? '')
                                  .toLowerCase()
                                  .contains(filter) ||
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
                    // +1 for the column header at wide widths. WHO DID IT and
                    // TO WHOM are both people's names, side by side, and with
                    // nothing naming the columns an operator cannot tell the
                    // two apart at a glance — which is the one distinction the
                    // record exists to make.
                    itemCount: entries.length + (wide ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (wide && index == 0) return const _RecordColumns();
                      final i = wide ? index - 1 : index;
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
    // Named, not addressed. `actorLabel` prefers the person's own name and
    // falls back through handle and email, so a record whose actor relation
    // came back without an email still says who acted.
    final actor = entry.actorLabel;

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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
        wide
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
                      readableAction(entry.action),
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
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: _Subject(entry: entry, alignEnd: true),
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
                          readableAction(entry.action),
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
                  _Subject(entry: entry, alignEnd: false),
                ],
              ),
            // WHY. The fourth question the record exists to answer, and the
            // one an operator reading someone else's decision came for. It
            // gets its own line at every width rather than being squeezed
            // into a column that would truncate it to nothing.
            if (entry.reason.isNotEmpty) ...[
              const SizedBox(height: AuraSpace.s8),
              Text(
                readableReason(entry.reason),
                style: const TextStyle(
                  color: AuraSurface.muted,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ],
            if (entry.failed) ...[
              const SizedBox(height: AuraSpace.s8),
              const OperatorStatePill(
                state: 'FAILED',
                tone: OperatorTone.danger,
                dense: true,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// TO WHOM — named where the record can name it.
///
/// A resolved person or institution is shown by name and opens as a subject,
/// because "what was done to this person" and "who is this person" are the
/// same investigation. An unresolvable target stays a plain reference and is
/// deliberately NOT a link: offering to open something that has no page, or
/// no longer exists, is a worse answer than showing the id.
class _Subject extends StatelessWidget {
  const _Subject({required this.entry, required this.alignEnd});

  final AdminAuditLogEntry entry;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    final subject = entry.subject;
    final qualifier = subject.qualifier;

    final label = Column(
      crossAxisAlignment:
          alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          subject.display,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: alignEnd ? TextAlign.right : TextAlign.left,
          style: TextStyle(
            // A NAMED SUBJECT READS AS A SUBJECT. An unresolved reference
            // stays quiet, so the eye is not drawn to a cuid.
            color: subject.navigable ? AuraSurface.muted : AuraSurface.faint,
            fontSize: 12,
            fontWeight: subject.navigable ? FontWeight.w500 : FontWeight.w400,
          ),
        ),
        if (qualifier != null)
          Text(
            qualifier,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: AuraSurface.faint, fontSize: 11),
          ),
      ],
    );

    if (!subject.navigable) return label;

    final route = subject.isPerson
        ? operatorPersonRoute(subject.id!)
        : operatorInstitutionRoute(subject.id!);

    return InkWell(
      onTap: () => context.go(route),
      borderRadius: BorderRadius.circular(AuraRadius.pill),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: label,
      ),
    );
  }
}

/// The column header. Wide widths only — the narrow layout already labels
/// each value by stacking it under the action.
class _RecordColumns extends StatelessWidget {
  const _RecordColumns();

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(
      color: AuraSurface.faint,
      fontSize: 10.5,
      letterSpacing: 0.8,
      fontWeight: FontWeight.w700,
    );

    return const Padding(
      padding: EdgeInsets.fromLTRB(
        AuraSpace.s14,
        0,
        AuraSpace.s14,
        AuraSpace.s12,
      ),
      child: Row(
        children: [
          SizedBox(width: 52, child: Text('WHEN', style: style)),
          Expanded(flex: 3, child: Text('WHAT HAPPENED', style: style)),
          Expanded(flex: 2, child: Text('WHO DID IT', style: style)),
          Expanded(
            flex: 2,
            child: Text('TO WHOM', style: style, textAlign: TextAlign.right),
          ),
        ],
      ),
    );
  }
}

/// WHY, in the words of whoever is answering.
///
/// Two different things arrive in this field. When an operator acts, they type
/// a sentence and it is carried verbatim — that is the whole reason a reason
/// is required. When AURA ITSELF records a refusal, it writes a machine code:
/// `missing_permission`, `expired_grant`. The record was printing those raw,
/// so the one line meant to explain a decision read as a log key.
///
/// A code is recognisable: it is one token, lowercase, with underscores and no
/// sentence punctuation. Anything else is a person's writing and is never
/// touched — rewriting what an operator actually said would be a far worse
/// failure than showing a code.
String readableReason(String reason) {
  final raw = reason.trim();
  if (raw.isEmpty) return raw;

  const known = <String, String>{
    'missing_permission': 'The permission this action requires was not held.',
    'insufficient_permission':
        'The permission this action requires was not held.',
    'expired_grant': 'The operator grant had expired.',
    'revoked_grant': 'The operator grant had been revoked.',
    'not_owner': 'Only an owner may make this change.',
    'rate_limited': 'Refused because the same action was repeating too fast.',
    'unauthenticated': 'Nobody was signed in for this request.',
    'timed_out': 'The authority did not answer in time.',
    'unreachable': 'The authority could not be reached.',
    'read_failed': 'The read failed.',
  };

  final match = known[raw.toLowerCase()];
  if (match != null) return match;

  // An unrecognised code still reads better as words than as a key, but it is
  // only reshaped when it IS a code — never when it is prose.
  final looksLikeCode = !raw.contains(' ') &&
      raw.contains('_') &&
      raw == raw.toLowerCase();
  if (!looksLikeCode) return raw;

  final words = raw.replaceAll('_', ' ');
  return words[0].toUpperCase() + words.substring(1);
}
