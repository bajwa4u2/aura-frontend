import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'app/app_shell.dart';

// Single source of truth for auth state.
import 'core/auth/session_providers.dart';

import 'features/auth/presentation/auth_screen.dart';
import 'features/auth/presentation/register_screen.dart';
import 'features/auth/presentation/verify_email_screen.dart';
import 'features/auth/presentation/verify_pending_screen.dart';
import 'features/auth/presentation/forgot_password_screen.dart';
import 'features/auth/presentation/reset_password_screen.dart';

import 'features/home/presentation/public_home_screen.dart';
import 'features/home/presentation/member_home_screen.dart';
import 'features/search/presentation/search_screen.dart';
import 'features/updates/presentation/updates_screen.dart';
import 'features/announcements/presentation/announcements_screen.dart';
import 'features/announcements/presentation/announcement_detail_screen.dart';
import 'features/ai/presentation/claim_audit_screen.dart';
import 'features/me/presentation/me_screen.dart';
import 'features/me/presentation/edit_profile_screen.dart';
import 'features/posts/presentation/compose_screen.dart';
import 'features/posts/presentation/post_detail_screen.dart';
import 'features/profile/presentation/author_profile_screen.dart';

// SAVES
import 'features/saves/presentation/saved_screen.dart';

// Support fallback
import 'screens/support_fallback_screen.dart';

