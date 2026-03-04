import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'app/app_shell.dart';
import 'core/auth/auth_providers.dart';
import 'core/auth/session_bootstrap.dart';
import 'core/auth/session_providers.dart';

// Auth
import 'features/auth/presentation/auth_screen.dart';
import 'features/auth/presentation/register_screen.dart';
import 'features/auth/presentation/verify_email_screen.dart';
import 'features/auth/presentation/verify_pending_screen.dart';
import 'features/auth/presentation/forgot_password_screen.dart';
import 'features/auth/presentation/reset_password_screen.dart';

// Public / Member
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

// Static screens
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

bool _isTransientUnauthed(Ref ref) {
  final boot = ref.read(sessionBootstrapProvider);
  if (boot.isLoading) return true;

  final store = ref.read(tokenStoreProvider);
  if (!store.isLoaded) return true;

  return false;
}

String _normalizeRedirectDest(String dest) {
  final trimmed = dest.trim();
  if (trimmed.isEmpty) return '/home';
  if (trimmed == '/') return '/home';
  return trimmed;
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  ref.onDispose(refresh.dispose);

  ref.listen<AuthStatus>(authStatusProvider, (_, __) => refresh.value++);
  ref.listen<AsyncValue<bool>>(emailVerifiedProvider, (_, __) => refresh.value++);

  bool isPublicPath(String path) {
    if (path == '/' || path == '/public') return true;

    if (path == '/mission' ||
        path == '/white-paper' ||
        path == '/founder' ||
        path == '/privacy' ||
        path == '/investors' ||
        path == '/institutions' ||
        path == '/institution/sign-in' ||
        path == '/institution/request-verification' ||
        path == '/patrons' ||
        path == '/supporters') {
      return true;
    }

    if (path == '/announcements' || path.startsWith('/announcements/')) return true;

    // legacy alias is public-safe
    if (path == '/auth') return true;

    return false;
  }

  bool isAuthPath(String path) {
    return path == '/login' ||
        path == '/register' ||
        path == '/forgot-password' ||
        path == '/reset-password' ||
        path == '/verify-email' ||
        path == '/verify-pending' ||
        path == '/auth'; // legacy alias
  }

  return GoRouter(
    initialLocation: '/boot',
    refreshListenable: refresh,

    // If anything isn't wired, don't show a dead blank page.
    errorBuilder: (context, state) {
      final path = state.uri.toString();
      return Scaffold(
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Page not found',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Route: $path',
                    style: const TextStyle(fontSize: 13, color: Colors.black54),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      FilledButton(
                        onPressed: () => context.go('/home'),
                        child: const Text('Go to Home'),
                      ),
                      OutlinedButton(
                        onPressed: () => context.go('/public'),
                        child: const Text('Public home'),
                      ),
                      OutlinedButton(
                        onPressed: () => context.go('/login'),
                        child: const Text('Sign in'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },

    redirect: (context, state) async {
      final path = state.uri.path;
      final authStatus = ref.read(authStatusProvider);

      // ------------------------------------------------------------
      // BOOT GATE: never render public/home until bootstrap settles
      // ------------------------------------------------------------
      if (_isTransientUnauthed(ref)) {
        return path == '/boot' ? null : '/boot';
      }

      if (authStatus == AuthStatus.loading) {
        return path == '/boot' ? null : '/boot';
      }

      // Once stable, /boot decides where to go and exits.
      if (path == '/boot') {
        if (authStatus == AuthStatus.unauthed) return '/public';

        final verifiedAsync = ref.read(emailVerifiedProvider);
        if (verifiedAsync.isLoading || verifiedAsync.hasError) return '/verify-pending';

        final verified = verifiedAsync.value ?? false;
        return verified ? '/home' : '/verify-pending';
      }

      // Alias: some older UI calls /auth
      if (path == '/auth') {
        final dest = state.uri.queryParameters['redirect'];
        if (dest != null && dest.trim().isNotEmpty) {
          return '/login?redirect=${Uri.encodeComponent(dest)}';
        }
        return '/login';
      }

      final isPublic = isPublicPath(path);
      final isAuth = isAuthPath(path);

      // -------------------------
      // UNAUTHED
      // -------------------------
      if (authStatus == AuthStatus.unauthed) {
        if (isPublic || isAuth) return null;

        final dest = state.uri.toString();
        return '/login?redirect=${Uri.encodeComponent(dest)}';
      }

      // -------------------------
      // AUTHED
      // -------------------------

      // If we just became authed and are still on login/register, move to verify-pending
      // carrying redirect if present.
      if (path == '/login' || path == '/register') {
        final redirectTo = state.uri.queryParameters['redirect'];
        if (redirectTo != null && redirectTo.startsWith('/')) {
          return '/verify-pending?redirect=${Uri.encodeComponent(redirectTo)}';
        }
        return '/verify-pending';
      }

      final verifiedAsync = ref.read(emailVerifiedProvider);
      if (verifiedAsync.isLoading || verifiedAsync.hasError) return null;
      final verified = verifiedAsync.value ?? false;

      if (!verified) {
        if (isPublic ||
            path == '/verify-pending' ||
            path == '/verify-email' ||
            path == '/forgot-password' ||
            path == '/reset-password') {
          return null;
        }
        return '/verify-pending';
      }

      // Verified: never stay on verify screens
      if (path == '/verify-email') return '/home';
      if (path == '/verify-pending') {
        final redirectTo = state.uri.queryParameters['redirect'];
        if (redirectTo != null && redirectTo.startsWith('/')) {
          return _normalizeRedirectDest(redirectTo);
        }
        return '/home';
      }

      // If authed user hits auth pages, take them to redirect or /me
      if (isAuth) {
        final redirectTo = state.uri.queryParameters['redirect'];
        if (redirectTo != null && redirectTo.startsWith('/')) {
          return _normalizeRedirectDest(redirectTo);
        }
        return '/me';
      }

      // Authed users: "/" is member landing. Public pages still accessible via /public etc.
      if (path == '/') return '/home';

      return null;
    },

    routes: [
      // Boot gate (blank)
      GoRoute(
        path: '/boot',
        builder: (_, __) => const Scaffold(body: SizedBox.shrink()),
      ),

      // Root is public landing (authed users get redirected to /home in redirect())
      GoRoute(path: '/', builder: (_, __) => const PublicHomeScreen()),

      // Legacy alias used by some UI calls
      GoRoute(path: '/auth', redirect: (_, __) => '/login'),

      // Back-compat alias: older UI navigates to /feed
      GoRoute(path: '/feed', redirect: (_, __) => '/home'),

      // -------------------------
      // Public + Auth (NO AppShell)
      // -------------------------
      GoRoute(path: '/public', builder: (_, __) => const PublicHomeScreen()),
      GoRoute(path: '/mission', builder: (_, __) => const MissionScreen()),
      GoRoute(path: '/white-paper', builder: (_, __) => const WhitePaperScreen()),
      GoRoute(path: '/founder', builder: (_, __) => const FounderMessageScreen()),
      GoRoute(path: '/privacy', builder: (_, __) => const PrivacyPolicyScreen()),
      GoRoute(path: '/investors', builder: (_, __) => const InvestorsHubScreen()),
      GoRoute(path: '/institutions', builder: (_, __) => const InstitutionsHubScreen()),
      GoRoute(path: '/institution/sign-in', builder: (_, __) => const InstitutionSignInScreen()),
      GoRoute(
        path: '/institution/request-verification',
        builder: (_, __) => const InstitutionRequestVerificationScreen(),
      ),
      GoRoute(path: '/patrons', builder: (_, __) => const PatronsHubScreen()),
      GoRoute(path: '/supporters', builder: (_, __) => const SupportersHubScreen()),
      GoRoute(path: '/announcements', builder: (_, __) => const AnnouncementsScreen()),
      GoRoute(
        path: '/announcements/:slug',
        builder: (context, state) => AnnouncementDetailScreen(
          slug: state.pathParameters['slug'] ?? '',
        ),
      ),

      // Auth screens (NO AppShell)
      GoRoute(
        path: '/login',
        builder: (context, state) => AuthScreen(
          redirectTo: state.uri.queryParameters['redirect'],
        ),
      ),
      GoRoute(path: '/register', builder: (_, __) => const RegisterScreen()),
      GoRoute(path: '/forgot-password', builder: (_, __) => const ForgotPasswordScreen()),
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
      GoRoute(path: '/verify-pending', builder: (_, __) => const VerifyPendingScreen()),

      // -------------------------
      // Member area (WITH AppShell)
      // -------------------------
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(path: '/home', builder: (_, __) => const MemberHomeScreen()),
          GoRoute(path: '/search', builder: (_, __) => const SearchScreen()),
          GoRoute(path: '/saved', builder: (_, __) => const SavedScreen()),
          GoRoute(path: '/updates', builder: (_, __) => const UpdatesScreen()),
          GoRoute(path: '/ai/claim-audit', builder: (_, __) => const ClaimAuditScreen()),
          GoRoute(path: '/me', builder: (_, __) => const MeScreen()),
          GoRoute(path: '/me/edit', builder: (_, __) => const EditProfileScreen()),
          GoRoute(path: '/compose', builder: (_, __) => const ComposeScreen()),
          GoRoute(
            path: '/posts/:id',
            builder: (context, state) => PostDetailScreen(
              postId: state.pathParameters['id'] ?? '',
            ),
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