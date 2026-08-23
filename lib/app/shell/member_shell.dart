import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../route_classification.dart';
import '../../core/auth/session_providers.dart';
import '../../core/authority/capability_projection.dart';
import '../../core/institutions/institution_access_provider.dart';
import '../../core/institutions/institution_paths.dart';
import '../../core/media/aura_attachment_image.dart';
import '../../core/ui/aura_design_system.dart';
import '../../core/ui/aura_radius.dart';
import '../../core/ui/aura_responsive.dart';
import '../../core/ui/aura_space.dart';
import '../../core/ui/surface/surface_composition.dart';
import 'global_platform_shell.dart';
import '../../core/ui/aura_surface.dart';
import '../../core/navigation/navigation_authority.dart';
import '../../core/trust/trust_marks.dart';
import '../../core/ui/aura_text.dart';
import '../../features/institutions/data/institution_pending_counts.dart';
import '../../features/updates/module_attention.dart';
import '../../features/institutions/live_rooms/global_live_banner_layer.dart';
import '../../features/meetings/presentation/widgets/active_meeting_return_layer.dart';
import '../../features/institutions/ui/institution_ds.dart';
import 'rail/rail_composition.dart';
import '../../core/identity/person_identity_model.dart';
import '../../core/institutions/institution_route_authority.dart';

// ─────────────────────────────────────────────────────────────────────────────
// INSTITUTION COLOR PALETTE — teal authority, calm workspace
// ─────────────────────────────────────────────────────────────────────────────

const Color _institutionAccent = Color(0xFF0D9488);
const Color _institutionAccentSoft = Color(0x1E0D9488);
const Color _institutionAccentText = Color(0xFF5EEAD4);
const Color _institutionNavBg1 = Color(0xFF091820);
const Color _institutionNavBg2 = Color(0xFF071420);

const LinearGradient _institutionHeaderGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [
    Color(0xFF0B1C26),
    Color(0xFF0D2030),
    Color(0xFF0F2535),
  ],
);

const LinearGradient _institutionNavGradient = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: [_institutionNavBg1, _institutionNavBg2],
);

/// Key for the institution workspace Scaffold so the mobile slim bar can open
/// the navigation drawer reliably (Scaffold.of can resolve a nested scaffold).
final GlobalKey<ScaffoldState> _institutionScaffoldKey =
    GlobalKey<ScaffoldState>();

// ─────────────────────────────────────────────────────────────────────────────
// MEMBER SHELL
// ─────────────────────────────────────────────────────────────────────────────

/// Key for the member workspace Scaffold so the mobile bar can open the nav
/// drawer reliably (no nested-Scaffold ambiguity).
final GlobalKey<ScaffoldState> _memberScaffoldKey = GlobalKey<ScaffoldState>();

class MemberShell extends StatelessWidget {
  const MemberShell({super.key, required this.child});

  final Widget child;

  // ORDER IS NOT THIS SHELL'S TO DECIDE.
  //
  // These four were a private `static const` list here, which fed the rail,
  // the bottom bar and the drawer — so this shell's forms agreed by
  // construction, and nothing enforced that any OTHER shell would. Founder
  // ruling 2026-08-22 moved Create immediately after Home, and the right place
  // for that ruling to live is the navigation authority that already names the
  // four destinations, not a list inside one presentation.
  //
  // This shell now derives them from `PrimaryDestination.values` and supplies
  // only what is genuinely presentational: which icon represents each
  // destination on this form factor. Labels and addresses come from the
  // authority so a destination cannot acquire a second name or a second
  // address by being written down twice.
  static const Map<PrimaryDestination, (IconData, IconData)> _icons = {
    PrimaryDestination.home: (Icons.home_outlined, Icons.home_rounded),
    PrimaryDestination.create: (
      Icons.add_circle_outline_rounded,
      Icons.add_circle_rounded,
    ),
    PrimaryDestination.messages: (
      Icons.mail_outline_rounded,
      Icons.mail_rounded,
    ),
    PrimaryDestination.discover: (
      Icons.explore_outlined,
      Icons.explore_rounded,
    ),
  };

  static final List<_NavItem> _items = PrimaryDestination.values
      .map((d) => _NavItem(
            label: d.label,
            icon: _icons[d]!.$1,
            selectedIcon: _icons[d]!.$2,
            path: d.route,
          ))
      .toList(growable: false);

  static const double _tabletBreakpoint = kTabletBreak; // 900

  /// Returns the index of the nav item that should be highlighted, or
  /// -1 when the current path is not a primary nav destination.
  ///
  /// The previous default of returning 0 (Works) meant that a user
  /// viewing /posts/<id>, /author/<handle>, /search, /notifications,
  /// /me, /me/edit, /security, /saved, /updates, /activity, /thread/...
  /// — any non-primary detail route — saw "Works" highlighted in both
  /// the side and bottom nav. That misled the user about where they
  /// were inside the product. Returning -1 produces a clean "no item
  /// selected" state on detail routes, which is the truthful signal.
  int _indexForPath(String path) {
    // C3 — selected state is DESTINATION IDENTITY, resolved by the
    // canonical Navigation Authority (never local substring matching).
    final primary = NavigationAuthority.primaryOf(path);
    if (primary == null) return -1;
    return _items.indexWhere((i) => i.path == primary.route);
  }