import 'screens/mission_screen.dart';
import 'screens/white_paper_screen.dart';
import 'screens/founder_message_screen.dart';
import 'screens/privacy_policy_screen.dart';
import 'screens/investors_hub_screen.dart';
import 'screens/institutions_hub_screen.dart';
import 'screens/patrons_hub_screen.dart';
import 'screens/supporters_hub_screen.dart';
import 'screens/institution_sign_in_screen.dart';
import 'screens/institution_request_verification_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  // Refresh router when auth / verification changes.
  final refresh = ValueNotifier<int>(0);
  ref.onDispose(refresh.dispose);

  ref.listen<AuthStatus>(authStatusProvider, (_, __) => refresh.value++);
  ref.listen<AsyncValue<bool>>(emailVerifiedProvider, (_, __) => refresh.value++);

  const publicRoutes = <String>{
    '/announcements',
    '/public',
    '/mission',
    '/white-paper',
    '/founder',
    '/privacy',
    '/investors',
    '/institutions',
    '/institution/sign-in',
    '/institution/request-verification',
    '/patrons',
    '/supporters',
  };

  const authRoutes = <String>{
    '/login',
    '/register',
    '/forgot-password',
    '/reset-password',
    '/verify-email',
    '/verify-pending',
  };

  bool isPublicPath(String loc) => publicRoutes.contains(loc) || loc.startsWith('/announcements');
  bool isAuthPath(String loc) => authRoutes.contains(loc);

  // Normalize redirect destinations coming from query params.
  // We never want to navigate to "/" because we don't treat it as a real screen.
  String _normalizeRedirectDest(String dest) {
    final trimmed = dest.trim();
    if (trimmed.isEmpty) return '/home';
    if (trimmed == '/') return '/home';
    return trimmed;
  }

  return GoRouter(
    // IMPORTANT: Do not force initialLocation here.
    // Let browser deep links win (reset-password, verify-email, etc.)
    refreshListenable: refresh,
    redirect: (context, state) async {
      final loc = state.uri.path;

      final authStatus = ref.read(authStatusProvider);

      // Never redirect while auth bootstrap is running.
      if (authStatus == AuthStatus.loading) return null;

      final isPublic = isPublicPath(loc);
      final isAuth = isAuthPath(loc);

      // --- UNAUNTHED ---
      if (authStatus == AuthStatus.unauthed) {
        if (isPublic || isAuth) return null;

        final dest = state.uri.toString();
        return '/login?redirect=${Uri.encodeComponent(dest)}';
      }

      // --- AUTHED ---
      // If authed, wait for emailVerifiedProvider to resolve before forcing verify routes.
      final verifiedAsync = ref.read(emailVerifiedProvider);

      // If verification status is still loading, do NOT redirect into verify-pending.
      if (verifiedAsync.isLoading) {
        return null;
      }

      final verified = verifiedAsync.valueOrNull ?? false;

      if (!verified) {
        // Allow public routes + verification + password flows.
        if (loc == '/verify-pending' ||
            loc == '/verify-email' ||
            loc == '/forgot-password' ||
            loc == '/reset-password' ||
            isPublic) {
          return null;
        }
        return '/verify-pending';
      }

      // Verified authed: normalize public landing
      if (loc == '/public') return '/home';

      // If already authed and someone hits auth screens, send them onward.
      if (isAuth) {
        final redirectTo = state.uri.queryParameters['redirect'];
        if (redirectTo != null && redirectTo.startsWith('/')) {
          return _normalizeRedirectDest(redirectTo);
        }
        return '/me';
      }

      return null;
    },
    routes: [
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          // Root: always land somewhere real.
          // This prevents "GoException: no routes for location: /"
          GoRoute(
            path: '/',
            redirect: (context, state) => '/public',
          ),

          // Public
          GoRoute(path: '/public', builder: (context, state) => const PublicHomeScreen()),
          GoRoute(path: '/mission', builder: (context, state) => const MissionScreen()),
          GoRoute(path: '/white-paper', builder: (context, state) => const WhitePaperScreen()),
          GoRoute(path: '/founder', builder: (context, state) => const FounderMessageScreen()),
          GoRoute(path: '/privacy', builder: (context, state) => const PrivacyPolicyScreen()),
          GoRoute(path: '/investors', builder: (context, state) => const InvestorsHubScreen()),
          GoRoute(path: '/institutions', builder: (context, state) => const InstitutionsHubScreen()),
          GoRoute(path: '/institution/sign-in', builder: (context, state) => const InstitutionSignInScreen()),
          GoRoute(
            path: '/institution/request-verification',
            builder: (context, state) => const InstitutionRequestVerificationScreen(),
          ),
          GoRoute(path: '/patrons', builder: (context, state) => const PatronsHubScreen()),
          GoRoute(path: '/supporters', builder: (context, state) => const SupportersHubScreen()),

          // Auth
          GoRoute(
            path: '/login',
            builder: (context, state) => AuthScreen(
              redirectTo: state.uri.queryParameters['redirect'],
            ),
          ),
          GoRoute(path: '/register', builder: (context, state) => const RegisterScreen()),
          GoRoute(path: '/forgot-password', builder: (context, state) => const ForgotPasswordScreen()),
          GoRoute(path: '/reset-password', builder: (context, state) => const ResetPasswordScreen()),
          GoRoute(path: '/verify-email', builder: (context, state) => const VerifyEmailScreen()),
          GoRoute(path: '/verify-pending', builder: (context, state) => const VerifyPendingScreen()),

          // Member
          GoRoute(path: '/home', builder: (context, state) => const MemberHomeScreen()),
          GoRoute(path: '/search', builder: (context, state) => const SearchScreen()),
          GoRoute(path: '/saved', builder: (context, state) => const SavedScreen()),
          GoRoute(path: '/updates', builder: (context, state) => const UpdatesScreen()),
          GoRoute(path: '/announcements', builder: (context, state) => const AnnouncementsScreen()),
          GoRoute(
            path: '/announcements/:slug',
            builder: (context, state) => AnnouncementDetailScreen(slug: state.pathParameters['slug'] ?? ''),
          ),
          GoRoute(path: '/ai/claim-audit', builder: (context, state) => const ClaimAuditScreen()),
          GoRoute(path: '/me', builder: (context, state) => const MeScreen()),
          GoRoute(path: '/me/edit', builder: (context, state) => const EditProfileScreen()),
          GoRoute(path: '/compose', builder: (context, state) => const ComposeScreen()),
          GoRoute(
            path: '/posts/:id',
            builder: (context, state) => PostDetailScreen(postId: state.pathParameters['id'] ?? ''),
          ),
          GoRoute(
            path: '/u/:handle',
            builder: (context, state) => AuthorProfileScreen(handle: state.pathParameters['handle'] ?? ''),
          ),

          // Support (compile-safe fallback)
          GoRoute(
            path: '/support/:handle',
            builder: (context, state) => SupportFallbackScreen(
              handle: state.pathParameters['handle'] ?? '',
            ),
          ),
        ],
      ),
    ],
  );
});

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