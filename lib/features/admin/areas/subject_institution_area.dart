/// AN INSTITUTION, AS AN OPERATOR SUBJECT.
///
/// Standing, domain proof, membership and verification were four screens, one
/// of which (`/admin/institutions/:id/members`) could only be reached by
/// typing its URL. They are four authorities and remain so; this is one place
/// to see them and one place to invoke them from.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../ui/operator_states.dart';
import 'package:go_router/go_router.dart';

import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../data/admin_providers.dart';
import '../data/operator_work.dart';
import '../domain/operator_authority_provider.dart';
import '../domain/operator_capability.dart';
import '../ui/operator_action.dart';
import '../ui/operator_kit.dart';
import 'subjects_area.dart';

class SubjectInstitutionArea extends ConsumerWidget {
  const SubjectInstitutionArea({
    super.key,
    required this.institutionId,
    this.focus,
  });

  final String institutionId;

  /// Which part of the subject the operator was sent here for. See
  /// [SubjectPersonArea.focus] — same rule, same reason: it changes what leads
  /// and hides nothing.
  final String? focus;

  String get _focus => (focus ?? '').toLowerCase();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authority = ref.watch(operatorAuthorityProvider).valueOrNull ??
        const OperatorAuthority.none();

    if (!authority.can(OperatorCapability.institutionsRead)) {
      return const Padding(
        padding: EdgeInsets.all(AuraSpace.s20),
        child: OperatorInsufficientCapability(needs: 'institution'),
      );
    }

    // RESOLVED BY ID, NOT FOUND IN A LIST.
    //
    // This used to search `subjectInstitutionsProvider` — the directory —
    // for a matching row. The directory was status-filtered, so a suspended
    // or pending institution reported "No such institution" on its own page
    // while plainly existing. A subject's existence cannot depend on which
    // slice of a list happens to be loaded beside it.
    final institution$ = ref.watch(institutionSubjectProvider(institutionId));

    return institution$.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(AuraSpace.s20),
        child: OperatorLoading(lines: 4),
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.all(AuraSpace.s20),
        child: OperatorFailure(
          title: 'This institution could not be loaded',
          detail: 'This is a read failure. It does not mean the institution '
              'is gone.',
          onRetry: () =>
              ref.invalidate(institutionSubjectProvider(institutionId)),
        ),
      ),
      data: (resolved) {
        if (resolved == null) {
          // A subject that does not exist is a real answer, not an error.
          return const Padding(
            padding: EdgeInsets.all(AuraSpace.s20),
            child: OperatorClear(
              title: 'No such institution',
              detail: 'It may have been removed, or the address is stale.',
              icon: Icons.help_outline_rounded,
            ),
          );
        }
        final institution = resolved;

        return LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 980;
            final standing = _Standing(
              institution: institution,
              authority: authority,
            );
            final domains = _Domains(institutionId: institutionId);
            final work = _RelatedWork(institutionId: institutionId);
            final members = _Members(
              institutionId: institutionId,
              authority: authority,
            );
            // Silent unless the institution is actually deadlocked. It leads
            // because when it applies, nothing else about the institution
            // matters until it is resolved.
            final ownership = _OwnershipRecovery(
              institutionId: institutionId,
              authority: authority,
            );

            return ListView(
              padding: EdgeInsets.all(wide ? AuraSpace.s20 : AuraSpace.s12),
              children: [
                ownership,
                if (_focus.isNotEmpty) ...[
                  OperatorPanel(
                    child: Row(
                      children: [
                        Icon(
                          _focus == 'domains'
                              ? Icons.dns_rounded
                              : Icons.verified_outlined,
                          size: 16,
                          color: AuraSurface.accent,
                        ),
                        const SizedBox(width: AuraSpace.s10),
                        Expanded(
                          child: Text(
                            _focus == 'domains'
                                ? 'You were sent here by domain proof waiting '
                                    'on this institution.'
                                : 'You were sent here by a verification '
                                    'request waiting on this institution.',
                            style: const TextStyle(
                              color: AuraSurface.ink,
                              fontSize: 12.5,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AuraSpace.s20),
                ],
                if (wide)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            standing,
                            const SizedBox(height: AuraSpace.s20),
                            members,
                          ],
                        ),
                      ),
                      const SizedBox(width: AuraSpace.s20),
                      Expanded(
                        flex: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            work,
                            const SizedBox(height: AuraSpace.s20),
                            domains,
                          ],
                        ),
                      ),
                    ],
                  )
                else ...[
                  standing,
                  const SizedBox(height: AuraSpace.s20),
                  members,
                  const SizedBox(height: AuraSpace.s20),
                  work,
                  const SizedBox(height: AuraSpace.s20),
                  domains,
                ],
              ],
            );
          },
        );
      },
    );
  }
}