  @override
  Widget build(BuildContext context) {
    final uri = GoRouterState.of(context).uri;
    final path = uri.path;
    final selectedIndex = _indexForPath(path);
    // When the soft keyboard is up (e.g., typing in the composer) the bottom
    // nav both wastes the reclaimed space and risks an accidental tap that
    // navigates away mid-compose. Hide it while editing; it returns the
    // moment the keyboard dismisses.
    final keyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final isTablet = width >= _tabletBreakpoint; // 900
        // ACTIVE MEETING = focus surface: drop the persistent rail (and bottom
        // nav) to a hamburger drawer so the participant grid gets full width.
        final isMeetingFocus = isMeetingFocusPath(path);

        // Member navigation doctrine:
        //   * DESKTOP / TABLET (≥900): persistent LEFT RAIL — member identity +
        //     navigation. No bottom nav.
        //   * MOBILE (<900): no persistent bottom nav. A slim bar carries a
        //     menu button (opens the nav drawer) + identity; the full rail
        //     opens on demand as a drawer. Content gets the whole viewport.
        final showLeftRail = isTablet && !isMeetingFocus;

        return Scaffold(
          key: showLeftRail ? null : _memberScaffoldKey,
          backgroundColor: AuraSurface.page,
          drawer: showLeftRail
              ? null
              : Drawer(
                  backgroundColor: AuraSurface.page,
                  width: 288,
                  child: _MemberSideNav(
                    items: _items,
                    selectedIndex: selectedIndex,
                    currentPath: path,
                    inDrawer: true,
                  ),
                ),
          // Persistent bottom navigation for small screens (no left rail).
          // Restores always-visible section nav on mobile/tablet so the
          // create surfaces (and every other member surface) are never a
          // single hidden hamburger away. Suppressed on immersive routes
          // (realtime, thread/live) via the same predicate as the slim bar.
          bottomNavigationBar:
              (!showLeftRail &&
                  !isMeetingFocus &&
                  _showMemberMobileBar(path) &&
                  !keyboardOpen)
              ? _MemberBottomNav(
                  items: _items,
                  selectedIndex: selectedIndex,
                  currentPath: path,
                )
              : null,
          body: SafeArea(
            top: true,
            bottom: false,
            // Persistent-session UX: an active meeting follows the user
            // around the app as a return pill — never an abandoned tab.
            child: ActiveMeetingReturnLayer(
              child: GlobalLiveBannerLayer(
                child: GlobalPlatformShell(
                  contextBar: (!showLeftRail && _showMemberMobileBar(path))
                      ? const _MemberMobileBar()
                      : null,
                  child: Row(
                    children: [
                      if (showLeftRail)
                        _MemberSideNav(
                          items: _items,
                          selectedIndex: selectedIndex,
                          currentPath: path,
                        ),
                      Expanded(child: child),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// AXR-1 notification synchronization — which module's unread count a
/// member nav destination carries. Destinations without an owning module
/// (Home, Create, Support) never badge; their events live in Activity.
int _memberBadgeFor(_NavItem item, ModuleAttention attention) {
  switch (item.path) {
    case '/messages':
      return attention.messages;
    case '/institutions':
      return attention.institutions;
    default:
      return 0;
  }
}

/// The slim mobile bar (and its menu affordance) is suppressed on immersive
/// full-screen routes where navigation chrome should get out of the way.
bool _showMemberMobileBar(String path) {
  if (path.startsWith('/realtime')) return false;
  return true;
}

// ─────────────────────────────────────────────────────────────────────────────
// INSTITUTION SHELL
// ─────────────────────────────────────────────────────────────────────────────

class InstitutionShell extends ConsumerWidget {
  const InstitutionShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final identity = ref.watch(institutionIdentityProvider);
    final path = GoRouterState.of(context).uri.path;
    final isPreview = _isPublicPreviewPath(path);

    // Pending-attention counts power the nav badges. Only admins can read the
    // underlying endpoints, so we only subscribe for them; everyone else sees
    // no badges (and we avoid needless 403s). Counts refresh when the provider
    // is invalidated after approve/reject/invite actions.
    final counts = (identity != null && identity.isAdmin && identity.id.isNotEmpty)
        ? ref.watch(institutionPendingCountsProvider(identity.id)).valueOrNull
        : null;
    final pendingJoinRequests = counts?.joinRequests ?? 0;
    final pendingInvites = counts?.invites ?? 0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        // ACTIVE MEETING = focus surface: collapse the persistent rails to a
        // hamburger drawer so the participant grid takes the full width. The
        // drawer still opens the full institution navigation on demand.
        final isMeetingFocus = isMeetingFocusPath(path);
        final isDesktop = width >= kDesktopBreak && !isMeetingFocus; // 1200
        final isTablet = width >= kTabletBreak && !isMeetingFocus; // 900

        // Workspace navigation doctrine (institution workspace only):
        //   * DESKTOP / TABLET (≥900): the persistent LEFT RAIL is the single
        //     home for institution identity + ALL institution navigation. No
        //     institution context bar, no institution top tabs, no bottom nav.
        //   * MOBILE (<900): no persistent institution chrome. A slim context
        //     bar carries only a menu button + identity; the full navigation
        //     opens on demand in a drawer. No top tabs, no bottom nav.
        // The result recovers vertical space and lets page content start high.
        final showLeftRail = isTablet;

        final sideNav = _InstitutionSideNav(
          currentPath: path,
          identity: identity,
          pendingJoinRequests: pendingJoinRequests,
          pendingInvites: pendingInvites,
        );

        final body = GlobalPlatformShell(
          // Suppress the global search button on institution routes —
          // /search is member-scoped; surfacing it here would leak member
          // content into institution context. The notifications bell and
          // account menu stay (they're platform-level, not member-only).
          searchPath: null,
          // Desktop/tablet: identity + nav live in the left rail, so no
          // institution context bar at all. Mobile: a slim bar with a menu
          // button (opens the nav drawer) + identity — the only institution
          // chrome on small screens.
          contextBar: showLeftRail
              ? null
              : _InstitutionMobileBar(
                  identity: identity,
                  pendingTotal: pendingJoinRequests + pendingInvites,
                ),
          child: AuraSurfaceScaffold(
            type: AuraSurfaceType.institutionWorkspace,
            header: null,
            leftRail: showLeftRail ? sideNav : null,
            center: isPreview
                ? Column(
                    children: [
                      _PublicPreviewToolbar(identity: identity),
                      Expanded(child: child),
                    ],
                  )
                : child,
            contextRail: isDesktop
                ? AuraContextRail(
                    modules: _institutionContextModules(context, identity),
                  )
                : null,
            // Institution bottom navigation removed from the workspace.
            footer: null,
          ),
        );

        return Scaffold(
          key: showLeftRail ? null : _institutionScaffoldKey,
          backgroundColor: AuraSurface.page,
          // Mobile navigation drawer — the same rail, opened on demand.
          drawer: showLeftRail
              ? null
              : Drawer(
                  backgroundColor: _institutionNavBg1,
                  width: 288,
                  child: _InstitutionSideNav(
                    currentPath: path,
                    identity: identity,
                    pendingJoinRequests: pendingJoinRequests,
                    pendingInvites: pendingInvites,
                    inDrawer: true,
                  ),
                ),
          body: SafeArea(
            top: true,
            bottom: false,
            child: ActiveMeetingReturnLayer(
              child: GlobalLiveBannerLayer(child: body),
            ),
          ),
        );
      },
    );
  }

  static bool _isPublicPreviewPath(String path) {
    final parts = path.split('/').where((s) => s.isNotEmpty).toList();
    // ['institution', ':id', 'institutions', ':slug', ...]
    return parts.length >= 4 &&
        parts[0] == 'institution' &&
        parts[2] == 'institutions';
  }
}

/// Right-rail modules for the institution shell. Composition is owned
/// by `rail_composition.dart` so member-home, institution, admin, and
/// public discovery share one source of truth for civic-signal
/// priority. Each module self-hides when it has nothing to surface,
/// so the rail collapses gracefully on quiet days.
List<Widget> _institutionContextModules(
  BuildContext context,
  InstitutionIdentity? identity,
) {
  return institutionWorkspaceRailModules();
}

// ─────────────────────────────────────────────────────────────────────────────
// PUBLIC PREVIEW TOOLBAR — sticky banner shown above the public profile when
// rendered inside InstitutionShell (path: /institution/:id/institutions/:slug).
// ─────────────────────────────────────────────────────────────────────────────

/// Phase 6.6d — Public preview framing.
///
/// Sticky band that sits above the canonical public-profile screen
/// (`InstitutionDetailScreen`) when it is rendered inside the institution
/// workspace. Renders the **same** widget as the public route, so accuracy
/// is automatic by construction; this toolbar is purely framing.
///
/// Visuals:
///   * `InsTone.info` background + border — calm, non-alarming, reads as
///     "you are looking at the public face of this institution".
///   * Eyebrow + status line + tiny URL meta line on the left.
///   * Action cluster on the right: Edit profile · Copy URL · Open URL
///     (web only) · Exit preview.
class _PublicPreviewToolbar extends StatelessWidget {
  const _PublicPreviewToolbar({required this.identity});

  final InstitutionIdentity? identity;

  String _publicLink(String slug) {
    if (slug.isEmpty) return '';
    final base = Uri.base;
    if (base.scheme.startsWith('http')) {
      return '${base.origin}/institutions/$slug';
    }
    return '/institutions/$slug';
  }

  Future<void> _copy(BuildContext context, String link) async {
    if (link.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: link));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Public URL copied')),
    );
  }

  Future<void> _openExternal(BuildContext context, String link) async {
    // Web builds: copy + announce; native builds keep the same fallback.
    await Clipboard.setData(ClipboardData(text: link));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Open in new tab: $link')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final slug = identity?.slug ?? '';
    final link = _publicLink(slug);
    final tone = InsToneStyle.of(InsTone.info);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: tone.bg,
        border: Border(bottom: BorderSide(color: tone.border)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AuraSpace.s16,
          vertical: AuraSpace.s10,
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 760;
            final headline = _PreviewHeadline(link: link, tone: tone);
            final id = identity?.id ?? '';
            final actions = _PreviewActions(
              link: link,
              tone: tone,
              onEdit: () => context.go(
                id.isNotEmpty
                    ? institutionWorkspacePath(
                        id, InstitutionSection.editProfile)
                    : '/institution/dashboard',
              ),
              onCopy: () => _copy(context, link),
              onOpen: link.isNotEmpty && Uri.base.scheme.startsWith('http')
                  ? () => _openExternal(context, link)
                  : null,
              onExit: () => context.go(
                id.isNotEmpty
                    ? institutionWorkspacePath(
                        id, InstitutionSection.profile)
                    : '/institution/dashboard',
              ),
            );
            if (wide) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(child: headline),
                  const SizedBox(width: AuraSpace.s12),
                  actions,
                ],
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                headline,
                const SizedBox(height: AuraSpace.s8),
                actions,
              ],
            );
          },
        ),
      ),
    );
  }
}

