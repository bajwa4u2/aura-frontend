import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/session_providers.dart';
import '../../../core/ui/aura_platform_components.dart';
import '../../../core/ui/aura_radius.dart';
import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';
import '../../../core/ui/aura_text_block.dart';
import 'notification_permission_tile.dart';

class SecurityScreen extends ConsumerWidget {
  const SecurityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authed = ref.watch(isAuthedProvider);
    final emailVerifiedAsync = ref.watch(emailVerifiedProvider);

    if (!authed) {
      return AuraScaffold(
        showHeader: false,
        body: _centeredContent([
          _PremiumPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Sign in to continue', style: AuraText.title),
                const SizedBox(height: AuraSpace.s8),
                AuraTextBlock(
                  'You need to be signed in to view security settings.',
                  style: AuraText.body.copyWith(color: AuraSurface.muted),
                ),
                const SizedBox(height: AuraSpace.s16),
                Row(
                  children: [
                    AuraPrimaryButton(
                      label: 'Sign in',
                      onPressed: () => context.go('/login'),
                      icon: Icons.login_rounded,
                    ),
                    const SizedBox(width: AuraSpace.s10),
                    AuraGhostButton(
                      label: 'Back',
                      onPressed: () => context.go('/public'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ]),
      );
    }

    final emailStatusText = emailVerifiedAsync.when(
      data: (verified) => verified ? 'Verified' : 'Not verified',
      loading: () => 'Checking…',
      error: (_, __) => 'Unavailable',
    );

    final emailVerified = emailVerifiedAsync.maybeWhen(
      data: (v) => v,
      orElse: () => false,
    );

    return AuraScaffold(
      showHeader: false,
      body: _centeredContent([
        // ── Header ──────────────────────────────────────────────────────────
        _SecurityHeaderPanel(),

        // ── Security status ──────────────────────────────────────────────────
        _SecuritySection(
          icon: Icons.shield_outlined,
          title: 'Security',
          items: [
            _SecurityRow(
              title: 'Password',
              subtitle: 'Send a reset link to your email',
              leading: Icons.lock_outline,
              statusLabel: 'Change',
              statusStyle: _StatusStyle.neutral,
              onTap: () => context.go('/forgot-password'),
            ),
            _SecurityRow(
              title: 'Email verification',
              subtitle: emailVerified
                  ? 'Your email address is confirmed'
                  : 'Verify your email to secure your account',
              leading: Icons.verified_user_outlined,
              statusLabel: emailStatusText,
              statusStyle: emailVerified
                  ? _StatusStyle.good
                  : _StatusStyle.warn,
              onTap: () => context.go('/verify-pending'),
            ),
          ],
        ),

        // ── Sessions ─────────────────────────────────────────────────────────
        const _SecuritySection(
          icon: Icons.devices_outlined,
          title: 'Sessions',
          items: [
            _SecurityRow(
              title: 'This device',
              subtitle: 'Currently authenticated session',
              leading: Icons.computer_outlined,
              statusLabel: 'Active',
              statusStyle: _StatusStyle.good,
            ),
          ],
        ),

        // ── Browser notifications (web only) ─────────────────────────────────
        if (kIsWeb) const BrowserNotificationsSection(),

        // ── Danger zone ───────────────────────────────────────────────────────
        _DangerZonePanel(
          onDeleteAccount: () => context.go('/account-deletion'),
        ),
      ]),
    );
  }

  Widget _centeredContent(List<Widget> sections) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth < 600
            ? double.infinity
            : constraints.maxWidth < 980
                ? 760.0
                : 860.0;
        final hPad = constraints.maxWidth < 600
            ? 12.0
            : constraints.maxWidth < 980
                ? 24.0
                : 32.0;

        return Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: ListView.separated(
              padding: EdgeInsets.fromLTRB(hPad, 18, hPad, 28),
              itemCount: sections.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(height: AuraSpace.s24),
              itemBuilder: (_, i) => sections[i],
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SECURITY HEADER
// ─────────────────────────────────────────────────────────────────────────────

class _SecurityHeaderPanel extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A2235), Color(0xFF152030)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AuraRadius.xl),
        border: Border.all(
          color: AuraSurface.accent.withValues(alpha: 0.18),
        ),
      ),
      padding: const EdgeInsets.all(AuraSpace.s24),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AuraSurface.accentSoft,
              borderRadius: BorderRadius.circular(AuraRadius.lg),
              border: Border.all(
                color: AuraSurface.accent.withValues(alpha: 0.3),
              ),
            ),
            child: const Icon(
              Icons.security_outlined,
              size: 26,
              color: AuraSurface.accentText,
            ),
          ),
          const SizedBox(width: AuraSpace.s16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Account Security',
                  style: AuraText.title.copyWith(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: AuraSurface.ink,
                  ),
                ),
                const SizedBox(height: 4),
                AuraTextBlock(
                  'Manage your credentials, sessions, and account safety.',
                  style: AuraText.body.copyWith(
                    color: AuraSurface.muted,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SECURITY SECTION
// ─────────────────────────────────────────────────────────────────────────────

class _SecuritySection extends StatelessWidget {
  const _SecuritySection({
    required this.icon,
    required this.title,
    required this.items,
  });

  final IconData icon;
  final String title;
  final List<Widget> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: AuraSpace.s10),
          child: Row(
            children: [
              Icon(icon, size: 15, color: AuraSurface.muted),
              const SizedBox(width: AuraSpace.s8),
              Text(
                title,
                style: AuraText.muted.copyWith(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                ),
              ),
            ],
          ),
        ),
        _PremiumPanel(
          padding: EdgeInsets.zero,
          child: Column(
            children: _withDividers(items),
          ),
        ),
      ],
    );
  }

  List<Widget> _withDividers(List<Widget> children) {
    final out = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      out.add(children[i]);
      if (i != children.length - 1) {
        out.add(
          const Divider(height: 1, thickness: 1, color: AuraSurface.divider),
        );
      }
    }
    return out;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SECURITY ROW
