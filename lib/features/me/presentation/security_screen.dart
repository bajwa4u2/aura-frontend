import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/session_providers.dart';
import '../../../core/ui/aura_platform_components.dart';
import '../../../core/ui/aura_radius.dart';
import '../../../core/ui/aura_scaffold.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/substrate_chip.dart';
import '../../../core/ui/aura_surface.dart';
import '../../../core/ui/aura_text.dart';
import '../../../core/ui/aura_text_block.dart';
import '../../../core/auth/trusted_device_store.dart';
import '../../auth/auth_repository.dart';
import 'notification_permission_tile.dart';

// ── Providers ────────────────────────────────────────────────────────────────

final _sessionsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final repo = ref.watch(authRepositoryProvider);
  return repo.listSessions();
});

final _trustedDevicesProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final repo = ref.watch(authRepositoryProvider);
  return repo.listTrustedDevices();
});

final _loginActivityProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final repo = ref.watch(authRepositoryProvider);
  return repo.listLoginActivity();
});

class SecurityScreen extends ConsumerStatefulWidget {
  const SecurityScreen({super.key});

  @override
  ConsumerState<SecurityScreen> createState() => _SecurityScreenState();
}

class _SecurityScreenState extends ConsumerState<SecurityScreen> {
  bool _revokingAll = false;
  bool _historyExpanded = false;

  // ── Mutations ─────────────────────────────────────────────────────────────

  Future<void> _revokeSession(String sessionId) async {
    try {
      await ref.read(authRepositoryProvider).revokeSession(sessionId);
      ref.invalidate(_sessionsProvider);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  Future<void> _revokeOtherSessions() async {
    setState(() => _revokingAll = true);
    try {
      await ref.read(authRepositoryProvider).revokeOtherSessions();
      ref.invalidate(_sessionsProvider);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _revokingAll = false);
    }
  }

  Future<void> _revokeDevice(String deviceId) async {
    try {
      await ref.read(authRepositoryProvider).revokeTrustedDevice(deviceId);
      await TrustedDeviceStore.remove();
      ref.invalidate(_trustedDevicesProvider);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  Future<void> _renameDevice(String deviceId, String currentName) async {
    final ctrl = TextEditingController(text: currentName);
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename device'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Device name'),
          textInputAction: TextInputAction.done,
          onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    ctrl.dispose();

    if (newName == null || newName == currentName) return;

    try {
      await ref
          .read(authRepositoryProvider)
          .renameTrustedDevice(deviceId, newName);
      ref.invalidate(_trustedDevicesProvider);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  Future<void> _showDeviceOptions(String deviceId, String displayName) async {
    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(displayName.isNotEmpty ? displayName : 'Trusted device'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, 'rename'),
            child: const Text('Rename'),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, 'revoke'),
            child: const Text(
              'Revoke',
              style: TextStyle(color: AuraSurface.coRose),
            ),
          ),
        ],
      ),
    );

