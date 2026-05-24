import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ui/aura_platform_components.dart';
import '../../../core/ui/aura_radius.dart';
import '../../../core/ui/aura_responsive.dart';
import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/substrate_chip.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';
import '../data/admin_providers.dart';
import 'admin_error.dart';

class AdminInstitutionDomainsScreen extends ConsumerWidget {
  const AdminInstitutionDomainsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final domainsAsync = ref.watch(adminInstitutionDomainsProvider);

    return AuraScaffold(
      title: 'Institution domains',
      showHomeAction: true,
      body: domainsAsync.when(
        loading: () => const Center(
          child: AuraLoadingState(message: 'Loading domain requests…'),
        ),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(AuraSpace.s16),
            child: AuraErrorState(
              title: 'Failed to load domain requests',
              body: adminErrorMessage(e),
              action: AuraSecondaryButton(
                label: 'Retry',
                icon: Icons.refresh_rounded,
                onPressed: () => ref.invalidate(adminInstitutionDomainsProvider),
              ),
            ),
          ),
        ),
        data: (domains) {
          if (domains.isEmpty) {
            return const Center(
              child: AuraEmptyState(
                title: 'No pending domains',
                body: 'All institution domain requests have been reviewed.',
                icon: Icons.apartment_outlined,
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(
              AuraSpace.s16,
              AuraSpace.s16,
              AuraSpace.s16,
              AuraSpace.s32,
            ),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: kWorkspaceWidth),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final domain in domains) ...[
                        _DomainCard(domain: domain),
                        const SizedBox(height: AuraSpace.s10),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _DomainCard extends ConsumerStatefulWidget {
  const _DomainCard({required this.domain});

  final AdminInstitutionDomain domain;

  @override
  ConsumerState<_DomainCard> createState() => _DomainCardState();
}

class _DomainCardState extends ConsumerState<_DomainCard> {
  bool _busy = false;
  String? _error;
  bool _done = false;

  Future<void> _approve() async {
    setState(() { _busy = true; _error = null; });
    try {
      await ref.read(adminRepositoryProvider).approveDomain(widget.domain.id);
      if (mounted) {
        setState(() { _done = true; _busy = false; });
        ref.invalidate(adminInstitutionDomainsProvider);
      }
    } catch (e) {
      if (mounted) setState(() { _error = adminErrorMessage(e); _busy = false; });
    }
  }

  Future<void> _reject() async {
    setState(() { _busy = true; _error = null; });
    try {
      await ref.read(adminRepositoryProvider).rejectDomain(widget.domain.id);
      if (mounted) {
        setState(() { _done = true; _busy = false; });
        ref.invalidate(adminInstitutionDomainsProvider);
      }
    } catch (e) {
      if (mounted) setState(() { _error = adminErrorMessage(e); _busy = false; });
    }
  }

  String _formatDate(DateTime dt) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    if (_done) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(AuraSpace.s16),
      decoration: BoxDecoration(
        color: AuraSurface.card,
        borderRadius: BorderRadius.circular(AuraRadius.card),
        border: Border.all(color: AuraSurface.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AuraSurface.elevated,
                  borderRadius: BorderRadius.circular(AuraRadius.md),
                  border: Border.all(color: AuraSurface.divider),
                ),
                child: const Icon(
                  Icons.apartment_outlined,
                  size: 20,
                  color: AuraSurface.faint,
                ),
              ),
              const SizedBox(width: AuraSpace.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.domain.organizationName,
                      style: AuraText.body.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AuraSpace.s4),
                    Text(
                      widget.domain.domain,
                      style: AuraText.small.copyWith(
                        color: AuraSurface.accentText,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Requested: ${_formatDate(widget.domain.createdAt)}',
                      style: AuraText.micro.copyWith(color: AuraSurface.faint),
                    ),
                  ],
                ),
              ),
              _StatusPill(status: widget.domain.status),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: AuraSpace.s10),
            Text(
              _error!,
              style: AuraText.small.copyWith(color: AuraSurface.coRose),
            ),
          ],
          const SizedBox(height: AuraSpace.s14),
          Row(
            children: [
              AuraPrimaryButton(
                label: 'Approve',
                icon: Icons.check_circle_outline,
                onPressed: _busy ? null : _approve,
              ),
              const SizedBox(width: AuraSpace.s10),
              AuraSecondaryButton(
                label: 'Reject',
                icon: Icons.cancel_outlined,
                onPressed: _busy ? null : _reject,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Institution domain verification status rendered as a canonical
/// `SubstrateChip`. Maps the institution-domain lifecycle to canonical
/// state semantics per `system/diagnostics/diagnostics-grammar.md`
/// §3.3 (the pass/fail/unknown triad applied to verification gates).
class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final state = switch (status.toLowerCase()) {
      'verified' || 'active' => SubstrateChipState.verdant,
      'failed' || 'rejected' => SubstrateChipState.rose,
      'pending' || 'unknown' => SubstrateChipState.mist,
      _ => SubstrateChipState.sun,
    };
    return SubstrateChip(label: status, state: state);
  }
}
