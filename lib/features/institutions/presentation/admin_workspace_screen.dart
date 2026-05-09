import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/admin_access_provider.dart';
import '../../../core/errors/app_error_mapper.dart';
import '../../../core/ui/aura_platform_components.dart';
import '../../../core/ui/aura_radius.dart';
import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';
import '../../admin/data/admin_providers.dart';

// ─────────────────────────────────────────────────────────────────────────────

class AdminWorkspaceScreen extends ConsumerWidget {
  const AdminWorkspaceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final adminAsync = ref.watch(appAdminAccessProvider);

    return adminAsync.when(
      loading: () => AuraScaffold(
        title: 'Admin workspace',
        showHomeAction: true,
        body: const Center(child: AuraLoadingState(message: 'Verifying access…')),
      ),
      error: (e, _) => AuraScaffold(
        title: 'Admin workspace',
        showHomeAction: true,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(AuraSpace.s16),
            child: AuraErrorState(
              title: 'Failed to load workspace',
              body: e.toString(),
            ),
          ),
        ),
      ),
      data: (admin) {
        if (!admin.isAdmin) {
          return AuraScaffold(
            title: 'Admin workspace',
            showHomeAction: true,
            body: const _DeniedState(),
          );
        }
        return const _AdminDashboard();
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DENIED
// ─────────────────────────────────────────────────────────────────────────────

class _DeniedState extends StatelessWidget {
  const _DeniedState();

  @override
  Widget build(BuildContext context) {
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
            const Text('Access denied', style: AuraText.title),
            const SizedBox(height: AuraSpace.s8),
            Text(
              'Your account does not hold an active admin grant.',
              style: AuraText.body.copyWith(color: AuraSurface.muted),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MAIN DASHBOARD
// ─────────────────────────────────────────────────────────────────────────────

class _AdminDashboard extends ConsumerWidget {
  const _AdminDashboard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final meAsync = ref.watch(adminMeProvider);
    final metricsAsync = ref.watch(adminMetricsProvider);
    final healthAsync = ref.watch(adminHealthProvider);

    return AuraScaffold(
      showHeader: false,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AuraSpace.s16,
          AuraSpace.s20,
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
                  _IdentityCard(meAsync: meAsync),
                  const SizedBox(height: AuraSpace.s20),
                  _MetricsPanel(metricsAsync: metricsAsync),
                  const SizedBox(height: AuraSpace.s20),
                  _HealthPanel(healthAsync: healthAsync),
                  const SizedBox(height: AuraSpace.s20),
                  _QuickActionsPanel(),
                  const SizedBox(height: AuraSpace.s20),
                  _GovernancePanel(),
                  const SizedBox(height: AuraSpace.s20),
                  _SystemPanel(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// IDENTITY CARD
// ─────────────────────────────────────────────────────────────────────────────

class _IdentityCard extends StatelessWidget {
  const _IdentityCard({required this.meAsync});

  final AsyncValue<AdminAccess?> meAsync;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AuraSpace.s20),
      decoration: BoxDecoration(
        color: AuraSurface.card,
        borderRadius: BorderRadius.circular(AuraRadius.xl),
        border: Border.all(color: AuraSurface.divider),
      ),
      child: meAsync.when(
        loading: () => const _CardLoading(),
        error: (e, _) => _CardError(message: AppErrorMapper.from(e).message),
        data: (me) {
          final displayName = me?.displayName ?? '';
          final email = me?.email ?? '';
          final role = me?.role ?? 'admin';
          final permissions = me?.permissions ?? const [];

          return Column(
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
                          'Backend-authorised access — identity and grants verified by /v1/admin/me.',
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
                  if (displayName.isNotEmpty)
                    _Chip(label: displayName),
                  if (email.isNotEmpty)
                    _Chip(label: email, muted: true),
                  _Chip(
                    label: role.isNotEmpty ? role.toUpperCase() : 'ADMIN',
                    accent: true,
                  ),
                  if (permissions.isNotEmpty)
                    _Chip(
                      label: '${permissions.length} permission${permissions.length == 1 ? '' : 's'}',
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// METRICS PANEL
// ─────────────────────────────────────────────────────────────────────────────

class _MetricsPanel extends StatelessWidget {
  const _MetricsPanel({required this.metricsAsync});

  final AsyncValue<AdminMetricOverview?> metricsAsync;

  @override
  Widget build(BuildContext context) {
    return _Section(
      label: 'Platform metrics',
      icon: Icons.bar_chart_outlined,
      child: metricsAsync.when(
        loading: () => const _CardLoading(),
        error: (e, _) => _CardError(message: AppErrorMapper.from(e).message),
        data: (m) {
          if (m == null) {
            return const _EmptyCard(
              message: 'Metrics unavailable.',
            );
          }
          return Wrap(
            spacing: AuraSpace.s10,
            runSpacing: AuraSpace.s10,
            children: [
              _MetricTile(label: 'Total users', value: m.totalUsers),
              _MetricTile(label: 'Active users', value: m.activeUsers),
              _MetricTile(label: 'Institutions', value: m.totalInstitutions),
              _MetricTile(label: 'Pending reports', value: m.pendingReports),
              _MetricTile(label: 'Communications', value: m.totalCommunications),
              _MetricTile(label: 'Realtime sessions', value: m.realtimeSessions),
              _MetricTile(label: 'Devices', value: m.totalDevices),
              _MetricTile(label: 'Push queue', value: m.pendingPushJobs),
            ],
          );
        },
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 140,
      padding: const EdgeInsets.symmetric(
        horizontal: AuraSpace.s14,
        vertical: AuraSpace.s12,
      ),
      decoration: BoxDecoration(
        color: AuraSurface.elevated,
        borderRadius: BorderRadius.circular(AuraRadius.card),
        border: Border.all(color: AuraSurface.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value.toString(),
            style: AuraText.title.copyWith(
              color: AuraSurface.accentText,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AuraSpace.s4),
          Text(
            label,
            style: AuraText.micro.copyWith(color: AuraSurface.faint),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HEALTH PANEL
// ─────────────────────────────────────────────────────────────────────────────

class _HealthPanel extends StatelessWidget {
  const _HealthPanel({required this.healthAsync});

  final AsyncValue<AdminHealthSnapshot?> healthAsync;

  @override
  Widget build(BuildContext context) {
    return _Section(
      label: 'System health',
      icon: Icons.monitor_heart_outlined,
      child: healthAsync.when(
        loading: () => const _CardLoading(),
        error: (e, _) => _CardError(message: AppErrorMapper.from(e).message),
        data: (h) {
          if (h == null) {
            return const _EmptyCard(message: 'Health status unavailable.');
          }
          return Wrap(
            spacing: AuraSpace.s10,
            runSpacing: AuraSpace.s10,
            children: [
              _HealthChip(label: 'API', status: h.apiStatus, snap: h),
              _HealthChip(label: 'Database', status: h.dbStatus, snap: h),
              _HealthChip(label: 'Email', status: h.emailStatus, snap: h),
              _HealthChip(label: 'Push', status: h.pushStatus, snap: h),
              _HealthChip(label: 'Realtime', status: h.realtimeStatus, snap: h),
            ],
          );
        },
      ),
    );
  }
}

class _HealthChip extends StatelessWidget {
  const _HealthChip({
    required this.label,
    required this.status,
    required this.snap,
  });

  final String label;
  final String status;
  final AdminHealthSnapshot snap;

  @override
  Widget build(BuildContext context) {
    final ok = snap.isOk(status);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AuraSpace.s12,
        vertical: AuraSpace.s8,
      ),
      decoration: BoxDecoration(
        color: ok ? AuraSurface.accentSoft : AuraSurface.dangerBg,
        borderRadius: BorderRadius.circular(AuraRadius.pill),
        border: Border.all(
          color: ok
              ? AuraSurface.accent.withValues(alpha: 0.3)
              : AuraSurface.dangerInk.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: ok ? AuraSurface.accentText : AuraSurface.dangerInk,
            ),
          ),
          const SizedBox(width: AuraSpace.s6),
          Text(
            '$label · $status',
            style: AuraText.micro.copyWith(
              color: ok ? AuraSurface.accentText : AuraSurface.dangerInk,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// QUICK ACTIONS
// ─────────────────────────────────────────────────────────────────────────────

class _QuickActionsPanel extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return _Section(
      label: 'Content',
      icon: Icons.campaign_outlined,
      child: _ModuleList(modules: [
        _ModuleTile(
          icon: Icons.campaign_outlined,
          title: 'Announcements',
          description: 'Browse and manage platform-wide announcements',
          onTap: () => context.go('/announcements'),
        ),
        _ModuleTile(
          icon: Icons.add_box_outlined,
          title: 'New announcement',
          description: 'Draft and publish a new platform notice',
          onTap: () => context.go('/announcements/create'),
        ),
        _ModuleTile(
          icon: Icons.mail_outline,
          title: 'Communications center',
          description: 'Newsletters, digests, AI drafts, and campaign approvals',
          onTap: () => context.go('/admin/communications'),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// GOVERNANCE PANEL
// ─────────────────────────────────────────────────────────────────────────────

class _GovernancePanel extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return _Section(
      label: 'Governance',
      icon: Icons.shield_outlined,
      child: _ModuleList(modules: [
        _ModuleTile(
          icon: Icons.group_outlined,
          title: 'Users',
          description: 'Member accounts, roles, and status management',
          onTap: () => context.go('/admin/users'),
        ),
        _ModuleTile(
          icon: Icons.verified_user_outlined,
          title: 'Grants',
          description: 'View and manage admin grants, roles, and expiry',
          onTap: () => context.go('/admin/grants'),
        ),
        _ModuleTile(
          icon: Icons.history_rounded,
          title: 'Audit log',
          description: 'Admin action history and governance trail',
          onTap: () => context.go('/admin/audit-logs'),
        ),
        _ModuleTile(
          icon: Icons.apartment_outlined,
          title: 'Institutions',
          description: 'List verified, pending, and suspended institutions',
          onTap: () => context.go('/admin/institutions'),
        ),
        _ModuleTile(
          icon: Icons.domain_outlined,
          title: 'Institution domains',
          description: 'Review and approve institution domain requests',
          onTap: () => context.go('/admin/institution-domains'),
        ),
        _ModuleTile(
          icon: Icons.rate_review_outlined,
          title: 'Review queue',
          description: 'Approve or reject institution and membership requests',
          onTap: () => context.go('/admin/review-queue'),
        ),
        _ModuleTile(
          icon: Icons.shield_outlined,
          title: 'Moderation',
          description: 'Review reports, take enforcement actions, track outcomes',
          onTap: () => context.go('/admin/moderation'),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SYSTEM PANEL
// ─────────────────────────────────────────────────────────────────────────────

class _SystemPanel extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return _Section(
      label: 'System',
      icon: Icons.tune_outlined,
      child: _ModuleList(modules: [
        _ModuleTile(
          icon: Icons.tune_outlined,
          title: 'Settings',
          description: 'Platform configuration and system settings',
          onTap: () => context.go('/admin/settings'),
        ),
        _ModuleTile(
          icon: Icons.flag_outlined,
          title: 'Feature flags',
          description: 'Enable or disable platform features',
          onTap: () => context.go('/admin/feature-flags'),
        ),
        _ModuleTile(
          icon: Icons.policy_outlined,
          title: 'Policies',
          description: 'Configure institution, security, and feature policies',
          onTap: () => context.go('/admin/policies'),
        ),
        _ModuleTile(
          icon: Icons.support_agent_outlined,
          title: 'Support console',
          description: 'View and manage admin support tickets and escalations',
          onTap: () => context.go('/admin/support'),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SHARED WIDGETS
// ─────────────────────────────────────────────────────────────────────────────

class _Section extends StatelessWidget {
  const _Section({
    required this.label,
    required this.icon,
    required this.child,
  });

  final String label;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: AuraSurface.faint),
            const SizedBox(width: AuraSpace.s6),
            Text(
              label.toUpperCase(),
              style: AuraText.label.copyWith(
                color: AuraSurface.faint,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
        const SizedBox(height: AuraSpace.s10),
        Container(
          decoration: BoxDecoration(
            color: AuraSurface.card,
            borderRadius: BorderRadius.circular(AuraRadius.card),
            border: Border.all(color: AuraSurface.divider),
          ),
          child: child,
        ),
      ],
    );
  }
}

class _ModuleList extends StatelessWidget {
  const _ModuleList({required this.modules});

  final List<_ModuleTile> modules;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < modules.length; i++) ...[
          modules[i],
          if (i < modules.length - 1)
            Container(
              height: 1,
              margin: const EdgeInsets.symmetric(horizontal: AuraSpace.s16),
              color: AuraSurface.divider,
            ),
        ],
      ],
    );
  }
}

class _ModuleTile extends StatelessWidget {
  const _ModuleTile({
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
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
                color: AuraSurface.accentSoft,
                borderRadius: BorderRadius.circular(AuraRadius.md),
                border: Border.all(
                  color: AuraSurface.accent.withValues(alpha: 0.2),
                ),
              ),
              child: Icon(icon, size: 20, color: AuraSurface.accentText),
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
            const Icon(
              Icons.chevron_right,
              size: 18,
              color: AuraSurface.faint,
            ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, this.muted = false, this.accent = false});

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

class _CardLoading extends StatelessWidget {
  const _CardLoading();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(AuraSpace.s16),
      child: AuraLoadingState(message: 'Loading…'),
    );
  }
}

class _CardError extends StatelessWidget {
  const _CardError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AuraSpace.s16),
      child: AuraErrorState(
        title: 'Could not load',
        body: message,
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AuraSpace.s16),
      child: Text(
        message,
        style: AuraText.small.copyWith(color: AuraSurface.faint),
      ),
    );
  }
}
