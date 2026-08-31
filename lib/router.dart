import 'features/discover/presentation/discover_search.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'app/app_shell.dart';
import 'app/route_classification.dart';
import 'app/route_targets.dart';
import 'core/auth/admin_access_provider.dart';
import 'core/auth/auth_providers.dart';
import 'core/auth/session_bootstrap.dart';
import 'core/product/product_state.dart';
import 'core/product/product_state_view.dart';
import 'core/auth/session_providers.dart';
import 'core/auth/session_hint.dart';
import 'core/diagnostics/runtime_trace.dart';
import 'core/institutions/institution_access_provider.dart';
import 'core/authority/authority_providers.dart';
import 'core/institutions/institution_destination_authority.dart';
import 'core/institutions/institution_route_authority.dart';
import 'core/institutions/institution_route_scope.dart';
import 'core/institutions/institution_space_route_scope.dart';
import 'core/interactions/direct_thread_cutover_scope.dart';
import 'core/navigation/destination_continuity.dart';
import 'features/meetings/presentation/booking_route_entry.dart';
import 'features/meetings/application/meetings_provider.dart';
import 'features/realtime/application/realtime_providers.dart';
import 'features/realtime/domain/realtime_enums.dart';

// Auth
import 'features/auth/presentation/auth_screen.dart';
import 'features/auth/presentation/register_screen.dart';
import 'features/auth/presentation/verify_email_screen.dart';
import 'features/auth/presentation/identity_baseline_screen.dart';
import 'features/auth/presentation/verify_pending_screen.dart';
import 'features/auth/presentation/forgot_password_screen.dart';
import 'features/auth/presentation/reset_password_screen.dart';

// Public / Member
import 'features/feed/domain/feed_item.dart' show FeedItemType;
import 'features/home/presentation/public_home_screen.dart';
import 'features/home/presentation/member_home_screen.dart';
import 'features/public/presentation/institution_sector_screen.dart';
import 'features/public/presentation/space_detail_screen.dart';
import 'features/public/presentation/spaces_discovery_screen.dart';
import 'features/public/presentation/thread_screen.dart';
import 'features/public/presentation/transparency_screen.dart';
import 'features/updates/presentation/updates_screen.dart';
import 'features/activity/presentation/activity_screen.dart';
import 'features/announcements/presentation/announcements_screen.dart';
import 'features/announcements/presentation/announcement_detail_screen.dart';
import 'features/announcements/presentation/announcement_editor_screen.dart';
import 'features/communications/presentation/communications_center_screen.dart';
import 'features/ai/presentation/claim_audit_screen.dart';
import 'features/me/presentation/me_screen.dart';
import 'features/me/presentation/edit_profile_screen.dart';
import 'features/me/presentation/blocked_people_screen.dart';
import 'features/me/presentation/preferences_screen.dart';
import 'features/me/presentation/security_screen.dart';
import 'features/devices/presentation/devices_screen.dart';
import 'features/me/presentation/change_password_screen.dart';
import 'features/posts/presentation/compose_screen.dart';
import 'features/share/presentation/share_screen.dart';
import 'features/posts/presentation/post_detail_screen.dart';
import 'features/profile/presentation/author_profile_screen.dart';
import 'features/profile/presentation/follow_requests_screen.dart';
import 'features/profile/presentation/followers_screen.dart';
import 'features/profile/presentation/following_screen.dart';
import 'features/institutions/presentation/institution_detail_screen.dart';
import 'features/institutions/presentation/institution_dashboard_screen.dart';
import 'features/institutions/presentation/institution_standing_screen.dart';
import 'features/institutions/presentation/institution_members_screen.dart';
import 'features/institutions/presentation/institution_invites_screen.dart';
import 'features/institutions/presentation/institution_join_requests_screen.dart';
import 'features/institutions/presentation/admin_workspace_screen.dart';
import 'features/institutions/wizard/institution_onboarding_wizard.dart';
import 'features/admin/presentation/admin_institutions_screen.dart';
import 'features/admin/presentation/admin_institution_members_screen.dart';
import 'features/admin/presentation/admin_users_screen.dart';
import 'features/admin/presentation/admin_grants_screen.dart';
import 'features/admin/presentation/admin_audit_logs_screen.dart';
import 'features/admin/presentation/admin_settings_screen.dart';
import 'features/admin/presentation/admin_feature_flags_screen.dart';
import 'features/admin/presentation/admin_communications_screen.dart';
import 'features/admin/presentation/admin_institution_domains_screen.dart';
import 'features/admin/presentation/admin_review_queue_screen.dart';
import 'features/admin/presentation/admin_migrations_screen.dart';
import 'features/admin/presentation/admin_policies_screen.dart';
import 'features/admin/presentation/admin_moderation_screen.dart';
import 'features/institutions/domain/institution_domains_screen.dart';
import 'features/institutions/units/institution_unit_context_screen.dart';
import 'features/institutions/units/institution_units_screen.dart';
import 'features/institutions/profile/institution_profile_screen.dart';
import 'features/institutions/profile/institution_edit_profile_screen.dart';
import 'features/institutions/verification/institution_request_verification_screen.dart';
import 'features/institutions/announcements/institution_announcements_screen.dart';
import 'features/institutions/announcements/institution_announcement_composer.dart';
import 'features/institutions/presentation/institution_spaces_screen.dart';
import 'features/institutions/spaces/institution_space_screen.dart';
import 'features/institutions/live_rooms/institution_live_rooms_screen.dart';
import 'features/institutions/explore/institution_explore_screen.dart';
import 'features/institutions/posts/institution_post_composer_screen.dart';
import 'features/institutions/posts/institution_post_detail_screen.dart';
import 'features/institutions/engagement/engagement_list_screen.dart';
import 'features/institutions/engagement/engagement_detail_screen.dart';
import 'features/institutions/participation/participation_screen.dart';
import 'features/direct_threads/presentation/direct_intent_screen.dart';
import 'core/navigation/navigation_authority.dart';
import 'features/discover/presentation/discover_screen.dart';
import 'features/conversation/presentation/messages_screen.dart';
import 'features/conversation/presentation/conversation_screen.dart';
import 'features/conversation/presentation/new_conversation_picker.dart';
import 'features/conversation/presentation/claim_invitation_screen.dart';
import 'features/discover/presentation/people_discovery_screen.dart';
import 'features/articles/presentation/article_editor_screen.dart';
import 'features/articles/presentation/article_screen.dart';
import 'features/discover/presentation/articles_discovery_screen.dart';
import 'features/discover/presentation/institutions_discovery_screen.dart';
import 'features/institutions/messaging/institution_messaging_screen.dart';
import 'features/institutions/activity/institution_activity_screen.dart';
import 'features/monetization/presentation/institution_billing_screen.dart';
import 'features/saves/presentation/saved_screen.dart';
import 'features/create/presentation/create_hub_screen.dart';
import 'features/invitations/presentation/invite_hub_screen.dart';
import 'features/invitations/presentation/invitations_screen.dart';
import 'features/invitations/presentation/invite_accept_screen.dart';
import 'features/invitations/presentation/invite_create_screen.dart';
import 'features/invitations/presentation/contact_import_screen.dart';
import 'features/realtime/presentation/realtime_lobby_screen.dart';
import 'features/realtime/presentation/realtime_room_screen.dart';
import 'features/meetings/presentation/booking_cancel_screen.dart';
import 'features/meetings/presentation/create_meeting_screen.dart';
import 'features/meetings/presentation/guest_waiting_room_screen.dart';
import 'features/meetings/presentation/institution_availability_screen.dart';
import 'features/meetings/presentation/keep_meeting_screen.dart';
import 'features/meetings/presentation/meeting_detail_screen.dart';
import 'features/meetings/presentation/meeting_join_error_screen.dart';
import 'features/meetings/presentation/meeting_join_fallback_screen.dart';
import 'features/meetings/presentation/meeting_live_room_screen.dart';
import 'features/meetings/presentation/pre_join_screen.dart';
import 'features/meetings/presentation/public_booking_screen.dart';
import 'features/meetings/presentation/meetings_home_screen.dart';

// Static screens
import 'screens/support_fallback_screen.dart';
import 'screens/mission_screen.dart';
import 'screens/white_paper_screen.dart';
import 'screens/founder_message_screen.dart';
import 'screens/privacy_policy_screen.dart';
import 'screens/investors_hub_screen.dart';
import 'screens/institutions_hub_screen.dart';
import 'features/public/presentation/public_institution_units_screen.dart';
import 'features/public/presentation/public_unit_detail_screen.dart';
import 'screens/patrons_hub_screen.dart';
import 'screens/supporters_hub_screen.dart';
import 'screens/institution_sign_in_screen.dart';
import 'screens/contact_screen.dart';
import 'screens/account_deletion_screen.dart';
import 'screens/child_safety_screen.dart';
import 'screens/terms_screen.dart';
import 'features/support/presentation/support_agent_screen.dart';
import 'features/support/presentation/admin_support_console_screen.dart';
import 'features/media_governance/presentation/restricted_media_screen.dart';
import 'features/admin/presentation/admin_media_appeals_screen.dart';
import 'features/identity/presentation/identity_verification_screen.dart';
import 'features/admin/presentation/identity_review_screen.dart';
import 'features/feedback/presentation/feedback_screen.dart';
import 'features/feedback/presentation/my_feedback_screen.dart';
import 'features/feedback/presentation/feedback_console_screen.dart';

const String kInstitutionDashboardRoute = '/institution/dashboard';
const String kInstitutionCreateRoute = '/institution/create';
const String kInstitutionGetStartedRoute = '/institutions/get-started';
const String kInstitutionDomainsRoute = '/institution/domains';
const String kInstitutionProfileRoute = '/institution/profile';
const String kInstitutionVerificationRoute =
    '/institution/request-verification';
const String kInstitutionAnnouncementsRoute = '/institution/announcements';
const String kInstitutionCorrespondenceRoute = '/institution/correspondence';
const String kInstitutionEditProfileRoute = '/institution/edit-profile';
const String kInstitutionLiveRoomsRoute = '/institution/live-rooms';
const String kEnterInstitutionRoute = '/enter-institution';
// Identity Foundation Phase 1 — required identity baseline (Date of Birth).
const String kCompleteIdentityRoute = '/complete-identity';
const String kAdminWorkspaceRoute = '/admin';
const String kAdminCommunicationsRoute = '/admin/communications';
const String kMeCommunicationsRoute = '/me/settings/communications';
const String kMePreferencesRoute = '/me/preferences';
const String kMeBlockedRoute = '/me/blocked';
const String kRouterBootRoute = '/_boot';

const String kMessagesRoute = '/messages';
// CO-RC-C7-005 Phase 5: the `/me/correspondence` constants are gone. Route
// classification and the navigation authority no longer name the family, and
// nothing builds a screen from it, so keeping the names alive would only make
// a retired address look reachable.

String _normalizeRedirectDest(String? dest, {String fallback = '/home'}) {
  final trimmed = (dest ?? '').trim();
  if (trimmed.isEmpty || trimmed == '/') return fallback;
  if (!trimmed.startsWith('/')) return fallback;
  if (trimmed == kRouterBootRoute) return fallback;
  return normalizeMemberFacingRoute(trimmed, fallback: fallback);
}

bool _queryBool(String? value) {
  final v = (value ?? '').trim().toLowerCase();
  return v == '1' || v == 'true' || v == 'yes' || v == 'on';
}

// 2026-08-14 — Meetings regression restoration. A meeting belonging to an
// institution does not make its attendee an institution actor: AUTHENTICATION
// determines who the person is, INSTITUTION AUTHORITY determines whether they
// may act as the institution, and MEETING ATTENDANCE AUTHORITY (backend:
// MeetingService.getMeetingForMember — host/participant/invitee/institution-
// member) determines whether they may attend. The blanket "every
// /institution/:id/... sub-path requires institutionAccess.hasAccess" rule
// below predates Meetings' institution-namespaced route family
// (`/institution/:id/meetings/:meetingId(...)`, added 2026-07-11 so a
// meeting's URL can carry institution context) and was never narrowed for
// it — so a legitimate booked/invited attendee with no institution access
// was redirected to Institution Sign In the moment a "View meeting" link,
// the post-signin "keep this booking" flow, or the record's own "Enter
// room" button built that URL. The backend's own authorization for these
// routes was never institution-actor-gated to begin with — this frontend
// rule was simply broader than the resource it protects.
//
// Extracted to a top-level, dependency-free pure function (previously a
// closure-local method with identical logic) so it is independently unit
// testable without a full router/provider harness — it was not otherwise
// testable, and this exact regression needs a permanent regression guard.
bool requiresInstitutionAccessForPath(String path) {
  if (path == kInstitutionDashboardRoute ||
      path == kInstitutionProfileRoute ||
      path == kInstitutionEditProfileRoute ||
      path == kInstitutionCorrespondenceRoute ||
      path == kInstitutionLiveRoomsRoute ||
      path == kInstitutionVerificationRoute) {
    return true;
  }

  // Meeting attendance sub-paths carry an institutionId for URL context
  // only — they are governed by Meeting Attendance Authority, not
  // Institution Authority. "new" is excluded: meeting *creation* under an
  // institution genuinely is institution-staff-only and must stay gated
  // (matches `institutionSubPath` below via fallthrough).
  final meetingAttendeePath = RegExp(
    r'^/institution/[^/]+/meetings/(?!new(?:/|$))[^/]+',
  );
  if (meetingAttendeePath.hasMatch(path)) {
    return false;
  }

  // READING AN INSTITUTION POST IS NOT ACTING AS THE INSTITUTION.
  //
  // Same doctrine as the meeting-attendance exemption above, and the same
  // defect it was written to stop: an institutionId in the path is URL
  // CONTEXT, not a claim to institution identity. An institution post is
  // published to be read — it appears in the public feed and carries a
  // shareable address — so a reader who is not a member was being told they
  // were not a member of something they were only trying to read.
  //
  // Composition stays gated: `posts/new` is genuinely speaking AS the
  // institution and is excluded here exactly as `meetings/new` is above.
  final institutionPostReadPath = RegExp(
    r'^/institution/[^/]+/posts/(?!new(?:/|$))[^/]+',
  );
  if (institutionPostReadPath.hasMatch(path)) {
    return false;
  }

  // All other /institution/:id/... routes require institution access.
  final institutionSubPath = RegExp(r'^/institution/[^/]+/.+');
  return institutionSubPath.hasMatch(path);
}

