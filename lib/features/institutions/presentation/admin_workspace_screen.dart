import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/admin_access_provider.dart';
import '../../../core/ui/aura_platform_components.dart';
import '../../../core/ui/aura_radius.dart';
import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';

class AdminWorkspaceScreen extends ConsumerWidget {
  const AdminWorkspaceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final adminAsync = ref.watch(appAdminAccessProvider);

    return AuraScaffold(
      title: 'Admin workspace',
      showHomeAction: true,
      body: adminAsync.when(
        loading: () =>
            const Center(child: AuraLoadingState(message: 'Loading…')),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(AuraSpace.s16),
            child: AuraErrorState(
              title: 'Failed to load workspace',
              body: e.toString(),
            ),
          ),
        ),
        data: (admin) {
          if (!admin.isAdmin) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AuraSpace.s24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: const BoxDecoration(
                        color: AuraSurface.dangerBg,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.lock_outline,
                        size: 28,
                        color: AuraSurface.dangerInk,
                      ),
                    ),
                    const SizedBox(height: AuraSpace.s16),
                    const Text('Not available', style: AuraText.title),
                    const SizedBox(height: AuraSpace.s8),
                    Text(
                      'This workspace is only available to platform admins.',
                      style: AuraText.body.copyWith(color: AuraSurface.muted),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          final me = admin.me ?? <String, dynamic>{};
          final name =
              (me['displayName'] ?? me['name'] ?? '').toString().trim();
          final email = (me['email'] ?? '').toString().trim();

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
                      _AdminHeader(name: name, email: email),
                      const SizedBox(height: AuraSpace.s20),
                      _ModuleGroup(
                        label: 'Content',
                        modules: [
                          _AdminModule(
                            icon: Icons.campaign_outlined,
                            title: 'Announcements',
                            description:
                                'Publish and manage platform-wide announcements',
                            available: true,
                            onTap: () => context.go('/announcements'),
                          ),
                          _AdminModule(
                            icon: Icons.add_box_outlined,
                            title: 'New announcement',
                            description:
                                'Draft and publish a new platform notice',
                            available: true,
                            onTap: () => context.go('/announcements/create'),
                          ),
                          _AdminModule(
                            icon: Icons.mail_outline,
                            title: 'Communications center',
                            description:
                                'Preview newsletters, digests, AI drafts, and campaign approvals',
                            available: true,
                            onTap: () => context.go('/admin/communications'),
                          ),
                        ],
                      ),
                      const SizedBox(height: AuraSpace.s16),
                      _ModuleGroup(
                        label: 'Discovery',
                        modules: [
                          _AdminModule(
                            icon: Icons.apartment_outlined,
                            title: 'Institutions',
                            description:
                                'Browse registered institutions and their status',
                            available: true,
                            onTap: () => context.go('/institutions'),
                          ),
                          _AdminModule(
                            icon: Icons.search_rounded,
                            title: 'Member search',
                            description:
                                'Search across the platform member directory',
                            available: true,
                            onTap: () => context.go('/search'),
                          ),
                        ],
                      ),
                      const SizedBox(height: AuraSpace.s16),
                      _ModuleGroup(
                        label: 'Platform activity',
                        modules: [
                          _AdminModule(
                            icon: Icons.timeline_outlined,
                            title: 'Activity feed',
                            description:
                                'Review platform-wide activity and signals',
                            available: true,
                            onTap: () => context.go('/activity'),
                          ),
                        ],
                      ),
                      const SizedBox(height: AuraSpace.s16),
                      const _ModuleGroup(
                        label: 'Governance',
                        planned: true,
                        modules: [
                          _AdminModule(
                            icon: Icons.group_outlined,
                            title: 'Users & members',
                            description:
                                'Member accounts, roles, and status management',
                            available: false,
                          ),
                          _AdminModule(
                            icon: Icons.report_gmailerrorred_outlined,
                            title: 'Reports & moderation',
                            description:
                                'Content reports, flags, and moderation queue',
                            available: false,
                          ),
                          _AdminModule(
                            icon: Icons.verified_outlined,
                            title: 'Verification',
                            description:
                                'Institutional credential verification requests',
                            available: false,
                          ),
                        ],
                      ),
                      const SizedBox(height: AuraSpace.s16),
                      const _ModuleGroup(
                        label: 'System',
                        planned: true,
                        modules: [
                          _AdminModule(
                            icon: Icons.bar_chart_outlined,
                            title: 'Analytics',
                            description:
                                'Platform usage, growth, and engagement metrics',
                            available: false,
                          ),
                          _AdminModule(
                            icon: Icons.tune_outlined,
                            title: 'Platform settings',
                            description:
                                'Feature flags, limits, and system configuration',
                            available: false,
                          ),
                          _AdminModule(
                            icon: Icons.history_rounded,
                            title: 'Audit log',
                            description:
                                'Admin action history and governance trail',
                            available: false,
                          ),
                          _AdminModule(
                            icon: Icons.monitor_heart_outlined,
                            title: 'System health',
                            description:
                                'Service status, queue depth, and error rates',
                            available: false,
                          ),
                        ],
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

// ── Admin header ───────────────────────────────────────────────────────────

class _AdminHeader extends StatelessWidget {
  const _AdminHeader({required this.name, required this.email});

  final String name;
  final String email;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AuraSpace.s20),
      decoration: BoxDecoration(
        color: AuraSurface.card,
        borderRadius: BorderRadius.circular(AuraRadius.xl),
        border: Border.all(color: AuraSurface.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: AuraSurface.accentSoft,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AuraSurface.accent.withValues(alpha: 0.3),
                  ),
                ),
                child: const Icon(
                  Icons.admin_panel_settings_outlined,
                  size: 24,
                  color: AuraSurface.accentText,
                ),
              ),
              const SizedBox(width: AuraSpace.s14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Admin workspace', style: AuraText.title),
                    const SizedBox(height: AuraSpace.s4),
                    Text(
                      'Platform authority surface — system-level controls for platform administration and governance.',
                      style: AuraText.small.copyWith(
                        color: AuraSurface.muted,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AuraSpace.s16),
          Wrap(
            spacing: AuraSpace.s8,
            runSpacing: AuraSpace.s8,
            children: [
              if (name.isNotEmpty) _IdentityChip(label: name),
              if (email.isNotEmpty)
                _IdentityChip(label: email, muted: true),
              const _IdentityChip(label: 'Platform admin', accent: true),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Module group ───────────────────────────────────────────────────────────

class _ModuleGroup extends StatelessWidget {
  const _ModuleGroup({
    required this.label,
    required this.modules,
    this.planned = false,
  });

  final String label;
  final List<_AdminModule> modules;
  final bool planned;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label.toUpperCase(),
              style: AuraText.label.copyWith(
                color: AuraSurface.faint,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
            ),
            if (planned) ...[
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
                  'Coming soon',
                  style: AuraText.micro.copyWith(color: AuraSurface.faint),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: AuraSpace.s10),
        Container(
          decoration: BoxDecoration(
            color: AuraSurface.card,
            borderRadius: BorderRadius.circular(AuraRadius.card),
            border: Border.all(color: AuraSurface.divider),
          ),
          child: Column(
            children: [
              for (var i = 0; i < modules.length; i++) ...[
                modules[i],
                if (i < modules.length - 1)
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
    );
  }
}

// ── Module tile ────────────────────────────────────────────────────────────

class _AdminModule extends StatelessWidget {
  const _AdminModule({
    required this.icon,
    required this.title,
    required this.description,
    required this.available,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String description;
  final bool available;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final opacity = available ? 1.0 : 0.48;

    return Opacity(
      opacity: opacity,
      child: InkWell(
        onTap: available ? onTap : null,
        borderRadius: BorderRadius.circular(AuraRadius.card),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AuraSpace.s16,
            vertical: AuraSpace.s14,
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: available
                      ? AuraSurface.accentSoft
                      : AuraSurface.elevated,
                  borderRadius: BorderRadius.circular(AuraRadius.md),
                  border: Border.all(
                    color: available
                        ? AuraSurface.accent.withValues(alpha: 0.2)
                        : AuraSurface.divider,
                  ),
                ),
                child: Icon(
                  icon,
                  size: 20,
                  color: available
                      ? AuraSurface.accentText
                      : AuraSurface.faint,
                ),
              ),
              const SizedBox(width: AuraSpace.s14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AuraText.body.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AuraSurface.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      description,
                      style: AuraText.small.copyWith(
                        color: AuraSurface.muted,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AuraSpace.s10),
              Icon(
                available ? Icons.chevron_right : Icons.lock_outline,
                size: 18,
                color: AuraSurface.faint,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Identity chip ──────────────────────────────────────────────────────────

class _IdentityChip extends StatelessWidget {
  const _IdentityChip({required this.label, this.muted = false, this.accent = false});

  final String label;
  final bool muted;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AuraSpace.s10,
        vertical: AuraSpace.s6,
      ),
      decoration: BoxDecoration(
        color: accent ? AuraSurface.accentSoft : AuraSurface.elevated,
        border: Border.all(
          color: accent
              ? AuraSurface.accent.withValues(alpha: 0.3)
              : AuraSurface.divider,
        ),
        borderRadius: BorderRadius.circular(AuraRadius.pill),
      ),
      child: Text(
        label,
        style: AuraText.small.copyWith(
          fontWeight: FontWeight.w600,
          color: accent
              ? AuraSurface.accentText
              : muted
              ? AuraSurface.muted
              : AuraSurface.ink,
        ),
      ),
    );
  }
}
