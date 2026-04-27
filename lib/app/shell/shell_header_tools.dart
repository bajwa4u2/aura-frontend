import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/auth_providers.dart';
import '../../core/auth/session_providers.dart';
import '../../core/net/dio_provider.dart';
import '../../core/ui/aura_radius.dart';
import '../../core/ui/aura_space.dart';
import '../../core/ui/aura_surface.dart';
import '../../core/ui/aura_text.dart';
import '../../features/updates/providers.dart';
import '../route_targets.dart';

// ─────────────────────────────────────────────────────────────────────────────
// HEADER TOOLS (ICON STRIP)
// ─────────────────────────────────────────────────────────────────────────────

class ShellHeaderTools extends ConsumerStatefulWidget {
  const ShellHeaderTools({
    super.key,
    required this.isTablet,
    required this.isDesktop,
    required this.searchPath,
    required this.activityPath,
    required this.invitePath,
    this.liveRoomsPath,
  });

  final bool isTablet;
  final bool isDesktop;
  final String searchPath;
  final String activityPath;
  final String invitePath;
  final String? liveRoomsPath;

  @override
  ConsumerState<ShellHeaderTools> createState() => _ShellHeaderToolsState();
}

class _ShellHeaderToolsState extends ConsumerState<ShellHeaderTools> {
  bool _busyLogout = false;

  Future<void> _handleAccountAction(String value) async {
    switch (value) {
      case 'profile':
        context.go('/me');
        return;
      case 'edit_profile':
        context.go('/me/edit');
        return;
      case 'security':
        context.go('/security');
        return;
      case 'logout':
        await _logout();
        return;
    }
  }

  Future<void> _logout() async {
    if (_busyLogout) return;
    setState(() => _busyLogout = true);

    final currentPath = GoRouterState.of(context).uri.path;
    final returnPath = shouldUseMemberShellForAuthed(currentPath)
        ? currentPath
        : '/public';

    final container = ProviderScope.containerOf(context, listen: false);
    final dio = container.read(dioProvider);

    try {
      await dio.post('/auth/logout');
    } catch (_) {}

    try {
      await container.read(tokenStoreProvider).clear();
      container.invalidate(emailVerifiedProvider);
      container.invalidate(authStatusProvider);
      container.invalidate(isAuthedProvider);
    } finally {
      if (mounted) context.go(returnPath);
      if (mounted) setState(() => _busyLogout = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount = ref.watch(notificationsUnreadCountProvider);
    const gap = SizedBox(width: AuraSpace.s6);

    final tools = <Widget>[
      _HeaderIconBtn(
        icon: Icons.search_rounded,
        tooltip: 'Search',
        onTap: () => context.push(widget.searchPath),
      ),
      gap,
      _HeaderActivityBtn(
        unreadCount: unreadCount,
        onTap: () => context.push(widget.activityPath),
      ),
      if ((widget.liveRoomsPath ?? '').isNotEmpty) ...[
        gap,
        _HeaderIconBtn(
          icon: Icons.videocam_outlined,
          tooltip: 'Live rooms',
          onTap: () => context.push(widget.liveRoomsPath!),
        ),
      ],
      gap,
      _HeaderIconBtn(
        icon: Icons.outbound_outlined,
        tooltip: 'Invite',
        onTap: () => context.push(widget.invitePath),
      ),
      gap,
      _HeaderAccountBtn(
        busy: _busyLogout,
        onSelected: (v) => unawaited(_handleAccountAction(v)),
      ),
    ];

    if (widget.isTablet) tools.add(const SizedBox(width: AuraSpace.s4));
    return Row(mainAxisSize: MainAxisSize.min, children: tools);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HEADER BUTTON ATOMS
// ─────────────────────────────────────────────────────────────────────────────

class _HeaderIconBtn extends StatelessWidget {
  const _HeaderIconBtn({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AuraRadius.pill),
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: AuraSurface.subtle,
            borderRadius: BorderRadius.circular(AuraRadius.pill),
            border: Border.all(color: AuraSurface.divider),
          ),
          child: Icon(icon, size: 18, color: AuraSurface.muted),
        ),
      ),
    );
  }
}

class _HeaderActivityBtn extends StatelessWidget {
  const _HeaderActivityBtn({
    required this.unreadCount,
    required this.onTap,
  });

  final int unreadCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Activity',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AuraRadius.pill),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AuraSurface.subtle,
                borderRadius: BorderRadius.circular(AuraRadius.pill),
                border: Border.all(color: AuraSurface.divider),
              ),
              child: const Icon(Icons.notifications_none_rounded,
                  size: 18, color: AuraSurface.muted),
            ),
            if (unreadCount > 0)
              Positioned(
                right: 0,
                top: 0,
                child: _UnreadDot(count: unreadCount),
              ),
          ],
        ),
      ),
    );
  }
}

class _UnreadDot extends StatelessWidget {
  const _UnreadDot({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final label = count > 99 ? '99+' : '$count';
    return Container(
      constraints: const BoxConstraints(minWidth: 17, minHeight: 17),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: AuraSurface.accent,
        borderRadius: BorderRadius.circular(AuraRadius.pill),
        border: Border.all(color: AuraSurface.page, width: 1.5),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: AuraText.micro.copyWith(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _HeaderAccountBtn extends StatelessWidget {
  const _HeaderAccountBtn({required this.busy, required this.onSelected});

  final bool busy;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return AbsorbPointer(
      absorbing: busy,
      child: PopupMenuButton<String>(
        tooltip: 'Account',
        onSelected: onSelected,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AuraRadius.r16),
          side: const BorderSide(color: AuraSurface.divider),
        ),
        color: AuraSurface.overlay,
        itemBuilder: (context) => [
          _menuItem('profile', Icons.person_outline_rounded, 'Profile'),
          _menuItem('edit_profile', Icons.edit_outlined, 'Edit profile'),
          _menuItem('security', Icons.shield_outlined, 'Security'),
          const PopupMenuDivider(),
          _menuItem(
            'logout',
            busy ? Icons.hourglass_empty : Icons.logout_rounded,
            busy ? 'Signing out…' : 'Sign out',
            danger: true,
          ),
        ],
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: AuraSurface.subtle,
            borderRadius: BorderRadius.circular(AuraRadius.pill),
            border: Border.all(color: AuraSurface.divider),
          ),
          child: busy
              ? const Center(
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AuraSurface.muted,
                    ),
                  ),
                )
              : const Icon(Icons.person_outline_rounded,
                  size: 18, color: AuraSurface.muted),
        ),
      ),
    );
  }

  PopupMenuItem<String> _menuItem(
    String value,
    IconData icon,
    String label, {
    bool danger = false,
  }) {
    final color = danger ? AuraSurface.dangerInk : AuraSurface.ink;
    return PopupMenuItem<String>(
      value: value,
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: AuraSpace.s10),
          Text(
            label,
            style: AuraText.small.copyWith(
                color: color, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