    if (!mounted) return;
    if (choice == 'rename') {
      await _renameDevice(deviceId, displayName);
    } else if (choice == 'revoke') {
      await _revokeDevice(deviceId);
    }
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final authed = ref.watch(isAuthedProvider);
    final emailVerifiedAsync = ref.watch(emailVerifiedProvider);
    final sessionsAsync = ref.watch(_sessionsProvider);
    final devicesAsync = ref.watch(_trustedDevicesProvider);
    final activityAsync = ref.watch(_loginActivityProvider);

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
      data: (verified) => (verified ?? false) ? 'Verified' : 'Not verified',
      loading: () => 'Checking…',
      error: (_, __) => 'Unavailable',
    );

    final bool emailVerified = emailVerifiedAsync.maybeWhen(
      data: (v) => v ?? false,
      orElse: () => false,
    );

    // Classify the session list once per build into the four buckets the
    // section structure renders.
    final classified = sessionsAsync.maybeWhen(
      data: (raw) => _classifySessions(raw),
      orElse: () => const _ClassifiedSessions.empty(),
    );

    return AuraScaffold(
      showHeader: false,
      body: _centeredContent([
        const _SecurityHeaderPanel(),

        _SecuritySection(
          icon: Icons.shield_outlined,
          title: 'Account security',
          items: [
            _SecurityRow(
              title: 'Password',
              subtitle: 'Change your current password',
              leading: Icons.lock_outline,
              statusLabel: 'Change',
              statusStyle: _StatusStyle.neutral,
              onTap: () => context.go('/change-password'),
            ),
            _SecurityRow(
              title: 'Email verification',
              subtitle: emailVerified
                  ? 'Your email address is confirmed'
                  : 'Verify your email to secure your account',
              leading: Icons.verified_user_outlined,
              statusLabel: emailStatusText,
              statusStyle: emailVerified ? _StatusStyle.good : _StatusStyle.warn,
              onTap: () => context.go('/verify-pending'),
            ),
          ],
        ),

        // ── 1. Current session — strongest visual priority ────────────────
        sessionsAsync.when(
          loading: () => const _SectionedPanel(
            title: 'This device',
            subtitle: 'Loading the session you are using now…',
            child: _LoadingRow(),
          ),
          error: (_, __) => const _SectionedPanel(
            title: 'This device',
            subtitle: 'Could not load your current session.',
            child: _ErrorRow(),
          ),
          data: (_) {
            final current = classified.current;
            if (current == null) {
              return const SizedBox.shrink();
            }
            return _CurrentSessionPanel(session: current);
          },
        ),

        // ── 2. Other active sessions ──────────────────────────────────────
        _SecuritySection(
          icon: Icons.devices_outlined,
          title: 'Other active sessions',
          items: [
            ...sessionsAsync.when(
              loading: () => <Widget>[const _LoadingRow()],
              error: (_, __) => <Widget>[const _ErrorRow()],
              data: (_) {
                if (classified.otherActive.isEmpty) {
                  return <Widget>[
                    const _SecurityRow(
                      title: 'No other active sessions',
                      subtitle:
                          'You\'re only signed in on this device right now.',
                      leading: Icons.check_circle_outline,
                      statusStyle: _StatusStyle.good,
                    ),
                  ];
                }
                return classified.otherActive
                    .map<Widget>(
                      (s) => _SessionRow(
                        session: s,
                        onRevoke: () => _revokeSession(s.id),
                      ),
                    )
                    .toList();
              },
            ),
            if (classified.otherActive.isNotEmpty)
              _SecurityRow(
                title: _revokingAll
                    ? 'Signing out…'
                    : 'Sign out of all other sessions',
                subtitle:
                    'Revokes every active session except the one on this device.',
                leading: Icons.logout_rounded,
                statusLabel: 'Sign out all',
                statusStyle: _StatusStyle.warn,
                onTap: _revokingAll ? null : _revokeOtherSessions,
              ),
          ],
        ),

        // ── 3. Trusted devices ────────────────────────────────────────────
        _SecuritySection(
          icon: Icons.phonelink_lock_outlined,
          title: 'Trusted devices',
          subtitle:
              'Skip the email code on devices you\'ve approved long-term.',
          items: devicesAsync.when(
            loading: () => <Widget>[const _LoadingRow()],
            error: (_, __) => <Widget>[const _ErrorRow()],
            data: (devices) {
              if (devices.isEmpty) {
                return <Widget>[
                  const _SecurityRow(
                    title: 'No trusted devices',
                    subtitle:
                        'On next sign-in, choose "Trust this device" to add one.',
                    leading: Icons.phonelink_outlined,
                    statusStyle: _StatusStyle.neutral,
                  ),
                ];
              }
              return devices.map<Widget>((d) {
                final name =
                    (d['deviceName'] ?? d['userAgentHint'] ?? 'Unknown device')
                        .toString();
                final hint = (d['ipHint'] ?? '').toString();
                return _SecurityRow(
                  title: name,
                  subtitle: hint.isNotEmpty ? hint : null,
                  leading: Icons.phonelink_lock_outlined,
                  statusLabel: 'Options',
                  statusStyle: _StatusStyle.neutral,
                  onTap: () => _showDeviceOptions(d['id'].toString(), name),
                );
              }).toList();
            },
          ),
        ),

        // ── 4. History (collapsed by default) ─────────────────────────────
        _SessionHistoryPanel(
          activityAsync: activityAsync,
          expanded: _historyExpanded,
          onToggle: () =>
              setState(() => _historyExpanded = !_historyExpanded),
        ),

        if (kIsWeb) const BrowserNotificationsSection(),

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
// SESSION MODEL
// ─────────────────────────────────────────────────────────────────────────────

/// Frontend-side projection of a row returned by `GET /v1/auth/sessions`.
/// We normalize the loose `Map<String, dynamic>` shape into something the
/// section renderers can rely on.
class _Session {
  const _Session({
    required this.id,
    required this.current,
    required this.label,
    required this.platform,
    required this.distribution,
    required this.appVersion,
    required this.ipHint,
    required this.createdAt,
    required this.lastSeenAt,
  });

  factory _Session.fromJson(Map<String, dynamic> m) {
    String s(dynamic v) => (v ?? '').toString();
    return _Session(
      id: s(m['id']),
      current: m['current'] == true,
      label: s(m['userAgentHint']).trim(),
      platform: s(m['clientPlatform']).trim().toLowerCase(),
      distribution: s(m['clientDistribution']).trim().toLowerCase(),
      appVersion: s(m['clientAppVersion']).trim(),
      ipHint: s(m['ipHint']).trim(),
      createdAt: _parseDate(m['createdAt']),
      lastSeenAt: _parseDate(m['lastSeenAt']),
    );
  }

  final String id;
  final bool current;
  final String label;
  final String platform;
  final String distribution;
  final String appVersion;
  final String ipHint;
  final DateTime? createdAt;
  final DateTime? lastSeenAt;

  /// Icon that best represents the device class.
  IconData get icon {
    switch (platform) {
      case 'web':
        return Icons.public_outlined;
      case 'windows':
      case 'macos':
      case 'linux':
        return Icons.laptop_mac_outlined;
      case 'ios':
        return Icons.phone_iphone_outlined;
      case 'android':
        return Icons.phone_android_outlined;
      default:
        if (distribution.contains('web')) return Icons.public_outlined;
        return Icons.devices_other_outlined;
    }
  }

  /// "12m ago" / "3h ago" / "2d ago" relative to now.
  String get lastSeenLabel {
    final t = lastSeenAt ?? createdAt;
    if (t == null) return '';
    final diff = DateTime.now().difference(t);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    final dt = t.toLocal();
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  static DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    final s = v.toString().trim();
    if (s.isEmpty) return null;
    return DateTime.tryParse(s);
  }
}

class _ClassifiedSessions {
  const _ClassifiedSessions({
    required this.current,
    required this.otherActive,
  });
  const _ClassifiedSessions.empty()
      : current = null,
        otherActive = const [];

  final _Session? current;
  final List<_Session> otherActive;
}

_ClassifiedSessions _classifySessions(List<Map<String, dynamic>> raw) {
  final sessions = raw.map(_Session.fromJson).toList();
  _Session? current;
  final others = <_Session>[];
  for (final s in sessions) {
    if (s.current && current == null) {
      current = s;
    } else {
      others.add(s);
    }
  }
  // Sort other active by last-seen, most recent first. Backend already
  // sorts but resorting here keeps the UX correct if backend order ever
  // changes.
  others.sort((a, b) {
    final at = a.lastSeenAt ?? a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    final bt = b.lastSeenAt ?? b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    return bt.compareTo(at);
  });
  return _ClassifiedSessions(current: current, otherActive: others);
}

// ─────────────────────────────────────────────────────────────────────────────
// CURRENT SESSION HERO
// ─────────────────────────────────────────────────────────────────────────────

class _CurrentSessionPanel extends StatelessWidget {
  const _CurrentSessionPanel({required this.session});

  final _Session session;

  @override
  Widget build(BuildContext context) {
    final label = session.label.isNotEmpty ? session.label : 'Aura';
    final ip = session.ipHint;
    final lastSeen = session.lastSeenLabel;
    final metaParts = <String>[
      if (ip.isNotEmpty) ip,
      if (lastSeen.isNotEmpty) 'Last active $lastSeen',
    ];

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A2A3A), Color(0xFF152030)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AuraRadius.xl),
        border: Border.all(
          color: AuraSurface.coVerdant.withValues(alpha: 0.28),
        ),
      ),
      padding: const EdgeInsets.all(AuraSpace.s20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: AuraSurface.coVerdant,
                  borderRadius: BorderRadius.circular(7),
                  boxShadow: [
                    BoxShadow(
                      color: AuraSurface.coVerdant.withValues(alpha: 0.45),
                      blurRadius: 10,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AuraSpace.s10),
              Text(
                'THIS DEVICE',
                style: AuraText.label.copyWith(
                  color: AuraSurface.coVerdant,
                  letterSpacing: 1.4,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: AuraSpace.s12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AuraSurface.accentSoft,
                  borderRadius: BorderRadius.circular(AuraRadius.md),
                ),
                child: Icon(session.icon, color: AuraSurface.accentText),
              ),
              const SizedBox(width: AuraSpace.s14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: AuraText.title.copyWith(fontSize: 18),
                    ),
                    if (metaParts.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        metaParts.join(' · '),
                        style: AuraText.small.copyWith(
                          color: AuraSurface.muted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// OTHER ACTIVE SESSION ROW
// ─────────────────────────────────────────────────────────────────────────────

class _SessionRow extends StatelessWidget {
  const _SessionRow({required this.session, required this.onRevoke});

  final _Session session;
  final VoidCallback onRevoke;

  @override
  Widget build(BuildContext context) {
    final label = session.label.isNotEmpty ? session.label : 'Unknown device';
    final ip = session.ipHint;
    final lastSeen = session.lastSeenLabel;
    final parts = <String>[
      if (ip.isNotEmpty) ip,
      if (lastSeen.isNotEmpty) lastSeen,
    ];
    return _SecurityRow(
      title: label,
      subtitle: parts.isNotEmpty ? parts.join(' · ') : null,
      leading: session.icon,
      statusLabel: 'Revoke',
      statusStyle: _StatusStyle.warn,
      onTap: onRevoke,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SESSION HISTORY (collapsed)
// ─────────────────────────────────────────────────────────────────────────────

class _SessionHistoryPanel extends StatelessWidget {
  const _SessionHistoryPanel({
    required this.activityAsync,
    required this.expanded,
    required this.onToggle,
  });

  final AsyncValue<List<Map<String, dynamic>>> activityAsync;
  final bool expanded;
  final VoidCallback onToggle;

  String _formatTime(String? isoString) {
    if (isoString == null || isoString.isEmpty) return '';
    try {
      final dt = DateTime.parse(isoString).toLocal();
      final diff = DateTime.now().difference(dt);
      if (diff.inSeconds < 60) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      if (diff.inDays < 7) return '${diff.inDays}d ago';
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final count = activityAsync.maybeWhen(
      data: (events) => events.length,
      orElse: () => 0,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: AuraSpace.s10),
          child: Row(
            children: [
              const Icon(
                Icons.history_outlined,
                size: 15,
                color: AuraSurface.muted,
              ),
              const SizedBox(width: AuraSpace.s8),
              Text(
                'Sign-in history',
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
            children: [
              _SecurityRow(
                title: expanded
                    ? 'Hide sign-in history'
                    : 'Show recent sign-ins',
                subtitle: count > 0
                    ? '$count recent events'
                    : 'No recent sign-in events',
                leading: expanded
                    ? Icons.expand_less_rounded
                    : Icons.expand_more_rounded,
                onTap: onToggle,
              ),
              if (expanded)
                ...activityAsync.when(
                  loading: () => <Widget>[const _LoadingRow()],
                  error: (_, __) => <Widget>[const _ErrorRow()],
                  data: (events) {
                    if (events.isEmpty) {
                      return <Widget>[
                        const _SecurityRow(
                          title: 'No sign-in events',
                          leading: Icons.history_outlined,
                          statusStyle: _StatusStyle.neutral,
                        ),
                      ];
                    }
                    return events.map<Widget>((e) {
                      final result = (e['result'] ?? '').toString();
                      final ua = (e['userAgentHint'] ?? '').toString();
                      final ip = (e['ipHint'] ?? '').toString();
                      final timeStr = _formatTime(e['createdAt']?.toString());
                      final sub = <String>[
                        if (ua.isNotEmpty) ua,
                        if (ip.isNotEmpty) ip,
                      ].join(' · ');

                      final (title, icon, style) = switch (result) {
                        'SUCCESS' => (
                            'Successful sign-in',
                            Icons.login_rounded,
                            _StatusStyle.good
                          ),
                        'TRUSTED_DEVICE' => (
                            'Sign-in via trusted device',
                            Icons.phonelink_lock_outlined,
                            _StatusStyle.good
                          ),
                        'FAILED_PASSWORD' => (
                            'Failed password',
                            Icons.lock_outline,
                            _StatusStyle.warn
                          ),
                        'FAILED_CODE' => (
                            'Failed code attempt',
                            Icons.pin_outlined,
                            _StatusStyle.warn
                          ),
                        _ => (
                            result,
                            Icons.history_outlined,
                            _StatusStyle.neutral,
                          ),
                      };

                      return _SecurityRow(
                        title: title,
                        subtitle: sub.isNotEmpty ? sub : null,
                        leading: icon,
                        statusLabel: timeStr,
                        statusStyle: style,
                      );
                    }).toList();
                  },
                ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SECURITY HEADER
// ─────────────────────────────────────────────────────────────────────────────

class _SecurityHeaderPanel extends StatelessWidget {
  const _SecurityHeaderPanel();
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
                  'Account security',
                  style: AuraText.title.copyWith(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: AuraSurface.ink,
                  ),
                ),
                const SizedBox(height: 4),
                AuraTextBlock(
                  'Sessions, trusted devices, and account safety.',
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
// LOOSE PRIMITIVES
// ─────────────────────────────────────────────────────────────────────────────

class _SecuritySection extends StatelessWidget {
  const _SecuritySection({
    required this.icon,
    required this.title,
    required this.items,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
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
        if ((subtitle ?? '').isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: AuraSpace.s10),
            child: Text(
              subtitle!,
              style: AuraText.small.copyWith(color: AuraSurface.muted),
            ),
          ),
        _PremiumPanel(
          padding: EdgeInsets.zero,
          child: Column(children: _withDividers(items)),
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

class _SectionedPanel extends StatelessWidget {
  const _SectionedPanel({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return _PremiumPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AuraText.subtitle),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: AuraText.small.copyWith(color: AuraSurface.muted),
          ),
          const SizedBox(height: AuraSpace.s12),
          child,
        ],
      ),
    );
  }
}

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

/// Security-card status badge — wraps the canonical SubstrateChip
/// with an optional trailing chevron used when the row is tappable.
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
    final state = switch (style) {
      _StatusStyle.good => SubstrateChipState.verdant,
      _StatusStyle.warn => SubstrateChipState.sun,
      _StatusStyle.danger => SubstrateChipState.rose,
      _StatusStyle.neutral => SubstrateChipState.mist,
    };

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SubstrateChip(label: label, state: state),
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

class _LoadingRow extends StatelessWidget {
  const _LoadingRow();
  @override
  Widget build(BuildContext context) => const _SecurityRow(
        title: 'Loading…',
        leading: Icons.hourglass_empty_rounded,
        statusStyle: _StatusStyle.neutral,
      );
}

class _ErrorRow extends StatelessWidget {
  const _ErrorRow();
  @override
  Widget build(BuildContext context) => const _SecurityRow(
        title: 'Could not load',
        subtitle: 'Check your connection and try again.',
        leading: Icons.error_outline,
        statusStyle: _StatusStyle.warn,
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// DANGER ZONE + PANEL
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
                color: AuraSurface.coRose.withValues(alpha: 0.7),
              ),
              const SizedBox(width: AuraSpace.s8),
              Text(
                'Danger zone',
                style: AuraText.muted.copyWith(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                  color: AuraSurface.coRose.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: AuraSurface.coRose.withValues(alpha: 0.16).withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(AuraRadius.xl),
            border: Border.all(
              color: AuraSurface.coRose.withValues(alpha: 0.18),
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
                        color: AuraSurface.coRose,
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
                                color: AuraSurface.coRose,
                              ),
                            ),
                            const SizedBox(height: 4),
                            AuraTextBlock(
                              'Permanently remove your account and all its data.',
                              style: AuraText.small.copyWith(
                                color: AuraSurface.coRose
                                    .withValues(alpha: 0.7),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right,
                        size: 18,
                        color: AuraSurface.coRose,
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
