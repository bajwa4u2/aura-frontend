import 'package:flutter/widgets.dart';

import 'rail_modules.dart';

/// Shared rail composition engine.
///
/// One source of truth for which civic-signal modules each shell stacks
/// in its right rail, and in what priority order. The composition is
/// purely a list of modules — every module is provider-backed and
/// self-collapses, so a shell can hand a single list to
/// `AuraContextRail` and get an adaptive, priority-aware rail without
/// inventing per-shell rail logic.
///
/// ─────────────────────────────────────────────────────────────────────
///   PRIORITY CONTRACT
/// ─────────────────────────────────────────────────────────────────────
///
/// Each shell's composition function returns modules in **display
/// priority order**. The most time-sensitive operational modules sit at
/// the top; longer-running discovery / grounding modules sit below.
/// `AuraContextRail` renders the list in order; modules that have no
/// data return `SizedBox.shrink()` and visually disappear, so the rail
/// naturally compresses on quiet days without re-ordering logic.
///
/// ─────────────────────────────────────────────────────────────────────
///   WHY A SHARED ENGINE
/// ─────────────────────────────────────────────────────────────────────
///
/// Before this file, every shell inlined its own module list — member
/// home, institution shell, admin shell, public discovery strip each
/// hardcoded which modules to render in which order. That made
/// surface-specific intent invisible (the same module appearing in two
/// shells looked accidental rather than intentional), and any change to
/// the civic-signal vocabulary had to be hunted across four files.
///
/// This file gathers the contract in one place. Adding a new module to
/// the member rail is now a one-line edit; promoting the same module
/// into the institution rail is another one-line edit; the shells
/// remain pure consumers.
///
/// ─────────────────────────────────────────────────────────────────────
///   WHAT THIS FILE IS NOT
/// ─────────────────────────────────────────────────────────────────────
///
///   * Not a new layout primitive. Shells still call `AuraContextRail`
///     directly; this file only assembles the module list.
///   * Not a relevance-sort engine. Modules are statically ordered per
///     surface. When backend ships per-module relevance signals, a
///     sort path can be added without changing this API.
///   * Not a provider. Each module reads its own provider; nothing
///     here watches any Riverpod state.

// ─────────────────────────────────────────────────────────────────────────────
// MEMBER FEED
// ─────────────────────────────────────────────────────────────────────────────

/// Modules for the member discourse feed (route-level
/// `AuraSurfaceScaffold(discourseFeed)`).
///
/// Priority order:
///   1. LIVE NOW                — sessions in progress (urgent / time-bound).
///   2. TRENDING DISCOURSE      — items with reply momentum + recent activity.
///   3. INSTITUTIONAL RESPONSE  — where institutions have replied publicly,
///                                including any accountability chip.
///   4. RECENT ACTIVITY         — viewer's notification inbox summary.
///   5. PINNED ANNOUNCEMENT     — platform-level notice.
///   6. SAVED                   — viewer's unfinished discourse to return to.
///   7. VERIFIED INSTITUTIONS   — discovery / ecosystem orientation.
///   8. GOVERNANCE NOTICE       — grounding rationale (always-on).
List<Widget> memberFeedRailModules() {
  return const [
    LiveNowRailModule(),
    TrendingDiscourseRailModule(),
    InstitutionalResponseRailModule(),
    RecentActivityRailModule(),
    PinnedAnnouncementRailModule(),
    SavedRailModule(),
    VerifiedInstitutionsRailModule(),
    GovernanceNoticeRailModule(),
  ];
}

// ─────────────────────────────────────────────────────────────────────────────
// INSTITUTION WORKSPACE
// ─────────────────────────────────────────────────────────────────────────────

/// Modules for the institution workspace (`AuraSurfaceScaffold
/// (institutionWorkspace)`).
///
/// Institution-side priority emphasises operational continuity: who is
/// live, where institutions are visibly responding, recent activity in
/// this workspace, identity orientation, then long-running concerns
/// and grounding.
List<Widget> institutionWorkspaceRailModules() {
  return const [
    LiveNowRailModule(),
    InstitutionalResponseRailModule(),
    InstitutionRecentActivityRailModule(),
    WorkspaceActivityRailModule(),
    SavedRailModule(),
    GovernanceNoticeRailModule(),
  ];
}

// ─────────────────────────────────────────────────────────────────────────────
// ADMIN CONTROL
// ─────────────────────────────────────────────────────────────────────────────

/// Modules for the admin control surface.
///
/// Admin priority is decision-pressure first: platform health snapshot,
/// review-queue, pending verifications, then real-time visibility into
/// live sessions. Each admin module returns empty for non-admin viewers
/// (provider gated on `adminMeProvider`).
List<Widget> adminControlRailModules() {
  return const [
    AdminPlatformHealthRailModule(),
    AdminReviewQueueRailModule(),
    AdminPendingInstitutionsRailModule(),
    LiveNowRailModule(),
  ];
}

// ─────────────────────────────────────────────────────────────────────────────
// PUBLIC DISCOVERY
// ─────────────────────────────────────────────────────────────────────────────

/// Module triples for the public-home discovery strip. The strip
/// arranges the three columns side-by-side at desktop and stacks them
/// in flat order at narrower widths.
///
/// Column 1 — Civic signal:
///   trending discourse + institutional response (visible accountability).
///
/// Column 2 — Ecosystem:
///   live sessions + verified institutions (who exists, who's active).
///
/// Column 3 — Continuity:
///   pinned announcement + governance notice (grounding rationale).
///
/// Each column self-collapses by virtue of every module self-collapsing
/// when its provider has nothing to surface, so an empty platform shows
/// only the static governance note.
class PublicDiscoveryColumns {
  const PublicDiscoveryColumns({
    required this.civicSignal,
    required this.ecosystem,
    required this.continuity,
  });

  final List<Widget> civicSignal;
  final List<Widget> ecosystem;
  final List<Widget> continuity;

  /// Flat stacked order used at tablet / mobile widths.
  List<Widget> get stacked => [
        ...civicSignal,
        ...ecosystem,
        ...continuity,
      ];
}

PublicDiscoveryColumns publicDiscoveryColumns() {
  return const PublicDiscoveryColumns(
    civicSignal: [
      TrendingDiscourseRailModule(),
      InstitutionalResponseRailModule(),
    ],
    ecosystem: [
      LiveNowRailModule(),
      VerifiedInstitutionsRailModule(),
    ],
    continuity: [
      PinnedAnnouncementRailModule(),
      GovernanceNoticeRailModule(),
    ],
  );
}