/// INSTITUTION ROUTE RESTORATION — RC2 + RC3.
///
/// Both helpers ask ONE authority (`decideInstitutionRoute`) instead of
/// reading the active identity directly, and map its outcome through the
/// pure mappers beside it. See institution_route_authority.dart: the old
/// code could not tell "still loading" from "no institution", and treated
/// the URL's institution id as something ambient state could overrule.
///
/// The two entry points remain because the two route shapes genuinely
/// differ — one carries no id, the other carries a claim.
///
/// Both can now STAY PUT while the authority is still resolving. The shorthand
/// shape previously had no builder, so "unresolved" had to resolve to SOME
/// address, and that address was `/_boot?redirect=…` — a real navigation that
/// put Aura's machinery in the address bar and a transit page into history.
/// Giving the shorthand routes a loading builder removes that requirement:
/// "not resolved yet" renders in place, at the URL the person asked for, and
/// the router re-evaluates the moment the authority settles.
String? _redirectShorthandToCanonical(
  Ref ref,
  GoRouterState state,
  String section,
) {
  return institutionShorthandRedirect(
    decideInstitutionRoute(
      snapshot: ref.read(institutionAuthoritySnapshotProvider),
      pathId: null,
    ),
    section: section,
    dashboardRoute: kInstitutionNoAffiliationDestination,
  );
}

/// Validate the institution id the URL carries. Returning `null` means the
/// route may proceed unchanged — which is also how "still resolving" is
/// expressed, because deciding nothing is the correct response to not
/// knowing yet.
String? _enforceCanonicalIdMatch(
  Ref ref,
  GoRouterState state,
  String? pathId,
  String section,
) {
  // ADDRESS FIRST, AUTHORITY SECOND (founder ruling AD2).
  //
  // The segment may be the canonical slug, a legacy id, or a differently-cased
  // slug. Resolving it says WHICH institution is addressed and nothing more —
  // the standing and capability checks below are untouched and still run
  // against the resolved id.
  //
  // A non-canonical form is REDIRECTED rather than tolerated: production holds
  // durable id-shaped links (23 notification rows), and leaving them working
  // in place would keep two address forms alive forever instead of converging
  // them on arrival.
  final snapshot = ref.read(institutionAuthoritySnapshotProvider);
  final address = resolveInstitutionAddress(snapshot, pathId);
  if (address != null && !address.isCanonical) {
    final path = state.uri.path;
    final rest = path.startsWith('/institution/${pathId ?? ''}')
        ? path.substring('/institution/${pathId ?? ''}'.length)
        : '';
    final query = state.uri.hasQuery ? '?${state.uri.query}' : '';
    return '/institution/${address.canonicalSlug}$rest$query';
  }

  final canonical = institutionCanonicalRedirect(
    decideInstitutionRoute(
      snapshot: snapshot,
      // The RESOLVED id, so the existing authority logic is unchanged: it
      // still compares an institution id against held memberships.
      pathId: address?.institutionId ?? pathId,
    ),
    section: section,
    dashboardRoute: kInstitutionNoAffiliationDestination,
  );
  if (canonical != null) return canonical;

  // DENIAL PROTECTS THE BOUNDARY SECOND.
  //
  // Standing said yes; this asks whether the person may hold THIS destination.
  // Navigation already declined to offer it, so ordinarily nobody arrives here
  // — but a bookmark, a pasted URL, a notification whose authority has since
  // changed, or a refresh after a capability was revoked all reach an address
  // the rail no longer shows. Those are the exceptional paths, and they must
  // fail to a truthful standing surface rather than render an operational
  // screen that then falls apart on 403s.
  //
  // Both consumers read ONE table, so the rail and the address can never
  // disagree about who may hold a destination.
  // RC2 — deciding on unresolved is the bug.
  if (!snapshot.resolved) return null;

  final required = institutionDestinationAuthority(section);
  if (required.isEmpty) return null;

  final projection = ref.read(capabilityProjectionProvider);
  return institutionDestinationPermits(projection, section)
      ? null
      : kInstitutionDenialDestination;
}

