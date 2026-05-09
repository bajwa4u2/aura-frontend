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
import '../../core/interactions/notifications_repository.dart';
import '../../features/realtime/application/realtime_providers.dart';
import '../../features/realtime/domain/realtime_enums.dart';
import '../../features/realtime/domain/realtime_models.dart';
import '../route_targets.dart';

// Cached current-user profile for header avatar. Delegates to the canonical
// `authMeDataProvider` so /auth/me is fetched exactly once per session — this
// previously duplicated the call to /users/me from a separate provider.
final _shellMeProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  return ref.watch(authMeDataProvider.future);
});

// ─────────────────────────────────────────────────────────────────────────────
// HEADER TOOLS (ICON STRIP)
// ─────────────────────────────────────────────────────────────────────────────

class ShellHeaderTools extends ConsumerStatefulWidget {
  const ShellHeaderTools({
    super.key,
    required this.isTablet,
    required this.isDesktop,
    this.searchPath,
    this.activityPath,
    this.invitePath,
    this.showLive = true,
  });

  final bool isTablet;
  final bool isDesktop;

  /// When null the search button is hidden. Member shell passes the global
  /// `/search` route; institution shell currently passes null because there
  /// is no institution-scoped search surface yet — the global search would
  /// otherwise leak member content into institution context.
  final String? searchPath;

  /// When null the activity (notifications) bell is hidden.
  final String? activityPath;

  /// When null the invite icon is hidden.
  final String? invitePath;

  /// When false the Live pill is hidden.
  final bool showLive;

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
      case 'preferences':
        context.go('/me/settings/communications');
        return;
      case 'settings':
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
    final unreadCount = ref
        .watch(unreadNotificationCountProvider)
        .maybeWhen(data: (c) => c, orElse: () => 0);
    final me = ref
        .watch(_shellMeProvider)
        .maybeWhen(data: (d) => d, orElse: () => <String, dynamic>{});
    const gap = SizedBox(width: AuraSpace.s6);

    final tools = <Widget>[
      if (widget.searchPath != null)
        _HeaderIconBtn(
          icon: Icons.search_rounded,
          tooltip: 'Search',
          onTap: () => context.push(widget.searchPath!),
        ),
      if (widget.activityPath != null) ...[
        gap,
        _HeaderActivityBtn(
          unreadCount: unreadCount,
          onTap: () => context.push(widget.activityPath!),
        ),
      ],
      if (widget.showLive) ...[
        gap,
        const _HeaderLiveBtn(),
      ],
      if (widget.invitePath != null) ...[
        gap,
        _HeaderIconBtn(
          icon: Icons.outbound_outlined,
          tooltip: 'Invite',
          onTap: () => context.push(widget.invitePath!),
        ),
      ],
      gap,
      _HeaderAccountBtn(
        busy: _busyLogout,
        me: me,
        onSelected: (v) => unawaited(_handleAccountAction(v)),
      ),
    ];

    if (widget.isTablet) tools.add(const SizedBox(width: AuraSpace.s4));
    return Row(mainAxisSize: MainAxisSize.min, children: tools);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// LIVE BUTTON — replaces "Live rooms" icon; shows discoverable Space/Room/
// Institution sessions in a capped (max 3) popup, deduplicated, no 1:1 DMs.
// ─────────────────────────────────────────────────────────────────────────────

class _HeaderLiveBtn extends ConsumerWidget {
  const _HeaderLiveBtn();

