/// INSTITUTIONAL GRANT REQUESTS — the queue an operator decides.
///
/// An institution's owner asks once for the 30-day Institutional Grant; Aura
/// approves or declines it. Each request is shown with what a decision needs:
/// which institution, which tier it asked for, who asked, what they wrote and
/// when. Nothing is pre-selected: the interface does not suggest an answer.
///
/// Reached from WORK, beside the queues the work summary enumerates. The
/// summary does not carry this source yet, so the chip there reads this
/// queue directly rather than inventing a source name.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/product/temporal.dart';
import '../../../core/ui/aura_radius.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../../monetization/providers/monetization_providers.dart';
import '../data/operator_grants.dart';
import '../domain/operator_authority_provider.dart';
import '../domain/operator_capability.dart';
import '../ui/operator_action.dart';
import '../ui/operator_kit.dart';

class GrantRequestsArea extends ConsumerWidget {
  const GrantRequestsArea({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authority =
        ref.watch(operatorAuthorityProvider).valueOrNull ??
        const OperatorAuthority.none();

    if (!authority.can(OperatorCapability.institutionsRead)) {
      return const Padding(
        padding: EdgeInsets.all(AuraSpace.s20),
        child: OperatorInsufficientCapability(needs: 'institutions'),
      );
    }

    final canDecide = authority.can(OperatorCapability.institutionsWrite);
    final requests = ref.watch(pendingGrantRequestsProvider);

    return _Frame(
      children: [
        OperatorSection(
          title: 'Institutional grant requests',
          subtitle:
              'An owner asked for 30 days of Pro at no charge. Each '
              'institution and each person may have it once.',
          trailing: requests.maybeWhen(
            data: (list) => Text(
              '${list.length} waiting',
              style: const TextStyle(
                color: AuraSurface.muted,
                fontSize: 12.5,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
            // An em dash, never 0: unknown is not the same as nothing waiting.
            orElse: () => const Text(
              '—',
              style: TextStyle(color: AuraSurface.faint, fontSize: 12.5),
            ),
          ),
          child: requests.when(
            loading: () => const OperatorLoading(lines: 4),
            error: (_, __) => OperatorFailure(
              title: 'The grant requests could not be loaded',
              detail: 'Nothing was decided. This is a read failure.',
              onRetry: () => ref.invalidate(pendingGrantRequestsProvider),
            ),
            data: (list) {
              if (list.isEmpty) {
                return const OperatorPanel(
                  child: OperatorClear(
                    title: 'Nothing is waiting',
                    detail: 'No institution is waiting for a grant decision.',
                  ),
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final r in list) ...[
                    _RequestCard(
                      key: ValueKey(r.id),
                      request: r,
                      canDecide: canDecide,
                    ),
                    const SizedBox(height: AuraSpace.s12),
                  ],
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Bounded rather than full-bleed on a wide screen, as the integrity detail
/// pages are.
class _Frame extends StatelessWidget {
  const _Frame({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 980;
        return ListView(
          padding: EdgeInsets.all(wide ? AuraSpace.s20 : AuraSpace.s12),
          children: [
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

class _RequestCard extends ConsumerWidget {
  const _RequestCard({
    super.key,
    required this.request,
    required this.canDecide,
  });

  final OperatorGrantRequest request;
  final bool canDecide;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = request;
    final tier = _tierLabel(ref, r.requestedTier);
    final asked = r.requestedAt;
    final ageDays = asked == null
        ? null
        : DateTime.now().difference(asked).inDays.clamp(0, 100000);
    final alreadyPro = (r.institutionPlan ?? '').toUpperCase() == 'PRO';

    return OperatorPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  r.institutionName,
                  style: const TextStyle(
                    color: AuraSurface.ink,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                  ),
                ),
              ),
              if (ageDays != null) OperatorAge(days: ageDays, dense: true),
            ],
          ),
          if (r.institutionSlug != null) ...[
            const SizedBox(height: 2),
            Text(
              '@${r.institutionSlug}',
              style: const TextStyle(color: AuraSurface.faint, fontSize: 12),
            ),
          ],
          const SizedBox(height: AuraSpace.s12),
          _Meta(label: 'Tier asked for', value: tier),
          _Meta(label: 'Asked by', value: r.requesterLabel),
          _Meta(
            label: 'Asked on',
            value: asked == null ? '' : AuraTemporal.fullShort(asked),
          ),
          if (alreadyPro)
            const _Meta(
              label: 'Plan now',
              value: 'Pro. It started paying after it asked; approving is '
                  'refused.',
            ),
          const SizedBox(height: AuraSpace.s4),
          const Text(
            'WHAT THEY WROTE',
            style: TextStyle(
              color: AuraSurface.faint,
              fontSize: 11,
              letterSpacing: 0.8,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AuraSpace.s8),
          _Quoted(r.message ?? ''),
          const SizedBox(height: AuraSpace.s16),
          if (!canDecide)
            const Text(
              'You may read these requests, but not decide them.',
              style: TextStyle(color: AuraSurface.faint, fontSize: 12.5),
            )
          else
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: () => _approve(context, ref, tier),
                    style: FilledButton.styleFrom(
                      backgroundColor: AuraSurface.accent,
                      foregroundColor: AuraSurface.onAccent,
                      padding: const EdgeInsets.symmetric(
                        vertical: AuraSpace.s14,
                      ),
                    ),
                    child: const Text('Approve'),
                  ),
                ),
                const SizedBox(width: AuraSpace.s12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _decline(context, ref),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AuraSurface.dangerInk,
                      side: const BorderSide(color: AuraSurface.divider),
                      padding: const EdgeInsets.symmetric(
                        vertical: AuraSpace.s14,
                      ),
                    ),
                    child: const Text('Decline'),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Future<void> _approve(BuildContext context, WidgetRef ref, String tier) async {
    await runOperatorAction(
      context,
      OperatorAction(
        title: 'Approve the grant',
        subject: request.institutionName,
        detail:
            'The institution is on $tier for 30 days, with that tier\'s '
            'staff seats and allowance. Nothing is charged; it returns to '
            'Free when the grant ends.',
        confirmLabel: 'Approve',
        consequences: [
          OperatorConsequence(
            text: '${request.institutionName} is on Pro · $tier for 30 days.',
            tone: OperatorTone.good,
            icon: Icons.workspace_premium_outlined,
          ),
          OperatorConsequence.notifies("The institution's owners"),
          const OperatorConsequence(
            text: 'Neither this institution nor this person can have the '
                'grant again.',
            icon: Icons.block_outlined,
          ),
          OperatorConsequence.recorded('This decision'),
        ],
        perform: (_) async {
          await ref.read(operatorGrantRepositoryProvider).approve(request.id);
          return 'Approved. The owners have been told.';
        },
      ),
    );
    // Re-read however the sheet was closed: a decision that landed leaves
    // the queue, and one refused (already decided elsewhere) may have too.
    ref.invalidate(pendingGrantRequestsProvider);
  }

  Future<void> _decline(BuildContext context, WidgetRef ref) async {
    await runOperatorAction(
      context,
      OperatorAction(
        title: 'Decline the request',
        subject: request.institutionName,
        detail:
            'The institution stays on its current plan. A reason is '
            'optional; if you write one, the owners can read it.',
        confirmLabel: 'Decline',
        destructive: true,
        offersReason: true,
        reasonLabel: 'What the owners are told (optional)',
        consequences: [
          const OperatorConsequence(
            text: 'Nothing changes for the institution.',
            icon: Icons.remove_circle_outline_rounded,
          ),
          OperatorConsequence.notifies("The institution's owners"),
          OperatorConsequence.recorded('This decision and any reason'),
        ],
        perform: (reason) async {
          await ref
              .read(operatorGrantRepositoryProvider)
              .decline(request.id, reason: reason);
          return 'Declined. The owners have been told.';
        },
      ),
    );
    // Re-read however the sheet was closed: a decision that landed leaves
    // the queue, and one refused (already decided elsewhere) may have too.
    ref.invalidate(pendingGrantRequestsProvider);
  }
}

/// The tier's own label from the plan configuration; a readable form of the
/// code when the configuration is not to hand.
String _tierLabel(WidgetRef ref, String code) {
  final config = ref.watch(monetizationConfigProvider).valueOrNull;
  final label = config?.tierByCode(code)?.label;
  if (label != null && label.trim().isNotEmpty) return label;
  if (code.trim().isEmpty) return 'Not stated';
  final words = code.toLowerCase().split('_').where((w) => w.isNotEmpty);
  final text = words.join(' ');
  return text.isEmpty ? code : '${text[0].toUpperCase()}${text.substring(1)}';
}

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

/// Somebody else's words, marked as theirs by the rule down the left edge.
class _Quoted extends StatelessWidget {
  const _Quoted(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
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
        border: Border(left: BorderSide(color: AuraSurface.accent, width: 3)),
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
