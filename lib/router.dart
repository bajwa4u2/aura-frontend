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
import 'core/auth/session_providers.dart';
import 'core/diagnostics/runtime_trace.dart';
import 'core/institutions/institution_access_provider.dart';
import 'features/meetings/application/meetings_provider.dart';
import 'features/realtime/application/realtime_providers.dart';
import 'features/realtime/domain/realtime_enums.dart';

// Auth
import 'features/auth/presentation/auth_screen.dart';
import 'features/auth/presentation/register_screen.dart';
import 'features/auth/presentation/verify_email_screen.dart';
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
import 'features/search/presentation/search_screen.dart';
import 'features/updates/presentation/updates_screen.dart';
import 'features/activity/presentation/activity_screen.dart';
import 'features/announcements/presentation/announcements_screen.dart';
import 'features/announcements/presentation/announcement_detail_screen.dart';
import 'features/announcements/presentation/announcement_editor_screen.dart';
import 'features/communications/presentation/communications_center_screen.dart';
import 'features/ai/presentation/claim_audit_screen.dart';
import 'features/me/presentation/me_screen.dart';
import 'features/me/presentation/edit_profile_screen.dart';
import 'features/me/presentation/security_screen.dart';
import 'features/me/presentation/change_password_screen.dart';
import 'features/posts/presentation/compose_screen.dart';
import 'features/posts/presentation/post_detail_screen.dart';
import 'features/profile/presentation/author_profile_screen.dart';
import 'features/profile/presentation/follow_requests_screen.dart';
import 'features/profile/presentation/followers_screen.dart';
import 'features/profile/presentation/following_screen.dart';
import 'features/institutions/presentation/institution_detail_screen.dart';
import 'features/institutions/presentation/institution_dashboard_screen.dart';
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
import 'features/admin/presentation/admin_policies_screen.dart';
import 'features/admin/presentation/admin_moderation_screen.dart';
import 'features/institutions/domain/institution_domains_screen.dart';
import 'features/institutions/units/institution_units_screen.dart';
import 'features/institutions/profile/institution_profile_screen.dart';
import 'features/institutions/profile/institution_edit_profile_screen.dart';
import 'features/institutions/verification/institution_request_verification_screen.dart';
import 'features/institutions/announcements/institution_announcements_screen.dart';
import 'features/institutions/announcements/institution_announcement_composer.dart';
import 'features/institutions/presentation/institution_spaces_screen.dart';
import 'features/institutions/live_rooms/institution_live_rooms_screen.dart';
import 'features/institutions/explore/institution_explore_screen.dart';
import 'features/institutions/posts/institution_post_composer_screen.dart';
import 'features/institutions/posts/institution_post_detail_screen.dart';
import 'features/institutions/engagement/engagement_list_screen.dart';
import 'features/institutions/engagement/engagement_detail_screen.dart';
import 'features/institutions/participation/participation_screen.dart';
import 'features/direct_threads/presentation/direct_intent_screen.dart';
import 'features/direct_threads/presentation/direct_thread_screen.dart';
import 'features/direct_threads/presentation/inbox_screen.dart';
import 'features/messages/presentation/messages_hub_screen.dart';
import 'features/institutions/messaging/institution_messaging_screen.dart';
import 'features/notifications/presentation/notifications_screen.dart';
import 'features/institutions/activity/institution_activity_screen.dart';
import 'features/monetization/presentation/institution_billing_screen.dart';
import 'features/saves/presentation/saved_screen.dart';
import 'features/correspondence/presentation/correspondence_hub_screen.dart';
import 'features/correspondence/presentation/space_screen.dart';
import 'features/correspondence/presentation/thread_state_wrapper.dart';
import 'features/correspondence/presentation/invite_member_screen.dart';
import 'features/create/presentation/create_hub_screen.dart';
import 'features/invitations/presentation/invite_hub_screen.dart';
import 'features/invitations/presentation/invitations_screen.dart';
import 'features/invitations/presentation/invite_accept_screen.dart';
import 'features/invitations/presentation/invite_create_screen.dart';
import 'features/invitations/presentation/contact_import_screen.dart';
import 'features/realtime/presentation/realtime_lobby_screen.dart';
import 'features/realtime/presentation/realtime_room_screen.dart';
import 'features/meetings/presentation/booking_cancel_screen.dart';
import 'features/meetings/presentation/booking_confirm_screen.dart';
import 'features/meetings/presentation/booking_reschedule_screen.dart';
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
import 'features/meetings/presentation/slot_picker_screen.dart';
import 'features/meetings/presentation/meetings_home_screen.dart';
import 'features/meetings/presentation/availability_setup_screen.dart';
import 'features/meetings/domain/availability_profile.dart';

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
const String kAdminWorkspaceRoute = '/admin';
const String kAdminCommunicationsRoute = '/admin/communications';
const String kMeCommunicationsRoute = '/me/settings/communications';
const String kRouterBootRoute = '/_boot';

