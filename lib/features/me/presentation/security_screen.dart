import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/session_providers.dart';
import '../../../core/ui/aura_card.dart' as ui;
import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';

class SecurityScreen extends ConsumerWidget {
  const SecurityScreen({super.key});

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AuraSpace.s10),
      child: Text(title, style: AuraText.title),
    );
  }

  List<Widget> _withDividers(List<Widget> children) {
    final out = <Widget>[];

    for (var i = 0; i < children.length; i++) {
      out.add(children[i]);
      if (i != children.length - 1) {
        out.add(const Divider(
          height: 1,
          thickness: 1,
          color: AuraSurface.divider,
        ));
      }
    }

    return out;
  }

  Widget _section({
    required String title,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(title),
        ui.AuraCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: _withDividers(children),
          ),
        ),
      ],
    );
  }

  Widget _row({
    required String title,
    String? subtitle,
    String? trailing,
    IconData? leading,
    VoidCallback? onTap,
    bool danger = false,
  }) {
    final active = onTap != null;
    final titleColor = danger ? Colors.redAccent : AuraSurface.ink;
    final iconColor = danger
        ? Colors.redAccent
        : active
            ? AuraSurface.ink
            : AuraSurface.muted;

    return Material(
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
                  color: iconColor,
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
                        color: titleColor,
                      ),
                    ),
                    if (subtitle != null && subtitle.trim().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: AuraText.small.copyWith(
                          color: AuraSurface.muted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null && trailing.trim().isNotEmpty) ...[
                Text(
                  trailing,
                  style: AuraText.small.copyWith(
                    color: AuraSurface.muted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: AuraSpace.s10),
              ],
              Icon(
                Icons.chevron_right,
                size: 18,
                color: active ? AuraSurface.muted : AuraSurface.divider,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _cardList(List<Widget> children) {
    final items = <Widget>[];

    for (var i = 0; i < children.length; i++) {
      items.add(children[i]);
      if (i != children.length - 1) {
        items.add(const SizedBox(height: 32));
      }
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;

        double horizontalPadding;
        double maxWidth;

        if (width < 600) {
          horizontalPadding = 12;
          maxWidth = double.infinity;
        } else if (width < 980) {
          horizontalPadding = 24;
          maxWidth = 760;
        } else {
          horizontalPadding = 32;
          maxWidth = 860;
        }

        return Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                18,
                horizontalPadding,
                28,
              ),
              children: items,
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authed = ref.watch(isAuthedProvider);
    final emailVerifiedAsync = ref.watch(emailVerifiedProvider);

    if (!authed) {
      return AuraScaffold(
        showHeader: false,
        body: _cardList([
          ui.AuraCard(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Sign in', style: AuraText.title),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      FilledButton(
                        onPressed: () => context.go('/login'),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                        child: const Text('Sign in'),
                      ),
                      OutlinedButton(
                        onPressed: () => context.go('/public'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                        child: const Text('Back'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ]),
      );
    }

    final emailStatusText = emailVerifiedAsync.when(
      data: (verified) => verified ? 'Verified' : 'Not verified',
      loading: () => 'Checking',
      error: (_, __) => 'Unavailable',
    );

    return AuraScaffold(
      showHeader: false,
      body: _cardList([
        _section(
          title: 'Security',
          children: [
            _row(
              title: 'Change password',
              subtitle: 'Send a reset link to your email',
              leading: Icons.lock_outline,
              onTap: () => context.go('/forgot-password'),
            ),
            _row(
              title: 'Email status',
              trailing: emailStatusText,
              leading: Icons.verified_user_outlined,
              onTap: () => context.go('/verify-pending'),
            ),
          ],
        ),
        _section(
          title: 'Sessions',
          children: [
            _row(
              title: 'This device',
              trailing: 'Active',
              leading: Icons.devices_outlined,
            ),
          ],
        ),
        _section(
          title: 'Account',
          children: [
            _row(
              title: 'Account deletion',
              subtitle: 'Permanently remove your account',
              leading: Icons.delete_outline,
              danger: true,
              onTap: () => context.go('/account-deletion'),
            ),
          ],
        ),
      ]),
    );
  }
}
