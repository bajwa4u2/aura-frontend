/// AN INSTITUTION, AS AN OPERATOR SUBJECT.
///
/// Standing, domain proof, membership and verification were four screens, one
/// of which (`/admin/institutions/:id/members`) could only be reached by
/// typing its URL. They are four authorities and remain so; this is one place
/// to see them and one place to invoke them from.
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
import 'subjects_area.dart';

class SubjectInstitutionArea extends ConsumerWidget {
  const SubjectInstitutionArea({super.key, required this.institutionId});

  final String institutionId;

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

    final institutions = ref.watch(subjectInstitutionsProvider);

    return institutions.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(AuraSpace.s20),
        child: OperatorLoading(lines: 4),
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.all(AuraSpace.s20),
        child: OperatorFailure(
          title: 'This institution could not be loaded',
          onRetry: () => ref.invalidate(subjectInstitutionsProvider),
        ),
      ),
      data: (all) {
        final match = all.where((i) => i.id == institutionId).toList();
        if (match.isEmpty) {
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
        final institution = match.first;

        return LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 980;
            final standing = _Standing(
              institution: institution,
              authority: authority,
            );
            final domains = _Domains(institutionId: institutionId);
            final work = _RelatedWork(institutionId: institutionId);

            return ListView(
              padding: EdgeInsets.all(wide ? AuraSpace.s20 : AuraSpace.s12),
              children: [
                if (wide)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 3, child: standing),
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

    final domains = ref.watch(adminInstitutionDomainsProvider);

    return domains.when(
      loading: () => const OperatorSection(
        title: 'Domain proof',
        child: OperatorLoading(lines: 1),
      ),
      error: (_, __) => const SizedBox.shrink(),
      data: (all) {
        final mine = all.where((d) => d.id == institutionId).toList();
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
                  if (canWrite) ...[
                    const SizedBox(height: AuraSpace.s8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        onPressed: () => _approve(context, ref, d.id, d.domain),
                        child: const Text('Approve domain'),
                      ),
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

  Future<void> _approve(
    BuildContext context,
    WidgetRef ref,
    String domainId,
    String domain,
  ) async {
    final done = await runOperatorAction(
      context,
      OperatorAction(
        title: 'Approve domain proof',
        subject: domain,
        detail: 'The verification authority applies this decision. Approving '
            'domain proof is a statement about institutional legitimacy, not '
            'about any individual person.',
        confirmLabel: 'Approve',
        consequences: [
          const OperatorConsequence(
            text: 'The institution may claim this domain.',
            tone: OperatorTone.good,
            icon: Icons.verified_rounded,
          ),
          OperatorConsequence.notifies('The requesting institution'),
          OperatorConsequence.recorded('This approval'),
        ],
        perform: (_) async {
          await ref
              .read(adminRepositoryProvider)
              .approveDomain(domainId);
          return 'Domain approved and the decision recorded.';
        },
      ),
    );
    if (done) ref.invalidate(adminInstitutionDomainsProvider);
  }
}

class _RelatedWork extends ConsumerWidget {
  const _RelatedWork({required this.institutionId});

  final String institutionId;

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
        final mine = items
            .where((i) => i.subjectId == institutionId)
            .toList(growable: false);
        if (mine.isEmpty) {
          return const OperatorSection(
            title: 'Waiting on this subject',
            child: OperatorPanel(child: OperatorClear(title: 'Nothing open')),
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