const String kMessagesRoute = '/messages';
const String kCorrespondenceHubRoute = '/me/correspondence';
const String kCreateConversationRoute =
    '/me/correspondence/create/conversation';
const String kCreateSpaceRoute = '/me/correspondence/create/space';

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

/// Routing-hardening — convert a legacy `/institution/<section>`
/// shorthand into a canonical `/institution/:id/<section>` URL using
/// the active institution identity. Falls back to the global
/// dashboard selector when no id can be resolved.
String _redirectShorthandToCanonical(Ref ref, String section) {
  final id = ref.read(institutionIdentityProvider)?.id ?? '';
  if (id.isNotEmpty) return '/institution/$id/$section';
  return kInstitutionDashboardRoute;
}

/// Enforce "path id dominates provider" for canonical workspace
/// routes. If the URL carries an institution id that doesn't match the
/// active identity (or carries no id at all), rewrite to the active
/// identity's URL — or to the global dashboard if no identity exists.
/// Returning `null` means the route may proceed unchanged.
String? _enforceCanonicalIdMatch(Ref ref, String? pathId, String section) {
  final pathTrim = (pathId ?? '').trim();
  final activeId = ref.read(institutionIdentityProvider)?.id ?? '';
  if (pathTrim.isEmpty) {
    return activeId.isNotEmpty
        ? '/institution/$activeId/$section'
        : kInstitutionDashboardRoute;
  }
  // When the active identity is known and disagrees with the URL,
  // canonicalize. When no active identity is resolved (e.g. transient
  // bootstrap state on a deep link), trust the URL — the auth gate
  // higher up has already verified institution access.
  if (activeId.isNotEmpty && pathTrim != activeId) {
    return '/institution/$activeId/$section';
  }
  return null;
}