// ─────────────────────────────────────────────────────────────────────────────

enum _StatusStyle { good, warn, danger, neutral }

class _SecurityRow extends StatelessWidget {
  const _SecurityRow({
    required this.title,
    this.subtitle,
    this.leading,
    this.statusLabel,
    this.statusStyle = _StatusStyle.neutral,
    this.onTap,
  });

  final String title;
  final String? subtitle;
  final IconData? leading;
  final String? statusLabel;
  final _StatusStyle statusStyle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final active = onTap != null;

    return MouseRegion(
      cursor: active ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AuraSpace.s16,
              vertical: AuraSpace.s14,
            ),
            child: Row(
              children: [
                if (leading != null) ...[
                  Icon(
                    leading,
                    size: 18,
                    color: active ? AuraSurface.ink : AuraSurface.muted,
                  ),
                  const SizedBox(width: AuraSpace.s12),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: AuraText.body.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AuraSurface.ink,
                        ),
                      ),
                      if (subtitle != null &&
                          subtitle!.trim().isNotEmpty) ...[
                        const SizedBox(height: 4),
                        AuraTextBlock(
                          subtitle!,
                          style: AuraText.small.copyWith(
                            color: AuraSurface.muted,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (statusLabel != null && statusLabel!.trim().isNotEmpty) ...[
                  const SizedBox(width: AuraSpace.s12),
                  _StatusBadge(
                    label: statusLabel!,
                    style: statusStyle,
                    showChevron: active,
                  ),
                ] else if (active) ...[
                  const SizedBox(width: AuraSpace.s8),
                  const Icon(
                    Icons.chevron_right,
                    size: 18,
                    color: AuraSurface.muted,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({
    required this.label,
    required this.style,
    this.showChevron = false,
  });

  final String label;
  final _StatusStyle style;
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    final (bg, ink) = switch (style) {
      _StatusStyle.good => (AuraSurface.goodBg, AuraSurface.goodInk),
      _StatusStyle.warn => (AuraSurface.warnBg, AuraSurface.warnInk),
      _StatusStyle.danger => (AuraSurface.dangerBg, AuraSurface.dangerInk),
      _StatusStyle.neutral => (AuraSurface.elevated, AuraSurface.muted),
    };

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AuraSpace.s10,
            vertical: 4,
          ),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(AuraRadius.pill),
            border: Border.all(
              color: ink.withValues(alpha: 0.22),
            ),
          ),
          child: Text(
            label,
            style: AuraText.small.copyWith(
              color: ink,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        if (showChevron) ...[
          const SizedBox(width: AuraSpace.s6),
          const Icon(
            Icons.chevron_right,
            size: 18,
            color: AuraSurface.muted,
          ),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DANGER ZONE
// ─────────────────────────────────────────────────────────────────────────────

class _DangerZonePanel extends StatelessWidget {
  const _DangerZonePanel({required this.onDeleteAccount});

  final VoidCallback onDeleteAccount;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: AuraSpace.s10),
          child: Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                size: 15,
                color: AuraSurface.dangerInk.withValues(alpha: 0.7),
              ),
              const SizedBox(width: AuraSpace.s8),
              Text(
                'Danger zone',
                style: AuraText.muted.copyWith(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                  color: AuraSurface.dangerInk.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: AuraSurface.dangerBg.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(AuraRadius.xl),
            border: Border.all(
              color: AuraSurface.dangerInk.withValues(alpha: 0.18),
            ),
          ),
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(AuraRadius.xl),
                onTap: onDeleteAccount,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AuraSpace.s16,
                    vertical: AuraSpace.s14,
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.delete_outline,
                        size: 18,
                        color: AuraSurface.dangerInk,
                      ),
                      const SizedBox(width: AuraSpace.s12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Delete account',
                              style: AuraText.body.copyWith(
                                fontWeight: FontWeight.w700,
                                color: AuraSurface.dangerInk,
                              ),
                            ),
                            const SizedBox(height: 4),
                            AuraTextBlock(
                              'Permanently remove your account and all its data.',
                              style: AuraText.small.copyWith(
                                color: AuraSurface.dangerInk
                                    .withValues(alpha: 0.7),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right,
                        size: 18,
                        color: AuraSurface.dangerInk,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PREMIUM PANEL CONTAINER
// ─────────────────────────────────────────────────────────────────────────────

class _PremiumPanel extends StatelessWidget {
  const _PremiumPanel({required this.child, this.padding});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AuraSurface.card,
        borderRadius: BorderRadius.circular(AuraRadius.xl),
        border: Border.all(color: AuraSurface.divider),
      ),
      padding: padding ?? const EdgeInsets.all(AuraSpace.s20),
      child: child,
    );
  }
}
