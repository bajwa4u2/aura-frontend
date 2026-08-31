/// A PERSON, AS AN OPERATOR SUBJECT.
///
/// One place to see who someone is, what standing they hold, what has been
/// decided about them, and what may be done next — without pretending those
/// are one authority. Identity verification, account standing and admin
/// capability are three different decisions made by three different
/// authorities, and this shows them side by side without merging them.
///
/// Audit lives HERE, on the subject, not only in a global log. An operator
/// investigating a person should not have to go and search a chronological
/// list of the whole estate to find out what happened to them.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../data/admin_providers.dart';
import '../data/operator_work.dart';
import '../domain/operator_authority_provider.dart';
import '../domain/operator_capability.dart';
import '../ui/operator_action.dart';
import '../ui/operator_kit.dart';

final personVerificationProvider = FutureProvider.autoDispose
    .family<AdminPersonVerification, String>((ref, userId) async {
  return ref.watch(adminRepositoryProvider).fetchPersonVerification(userId);
});

class SubjectPersonArea extends ConsumerWidget {
  const SubjectPersonArea({super.key, required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authority = ref.watch(operatorAuthorityProvider).valueOrNull ??
        const OperatorAuthority.none();

    if (!authority.can(OperatorCapability.usersRead)) {
      return const Padding(
        padding: EdgeInsets.all(AuraSpace.s20),
        child: OperatorInsufficientCapability(needs: 'people'),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 980;
        final identity = _IdentityBlock(userId: userId, authority: authority);
        final work = _RelatedWork(userId: userId);
        final history = _PersonHistory(userId: userId, authority: authority);

        return ListView(
          padding: EdgeInsets.all(wide ? AuraSpace.s20 : AuraSpace.s12),
          children: [
            if (wide)
              // Desktop investigates with evidence and history side by side.
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 3, child: identity),
                  const SizedBox(width: AuraSpace.s20),
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        work,
                        const SizedBox(height: AuraSpace.s20),
                        history,
                      ],
                    ),
                  ),
                ],
              )
            else ...[
              // Mobile drills in: the subject first, then what is waiting on
              // it, then what has happened. Same capability, staged.
              identity,
              const SizedBox(height: AuraSpace.s20),
              work,
              const SizedBox(height: AuraSpace.s20),
              history,
            ],
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _IdentityBlock extends ConsumerWidget {
  const _IdentityBlock({required this.userId, required this.authority});

  final String userId;
  final OperatorAuthority authority;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canReadIdentity =
        authority.can(OperatorCapability.identityVerificationRead);

    if (!canReadIdentity) {
      // Deliberate: holding USERS_READ does not admit anyone to identity
      // evidence. The separation is a governance decision, not a UI detail.
      return const OperatorSection(
        title: 'Identity',
        child: OperatorInsufficientCapability(needs: 'identity verification'),
      );
    }

    final verification = ref.watch(personVerificationProvider(userId));

    return verification.when(
      loading: () => const OperatorSection(
        title: 'Identity',
        child: OperatorLoading(lines: 2),
      ),
      error: (e, _) => OperatorSection(
        title: 'Identity',
        child: OperatorFailure(
          title: 'Verification state could not be read',
          onRetry: () => ref.invalidate(personVerificationProvider(userId)),
        ),
      ),
      data: (v) {
        final canWrite =
            authority.can(OperatorCapability.identityVerificationWrite);
        return OperatorSection(
          title: 'Identity',
          subtitle: v.activeClasses.isEmpty
              ? 'No active verification'
              : '${v.activeClasses.length} active '
                  'class${v.activeClasses.length == 1 ? '' : 'es'}',
          child: OperatorPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (v.activeClasses.isEmpty)
                  const Text(
                    'This person holds no verified identity class.',
                    style:
                        TextStyle(color: AuraSurface.muted, fontSize: 13),
                  )
                else
                  Wrap(
                    spacing: AuraSpace.s8,
                    runSpacing: AuraSpace.s8,
                    children: [
                      for (final c in v.activeClasses)
                        OperatorStatePill(
                          state: c,
                          tone: OperatorTone.good,
                        ),
                    ],
                  ),
                if (canWrite) ...[
                  const SizedBox(height: AuraSpace.s16),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      icon: const Icon(Icons.gpp_bad_rounded, size: 16),
                      label: const Text('Revoke verification'),
                      style: TextButton.styleFrom(
                        foregroundColor: AuraSurface.dangerInk,
                      ),
                      onPressed: v.activeClasses.isEmpty
                          ? null
                          : () => _revoke(context, ref, v.activeClasses.first),
                    ),
                  ),
                ] else ...[
                  const SizedBox(height: AuraSpace.s12),
                  const Text(
                    'You may read this, but not decide it.',
                    style:
                        TextStyle(color: AuraSurface.faint, fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _revoke(
    BuildContext context,
    WidgetRef ref,
    String verificationClass,
  ) async {
    final done = await runOperatorAction(
      context,
      OperatorAction(
        title: 'Revoke verification',
        subject: '$verificationClass · person $userId',
        detail: 'The identity authority records this decision and applies it. '
            'Aura Admin invokes that authority; it does not decide here.',
        confirmLabel: 'Revoke',
        destructive: true,
        requiresReason: true,
        reasonLabel: 'Why this is being revoked',
        consequences: [
          const OperatorConsequence(
            text: 'The person loses this verified class immediately.',
            tone: OperatorTone.danger,
            icon: Icons.remove_moderator_rounded,
          ),
          OperatorConsequence.notifies('The person'),
          OperatorConsequence.recorded('This decision and your reason'),
        ],
        perform: (reason) async {
          await ref.read(adminRepositoryProvider).revokePersonVerification(
                userId,
                verificationClass: verificationClass,
                reason: reason ?? '',
              );
          return 'Verification revoked. The person has been notified and the '
              'decision recorded.';
        },
      ),
    );
    if (done) ref.invalidate(personVerificationProvider(userId));
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _RelatedWork extends ConsumerWidget {
  const _RelatedWork({required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final work = ref.watch(operatorWorkListProvider);

    return work.when(
      loading: () => const OperatorSection(
        title: 'Waiting on this subject',
        child: OperatorLoading(lines: 1),
      ),
      error: (_, __) => const SizedBox.shrink(),
      data: (items) {
        final mine =
            items.where((i) => i.subjectId == userId).toList(growable: false);
        if (mine.isEmpty) {
          return const OperatorSection(
            title: 'Waiting on this subject',
            child: OperatorPanel(
              child: OperatorClear(title: 'Nothing open'),
            ),
          );
        }
        return OperatorSection(
          title: 'Waiting on this subject',
          child: OperatorPanel(
            padding: const EdgeInsets.symmetric(vertical: AuraSpace.s4),
            child: Column(
              children: [
                for (final item in mine)
                  ListTile(
                    dense: true,
                    title: Text(
                      item.title,
                      style: const TextStyle(
                          color: AuraSurface.ink, fontSize: 13),
                    ),
                    subtitle: Text(
                      item.sourceLabel,
                      style: const TextStyle(
                          color: AuraSurface.muted, fontSize: 11.5),
                    ),
                    trailing: OperatorAge(days: item.ageDays, dense: true),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _PersonHistory extends ConsumerWidget {
  const _PersonHistory({required this.userId, required this.authority});

  final String userId;
  final OperatorAuthority authority;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!authority.can(OperatorCapability.auditRead)) {
      return const OperatorSection(
        title: 'History',
        child: OperatorInsufficientCapability(needs: 'audit'),
      );
    }

    final verification = ref.watch(personVerificationProvider(userId));

    return verification.when(
      loading: () => const OperatorSection(
        title: 'History',
        child: OperatorLoading(lines: 2),
      ),
      error: (_, __) => const SizedBox.shrink(),
      data: (v) {
        if (v.history.isEmpty) {
          return const OperatorSection(
            title: 'History',
            child: OperatorPanel(
              child: OperatorClear(
                title: 'No decisions recorded',
                icon: Icons.history_rounded,
              ),
            ),
          );
        }
        return OperatorSection(
          title: 'History',
          subtitle: 'Decisions recorded against this person',
          child: OperatorPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final record in v.history)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AuraSpace.s12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // A timeline reads as a sequence, which is what
                        // history is. A table of rows does not.
                        Container(
                          width: 6,
                          height: 6,
                          margin: const EdgeInsets.only(top: 6),
                          decoration: const BoxDecoration(
                            color: AuraSurface.accent,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: AuraSpace.s12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  OperatorStatePill(
                                    state: record.state,
                                    dense: true,
                                  ),
                                  const SizedBox(width: AuraSpace.s8),
                                  Text(
                                    record.verificationClass,
                                    style: const TextStyle(
                                      color: AuraSurface.ink,
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              if (record.reason.isNotEmpty) ...[
                                const SizedBox(height: 3),
                                Text(
                                  record.reason,
                                  style: const TextStyle(
                                    color: AuraSurface.muted,
                                    fontSize: 12,
                                    height: 1.35,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
