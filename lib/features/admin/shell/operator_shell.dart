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

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/ui/aura_radius.dart';
import '../../../core/ui/aura_space.dart';
import '../../../core/ui/aura_surface.dart';
import '../runtime/admin_runtime_coordinator.dart';
import '../domain/operator_area.dart';
import '../domain/operator_authority_provider.dart';
import '../domain/operator_capability.dart';
import 'operator_identity_chip.dart';
import 'operator_unavailable.dart';

/// Width at and above which the rail carries labels and areas may use the
/// full multi-pane composition.
const double kOperatorDesktopWidth = 1180;

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
  @override
  void initState() {
    super.initState();
    // Admin polling is gated on the shell being mounted AND the app being
    // foregrounded, so a backgrounded tab does zero admin work. Carried over
    // from the shell this replaces — losing it would have quietly reintroduced
    // background polling for every operator.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(adminRuntimeCoordinatorProvider.notifier).markShellMounted();
    });
  }

  @override
  void dispose() {
    final container = ProviderScope.containerOf(context, listen: false);
    container
        .read(adminRuntimeCoordinatorProvider.notifier)
        .markShellUnmounted();
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

        return LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final isDesktop = width >= kOperatorDesktopWidth;
            final hasRail = width >= kOperatorRailWidth;

            return Scaffold(
              backgroundColor: AuraSurface.page,
              body: SafeArea(
                child: Column(
                  children: [
                    _OperatorHeader(
                      area: current,
                      authority: authority,
                      dense: !hasRail,
                    ),
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
                          Expanded(child: widget.child),
                        ],
                      ),
                    ),
                    if (!hasRail)
                      _OperatorBar(areas: areas, current: current),
                  ],
                ),
              ),
            );
          },
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
    required this.area,
    required this.authority,
    required this.dense,
  });

  final OperatorArea area;
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
          Icon(area.icon, size: dense ? 18 : 20, color: AuraSurface.accent),
          const SizedBox(width: AuraSpace.s10),
          Text(
            area.label,
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
    return Container(
      width: expanded ? 216 : 72,
      decoration: const BoxDecoration(
        color: AuraSurface.card,
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
              area: area,
              selected: area == current,
              expanded: expanded,
            ),
        ],
      ),
    );
  }
}

class _RailItem extends StatelessWidget {
  const _RailItem({
    required this.area,
    required this.selected,
    required this.expanded,
  });

  final OperatorArea area;
  final bool selected;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final content = Row(
      mainAxisAlignment:
          expanded ? MainAxisAlignment.start : MainAxisAlignment.center,
      children: [
        Icon(
          area.icon,
          size: 20,
          color: selected ? AuraSurface.accent : AuraSurface.muted,
        ),
        if (expanded) ...[
          const SizedBox(width: AuraSpace.s12),
          Expanded(
            child: Text(
              area.label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: selected ? AuraSurface.ink : AuraSurface.muted,
                fontSize: 14,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ),
        ],
      ],
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: AuraSpace.s4),
      child: Semantics(
        selected: selected,
        button: true,
        label: area.label,
        child: Material(
          color: selected ? AuraSurface.elevated : Colors.transparent,
          borderRadius: BorderRadius.circular(AuraRadius.md),
          child: InkWell(
            borderRadius: BorderRadius.circular(AuraRadius.md),
            onTap: () => context.go(area.path),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: expanded ? AuraSpace.s12 : AuraSpace.s8,
                vertical: AuraSpace.s12,
              ),
              child: content,
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MOBILE BAR — primary areas plus a sheet, never fourteen crushed columns
// ─────────────────────────────────────────────────────────────────────────────

class _OperatorBar extends StatelessWidget {
  const _OperatorBar({required this.areas, required this.current});

  final List<OperatorArea> areas;
  final OperatorArea current;

  @override
  Widget build(BuildContext context) {
    final primary = areas.take(kMobilePrimaryAreas).toList();
    final overflow = areas.skip(kMobilePrimaryAreas).toList();
    final inOverflow = overflow.contains(current);

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
          if (overflow.isNotEmpty)
            Expanded(
              child: _BarItem(
                icon: Icons.more_horiz_rounded,
                label: 'More',
                selected: inOverflow,
                onTap: () => _showMore(context, overflow, current),
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
            const SizedBox(height: AuraSpace.s8),
          ],
        ),
      ),
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
