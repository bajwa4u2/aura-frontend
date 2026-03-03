import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'app/app_shell.dart';
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

import 'features/saves/presentation/saved_screen.dart';

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

/// Tracks the last time we were in a stable AUThed state.
/// Used to prevent route thrash when auth briefly flips to unauthed during refresh/me checks.
final _lastAuthedAtProvider = StateProvider<DateTime?>((ref) => null);

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  ref.onDispose(refresh.dispose);

  // Update refresh + lastAuthed timestamp when auth changes.
  ref.listen<AuthStatus>(authStatusProvider, (prev, next) {
    if (next == AuthStatus.authed) {
      ref.read(_lastAuthedAtProvider.notifier).state = DateTime.now();
    }
    refresh.value++;
  });

  // Email verification changes can affect routing decisions.
  ref.listen<AsyncValue<bool>>(emailVerifiedProvider, (_, __) => refresh.value++);

  const publicRoutes = <String>{
    '/announcements',
    '/',
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

  bool isPublicPath(String loc) =>
      publicRoutes.contains(loc) || loc.startsWith('/announcements');
  bool isAuthPath(String loc) => authRoutes.contains(loc);

  String _normalizeRedirectDest(String dest) {
    final trimmed = dest.trim();
    if (trimmed.isEmpty) return '/home';
    if (trimmed == '/') return '/home';
    return trimmed;
  }

  bool _isTransientUnauthed(WidgetRef ref) {
    // Grace window to prevent login-screen thrash while refresh/me checks are stabilizing.
    const grace = Duration(milliseconds: 2500);
    final lastAuthedAt = ref.read(_lastAuthedAtProvider);
    if (lastAuthedAt == null) return false;
    final elapsed = DateTime.now().difference(lastAuthedAt);
    return elapsed >= Duration.zero && elapsed <= grace;
  }

  return GoRouter(
    refreshListenable: refresh,
    redirect: (context, state) async {
      final loc = state.uri.path;
      final authStatus = ref.read(authStatusProvider);

      final isPublic = isPublicPath(loc);
      final isAuth = isAuthPath(loc);

      // 1) While auth is still loading/booting, never redirect.
      // This prevents /login overlay while session restore is in-flight.
      if (authStatus == AuthStatus.loading) return null;

      // 2) UNAUTHED handling (with transient stabilization).
      if (authStatus == AuthStatus.unauthed) {
        // If we were just authed a moment ago, do not redirect to login yet.
        // This prevents route thrash during refresh storms or provider rebuilds.
        if (_isTransientUnauthed(ref)) return null;

        if (isPublic || isAuth) return null;

        final dest = state.uri.toString();
        return '/login?redirect=${Uri.encodeComponent(dest)}';
      }

      // 3) AUTHED handling
      final verifiedAsync = ref.read(emailVerifiedProvider);

      // If verification state is not known yet (loading OR error), don't redirect.
      // Let the app settle and retry /auth/me.
      if (verifiedAsync.isLoading || verifiedAsync.hasError) return null;

      final verified = verifiedAsync.value ?? false;

      if (!verified) {
        // Allow verification + password flows even when not verified.
        if (loc == '/verify-pending' ||
            loc == '/verify-email' ||
            loc == '/forgot-password' ||
            loc == '/reset-password' ||
            isPublic) {
          return null;
        }
        return '/verify-pending';
      }

      // If verified, never keep them stuck on verify screens.
      if (loc == '/verify-pending' || loc == '/verify-email') return '/home';

      // If verified and they visit /public, send them to /home.
      if (loc == '/public') return '/home';

      // If authed + verified, don't keep them on auth pages.
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
          GoRoute(path: '/', redirect: (context, state) => '/public'),

          // Public
          GoRoute(
            path: '/public',
            builder: (context, state) => const PublicHomeScreen(),
          ),
          GoRoute(
            path: '/mission',
            builder: (context, state) => const MissionScreen(),
          ),
          GoRoute(
            path: '/white-paper',
            builder: (context, state) => const WhitePaperScreen(),
          ),
          GoRoute(
            path: '/founder',
            builder: (context, state) => const FounderMessageScreen(),
          ),
          GoRoute(
            path: '/privacy',
            builder: (context, state) => const PrivacyPolicyScreen(),
          ),
          GoRoute(
            path: '/investors',
            builder: (context, state) => const InvestorsHubScreen(),
          ),
          GoRoute(
            path: '/institutions',
            builder: (context, state) => const InstitutionsHubScreen(),
          ),
          GoRoute(
            path: '/institution/sign-in',
            builder: (context, state) => const InstitutionSignInScreen(),
          ),
          GoRoute(
            path: '/institution/request-verification',
            builder: (context, state) =>
                const InstitutionRequestVerificationScreen(),
          ),
          GoRoute(
            path: '/patrons',
            builder: (context, state) => const PatronsHubScreen(),
          ),
          GoRoute(
            path: '/supporters',
            builder: (context, state) => const SupportersHubScreen(),
          ),

          // Auth
          GoRoute(
            path: '/login',
            builder: (context, state) =>
                AuthScreen(redirectTo: state.uri.queryParameters['redirect']),
          ),
          GoRoute(
            path: '/register',
            builder: (context, state) => const RegisterScreen(),
          ),
          GoRoute(
            path: '/forgot-password',
            builder: (context, state) => const ForgotPasswordScreen(),
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
            ),
          ),
          GoRoute(
            path: '/verify-pending',
            builder: (context, state) => const VerifyPendingScreen(),
          ),

          // Member
          GoRoute(
            path: '/home',
            builder: (context, state) => const MemberHomeScreen(),
          ),
          GoRoute(
            path: '/search',
            builder: (context, state) => const SearchScreen(),
          ),
          GoRoute(
            path: '/saved',
            builder: (context, state) => const SavedScreen(),
          ),
          GoRoute(
            path: '/updates',
            builder: (context, state) => const UpdatesScreen(),
          ),
          GoRoute(
            path: '/announcements',
            builder: (context, state) => const AnnouncementsScreen(),
          ),
          GoRoute(
            path: '/announcements/:slug',
            builder: (context, state) => AnnouncementDetailScreen(
              slug: state.pathParameters['slug'] ?? '',
            ),
          ),
          GoRoute(
            path: '/ai/claim-audit',
            builder: (context, state) => const ClaimAuditScreen(),
          ),
          GoRoute(path: '/me', builder: (context, state) => const MeScreen()),
          GoRoute(
            path: '/me/edit',
            builder: (context, state) => const EditProfileScreen(),
          ),
          GoRoute(
            path: '/compose',
            builder: (context, state) => const ComposeScreen(),
          ),
          GoRoute(
            path: '/posts/:id',
            builder: (context, state) =>
                PostDetailScreen(postId: state.pathParameters['id'] ?? ''),
          ),
          GoRoute(
            path: '/u/:handle',
            builder: (context, state) => AuthorProfileScreen(
              handle: state.pathParameters['handle'] ?? '',
            ),
          ),
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