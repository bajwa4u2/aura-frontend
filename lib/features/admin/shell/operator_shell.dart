/// THE CANONICAL AURA ADMIN SHELL.
///
/// One shell, four platforms, one authority.
///
/// WHAT THIS REPLACES
/// ------------------
/// A flat fourteen-item sidebar with no capability gating, whose mobile form
/// put all fourteen destinations in a single `Row` of `Expanded` children —
/// no scroll, no overflow, roughly 27px per target on a phone. Alongside it,
/// eighteen screens each built their OWN `AuraScaffold` inside that shell, so
/// the console was really eighteen small applications sharing a sidebar.
///
/// THE RULES THIS SHELL ENFORCES
/// -----------------------------
/// 1. NAVIGATION IS DERIVED FROM AUTHORITY. The areas an operator sees come
///    from `effectivePermissions`. A MODERATOR holds four permissions and an
///    ANALYST three; they must not be shown an OWNER's console.
/// 2. THE SHELL OWNS THE CHROME. Areas render content, never a scaffold.
///    That is what makes one coherent product instead of eighteen.
/// 3. PLATFORM-APPROPRIATE, NOT PLATFORM-REDUCED. Desktop gets a labelled
///    rail and room for multi-pane work; mobile gets a touch-native bar and a
///    sheet for the rest. No capability disappears because the viewport did.
library;

import '../../../core/ui/aura_design_system.dart';
import '../../../core/ui/surface/surface_composition.dart';
import '../../../app/shell/global_platform_shell.dart';
import '../../../core/ui/aura_window.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/ui/aura_radius.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../domain/finance_entry.dart';
import '../runtime/admin_runtime_coordinator.dart';
import '../../../core/auth/admin_access_provider.dart';
import '../domain/operator_area.dart';
import '../domain/operator_authority_provider.dart';
import '../domain/operator_capability.dart';
import 'operator_identity_chip.dart';
import 'operator_unavailable.dart';

/// Width at and above which the rail carries labels and areas may use the
/// full multi-pane composition.
/// Width at and above which the rail carries LABELS.
///
/// Was 1180, which made 1142 — an ordinary laptop viewport, and the one the
/// founder actually reviewed on — fall into an icon-only rail: seven
/// unlabelled glyphs with no way to tell Integrity from Platform from Record.
///
/// The frozen IA is seven NAMED areas. A width where the names disappear is a
/// width where the IA does not exist, so the threshold now sits below the
/// common laptop range and the compact rail below it carries names too.
const double kOperatorDesktopWidth = 1000;

/// Width at and above which a persistent icon rail is shown instead of the
/// bottom bar.
const double kOperatorRailWidth = 760;

/// Primary destinations kept on the mobile bar. The rest live one tap away in
/// a sheet rather than being crushed into the same row.
const int kMobilePrimaryAreas = 3;

class OperatorShell extends ConsumerStatefulWidget {
  const OperatorShell({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<OperatorShell> createState() => _OperatorShellState();
}

class _OperatorShellState extends ConsumerState<OperatorShell> {
  /// Held from mount so `dispose` never has to look it up.
  ///
  /// The shell this replaces called `ProviderScope.containerOf(context)` in
  /// `dispose`, which is an ancestor lookup on an already-deactivated widget.
  /// It throws — and because it throws BEFORE `markShellUnmounted`, the
  /// coordinator's polling timer was never cancelled. A leaked timer on the
  /// one surface whose entire job is to stop polling when it goes away.
  AdminRuntimeCoordinator? _coordinator;

  @override
  void initState() {
    super.initState();

    // THE CONSOLE GRANTS ITS OWN PROBE.
    //
    // `appAdminAccessProvider` refuses to fire `GET /v1/admin/me` until some
    // callsite latches `appAdminProbeAllowedProvider` — the discipline that
    // stopped every signed-in non-operator writing an `admin.access.denied`
    // row on every route change. Correct, and it must stay.
    //
    // But the ONLY place that latched it was a side effect inside the router's
    // `redirect`, which runs on navigation and on `refreshListenable` — both
    // driven by the widget pipeline. On a cold load the first `redirect` runs
    // before `/auth/refresh` has returned, so `authStatus` is not yet `authed`
    // and the latch is not set; the console then waits for a LATER redirect
    // that nothing is guaranteed to cause.
    //
    // Measured in production: a tab left in the background sat on
    // "Establishing authority" for 213 seconds with `/admin/me` never
    // requested once, while presence and notification timers kept firing
    // normally. Flutter web throttles its frame loop when a tab is hidden, so
    // the redirect→latch→probe chain simply stopped advancing — and there is
    // no timeout behind it, so the console waits forever rather than failing.
    //
    // THIS SHELL IS THE HONEST PLACE FOR THE GRANT. Its existence IS the fact
    // the latch was trying to establish: an operator surface is on screen, so
    // asking what they may operate is exactly what should happen next. It is
    // set synchronously in `initState` rather than after a frame, because
    // waiting for a frame is the failure being fixed.
    //
    // The router keeps its own grant. Two callsites setting the same latch to
    // the same value is not duplication worth removing — it is the difference
    // between one path having to work and either path being enough.
    // A MICROTASK, NOT A FRAME. Riverpod refuses a provider mutation while the
    // tree is building, and `initState` here runs inside the router's build.
    // A microtask drains on the event loop the moment that build returns — it
    // does not wait for a frame, which is the whole point: frame starvation is
    // the failure being fixed.
    Future.microtask(() {
      if (!mounted) return;
      ref.read(appAdminProbeAllowedProvider.notifier).state = true;
    });

    // Admin polling is gated on the shell being mounted AND the app being
    // foregrounded, so a backgrounded tab does zero admin work.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final coordinator = ref.read(adminRuntimeCoordinatorProvider.notifier);
      _coordinator = coordinator;
      coordinator.markShellMounted();
    });
  }

