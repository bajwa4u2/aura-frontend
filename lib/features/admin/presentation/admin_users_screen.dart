import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ui/aura_platform_components.dart';
import '../../../core/ui/aura_radius.dart';
import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';
import '../data/admin_providers.dart';
import 'admin_error.dart';

class AdminUsersScreen extends ConsumerWidget {
  const AdminUsersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersAsync = ref.watch(adminUsersProvider);

    return AuraScaffold(
      title: 'Users',
      showHomeAction: true,
      body: usersAsync.when(
        loading: () => const Center(
          child: AuraLoadingState(message: 'Loading users…'),
        ),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(AuraSpace.s16),
            child: AuraErrorState(
              title: 'Failed to load users',
              body: adminErrorMessage(e),
              action: AuraSecondaryButton(
                label: 'Retry',
                icon: Icons.refresh_rounded,
                onPressed: () => ref.invalidate(adminUsersProvider),
              ),
            ),
          ),
        ),
        data: (users) {
          if (users.isEmpty) {
            return const Center(
              child: AuraEmptyState(
                title: 'No users found',
                body: 'No platform users are available.',
                icon: Icons.group_outlined,
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
                  constraints: const BoxConstraints(maxWidth: 960),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SectionHeader(
                        label: 'Members',
                        count: users.length,
                      ),
                      const SizedBox(height: AuraSpace.s12),
                      Container(
                        decoration: BoxDecoration(
                          color: AuraSurface.card,
                          borderRadius: BorderRadius.circular(AuraRadius.card),
                          border: Border.all(color: AuraSurface.divider),
                        ),
                        child: Column(
                          children: [
                            for (var i = 0; i < users.length; i++) ...[
                              _UserRow(user: users[i]),
                              if (i < users.length - 1)
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

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label, required this.count});

  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label.toUpperCase(),
          style: AuraText.label.copyWith(
            color: AuraSurface.faint,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(width: AuraSpace.s8),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AuraSpace.s8,
            vertical: 2,
          ),
          decoration: BoxDecoration(
            color: AuraSurface.elevated,
            borderRadius: BorderRadius.circular(AuraRadius.pill),
            border: Border.all(color: AuraSurface.divider),
          ),
          child: Text(
            count.toString(),
            style: AuraText.micro.copyWith(
              color: AuraSurface.muted,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _UserRow extends StatelessWidget {
  const _UserRow({required this.user});

  final AdminUserSummary user;

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return AuraSurface.accentText;
      case 'suspended':
        return AuraSurface.dangerInk;
      default:
        return AuraSurface.faint;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AuraSpace.s16,
        vertical: AuraSpace.s12,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.displayName.isNotEmpty ? user.displayName : user.handle,
                  style: AuraText.body.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: AuraSpace.s2),
                Text(
                  user.email,
                  style: AuraText.small.copyWith(color: AuraSurface.muted),
                ),
              ],
            ),
          ),
          const SizedBox(width: AuraSpace.s12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _RoleBadge(role: user.role),
              const SizedBox(height: AuraSpace.s4),
              Text(
                user.status,
                style: AuraText.micro.copyWith(
                  color: _statusColor(user.status),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RoleBadge extends StatelessWidget {
  const _RoleBadge({required this.role});

  final String role;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AuraSpace.s8,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: AuraSurface.elevated,
        borderRadius: BorderRadius.circular(AuraRadius.pill),
        border: Border.all(color: AuraSurface.divider),
      ),
      child: Text(
        role.toUpperCase(),
        style: AuraText.micro.copyWith(
          color: AuraSurface.faint,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}