// REFRESH IS NOT NAVIGATION — AND THE ADDRESS HAS TO KNOW WHERE YOU ARE.
//
// go_router does NOT reflect imperative navigation in the browser URL unless
// this is set: `optionURLReflectsImperativeAPIs` defaults to false. Aura has
// 186 `context.push(...)` call sites, so for every one of them the screen
// changed and the address did not.
//
// That is the founder-observed defect, and it is why a route census kept
// passing: a census navigates BY ADDRESS, so address and screen always agree
// for it. A person navigates BY TAPPING. Their address therefore stays on
// whatever they last arrived at by address — and a refresh faithfully
// reconstructs THAT, moving them backward to a screen they had already left.
//
// Measured live on 2026-08-22: pressing the call button rendered the call room
// while the browser still carried /messages/c/<id>. Screen identity and
// navigational identity had diverged; refreshing there would have discarded
// the call.
//
// The library documents this option as "for backward compatibility" and warns
// that a pushed route's URL is not always deep-linkable. That warning does not
// describe Aura: the C3 route-integrity gate already asserts every address the
// Navigation Authority can emit is a registered route, and NO navigation site
// passes `extra`, so no pushed destination depends on state the URL cannot
// carry. Every pushed address here is reconstructible.
//
// Set once, at the canonical navigation boundary, rather than per route —
// the divergence was never specific to the call route.
final routerProvider = Provider<GoRouter>((ref) {
  GoRouter.optionURLReflectsImperativeAPIs = true;
  final refresh = ValueNotifier<int>(0);
  ref.onDispose(refresh.dispose);

  // ── REFRESH-LISTENER DISCIPLINE ────────────────────────────────────
  //
  // GoRouter rebuilds the Navigator (which re-runs ShellRoute.builder
  // and so the AppShell + every routed screen) every time
  // `refreshListenable` fires. The previous wiring fired on EVERY
  // AsyncValue emit from the access providers — including the loading
  // half of every invalidate / refetch — producing a router-refresh
  // storm whenever any of those providers transiently re-evaluated.
  //
  // Tightened contract: fire ONLY when the materialised value changes.
  // `.valueOrNull` honours `copyWithPrevious`, so a reload that lands
  // on the same value as before never fires the listener — and a
  // genuine state transition still does. The result is a stable router
  // / shell / screen surface during routine background activity.
  ref.listen<AuthStatus>(authStatusProvider, (prev, next) {
    if (prev != next) {
      refresh.value++;
      RuntimeTrace.emit(
        'router.refresh',
        'authStatus',
        data: {'next': next.name},
      );
    }
  });

  ref.listen<AsyncValue<bool?>>(emailVerifiedProvider, (prev, next) {
    final prevValue = prev?.valueOrNull;
    final nextValue = next.valueOrNull;
    if (prevValue != nextValue) {
      refresh.value++;
      RuntimeTrace.emit(
        'router.refresh',
        'emailVerified',
        data: {'next': nextValue},
      );
    }
  });

  ref.listen<AsyncValue<bool?>>(identityBaselineCompleteProvider, (prev, next) {
    final prevValue = prev?.valueOrNull;
    final nextValue = next.valueOrNull;
    if (prevValue != nextValue) {
      refresh.value++;
      RuntimeTrace.emit(
        'router.refresh',
        'identityBaselineComplete',
        data: {'next': nextValue},
      );
    }
  });

  // RC5 — FIRE ON THE ASYNC VALUE'S IDENTITY, NOT ONLY ITS VALUE.
  //
  // Comparing materialised values alone means a transition INTO ERROR never
  // re-runs the redirect: loading -> error is null -> null, and data -> error
  // keeps the previous value through `copyWithPrevious`. The router then goes
  // on standing by a decision it made against state that has since failed,
  // with nothing left to correct it.
  //
  // The key below carries whether the provider is loading or in error as well
  // as what it holds, so every genuine transition is seen — and a reload that
  // lands on the same value still fires nothing, which is the property the
  // original tightening was for.
  String institutionKey(AsyncValue<InstitutionAccess>? v) =>
      '${v?.isLoading ?? true}/${v?.hasError ?? false}/${v?.valueOrNull?.state.name ?? '-'}';

  ref.listen<AsyncValue<InstitutionAccess>>(institutionAccessProvider, (
    prev,
    next,
  ) {
    final nextState = next.valueOrNull?.state;
    if (institutionKey(prev) != institutionKey(next)) {
      refresh.value++;
      RuntimeTrace.emit(
        'router.refresh',
        'institutionAccess',
        data: {'next': nextState?.name},
      );
    }
  });

  String adminKey(AsyncValue<AppAdminAccess>? v) =>
      '${v?.isLoading ?? true}/${v?.hasError ?? false}/${v?.valueOrNull?.isAdmin ?? '-'}';

  ref.listen<AsyncValue<AppAdminAccess>>(appAdminAccessProvider, (prev, next) {
    final nextAdmin = next.valueOrNull?.isAdmin;
    if (adminKey(prev) != adminKey(next)) {
      refresh.value++;
      RuntimeTrace.emit(
        'router.refresh',
        'appAdminAccess',
        data: {'next': nextAdmin},
      );
    }
  });

  // ROUTE CLASSIFICATION (F069, founder ruling 2026-08-17) now lives in the
  // testable shared authority `app/route_classification.dart` — PUBLIC ·
  // MEMBER · AUTH_ACTION · GUEST_REACHABLE, unknown fails CLOSED. These
  // thin aliases keep the redirect logic below reading naturally.
  //
  // `isPublic` here means "a visitor without a member session may reach
  // this route" — public, auth ceremonies, and guest-reachable meeting
  // entry alike. Guest-reachable paths are no longer collapsed into
  // PUBLIC in the classification itself; guest ADMISSION continues to be
  // decided by the destination's own canonical authority, exactly as
  // before (Meetings behavior unchanged).
  bool isPublicPath(String path) => routeAllowsUnauthenticatedEntry(path);

  bool isMemberPath(String path) => classifyRoute(path) == RouteClass.member;

  bool requiresAuth(String path) => isMemberPath(path);

  bool requiresVerifiedEmail(String path) {
    return requiresAuth(path) &&
        path != '/verify-email' &&
        path != '/verify-pending' &&
        path != kCompleteIdentityRoute;
  }

  // Identity Foundation Phase 1 — the first identity field. Deliberately
  // independent of requiresVerifiedEmail: an unverified member must still
  // be able to reach and complete this screen, so the two "authed but
  // incomplete" gates never deadlock each other.
  bool requiresIdentityBaseline(String path) {
    return requiresAuth(path) && path != kCompleteIdentityRoute;
  }

  bool isGuestOnly(String path) => isPlainAuthPage(path);

  bool requiresAppAdmin(String path) =>
      path == kAdminWorkspaceRoute || path.startsWith('$kAdminWorkspaceRoute/');

  bool requiresInstitutionAccess(String path) =>
      requiresInstitutionAccessForPath(path);

  // RC6 — the requirement is DECLARED per workspace section, in
  // route_classification.dart, and both URL forms of a destination resolve
  // to the same section. These predicates used to be written here by hand:
  // the admin one matched exactly two SHORTHAND constants, so the canonical
  // `/institution/:id/edit-profile` and `/institution/:id/domains` carried
  // no admin gate at all — and once RC2/RC3 turned the shorthands into pure
  // redirects, the gate could no longer match anything that rendered.
  bool requiresInstitutionAdminOrSpeaker(String path) {
    final policy = institutionRoutePolicyFor(path);
    return policy == InstitutionRoutePolicy.adminOrSpeaker;
  }

  bool requiresInstitutionAdmin(String path) {
    return institutionRoutePolicyFor(path) == InstitutionRoutePolicy.admin;
  }

  // ── MEETING KILL SWITCH ────────────────────────────────────────────
  //
  // A `/realtime/:sessionId` deep link must NEVER render RealtimeRoomScreen
  // (the generic "Audio meeting / Join call / Connection lost" transport
  // screen) when the underlying session is a MEETING surface. No current
  // meeting code path emits `/realtime/` links — but stale links, cached
  // deep links, and pre-split deployments can still exist in the wild, so
  // the router diverts them architecturally, before the screen ever mounts.
  //
  // Resolutions are cached per sessionId to keep legitimate direct-call and
  // live-room navigation on the fast path (no extra fetch after the first)
  // and to guard against redirect loops.
  final realtimeMeetingRedirects = <String, String>{}; // sessionId → meetingId
  final realtimeSurfaceResolved =
      <String>{}; // sessionIds confirmed non-meeting

  return GoRouter(
    refreshListenable: refresh,
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            SelectableText(
              'Route not found: ${state.uri.path}',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => GoRouter.of(context).go('/'),
              child: const Text('Go home'),
            ),
          ],
        ),
      ),
    ),
    redirect: (context, state) {
      final path = state.uri.path;
      final currentLocation = state.uri.toString();

      final bootstrap = ref.read(sessionBootstrapProvider);
      final authStatus = ref.read(authStatusProvider);
      final emailVerifiedAsync = ref.read(emailVerifiedProvider);
      final identityBaselineAsync = ref.read(identityBaselineCompleteProvider);
      final institutionAsync = ref.read(institutionAccessProvider);

      // Admin probe gating: only allow `/v1/admin/me` to fire when the
      // user is intentionally heading to /admin/* (or already cached as
      // admin). Mutating the StateProvider before reading the FutureProvider
      // is safe because both providers re-evaluate via the refreshListenable
      // listener at the top of this provider.
      if (authStatus == AuthStatus.authed && requiresAppAdmin(path)) {
        final probeAllowed = ref.read(appAdminProbeAllowedProvider);
        if (!probeAllowed) {
          ref.read(appAdminProbeAllowedProvider.notifier).state = true;
        }
      }
      final appAdminAsync = ref.read(appAdminAccessProvider);

      final defaultRedirect = authStatus == AuthStatus.authed
          ? '/home'
          : '/public';
      final redirectDest = _normalizeRedirectDest(
        state.uri.queryParameters['redirect'],
        fallback: defaultRedirect,
      );

      final isBootstrapping = bootstrap.isLoading && !bootstrap.hasValue;
      final isLoggedIn = authStatus == AuthStatus.authed;
      final isVerifyPending = path == '/verify-pending';
      final isVerifyEmail = path == '/verify-email';
      final isCompleteIdentity = path == kCompleteIdentityRoute;
      final isPublic = isPublicPath(path);
      final isAuthAction = isAuthActionPath(path);

      // null = unknown (empty /auth/me, error, or still loading) → stay/wait
      final bool? isVerified = emailVerifiedAsync.when(
        data: (value) => value,
        error: (_, __) => null,
        loading: () => null,
      );

      // isVerified == null means we don't yet know the verification state.
      // Treat it like loading so the router does not redirect prematurely.
      final isVerificationLoading =
          isLoggedIn &&
          (emailVerifiedAsync.isLoading ||
              emailVerifiedAsync.isRefreshing ||
              isVerified == null);

      // Identity Foundation Phase 1 — same null-means-wait discipline as
      // isVerified above, independent gate.
      final bool? isIdentityBaselineComplete = identityBaselineAsync.when(
        data: (value) => value,
        error: (_, __) => null,
        loading: () => null,
      );

      final isIdentityBaselineLoading =
          isLoggedIn &&
          (identityBaselineAsync.isLoading ||
              identityBaselineAsync.isRefreshing ||
              isIdentityBaselineComplete == null);

      final institutionAccess = institutionAsync.maybeWhen(
        data: (value) => value,
        orElse: () =>
            const InstitutionAccess(state: InstitutionAccessState.none),
      );

      final appAdmin = appAdminAsync.maybeWhen(
        data: (value) => value,
        orElse: () => const AppAdminAccess(state: AppAdminState.none),
      );

      final requiresInstitution =
          requiresInstitutionAccess(path) ||
          requiresInstitutionAdminOrSpeaker(path) ||
          requiresInstitutionAdmin(path);

      // Wait for both institution access and admin access to settle on institution paths,
      // so platform admins aren't wrongly redirected before their admin state loads.
      final institutionAccessLoading =
          isLoggedIn &&
          requiresInstitution &&
          (institutionAsync.isLoading || appAdminAsync.isLoading);

      final appAdminLoading =
          isLoggedIn && requiresAppAdmin(path) && appAdminAsync.isLoading;

      if (isBootstrapping) {
        // RESTORING A SESSION IS NOT GOING SOMEWHERE.
        //
        // This used to navigate to `/_boot?redirect=<destination>`, which put
        // Aura's own machinery in the address bar, pushed a transit page into
        // history, and made a reload during restore re-enter `_boot` instead
        // of the destination. Someone opening a shared article saw
        // `/_boot?redirect=/articles/...` rather than the article.
        //
        // Staying put costs nothing that navigating away was buying: `BootGate`
        // renders the restoring state IN PLACE and, crucially, renders it
        // INSTEAD of the routed child — so the destination never mounts and
        // cannot fire requests while authentication is still unknown, which is
        // the real work the old redirect was doing.
        //
        // F065 doctrine is preserved exactly: authentication is UNKNOWN here,
        // and nothing resolves it to signed-out. The destination is the URL
        // itself, so there is nothing to carry, lose, or validate on return.
        return null;
      }

      if (isLoggedIn &&
          (isVerificationLoading ||
              isIdentityBaselineLoading ||
              institutionAccessLoading ||
              appAdminLoading)) {
        return null;
      }

      // A SIGNED-IN MEMBER DOES NOT LAND ON THE ACQUISITION PAGE.
      //
      // `/` renders PublicHomeScreen unconditionally, and nothing sent an
      // authenticated member anywhere else. On the web that never showed:
      // the browser retains a URL, so a returning member reopens `/messages`
      // or `/home` and never sees the root. Android has no such memory — a
      // cold start begins at `/` — so every launch put a signed-in member on
      // the page that explains what Aura is, with the bottom nav highlighting
      // "Home" beside content that is not their home.
      //
      // Deliberately placed AFTER the loading guards above: deciding this
      // while authority is still resolving is the RC2 defect, and it would
      // bounce a member off a legitimate deep link mid-resolution. Only the
      // bare root is redirected, so every other address — including a
      // notification's destination — is untouched.
      if (isLoggedIn && path == '/') {
        return '/home';
      }

      if (isBootPath(path)) {
        if (!isLoggedIn) {
          if (isPublicPath(redirectDest) || isAuthActionPath(redirectDest)) {
            return redirectDest;
          }

          final encoded = Uri.encodeComponent(
            _normalizeRedirectDest(redirectDest, fallback: '/public'),
          );
          return '/login?redirect=$encoded';
        }

        // Identity Foundation Phase 1 — the first identity field, checked
        // before email verification so the two independent "authed but
        // incomplete" gates never fight over which one wins on a cold
        // boot/reopen/refresh.
        if (isIdentityBaselineComplete == false) {
          final encoded = Uri.encodeComponent(
            _normalizeRedirectDest(redirectDest, fallback: '/home'),
          );
          return '$kCompleteIdentityRoute?redirect=$encoded';
        }

        if (isVerified == false) {
          final encoded = Uri.encodeComponent(
            _normalizeRedirectDest(redirectDest, fallback: '/home'),
          );
          return '/verify-pending?redirect=$encoded';
        }

        return redirectDest;
      }

      if (!isLoggedIn) {
        if (requiresAuth(path) && !isPublic) {
          final encoded = Uri.encodeComponent(
            _normalizeRedirectDest(currentLocation, fallback: '/public'),
          );
          return '/login?redirect=$encoded';
        }

        return null;
      }

      // Identity Foundation Phase 1 — required identity baseline. Checked
      // before email verification (see the boot-path block above for why),
      // and before any deep-link/navigation target so an incomplete member
      // never reaches normal app content first.
      if (isIdentityBaselineComplete == false) {
        if (isCompleteIdentity) return null;

        if (requiresIdentityBaseline(path)) {
          final encoded = Uri.encodeComponent(
            _normalizeRedirectDest(currentLocation, fallback: '/home'),
          );
          return '$kCompleteIdentityRoute?redirect=$encoded';
        }

        if (isPublic || isAuthAction) {
          return null;
        }
      }

      if (isIdentityBaselineComplete == true && isCompleteIdentity) {
        return redirectDest;
      }

      if (isVerifyEmail) {
        // Signed-in and verified users have no reason to stay on the verify-email
        // page. Redirect them to their intended destination (or /home).
        // This handles: hard-reload on /verify-email while already signed in,
        // and the post-verification case where the user IS authenticated.
        if (isLoggedIn && isVerified == true) {
          return redirectDest;
        }
        return null;
      }

      if (isVerified == false) {
        if (isVerifyPending) return null;

        if (requiresVerifiedEmail(path) || isGuestOnly(path)) {
          final encoded = Uri.encodeComponent(
            _normalizeRedirectDest(currentLocation, fallback: '/home'),
          );
          return '/verify-pending?redirect=$encoded';
        }

        if (isPublic || isAuthAction) {
          return null;
        }
      }

      if (isVerified == true) {
        if (isGuestOnly(path) || isVerifyPending) {
          return redirectDest;
        }
      }

      // RC4 — TERMINAL DENIAL. A non-admin does not become an admin by
      // visiting /home, so there is nothing to return from and nothing worth
      // remembering. Classified deliberately, not by omission.
      if (requiresAppAdmin(path) && !appAdmin.isAdmin) {
        return gateRedirect(
          gate: '/home',
          target: currentLocation,
          kind: ExitKind.terminalDenial,
        );
      }

      // Platform admins bypass all institution membership gates — the backend
      // enforces INSTITUTIONS_READ/WRITE via its own bypass logic.
      if (!appAdmin.isAdmin) {
        // A PERSON WITHOUT STANDING IS TOLD SO — NOT ASKED TO LOG IN AGAIN.
        //
        // Founder ruling D5/D6, and the frozen doctrine that institution
        // standing is a RELATIONSHIP a person holds, never a second account.
        // This gate used to send them to `/enter-institution`, which asks for
        // an institution email and password and offers to create an
        // institutional account — the legacy model, in which an institution
        // was its own login. Android certification caught it: an already
        // authenticated member, named in the header, was shown "Institution
        // sign in — Private institutional access".
        //
        // That is the same shape as the 2026-08-14 meetings regression
        // (institutionId-in-path != institution-actor identity), on a
        // different route family, and it contradicted the standing route
        // declared a few lines below in this very file: standing "never
        // pretends the person entered".
        //
        // Terminal, like the `/home` denial above: there is nothing here for
        // the person to pass. The standing surface states what they hold and
        // carries the legitimate way to obtain more — which is onboarding an
        // institution, not signing into one.
        if (requiresInstitutionAccess(path) && !institutionAccess.hasAccess) {
          return gateRedirect(
            gate: kInstitutionNoAffiliationDestination,
            target: currentLocation,
            kind: ExitKind.terminalDenial,
          );
        }

        final isInstitutionAdmin =
            institutionAccess.state == InstitutionAccessState.authorizedSpeaker;
        final isInstitutionSpeakerOrAdmin =
            institutionAccess.state ==
                InstitutionAccessState.authorizedSpeaker ||
            institutionAccess.state == InstitutionAccessState.verifiedMember;

        // RC4 — TERMINAL DENIAL, both. Standing inside an institution is
        // granted by that institution, never by arriving at the dashboard.
        // Remembering the destination would only redirect the person back
        // into the same refusal.
        if (requiresInstitutionAdmin(path) && !isInstitutionAdmin) {
          return gateRedirect(
            // RC4 terminal denial -- deliberately NOT the entry destination.
            // A person refused admin standing has not thereby earned the
            // workspace front door.
            gate: kInstitutionDenialDestination,
            target: currentLocation,
            kind: ExitKind.terminalDenial,
          );
        }

        if (requiresInstitutionAdminOrSpeaker(path) &&
            !isInstitutionSpeakerOrAdmin) {
          return gateRedirect(
            // RC4 terminal denial -- see above.
            gate: kInstitutionDenialDestination,
            target: currentLocation,
            kind: ExitKind.terminalDenial,
          );
        }
      }

      return null;
    },
    routes: [
      GoRoute(
        path: kRouterBootRoute,
        builder: (_, __) => const _RouterBootScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) {
          return AppShell(child: child);
        },
        routes: [
          GoRoute(path: '/', builder: (_, __) => const PublicHomeScreen()),
          GoRoute(path: '/auth', redirect: (_, __) => '/login'),

          // Public routes
          GoRoute(
            path: '/public',
            builder: (_, __) => const PublicHomeScreen(),
          ),
          GoRoute(path: '/mission', builder: (_, __) => const MissionScreen()),
          GoRoute(
            path: '/white-paper',
            builder: (_, __) => const WhitePaperScreen(),
          ),
          GoRoute(
            path: '/founder',
            builder: (_, __) => const FounderMessageScreen(),
          ),
          GoRoute(
            path: '/privacy',
            builder: (_, __) => const PrivacyPolicyScreen(),
          ),
          GoRoute(path: '/terms', builder: (_, __) => const TermsScreen()),
          GoRoute(
            path: '/child-safety',
            builder: (_, __) => const ChildSafetyScreen(),
          ),
          GoRoute(path: '/safety', redirect: (_, __) => '/child-safety'),
          GoRoute(path: '/trust-safety', redirect: (_, __) => '/child-safety'),
          GoRoute(path: '/contact', builder: (_, __) => const ContactScreen()),
          GoRoute(
            path: '/support/agent',
            builder: (_, __) => const SupportAgentScreen(),
          ),
          GoRoute(
            path: '/account-deletion',
            builder: (_, __) => const AccountDeletionScreen(),
          ),
          GoRoute(
            path: '/investors',
            builder: (_, __) => const InvestorsHubScreen(),
          ),
          GoRoute(
            path: '/institutions',
            builder: (_, __) => const InstitutionsHubScreen(),
          ),
          // Static routes under /institutions/ must come before the dynamic
          // :slug route so GoRouter's first-match-wins order picks them up.
          GoRoute(
            path: kInstitutionGetStartedRoute,
            builder: (context, state) => InstitutionOnboardingWizard(
              mode: state.uri.queryParameters['mode'],
              inviteCode: state.uri.queryParameters['code'],
            ),
          ),
          // Sector landing — `/institutions/sector/:classId`. Renders an
          // ecosystem-style page scoped to a single curated ontology
          // class (e.g., GOVERNMENT, HEALTHCARE). MUST be registered
          // before the dynamic `/institutions/:slug` route so the
          // first-match-wins router resolves `sector` here, not as a
          // slug.
          GoRoute(
            path: '/institutions/sector/:classId',
            builder: (context, state) => InstitutionSectorScreen(
              classId: state.pathParameters['classId'] ?? '',
            ),
          ),
          GoRoute(
            path: '/institutions/:slug',
            redirect: (context, state) {
              // Guard against reserved keywords escaping past static routes.
              // `sector` is the prefix for the sector-landing route
              // (`/institutions/sector/:classId`); landing on
              // `/institutions/sector` alone (no classId) bounces back to
              // the directory rather than misinterpreting `sector` as an
              // institution slug.
              const reserved = {'get-started', 'sector'};
              final slug = state.pathParameters['slug'] ?? '';
              if (slug == 'get-started') return kInstitutionGetStartedRoute;
              if (reserved.contains(slug)) return '/institutions';
              return null;
            },
            builder: (context, state) => InstitutionDetailScreen(
              slug: state.pathParameters['slug'] ?? '',
            ),
          ),
          // Public listing of an institution's units (sub-entities). The
          // detail screen at `/institutions/:slug` already exists; this
          // route surfaces the unit roster as a stand-alone page so the
          // institutional topology — "Aura Platform LLC → Aura,
          // Orchestrate" — is browsable without sign-in.
          GoRoute(
            path: '/institutions/:slug/units',
            builder: (context, state) => PublicInstitutionUnitsScreen(
              slug: state.pathParameters['slug'] ?? '',
            ),
          ),
          GoRoute(
            path: '/institutions/:slug/units/:unitSlug',
            builder: (context, state) => PublicUnitDetailScreen(
              slug: state.pathParameters['slug'] ?? '',
              unitSlug: state.pathParameters['unitSlug'] ?? '',
            ),
          ),
          GoRoute(path: '/institution/sign-in', redirect: (_, __) => '/login'),
          GoRoute(
            path: kInstitutionCreateRoute,
            redirect: (_, __) => '$kInstitutionGetStartedRoute?mode=create',
          ),
          GoRoute(
            path: '/patrons',
            builder: (_, __) => const PatronsHubScreen(),
          ),
          GoRoute(
            path: '/supporters',
            builder: (_, __) => const SupportersHubScreen(),
          ),
          GoRoute(
            path: '/announcements',
            builder: (_, __) => const AnnouncementsScreen(),
          ),
          GoRoute(
            path: '/announcements/create',
            builder: (context, state) {
              final scope = (state.uri.queryParameters['scope'] ?? '')
                  .trim()
                  .toLowerCase();
              final editorScope = scope == 'institution'
                  ? AnnouncementEditorScope.institution
                  : AnnouncementEditorScope.platform;
              return AnnouncementEditorScreen(scope: editorScope);
            },
          ),
          GoRoute(
            path: '/announcements/:slug',
            builder: (context, state) => AnnouncementDetailScreen(
              slug: state.pathParameters['slug'] ?? '',
            ),
          ),
          // Public booking pages — no auth required (Calendly replacement)
          // These MUST appear before the ShellRoute member routes because
          // /meet/:slug is public and must not require authentication.
          GoRoute(
            path: '/meet/:slug',
            builder: (context, state) =>
                PublicBookingScreen(slug: state.pathParameters['slug'] ?? ''),
          ),
          // RC8 — the subject of this route lives in the ROUTE, not in the
          // in-memory object the previous screen was holding. It used to fall
          // through to a booking page for NOBODY on any refresh, bookmark or
          // shared link — with the slug sitting right there in the path it
          // was standing on.
          GoRoute(
            path: '/meet/:slug/book',
            builder: (context, state) => BookingRouteEntry(
              slug: state.pathParameters['slug'] ?? '',
              slot: slotFromQuery(state.uri.queryParameters),
              durationMinutes: int.tryParse(
                state.uri.queryParameters['duration'] ?? '',
              ),
            ),
          ),

          // SEARCH IS DISCOVER, NOT A SEPARATE SCREEN.
          //
          // The address stays — governed tag taps arrive here as
          // `/search?q=...` and older links still point at it — but it now
          // renders the Discover surface in its searching state rather than a
          // second search product with its own results, its own empty state
          // and its own idea of what a result is.
          //
          // A query in the address is applied to the same state the field
          // publishes, so arriving with `?q=` and typing by hand end in
          // exactly the same place.
          GoRoute(
            path: '/search',
            builder: (_, state) {
              final q = (state.uri.queryParameters['q'] ?? '').trim();
              return _DiscoverSearchEntryPoint(seedQuery: q);
            },
          ),
          // C3 — DISCOVER: founder-frozen consolidated discovery intention.
          GoRoute(
            path: '/discover',
            builder: (_, __) => const DiscoverScreen(),
          ),
          GoRoute(
            path: '/posts/:id',
            builder: (context, state) =>
                PostDetailScreen(postId: state.pathParameters['id'] ?? ''),
          ),
          // CH-12 E6 — the member's route back from a restricted attachment.
          // D3's chain ends in an APPEAL a person can actually reach, and this
          // is where a quarantine notice lands. The screen shows nothing at all
          // to a caller without standing, so the path is safe to hold a raw
          // media id.
          GoRoute(
            path: '/media/:id/restricted',
            builder: (context, state) => RestrictedMediaScreen(
              mediaId: state.pathParameters['id'] ?? '',
            ),
          ),
          // Public-UX generalized thread surface — works for both user
          // posts and institution posts via the existing
          // `feedItemDetailProvider` / `feedItemRepliesProvider`. The
          // legacy `/posts/:id` and `/institution/:id/posts/:postId`
          // routes are unchanged.
          GoRoute(
            path: '/thread/:id',
            builder: (context, state) {
              final qp = state.uri.queryParameters;
              final wireType = (qp['type'] ?? '').toUpperCase();
              final type = wireType == 'INSTITUTION_POST'
                  ? FeedItemType.institutionPost
                  : FeedItemType.userPost;
              return ThreadScreen(
                postId: state.pathParameters['id'] ?? '',
                type: type,
                parentInstitutionId: qp['parentInstitutionId'],
                // Phase 6.1 — entry-accuracy hints. `focus` selects a
                // named anchor (timeline / first-official / last-reply);
                // `replyId` deep-links to a specific reply.
                focusTarget: qp['focus'],
                focusReplyId: qp['replyId'],
              );
            },
          ),
          // Public-UX Phase 2 — Spaces.
          GoRoute(
            path: '/spaces',
            builder: (_, __) => const SpacesDiscoveryScreen(),
          ),
          GoRoute(
            path: '/spaces/:slug',
            builder: (_, state) =>
                SpaceDetailScreen(slug: state.pathParameters['slug'] ?? ''),
          ),
          // Public-UX Phase 2 — Transparency page.
          GoRoute(
            path: '/aura/participation',
            builder: (_, __) => const TransparencyScreen(),
          ),
          GoRoute(
            path: '/author/:handle',
            redirect: (context, state) {
              final handle = state.pathParameters['handle'] ?? '';
              return '/u/$handle';
            },
          ),
          GoRoute(
            path: '/u/:handle',
            builder: (context, state) => AuthorProfileScreen(
              handle: state.pathParameters['handle'] ?? '',
            ),
          ),
          GoRoute(
            path: '/u/:handle/followers',
            builder: (context, state) =>
                FollowersScreen(handle: state.pathParameters['handle'] ?? ''),
          ),
          GoRoute(
            path: '/u/:handle/following',
            builder: (context, state) =>
                FollowingScreen(handle: state.pathParameters['handle'] ?? ''),
          ),
          GoRoute(
            path: '/support/:handle',
            builder: (context, state) => SupportFallbackScreen(
              handle: state.pathParameters['handle'] ?? '',
            ),
          ),

          // Auth routes
          GoRoute(
            path: '/login',
            builder: (context, state) => AuthScreen(
              redirectTo: state.uri.queryParameters['redirect'],
              email: state.uri.queryParameters['email'],
              notice: state.uri.queryParameters['verified'] == '1'
                  ? 'verified'
                  : (state.uri.queryParameters['reset'] == '1'
                        ? 'reset'
                        : null),
            ),
          ),
          GoRoute(
            path: '/register',
            builder: (context, state) => RegisterScreen(
              redirectTo: state.uri.queryParameters['redirect'],
            ),
          ),
          GoRoute(
            path: '/forgot-password',
            builder: (_, __) => const ForgotPasswordScreen(),
          ),
          GoRoute(
            path: '/reset-password',
            builder: (context, state) => ResetPasswordScreen(
              token: state.uri.queryParameters['token'],
              email: state.uri.queryParameters['email'],
              redirectTo: state.uri.queryParameters['redirect'],
            ),
          ),
          GoRoute(
            path: '/verify-email',
            builder: (context, state) => VerifyEmailScreen(
              token: state.uri.queryParameters['token'],
              email: state.uri.queryParameters['email'],
              redirectTo: state.uri.queryParameters['redirect'],
              verified: _queryBool(state.uri.queryParameters['verified']),
            ),
          ),
          GoRoute(
            path: '/verify-pending',
            builder: (context, state) => VerifyPendingScreen(
              email: state.uri.queryParameters['email'],
              redirectTo: state.uri.queryParameters['redirect'],
              emailSent:
                  _queryBool(state.uri.queryParameters['emailSent']) ||
                  state.uri.queryParameters['emailSent'] == null,
            ),
          ),
          GoRoute(
            path: kCompleteIdentityRoute,
            builder: (context, state) => IdentityBaselineScreen(
              redirectTo: state.uri.queryParameters['redirect'],
            ),
          ),

          // Member + institution routes
          GoRoute(path: '/home', builder: (_, __) => const MemberHomeScreen()),

          // ── Meetings ─────────────────────────────────────────────────
          // MEETINGS ARE AN INSTITUTIONAL DOMAIN (founder ruling,
          // 2026-08-16): the institution owns the meeting lifecycle; a
          // member's relationship is contextual — booking, invitation /
          // attention, Me → Participations, and direct deep links below.
          // There is deliberately NO bare `/meetings` destination and no
          // personal meetings home; Meetings is not a primary. IMPORTANT:
          // static paths (/meetings/join/:code) must appear BEFORE the
          // dynamic /meetings/:id route so GoRouter's first-match-wins
          // order resolves them correctly.
          GoRoute(
            path: '/institution/:institutionId/meetings',
            builder: (context, state) => InstitutionRouteScope(
              address: state.pathParameters['institutionId'],
              builder: (institutionId) =>
                  MeetingsHomeScreen(institutionId: institutionId),
            ),
          ),
          // Institution-owned scheduling — created meetings carry the
          // institution's ownership from birth.
          GoRoute(
            path: '/institution/:institutionId/meetings/new',
            builder: (context, state) => InstitutionRouteScope(
              address: state.pathParameters['institutionId'],
              builder: (institutionId) => CreateMeetingScreen(
                institutionId: institutionId,
                startNow:
                    state.uri.queryParameters['instant'] == '1' ||
                    state.uri.queryParameters['instant'] == 'true',
              ),
            ),
          ),
          // Codeless recovery route — MUST precede `/meetings/join/:code` and
          // `/meetings/:id`. Older emails shipped a codeless `/meetings/join`
          // button; without this it fell through to `/meetings/:id` (id="join")
          // → 404 → DioException. Renders a guest-safe code-entry fallback.
          GoRoute(
            path: '/meetings/join',
            builder: (context, state) => const MeetingJoinFallbackScreen(),
          ),
          // Participant continuity — after sign-in/registration the booking
          // reference (`bt`) attaches the booked meeting to the member's
          // account and lands on the meeting record. Static path: MUST
          // precede `/meetings/:id`.
          GoRoute(
            path: '/meetings/keep',
            builder: (context, state) => KeepMeetingScreen(
              bookerToken: state.uri.queryParameters['bt'],
              meetingCode: state.uri.queryParameters['code'],
            ),
          ),
          // Guest-safe terminal fallback — a MEETING context that could not be
          // resolved must land here, never on the generic RealtimeRoomScreen.
          GoRoute(
            path: '/meetings/join-error',
            builder: (context, state) => MeetingJoinErrorScreen(
              meetingId: state.uri.queryParameters['meetingId'],
              sessionId: state.uri.queryParameters['sessionId'],
              code: state.uri.queryParameters['code'],
              guestId: state.uri.queryParameters['guestId'],
              reason: state.uri.queryParameters['reason'],
            ),
          ),
          GoRoute(
            path: '/meetings/join/:code',
            builder: (context, state) => PreJoinScreen(
              meetingCode: state.pathParameters['code'] ?? '',
              bookerToken: state.uri.queryParameters['bt'],
              // Invitation proof (`in`) — participation evidence carried by
              // emailed invitation links; preserved through login returns.
              invitationToken: state.uri.queryParameters['in'],
            ),
          ),
          GoRoute(
            path: '/meetings/:id',
            builder: (context, state) => MeetingDetailScreen(
              meetingId: state.pathParameters['id'] ?? '',
            ),
          ),
          // MEETING RECORD ALIASES - CANONICALISED (founder ruling
          // 2026-08-25 §XII).
          //
          // `/prep`, `/room`, `/summary` and `/post-meeting` each BUILT the
          // record screen with identical arguments — the screen has no
          // section parameter, so the four names named nothing. `/room` was
          // the actively misleading one: it promised the live room and
          // rendered the record, while the real room sat at `/live`.
          //
          // They now REDIRECT to the canonical record rather than rendering a
          // second copy of it, so a bookmark still works and the address bar
          // ends up telling the truth. One destination, one URL, four
          // historical doors into it.
          GoRoute(
            path: '/meetings/:meetingId/prep',
            redirect: (context, state) =>
                '/meetings/${state.pathParameters['meetingId'] ?? ''}',
          ),
          // Lobby retired: the Meeting Record is the doorway to the room.
          // Guests never land here anymore (pre-join routes straight to
          // /live); members see the record with its Enter room banner.
          GoRoute(
            path: '/meetings/:meetingId/room',
            redirect: (context, state) =>
                '/meetings/${state.pathParameters['meetingId'] ?? ''}',
          ),
          GoRoute(
            path: '/meetings/:meetingId/waiting',
            builder: (context, state) => GuestWaitingRoomScreen(
              meetingId: state.pathParameters['meetingId'] ?? '',
              sessionId: state.uri.queryParameters['sessionId'],
              returnTo: state.uri.queryParameters['returnTo'],
              meetingCode: state.uri.queryParameters['code'],
              guestId: state.uri.queryParameters['guestId'],
            ),
          ),
          GoRoute(
            path: '/meetings/:meetingId/live',
            builder: (context, state) => MeetingLiveRoomScreen(
              meetingId: state.pathParameters['meetingId'] ?? '',
              sessionId: state.uri.queryParameters['sessionId'] ?? '',
              isHost: state.uri.queryParameters['isHost'] == 'true',
              meetingCode: state.uri.queryParameters['code'],
              guestUserId: state.uri.queryParameters['guestId'],
            ),
          ),
          // Summary and workspace merged into the Meeting Record — one page
          // is the meeting before, during, and after. Old links keep working.
          GoRoute(
            path: '/meetings/:meetingId/summary',
            redirect: (context, state) =>
                '/meetings/${state.pathParameters['meetingId'] ?? ''}',
          ),
          GoRoute(
            path: '/meetings/:meetingId/post-meeting',
            redirect: (context, state) =>
                '/meetings/${state.pathParameters['meetingId'] ?? ''}',
          ),
          GoRoute(
            path: '/institution/:institutionId/meetings/:meetingId',
            builder: (context, state) => InstitutionRouteScope(
              address: state.pathParameters['institutionId'],
              builder: (institutionId) => MeetingDetailScreen(
                meetingId: state.pathParameters['meetingId'] ?? '',
                institutionId: institutionId,
              ),
            ),
          ),
          GoRoute(
            path: '/institution/:institutionId/meetings/:meetingId/prep',
            redirect: (context, state) =>
                '/institution/${state.pathParameters['institutionId'] ?? ''}'
                '/meetings/${state.pathParameters['meetingId'] ?? ''}',
          ),
          GoRoute(
            path: '/institution/:institutionId/meetings/:meetingId/room',
            redirect: (context, state) =>
                '/institution/${state.pathParameters['institutionId'] ?? ''}'
                '/meetings/${state.pathParameters['meetingId'] ?? ''}',
          ),
          GoRoute(
            path: '/institution/:institutionId/meetings/:meetingId/waiting',
            builder: (context, state) => InstitutionRouteScope(
              address: state.pathParameters['institutionId'],
              builder: (institutionId) => GuestWaitingRoomScreen(
                meetingId: state.pathParameters['meetingId'] ?? '',
                institutionId: institutionId,
                sessionId: state.uri.queryParameters['sessionId'],
                returnTo: state.uri.queryParameters['returnTo'],
                guestId: state.uri.queryParameters['guestId'],
              ),
            ),
          ),
          GoRoute(
            path: '/institution/:institutionId/meetings/:meetingId/live',
            builder: (context, state) => InstitutionRouteScope(
              address: state.pathParameters['institutionId'],
              builder: (institutionId) => MeetingLiveRoomScreen(
                meetingId: state.pathParameters['meetingId'] ?? '',
                institutionId: institutionId,
                sessionId: state.uri.queryParameters['sessionId'] ?? '',
                isHost: state.uri.queryParameters['isHost'] == 'true',
                meetingCode: state.uri.queryParameters['code'],
                guestUserId: state.uri.queryParameters['guestId'],
              ),
            ),
          ),
          GoRoute(
            path: '/institution/:institutionId/meetings/:meetingId/summary',
            redirect: (context, state) =>
                '/institution/${state.pathParameters['institutionId'] ?? ''}'
                '/meetings/${state.pathParameters['meetingId'] ?? ''}',
          ),
          GoRoute(
            path: '/institution/:institutionId/meetings/:meetingId/post-meeting',
            redirect: (context, state) =>
                '/institution/${state.pathParameters['institutionId'] ?? ''}'
                '/meetings/${state.pathParameters['meetingId'] ?? ''}',
          ),
          // Institution admin booking pages — gated by InstitutionRoleGuard (ADMIN) on backend
          GoRoute(
            path: '/institution/:institutionId/availability',
            // Booking PAGES management, not the public booking surface -- that
            // lives unauthenticated at /i/:slug/meet/:bookingSlug. An earlier
            // audit filed this as a context destination on the strength of the
            // word "booking"; the route it serves says otherwise.
            redirect: (context, state) => _enforceCanonicalIdMatch(
              ref,
              state,
              state.pathParameters['institutionId'],
              'availability',
            ),
            builder: (context, state) => InstitutionRouteScope(
              address: state.pathParameters['institutionId'],
              builder: (institutionId) =>
                  InstitutionAvailabilityScreen(institutionId: institutionId),
            ),
          ),
          // Institution-owned public booking — /i/:institutionSlug/meet/:bookingSlug
          // These are public (no auth) but still inside ShellRoute for the app chrome.
          GoRoute(
            path: '/i/:institutionSlug/meet/:bookingSlug',
            builder: (context, state) => InstitutionPublicBookingScreen(
              institutionSlug: state.pathParameters['institutionSlug'] ?? '',
              bookingSlug: state.pathParameters['bookingSlug'] ?? '',
            ),
          ),
          // Cancel link from booking confirmation email
          GoRoute(
            path: '/i/:institutionSlug/meet/cancel/:token',
            builder: (context, state) =>
                BookingCancelScreen(token: state.pathParameters['token'] ?? ''),
          ),
          GoRoute(
            path: '/meet/cancel/:token',
            builder: (context, state) =>
                BookingCancelScreen(token: state.pathParameters['token'] ?? ''),
          ),
          // H4: reschedule routes
          GoRoute(
            path: '/i/:institutionSlug/meet/reschedule/:token',
            // RC8 — reached from a confirmation EMAIL, which carries no
            // in-app state, so this route never worked at all: it fell
            // through to a CANCEL screen with the token discarded. The token
            // now names the booking, and the BOOKING's own state decides
            // whether a reschedule is offered.
            builder: (context, state) => RescheduleRouteEntry(
              token: state.pathParameters['token'] ?? '',
            ),
          ),
          GoRoute(
            path: '/meet/reschedule/:token',
            // RC8 — reached from a confirmation EMAIL, which carries no
            // in-app state, so this route never worked at all: it fell
            // through to a CANCEL screen with the token discarded. The token
            // now names the booking, and the BOOKING's own state decides
            // whether a reschedule is offered.
            builder: (context, state) => RescheduleRouteEntry(
              token: state.pathParameters['token'] ?? '',
            ),
          ),
          GoRoute(
            path: '/i/:institutionSlug/meet/:bookingSlug/book',
            // RC8 — same correction as the personal booking route: the
            // subject lives in the route, not in whatever object the previous
            // screen was holding.
            builder: (context, state) => BookingRouteEntry(
              slug: state.pathParameters['bookingSlug'] ?? '',
              institutionSlug: state.pathParameters['institutionSlug'],
              slot: slotFromQuery(state.uri.queryParameters),
              durationMinutes: int.tryParse(
                state.uri.queryParameters['duration'] ?? '',
              ),
            ),
          ),
          // /messages — restored to MessagesHubScreen (existing
          // conversations/spaces/invites). The new actor-aware direct
          // inbox is mounted as a sub-route at /messages/direct so it's
          // an addition, not a replacement.
          // ── AURA CONVERSATION SYSTEM (canon 2026-08-16) ─────────────
          // MESSAGES = where my Conversations live. One list, one screen,
          // one composer, one creation flow. The legacy hub and its
          // routes retire in the transition phase after history
          // migration; until then their addresses remain reachable.
          GoRoute(
            path: kMessagesRoute,
            builder: (_, __) => const MessagesScreen(),
          ),
          GoRoute(
            path: '/messages/new',
            builder: (_, state) {
              // A profile's "Invite to space" arrives carrying handle/name/
              // userId. These were dropped on the floor, so the picker opened
              // empty and the person searched again for whoever they had just
              // been reading about.
              final q = state.uri.queryParameters;
              final prefill = (q['handle'] ?? '').trim().isNotEmpty
                  ? q['handle']!.trim()
                  : (q['name'] ?? '').trim();
              return NewConversationPicker(
                initialQuery: prefill.isEmpty ? null : prefill,
              );
            },
          ),
          GoRoute(
            path: '/messages/c/:conversationId',
            builder: (context, state) => ConversationScreen(
              conversationId: state.pathParameters['conversationId'] ?? '',
            ),
          ),
          // Discover → People: personalized human discovery (frozen).
          GoRoute(
            path: '/discover/people',
            builder: (_, __) => const PeopleDiscoveryScreen(),
          ),
          // AURA ARTICLES (founder addendum 2026-08-16): the fourth
          // Discover domain, now REAL. Reading is public product surface;
          // authoring is the author's own.
          GoRoute(
            path: '/discover/articles',
            builder: (_, __) => const ArticlesDiscoveryScreen(),
          ),
          // INSTITUTIONS DISCOVERY — the domain destination.
          //
          // `/institutions` remains the PUBLIC directory it has always been;
          // this is the discovery experience the Discover landing opens, where
          // relevance orders the ecosystem and the sector ontology finally has
          // a place that is not a wall on the general landing.
          GoRoute(
            path: '/discover/institutions',
            builder: (_, __) => const InstitutionsDiscoveryScreen(),
          ),
          GoRoute(
            path: '/articles/write',
            builder: (_, __) => const ArticleEditorScreen(),
          ),
          GoRoute(
            path: '/articles/write/:articleId',
            builder: (context, state) => ArticleEditorScreen(
              articleId: state.pathParameters['articleId'],
            ),
          ),
          // Product feedback. Authed but otherwise ungated: someone who cannot
          // yet do anything in Aura is often exactly the person with something
          // worth hearing about why.
          GoRoute(
            path: '/feedback',
            builder: (context, state) => const FeedbackScreen(),
          ),
          GoRoute(
            path: '/feedback/mine',
            builder: (context, state) => const MyFeedbackScreen(),
          ),
          GoRoute(
            path: '/articles/:slug',
            builder: (context, state) =>
                ArticleScreen(slug: state.pathParameters['slug'] ?? ''),
          ),
          // External invitation claim landing — PUBLIC by nature (the
          // recipient may not have an account). Single-segment /i/:token;
          // the /i/:slug/meet/... booking namespace is 3+ segments.
          GoRoute(
            path: '/i/:token',
            builder: (context, state) => ClaimInvitationScreen(
              token: state.pathParameters['token'] ?? '',
            ),
          ),
          // /messages/legacy-hub RETIRED with the correspondence family.
          // Canonical /messages has served this purpose since the additive
          // deploy; the parked predecessor is removed, not the product.
          // THE LEGACY DIRECT INBOX IS RETIRED, ITS ADDRESSES ARE NOT.
          //
          // These listed correspondence from the DirectThread authority, whose
          // content was reconciled into Conversation on 2026-08-23. Keeping
          // them rendering meant two inboxes over one body of correspondence,
          // where only one of them was being kept true. Archived is a filter
          // on the canonical inbox, not a separate place, so both addresses
          // have the same canonical answer.
          GoRoute(
            path: '$kMessagesRoute/direct',
            redirect: (_, __) => kMessagesRoute,
          ),
          GoRoute(
            path: '$kMessagesRoute/direct/archived',
            redirect: (_, __) => kMessagesRoute,
          ),
          GoRoute(path: '/create', builder: (_, __) => const CreateHubScreen()),
          GoRoute(path: '/saved', builder: (_, __) => const SavedScreen()),
          GoRoute(path: '/updates', builder: (_, __) => const UpdatesScreen()),
          GoRoute(path: '/conversations', redirect: (_, __) => kMessagesRoute),
          GoRoute(
            path: '/activity',
            builder: (_, __) => const ActivityScreen(),
          ),
          GoRoute(
            path: '/ai/claim-audit',
            builder: (_, __) => const ClaimAuditScreen(),
          ),
          GoRoute(path: '/me', builder: (_, __) => const MeScreen()),
          GoRoute(
            path: '/me/edit',
            builder: (_, __) => const EditProfileScreen(),
          ),
          GoRoute(
            path: '/security',
            builder: (_, __) => const SecurityScreen(),
          ),
          GoRoute(
            path: NavigationAuthority.identityVerificationRoute,
            builder: (_, __) => const IdentityVerificationScreen(),
          ),
          GoRoute(path: '/devices', builder: (_, __) => const DevicesScreen()),
          GoRoute(
            path: '/change-password',
            builder: (_, __) => const ChangePasswordScreen(),
          ),
          GoRoute(
            path: '/settings/communications',
            redirect: (_, __) => kMeCommunicationsRoute,
          ),
          GoRoute(
            // THE PREFERENCES LANDING.
            //
            // Both navigation entries pointed at narrower screens —
            // "Preferences" opened notifications and "Settings" opened
            // security — so the question "where do I change how Aura works
            // for me" had no answer anywhere in the product.
            path: kMePreferencesRoute,
            builder: (_, __) => const PreferencesScreen(),
          ),
          GoRoute(
            // An authority that already supported unblocking and had no
            // surface offering it.
            path: kMeBlockedRoute,
            builder: (_, __) => const BlockedPeopleScreen(),
          ),
          GoRoute(
            path: kMeCommunicationsRoute,
            builder: (_, __) => const CommunicationsCenterScreen(),
          ),
          GoRoute(
            path: '/me/follow-requests',
            builder: (_, __) => const FollowRequestsScreen(),
          ),
          GoRoute(
            path: '/me/invitations',
            builder: (_, __) => const InvitationsScreen(),
          ),
          GoRoute(
            path: '/invite',
            builder: (context, state) => InviteHubScreen(
              spaceId: state.uri.queryParameters['spaceId'],
              threadId: state.uri.queryParameters['threadId'],
              returnTo: state.uri.queryParameters['returnTo'],
            ),
          ),
          GoRoute(
            path: '/invite/create',
            builder: (context, state) => InviteCreateScreen(
              destinationType:
                  (state.uri.queryParameters['destinationType'] ?? 'JOIN_AURA')
                      .trim()
                      .toUpperCase(),
              spaceId: state.uri.queryParameters['spaceId'],
              threadId: state.uri.queryParameters['threadId'],
              returnTo: state.uri.queryParameters['returnTo'],
            ),
          ),
          GoRoute(
            path: '/invite/accept',
            builder: (context, state) => InviteAcceptScreen(
              token: state.uri.queryParameters['token'] ?? '',
            ),
          ),
          GoRoute(
            path: '/invite/import',
            builder: (context, state) => ContactImportScreen(
              spaceId: state.uri.queryParameters['spaceId'],
              institutionId: state.uri.queryParameters['institutionId'],
            ),
          ),
          GoRoute(
            path: kAdminWorkspaceRoute,
            builder: (_, __) => const AdminWorkspaceScreen(),
          ),
          GoRoute(
            path: kAdminCommunicationsRoute,
            builder: (_, __) => const AdminCommunicationsScreen(),
          ),
          GoRoute(
            path: '/admin/institutions',
            builder: (_, __) => const AdminInstitutionsScreen(),
          ),
          GoRoute(
            path: '/admin/institutions/:id/members',
            builder: (_, state) => AdminInstitutionMembersScreen(
              institutionId: state.pathParameters['id']!,
              institutionName: state.uri.queryParameters['name'],
            ),
          ),
          GoRoute(
            path: '/admin/users',
            builder: (_, __) => const AdminUsersScreen(),
          ),
          GoRoute(
            path: '/admin/identity-review',
            builder: (_, __) => const IdentityReviewScreen(),
          ),
          // Product feedback triage lives in the SAME admin console family as
          // identity review and moderation — not a second administration
          // universe with its own navigation and its own idea of authority.
          GoRoute(
            path: '/admin/feedback',
            builder: (_, __) => const FeedbackConsoleScreen(),
          ),
          GoRoute(
            path: '/admin/grants',
            builder: (_, __) => const AdminGrantsScreen(),
          ),
          GoRoute(
            path: '/admin/audit-logs',
            builder: (_, __) => const AdminAuditLogsScreen(),
          ),
          GoRoute(
            path: '/admin/settings',
            builder: (_, __) => const AdminSettingsScreen(),
          ),
          GoRoute(
            path: '/admin/feature-flags',
            builder: (_, __) => const AdminFeatureFlagsScreen(),
          ),
          GoRoute(
            path: '/admin/institution-domains',
            builder: (_, __) => const AdminInstitutionDomainsScreen(),
          ),
          GoRoute(
            path: '/admin/review-queue',
            builder: (_, __) => const AdminReviewQueueScreen(),
          ),
          GoRoute(
            path: '/admin/migrations',
            builder: (_, __) => const AdminMigrationsScreen(),
          ),
          GoRoute(
            path: '/admin/policies',
            builder: (_, __) => const AdminPoliciesScreen(),
          ),
          GoRoute(
            path: '/admin/moderation',
            builder: (_, __) => const AdminModerationScreen(),
          ),
          // CH-12 E6 — the reviewer's side of the governed route back. Sits in
          // the existing admin shell under the same MODERATION_READ /
          // MODERATION_WRITE authority the moderation queue already uses.
          GoRoute(
            path: '/admin/media-appeals',
            builder: (_, __) => const AdminMediaAppealsScreen(),
          ),
          GoRoute(
            path: '/admin/support',
            builder: (_, __) => const AdminSupportConsoleScreen(),
          ),

          // CO-RC-C7-005 PHASE 5 (2026-08-20): the personal correspondence
          // route family is RETIRED. `/me/correspondence` and its space,
          // thread, invite, archived and live sub-routes are gone, and with
          // them every path by which product traffic could enter the legacy
          // Thread/Message runtime.
          //
          // Founder ruling: addresses whose only destination was abandoned
          // legacy history may expire. No translator replaces them — a
          // compatibility subsystem to preserve content the founder has
          // ruled worthless would be the same fossil with a redirect in
          // front of it.
          //
          // Canonical messaging is unaffected and lives at /messages.
          // SHARE — the content-first creation intention.
          //
          // A sibling of /compose rather than a mode of it. `/compose` is
          // discourse-first and owns text, topics, tags and external
          // distribution; Share starts from content that already exists and
          // asks where it should go. They converge beneath the surface on one
          // acquisition module, one draft type, one preview and one upload --
          // different entrances, one content system.
          GoRoute(
            path: '/share',
            builder: (context, state) => const ShareScreen(),
          ),
          GoRoute(
            path: '/compose',
            builder: (context, state) {
              final asInstitution = _queryBool(
                state.uri.queryParameters['asInstitution'],
              );
              return ComposeScreen(
                replyToPostId: state.uri.queryParameters['replyTo'],
                replyToInstitutionPostId:
                    state.uri.queryParameters['replyToInstitutionPostId'],
                parentInstitutionId:
                    state.uri.queryParameters['parentInstitutionId'],
                heldPostId: state.uri.queryParameters['held'],
                editPostId: state.uri.queryParameters['edit'],
                surface: state.uri.queryParameters['surface'],
                mode: state.uri.queryParameters['mode'],
                asInstitution: asInstitution,
                institutionId: state.uri.queryParameters['institutionId']
                    ?.trim(),
                publicSpaceId: state.uri.queryParameters['publicSpaceId']
                    ?.trim(),
                publicSpaceName: state.uri.queryParameters['publicSpaceName']
                    ?.trim(),
                publicSpaceSlug: state.uri.queryParameters['publicSpaceSlug']
                    ?.trim(),
                intent: state.uri.queryParameters['intent']?.trim(),
                continuesPostId: state.uri.queryParameters['continuesPostId']
                    ?.trim(),
              );
            },
          ),
          GoRoute(
            path: '/posts/:postId/edit',
            builder: (context, state) => ComposeScreen(
              editPostId: state.pathParameters['postId']?.trim(),
            ),
          ),
          GoRoute(
            path: kEnterInstitutionRoute,
            builder: (_, __) => const InstitutionSignInScreen(),
          ),
          // ── Institution workspace routing ─────────────────────────
          //
          // Routing-hardening pass — every institution-scoped section
          // is reachable through a canonical `/institution/:id/<section>`
          // route. Legacy `/institution/<section>` shorthands are now
          // pure redirect helpers; they never render a screen.
          //
          // Canonical routes carry a redirect guard that enforces the
          // rule "path id dominates provider": if a user lands on
          // `/institution/<other>/profile` while their active identity
          // is `<self>`, the router rewrites the URL to
          // `/institution/<self>/profile` before the screen builds. The
          // screens themselves are unchanged — they still hydrate
          // display data via `institutionIdentityProvider`, but the URL
          // is always consistent with that identity.
          //
          // The institution **dashboard** is intentionally left as a
          // global selector at `/institution/dashboard`. It loads
          // `/institutions/me` to discover the user's primary
          // institution and acts as the safe fallback when no id can be
          // resolved. The id-aware alias `/institution/:id/dashboard`
          // exists for symmetry and redirects to the global path.

          // STANDING — the non-workspace answer (founder ruling D5/D6).
          //
          // Terminal denial and "you hold no institution" used to resolve to
          // /institution/dashboard, which is also the Overview. Once Overview
          // became an ADMIN destination, a refusal would have landed a person
          // on an administrative surface. This is its own address, outside the
          // workspace shell, and it never pretends the person entered.
          GoRoute(
            path: kInstitutionStandingRoute,
            builder: (_, state) => InstitutionStandingScreen(
              reason: institutionStandingReasonFrom(
                state.uri.queryParameters['reason'],
              ),
            ),
          ),
          // The id-less Overview address is now a SHORTHAND, not a surface:
          // Overview is id-scoped and administrative, so this resolves to the
          // canonical address of the institution in context (where the same
          // authority check then applies) or to standing.
          GoRoute(
            path: kInstitutionDashboardRoute,
            redirect: (context, state) =>
                _redirectShorthandToCanonical(ref, state, 'dashboard'),
            builder: (_, __) => const Scaffold(
              body: AuraProductState(state: ProductState.loading),
            ),
          ),
          // OVERVIEW IS ADDRESSABLE (founder ruling, institution addendum).
          //
          // This used to redirect to the id-less address, which DISCARDED the
          // institution the URL named. A person holding two institutions could
          // not bookmark, link or refresh institution B's Overview: every
          // id-bearing address collapsed to whichever institution the ambient
          // membership happened to be. That is the same truthfulness defect
          // RC3 names -- a validated claim must be honoured, not swapped for
          // ambient state.
          //
          // The backend already answers per institution: `/institutions/me`
          // takes an optional `institutionId`, and the caller's own membership
          // of it is what authorises the answer. So the id travels to the
          // screen, and an id the person does not hold resolves through the
          // same authority every other canonical destination uses.
          GoRoute(
            path: '/institution/:institutionId/dashboard',
            redirect: (context, state) => _enforceCanonicalIdMatch(
              ref,
              state,
              state.pathParameters['institutionId'],
              'dashboard',
            ),
            builder: (context, state) => InstitutionRouteScope(
              address: state.pathParameters['institutionId'],
              builder: (institutionId) =>
                  InstitutionDashboardScreen(institutionId: institutionId),
            ),
          ),

          // Domains — shorthand redirects, canonical builds.
          GoRoute(
            path: kInstitutionDomainsRoute,
            redirect: (context, state) =>
                _redirectShorthandToCanonical(ref, state, 'domains'),
            // Rendered only while the institution authority is still
            // resolving; the redirect above takes over the instant it does.
            builder: (_, __) => const Scaffold(
              body: AuraProductState(state: ProductState.loading),
            ),
          ),
          GoRoute(
            path: '/institution/:institutionId/domains',
            redirect: (context, state) => _enforceCanonicalIdMatch(
              ref,
              state,
              state.pathParameters['institutionId'],
              'domains',
            ),
            builder: (_, state) => InstitutionRouteScope(
              address: state.pathParameters['institutionId'],
              builder: (institutionId) =>
                  InstitutionDomainsScreen(institutionId: institutionId),
            ),
          ),

          // Units (already canonical, kept here for proximity).
          // UNIT CONTEXT — inside the institution, not a second workspace.
          // Participation baseline: understanding a unit of the institution
          // you belong to is participation. What the viewer SEES inside is
          // decided by the server projection, and administering it is gated
          // separately on the Units surface.
          GoRoute(
            path: '/institution/:institutionId/units/:unitId',
            redirect: (context, state) => _enforceCanonicalIdMatch(
              ref,
              state,
              state.pathParameters['institutionId'],
              'units/context',
            ),
            builder: (context, state) => InstitutionRouteScope(
              address: state.pathParameters['institutionId'],
              builder: (institutionId) => InstitutionUnitContextScreen(
                institutionId: institutionId,
                unitId: state.pathParameters['unitId'] ?? '',
              ),
            ),
          ),
          GoRoute(
            path: '/institution/:institutionId/units',
            redirect: (context, state) => _enforceCanonicalIdMatch(
              ref,
              state,
              state.pathParameters['institutionId'],
              'units',
            ),
            builder: (_, state) => InstitutionRouteScope(
              address: state.pathParameters['institutionId'],
              builder: (institutionId) =>
                  InstitutionUnitsScreen(institutionId: institutionId),
            ),
          ),

          // Public Engagement workspace — list + detail + participation settings.
          GoRoute(
            path: '/institution/:institutionId/public-engagement',
            builder: (_, state) => InstitutionRouteScope(
              address: state.pathParameters['institutionId'],
              builder: (institutionId) =>
                  EngagementListScreen(institutionId: institutionId),
            ),
          ),
          GoRoute(
            path: '/institution/:institutionId/public-engagement/participation',
            builder: (_, state) => InstitutionRouteScope(
              address: state.pathParameters['institutionId'],
              builder: (institutionId) =>
                  ParticipationScreen(institutionId: institutionId),
            ),
          ),
          GoRoute(
            path: '/institution/:institutionId/public-engagement/:recordId',
            builder: (_, state) => InstitutionRouteScope(
              address: state.pathParameters['institutionId'],
              builder: (institutionId) => EngagementDetailScreen(
                institutionId: institutionId,
                recordId: state.pathParameters['recordId']!,
              ),
            ),
          ),

          // Profile.
          GoRoute(
            path: kInstitutionProfileRoute,
            redirect: (context, state) =>
                _redirectShorthandToCanonical(ref, state, 'profile'),
            // Rendered only while the institution authority is still
            // resolving; the redirect above takes over the instant it does.
            builder: (_, __) => const Scaffold(
              body: AuraProductState(state: ProductState.loading),
            ),
          ),
          GoRoute(
            path: '/institution/:institutionId/profile',
            redirect: (context, state) => _enforceCanonicalIdMatch(
              ref,
              state,
              state.pathParameters['institutionId'],
              'profile',
            ),
            builder: (_, state) => InstitutionRouteScope(
              address: state.pathParameters['institutionId'],
              builder: (institutionId) =>
                  InstitutionProfileScreen(institutionId: institutionId),
            ),
          ),

          // Edit profile.
          GoRoute(
            path: kInstitutionEditProfileRoute,
            redirect: (context, state) =>
                _redirectShorthandToCanonical(ref, state, 'edit-profile'),
            // Rendered only while the institution authority is still
            // resolving; the redirect above takes over the instant it does.
            builder: (_, __) => const Scaffold(
              body: AuraProductState(state: ProductState.loading),
            ),
          ),
          GoRoute(
            path: '/institution/:institutionId/edit-profile',
            redirect: (context, state) => _enforceCanonicalIdMatch(
              ref,
              state,
              state.pathParameters['institutionId'],
              'edit-profile',
            ),
            builder: (_, state) => InstitutionRouteScope(
              address: state.pathParameters['institutionId'],
              builder: (institutionId) =>
                  InstitutionEditProfileScreen(institutionId: institutionId),
            ),
          ),

          // Request verification.
          GoRoute(
            path: kInstitutionVerificationRoute,
            redirect: (context, state) => _redirectShorthandToCanonical(
              ref,
              state,
              'request-verification',
            ),
            // Rendered only while the institution authority is still
            // resolving; the redirect above takes over the instant it does.
            builder: (_, __) => const Scaffold(
              body: AuraProductState(state: ProductState.loading),
            ),
          ),
          GoRoute(
            path: '/institution/:institutionId/request-verification',
            redirect: (context, state) => _enforceCanonicalIdMatch(
              ref,
              state,
              state.pathParameters['institutionId'],
              'request-verification',
            ),
            builder: (_, __) => const InstitutionRequestVerificationScreen(),
          ),

          // Correspondence — consolidated into Messages. There used to be two
          // separate institution surfaces both titled "Messages"
          // (/messages and /correspondence). /correspondence is now a
          // permanent redirect to the canonical Messages surface so any
          // existing link still lands somewhere sensible and the duplicate is
          // gone from the workspace.
          GoRoute(
            path: kInstitutionCorrespondenceRoute,
            redirect: (context, state) =>
                _redirectShorthandToCanonical(ref, state, 'messages'),
          ),
          GoRoute(
            path: '/institution/:institutionId/correspondence',
            redirect: (context, state) {
              final id = state.pathParameters['institutionId'] ?? '';
              return id.isNotEmpty
                  ? '/institution/$id/messages'
                  : kInstitutionNoAffiliationDestination;
            },
          ),

          // Announcements (the const was dead — keep a redirect helper
          // so any external link is canonicalized rather than 404).
          GoRoute(
            path: kInstitutionAnnouncementsRoute,
            redirect: (context, state) =>
                _redirectShorthandToCanonical(ref, state, 'announcements'),
          ),

          // Live rooms.
          GoRoute(
            path: kInstitutionLiveRoomsRoute,
            redirect: (context, state) =>
                _redirectShorthandToCanonical(ref, state, 'live-rooms'),
          ),
          GoRoute(
            path: '/institution/:institutionId/live-rooms',
            redirect: (context, state) => _enforceCanonicalIdMatch(
              ref,
              state,
              state.pathParameters['institutionId'],
              'live-rooms',
            ),
            builder: (context, state) => InstitutionRouteScope(
              address: state.pathParameters['institutionId'],
              builder: (institutionId) =>
                  InstitutionLiveRoomsScreen(institutionId: institutionId),
            ),
          ),
          GoRoute(
            path: '/institution/:institutionId/announcements',
            redirect: (context, state) => _enforceCanonicalIdMatch(
              ref,
              state,
              state.pathParameters['institutionId'],
              'announcements',
            ),
            builder: (context, state) => InstitutionRouteScope(
              address: state.pathParameters['institutionId'],
              builder: (institutionId) =>
                  InstitutionAnnouncementsScreen(institutionId: institutionId),
            ),
          ),
          GoRoute(
            path: '/institution/:institutionId/announcements/new',
            redirect: (context, state) => _enforceCanonicalIdMatch(
              ref,
              state,
              state.pathParameters['institutionId'],
              'announcements/new',
            ),
            builder: (context, state) => InstitutionRouteScope(
              address: state.pathParameters['institutionId'],
              builder: (institutionId) =>
                  InstitutionAnnouncementComposer(institutionId: institutionId),
            ),
          ),
          GoRoute(
            path:
                '/institution/:institutionId/announcements/:announcementId/edit',
            builder: (context, state) => InstitutionRouteScope(
              address: state.pathParameters['institutionId'],
              builder: (institutionId) => InstitutionAnnouncementComposer(
                institutionId: institutionId,
                announcementId: state.pathParameters['announcementId'],
              ),
            ),
          ),
          GoRoute(
            path: '/institution/:institutionId/spaces',
            redirect: (context, state) => _enforceCanonicalIdMatch(
              ref,
              state,
              state.pathParameters['institutionId'],
              'spaces',
            ),
            builder: (context, state) => InstitutionRouteScope(
              address: state.pathParameters['institutionId'],
              builder: (institutionId) =>
                  InstitutionSpacesScreen(institutionId: institutionId),
            ),
          ),
          // RC-C7 RECONSTRUCTION (2026-08-20). This route used to build the
          // legacy `SpaceScreen` — the same widget as
          // `/me/correspondence/:spaceId`, on the Thread/Message runtime. It
          // now builds the reconstructed surface: Space governs identity,
          // purpose and membership; the canonical Conversation owns the
          // communication. The legacy route remains for personal
          // correspondence until that family is retired.
          GoRoute(
            // BOTH SEGMENTS ARE PRODUCT ADDRESSES (founder ruling 2026-08-23),
            // and each is resolved to a persistence id at its own boundary
            // before any screen sees it. The Space scope is nested inside the
            // institution scope because a Space address is scoped to its
            // parent institution — resolving it needs the institution first.
            path: '/institution/:institutionId/spaces/:spaceAddress',
            // THE SAME BOUNDARY EVERY OTHER INSTITUTION ROUTE STANDS BEHIND.
            //
            // This route was the only institution destination with no
            // canonical-address enforcement and no standing/denial check: a
            // non-canonical address was tolerated rather than converged, and
            // the authority gate that protects `spaces` — and every sibling
            // section — never ran for the Space a person actually opens.
            //
            // `_enforceCanonicalIdMatch` preserves the remainder of the path,
            // so the Space segment survives the canonical rewrite intact.
            redirect: (context, state) => _enforceCanonicalIdMatch(
              ref,
              state,
              state.pathParameters['institutionId'],
              'spaces',
            ),
            builder: (context, state) => InstitutionRouteScope(
              address: state.pathParameters['institutionId'],
              builder: (institutionId) => InstitutionSpaceRouteScope(
                institutionId: institutionId,
                address: state.pathParameters['spaceAddress'],
                builder: (entry) => InstitutionSpaceScreen(
                  institutionId: institutionId,
                  spaceId: entry.spaceId,
                  entry: entry,
                ),
              ),
            ),
          ),
          // The institution thread/archived-thread routes are RETIRED with
          // the Thread runtime. They were already orphaned by the Institution
          // Spaces reconstruction: the reconstructed surface produces neither,
          // and the only code that ever did was space_screen itself.
          GoRoute(
            path: '/institution/:institutionId/members',
            // STANDING-ONLY DESTINATION. Unlike Meetings, where the
            // institutionId is CONTEXT for a participant who may hold no
            // membership, this surface exists only for someone with standing.
            // Without validation a stale or foreign id rendered the workspace
            // chrome and then failed piecemeal on backend 403s -- the refusal
            // arriving as a broken screen instead of a governed answer.
            redirect: (context, state) => _enforceCanonicalIdMatch(
              ref,
              state,
              state.pathParameters['institutionId'],
              'members',
            ),
            builder: (context, state) => InstitutionRouteScope(
              address: state.pathParameters['institutionId'],
              builder: (institutionId) =>
                  InstitutionMembersScreen(institutionId: institutionId),
            ),
          ),
          GoRoute(
            path: '/institution/:institutionId/invites',
            // STANDING-ONLY DESTINATION. Unlike Meetings, where the
            // institutionId is CONTEXT for a participant who may hold no
            // membership, this surface exists only for someone with standing.
            // Without validation a stale or foreign id rendered the workspace
            // chrome and then failed piecemeal on backend 403s -- the refusal
            // arriving as a broken screen instead of a governed answer.
            redirect: (context, state) => _enforceCanonicalIdMatch(
              ref,
              state,
              state.pathParameters['institutionId'],
              'invites',
            ),
            builder: (context, state) => InstitutionRouteScope(
              address: state.pathParameters['institutionId'],
              builder: (institutionId) =>
                  InstitutionInvitesScreen(institutionId: institutionId),
            ),
          ),
          GoRoute(
            path: '/institution/:institutionId/join-requests',
            // STANDING-ONLY DESTINATION. Unlike Meetings, where the
            // institutionId is CONTEXT for a participant who may hold no
            // membership, this surface exists only for someone with standing.
            // Without validation a stale or foreign id rendered the workspace
            // chrome and then failed piecemeal on backend 403s -- the refusal
            // arriving as a broken screen instead of a governed answer.
            redirect: (context, state) => _enforceCanonicalIdMatch(
              ref,
              state,
              state.pathParameters['institutionId'],
              'join-requests',
            ),
            builder: (context, state) => InstitutionRouteScope(
              address: state.pathParameters['institutionId'],
              builder: (institutionId) =>
                  InstitutionJoinRequestsScreen(institutionId: institutionId),
            ),
          ),
          GoRoute(
            path: '/institution/:institutionId/explore',
            builder: (context, state) => InstitutionRouteScope(
              address: state.pathParameters['institutionId'],
              builder: (institutionId) =>
                  InstitutionExploreScreen(institutionId: institutionId),
            ),
          ),
          GoRoute(
            path: '/institution/:institutionId/posts/new',
            redirect: (context, state) => _enforceCanonicalIdMatch(
              ref,
              state,
              state.pathParameters['institutionId'],
              'posts/new',
            ),
            builder: (context, state) => InstitutionRouteScope(
              address: state.pathParameters['institutionId'],
              builder: (institutionId) => InstitutionPostComposerScreen(
                institutionId: institutionId,
                defaultScope: state.uri.queryParameters['scope'],
              ),
            ),
          ),
          GoRoute(
            path: '/institution/:institutionId/posts/:postId',
            builder: (context, state) => InstitutionRouteScope(
              address: state.pathParameters['institutionId'],
              builder: (institutionId) => InstitutionPostDetailScreen(
                institutionId: institutionId,
                postId: state.pathParameters['postId'] ?? '',
              ),
            ),
          ),
          GoRoute(
            // CUTOVER (founder authorisation 2026-08-23). A legacy direct
            // address resolves INTO the canonical Conversation rather than
            // reopening the legacy surface. Durable links keep working; a
            // second messaging authority does not stay alive to serve them.
            path: '/direct/:threadId',
            builder: (context, state) => DirectThreadCutoverScope(
              threadId: state.pathParameters['threadId'] ?? '',
            ),
          ),
          GoRoute(
            path: '/direct-intent',
            builder: (context, state) => DirectIntentScreen(
              targetType: state.uri.queryParameters['targetType'] ?? '',
              targetUserId: state.uri.queryParameters['targetUserId'],
              targetInstitutionId:
                  state.uri.queryParameters['targetInstitutionId'],
            ),
          ),
          GoRoute(
            // COMPATIBILITY ONLY (founder ruling §8, 2026-08-23).
            //
            // Notifications and Activity were two doors onto one data source —
            // measured: both screens consumed the same client provider. Activity
            // is the surviving destination, so this no longer renders a second
            // implementation of it. Durable links keep working by RESOLVING into
            // the canonical destination, which is the same rule applied to legacy
            // direct addresses.
            //
            // RETIREMENT CONDITION: removed once no persisted notification
            // deeplink and no released client still names `/notifications`.
            // Production currently holds such deeplinks, so it stays.
            path: '/notifications',
            redirect: (_, __) => '/activity',
          ),
          // Phase-2 shell-preserving variants: opening a profile from inside
          // the institution shell keeps the institution actor context (no
          // accidental drop to MemberShell). The screen itself reads the
          // active actor from the route path so the inner Follow/Message
          // buttons act as the institution.
          GoRoute(
            path: '/institution/:institutionId/u/:handle',
            // DR4 — retired mirror (pure duplicate of the Person object).
            // The address survives as an alias; the modern destination
            // owns the experience.
            redirect: (context, state) =>
                NavigationAuthority.legacyAliasTarget(state.uri.path) ??
                '/u/${state.pathParameters['handle'] ?? ''}',
          ),
          GoRoute(
            path: '/institution/:institutionId/institutions/:slug',
            // DR4 — retired mirror (pure duplicate of the Institution
            // object).
            redirect: (context, state) =>
                NavigationAuthority.legacyAliasTarget(state.uri.path) ??
                '/institutions/${state.pathParameters['slug'] ?? ''}',
          ),
          GoRoute(
            // CUTOVER, INSTITUTION SIDE (founder ruling 2026-08-24,
            // "eliminate the debt").
            //
            // The member address `/direct/:threadId` was cut over on
            // 2026-08-23 and the SERVER cut over with it: `mapThread` now
            // answers `/messages/c/:conversationId` for an institution actor
            // exactly as it does for a person. This route was the last place
            // still rendering the legacy Direct runtime, so a durable
            // institution link — a persisted notification deeplink, an older
            // released client — reopened a second messaging authority that
            // nothing else in the product still used.
            //
            // It resolves the same way the member address does. The
            // destination is the server's own answer, not a client guess.
            path: '/institution/:institutionId/direct/:threadId',
            builder: (context, state) => DirectThreadCutoverScope(
              threadId: state.pathParameters['threadId'] ?? '',
            ),
          ),
          GoRoute(
            path: '/institution/:institutionId/posts/:postId/edit',
            redirect: (context, state) => _enforceCanonicalIdMatch(
              ref,
              state,
              state.pathParameters['institutionId'],
              'posts/edit',
            ),
            builder: (context, state) => InstitutionRouteScope(
              address: state.pathParameters['institutionId'],
              builder: (institutionId) => InstitutionPostComposerScreen(
                institutionId: institutionId,
                postId: state.pathParameters['postId'],
              ),
            ),
          ),
          GoRoute(
            path: '/institution/:institutionId/activity',
            redirect: (context, state) => _enforceCanonicalIdMatch(
              ref,
              state,
              state.pathParameters['institutionId'],
              'activity',
            ),
            builder: (context, state) => InstitutionRouteScope(
              address: state.pathParameters['institutionId'],
              builder: (institutionId) =>
                  InstitutionActivityScreen(institutionId: institutionId),
            ),
          ),
          // Institution billing — backend-gated to OWNER/ADMIN at the
          // checkout endpoint. Screen itself disables purchases on iOS/
          // Android via defaultTargetPlatform.
          GoRoute(
            path: '/institution/:institutionId/billing',
            // STANDING-ONLY DESTINATION. Unlike Meetings, where the
            // institutionId is CONTEXT for a participant who may hold no
            // membership, this surface exists only for someone with standing.
            // Without validation a stale or foreign id rendered the workspace
            // chrome and then failed piecemeal on backend 403s -- the refusal
            // arriving as a broken screen instead of a governed answer.
            redirect: (context, state) => _enforceCanonicalIdMatch(
              ref,
              state,
              state.pathParameters['institutionId'],
              'billing',
            ),
            builder: (context, state) => InstitutionRouteScope(
              address: state.pathParameters['institutionId'],
              builder: (institutionId) =>
                  InstitutionBillingScreen(institutionId: institutionId),
            ),
          ),
          // /institution/:id/messages — restored to InstitutionMessagingScreen
          // (existing workspace messaging). The new actor-aware direct
          // inbox lives at /institution/:id/messages/direct.
          GoRoute(
            path: '/institution/:institutionId/messages',
            // C3 — the institution-inbox destination states its context
            // EXPLICITLY; the path itself confers nothing.
            builder: (context, state) => InstitutionRouteScope(
              address: state.pathParameters['institutionId'],
              builder: (institutionId) =>
                  InstitutionMessagingScreen(institutionId: institutionId),
            ),
          ),
          // The institution-context legacy inbox, retired with its member
          // twin. A person's correspondence is theirs wherever it was begun —
          // the canonical inbox is the same one — and the server already
          // sends an institution actor to `/messages/c/:id`, so this converges
          // on the destination the authority already names.
          GoRoute(
            path: '/institution/:institutionId/messages/direct',
            redirect: (_, __) => kMessagesRoute,
          ),
          GoRoute(
            path: '/institution/:institutionId/messages/direct/archived',
            redirect: (_, __) => kMessagesRoute,
          ),
          // THE LIVE DIRECTORY IS A DESTINATION, NOT A CALL.
          //
          // Founder-reported: opening Live from the drawer was "free fall,
          // dead end, no app hierarchy". It rendered outside the ShellRoute —
          // no bottom bar, no drawer, no way back — because it sat with the
          // realtime CALL routes and inherited their deliberate chrome
          // suppression through a shared `/realtime` prefix.
          //
          // Browsing what is live is ordinary navigation and keeps the app's
          // hierarchy. Entering a session (`/realtime/:sessionId`) remains
          // immersive and stays outside.
          GoRoute(
            path: '/realtime',
            builder: (_, __) => const RealtimeLobbyScreen(),
          ),
        ],
      ),

      // A CALL renders without the member nav/sidebar — chrome gets out of
      // the way once you are in a session. The LOBBY is not a call: it is a
      // directory you browse, and it now lives inside the shell (see above).
      // The two shared a path prefix, which is how the directory came to wear
      // a call's chrome suppression.
      GoRoute(
        path: '/realtime/:sessionId',
        // MEETING KILL SWITCH — divert meeting sessions to the meeting live
        // room before RealtimeRoomScreen can mount. See notes near the
        // realtimeMeetingRedirects cache above.
        redirect: (context, state) async {
          final sessionId = (state.pathParameters['sessionId'] ?? '').trim();
          if (sessionId.isEmpty) return null;

          final guestId = (state.uri.queryParameters['guestId'] ?? '').trim();
          final code = (state.uri.queryParameters['code'] ?? '').trim();

          // Fast path: already confirmed non-meeting → let the call screen render.
          if (realtimeSurfaceResolved.contains(sessionId) &&
              !realtimeMeetingRedirects.containsKey(sessionId)) {
            return null;
          }

          var meetingId = realtimeMeetingRedirects[sessionId];
          if (meetingId == null &&
              !realtimeSurfaceResolved.contains(sessionId)) {
            // Guests arriving on a stale `/realtime/` deep link may not be
            // authed yet; exchange the guest token first (using the guestId
            // that survives web reloads) so the surface lookup can succeed.
            // Without this the lookup 401s and the guest falls through to the
            // very screen we are trying to avoid.
            if (guestId.isNotEmpty) {
              final tokenStore = ref.read(tokenStoreProvider);
              await tokenStore.load();
              if (!tokenStore.isAuthed) {
                try {
                  final guestAuth = await ref
                      .read(meetingsRepositoryProvider)
                      .exchangeGuestAuth(guestId);
                  if (guestAuth.accessToken.trim().isNotEmpty) {
                    await tokenStore.setSession(
                      accessToken: guestAuth.accessToken,
                    );
                  }
                } catch (_) {}
              }
            }

            final session = await ref
                .read(realtimeRepositoryProvider)
                .fetchSessionCore(sessionId);
            if (session != null) {
              if (session.surfaceType == RealtimeSurfaceType.meeting) {
                final resolved = (session.surfaceId ?? '').trim();
                if (resolved.isNotEmpty) {
                  meetingId = resolved;
                  realtimeMeetingRedirects[sessionId] = resolved;
                }
              } else {
                // Confirmed non-meeting (direct call / live room) — cache so
                // we never re-fetch on subsequent navigations to this session.
                realtimeSurfaceResolved.add(sessionId);
              }
            }
            // On a null session (transport error / not authed) we intentionally
            // do NOT cache, so a later retry can still resolve and divert.
          }

          if (meetingId != null && meetingId.isNotEmpty) {
            final target = Uri(
              path: '/meetings/$meetingId/live',
              queryParameters: <String, String>{
                'sessionId': sessionId,
                'isHost': 'false',
                if (code.isNotEmpty) 'code': code,
                if (guestId.isNotEmpty) 'guestId': guestId,
              },
            ).toString();
            // Production-visible (not kDebugMode-gated) so a live diversion is
            // observable in the browser/device console without a repro build.
            debugPrint(
              '[killswitch] realtime->meeting'
              ' from=${state.uri} to=$target'
              ' meetingId=$meetingId sessionId=$sessionId'
              ' code=$code guestId=$guestId screen=RealtimeRoomScreen',
            );
            return target;
          }

          // HARD BLOCK — a `guestId` on a `/realtime/` link is a meeting-guest
          // signal (guests only ever exist for meetings). If we reach here the
          // surface could NOT be resolved (transport error / expired guest
          // token / unknown session). We must NOT fall through to
          // RealtimeRoomScreen for a meeting guest, so divert to the guest-safe
          // error screen with diagnostics instead.
          if (guestId.isNotEmpty) {
            final target = Uri(
              path: '/meetings/join-error',
              queryParameters: <String, String>{
                'sessionId': sessionId,
                if (code.isNotEmpty) 'code': code,
                'guestId': guestId,
                'reason': 'surface_unresolved',
              },
            ).toString();
            debugPrint(
              '[killswitch] realtime->join-error'
              ' from=${state.uri} to=$target'
              ' sessionId=$sessionId code=$code guestId=$guestId'
              ' screen=RealtimeRoomScreen',
            );
            return target;
          }

          // SIGNED-OUT HARD BLOCK — RealtimeRoomScreen is member-only. Every
          // legitimate realtime participant is an authed member (direct calls /
          // live rooms) or a meeting guest (handled above). A visitor with NO
          // token on `/realtime/:sessionId` is therefore always a misrouted
          // meeting guest (e.g. a stale `/realtime/` link with no guestId, or a
          // navigation that fired before guest-auth was exchanged). Never render
          // the legacy "Audio meeting / Could not join" screen for them — send
          // them to the meeting code-entry recovery instead.
          // Load persisted tokens first so a member cold-deep-linking to their
          // own direct call on web (in-memory token not yet restored) is not
          // mistaken for a signed-out visitor.
          final tokenStore = ref.read(tokenStoreProvider);
          await tokenStore.load();

          // AN EXPIRED TOKEN IS NOT A SIGNED-OUT VISITOR.
          //
          // This used to gate on `tokenStore.isAuthed`, which deliberately
          // reports FALSE for a persisted access token that is past its `exp`
          // -- see its own doc comment: it does that so the bootstrap refresh
          // path runs and swaps in a live token before any protected request
          // fires. It answers "is this token immediately usable", NOT "is
          // this person signed out", and reading it as the second ejected
          // real members.
          //
          // Founder-observed 2026-08-28: a call started from an institution
          // space rang the callee correctly, and the CALLER was redirected
          // here to the guest meeting-code screen while still displayed as
          // signed in. The session showed SESSION_CREATED and INVITE_ACCEPTED
          // with no PARTICIPANT_JOINED for the host and no SDP exchange at
          // all -- the callee was connected to nobody.
          //
          // The refresh token cannot be consulted here: on web it is an
          // HttpOnly cookie and is not readable from Dart. What CAN be known
          // is whether a session exists at all -- a member token (expired or
          // not) or a persisted session hint. Only their joint absence means
          // nobody is signed in.
          final rawToken = (tokenStore.accessToken ?? '').trim();
          final hasMemberToken =
              rawToken.isNotEmpty && !isGuestAccessToken(rawToken);
          final hasHint = await hasSessionHint();
          if (!hasMemberToken && !hasHint) {
            // A CALL IS NOT A MEETING, AND A TOKENLESS VISITOR IS NOT A GUEST.
            //
            // This branch used to send EVERY sessionless visitor to
            // `/meetings/join`, on the premise stated above -- that anyone
            // without a token on `/realtime/` is "always a misrouted meeting
            // guest". That was true when `/realtime/` meant meetings. Thread
            // and conversation calls live here too, so the premise now
            // misfires on the people it was written to protect: a member of a
            // CONVERSATION call whose session cannot be read is handed a
            // meeting code-entry screen, asked for a code that does not exist
            // and never will, under a "Sign in | Join" header. Founder-
            // observed 2026-08-29 during a four-person thread call.
            //
            // The meeting-guest reading is kept where there is actual
            // evidence for it -- a `code` in the address (a `guestId` is
            // already handled by the hard block above). Absence of a token is
            // not that evidence. Everyone else is sent to sign in and
            // returned to the call they were trying to reach.
            if (code.isNotEmpty) {
              debugPrint(
                '[killswitch] realtime->join (meeting code, no session)'
                ' from=${state.uri} sessionId=$sessionId code=$code'
                ' screen=RealtimeRoomScreen',
              );
              return '/meetings/join';
            }
            final encoded = Uri.encodeComponent(state.uri.toString());
            debugPrint(
              '[killswitch] realtime->login (no session)'
              ' from=${state.uri} sessionId=$sessionId'
              ' screen=RealtimeRoomScreen',
            );
            return '/login?redirect=$encoded';
          }
          return null;
        },
        builder: (context, state) => RealtimeRoomScreen(
          sessionId: state.pathParameters['sessionId'] ?? '',
          action: state.uri.queryParameters['action'],
          returnTo: state.uri.queryParameters['returnTo'],
          insSessionType: state.uri.queryParameters['sessionType'],
          insSessionAudience: state.uri.queryParameters['sessionAudience'],
          insSessionTitle: state.uri.queryParameters['sessionTitle'],
          guestId: state.uri.queryParameters['guestId'],
        ),
      ),
    ],
  );
});