final routerProvider = Provider<GoRouter>((ref) {
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

  ref.listen<AsyncValue<InstitutionAccess>>(institutionAccessProvider, (
    prev,
    next,
  ) {
    final prevState = prev?.valueOrNull?.state;
    final nextState = next.valueOrNull?.state;
    if (prevState != nextState) {
      refresh.value++;
      RuntimeTrace.emit(
        'router.refresh',
        'institutionAccess',
        data: {'next': nextState?.name},
      );
    }
  });

  ref.listen<AsyncValue<AppAdminAccess>>(appAdminAccessProvider, (prev, next) {
    final prevAdmin = prev?.valueOrNull?.isAdmin;
    final nextAdmin = next.valueOrNull?.isAdmin;
    if (prevAdmin != nextAdmin) {
      refresh.value++;
      RuntimeTrace.emit(
        'router.refresh',
        'appAdminAccess',
        data: {'next': nextAdmin},
      );
    }
  });

  bool isBootPath(String path) => path == kRouterBootRoute;

  bool isPlainAuthPage(String path) {
    return path == '/login' || path == '/register' || path == '/auth';
  }

  bool isAuthActionPath(String path) {
    return path == '/forgot-password' ||
        path == '/reset-password' ||
        path == '/verify-email' ||
        path == '/verify-pending';
  }

  bool isPublicPath(String path) {
    if (path == '/' || path == '/public') return true;
    if (isBootPath(path)) return true;
    if (isPlainAuthPage(path)) return true;
    if (isAuthActionPath(path)) return true;

    if (path == '/mission' ||
        path == '/white-paper' ||
        path == '/terms' ||
        path == '/founder' ||
        path == '/privacy' ||
        path == '/child-safety' ||
        path == '/safety' ||
        path == '/trust-safety' ||
        path == '/contact' ||
        path == '/account-deletion' ||
        path == '/investors' ||
        // Institutional discovery — the directory hub, detail pages, and
        // public unit pages are all browsable without sign-in. Only the
        // onboarding wizard (/institutions/get-started) is auth-gated;
        // it's matched separately by isMemberShellPath.
        path == '/institutions' ||
        (path.startsWith('/institutions/') &&
            path != '/institutions/get-started') ||
        path == '/patrons' ||
        path == '/supporters' ||
        path == '/search' ||
        path.startsWith('/posts/') ||
        path.startsWith('/u/') ||
        path.startsWith('/author/') ||
        path.startsWith('/support/') ||
        isPublicInviteAcceptPath(path)) {
      return true;
    }

    if (path == '/announcements') return true;
    if (path.startsWith('/announcements/')) return true;

    // Public booking pages — no auth required
    if (path.startsWith('/meet/')) return true;

    // Institution-owned public booking pages — /i/:slug/meet/:bookingSlug
    if (path.startsWith('/i/')) return true;

    // Pre-join screen — guests arrive here from booking confirmation emails.
    // The bare `/meetings/join` (codeless legacy links) is public too so an
    // external guest reaches the code-entry recovery screen, never a login wall.
    if (path == '/meetings/join') return true;
    if (path == '/meetings/join-error') return true;
    if (path.startsWith('/meetings/join/')) return true;
    // Guest-reachable meeting paths: room (pre-live lobby), waiting, live, summary
    if (RegExp(
      r'^/meetings/[^/]+/(room|waiting|live|summary|post-meeting)$',
    ).hasMatch(path)) {
      return true;
    }

    return false;
  }

  bool isMemberPath(String path) => isMemberShellPath(path);

  bool requiresAuth(String path) => isMemberPath(path);

  bool requiresVerifiedEmail(String path) {
    return requiresAuth(path) &&
        path != '/verify-email' &&
        path != '/verify-pending';
  }

  bool isGuestOnly(String path) => isPlainAuthPage(path);

  bool requiresAppAdmin(String path) =>
      path == kAdminWorkspaceRoute || path.startsWith('$kAdminWorkspaceRoute/');

  bool requiresInstitutionAccess(String path) {
    if (path == kInstitutionDashboardRoute ||
        path == kInstitutionProfileRoute ||
        path == kInstitutionEditProfileRoute ||
        path == kInstitutionCorrespondenceRoute ||
        path == kInstitutionLiveRoomsRoute ||
        path == kInstitutionVerificationRoute) {
      return true;
    }
    // All /institution/:id/... routes require institution access
    final institutionSubPath = RegExp(r'^/institution/[^/]+/.+');
    return institutionSubPath.hasMatch(path);
  }

  bool requiresInstitutionAdminOrSpeaker(String path) {
    // Announcements require authorized speaker or admin
    return RegExp(r'^/institution/[^/]+/announcements').hasMatch(path);
  }

  bool requiresInstitutionAdmin(String path) {
    return path == kInstitutionDomainsRoute ||
        path == kInstitutionEditProfileRoute;
  }

  String bootRedirectFor(String target, {required String fallback}) {
    final encoded = Uri.encodeComponent(
      _normalizeRedirectDest(target, fallback: fallback),
    );
    return '$kRouterBootRoute?redirect=$encoded';
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
  final realtimeSurfaceResolved = <String>{}; // sessionIds confirmed non-meeting

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
        if (isBootPath(path)) return null;

        return bootRedirectFor(currentLocation, fallback: defaultRedirect);
      }

      if (isLoggedIn &&
          (isVerificationLoading ||
              institutionAccessLoading ||
              appAdminLoading)) {
        return null;
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

      if (requiresAppAdmin(path) && !appAdmin.isAdmin) {
        return '/home';
      }

      // Platform admins bypass all institution membership gates — the backend
      // enforces INSTITUTIONS_READ/WRITE via its own bypass logic.
      if (!appAdmin.isAdmin) {
        if (requiresInstitutionAccess(path) && !institutionAccess.hasAccess) {
          return kEnterInstitutionRoute;
        }

        final isInstitutionAdmin =
            institutionAccess.state == InstitutionAccessState.authorizedSpeaker;
        final isInstitutionSpeakerOrAdmin =
            institutionAccess.state ==
                InstitutionAccessState.authorizedSpeaker ||
            institutionAccess.state == InstitutionAccessState.verifiedMember;

        if (requiresInstitutionAdmin(path) && !isInstitutionAdmin) {
          return kInstitutionDashboardRoute;
        }

        if (requiresInstitutionAdminOrSpeaker(path) &&
            !isInstitutionSpeakerOrAdmin) {
          return kInstitutionDashboardRoute;
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
          GoRoute(
            path: '/meet/:slug/book',
            builder: (context, state) {
              final extra = state.extra;
              if (extra is Map<String, dynamic>) {
                final profile = extra['profile'] as AvailabilityProfile?;
                final slot = extra['slot'] as TimeSlot?;
                final duration = extra['duration'] as int? ?? 30;
                if (profile != null && slot != null) {
                  return BookingConfirmScreen(
                    profile: profile,
                    slot: slot,
                    durationMinutes: duration,
                  );
                }
              }
              if (extra is AvailabilityProfile) {
                // Arrived from booking page without pre-selecting a slot
                return SlotPickerScreen(profile: extra);
              }
              return const PublicBookingScreen(slug: '');
            },
          ),

          GoRoute(path: '/search', builder: (_, __) => const SearchScreen()),
          GoRoute(
            path: '/posts/:id',
            builder: (context, state) =>
                PostDetailScreen(postId: state.pathParameters['id'] ?? ''),
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

          // Member + institution routes
          GoRoute(path: '/home', builder: (_, __) => const MemberHomeScreen()),

          // ── Meetings ─────────────────────────────────────────────────
          // IMPORTANT: static paths (/meetings/new, /meetings/join/:code)
          // must appear BEFORE the dynamic /meetings/:id route so
          // GoRouter's first-match-wins order resolves them correctly.
          GoRoute(
            path: '/meetings',
            builder: (_, __) => const MeetingsHomeScreen(),
          ),
          GoRoute(
            path: '/institution/:institutionId/meetings',
            builder: (context, state) => MeetingsHomeScreen(
              institutionId: state.pathParameters['institutionId'],
            ),
          ),
          GoRoute(
            path: '/meetings/new',
            builder: (_, __) => const CreateMeetingScreen(),
          ),
          // Institution-owned scheduling — created meetings carry the
          // institution's ownership from birth.
          GoRoute(
            path: '/institution/:institutionId/meetings/new',
            builder: (context, state) => CreateMeetingScreen(
              institutionId: state.pathParameters['institutionId'],
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
            ),
          ),
          GoRoute(
            path: '/meetings/:id',
            builder: (context, state) => MeetingDetailScreen(
              meetingId: state.pathParameters['id'] ?? '',
            ),
          ),
          GoRoute(
            path: '/meetings/:meetingId/prep',
            builder: (context, state) => MeetingDetailScreen(
              meetingId: state.pathParameters['meetingId'] ?? '',
            ),
          ),
          // Lobby retired: the Meeting Record is the doorway to the room.
          // Guests never land here anymore (pre-join routes straight to
          // /live); members see the record with its Enter room banner.
          GoRoute(
            path: '/meetings/:meetingId/room',
            builder: (context, state) => MeetingDetailScreen(
              meetingId: state.pathParameters['meetingId'] ?? '',
            ),
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
            builder: (context, state) => MeetingDetailScreen(
              meetingId: state.pathParameters['meetingId'] ?? '',
            ),
          ),
          GoRoute(
            path: '/meetings/:meetingId/post-meeting',
            builder: (context, state) => MeetingDetailScreen(
              meetingId: state.pathParameters['meetingId'] ?? '',
            ),
          ),
          GoRoute(
            path: '/institution/:institutionId/meetings/:meetingId',
            builder: (context, state) => MeetingDetailScreen(
              meetingId: state.pathParameters['meetingId'] ?? '',
              institutionId: state.pathParameters['institutionId'],
            ),
          ),
          GoRoute(
            path: '/institution/:institutionId/meetings/:meetingId/prep',
            builder: (context, state) => MeetingDetailScreen(
              meetingId: state.pathParameters['meetingId'] ?? '',
              institutionId: state.pathParameters['institutionId'],
            ),
          ),
          GoRoute(
            path: '/institution/:institutionId/meetings/:meetingId/room',
            builder: (context, state) => MeetingDetailScreen(
              meetingId: state.pathParameters['meetingId'] ?? '',
              institutionId: state.pathParameters['institutionId'],
            ),
          ),
          GoRoute(
            path: '/institution/:institutionId/meetings/:meetingId/waiting',
            builder: (context, state) => GuestWaitingRoomScreen(
              meetingId: state.pathParameters['meetingId'] ?? '',
              institutionId: state.pathParameters['institutionId'],
              sessionId: state.uri.queryParameters['sessionId'],
              returnTo: state.uri.queryParameters['returnTo'],
              guestId: state.uri.queryParameters['guestId'],
            ),
          ),
          GoRoute(
            path: '/institution/:institutionId/meetings/:meetingId/live',
            builder: (context, state) => MeetingLiveRoomScreen(
              meetingId: state.pathParameters['meetingId'] ?? '',
              institutionId: state.pathParameters['institutionId'],
              sessionId: state.uri.queryParameters['sessionId'] ?? '',
              isHost: state.uri.queryParameters['isHost'] == 'true',
              meetingCode: state.uri.queryParameters['code'],
              guestUserId: state.uri.queryParameters['guestId'],
            ),
          ),
          GoRoute(
            path: '/institution/:institutionId/meetings/:meetingId/summary',
            builder: (context, state) => MeetingDetailScreen(
              meetingId: state.pathParameters['meetingId'] ?? '',
              institutionId: state.pathParameters['institutionId'],
            ),
          ),
          GoRoute(
            path:
                '/institution/:institutionId/meetings/:meetingId/post-meeting',
            builder: (context, state) => MeetingDetailScreen(
              meetingId: state.pathParameters['meetingId'] ?? '',
              institutionId: state.pathParameters['institutionId'],
            ),
          ),
          GoRoute(
            path: '/availability',
            builder: (_, __) => const AvailabilitySetupScreen(),
          ),
          // Institution admin booking pages — gated by InstitutionRoleGuard (ADMIN) on backend
          GoRoute(
            path: '/institution/:institutionId/availability',
            builder: (context, state) => InstitutionAvailabilityScreen(
              institutionId: state.pathParameters['institutionId'] ?? '',
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
            builder: (context, state) {
              final extra = state.extra;
              final profile = extra is AvailabilityProfile ? extra : null;
              if (profile != null) {
                return BookingRescheduleScreen(
                  token: state.pathParameters['token'] ?? '',
                  profile: profile,
                );
              }
              return const BookingCancelScreen(token: ''); // fallback
            },
          ),
          GoRoute(
            path: '/meet/reschedule/:token',
            builder: (context, state) {
              final extra = state.extra;
              final profile = extra is AvailabilityProfile ? extra : null;
              if (profile != null) {
                return BookingRescheduleScreen(
                  token: state.pathParameters['token'] ?? '',
                  profile: profile,
                );
              }
              return const BookingCancelScreen(token: ''); // fallback
            },
          ),
          GoRoute(
            path: '/i/:institutionSlug/meet/:bookingSlug/book',
            builder: (context, state) {
              final extra = state.extra;
              if (extra is Map<String, dynamic>) {
                final profile = extra['profile'] as AvailabilityProfile?;
                final slot = extra['slot'] as TimeSlot?;
                final duration = extra['duration'] as int? ?? 30;
                if (profile != null && slot != null) {
                  return BookingConfirmScreen(
                    profile: profile,
                    slot: slot,
                    durationMinutes: duration,
                  );
                }
              }
              if (extra is AvailabilityProfile) {
                return SlotPickerScreen(profile: extra);
              }
              // Fallback: reload the institution booking page
              return InstitutionPublicBookingScreen(
                institutionSlug: state.pathParameters['institutionSlug'] ?? '',
                bookingSlug: state.pathParameters['bookingSlug'] ?? '',
              );
            },
          ),
          // /messages — restored to MessagesHubScreen (existing
          // conversations/spaces/invites). The new actor-aware direct
          // inbox is mounted as a sub-route at /messages/direct so it's
          // an addition, not a replacement.
          GoRoute(
            path: kMessagesRoute,
            builder: (_, __) => const MessagesHubScreen(),
          ),
          GoRoute(
            path: '$kMessagesRoute/direct',
            builder: (_, __) => const InboxScreen(),
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
            path: '/change-password',
            builder: (_, __) => const ChangePasswordScreen(),
          ),
          GoRoute(
            path: '/settings/communications',
            redirect: (_, __) => kMeCommunicationsRoute,
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
            path: '/admin/policies',
            builder: (_, __) => const AdminPoliciesScreen(),
          ),
          GoRoute(
            path: '/admin/moderation',
            builder: (_, __) => const AdminModerationScreen(),
          ),
          GoRoute(
            path: '/admin/support',
            builder: (_, __) => const AdminSupportConsoleScreen(),
          ),

          // Correspondence routes flattened for stable direct navigation
          GoRoute(
            path: kCorrespondenceHubRoute,
            builder: (_, __) => const CorrespondenceHubScreen(),
          ),
          GoRoute(
            path: kCreateConversationRoute,
            redirect: (context, state) {
              final query = <String, String>{...state.uri.queryParameters};
              query['start'] = 'private';
              return Uri(
                path: kCorrespondenceHubRoute,
                queryParameters: query,
              ).toString();
            },
          ),
          GoRoute(
            path: kCreateSpaceRoute,
            redirect: (context, state) {
              final query = <String, String>{...state.uri.queryParameters};
              query['start'] = 'space';
              return Uri(
                path: kCorrespondenceHubRoute,
                queryParameters: query,
              ).toString();
            },
          ),
          GoRoute(
            path: '/me/correspondence/:spaceId',
            builder: (context, state) =>
                SpaceScreen(spaceId: state.pathParameters['spaceId'] ?? ''),
          ),
          GoRoute(
            path: '/me/correspondence/:spaceId/invite',
            builder: (context, state) => InviteMemberScreen(
              spaceId: state.pathParameters['spaceId'] ?? '',
            ),
          ),
          GoRoute(
            path: '/me/correspondence/:spaceId/thread/:threadId',
            builder: (context, state) => ThreadStateWrapper(
              threadId: state.pathParameters['threadId'] ?? '',
            ),
          ),
          GoRoute(
            path:
                '/me/correspondence/:spaceId/thread/:threadId/live/:sessionId',
            builder: (context, state) => ThreadStateWrapper(
              threadId: state.pathParameters['threadId'] ?? '',
            ),
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
              );
            },
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

          // Global institution selector (no id required).
          GoRoute(
            path: kInstitutionDashboardRoute,
            builder: (_, __) => const InstitutionDashboardScreen(),
          ),
          // Symmetric canonical alias — redirects to the global selector.
          GoRoute(
            path: '/institution/:institutionId/dashboard',
            redirect: (_, __) => kInstitutionDashboardRoute,
          ),

          // Domains — shorthand redirects, canonical builds.
          GoRoute(
            path: kInstitutionDomainsRoute,
            redirect: (context, state) =>
                _redirectShorthandToCanonical(ref, 'domains'),
          ),
          GoRoute(
            path: '/institution/:institutionId/domains',
            redirect: (context, state) => _enforceCanonicalIdMatch(
              ref,
              state.pathParameters['institutionId'],
              'domains',
            ),
            builder: (_, __) => const InstitutionDomainsScreen(),
          ),

          // Units (already canonical, kept here for proximity).
          GoRoute(
            path: '/institution/:institutionId/units',
            builder: (_, state) => InstitutionUnitsScreen(
              institutionId: state.pathParameters['institutionId']!,
            ),
          ),

          // Public Engagement workspace — list + detail + participation settings.
          GoRoute(
            path: '/institution/:institutionId/public-engagement',
            builder: (_, state) => EngagementListScreen(
              institutionId: state.pathParameters['institutionId']!,
            ),
          ),
          GoRoute(
            path: '/institution/:institutionId/public-engagement/participation',
            builder: (_, state) => ParticipationScreen(
              institutionId: state.pathParameters['institutionId']!,
            ),
          ),
          GoRoute(
            path: '/institution/:institutionId/public-engagement/:recordId',
            builder: (_, state) => EngagementDetailScreen(
              institutionId: state.pathParameters['institutionId']!,
              recordId: state.pathParameters['recordId']!,
            ),
          ),

          // Profile.
          GoRoute(
            path: kInstitutionProfileRoute,
            redirect: (context, state) =>
                _redirectShorthandToCanonical(ref, 'profile'),
          ),
          GoRoute(
            path: '/institution/:institutionId/profile',
            redirect: (context, state) => _enforceCanonicalIdMatch(
              ref,
              state.pathParameters['institutionId'],
              'profile',
            ),
            builder: (_, __) => const InstitutionProfileScreen(),
          ),

          // Edit profile.
          GoRoute(
            path: kInstitutionEditProfileRoute,
            redirect: (context, state) =>
                _redirectShorthandToCanonical(ref, 'edit-profile'),
          ),
          GoRoute(
            path: '/institution/:institutionId/edit-profile',
            redirect: (context, state) => _enforceCanonicalIdMatch(
              ref,
              state.pathParameters['institutionId'],
              'edit-profile',
            ),
            builder: (_, __) => const InstitutionEditProfileScreen(),
          ),

          // Request verification.
          GoRoute(
            path: kInstitutionVerificationRoute,
            redirect: (context, state) =>
                _redirectShorthandToCanonical(ref, 'request-verification'),
          ),
          GoRoute(
            path: '/institution/:institutionId/request-verification',
            redirect: (context, state) => _enforceCanonicalIdMatch(
              ref,
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
                _redirectShorthandToCanonical(ref, 'messages'),
          ),
          GoRoute(
            path: '/institution/:institutionId/correspondence',
            redirect: (context, state) {
              final id = state.pathParameters['institutionId'] ?? '';
              return id.isNotEmpty
                  ? '/institution/$id/messages'
                  : kInstitutionDashboardRoute;
            },
          ),

          // Announcements (the const was dead — keep a redirect helper
          // so any external link is canonicalized rather than 404).
          GoRoute(
            path: kInstitutionAnnouncementsRoute,
            redirect: (context, state) =>
                _redirectShorthandToCanonical(ref, 'announcements'),
          ),

          // Live rooms.
          GoRoute(
            path: kInstitutionLiveRoomsRoute,
            redirect: (context, state) =>
                _redirectShorthandToCanonical(ref, 'live-rooms'),
          ),
          GoRoute(
            path: '/institution/:institutionId/live-rooms',
            redirect: (context, state) => _enforceCanonicalIdMatch(
              ref,
              state.pathParameters['institutionId'],
              'live-rooms',
            ),
            builder: (context, state) => InstitutionLiveRoomsScreen(
              institutionId: state.pathParameters['institutionId'] ?? '',
            ),
          ),
          GoRoute(
            path: '/institution/:institutionId/announcements',
            builder: (context, state) => InstitutionAnnouncementsScreen(
              institutionId: state.pathParameters['institutionId'] ?? '',
            ),
          ),
          GoRoute(
            path: '/institution/:institutionId/announcements/new',
            builder: (context, state) => InstitutionAnnouncementComposer(
              institutionId: state.pathParameters['institutionId'] ?? '',
            ),
          ),
          GoRoute(
            path:
                '/institution/:institutionId/announcements/:announcementId/edit',
            builder: (context, state) => InstitutionAnnouncementComposer(
              institutionId: state.pathParameters['institutionId'] ?? '',
              announcementId: state.pathParameters['announcementId'],
            ),
          ),
          GoRoute(
            path: '/institution/:institutionId/spaces',
            builder: (context, state) => InstitutionSpacesScreen(
              institutionId: state.pathParameters['institutionId'] ?? '',
            ),
          ),
          GoRoute(
            path: '/institution/:institutionId/spaces/:spaceId',
            builder: (context, state) =>
                SpaceScreen(spaceId: state.pathParameters['spaceId'] ?? ''),
          ),
          GoRoute(
            path:
                '/institution/:institutionId/spaces/:spaceId/thread/:threadId',
            builder: (context, state) => ThreadStateWrapper(
              threadId: state.pathParameters['threadId'] ?? '',
            ),
          ),
          GoRoute(
            path: '/institution/:institutionId/members',
            builder: (context, state) => InstitutionMembersScreen(
              institutionId: state.pathParameters['institutionId'] ?? '',
            ),
          ),
          GoRoute(
            path: '/institution/:institutionId/invites',
            builder: (context, state) => InstitutionInvitesScreen(
              institutionId: state.pathParameters['institutionId'] ?? '',
            ),
          ),
          GoRoute(
            path: '/institution/:institutionId/join-requests',
            builder: (context, state) => InstitutionJoinRequestsScreen(
              institutionId: state.pathParameters['institutionId'] ?? '',
            ),
          ),
          GoRoute(
            path: '/institution/:institutionId/explore',
            builder: (context, state) => InstitutionExploreScreen(
              institutionId: state.pathParameters['institutionId'] ?? '',
            ),
          ),
          GoRoute(
            path: '/institution/:institutionId/posts/new',
            builder: (context, state) => InstitutionPostComposerScreen(
              institutionId: state.pathParameters['institutionId'] ?? '',
              defaultScope: state.uri.queryParameters['scope'],
            ),
          ),
          GoRoute(
            path: '/institution/:institutionId/posts/:postId',
            builder: (context, state) => InstitutionPostDetailScreen(
              institutionId: state.pathParameters['institutionId'] ?? '',
              postId: state.pathParameters['postId'] ?? '',
            ),
          ),
          GoRoute(
            path: '/direct/:threadId',
            builder: (context, state) => DirectThreadScreen(
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
            path: '/notifications',
            builder: (_, __) => const NotificationsScreen(),
          ),
          // Phase-2 shell-preserving variants: opening a profile from inside
          // the institution shell keeps the institution actor context (no
          // accidental drop to MemberShell). The screen itself reads the
          // active actor from the route path so the inner Follow/Message
          // buttons act as the institution.
          GoRoute(
            path: '/institution/:institutionId/u/:handle',
            builder: (context, state) => AuthorProfileScreen(
              handle: state.pathParameters['handle'] ?? '',
            ),
          ),
          GoRoute(
            path: '/institution/:institutionId/institutions/:slug',
            builder: (context, state) => InstitutionDetailScreen(
              slug: state.pathParameters['slug'] ?? '',
            ),
          ),
          GoRoute(
            path: '/institution/:institutionId/direct/:threadId',
            builder: (context, state) => DirectThreadScreen(
              threadId: state.pathParameters['threadId'] ?? '',
            ),
          ),
          GoRoute(
            path: '/institution/:institutionId/posts/:postId/edit',
            builder: (context, state) => InstitutionPostComposerScreen(
              institutionId: state.pathParameters['institutionId'] ?? '',
              postId: state.pathParameters['postId'],
            ),
          ),
          GoRoute(
            path: '/institution/:institutionId/activity',
            builder: (context, state) => InstitutionActivityScreen(
              institutionId: state.pathParameters['institutionId'] ?? '',
            ),
          ),
          // Institution billing — backend-gated to OWNER/ADMIN at the
          // checkout endpoint. Screen itself disables purchases on iOS/
          // Android via defaultTargetPlatform.
          GoRoute(
            path: '/institution/:institutionId/billing',
            builder: (context, state) => InstitutionBillingScreen(
              institutionId: state.pathParameters['institutionId'] ?? '',
            ),
          ),
          // /institution/:id/messages — restored to InstitutionMessagingScreen
          // (existing workspace messaging). The new actor-aware direct
          // inbox lives at /institution/:id/messages/direct.
          GoRoute(
            path: '/institution/:institutionId/messages',
            builder: (context, state) => InstitutionMessagingScreen(
              institutionId: state.pathParameters['institutionId'] ?? '',
            ),
          ),
          GoRoute(
            path: '/institution/:institutionId/messages/direct',
            builder: (_, __) => const InboxScreen(),
          ),
        ],
      ),

      // Realtime call routes are intentionally outside the ShellRoute so
      // the call window renders without the member nav/sidebar.
      GoRoute(
        path: '/realtime',
        builder: (_, __) => const RealtimeLobbyScreen(),
      ),
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
          if (meetingId == null && !realtimeSurfaceResolved.contains(sessionId)) {
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
          if (!tokenStore.isAuthed) {
            debugPrint(
              '[killswitch] realtime->join (unauthenticated)'
              ' from=${state.uri} sessionId=$sessionId'
              ' screen=RealtimeRoomScreen',
            );
            return '/meetings/join';
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

class _RouterBootScreen extends StatelessWidget {
  const _RouterBootScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(strokeWidth: 2.4),
        ),
      ),
    );
  }
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