class _PreviewHeadline extends StatelessWidget {
  const _PreviewHeadline({required this.link, required this.tone});

  final String link;
  final InsToneStyle tone;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: tone.bg,
            shape: BoxShape.circle,
            border: Border.all(color: tone.border),
          ),
          alignment: Alignment.center,
          child: Icon(Icons.visibility_outlined, size: 15, color: tone.fg),
        ),
        const SizedBox(width: AuraSpace.s10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'PREVIEW',
                style: AuraText.micro.copyWith(
                  color: tone.fg,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.9,
                  fontSize: 10,
                ),
              ),
              const SizedBox(height: 1),
              Row(
                children: [
                  Flexible(
                    child: Text(
                      'Viewing the public profile',
                      style: AuraText.small.copyWith(
                        color: tone.fg,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (link.isNotEmpty) ...[
                    const SizedBox(width: AuraSpace.s8),
                    Flexible(
                      child: Text(
                        link,
                        style: AuraText.micro.copyWith(
                          color: AuraSurface.muted,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PreviewActions extends StatelessWidget {
  const _PreviewActions({
    required this.link,
    required this.tone,
    required this.onEdit,
    required this.onCopy,
    required this.onOpen,
    required this.onExit,
  });

  final String link;
  final InsToneStyle tone;
  final VoidCallback onEdit;
  final VoidCallback onCopy;
  final VoidCallback? onOpen;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AuraSpace.s8,
      runSpacing: AuraSpace.s6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _PreviewChip(
          label: 'Edit profile',
          icon: Icons.edit_outlined,
          tone: tone,
          onTap: onEdit,
        ),
        if (link.isNotEmpty)
          _PreviewChip(
            label: 'Copy URL',
            icon: Icons.link_rounded,
            tone: tone,
            onTap: onCopy,
          ),
        if (onOpen != null)
          _PreviewChip(
            label: 'Open URL',
            icon: Icons.open_in_new_rounded,
            tone: tone,
            onTap: onOpen!,
          ),
        _PreviewChip(
          label: 'Exit preview',
          icon: Icons.close_rounded,
          tone: tone,
          onTap: onExit,
          emphasized: true,
        ),
      ],
    );
  }
}

class _PreviewChip extends StatelessWidget {
  const _PreviewChip({
    required this.label,
    required this.icon,
    required this.tone,
    required this.onTap,
    this.emphasized = false,
  });

  final String label;
  final IconData icon;
  final InsToneStyle tone;
  final VoidCallback onTap;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final fg = tone.fg;
    final bg = emphasized ? tone.bg : Colors.transparent;
    final border = emphasized ? tone.border : tone.border;
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(AuraRadius.pill),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AuraRadius.pill),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: border),
            borderRadius: BorderRadius.circular(AuraRadius.pill),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AuraSpace.s10,
            vertical: 6,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 13, color: fg),
              const SizedBox(width: 5),
              Text(
                label,
                style: AuraText.small.copyWith(
                  color: fg,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MEMBER HEADER — REMOVED.
// The member shell no longer renders its own header; the global Aura
// wordmark + account/search/notifications/live tools live in the
// persistent GlobalPlatformShell above. If you need to restyle the
// global header, edit `global_platform_shell.dart`, not here.

// =============================================================================
// INSTITUTION MOBILE BAR — slim, on-demand workspace nav affordance.
// Carries only a menu button (opens the navigation drawer) + institution
// identity. No persistent top tabs and no bottom nav; the full navigation
// lives in the drawer (same rail as desktop/tablet).
// =============================================================================

class _InstitutionMobileBar extends StatelessWidget {
  const _InstitutionMobileBar({required this.identity, this.pendingTotal = 0});

  final InstitutionIdentity? identity;
  final int pendingTotal;

  @override
  Widget build(BuildContext context) {
    final name = identity?.name ?? '';
    return Container(
      decoration: const BoxDecoration(
        gradient: _institutionHeaderGradient,
        border: Border(bottom: BorderSide(color: Color(0x220D9488))),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AuraSpace.s8,
          vertical: AuraSpace.s2,
        ),
        child: Row(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                IconButton(
                  icon: const Icon(Icons.menu_rounded,
                      size: 22, color: AuraSurface.ink),
                  tooltip: 'Workspace navigation',
                  visualDensity: VisualDensity.compact,
                  onPressed: () =>
                      _institutionScaffoldKey.currentState?.openDrawer(),
                ),
                if (pendingTotal > 0)
                  Positioned(
                    right: 4,
                    top: 4,
                    child: IgnorePointer(
                        child: _NavCountBadge(count: pendingTotal)),
                  ),
              ],
            ),
            const SizedBox(width: AuraSpace.s2),
            _InstitutionAvatarSmall(name: name, logoUrl: identity?.logoUrl),
            const SizedBox(width: AuraSpace.s8),
            Expanded(
              child: Text(
                name.isEmpty ? 'Workspace' : name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AuraText.small.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AuraSurface.ink,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
class _InstitutionAvatarSmall extends StatelessWidget {
  const _InstitutionAvatarSmall({required this.name, this.logoUrl});

  final String name;
  final String? logoUrl;

  @override
  Widget build(BuildContext context) {
    final initials =
        name.isNotEmpty ? name.trim()[0].toUpperCase() : '';

    return GestureDetector(
      onTap: () => context.go('/institution/dashboard'),
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: _institutionAccentSoft,
          shape: BoxShape.circle,
          border:
              Border.all(color: _institutionAccent.withValues(alpha: 0.4)),
        ),
        clipBehavior: Clip.antiAlias,
        child: logoUrl != null && logoUrl!.isNotEmpty
            ? AuraAttachmentImage(
                // Institution id is not threaded through this widget;
                // URL is unique per logo so URL-keyed caching is fine
                // (a logo replacement would change the URL anyway since
                // backend writes a new R2 object per upload).
                url: logoUrl!,
                fit: BoxFit.cover,
                errorWidget: (_) => _avatarFallback(initials),
              )
            : _avatarFallback(initials),
      ),
    );
  }

  Widget _avatarFallback(String initials) {
    if (initials.isNotEmpty) {
      return Center(
        child: Text(
          initials,
          style: AuraText.micro.copyWith(
            color: _institutionAccentText,
            fontWeight: FontWeight.w800,
            fontSize: 13,
          ),
        ),
      );
    }
    return const Icon(
      Icons.apartment_outlined,
      size: 16,
      color: _institutionAccentText,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MEMBER SIDE NAV
// ─────────────────────────────────────────────────────────────────────────────

class _MemberSideNav extends ConsumerWidget {
  const _MemberSideNav({
    required this.items,
    required this.selectedIndex,
    required this.currentPath,
    this.inDrawer = false,
  });

  final List<_NavItem> items;
  final int selectedIndex;
  final String currentPath;
  final bool inDrawer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // AXR-1 notification synchronization — module badges derive from the
    // same notification rows as the global bell (one source of truth).
    final attention = ref.watch(moduleAttentionProvider);
    final list = Padding(
      padding: const EdgeInsets.fromLTRB(
          AuraSpace.s12, AuraSpace.s8, AuraSpace.s12, AuraSpace.s20),
      child: Column(
        children: [
          // Member identity at the top of the rail (it is no longer repeated
          // as a page hero on member surfaces).
          const _MemberIdentityHeader(),
          const SizedBox(height: AuraSpace.s10),
          for (var i = 0; i < items.length; i++) ...[
            _MemberSideNavTile(
              item: items[i],
              selected: i == selectedIndex,
              badgeCount: _memberBadgeFor(items[i], attention),
              onTap: () {
                final target = items[i].path;
                if (target != currentPath) context.go(target);
                if (inDrawer) Navigator.of(context).maybePop();
              },
            ),
            if (i != items.length - 1) const SizedBox(height: AuraSpace.s4),
          ],
          const Spacer(),
        ],
      ),
    );

    if (inDrawer) {
      return DecoratedBox(
        decoration: const BoxDecoration(gradient: AuraGradients.sideNav),
        child: SafeArea(child: list),
      );
    }
    return Container(
      width: 240,
      decoration: const BoxDecoration(
        gradient: AuraGradients.sideNav,
        border: Border(right: BorderSide(color: AuraSurface.divider)),
      ),
      child: list,
    );
  }
}

/// Compact current-user identity block for the member rail / drawer.
class _MemberIdentityHeader extends ConsumerWidget {
  const _MemberIdentityHeader();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // F053/F116 — the shell names the signed-in person through the canonical
    // model, so the nav and every surface it opens agree. `title` is NOT
    // person identity (it is an institutional role line) and stays a local
    // read: destination-specific composition is preserved, not absorbed.
    final me = ref.watch(authMeDataProvider).valueOrNull;
    final user = (me?['user'] is Map)
        ? Map<String, dynamic>.from(me!['user'] as Map)
        : const <String, dynamic>{};
    final person = AuraPersonIdentity.fromJson(me);
    final name = person.displayName;
    final title = (user['title'] ?? '').toString().trim();
    final avatarUrl = person.avatarUrl ?? '';
    final initials = name.isNotEmpty ? name[0].toUpperCase() : '';
    final affiliations = ref.watch(myAffiliationsProvider);
    // UNKNOWN IS NOT ABSENT. An empty list means "none" only once institution
    // access has actually resolved; before that it means "not yet", and
    // presenting it as none is what made a person who speaks for an
    // institution appear briefly as though they did not.
    final affiliationsResolved = ref.watch(myAffiliationsResolvedProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => context.go('/me'),
        borderRadius: BorderRadius.circular(AuraRadius.r14),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AuraSpace.s8,
            vertical: AuraSpace.s8,
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AuraSurface.accentSoft,
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: AuraSurface.accent.withValues(alpha: 0.35)),
                ),
                clipBehavior: Clip.antiAlias,
                child: avatarUrl.isNotEmpty
                    ? AuraAttachmentImage(
                        url: avatarUrl,
                        fit: BoxFit.cover,
                        errorWidget: (_) => _MemberAvatarFallback(initials),
                      )
                    : _MemberAvatarFallback(initials),
              ),
              const SizedBox(width: AuraSpace.s10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Handle is intentionally NOT shown here — in the user's
                    // own nav it's low-value and competes with the affiliation
                    // line below. The @handle stays internal / on the profile
                    // view. Identity block = name + affiliation-or-nothing.
                    Text(
                      name.isEmpty ? 'Your account' : name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AuraText.small.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AuraSurface.ink,
                      ),
                    ),
                    if (title.isNotEmpty)
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AuraText.micro.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AuraSurface.muted,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
        if (!affiliationsResolved)
          const _AffiliationLineResolving()
        else if (affiliations.isNotEmpty)
          _AffiliationLine(affiliations: affiliations),
      ],
    );
  }
}

/// Compact affiliation line under the member identity block. Shows the
/// primary institution + capacity (Speaks for / Owner / Admin / Member),
/// a verified tick, and "+N" when the member belongs to several. Self-hides
/// when the member has no affiliation. Tapping opens the institution
/// workspace selector.
/// The affiliation line while institution access is still being resolved.
///
/// It occupies the same vertical space the real line will, so the identity
/// block does not reflow when the answer arrives, and it says nothing about
/// whether the person holds an institution — because that is not yet known.
class _AffiliationLineResolving extends StatelessWidget {
  const _AffiliationLineResolving();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(
        left: AuraSpace.s8,
        right: AuraSpace.s8,
        top: AuraSpace.s4,
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: AuraSpace.s8,
          vertical: AuraSpace.s6,
        ),
        child: SizedBox(height: 18),
      ),
    );
  }
}

class _AffiliationLine extends StatelessWidget {
  const _AffiliationLine({required this.affiliations});

  final List<MemberAffiliation> affiliations;

  String _capacity(MemberAffiliation a) {
    if (a.canSpeakOfficially) return 'Speaks for';
    switch (a.role) {
      case 'OWNER':
        return 'Owner ·';
      case 'ADMIN':
        return 'Admin ·';
      case 'EDITOR':
        return 'Editor ·';
      default:
        return 'Member ·';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (affiliations.isEmpty) return const SizedBox.shrink();
    final primary = affiliations.first;
    final extra = affiliations.length - 1;
    final name = primary.name.isEmpty ? 'an institution' : primary.name;
    final label = '${_capacity(primary)} $name';

    return Padding(
      padding: const EdgeInsets.only(
        left: AuraSpace.s8,
        right: AuraSpace.s8,
        top: AuraSpace.s4,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          // ENTERING AN INSTITUTION LANDS ON EXPLORE.
          //
          // Founder ruling 2026-08-22. This tapped through to the dashboard,
          // which is Overview -- standing, verification state and a setup
          // checklist. That is administrative/operational information, not the
          // institution's primary experience, so entering an institution began
          // by showing a person its paperwork.
          //
          // The destination comes from the authority rather than a literal,
          // because ENTRY, REFUSAL and NO-AFFILIATION are three different
          // questions that used to share one constant.
          onTap: () => context.go(
            institutionEntryDestination(primary.id),
          ),
          borderRadius: BorderRadius.circular(AuraRadius.r10),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AuraSpace.s8,
              vertical: AuraSpace.s6,
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.account_balance_outlined,
                  size: 13,
                  color: AuraSurface.muted,
                ),
                const SizedBox(width: AuraSpace.s6),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AuraText.micro.copyWith(
                      color: AuraSurface.muted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (primary.isVerified) ...[
                  const SizedBox(width: 3),
                  const InstitutionVerifiedIcon(
                    iconSize: 11,
                    color: AuraSurface.accentText,
                  ),
                ],
                if (extra > 0) ...[
                  const SizedBox(width: AuraSpace.s6),
                  Text(
                    '+$extra',
                    style: AuraText.micro.copyWith(
                      color: AuraSurface.accentText,
                      fontWeight: FontWeight.w800,
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

class _MemberAvatarFallback extends StatelessWidget {
  const _MemberAvatarFallback(this.initials);
  final String initials;
  @override
  Widget build(BuildContext context) {
    if (initials.isEmpty) {
      return const Icon(Icons.person_rounded,
          size: 18, color: AuraSurface.accentText);
    }
    return Center(
      child: Text(
        initials,
        style: AuraText.small.copyWith(
          color: AuraSurface.accentText,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

/// Slim mobile bar for member surfaces: a menu button (opens the nav drawer)
/// plus the current-user identity. The only persistent member chrome on phones.
class _MemberMobileBar extends ConsumerWidget {
  const _MemberMobileBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // F053/F116 — same reader, same fallback order. 'Menu' is kept as the
    // label of a CONTROL for a person who could not be resolved: it names the
    // affordance, it does not pretend to identify anyone.
    final person = AuraPersonIdentity.fromJson(
      ref.watch(authMeDataProvider).valueOrNull,
    );
    final label = person.isEmpty ? 'Menu' : person.label;

    return Container(
      decoration: const BoxDecoration(
        gradient: AuraGradients.sideNav,
        border: Border(bottom: BorderSide(color: AuraSurface.divider)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AuraSpace.s8,
          vertical: AuraSpace.s2,
        ),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.menu_rounded,
                  size: 22, color: AuraSurface.ink),
              tooltip: 'Menu',
              visualDensity: VisualDensity.compact,
              onPressed: () => _memberScaffoldKey.currentState?.openDrawer(),
            ),
            const SizedBox(width: AuraSpace.s2),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AuraText.small.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AuraSurface.ink,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MEMBER BOTTOM NAV — persistent section nav for small screens (no left rail).
// Mirrors the rail's item set so the user has the same five destinations
// (Works / Messages / Create / Institutions / Support) always one tap away.
// ─────────────────────────────────────────────────────────────────────────────

class _MemberBottomNav extends ConsumerWidget {
  const _MemberBottomNav({
    required this.items,
    required this.selectedIndex,
    required this.currentPath,
  });

  final List<_NavItem> items;
  final int selectedIndex;
  final String currentPath;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // AXR-1 — same module-attention source as the side rail.
    final attention = ref.watch(moduleAttentionProvider);
    return Container(
      decoration: const BoxDecoration(
        color: AuraSurface.card,
        border: Border(top: BorderSide(color: AuraSurface.divider)),
        boxShadow: [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 12,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 58,
          child: Row(
            children: [
              for (var i = 0; i < items.length; i++)
                Expanded(
                  child: _MemberBottomNavTile(
                    item: items[i],
                    selected: i == selectedIndex,
                    badgeCount: _memberBadgeFor(items[i], attention),
                    onTap: () {
                      if (items[i].path != currentPath) {
                        context.go(items[i].path);
                      }
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MemberBottomNavTile extends StatelessWidget {
  const _MemberBottomNavTile({
    required this.item,
    required this.selected,
    required this.onTap,
    this.badgeCount = 0,
  });

  final _NavItem item;
  final bool selected;
  final VoidCallback onTap;

  /// AXR-1 — unread count for this destination's owning module.
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AuraSurface.accentText : AuraSurface.muted;
    return Semantics(
      button: true,
      selected: selected,
      label: badgeCount > 0 ? '${item.label}, $badgeCount unread' : item.label,
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  selected ? item.selectedIcon : item.icon,
                  size: AuraIconSize.md,
                  color: color,
                ),
                if (badgeCount > 0)
                  Positioned(
                    top: -3,
                    right: -6,
                    child: _NavCountBadge(count: badgeCount),
                  ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              item.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AuraText.micro.copyWith(
                color: color,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MemberSideNavTile extends StatelessWidget {
  const _MemberSideNavTile({
    required this.item,
    required this.selected,
    required this.onTap,
    this.badgeCount = 0,
  });

  final _NavItem item;
  final bool selected;
  final VoidCallback onTap;

  /// AXR-1 notification synchronization — unread count for this
  /// destination's owning module (0 = no badge).
  final int badgeCount;

  @override
  Widget build(BuildContext context) {


    final iconData = selected ? item.selectedIcon : item.icon;
    final fgColor = selected ? AuraSurface.ink : AuraSurface.muted;

    return Semantics(
      button: true,
      label: item.label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AuraRadius.r14),
          child: AnimatedContainer(
            duration: AuraMotion.fast,
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
                horizontal: AuraSpace.s12, vertical: AuraSpace.s10),
            decoration: BoxDecoration(
              color: selected ? AuraSurface.accentSoft : Colors.transparent,
              borderRadius: BorderRadius.circular(AuraRadius.r14),
              border: Border.all(
                color: selected
                    ? AuraSurface.accent.withValues(alpha: 0.25)
                    : Colors.transparent,
              ),
            ),
            child: Row(
              children: [
                Icon(iconData, size: AuraIconSize.md, color: fgColor),
                const SizedBox(width: AuraSpace.s10),
                Expanded(
                  child: Text(
                    item.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AuraText.small.copyWith(
                      fontWeight:
                          selected ? FontWeight.w700 : FontWeight.w500,
                      color: fgColor,
                    ),
                  ),
                ),
                if (badgeCount > 0) ...[
                  const SizedBox(width: AuraSpace.s8),
                  _NavCountBadge(count: badgeCount),
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
// INSTITUTION SIDE NAV — left-border indicator, full workspace sections
// ─────────────────────────────────────────────────────────────────────────────

/// Describes a single entry in the institution side nav.
class InstWorkspaceEntry {
  const InstWorkspaceEntry({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    this.sectionLabel,
    this.pathBuilder,
    this.pathMatcher,
    this.requiresAny = const <ConsequentialAct>[],
    this.badge = 0,
    // ignore: unused_element_parameter
    this.disabled = false,
    // ignore: unused_element_parameter
    this.disabledReason,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final String? sectionLabel;

  /// THE AUTHORITY THIS DESTINATION REQUIRES, as canonical acts.
  ///
  /// Compositional, never role-shaped (founder ruling §9): a destination names
  /// the act it exists for, and the person's effective authority answers.
  /// Holding any one suffices, so Member+Host and Member+Representative compose
  /// without a variant of this list per role.
  ///
  /// Expressed as [ConsequentialAct] so navigation asks the SAME authority that
  /// governs controls — `CapabilityProjection`, whose own doctrine is "what may
  /// I do in this context", consuming the backend's effective set and never
  /// recomputing it. A parallel list of raw capability strings here would be a
  /// second client authority answering one question, which is the drift this
  /// reconstruction removes.
  ///
  /// EMPTY means the PARTICIPATION BASELINE (D1): standing in the institution
  /// is itself the authority. It does not mean "always visible" — a person with
  /// no standing has no workspace at all.
  final List<ConsequentialAct> requiresAny;

  /// Whether this viewer may hold this destination. Standing is the floor;
  /// the act's own requirement is the test above it.
  ///
  /// Hiding is not the security boundary and never was — the backend enforces.
  /// This decides what is OFFERED, so nobody navigates around controls built
  /// for authority they do not hold.
  bool permits(InstitutionIdentity? identity) {
    if (identity == null || identity.id.isEmpty) return false;
    if (requiresAny.isEmpty) return true;

    final projection = CapabilityProjection(
      InstitutionStanding.fromBackend(
        institutionId: identity.id,
        institutionName: identity.name,
        institutionLogoUrl: identity.logoUrl,
        capabilities: identity.capabilities,
        roleWire: identity.role,
        isInstitutionAccount:
            identity.isAuthorizedSpeaker && (identity.role ?? '').isEmpty,
      ),
    );

    return requiresAny.any(
      (act) => projection.presentationFor(act) == ControlPresentation.available,
    );
  }

  /// Pending-attention count rendered as a badge (0 = none).
  final int badge;

  /// Builds the navigation path from the current identity. Return null to disable.
  final String? Function(InstitutionIdentity?)? pathBuilder;

  /// Custom path matcher: returns true if this item is "selected" for path.
  final bool Function(String)? pathMatcher;

  final bool disabled;
  final String? disabledReason;

  String? resolvedPath(InstitutionIdentity? identity) =>
      pathBuilder?.call(identity);

  /// Returns a copy carrying [section] as its section label (used to reflow
  /// section headers onto the first visible entry after capability filtering).
  InstWorkspaceEntry withSectionLabel(String section) => InstWorkspaceEntry(
        label: label,
        icon: icon,
        selectedIcon: selectedIcon,
        sectionLabel: section,
        pathBuilder: pathBuilder,
        pathMatcher: pathMatcher,
        requiresAny: requiresAny,
        badge: badge,
      );

  bool isSelected(String currentPath, InstitutionIdentity? identity) {
    if (pathMatcher != null) return pathMatcher!(currentPath);
    final p = resolvedPath(identity);
    if (p == null) return false;
    final base = p.split('?')[0];
    return currentPath == base || currentPath.startsWith('$base/');
  }
}

List<InstWorkspaceEntry> buildInstitutionWorkspaceEntries(
  InstitutionIdentity? identity, {
  int pendingJoinRequests = 0,
  int pendingInvites = 0,
}) {
  final id = identity?.id ?? '';
  // `slug` was only ever needed by the Public Preview rail entry, which is a
  // contextual action on Profile rather than a destination of its own.

  String? sectionPath(String section) =>
      id.isNotEmpty ? '/institution/$id/$section' : null;

  // The left rail is the single home for ALL institution navigation, grouped
  // by intent (WORKSPACE / ADMIN / GOVERNANCE / IDENTITY). GOVERNANCE V1:
  // entries a member lacks authority for are HIDDEN, not greyed.
  final all = <InstWorkspaceEntry>[
    // ── WORKSPACE ──────────────────────────────────────────────────────────
    InstWorkspaceEntry(
      sectionLabel: 'WORKSPACE',
      label: 'Explore',
      icon: Icons.explore_outlined,
      selectedIcon: Icons.explore_rounded,
      pathBuilder: (_) =>
          id.isNotEmpty ? '/institution/$id/explore' : '/institution/dashboard',
      pathMatcher: (p) =>
          p.startsWith('/institution/') && p.contains('/explore'),
    ),
    InstWorkspaceEntry(
      label: 'Activity',
      icon: Icons.timeline_outlined,
      selectedIcon: Icons.timeline_rounded,
      pathBuilder: (_) => sectionPath('activity'),
      pathMatcher: (p) =>
          p.startsWith('/institution/') && p.contains('/activity'),
    ),
    InstWorkspaceEntry(
      label: 'Announcements',
      icon: Icons.campaign_outlined,
      selectedIcon: Icons.campaign_rounded,
      pathBuilder: (_) => sectionPath('announcements'),
      pathMatcher: (p) =>
          p.startsWith('/institution/') && p.contains('/announcements'),
    ),
    InstWorkspaceEntry(
      label: 'Live',
      icon: Icons.sensors_outlined,
      selectedIcon: Icons.sensors_rounded,
      pathBuilder: (_) => id.isNotEmpty ? '/institution/$id/live-rooms' : null,
      pathMatcher: (p) =>
          p.startsWith('/institution/') && p.contains('/live'),
    ),
    InstWorkspaceEntry(
      label: 'Spaces',
      icon: Icons.forum_outlined,
      selectedIcon: Icons.forum_rounded,
      pathBuilder: (_) => sectionPath('spaces'),
      pathMatcher: (p) =>
          p.startsWith('/institution/') && p.contains('/spaces'),
    ),
    InstWorkspaceEntry(
      label: 'Messages',
      icon: Icons.chat_bubble_outline_rounded,
      selectedIcon: Icons.chat_bubble_rounded,
      pathBuilder: (_) => sectionPath('messages'),
      pathMatcher: (p) =>
          p.startsWith('/institution/') && p.contains('/messages'),
    ),
    InstWorkspaceEntry(
      label: 'Meetings',
      icon: Icons.videocam_outlined,
      selectedIcon: Icons.videocam_rounded,
      pathBuilder: (_) => id.isNotEmpty ? '/institution/$id/meetings' : null,
      pathMatcher: (p) =>
          p.startsWith('/meetings/') ||
          (p.startsWith('/institution/') && p.contains('/meetings')),
    ),

    // ── ADMIN ──────────────────────────────────────────────────────────────
    InstWorkspaceEntry(
      sectionLabel: 'ADMIN',
      label: 'Members',
      icon: Icons.people_outline_rounded,
      selectedIcon: Icons.people_rounded,
      // PARTICIPATION BASELINE, deliberately. Canonical doctrine, stated in
      // institutions.service.ts: "Visibility follows responsibility: every
      // member sees who holds delegated capabilities." Knowing who speaks and
      // hosts for your institution is participation, not administration.
      // MANAGE_MEMBERS governs the ACTIONS inside, not the destination.
      pathBuilder: (_) => id.isNotEmpty ? '/institution/$id/members' : null,
      pathMatcher: (p) =>
          p.contains('/members') && p.startsWith('/institution/'),
    ),
    // D6: Overview is the OPERATIONAL institution destination and belongs in
    // ADMIN immediately after Members. It is no longer the standing surface
    // and no longer the id-less address -- both were the dual-purpose overload
    // the ruling retires.
    //
    // "Operational authority" is expressed compositionally, as holding ANY
    // administrative capability, rather than as a role test. That is what
    // keeps a pure Representative or Host -- who hold real authority, but not
    // administrative authority -- out of an operational surface without
    // needing a variant of this entry per role.
    InstWorkspaceEntry(
      label: 'Overview',
      icon: Icons.grid_view_outlined,
      selectedIcon: Icons.grid_view_rounded,
      requiresAny: const [
        ConsequentialAct.manageMembers,
        ConsequentialAct.manageJoinRequests,
        ConsequentialAct.manageInvitations,
        ConsequentialAct.manageSpaces,
        ConsequentialAct.publishAnnouncement,
        ConsequentialAct.manageMeetings,
        ConsequentialAct.manageAvailability,
        ConsequentialAct.manageAnalytics,
      ],
      pathBuilder: (_) => id.isNotEmpty ? '/institution/$id/dashboard' : null,
      pathMatcher: (p) =>
          p.startsWith('/institution/') && p.endsWith('/dashboard'),
    ),
    InstWorkspaceEntry(
      label: 'Join Requests',
      icon: Icons.person_add_outlined,
      selectedIcon: Icons.person_add_rounded,
      requiresAny: const [ConsequentialAct.manageJoinRequests],
      badge: pendingJoinRequests,
      pathBuilder: (_) =>
          id.isNotEmpty ? '/institution/$id/join-requests' : null,
      pathMatcher: (p) =>
          p.contains('/join-requests') && p.startsWith('/institution/'),
    ),
    InstWorkspaceEntry(
      label: 'Invites',
      icon: Icons.mail_outline_rounded,
      selectedIcon: Icons.mail_rounded,
      requiresAny: const [ConsequentialAct.manageInvitations],
      badge: pendingInvites,
      pathBuilder: (_) => id.isNotEmpty ? '/institution/$id/invites' : null,
      pathMatcher: (p) =>
          p.contains('/invite') && p.startsWith('/institution/'),
    ),
    InstWorkspaceEntry(
      label: 'Booking pages',
      icon: Icons.calendar_today_outlined,
      selectedIcon: Icons.calendar_today_rounded,
      requiresAny: const [ConsequentialAct.manageAvailability],
      pathBuilder: (_) =>
          id.isNotEmpty ? '/institution/$id/availability' : null,
      pathMatcher: (p) =>
          p.startsWith('/institution/') && p.endsWith('/availability'),
    ),

    // ── GOVERNANCE (owner-held; hidden from operators without the capability)
    InstWorkspaceEntry(
      sectionLabel: 'GOVERNANCE',
      label: 'Domains',
      icon: Icons.language_rounded,
      selectedIcon: Icons.language_rounded,
      requiresAny: const [ConsequentialAct.manageDomains],
      pathBuilder: (_) => id.isNotEmpty
          ? institutionWorkspacePath(id, InstitutionSection.domains)
          : null,
    ),
    InstWorkspaceEntry(
      label: 'Billing',
      icon: Icons.account_balance_wallet_outlined,
      selectedIcon: Icons.account_balance_wallet_rounded,
      requiresAny: const [ConsequentialAct.manageBilling],
      pathBuilder: (_) => id.isNotEmpty ? '/institution/$id/billing' : null,
      pathMatcher: (p) =>
          p.startsWith('/institution/') && p.endsWith('/billing'),
    ),

    // ── IDENTITY ───────────────────────────────────────────────────────────
    InstWorkspaceEntry(
      sectionLabel: 'IDENTITY',
      label: 'Profile',
      icon: Icons.badge_outlined,
      selectedIcon: Icons.badge_rounded,
      pathBuilder: (_) => id.isNotEmpty
          ? institutionWorkspacePath(id, InstitutionSection.profile)
          : null,
    ),
    InstWorkspaceEntry(
      label: 'Edit Profile',
      icon: Icons.edit_outlined,
      selectedIcon: Icons.edit_rounded,
      requiresAny: const [ConsequentialAct.manageBranding],
      pathBuilder: (_) => id.isNotEmpty
          ? institutionWorkspacePath(id, InstitutionSection.editProfile)
          : null,
    ),
    // PUBLIC PREVIEW IS AN ACTION, NOT A DESTINATION.
    //
    // Founder refinement 2026-08-22: seeing how the institution looks to the
    // public is something you do WHILE looking at the profile, not a separate
    // place you go. The capability and its route are unchanged and remain
    // reachable contextually from Profile; only the duplicate rail entry is
    // removed.
    //
    // The general rule this states: a rail entry earns its place by being a
    // DESTINATION -- somewhere with its own standing content and its own
    // reason to return. A contextual action or an alternate view of a
    // destination already in the rail inflates the rail without adding
    // anywhere to go.
  ];

  // Filter to entries the acting member may use, then reflow section labels
  // so a section whose anchor was hidden still labels its first visible entry
  // (and a fully hidden section disappears entirely).
  final visible = <InstWorkspaceEntry>[];
  String? pendingSection;
  for (final e in all) {
    if (e.sectionLabel != null) pendingSection = e.sectionLabel;
    if (!e.permits(identity)) continue;
    if (pendingSection != null && pendingSection != e.sectionLabel) {
      visible.add(e.withSectionLabel(pendingSection));
    } else {
      visible.add(e);
    }
    pendingSection = null;
  }
  return visible;
}

class _InstitutionSideNav extends StatelessWidget {
  const _InstitutionSideNav({
    required this.currentPath,
    required this.identity,
    this.pendingJoinRequests = 0,
    this.pendingInvites = 0,
    this.inDrawer = false,
  });

  final String currentPath;
  final InstitutionIdentity? identity;
  final int pendingJoinRequests;
  final int pendingInvites;

  /// When true the rail renders as the mobile navigation drawer: it expands to
  /// the drawer width and tapping a destination closes the drawer.
  final bool inDrawer;

  @override
  Widget build(BuildContext context) {
    final entries = buildInstitutionWorkspaceEntries(
      identity,
      pendingJoinRequests: pendingJoinRequests,
      pendingInvites: pendingInvites,
    );

    final list = ListView(
      padding: const EdgeInsets.fromLTRB(0, AuraSpace.s8, 0, AuraSpace.s20),
      children: [
        // Institution identity now lives at the top of the rail (it left the
        // old context bar). It is the workspace's anchor on every screen.
        _RailIdentityHeader(identity: identity),
        const SizedBox(height: AuraSpace.s4),
        for (final entry in entries) ...[
          if (entry.sectionLabel != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AuraSpace.s20,
                AuraSpace.s12,
                AuraSpace.s12,
                AuraSpace.s4,
              ),
              child: Text(
                entry.sectionLabel!,
                style: AuraText.micro.copyWith(
                  color: _institutionAccent.withValues(alpha: 0.6),
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                  fontSize: 9.5,
                ),
              ),
            ),
          _InstitutionSideNavTile(
            entry: entry,
            selected: entry.isSelected(currentPath, identity),
            identity: identity,
            currentPath: currentPath,
            onNavigate:
                inDrawer ? () => Navigator.of(context).maybePop() : null,
          ),
        ],
      ],
    );

    if (inDrawer) {
      // The Drawer parent already provides width + surface; just supply the
      // gradient and the scrolling nav list.
      return DecoratedBox(
        decoration: const BoxDecoration(gradient: _institutionNavGradient),
        child: SafeArea(child: list),
      );
    }

    return Container(
      width: 232,
      decoration: const BoxDecoration(
        gradient: _institutionNavGradient,
        border: Border(right: BorderSide(color: Color(0x14FFFFFF))),
      ),
      child: list,
    );
  }
}

/// Compact institution identity block shown at the top of the rail / drawer.
class _RailIdentityHeader extends StatelessWidget {
  const _RailIdentityHeader({required this.identity});

  final InstitutionIdentity? identity;

  @override
  Widget build(BuildContext context) {
    final name = identity?.name ?? '';
    final verified = identity?.isVerified ?? false;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AuraSpace.s16,
        AuraSpace.s8,
        AuraSpace.s12,
        AuraSpace.s8,
      ),
      child: GestureDetector(
        onTap: () => context.go('/institution/dashboard'),
        behavior: HitTestBehavior.opaque,
        child: Row(
          children: [
            _InstitutionAvatarSmall(name: name, logoUrl: identity?.logoUrl),
            const SizedBox(width: AuraSpace.s10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    name.isEmpty ? 'Institution' : name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AuraText.small.copyWith(
                      fontWeight: FontWeight.w800,
                      color: AuraSurface.ink,
                    ),
                  ),
                  if (verified)
                    const InstitutionVerifiedMark(
                      color: _institutionAccentText,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InstitutionSideNavTile extends StatelessWidget {
  const _InstitutionSideNavTile({
    required this.entry,
    required this.selected,
    required this.identity,
    required this.currentPath,
    this.onNavigate,
  });

  final InstWorkspaceEntry entry;
  final bool selected;
  final InstitutionIdentity? identity;
  final String currentPath;

  /// Called after a successful navigation — used to close the mobile drawer.
  final VoidCallback? onNavigate;

  @override
  Widget build(BuildContext context) {
    final target = entry.resolvedPath(identity);
    final isDisabled = entry.disabled || target == null;
    final iconColor = selected
        ? _institutionAccentText
        : isDisabled
            ? AuraSurface.faint.withValues(alpha: 0.45)
            : AuraSurface.faint;
    final textColor = selected
        ? _institutionAccentText
        : isDisabled
            ? AuraSurface.faint.withValues(alpha: 0.45)
            : AuraSurface.faint;

    void onTap() {
      if (isDisabled) return;
      if (target != currentPath.split('?')[0]) context.go(target);
      onNavigate?.call();
    }

    return Semantics(
      button: !isDisabled,
      label: entry.label,
      child: MouseRegion(
        cursor:
            isDisabled ? SystemMouseCursors.basic : SystemMouseCursors.click,
        child: GestureDetector(
          onTap: isDisabled ? null : onTap,
          child: AnimatedContainer(
            duration: AuraMotion.fast,
            margin: const EdgeInsets.symmetric(
              horizontal: AuraSpace.s8,
              vertical: 1,
            ),
            decoration: BoxDecoration(
              color: selected ? _institutionAccentSoft : Colors.transparent,
              borderRadius: BorderRadius.circular(AuraRadius.r10),
              border: Border.all(
                color: selected
                    ? _institutionAccent.withValues(alpha: 0.25)
                    : Colors.transparent,
              ),
            ),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: AuraMotion.fast,
                  width: 3,
                  height: 38,
                  decoration: BoxDecoration(
                    color: selected
                        ? _institutionAccent
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AuraSpace.s12,
                      vertical: AuraSpace.s8,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          selected ? entry.selectedIcon : entry.icon,
                          size: AuraIconSize.md,
                          color: iconColor,
                        ),
                        const SizedBox(width: AuraSpace.s10),
                        Expanded(
                          child: Text(
                            entry.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AuraText.small.copyWith(
                              fontWeight: selected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: textColor,
                            ),
                          ),
                        ),
                        if (!isDisabled && entry.badge > 0) ...[
                          const SizedBox(width: AuraSpace.s6),
                          _NavCountBadge(count: entry.badge),
                        ],
                        if (isDisabled && entry.disabledReason != null) ...[
                          const SizedBox(width: AuraSpace.s6),
                          Text(
                            entry.disabledReason!,
                            style: AuraText.micro.copyWith(
                              color: AuraSurface.faint.withValues(alpha: 0.5),
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// NAV COUNT BADGE — small pending-attention pill used across the institution
// navigation (primary nav, side nav, bottom-nav overflow). Caps at 99+.
// ─────────────────────────────────────────────────────────────────────────────

class _NavCountBadge extends StatelessWidget {
  const _NavCountBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();
    final text = count > 99 ? '99+' : '$count';
    return Container(
      constraints: const BoxConstraints(minWidth: 16),
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: _institutionAccent,
        borderRadius: BorderRadius.circular(AuraRadius.pill),
      ),
      alignment: Alignment.center,
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: AuraText.micro.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: 10,
          height: 1.1,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DATA CLASS
// ─────────────────────────────────────────────────────────────────────────────

class _NavItem {
  const _NavItem({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.path,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final String path;
}