class _Standing extends ConsumerWidget {
  const _Standing({required this.institution, required this.authority});

  final AdminInstitutionSummary institution;
  final OperatorAuthority authority;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canWrite = authority.can(OperatorCapability.institutionsWrite);

    return OperatorSection(
      title: institution.name,
      subtitle: institution.slug,
      child: OperatorPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                OperatorStatePill(
                  state: institution.status,
                  tone: institution.verifiedAt != null
                      ? OperatorTone.good
                      : OperatorTone.pending,
                ),
                const SizedBox(width: AuraSpace.s10),
                Text(
                  '${institution.memberCount} '
                  'member${institution.memberCount == 1 ? '' : 's'}',
                  style: const TextStyle(
                      color: AuraSurface.muted, fontSize: 12.5),
                ),
              ],
            ),
            if (institution.domain?.isNotEmpty == true) ...[
              const SizedBox(height: AuraSpace.s12),
              Row(
                children: [
                  const Icon(Icons.language_rounded,
                      size: 15, color: AuraSurface.faint),
                  const SizedBox(width: AuraSpace.s8),
                  Text(
                    institution.domain!,
                    style: const TextStyle(
                        color: AuraSurface.ink, fontSize: 13),
                  ),
                ],
              ),
            ],
            if (institution.suspendedAt != null) ...[
              const SizedBox(height: AuraSpace.s12),
              const Text(
                'This institution is suspended.',
                style:
                    TextStyle(color: AuraSurface.dangerInk, fontSize: 12.5),
              ),
            ],
            if (!canWrite) ...[
              const SizedBox(height: AuraSpace.s12),
              const Text(
                'You may read this standing, but not change it.',
                style: TextStyle(color: AuraSurface.faint, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Domains extends ConsumerWidget {
  const _Domains({required this.institutionId});

  final String institutionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authority = ref.watch(operatorAuthorityProvider).valueOrNull ??
        const OperatorAuthority.none();

    if (!authority.can(OperatorCapability.verificationRead)) {
      // Institution legitimacy is its own authority; holding INSTITUTIONS_READ
      // does not admit anyone to domain proof.
      return const OperatorSection(
        title: 'Domain proof',
        child: OperatorInsufficientCapability(needs: 'verification'),
      );
    }

    final domains = ref.watch(institutionDomainsProvider(institutionId));

    return domains.when(
      loading: () => const OperatorSection(
        title: 'Domain proof',
        child: OperatorLoading(lines: 1),
      ),
      error: (_, __) => const SizedBox.shrink(),
      data: (mine) {
        // NOT `d.id == institutionId`. `id` is the DOMAIN RECORD's id, so that
        // comparison was never true and the section reported "no domain proof
        // on record" for every institution that had some.
        if (mine.isEmpty) {
          return const OperatorSection(
            title: 'Domain proof',
            child: OperatorPanel(
              child: OperatorClear(
                title: 'No domain proof on record',
                icon: Icons.dns_rounded,
              ),
            ),
          );
        }
        final canWrite = authority.can(OperatorCapability.verificationWrite);
        return OperatorSection(
          title: 'Domain proof',
          child: OperatorPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final d in mine) ...[
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          d.domain,
                          style: const TextStyle(
                              color: AuraSurface.ink, fontSize: 13),
                        ),
                      ),
                      OperatorStatePill(state: d.status, dense: true),
                    ],
                  ),
                  // A decision is offered only while there is one to make.
                  // Approving an already-approved proof is an act with no
                  // consequence, and the console should not imply otherwise.
                  if (canWrite && d.isPending) ...[
                    const SizedBox(height: AuraSpace.s8),
                    Row(
                      children: [
                        TextButton(
                          onPressed: () =>
                              _decide(context, ref, d, approve: true),
                          child: const Text('Approve domain'),
                        ),
                        const SizedBox(width: AuraSpace.s8),
                        TextButton(
                          style: TextButton.styleFrom(
                            foregroundColor: AuraSurface.dangerInk,
                          ),
                          onPressed: () =>
                              _decide(context, ref, d, approve: false),
                          child: const Text('Reject'),
                        ),
                      ],
                    ),
                  ],
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _decide(
    BuildContext context,
    WidgetRef ref,
    AdminInstitutionDomain proof, {
    required bool approve,
  }) async {
    final done = await runOperatorAction(
      context,
      OperatorAction(
        title: approve ? 'Approve domain proof' : 'Reject domain proof',
        subject: proof.domain,
        detail: 'The verification authority applies this decision. Domain '
            'proof is a statement about institutional legitimacy, not about '
            'any individual person.',
        confirmLabel: approve ? 'Approve' : 'Reject',
        destructive: !approve,
        // The authority records a reason on either decision, so both ask for
        // one. A rejection an institution cannot understand is a rejection it
        // will simply submit again.
        requiresReason: true,
        reasonLabel: approve ? 'What proves this' : 'Why this is refused',
        consequences: [
          if (approve) ...[
            const OperatorConsequence(
              text: 'The institution may claim this domain.',
              tone: OperatorTone.good,
              icon: Icons.verified_rounded,
            ),
            OperatorConsequence.becomesPublic('The verified domain'),
          ] else
            const OperatorConsequence(
              text: 'The institution cannot claim this domain.',
              tone: OperatorTone.danger,
              icon: Icons.gpp_bad_rounded,
            ),
          OperatorConsequence.notifies('The requesting institution'),
          OperatorConsequence.recorded('This decision and your reason'),
        ],
        perform: (reason) async {
          final repository = ref.read(adminRepositoryProvider);
          if (approve) {
            await repository.approveDomain(proof.id, reason: reason);
            return 'Domain approved and the decision recorded.';
          }
          await repository.rejectDomain(proof.id, reason: reason);
          return 'Domain refused and the decision recorded.';
        },
      ),
    );
    if (done) {
      ref.invalidate(institutionDomainsProvider(institutionId));
      ref.invalidate(subjectInstitutionsProvider);
    }
  }
}


class _RelatedWork extends ConsumerWidget {
  const _RelatedWork({required this.institutionId});

  final String institutionId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final work = ref.watch(operatorWorkListProvider);

    // NEVER `SizedBox.shrink()` ON FAILURE. This section disappeared from a
    // live subject page when the worklist could not be read, so an operator
    // saw a subject with apparently nothing waiting on them — the most
    // dangerous possible reading of a failed dependency.
    return OperatorSection(
      title: 'Waiting on this subject',
      child: work.when(
        loading: () => const OperatorLoading(lines: 1),
        error: (_, __) => OperatorFailure(
          title: 'Open work could not be read',
          detail: 'This is a read failure. It does not mean nothing is '
              'waiting on this institution.',
          onRetry: () => ref.invalidate(operatorWorkListProvider),
        ),
        data: (signal) => OperatorSignalView<OperatorWorklist>(
          signal: signal,
          subject: 'open work',
          unauthorizedNeeds: 'a queue you can work',
          onRetry: () => ref.invalidate(operatorWorkListProvider),
          loading: const OperatorLoading(lines: 1),
          builder: (context, worklist) {
            final mine = worklist.items
                .where((i) => i.subjectId == institutionId)
                .toList(growable: false);

            if (mine.isEmpty) {
              return OperatorPanel(
                child: OperatorClear(
                  title: worklist.complete
                      ? 'Nothing open'
                      : 'Nothing open in the queues that answered',
                  icon: Icons.check_circle_outline_rounded,
                ),
              );
            }

            return OperatorPanel(
              padding: const EdgeInsets.symmetric(vertical: AuraSpace.s4),
              child: Column(
                children: [
                  for (final item in mine)
                    ListTile(
                      dense: true,
                      onTap: () => context.go(item.destination),
                      title: Text(
                        item.title,
                        style: const TextStyle(
                          color: AuraSurface.ink,
                          fontSize: 13,
                        ),
                      ),
                      subtitle: Text(
                        item.sourceLabel,
                        style: const TextStyle(
                          color: AuraSurface.muted,
                          fontSize: 11.5,
                        ),
                      ),
                      trailing: OperatorAge(days: item.ageDays, dense: true),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

/// Domain proof FOR ONE INSTITUTION, asked of the server rather than filtered
/// on this side. The estate-wide list is a different question with a different
/// answer, and reusing it here is how the section came to compare a domain
/// record's id against an institution's.
final institutionDomainsProvider = FutureProvider.autoDispose
    .family<List<AdminInstitutionDomain>, String>((ref, institutionId) async {
  return ref
      .watch(adminRepositoryProvider)
      .fetchInstitutionDomains(institutionId: institutionId);
});

final institutionMembersProvider = FutureProvider.autoDispose
    .family<List<AdminInstitutionMember>, String>((ref, institutionId) async {
  return ref.watch(adminRepositoryProvider).fetchInstitutionMembers(institutionId);
});

final institutionRecoveryProvider = FutureProvider.autoDispose
    .family<InstitutionOwnershipRecoveryState, String>((ref, institutionId) async {
  return ref
      .watch(adminRepositoryProvider)
      .fetchOwnershipRecoveryState(institutionId);
});

/// WHO RUNS THIS INSTITUTION.
///
/// `/admin/institutions/:id/members` existed and could only be reached by
/// typing its URL — no navigation entry pointed at it, so the one screen that
/// answers "who can act for this institution" was effectively unreachable.
class _Members extends ConsumerWidget {
  const _Members({required this.institutionId, required this.authority});

  final String institutionId;
  final OperatorAuthority authority;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final members = ref.watch(institutionMembersProvider(institutionId));

    return members.when(
      loading: () => const OperatorSection(
        title: 'Membership',
        child: OperatorLoading(lines: 3),
      ),
      error: (e, _) => OperatorSection(
        title: 'Membership',
        child: OperatorFailure(
          title: 'Membership could not be read',
          detail: '$e',
          onRetry: () =>
              ref.invalidate(institutionMembersProvider(institutionId)),
        ),
      ),
      data: (all) {
        if (all.isEmpty) {
          return const OperatorSection(
            title: 'Membership',
            child: OperatorPanel(
              child: OperatorClear(
                title: 'Nobody belongs to this institution',
                detail: 'Nobody can act for it, and nothing it publishes has '
                    'an author behind it.',
                icon: Icons.groups_outlined,
              ),
            ),
          );
        }

        final canWrite = authority.can(OperatorCapability.institutionsWrite);
        // Officers first: an operator asking "who runs this" is asking about
        // the people who can act, not scrolling an alphabetical roster.
        final ordered = [...all]..sort((a, b) {
            final rank = _roleRank(b.role) - _roleRank(a.role);
            if (rank != 0) return rank;
            return a.joinedAt.compareTo(b.joinedAt);
          });

        return OperatorSection(
          title: 'Membership',
          subtitle: '${all.length} member${all.length == 1 ? '' : 's'}',
          child: OperatorPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final member in ordered)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AuraSpace.s12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                member.displayName ??
                                    (member.handle == null
                                        ? member.userId
                                        : '@${member.handle}'),
                                style: const TextStyle(
                                  color: AuraSurface.ink,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              if (member.title != null &&
                                  member.title!.isNotEmpty)
                                Text(
                                  member.title!,
                                  style: const TextStyle(
                                    color: AuraSurface.muted,
                                    fontSize: 11.5,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: AuraSpace.s8),
                        // The role IS the authority. Shown as the record's own
                        // word rather than translated into a friendlier one
                        // that would stop matching what the API enforces.
                        OperatorStatePill(state: member.role, dense: true),
                        if (member.canSpeakOfficially) ...[
                          const SizedBox(width: AuraSpace.s4),
                          const Tooltip(
                            message: 'May speak as the institution',
                            child: Icon(
                              Icons.campaign_rounded,
                              size: 15,
                              color: AuraSurface.accent,
                            ),
                          ),
                        ],
                        // TWO ROWS THE ENDPOINT REFUSES, SO NEITHER IS
                        // OFFERED. An OWNER cannot be removed through member
                        // removal by anybody, platform admin included — the
                        // bypass was deliberately closed because it let an
                        // institution be stranded through an endpoint never
                        // meant to touch ownership. And nobody may remove
                        // themselves. A control that always fails is worse
                        // than no control: it teaches an operator that the
                        // console is unreliable.
                        if (canWrite &&
                            !_isOwner(member) &&
                            member.userId != authority.userId) ...[
                          const SizedBox(width: AuraSpace.s4),
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            iconSize: 16,
                            tooltip: 'Remove from this institution',
                            color: AuraSurface.dangerInk,
                            icon: const Icon(Icons.person_remove_rounded),
                            onPressed: () => _remove(context, ref, member),
                          ),
                        ] else if (canWrite && _isOwner(member)) ...[
                          const SizedBox(width: AuraSpace.s4),
                          const Tooltip(
                            message: 'An owner is changed through ownership, '
                                'never through membership',
                            child: Icon(
                              Icons.lock_outline_rounded,
                              size: 15,
                              color: AuraSurface.faint,
                            ),
                          ),
                        ],
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

  static bool _isOwner(AdminInstitutionMember member) =>
      member.role.toUpperCase() == 'OWNER';

  static int _roleRank(String role) => switch (role.toUpperCase()) {
        'OWNER' => 3,
        'ADMIN' => 2,
        'EDITOR' => 1,
        _ => 0,
      };

  Future<void> _remove(
    BuildContext context,
    WidgetRef ref,
    AdminInstitutionMember member,
  ) async {
    final who = member.displayName ??
        (member.handle == null ? member.userId : '@${member.handle}');

    final done = await runOperatorAction(
      context,
      OperatorAction(
        title: 'Remove from this institution',
        subject: '$who · ${member.role}',
        detail: 'They stop being able to act for the institution. Their own '
            'account is untouched, and nothing they published is removed.',
        confirmLabel: 'Remove',
        destructive: true,
        // NO REASON IS ASKED FOR, because the membership endpoint keeps none.
        // Demanding one an operator would then watch disappear is worse than
        // not asking: it implies a record that does not exist.
        consequences: [
          const OperatorConsequence(
            text: 'They can no longer act for this institution.',
            tone: OperatorTone.danger,
            icon: Icons.person_remove_rounded,
          ),
          if (member.canSpeakOfficially)
            const OperatorConsequence(
              text: 'They lose the ability to speak as the institution.',
              tone: OperatorTone.warn,
              icon: Icons.campaign_rounded,
            ),
          const OperatorConsequence(
            text: 'Aura keeps no reason for this. The membership record is '
                'closed, not deleted.',
            icon: Icons.info_outline_rounded,
          ),
        ],
        perform: (_) async {
          await ref
              .read(adminRepositoryProvider)
              .removeInstitutionMember(institutionId, member.userId);
          return '$who is no longer a member.';
        },
      ),
    );
    if (done) ref.invalidate(institutionMembersProvider(institutionId));
  }
}

// ─────────────────────────────────────────────────────────────────────────────

/// THE DEADLOCK, AND THE ONE WAY OUT OF IT.
///
/// An institution whose sole operator can no longer act has nobody who can
/// appoint a replacement — the authority to appoint is the authority that was
/// lost. Emergency recovery is the only act that resolves it, and it is
/// deliberately loud: it appoints an owner over the institution's own refusal.
///
/// SILENT WHEN NOT NEEDED. An always-visible "recover ownership" control on a
/// healthy institution is an invitation to use it.
class _OwnershipRecovery extends ConsumerWidget {
  const _OwnershipRecovery({
    required this.institutionId,
    required this.authority,
  });

  final String institutionId;
  final OperatorAuthority authority;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(institutionRecoveryProvider(institutionId));

    return state.maybeWhen(
      orElse: () => const SizedBox.shrink(),
      data: (recovery) {
        if (!recovery.recoveryRequired) return const SizedBox.shrink();

        final canWrite = authority.can(OperatorCapability.institutionsWrite);
        return OperatorSection(
          title: 'Ownership',
          subtitle: 'This institution has nobody who can act for it',
          child: OperatorPanel(
            tone: OperatorTone.danger,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  recovery.ownerOfRecordLabel == null
                      ? 'The institution has no owner able to exercise '
                          'authority, and nobody inside it can appoint one.'
                      : '${recovery.ownerOfRecordLabel} is still the owner of '
                          'record but can no longer act. Nobody inside the '
                          'institution can appoint a replacement.',
                  style: const TextStyle(
                    color: AuraSurface.ink,
                    fontSize: 13,
                    height: 1.45,
                  ),
                ),
                if (recovery.candidates.isEmpty) ...[
                  const SizedBox(height: AuraSpace.s12),
                  const Text(
                    'No member is eligible to take ownership, so there is '
                    'nobody to appoint.',
                    style: TextStyle(color: AuraSurface.muted, fontSize: 12.5),
                  ),
                ] else if (canWrite) ...[
                  const SizedBox(height: AuraSpace.s16),
                  const Text(
                    'ELIGIBLE TO TAKE OWNERSHIP',
                    style: TextStyle(
                      color: AuraSurface.faint,
                      fontSize: 11,
                      letterSpacing: 0.8,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: AuraSpace.s8),
                  for (final candidate in recovery.candidates)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AuraSpace.s8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              candidate.label,
                              style: const TextStyle(
                                color: AuraSurface.ink,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () =>
                                _recover(context, ref, candidate),
                            child: const Text('Appoint as owner'),
                          ),
                        ],
                      ),
                    ),
                ] else ...[
                  const SizedBox(height: AuraSpace.s12),
                  const Text(
                    'You may read this, but not decide it.',
                    style: TextStyle(color: AuraSurface.faint, fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _recover(
    BuildContext context,
    WidgetRef ref,
    OwnershipRecoveryCandidate candidate,
  ) async {
    final done = await runOperatorAction(
      context,
      OperatorAction(
        title: 'Appoint an owner',
        subject: candidate.label,
        detail: 'Aura appoints an owner over the institution rather than at '
            'its request. This is the platform overriding an institution, '
            'which is why it exists only for a deadlock and is recorded as '
            'plainly as it is performed.',
        confirmLabel: 'Appoint',
        destructive: true,
        requiresReason: true,
        reasonLabel: 'The circumstances that made this necessary',
        consequences: [
          OperatorConsequence(
            text: '${candidate.label} gains full authority over this '
                'institution.',
            tone: OperatorTone.danger,
            icon: Icons.admin_panel_settings_rounded,
          ),
          OperatorConsequence.notifies('The appointed owner'),
          const OperatorConsequence(
            text: 'Aura is acting over the institution, not for it.',
            tone: OperatorTone.warn,
            icon: Icons.gavel_rounded,
          ),
          OperatorConsequence.recorded('This decision and your reason'),
        ],
        perform: (reason) async {
          await ref.read(adminRepositoryProvider).emergencyRecoverOwnership(
                institutionId,
                candidate.userId,
                reason ?? '',
              );
          return '${candidate.label} is now the owner. The decision is '
              'recorded.';
        },
      ),
    );
    if (done) {
      ref.invalidate(institutionRecoveryProvider(institutionId));
      ref.invalidate(institutionMembersProvider(institutionId));
    }
  }
}