  String _sessionLabel(RealtimeSession s) {
    final name = s.contextName ?? s.title;
    switch (s.surfaceType) {
      case RealtimeSurfaceType.space:
        return name != null ? 'in $name' : 'Space';
      case RealtimeSurfaceType.room:
        return name ?? 'Live room';
      case RealtimeSurfaceType.institution:
        return name != null ? '$name · Institution' : 'Institution';
      default:
        return name ?? 'Live session';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessions = ref
        .watch(discoverableLiveSessionsProvider)
        .maybeWhen(data: (s) => s, orElse: () => <RealtimeSession>[]);
    final hasLive = sessions.isNotEmpty;

    return PopupMenuButton<String>(
      tooltip: 'Live',
      offset: const Offset(0, 44),
      color: AuraSurface.overlay,
      constraints: const BoxConstraints(minWidth: 240, maxWidth: 300),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AuraRadius.r16),
        side: const BorderSide(color: AuraSurface.divider),
      ),
      itemBuilder: (_) {
        if (sessions.isEmpty) {
          return [
            PopupMenuItem<String>(
              enabled: false,
              child: Text(
                'No live sessions right now',
                style: AuraText.small.copyWith(color: AuraSurface.muted),
              ),
            ),
          ];
        }
        return [
          ...sessions.map(
            (s) => PopupMenuItem<String>(
              value: s.id,
              child: _LiveSessionMenuTile(label: _sessionLabel(s), kind: s.kind),
            ),
          ),
          const PopupMenuDivider(),
          PopupMenuItem<String>(
            value: '__open',
            child: Row(
              children: [
                const Icon(Icons.open_in_full_rounded,
                    size: 14, color: AuraSurface.muted),
                const SizedBox(width: AuraSpace.s8),
                Text(
                  'Open Live',
                  style: AuraText.small.copyWith(color: AuraSurface.muted),
                ),
              ],
            ),
          ),
        ];
      },
      onSelected: (value) {
        if (value == '__open') {
          context.push('/realtime');
        } else {
          context.go('/realtime/$value');
        }
      },
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: AuraSpace.s12),
        decoration: BoxDecoration(
          color: AuraSurface.subtle,
          borderRadius: BorderRadius.circular(AuraRadius.pill),
          border: Border.all(
            color: hasLive
                ? AuraSurface.accent.withValues(alpha: 0.45)
                : AuraSurface.divider,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: hasLive
                    ? const Color(0xFF4ADE80)
                    : AuraSurface.faint,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: AuraSpace.s6),
            Text(
              'Live',
              style: AuraText.small.copyWith(
                fontWeight: FontWeight.w700,
                color: hasLive ? AuraSurface.ink : AuraSurface.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LiveSessionMenuTile extends StatelessWidget {
  const _LiveSessionMenuTile({required this.label, required this.kind});

  final String label;
  final String kind;

  @override
  Widget build(BuildContext context) {
    final isVideo = kind.toUpperCase() == 'VIDEO';
    return Row(
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: const BoxDecoration(
            color: Color(0xFF4ADE80),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: AuraSpace.s8),
        Icon(
          isVideo ? Icons.videocam_outlined : Icons.mic_outlined,
          size: 13,
          color: AuraSurface.muted,
        ),
        const SizedBox(width: AuraSpace.s6),
        Expanded(
          child: Text(
            label,
            style: AuraText.small.copyWith(
              color: AuraSurface.ink,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: AuraSpace.s8),
        Text(
          'Join',
          style: AuraText.label.copyWith(
            color: AuraSurface.accentText,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
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
  const _HeaderAccountBtn({
    required this.busy,
    required this.me,
    required this.onSelected,
  });

  final bool busy;
  final Map<String, dynamic> me;
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
          _menuItem('preferences', Icons.tune_outlined, 'Preferences'),
          _menuItem('settings', Icons.shield_outlined, 'Settings'),
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
          child: ClipOval(child: _avatarContent()),
        ),
      ),
    );
  }

  Widget _avatarContent() {
    if (busy) {
      return const Center(
        child: SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AuraSurface.muted,
          ),
        ),
      );
    }

    final avatarUrl = _pickMeString(
      me,
      const ['avatarUrl', 'photoUrl', 'imageUrl'],
    );
    if (avatarUrl.isNotEmpty) {
      return Image.network(
        avatarUrl,
        width: 38,
        height: 38,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _initialsOrIcon(),
      );
    }

    return _initialsOrIcon();
  }

  Widget _initialsOrIcon() {
    final name = _pickMeString(
      me,
      const ['displayName', 'name', 'handle'],
    );
    if (name.isNotEmpty) {
      final initial = name.trim().isNotEmpty
          ? name.trim().substring(0, 1).toUpperCase()
          : '';
      if (initial.isNotEmpty) {
        return Container(
          color: AuraSurface.accentSoft,
          alignment: Alignment.center,
          child: Text(
            initial,
            style: AuraText.small.copyWith(
              color: AuraSurface.accentText,
              fontWeight: FontWeight.w800,
            ),
          ),
        );
      }
    }
    return const Icon(
      Icons.person_outline_rounded,
      size: 18,
      color: AuraSurface.muted,
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
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

String _pickMeString(Map<String, dynamic> map, List<String> keys) {
  for (final key in keys) {
    final value = (map[key] ?? '').toString().trim();
    if (value.isNotEmpty) return value;
  }
  return '';
}
