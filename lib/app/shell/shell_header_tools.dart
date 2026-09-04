import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../router.dart' show kMePreferencesRoute;

import '../../core/auth/admin_access_provider.dart';
import '../../features/admin/domain/operator_area.dart';
import '../../features/admin/domain/operator_entry.dart';
import '../../core/auth/auth_providers.dart';
import '../../core/auth/session_providers.dart';
import '../../core/institutions/institution_access_provider.dart';
import '../../core/identity/person_identity_model.dart';
import '../../core/media/aura_attachment_image.dart';
import '../../core/navigation/navigation_authority.dart';
import '../../core/net/dio_provider.dart';
import '../../core/ui/aura_radius.dart';
import '../../core/ui/aura_space.dart';
import '../../core/ui/aura_surface.dart';
import '../../core/review/rate_aura.dart';
import '../../core/ui/aura_text.dart';
import '../../features/updates/providers.dart';
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

  // The former `invitePath` invite icon was retired (founder header
  // cleanup, 2026-08-16): no shell ever passed it, and invitation
  // creation is a CREATION intention, not a global utility — it lives in
  // the Create hub and Me → Connections.

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
        // ONE ENTRY, TO THE LANDING.
        //
        // There were two, and both were mislabelled: "Preferences" opened the
        // communications screen and "Settings" opened security, so a person
        // choosing between them was choosing between two words for the same
        // idea and getting whichever narrow screen sat behind the one they
        // picked. Both destinations are still reachable — from Preferences,
        // named for what they actually control.
        context.go(kMePreferencesRoute);
        return;
      case 'claim_audit':
        // Claim audit relocated out of the Create hub — it's an analysis
        // tool, not an act of creation. Surfaced here so admins can reach it
        // from any surface; gated on the display-only admin signal.
        context.go('/ai/claim-audit');
        return;
      case 'admin':
        // Enters NOW — the situation view — never a deep route. An operator
        // arriving should see what needs them before anything else.
        context.go(OperatorArea.now.path);
        return;
      case 'feedback':
        // The SAME destination the mobile drawer has always used. One feedback
        // capability, reached from both widths — not a desktop variant of it.
        context.go(NavigationAuthority.feedbackRoute);
        return;
      case 'rate':
        await openRateAura(ref.read(rateDestinationProvider));
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
    final me = ref
        .watch(_shellMeProvider)
        .maybeWhen(data: (d) => d, orElse: () => <String, dynamic>{});
    // Display-only admin signal (no probe) — gates the admin-only Claim audit
    // entry in the account menu.
    final isAdmin = ref.watch(appAdminCachedDisplayProvider);
    // THE OPERATOR ENTRANCE. Deliberately NOT `appAdminCachedDisplay`:
    // that cache is only populated by a probe that fires on entering
    // /admin, so an operator could not see the door until they had
    // already found it by typing the address. This asks a small,
    // audit-safe question instead.
    final canOperate = ref.watch(canEnterOperatorConsoleProvider);
    // Lifecycle signal for the institution-acquisition action: does the
    // member already participate in any institution?
    final hasInstitution = ref.watch(myAffiliationsProvider).isNotEmpty;
    // UNKNOWN IS NOT ABSENT. An empty affiliation list means "none" only once
    // access has resolved. Before that it means "not yet" -- and offering to
    // ADD an institution is an assertion that the person has none, so a member
    // who already speaks for one was invited to acquire one on every entry and
    // refresh, until the answer arrived and the button vanished. That flicker
    // is half of the founder-observed public -> institution transit.
    final affiliationsResolved = ref.watch(myAffiliationsResolvedProvider);
    const gap = SizedBox(width: AuraSpace.s6);

    // ─────────────────────────────────────────────────────────────────────
    // MOBILE CHROME (founder ruling 2026-08-23)
    // ─────────────────────────────────────────────────────────────────────
    //
    // The top header is NOT a second global navigation bar. On mobile the
    // primary destinations live in the bottom bar, account and institutional
    // context live in the drawer, and global search belongs to Discover. What
    // is left for the header is contextual identity and — only where genuinely
    // earned — an immediate attention signal.
    //
    // ONE control earns it. The audit found that "Activity" and the bell are
    // not two things: `activityPath` is `/notifications`, and the same button
    // carries the unread count. Notification attention is personal and
    // immediate, and NOTHING else projects it persistently — the bottom bar
    // badges Messages, not notifications — so burying it would have destroyed
    // the signal rather than relocated it. It stays.
    //
    // Everything else leaves: Search to Discover, Add institution and Account
    // to the drawer, Live to the drawer as a global destination. Its emptiness
    // is not a problem and is not backfilled.
    final mobileChrome = !widget.isTablet;

    // THE MOBILE HEADER CARRIES NOTHING (founder ruling, 2026-08-23).
    //
    // The bell was the last global control here, and the founder ruled it out
    // on sight. What remains above the content is the wordmark and the screen's
    // own context — the header is not a global navigation bar, and its
    // emptiness is the intended result rather than space to refill.
    //
    // THE ATTENTION SIGNAL IS NOT BURIED WITH IT. The earlier ruling was
    // explicit that unread semantics must be preserved, so notifications moved
    // to the drawer WITH their unread count rather than being dropped. Removing
    // the button was the instruction; removing the signal would not have been.
    if (mobileChrome) return const SizedBox.shrink();

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
      // ADD INSTITUTION — frozen lifecycle behavior (founder live-defect
      // ruling, 2026-08-16): a Person with NO institution relationship
      // keeps this first-class action persistently visible in the global
      // authenticated chrome at EVERY width. Once an institution
      // relationship exists, the onboarding action DISAPPEARS — the
      // workspace relationship takes over. Visibility derives only from
      // canonical relationship truth (myAffiliationsProvider); never from
      // route, shell, or cached assumptions. Not a Discover domain, not a
      // Create domain, never buried in menus/settings/redirect chains.
      if (affiliationsResolved && !hasInstitution) ...[
        gap,
        // ICON-ONLY ON PHONES — founder-reported collision, 2026-08-23.
        //
        // The tools row is MainAxisSize.min inside a Row with a Spacer, so it
        // does not wrap or scroll: anything wider than the remaining space
        // simply runs off the right edge. On a 411dp phone the labelled pill
        // pushed the ACCOUNT BUTTON entirely off-screen, which took identity
        // and sign-out with it — not a cosmetic clip.
        //
        // The frozen ruling says this action stays visible at EVERY width, so
        // it is not hidden or moved into a menu. Only its label is dropped;
        // the icon, tooltip and destination are unchanged.
        _HeaderAddInstitutionBtn(
          compact: !widget.isDesktop,
          iconOnly: !widget.isTablet,
        ),
      ],
    ];

    if (widget.isTablet) tools.add(const SizedBox(width: AuraSpace.s4));

    // THE ACCOUNT BUTTON IS NOT OPTIONAL, SO IT IS NOT IN THE FLEXIBLE GROUP.
    //
    // It carries the person's identity and the only route to sign out. When it
    // sat inside the same unbounded Row as everything else, a phone-width
    // header pushed it clean off the screen edge — sign-out became unreachable
    // rather than merely cramped.
    //
    // Narrowing the widest pill helped and did not settle it: whether the
    // header fits is a function of how many tools happen to be shown, which
    // changes with standing and with anything added later. So the structure
    // guarantees it instead of the arithmetic. The optional tools scroll
    // within whatever space remains — nothing is hidden or moved into a menu,
    // every affordance stays reachable — and the account button is laid out
    // last and unconditionally.
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            // Anchored to the end, so the tools nearest the account button —
            // the ones a reader's eye is already on — stay visible when space
            // runs short.
            reverse: true,
            child: Row(mainAxisSize: MainAxisSize.min, children: tools),
          ),
        ),
        gap,
        _HeaderAccountBtn(
          busy: _busyLogout,
          me: me,
          isAdmin: isAdmin,
          canOperate: canOperate,
          rateDestination: ref.watch(rateDestinationProvider),
          version: ref.watch(appVersionLabelProvider),
          onSelected: (v) => unawaited(_handleAccountAction(v)),
        ),
      ],
    );
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
    // GO LIVE viewer path (task #172): public broadcasts are listed for
    // EVERYONE — this is how a non-party discovers and watches a Live.
    final broadcastsRaw = ref
        .watch(publicBroadcastsProvider)
        .maybeWhen(data: (s) => s, orElse: () => <RealtimeSession>[]);
    final sessionIds = sessions.map((s) => s.id).toSet();
    final broadcasts = broadcastsRaw
        .where((b) => b.id.isNotEmpty && !sessionIds.contains(b.id))
        .take(3)
        .toList();
    final hasLive = sessions.isNotEmpty || broadcasts.isNotEmpty;

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
        if (sessions.isEmpty && broadcasts.isEmpty) {
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
          // Public broadcasts — joining routes through the same
          // /realtime/:id?action=join entry; the backend admits
          // non-parties as receive-only observers.
          ...broadcasts.map(
            (b) => PopupMenuItem<String>(
              value: '__watch:${b.id}',
              child: _LiveSessionMenuTile(
                label: b.title ?? b.contextName ?? 'Live broadcast',
                kind: b.kind,
              ),
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
          context.push(NavigationAuthority.liveDirectoryRoute);
        } else if (value.startsWith('__watch:')) {
          final id = value.substring('__watch:'.length);
          // Carry where the viewer actually was into the session, so leaving
          // the broadcast returns them there. Without it the room can only
          // derive an exit from the stage's own surface — the Conversation
          // that owns the call — which an observer is not a member of, and
          // which therefore resolves to an error page for them.
          context.push(
            NavigationAuthority.realtimeSessionJoinRoute(
              id,
              returnTo: GoRouterState.of(context).uri.toString(),
            ),
          );
        } else {
          context.go(NavigationAuthority.realtimeSessionRoute(value));
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
// ADD-INSTITUTION BUTTON — the institution-onboarding GLOBAL ACTION
// (desktop widths; folds into the account menu below them).
// ─────────────────────────────────────────────────────────────────────────────

class _HeaderAddInstitutionBtn extends StatelessWidget {
  const _HeaderAddInstitutionBtn({this.compact = false, this.iconOnly = false});

  /// Compact label below tablet widths — same action, same prominence.
  final bool compact;

  /// Phone widths. The action stays PERSISTENTLY VISIBLE as the frozen
  /// lifecycle ruling requires — it is the label that goes, not the action.
  /// Its tooltip and destination are unchanged.
  final bool iconOnly;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Bring your organization onto Aura',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () =>
              context.push(NavigationAuthority.institutionOnboardingRoute),
          borderRadius: BorderRadius.circular(AuraRadius.pill),
          hoverColor: const Color(0x1AFFFFFF),
          focusColor: const Color(0x22FFFFFF),
          splashColor: const Color(0x14FFFFFF),
          child: Container(
            height: 38,
            padding: const EdgeInsets.symmetric(horizontal: AuraSpace.s12),
            decoration: BoxDecoration(
              color: AuraSurface.subtle,
              borderRadius: BorderRadius.circular(AuraRadius.pill),
              border: Border.all(color: AuraSurface.divider),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.add_business_outlined,
                    size: 16, color: AuraSurface.muted),
                if (!iconOnly) ...[
                  const SizedBox(width: AuraSpace.s6),
                  Text(
                    compact ? 'Add institution' : 'Add your institution',
                    style: AuraText.small.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AuraSurface.muted,
                    ),
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
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AuraRadius.pill),
          // Explicit hover + focus colors so pointer-device users get a
          // clear affordance on the persistent platform bar. The ink
          // overlay on a dark surface needs more luminance than the
          // default Material hover (which is ~4% white) to register
          // visually against AuraSurface.subtle.
          hoverColor: const Color(0x1AFFFFFF),
          focusColor: const Color(0x22FFFFFF),
          splashColor: const Color(0x14FFFFFF),
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
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AuraRadius.pill),
          hoverColor: const Color(0x1AFFFFFF),
          focusColor: const Color(0x22FFFFFF),
          splashColor: const Color(0x14FFFFFF),
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
    required this.isAdmin,
    required this.canOperate,
    required this.onSelected,
    required this.rateDestination,
    required this.version,
  });

  final bool busy;
  final Map<String, dynamic> me;
  final bool isAdmin;

  /// Whether this person holds ANY operator capability. Capability decides
  /// visibility: an entrance shown to somebody who cannot enter is a door
  /// into a refusal.
  final bool canOperate;
  final ValueChanged<String> onSelected;

  /// Where "Rate Aura" would legitimately go on this platform. `none` on web,
  /// where the control is not shown at all rather than shown and inert.
  final RateDestination rateDestination;

  /// "Version 1.4.2", read from the canonical client identity. Null while it
  /// resolves.
  final String? version;

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
          if (isAdmin)
            _menuItem('claim_audit', Icons.fact_check_outlined, 'Claim audit'),
          if (canOperate) ...[
            const PopupMenuDivider(),
            // Named for what it is. "Admin" is the department; "Aura Admin" is
            // the product an operator opens, and it enters NOW.
            _menuItem('admin', Icons.shield_outlined, 'Aura Admin'),
          ],
          const PopupMenuDivider(),

          // FEEDBACK, RATE AND VERSION — IN THE MENU, NOT IN THE HEADER.
          //
          // The mobile drawer has carried Feedback for some time and the
          // desktop menu did not, so the same product capability existed on
          // one width and not the other. These three go here rather than as a
          // new header row for the reason the invite icon was retired in
          // 2026-08-16: permanent header width is for immediate attention, and
          // none of these is that.
          _menuItem('feedback', Icons.rate_review_outlined, 'Send feedback'),
          if (rateDestination.exists)
            _menuItem('rate', Icons.star_outline_rounded, 'Rate Aura'),

          const PopupMenuDivider(),
          _menuItem(
            'logout',
            busy ? Icons.hourglass_empty : Icons.logout_rounded,
            busy ? 'Signing out…' : 'Sign out',
            danger: true,
          ),

          // NOT AN ACTION, AND DELIBERATELY NOT SHAPED LIKE ONE.
          //
          // Disabled, unpadded, quiet: a person reading their version to a
          // support conversation should not be able to press it, and a menu
          // that turns into developer diagnostics stops being an account
          // menu. Absent entirely while identity is resolving, because a
          // placeholder version is worse than none.
          if (version case final String label)
            PopupMenuItem<String>(
              enabled: false,
              height: 34,
              child: Text(label, style: AuraText.small),
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

    // F053/F116 — the shell header is the most globally visible person in
    // the product, and it used to resolve that person itself: its own alias
    // list, its own nested-`user` unwrap. That private reader was written to
    // fix exactly the divergence the canonical reader now owns for everyone.
    final person = AuraPersonIdentity.fromJson(me);
    final avatarUrl = (person.avatarUrl ?? '').trim();
    if (avatarUrl.isNotEmpty) {
      final userId = person.userId;
      return AuraAttachmentImage(
        url: avatarUrl,
        attachmentId: userId.isNotEmpty ? 'user:$userId' : null,
        width: 38,
        height: 38,
        fit: BoxFit.cover,
        errorWidget: (_) => _initialsOrIcon(),
      );
    }

    return _initialsOrIcon();
  }

  Widget _initialsOrIcon() {
    final person = AuraPersonIdentity.fromJson(me);
    // The canonical order, and deliberately NOT the canonical label: when a
    // person resolves to nothing this surface falls back to an ICON, not to a
    // word. Which order to try is identity's decision and is delegated; what
    // to show when there is nothing to show is this surface's.
    final name = person.displayName.trim().isNotEmpty
        ? person.displayName.trim()
        : person.handle.trim();
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

