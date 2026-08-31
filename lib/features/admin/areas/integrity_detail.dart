/// THE FOUR INTEGRITY DESTINATIONS.
///
/// A worklist that cannot be worked is a list. Every row the unified worklist
/// produces names a destination, and these are four of the seven: a moderation
/// report, a media appeal, a piece of product feedback, a support case.
///
/// Each hands the item back to the authority that owns it and shows the
/// consequence before the operator commits. None of them decides anything.
///
/// WHAT IS SHARED IS THE SHAPE, NOT THE SUBJECT. They look alike because an
/// operator should not have to learn four interfaces; they stay four
/// authorities because they are four.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ui/aura_radius.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../../support/providers.dart';
import '../data/admin_providers.dart';
import '../data/admin_repository.dart';
import '../data/operator_integrity.dart';
import '../data/operator_work.dart';
import '../domain/operator_authority_provider.dart';
import '../domain/operator_capability.dart';
import '../ui/operator_action.dart';
import '../ui/operator_kit.dart';

/// The frame every detail destination shares: capability first, then the
/// subject, then what may be done about it.
class _DetailFrame extends StatelessWidget {
  const _DetailFrame({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 980;
        return ListView(
          padding: EdgeInsets.all(wide ? AuraSpace.s20 : AuraSpace.s12),
          children: [
            // Bounded rather than full-bleed on a wide screen: a report read
            // across 1600px is a report nobody finishes.
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: children,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Untrusted text somebody wrote. Never markup, never a link, never
/// interpolated into anything — quoted, so an operator can see where the
/// person's words start and the console's stop.
class _Quoted extends StatelessWidget {
  const _Quoted(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      // FULL WIDTH, deliberately. Sized to its text the block read as a chip
      // and the rule down its left edge disappeared, which is the whole thing
      // that marks these words as somebody else's rather than the console's.
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        AuraSpace.s12,
        AuraSpace.s10,
        AuraSpace.s12,
        AuraSpace.s10,
      ),
      decoration: const BoxDecoration(
        color: AuraSurface.page,
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(AuraRadius.md),
          bottomRight: Radius.circular(AuraRadius.md),
        ),
        border: Border(
          left: BorderSide(color: AuraSurface.accent, width: 3),
        ),
      ),
      child: SelectableText(
        text.isEmpty ? 'They wrote nothing.' : text,
        style: TextStyle(
          color: text.isEmpty ? AuraSurface.faint : AuraSurface.ink,
          fontSize: 13.5,
          height: 1.5,
        ),
      ),
    );
  }
}

/// A labelled fact in a detail header.
class _Meta extends StatelessWidget {
  const _Meta({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AuraSpace.s8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(color: AuraSurface.faint, fontSize: 12),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? '—' : value,
              style: const TextStyle(color: AuraSurface.ink, fontSize: 12.5),
            ),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// MODERATION — one report
// ═════════════════════════════════════════════════════════════════════════════

class ModerationReportDetail extends ConsumerWidget {
  const ModerationReportDetail({super.key, required this.reportId});

  final String reportId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authority = ref.watch(operatorAuthorityProvider).valueOrNull ??
        const OperatorAuthority.none();

    if (!authority.can(OperatorCapability.moderationRead)) {
      return const Padding(
        padding: EdgeInsets.all(AuraSpace.s20),
        child: OperatorInsufficientCapability(needs: 'moderation'),
      );
    }

    final report = ref.watch(moderationReportProvider(reportId));

    return report.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(AuraSpace.s20),
        child: OperatorLoading(lines: 4),
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.all(AuraSpace.s20),
        child: OperatorFailure(
          title: 'This report could not be read',
          detail: '$e',
          onRetry: () => ref.invalidate(moderationReportProvider(reportId)),
        ),
      ),
      data: (r) {
        final canWrite = authority.can(OperatorCapability.moderationWrite);
        final open = r.status.toUpperCase() != 'RESOLVED' &&
            r.status.toUpperCase() != 'DISMISSED';

        return _DetailFrame(
          children: [
            OperatorSection(
              title: 'Reported ${r.targetType.toLowerCase()}',
              subtitle: r.reason,
              trailing: OperatorStatePill(
                state: r.status,
                tone: open ? OperatorTone.pending : OperatorTone.neutral,
              ),
              child: OperatorPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Meta(
                      label: 'Reported by',
                      value: r.reporter.displayName.isEmpty
                          ? (r.reporter.handle.isEmpty
                              ? 'Somebody who has since left'
                              : '@${r.reporter.handle}')
                          : r.reporter.displayName,
                    ),
                    _Meta(label: 'Target', value: r.targetId),
                    if (r.details != null && r.details!.isNotEmpty) ...[
                      const SizedBox(height: AuraSpace.s8),
                      const Text(
                        'WHAT THEY SAID',
                        style: TextStyle(
                          color: AuraSurface.faint,
                          fontSize: 11,
                          letterSpacing: 0.8,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: AuraSpace.s8),
                      _Quoted(r.details!),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: AuraSpace.s20),
            if (r.actions.isNotEmpty) ...[
              OperatorSection(
                title: 'What has been done',
                child: OperatorPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final action in r.actions)
                        Padding(
                          padding: const EdgeInsets.only(bottom: AuraSpace.s10),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              OperatorStatePill(
                                state: action.actionType,
                                dense: true,
                              ),
                              const SizedBox(width: AuraSpace.s8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      action.moderator.displayName.isEmpty
                                          ? 'An operator'
                                          : action.moderator.displayName,
                                      style: const TextStyle(
                                        color: AuraSurface.ink,
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    if (action.note != null &&
                                        action.note!.isNotEmpty)
                                      Text(
                                        action.note!,
                                        style: const TextStyle(
                                          color: AuraSurface.muted,
                                          fontSize: 12,
                                          height: 1.35,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AuraSpace.s20),
            ],
            if (r.outcomeSummary != null && r.outcomeSummary!.isNotEmpty) ...[
              OperatorSection(
                title: 'Outcome',
                subtitle: 'What the reporter is told',
                child: OperatorPanel(child: _Quoted(r.outcomeSummary!)),
              ),
              const SizedBox(height: AuraSpace.s20),
            ],
            if (!canWrite)
              const OperatorPanel(
                child: Text(
                  'You may read this report, but not decide it.',
                  style: TextStyle(color: AuraSurface.faint, fontSize: 12.5),
                ),
              )
            else if (!open)
              const OperatorPanel(
                child: Text(
                  'This report is closed. Reopening it is not something this '
                  'console does.',
                  style: TextStyle(color: AuraSurface.faint, fontSize: 12.5),
                ),
              )
            else
              OperatorSection(
                title: 'What to do',
                subtitle: 'The actions this kind of target accepts',
                child: OperatorPanel(
                  child: Wrap(
                    spacing: AuraSpace.s8,
                    runSpacing: AuraSpace.s8,
                    children: [
                      for (final action in _actionsFor(r.targetType))
                        OutlinedButton(
                          onPressed: () => _act(context, ref, r, action),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _isSevere(action)
                                ? AuraSurface.dangerInk
                                : AuraSurface.ink,
                            side: const BorderSide(color: AuraSurface.divider),
                          ),
                          child: Text(_actionLabel(action)),
                        ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  /// WHAT MAY BE DONE, BY WHAT WAS REPORTED.
  ///
  /// `ModerationActionType` has no generic "remove": the removal action for a
  /// post is SOFT_DELETE_POST and for a message SOFT_DELETE_MESSAGE. A single
  /// button meaning "act" would have to invent a value the enum does not
  /// carry, and the authority would refuse it. This is the mapping the
  /// retired moderation screen already held, carried forward rather than
  /// re-derived.
  static const _actionsByTarget = <String, List<String>>{
    'POST': ['NOTE', 'WARN', 'REQUEST_REVISION', 'SOFT_DELETE_POST'],
    'USER': ['NOTE', 'WARN', 'REQUEST_CLARIFICATION', 'DISABLE_USER'],
    'MESSAGE': ['NOTE', 'WARN', 'SOFT_DELETE_MESSAGE'],
    'SPACE': ['NOTE', 'WARN', 'ARCHIVE_SPACE'],
    'THREAD': ['NOTE', 'WARN', 'ARCHIVE_THREAD'],
    'INSTITUTION': ['NOTE', 'WARN', 'SUSPEND_INSTITUTION'],
  };

  /// The RESTORE_* half of the enum is deliberately absent. Restoring is not a
  /// decision about an open report — it undoes an earlier one, and offering it
  /// here would let an operator "resolve" a report by reversing something
  /// unrelated to it.
  static List<String> _actionsFor(String targetType) =>
      _actionsByTarget[targetType.toUpperCase()] ?? const ['NOTE', 'WARN'];

  static bool _isSevere(String action) =>
      action.startsWith('SOFT_DELETE') ||
      action.startsWith('ARCHIVE') ||
      action == 'DISABLE_USER' ||
      action == 'SUSPEND_INSTITUTION';

  static String _actionLabel(String action) => switch (action) {
        'NOTE' => 'Note it and dismiss',
        'WARN' => 'Warn them',
        'REQUEST_REVISION' => 'Ask for a revision',
        'REQUEST_CLARIFICATION' => 'Ask for clarification',
        'SOFT_DELETE_POST' => 'Take the post down',
        'SOFT_DELETE_MESSAGE' => 'Take the message down',
        'ARCHIVE_SPACE' => 'Archive the space',
        'ARCHIVE_THREAD' => 'Archive the thread',
        'DISABLE_USER' => 'Disable the account',
        'SUSPEND_INSTITUTION' => 'Suspend the institution',
        _ => action,
      };

  /// NOTE closes a report without acting on anybody, so it resolves as
  /// DISMISSED. Everything else acted on the target, which is RESOLVED.
  static String _resultingStatus(String action) =>
      action == 'NOTE' ? 'DISMISSED' : 'RESOLVED';

  Future<void> _act(
    BuildContext context,
    WidgetRef ref,
    ModerationReport report,
    String action,
  ) async {
    final severe = _isSevere(action);
    final done = await runOperatorAction(
      context,
      OperatorAction(
        title: _actionLabel(action),
        subject: '${report.targetType} · ${report.targetId}',
        detail: 'The moderation authority applies this and records it against '
            'the target. What you write is what the reporter is shown; it is '
            'not your private reasoning.',
        confirmLabel: 'Apply',
        destructive: severe,
        requiresReason: true,
        reasonLabel: 'What the reporter is told',
        consequences: [
          if (severe)
            OperatorConsequence(
              text: '${_actionLabel(action)} — this changes what other people '
                  'can see.',
              tone: OperatorTone.danger,
              icon: Icons.gavel_rounded,
            )
          else if (action == 'NOTE')
            const OperatorConsequence(
              text: 'Nothing happens to the reported target.',
              icon: Icons.done_all_rounded,
            )
          else
            OperatorConsequence(
              text: _actionLabel(action),
              tone: OperatorTone.warn,
              icon: Icons.flag_rounded,
            ),
          if (action != 'NOTE')
            OperatorConsequence.notifies('The person who was reported'),
          OperatorConsequence(
            text: 'The report closes as '
                '${_resultingStatus(action).toLowerCase()}.',
            icon: Icons.inbox_rounded,
          ),
          OperatorConsequence.recorded('This action and its outcome'),
        ],
        perform: (reason) async {
          await ref.read(adminRepositoryProvider).submitModerationAction(
                actionType: action,
                targetType: report.targetType,
                targetId: report.targetId,
                reportId: report.id,
                reportStatus: _resultingStatus(action),
                outcomeSummary: reason,
              );
          return 'Applied, and the outcome recorded.';
        },
      ),
    );
    if (done) {
      ref.invalidate(moderationReportProvider(reportId));
      ref.invalidate(operatorWorkSummaryProvider);
      ref.invalidate(operatorWorkListProvider);
    }
  }
}


// ═════════════════════════════════════════════════════════════════════════════
// MEDIA APPEALS — one appeal against a quarantine
// ═════════════════════════════════════════════════════════════════════════════

class MediaAppealDetail extends ConsumerWidget {
  const MediaAppealDetail({super.key, required this.appealId});

  final String appealId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authority = ref.watch(operatorAuthorityProvider).valueOrNull ??
        const OperatorAuthority.none();

    if (!authority.can(OperatorCapability.moderationRead)) {
      return const Padding(
        padding: EdgeInsets.all(AuraSpace.s20),
        child: OperatorInsufficientCapability(needs: 'moderation'),
      );
    }

    final appeal = ref.watch(mediaAppealProvider(appealId));

    return appeal.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(AuraSpace.s20),
        child: OperatorLoading(lines: 4),
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.all(AuraSpace.s20),
        child: OperatorFailure(
          title: 'This appeal could not be read',
          detail: '$e',
          onRetry: () => ref.invalidate(mediaAppealProvider(appealId)),
        ),
      ),
      data: (a) {
        if (a == null) {
          // Not an error. An appeal leaves the queue once it is decided, and
          // saying "already decided" is more useful than "not found".
          return const Padding(
            padding: EdgeInsets.all(AuraSpace.s20),
            child: OperatorClear(
              title: 'This appeal is no longer open',
              detail: 'It has already been decided, so there is nothing here '
                  'to decide.',
              icon: Icons.done_all_rounded,
            ),
          );
        }

        final canWrite = authority.can(OperatorCapability.moderationWrite);
        return _DetailFrame(
          children: [
            OperatorSection(
              title: a.fileName ?? 'Quarantined file',
              subtitle: a.mimeType,
              trailing: OperatorStatePill(
                state: a.status,
                tone: OperatorTone.pending,
              ),
              child: OperatorPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Meta(label: 'Standing', value: a.standingBasis),
                    if (a.quarantineSource != null)
                      _Meta(label: 'Held by', value: a.quarantineSource!),
                    if (a.quarantineReason != null)
                      _Meta(label: 'Because', value: a.quarantineReason!),
                    const SizedBox(height: AuraSpace.s8),
                    const Text(
                      'WHAT THEY SAID',
                      style: TextStyle(
                        color: AuraSurface.faint,
                        fontSize: 11,
                        letterSpacing: 0.8,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AuraSpace.s8),
                    _Quoted(a.statement ?? ''),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AuraSpace.s20),
            // THE FILE IS NEVER SHOWN. A reviewer decides on the examiner's
            // finding and the appellant's statement; rendering quarantined
            // media into an operator's browser is the one thing a quarantine
            // exists to prevent.
            const OperatorPanel(
              child: Row(
                children: [
                  Icon(Icons.visibility_off_rounded,
                      size: 16, color: AuraSurface.faint),
                  SizedBox(width: AuraSpace.s10),
                  Expanded(
                    child: Text(
                      'The file itself is not shown. A quarantine exists to '
                      'keep it out of exactly this browser.',
                      style: TextStyle(
                        color: AuraSurface.muted,
                        fontSize: 12.5,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AuraSpace.s20),
            if (!canWrite)
              const OperatorPanel(
                child: Text(
                  'You may read this appeal, but not decide it.',
                  style: TextStyle(color: AuraSurface.faint, fontSize: 12.5),
                ),
              )
            else
              Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      onPressed: () => _decide(context, ref, a, release: true),
                      style: FilledButton.styleFrom(
                        backgroundColor: AuraSurface.accent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          vertical: AuraSpace.s14,
                        ),
                      ),
                      child: const Text('Release the file'),
                    ),
                  ),
                  const SizedBox(width: AuraSpace.s12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _decide(context, ref, a, release: false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AuraSurface.dangerInk,
                        side: const BorderSide(color: AuraSurface.divider),
                        padding: const EdgeInsets.symmetric(
                          vertical: AuraSpace.s14,
                        ),
                      ),
                      child: const Text('Keep it held'),
                    ),
                  ),
                ],
              ),
          ],
        );
      },
    );
  }

  Future<void> _decide(
    BuildContext context,
    WidgetRef ref,
    MediaAppealSummary appeal, {
    required bool release,
  }) async {
    final done = await runOperatorAction(
      context,
      OperatorAction(
        title: release ? 'Release the file' : 'Keep the file held',
        subject: appeal.fileName ?? appeal.mediaId,
        detail: release
            ? 'The quarantine is lifted and the file becomes usable on the '
                'terms of whatever it belongs to.'
            : 'The quarantine stands. The appellant is told the appeal was '
                'refused and why.',
        confirmLabel: release ? 'Release' : 'Keep held',
        destructive: !release,
        requiresReason: true,
        reasonLabel: release
            ? 'Why the examiner’s finding is overturned'
            : 'Why the appeal is refused',
        consequences: [
          if (release)
            OperatorConsequence.becomesPublic('The file')
          else
            const OperatorConsequence(
              text: 'The file stays out of reach.',
              tone: OperatorTone.danger,
              icon: Icons.lock_rounded,
            ),
          OperatorConsequence.notifies('The appellant'),
          OperatorConsequence.recorded('This decision and your reason'),
        ],
        perform: (reason) async {
          // REVERSED releases the object; UPHELD leaves it quarantined and
          // RETAINED. Upholding an appeal is never a deletion — quarantine IS
          // retention, and a decision does not change what quarantine is.
          await ref.read(adminRepositoryProvider).decideMediaAppeal(
                appeal.id,
                outcome: release ? 'REVERSED' : 'UPHELD',
                decisionSummary: reason ?? '',
              );
          return release
              ? 'Released. The appellant has been told.'
              : 'The quarantine stands. The appellant has been told.';
        },
      ),
    );
    if (done) {
      ref.invalidate(mediaAppealProvider(appealId));
      ref.invalidate(operatorWorkSummaryProvider);
      ref.invalidate(operatorWorkListProvider);
    }
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// PRODUCT FEEDBACK — one person's message
// ═════════════════════════════════════════════════════════════════════════════

class FeedbackDetail extends ConsumerWidget {
  const FeedbackDetail({super.key, required this.feedbackId});

  final String feedbackId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authority = ref.watch(operatorAuthorityProvider).valueOrNull ??
        const OperatorAuthority.none();

    if (!authority.can(OperatorCapability.productFeedbackRead)) {
      // NOT support. Support can email a person; feedback cannot, and the
      // separation carries recorded governance rationale.
      return const Padding(
        padding: EdgeInsets.all(AuraSpace.s20),
        child: OperatorInsufficientCapability(needs: 'product feedback'),
      );
    }

    final feedback = ref.watch(operatorFeedbackProvider(feedbackId));

    return feedback.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(AuraSpace.s20),
        child: OperatorLoading(lines: 4),
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.all(AuraSpace.s20),
        child: OperatorFailure(
          title: 'This feedback could not be read',
          detail: '$e',
          onRetry: () => ref.invalidate(operatorFeedbackProvider(feedbackId)),
        ),
      ),
      data: (f) {
        final canWrite = authority.can(OperatorCapability.productFeedbackWrite);
        return _DetailFrame(
          children: [
            OperatorSection(
              title: f.ref.isEmpty ? 'Feedback' : f.ref,
              subtitle: f.intent,
              trailing: OperatorStatePill(
                state: f.state,
                tone: f.isOpen ? OperatorTone.pending : OperatorTone.neutral,
              ),
              child: OperatorPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Quoted(f.message),
                    const SizedBox(height: AuraSpace.s16),
                    _Meta(
                      label: 'From',
                      value: f.authorLabel ??
                          'Somebody who has since left. The finding survives '
                              'them.',
                    ),
                    _Meta(
                      label: 'Where',
                      value: [
                        f.product,
                        f.platform,
                        if (f.appVersion != null) f.appVersion!,
                      ].where((e) => e.isNotEmpty).join(' · '),
                    ),
                    if (f.surface != null)
                      _Meta(label: 'On screen', value: f.surface!),
                    if (f.releaseChannel != null)
                      _Meta(label: 'Channel', value: f.releaseChannel!),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AuraSpace.s20),
            if (f.outcome != null || f.operatorNote != null) ...[
              OperatorSection(
                title: 'What came of it',
                child: OperatorPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (f.outcome != null) ...[
                        const Text(
                          'SHOWN TO THEM',
                          style: TextStyle(
                            color: AuraSurface.faint,
                            fontSize: 11,
                            letterSpacing: 0.8,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: AuraSpace.s8),
                        _Quoted(f.outcome!),
                        const SizedBox(height: AuraSpace.s12),
                      ],
                      if (f.operatorNote != null) ...[
                        const Text(
                          'INTERNAL — NEVER SHOWN',
                          style: TextStyle(
                            color: AuraSurface.faint,
                            fontSize: 11,
                            letterSpacing: 0.8,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: AuraSpace.s8),
                        _Quoted(f.operatorNote!),
                      ],
                      if (f.releaseRef != null) ...[
                        const SizedBox(height: AuraSpace.s12),
                        _Meta(label: 'Shipped in', value: f.releaseRef!),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AuraSpace.s20),
            ],
            if (!canWrite)
              const OperatorPanel(
                child: Text(
                  'You may read what people are saying, but not decide what '
                  'the product does about it.',
                  style: TextStyle(color: AuraSurface.faint, fontSize: 12.5),
                ),
              )
            else if (!f.isOpen)
              const OperatorPanel(
                child: Text(
                  'This is closed. Nothing further moves it.',
                  style: TextStyle(color: AuraSurface.faint, fontSize: 12.5),
                ),
              )
            else
              Wrap(
                spacing: AuraSpace.s8,
                runSpacing: AuraSpace.s8,
                children: [
                  for (final next in f.availableStates)
                    OutlinedButton(
                      onPressed: () => _triage(context, ref, f, next),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AuraSurface.ink,
                        side: const BorderSide(color: AuraSurface.divider),
                      ),
                      child: Text(_stateLabel(next)),
                    ),
                ],
              ),
          ],
        );
      },
    );
  }

  static String _stateLabel(String state) => switch (state.toUpperCase()) {
        'REVIEWED' => 'Mark as read',
        'ACTIONED' => 'Say what was done',
        'CLOSED' => 'Close it',
        _ => state,
      };

  Future<void> _triage(
    BuildContext context,
    WidgetRef ref,
    OperatorFeedback feedback,
    String next,
  ) async {
    // ACTIONED is the one state the authority refuses without an outcome:
    // "ACTIONED without an outcome is not an action." So the console asks for
    // one rather than letting the operator find out at the API.
    final actioned = next.toUpperCase() == 'ACTIONED';

    final done = await runOperatorAction(
      context,
      OperatorAction(
        title: _stateLabel(next),
        subject: feedback.ref.isEmpty ? feedback.id : feedback.ref,
        detail: actioned
            ? 'What you write here is what the person is shown. It is the '
                'difference between a suggestion box and a loop that closes.'
            : null,
        confirmLabel: actioned ? 'Record it' : 'Confirm',
        requiresReason: actioned,
        reasonLabel: 'What was done',
        consequences: [
          if (actioned)
            const OperatorConsequence(
              text: 'The person is shown what was done about their feedback.',
              tone: OperatorTone.good,
              icon: Icons.campaign_rounded,
            )
          else
            OperatorConsequence(
              text: 'The feedback moves to ${next.toLowerCase()}.',
              icon: Icons.arrow_forward_rounded,
            ),
          OperatorConsequence.recorded('This move'),
        ],
        perform: (reason) async {
          await ref.read(operatorFeedbackRepositoryProvider).triage(
                feedback.id,
                state: next,
                outcome: actioned ? reason : null,
              );
          return 'Recorded.';
        },
      ),
    );
    if (done) {
      ref.invalidate(operatorFeedbackProvider(feedbackId));
      ref.invalidate(operatorWorkSummaryProvider);
      ref.invalidate(operatorWorkListProvider);
    }
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// SUPPORT — one case
// ═════════════════════════════════════════════════════════════════════════════

class SupportCaseDetail extends ConsumerWidget {
  const SupportCaseDetail({super.key, required this.caseId});

  final String caseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authority = ref.watch(operatorAuthorityProvider).valueOrNull ??
        const OperatorAuthority.none();

    if (!authority.can(OperatorCapability.supportRead)) {
      return const Padding(
        padding: EdgeInsets.all(AuraSpace.s20),
        child: OperatorInsufficientCapability(needs: 'support'),
      );
    }

    final supportCase = ref.watch(operatorSupportCaseProvider(caseId));

    return supportCase.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(AuraSpace.s20),
        child: OperatorLoading(lines: 4),
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.all(AuraSpace.s20),
        child: OperatorFailure(
          title: 'This case could not be read',
          detail: '$e',
          onRetry: () => ref.invalidate(operatorSupportCaseProvider(caseId)),
        ),
      ),
      data: (c) {
        final canWrite = authority.can(OperatorCapability.supportWrite);
        return _DetailFrame(
          children: [
            OperatorSection(
              title: c.subject ?? (c.ref.isEmpty ? 'Support case' : c.ref),
              subtitle: [c.category, c.severity]
                  .where((e) => e.isNotEmpty)
                  .join(' · '),
              trailing: OperatorStatePill(state: c.status),
              child: OperatorPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Meta(label: 'From', value: c.requesterLabel),
                    if (c.assignedTo != null)
                      _Meta(label: 'Assigned to', value: c.assignedTo!)
                    else
                      const _Meta(label: 'Assigned to', value: 'Nobody'),
                    if (c.aiSummary != null) ...[
                      const SizedBox(height: AuraSpace.s8),
                      const Text(
                        'SUMMARISED, NOT DECIDED',
                        style: TextStyle(
                          color: AuraSurface.faint,
                          fontSize: 11,
                          letterSpacing: 0.8,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: AuraSpace.s8),
                      _Quoted(c.aiSummary!),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: AuraSpace.s20),
            OperatorSection(
              title: 'The conversation',
              subtitle: '${c.messages.length} '
                  'message${c.messages.length == 1 ? '' : 's'}',
              child: OperatorPanel(
                child: c.messages.isEmpty
                    ? const OperatorClear(
                        title: 'Nothing has been said yet',
                        icon: Icons.forum_outlined,
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final message in c.messages)
                            Padding(
                              padding: const EdgeInsets.only(
                                bottom: AuraSpace.s12,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    switch (message.voice) {
                                      SupportVoice.operator =>
                                        message.authorLabel ?? 'An operator',
                                      // Named, not disguised. An automated
                                      // reply read as a person's is the one
                                      // confusion a transcript must not allow.
                                      SupportVoice.assistant =>
                                        'Aura, automatically',
                                      SupportVoice.requester =>
                                        message.authorLabel ??
                                            c.requesterLabel,
                                    },
                                    style: TextStyle(
                                      color: switch (message.voice) {
                                        SupportVoice.operator =>
                                          AuraSurface.accent,
                                        SupportVoice.assistant =>
                                          AuraSurface.faint,
                                        SupportVoice.requester =>
                                          AuraSurface.muted,
                                      },
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  _Quoted(message.content),
                                ],
                              ),
                            ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: AuraSpace.s20),
            if (!canWrite)
              const OperatorPanel(
                child: Text(
                  'You may read this case, but not answer it.',
                  style: TextStyle(color: AuraSurface.faint, fontSize: 12.5),
                ),
              )
            else
              Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      onPressed: () => _reply(context, ref, c),
                      style: FilledButton.styleFrom(
                        backgroundColor: AuraSurface.accent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          vertical: AuraSpace.s14,
                        ),
                      ),
                      child: const Text('Reply'),
                    ),
                  ),
                  const SizedBox(width: AuraSpace.s12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _close(context, ref, c),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AuraSurface.ink,
                        side: const BorderSide(color: AuraSurface.divider),
                        padding: const EdgeInsets.symmetric(
                          vertical: AuraSpace.s14,
                        ),
                      ),
                      child: const Text('Close the case'),
                    ),
                  ),
                ],
              ),
          ],
        );
      },
    );
  }

  Future<void> _reply(
    BuildContext context,
    WidgetRef ref,
    OperatorSupportCase supportCase,
  ) async {
    final done = await runOperatorAction(
      context,
      OperatorAction(
        title: 'Reply',
        subject: supportCase.requesterLabel,
        detail: 'This reaches the person who asked. Support can do that; '
            'product feedback deliberately cannot.',
        confirmLabel: 'Send',
        requiresReason: true,
        reasonLabel: 'Your reply',
        consequences: [
          OperatorConsequence.notifies(supportCase.requesterLabel),
          const OperatorConsequence(
            text: 'It becomes part of the case record.',
            icon: Icons.history_edu_rounded,
          ),
        ],
        perform: (reply) async {
          await ref
              .read(supportRepositoryProvider)
              .adminReply(supportCase.id, reply ?? '');
          return 'Sent.';
        },
      ),
    );
    if (done) ref.invalidate(operatorSupportCaseProvider(caseId));
  }

  Future<void> _close(
    BuildContext context,
    WidgetRef ref,
    OperatorSupportCase supportCase,
  ) async {
    final done = await runOperatorAction(
      context,
      OperatorAction(
        title: 'Close the case',
        subject: supportCase.requesterLabel,
        detail: 'The case stops being open work. The person can still write '
            'again, which reopens the conversation rather than starting a '
            'second one.',
        confirmLabel: 'Close',
        requiresReason: true,
        reasonLabel: 'How it was resolved',
        consequences: [
          const OperatorConsequence(
            text: 'It leaves the open queue.',
            icon: Icons.inbox_rounded,
          ),
          OperatorConsequence.recorded('How it was resolved'),
        ],
        perform: (note) async {
          await ref.read(supportRepositoryProvider).adminChangeStatus(
                supportCase.id,
                'RESOLVED',
                note: note,
              );
          return 'Closed.';
        },
      ),
    );
    if (done) {
      ref.invalidate(operatorSupportCaseProvider(caseId));
      ref.invalidate(operatorWorkSummaryProvider);
      ref.invalidate(operatorWorkListProvider);
    }
  }
}