  @override
  void dispose() {
    _coordinator?.markShellUnmounted();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authorityAsync = ref.watch(operatorAuthorityProvider);

    return authorityAsync.when(
      loading: () => const _OperatorFrame(child: OperatorAuthorityLoading()),
      error: (_, __) => const _OperatorFrame(child: OperatorAuthorityError()),
      data: (authority) {
        if (!authority.isOperator) {
          return const _OperatorFrame(child: OperatorNoAuthority());
        }

        final areas = OperatorArea.visibleFor(authority);
        if (areas.isEmpty) {
          // Authority exists but grants nothing this console models. Saying so
          // is more useful than an empty rail.
          return const _OperatorFrame(child: OperatorNoAuthority());
        }

        final path = GoRouterState.of(context).uri.path;
        final current = OperatorArea.forPath(path) ?? areas.first;

        // THE FINANCE DOORWAY, NAMED IN THE CHROME ONLY WHEN IT IS THEIRS.
        //
        // `/admin/finance` matches no OperatorArea by design, so `current`
        // falls back to `areas.first` and the header would otherwise announce
        // "Now" above the Finance screen — chrome that contradicts its own
        // content.
        //
        // Gated on the SAME authority bit as the destination itself, never on
        // the route alone. A principal without a grant who reaches this path
        // directly keeps the ordinary fallback: the body says "Not available"
        // and the header says nothing about Finance, because a header reading
        // "Finance" would itself disclose that there is a Finance to be denied.
        final financeVisible = ref.watch(financeDestinationVisibleProvider);
        final onFinance = path == kFinanceDestinationPath ||
            path.startsWith('$kFinanceDestinationPath/');
        final namesFinance = onFinance && financeVisible;

        // THE OPERATOR CONSOLE IS A REALM OF AURA, NOT A SEPARATE PRODUCT.
        //
        // This shell drew its own chrome from top to bottom: no Aura platform
        // bar, no wordmark, no search or attention or account — a different
        // header height, its own 1000/760 breakpoints, and a rail that
        // expanded whenever the window was wide regardless of the posture the
        // person had chosen everywhere else. Crossing into Admin from Home
        // read as launching a different application.
        //
        // What is operator-specific stays: the area header, the authority
        // chip, the areas themselves. What is Aura stays Aura: the platform
        // bar above it, the window authority deciding when a rail exists, and
        // the same navigation posture the member and institution rails use.
        final win = AuraWindow.of(context);
        final hasRail = win.isDesktopClass;
        final isDesktop = win.navPosture == AuraNavPosture.expanded;

        return Scaffold(
          backgroundColor: AuraSurface.page,
          body: SafeArea(
            child: GlobalPlatformShell(
              // THE CONSOLE DECLARES ITS REALM RATHER THAN ITS OWN CHROME.
              //
              // The shared bar was rendering the member strip verbatim here:
              // `/search` over public discourse, a Live pill that offers to
              // leave, "Add your institution" onboarding, and a door to the
              // console the operator is standing in. Four controls answering
              // questions nobody asks in Admin.
              //
              // Declaring the realm is the correction the founder asked for.
              // The shell stays one shell; what it composes is decided by
              // where it stands. Attention and account remain, because a
              // notification is addressed to the person and not to the
              // surface, and identity is never realm-scoped.
              realm: AuraShellRealm.operator,
              searchPath: null,
              // The operator header becomes the context bar the platform
              // shell already knows how to carry — the same slot the member
              // shell uses — instead of a second top-level header.
              contextBar: _OperatorHeader(
                icon: namesFinance ? FinanceDestination.icon : current.icon,
                label: namesFinance ? FinanceDestination.label : current.label,
                authority: authority,
                dense: !hasRail,
              ),
              child: Column(
                children: [
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (hasRail)
                          _OperatorRail(
                            areas: areas,
                            current: current,
                            expanded: isDesktop,
                          ),
                        // The same content measure every other realm uses.
                        // Operator surfaces are working surfaces, so they take
                        // the room — but with the product's margins, not with
                        // none on one side and 120 px on the other.
                        Expanded(child: AuraWorkColumn(child: widget.child)),
                      ],
                    ),
                  ),
                  if (!hasRail)
                    _OperatorBar(areas: areas, current: current),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Chrome for states where no navigation can legitimately be drawn.
class _OperatorFrame extends StatelessWidget {
  const _OperatorFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AuraSurface.page,
      body: SafeArea(child: child),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HEADER
// ─────────────────────────────────────────────────────────────────────────────

class _OperatorHeader extends StatelessWidget {
  const _OperatorHeader({
    required this.icon,
    required this.label,
    required this.authority,
    required this.dense,
  });

  /// Presentation values rather than an [OperatorArea], for the same reason
  /// [_RailItem] takes them: the Finance doorway must be able to name itself in
  /// the chrome without being modelled as an operator area.
  final IconData icon;
  final String label;
  final OperatorAuthority authority;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: dense ? 56 : 64,
      padding: EdgeInsets.symmetric(horizontal: dense ? AuraSpace.s12 : AuraSpace.s20),
      decoration: const BoxDecoration(
        color: AuraSurface.card,
        border: Border(bottom: BorderSide(color: AuraSurface.divider)),
      ),
      child: Row(
        children: [
          Icon(icon, size: dense ? 18 : 20, color: AuraSurface.accent),
          const SizedBox(width: AuraSpace.s10),
          Text(
            label,
            style: TextStyle(
              color: AuraSurface.ink,
              fontSize: dense ? 16 : 18,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.2,
            ),
          ),
          if (!dense) ...[
            const SizedBox(width: AuraSpace.s12),
            Container(width: 1, height: 18, color: AuraSurface.divider),
            const SizedBox(width: AuraSpace.s12),
            const Text(
              'Aura operator',
              style: TextStyle(
                color: AuraSurface.muted,
                fontSize: 12,
                letterSpacing: 0.4,
              ),
            ),
          ],
          const Spacer(),
          OperatorIdentityChip(authority: authority, dense: dense),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// RAIL — tablet (icons) and desktop (labelled)
// ─────────────────────────────────────────────────────────────────────────────

class _OperatorRail extends StatelessWidget {
  const _OperatorRail({
    required this.areas,
    required this.current,
    required this.expanded,
  });

  final List<OperatorArea> areas;
  final OperatorArea current;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    // THREE RAIL FORMS, NOT TWO. Between the full rail and the bottom bar
    // there is a compact one that still names every area — because an icon
    // an operator cannot name is not navigation, it is a guess.
    return Container(
      // ONE EXPANDED WIDTH ACROSS THE PRODUCT. This was 216, the member
      // rail was 264 and the institution rail 232 — three numbers for one
      // region, so the left edge moved every time somebody crossed realms.
      width: expanded
          ? AuraNavPosture.expanded.railWidth
          : AuraNavPosture.compact.railWidth,
      // The same surface the member and institution rails use. Primary
      // navigation is one region of the product; painting it a flat card
      // colour here and a gradient everywhere else made the same region look
      // like it belonged to a different application.
      decoration: const BoxDecoration(
        gradient: AuraGradients.sideNav,
        border: Border(right: BorderSide(color: AuraSurface.divider)),
      ),
      child: ListView(
        padding: const EdgeInsets.symmetric(
          vertical: AuraSpace.s12,
          horizontal: AuraSpace.s8,
        ),
        children: [
          for (final area in areas)
            _RailItem(
              icon: area.icon,
              label: area.label,
              path: area.path,
              selected: area == current,
              expanded: expanded,
            ),
          // THE FINANCE DOORWAY, and the reason it is last and separate.
          //
          // Finance is not an operator area. It renders only when Finance
          // itself says this principal holds an active grant, and it renders
          // NOTHING otherwise — not disabled, not a teaser, not a request-access
          // affordance. An unauthorised operator learns nothing here, including
          // that a Finance system exists.
          _FinanceRailItem(expanded: expanded),
        ],
      ),
    );
  }
}

class _RailItem extends StatelessWidget {
  const _RailItem({
    required this.icon,
    required this.label,
    required this.path,
    required this.selected,
    required this.expanded,
  });

  /// Presentation values rather than an [OperatorArea], so the FINANCE
  /// destination can reuse this exact rendering without being modelled as an
  /// operator area. Every area gates on [OperatorCapability], and an area with
  /// an empty `anyOf` is visible to any operator at all — which is precisely
  /// the forbidden `if isAdmin then show Finance`.
  final IconData icon;
  final String label;
  final String path;
  final bool selected;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final Widget content = expanded
        ? Row(
            children: [
              Icon(
                icon,
                size: 20,
                color: selected ? AuraSurface.accent : AuraSurface.muted,
              ),
              const SizedBox(width: AuraSpace.s12),
              Expanded(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: selected ? AuraSurface.ink : AuraSurface.muted,
                    fontSize: 14,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ),
            ],
          )
        // COMPACT STILL CARRIES THE NAME. Stacked rather than dropped: the
        // seven areas are the product's vocabulary, and an operator should
        // never have to hover to learn where they are.
        : Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 20,
                color: selected ? AuraSurface.accent : AuraSurface.muted,
              ),
              const SizedBox(height: 4),
              // SHRINK, DO NOT TRUNCATE — the same rule the member rail
              // follows. Ellipsis turned these into "Subje…", "Integr…",
              // "Platfo…" and "Disco…", which asks an operator to decode four
              // of the seven areas they navigate by.
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  maxLines: 1,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: selected ? AuraSurface.ink : AuraSurface.muted,
                    fontSize: 10.5,
                    height: 1.1,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
            ],
          );

    return Padding(
      padding: const EdgeInsets.only(bottom: AuraSpace.s4),
      child: Semantics(
        selected: selected,
        button: true,
        label: label,
        child: Material(
          color: selected ? AuraSurface.elevated : Colors.transparent,
          borderRadius: BorderRadius.circular(AuraRadius.md),
          child: InkWell(
            borderRadius: BorderRadius.circular(AuraRadius.md),
            onTap: () => context.go(path),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: expanded ? AuraSpace.s12 : AuraSpace.s4,
                vertical: expanded ? AuraSpace.s12 : AuraSpace.s10,
              ),
              child: content,
            ),
          ),
        ),
      ),
    );
  }
}

/// The Finance destination in the rail.
///
/// AURA_ADMIN != FINANCE_AUTHORITY. Visibility comes from Finance's own
/// authority, resolved server-side from FinanceGrant, and from nothing this
/// console knows: not the operator role, not identity completeness, not
/// admissionBasis, not a verification badge, not a name or email match.
///
/// FAILS CLOSED. Unknown, loading, errored and unauthenticated all render
/// nothing at all.
class _FinanceRailItem extends ConsumerWidget {
  const _FinanceRailItem({required this.expanded});

  final bool expanded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(financeDestinationVisibleProvider)) {
      return const SizedBox.shrink();
    }
    final path = GoRouterState.of(context).uri.path;
    return _RailItem(
      icon: FinanceDestination.icon,
      label: FinanceDestination.label,
      path: kFinanceDestinationPath,
      selected: path == kFinanceDestinationPath ||
          path.startsWith('$kFinanceDestinationPath/'),
      expanded: expanded,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MOBILE BAR — primary areas plus a sheet, never fourteen crushed columns
// ─────────────────────────────────────────────────────────────────────────────

class _OperatorBar extends ConsumerWidget {
  const _OperatorBar({required this.areas, required this.current});

  final List<OperatorArea> areas;
  final OperatorArea current;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final primary = areas.take(kMobilePrimaryAreas).toList();
    final overflow = areas.skip(kMobilePrimaryAreas).toList();

    // NO CAPABILITY DISAPPEARS BECAUSE THE VIEWPORT DID — rule 3 of this shell,
    // and the reason Finance is resolved here rather than only in the rail.
    // A routed destination reachable on desktop and from nowhere on a phone is
    // the failure this estate has already shipped once: a complete surface,
    // routed, and linked from nothing.
    //
    // Resolved by this widget rather than passed in, so a future caller cannot
    // render the Finance entry by forgetting the gate. Fails closed with every
    // other non-eligible state.
    final financeVisible = ref.watch(financeDestinationVisibleProvider);
    final path = GoRouterState.of(context).uri.path;
    final onFinance = path == kFinanceDestinationPath ||
        path.startsWith('$kFinanceDestinationPath/');

    // The sheet is the only place Finance can go on a phone — it must never
    // take one of the three primary slots from an operator area. So the sheet
    // has to EXIST whenever Finance does, even for an operator whose authority
    // grants three areas or fewer and would otherwise see no "More" at all.
    final hasSheet = overflow.isNotEmpty || financeVisible;
    final inSheet = overflow.contains(current) || (onFinance && financeVisible);

    return Container(
      decoration: const BoxDecoration(
        color: AuraSurface.card,
        border: Border(top: BorderSide(color: AuraSurface.divider)),
      ),
      padding: const EdgeInsets.symmetric(vertical: AuraSpace.s4),
      child: Row(
        children: [
          for (final area in primary)
            Expanded(
              child: _BarItem(
                icon: area.icon,
                label: area.label,
                selected: area == current,
                onTap: () => context.go(area.path),
              ),
            ),
          if (hasSheet)
            Expanded(
              child: _BarItem(
                icon: Icons.more_horiz_rounded,
                label: 'More',
                selected: inSheet,
                onTap: () =>
                    _showMore(context, overflow, current, onFinance),
              ),
            ),
        ],
      ),
    );
  }

  void _showMore(
    BuildContext context,
    List<OperatorArea> overflow,
    OperatorArea current,
    bool selected,
  ) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AuraSurface.card,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AuraRadius.xl)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final area in overflow)
              ListTile(
                leading: Icon(
                  area.icon,
                  color: area == current ? AuraSurface.accent : AuraSurface.muted,
                ),
                title: Text(
                  area.label,
                  style: TextStyle(
                    color: AuraSurface.ink,
                    fontWeight:
                        area == current ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  context.go(area.path);
                },
              ),
            // THE FINANCE DOORWAY on mobile. Last and separate, exactly as in
            // the rail: not an operator area, rendered only on Finance's own
            // authority, and rendering NOTHING otherwise — not disabled, not a
            // teaser, no request-access affordance.
            //
            // Its own Consumer rather than the outer widget's bool, because the
            // sheet is a separate subtree with its own lifetime: a grant that
            // is revoked while the sheet is open must take the entry with it.
            //
            // SELECTION AND NAVIGATION COME FROM THE SHELL'S CONTEXT, NOT THE
            // SHEET'S. A modal route is pushed on the root navigator, outside
            // the GoRouter subtree that publishes route state — `GoRouterState.of`
            // throws there. Riverpod is unaffected (its scope is above the app),
            // which is why the authority check can still live inside the entry.
            _FinanceSheetEntry(
              selected: selected,
              onTap: () {
                Navigator.of(sheetContext).pop();
                context.go(kFinanceDestinationPath);
              },
            ),
            const SizedBox(height: AuraSpace.s8),
          ],
        ),
      ),
    );
  }
}