/// `/_boot` — RETIRED AS A DESTINATION, KEPT AS CONTINUITY.
///
/// Founder ruling: Aura must not expose an avoidable intermediate experience.
/// Restoring a session is not going somewhere, so the router no longer parks
/// cold loads here — it stays at the intended location and `BootGate` renders
/// the restoring state in place, preserving the URL, history and refresh.
///
/// The route survives only so that a `/_boot?redirect=…` address already
/// captured in someone's history or a stale bundle still resolves: the
/// redirect branch above sends it on to its destination. Nothing in Aura emits
/// this address any more.
///
/// F068's real property — a bounded, honest wait that never ends by GUESSING
/// an unknown session, which F065 forbids — was not weakened; it moved to
/// `BootGate` where the waiting now happens. This builder is what a person
/// sees only in the instant before the redirect resolves.
class _RouterBootScreen extends StatelessWidget {
  const _RouterBootScreen();

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: AuraProductState(state: ProductState.loading));
}

class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    _sub = stream.listen((_) => notifyListeners());
  }

  late final StreamSubscription<dynamic> _sub;

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}

/// THE SEARCH ADDRESS, RENDERED AS DISCOVER.
///
/// `/search?q=…` is a real, governed address: tag taps produce it and older
/// links still carry it. It no longer opens a second search product. This
/// seeds the incoming query into the same state the Discover field publishes
/// — once, on first build, so a person who then edits the field is not fought
/// by the address they arrived through — and hands over to the one surface.
class _DiscoverSearchEntryPoint extends ConsumerStatefulWidget {
  const _DiscoverSearchEntryPoint({required this.seedQuery});

  final String seedQuery;

  @override
  ConsumerState<_DiscoverSearchEntryPoint> createState() =>
      _DiscoverSearchEntryPointState();
}

class _DiscoverSearchEntryPointState
    extends ConsumerState<_DiscoverSearchEntryPoint> {
  @override
  void initState() {
    super.initState();
    final q = widget.seedQuery;
    if (q.isEmpty) return;
    // Applied after the first frame: writing to a provider during build is
    // what produces the "modified during build" crash.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(discoverQueryProvider.notifier).state = q;
      ref.read(discoverNarrowedDomainProvider.notifier).state = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Focus the field when there is nothing to show yet, so arriving at the
    // search address means being ready to type.
    return DiscoverScreen(autofocusSearch: widget.seedQuery.isEmpty);
  }
}
