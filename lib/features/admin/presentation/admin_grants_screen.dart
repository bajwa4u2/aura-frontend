import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ui/aura_platform_components.dart';
import '../../../core/ui/aura_radius.dart';
import '../../../core/ui/aura_responsive.dart';
import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';
import '../data/admin_providers.dart';
import 'admin_error.dart';

class AdminGrantsScreen extends ConsumerWidget {
  const AdminGrantsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final grantsAsync = ref.watch(adminGrantsProvider);

    return AuraScaffold(
      title: 'Admin grants',
      showHomeAction: true,
      body: grantsAsync.when(
        loading: () => const Center(
          child: AuraLoadingState(message: 'Loading grants…'),
        ),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(AuraSpace.s16),
            child: AuraErrorState(
              title: 'Failed to load grants',
              body: adminErrorMessage(e),
              action: AuraSecondaryButton(
                label: 'Retry',
                icon: Icons.refresh_rounded,
                onPressed: () => ref.invalidate(adminGrantsProvider),
              ),
            ),
          ),
        ),
        data: (grants) {
          if (grants.isEmpty) {
            return const Center(
              child: AuraEmptyState(
                title: 'No grants found',
                body: 'No admin grants are currently active.',
                icon: Icons.verified_user_outlined,
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
                      Container(
                        decoration: BoxDecoration(
                          color: AuraSurface.card,
                          borderRadius: BorderRadius.circular(AuraRadius.card),
                          border: Border.all(color: AuraSurface.divider),
                        ),
                        child: Column(
                          children: [
                            for (var i = 0; i < grants.length; i++) ...[
                              _GrantRow(grant: grants[i]),
                              if (i < grants.length - 1)
                                Container(
                                  height: 1,
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: AuraSpace.s16,
                                  ),
                                  color: AuraSurface.divider,
                                ),
                            ],
                          ],
                        ),
                      ),
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

class _GrantRow extends StatelessWidget {
  const _GrantRow({required this.grant});

  final AdminGrant grant;

  String _formatDate(DateTime dt) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }

  String _relativePast(DateTime past) {
    final diff = DateTime.now().difference(past);
    if (diff.inDays >= 1) {
      return '${diff.inDays}d ago';
    }
    if (diff.inHours >= 1) return '${diff.inHours}h ago';
    if (diff.inMinutes >= 1) return '${diff.inMinutes}m ago';
    return 'just now';
  }

  @override
  Widget build(BuildContext context) {
    final status = grant.derivedStatus;
    final isLive = status == AdminGrantStatus.active ||
        status == AdminGrantStatus.bootstrap;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AuraSpace.s16,
        vertical: AuraSpace.s14,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isLive ? AuraSurface.accentSoft : AuraSurface.elevated,
              borderRadius: BorderRadius.circular(AuraRadius.md),
              border: Border.all(
                color: isLive
                    ? AuraSurface.accent.withValues(alpha: 0.25)
                    : AuraSurface.divider,
              ),
            ),
            child: Icon(
              Icons.verified_user_outlined,
              size: 20,
              color: isLive ? AuraSurface.accentText : AuraSurface.faint,
            ),
          ),
          const SizedBox(width: AuraSpace.s14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: AuraSpace.s8,
                  runSpacing: AuraSpace.s4,
                  children: [
                    Text(
                      grant.role.toUpperCase(),
                      style: AuraText.body.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AuraSurface.ink,
                      ),
                    ),
                    _StatusBadge(status: status),
                  ],
                ),
                const SizedBox(height: AuraSpace.s4),
                Text(
                  'Granted ${_formatDate(grant.createdAt)} '
                  '(${_relativePast(grant.createdAt)})',
                  style: AuraText.micro.copyWith(color: AuraSurface.faint),
                ),
                if (grant.expiresAt != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    status == AdminGrantStatus.expired
                        ? 'Expired ${_formatDate(grant.expiresAt!)} '
                            '(${_relativePast(grant.expiresAt!)})'
                        : 'Expires ${_formatDate(grant.expiresAt!)}',
                    style: AuraText.micro.copyWith(
                      color: status == AdminGrantStatus.expired
                          ? AuraSurface.dangerInk
                          : AuraSurface.faint,
                    ),
                  ),
                ],
                if (status == AdminGrantStatus.bootstrap) ...[
                  const SizedBox(height: 2),
                  Text(
                    'System OWNER (bootstrap) — anchors initial admin access',
                    style: AuraText.micro.copyWith(
                      color: AuraSurface.muted,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
                if (grant.permissions.isNotEmpty) ...[
                  const SizedBox(height: AuraSpace.s6),
                  Wrap(
                    spacing: AuraSpace.s6,
                    runSpacing: AuraSpace.s4,
                    children: grant.permissions
                        .map((p) => _PermissionChip(label: p))
                        .toList(),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final AdminGrantStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, bg, fg, borderAlpha) = switch (status) {
      AdminGrantStatus.active => (
          'ACTIVE',
          AuraSurface.accentSoft,
          AuraSurface.accentText,
          0.3,
        ),
      AdminGrantStatus.bootstrap => (
          'BOOTSTRAP',
          AuraSurface.accentSoft,
          AuraSurface.accentText,
          0.3,
        ),
      AdminGrantStatus.expired => (
          'EXPIRED',
          AuraSurface.elevated,
          AuraSurface.dangerInk,
          0.3,
        ),
      AdminGrantStatus.revoked => (
          'REVOKED',
          AuraSurface.elevated,
          AuraSurface.muted,
          0.0,
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AuraSpace.s8,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AuraRadius.pill),
        border: Border.all(
          color: borderAlpha == 0.0
              ? AuraSurface.divider
              : AuraSurface.accent.withValues(alpha: borderAlpha),
        ),
      ),
      child: Text(
        label,
        style: AuraText.micro.copyWith(
          color: fg,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class _PermissionChip extends StatelessWidget {
  const _PermissionChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AuraSpace.s8, vertical: 2),
      decoration: BoxDecoration(
        color: AuraSurface.elevated,
        borderRadius: BorderRadius.circular(AuraRadius.pill),
        border: Border.all(color: AuraSurface.divider),
      ),
      child: Text(
        label,
        style: AuraText.micro.copyWith(
          color: AuraSurface.muted,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