/// The Finance doorway inside the mobile overflow sheet.
///
/// The bar's counterpart to [_FinanceRailItem], and it holds the same line:
/// visibility comes from Finance's own authority — an active FinanceGrant
/// resolved server-side — and from nothing this console knows. Not the operator
/// role, not identity completeness, not admissionBasis, not a name or email
/// match.
///
/// FAILS CLOSED. Unknown, loading, errored and unauthenticated render nothing
/// at all, so no failure mode can disclose that a Finance system exists.
class _FinanceSheetEntry extends ConsumerWidget {
  const _FinanceSheetEntry({required this.selected, required this.onTap});

  /// Resolved by the shell, which stands inside the GoRouter subtree. A modal
  /// sheet does not.
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(financeDestinationVisibleProvider)) {
      return const SizedBox.shrink();
    }

    return ListTile(
      leading: Icon(
        FinanceDestination.icon,
        color: selected ? AuraSurface.accent : AuraSurface.muted,
      ),
      title: Text(
        FinanceDestination.label,
        style: TextStyle(
          color: AuraSurface.ink,
          fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
        ),
      ),
      onTap: onTap,
    );
  }
}

class _BarItem extends StatelessWidget {
  const _BarItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AuraRadius.md),
        child: Padding(
          // A comfortable touch target rather than a dense desktop control
          // shrunk down to fit.
          padding: const EdgeInsets.symmetric(vertical: AuraSpace.s8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 22,
                color: selected ? AuraSurface.accent : AuraSurface.muted,
              ),
              const SizedBox(height: AuraSpace.s4),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  color: selected ? AuraSurface.ink : AuraSurface.muted,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
