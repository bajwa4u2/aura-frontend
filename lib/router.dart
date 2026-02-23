import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'app/app_shell.dart';

import 'core/auth/auth_providers.dart';

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
import 'features/me/presentation/me_screen.dart';
import 'features/me/presentation/edit_profile_screen.dart';
import 'features/posts/presentation/compose_screen.dart';
import 'features/posts/presentation/post_detail_screen.dart';
import 'features/profile/presentation/author_profile_screen.dart';
import 'features/monetization/presentation/support_screen.dart';

import 'screens/mission_screen.dart';
import 'screens/founder_message_screen.dart';
import 'screens/privacy_policy_screen.dart';
import 'screens/investors_hub_screen.dart';
import 'screens/institutions_hub_screen.dart';
import 'screens/patrons_hub_screen.dart';
import 'screens/supporters_hub_screen.dart';
import 'screens/institution_sign_in_screen.dart';
import 'screens/institution_request_verification_screen.dart';

/// Canonical router provider for the app.
/// This is the only router AuraApp should use.
final routerProvider = Provider<GoRouter>((ref) {
  final store = ref.watch(tokenStoreProvider);

  return GoRouter(
    initialLocation: '/public',
    refreshListenable: store,
    redirect: (context, state) async {
      final loc = state.matchedLocation;

      // 1) Anti-bounce lock: never redirect until tokens are restored.
      if (!store.isLoaded) return null;
      // If you prefer to hard-wait (rarely needed), use:
      // await store.waitUntilLoaded();

      final authStatus = ref.read(authStatusProvider);

      // Routes that should always be reachable without auth.
      const publicRoutes = <String>{
        '/public',
        '/mission',
        '/founder',
        '/privacy',
        '/investors',
        '/institutions',
        '/institution/sign-in',
        '/institution/request-verification',
        '/patrons',
        '/supporters',
      };

      // Auth flow routes (also public).
      const authRoutes = <String>{
        '/login',
        '/register',
        '/forgot-password',
        '/reset-password',
        '/verify-email',
        '/verify-pending',
      };

      final isPublic = publicRoutes.contains(loc);
      final isAuth = authRoutes.contains(loc);

      // During startup token restore, never bounce.
      if (authStatus == AuthStatus.loading) return null;

      // 2) Unauthed: allow public + auth; anything else -> login with redirect.
      if (authStatus == AuthStatus.unauthed) {
        if (isPublic || isAuth) return null;

        final dest = state.uri.toString();
        return '/login?redirect=${Uri.encodeComponent(dest)}';
      }

      // 3) Authed: now decide verification.
      final verifiedAsync = ref.read(emailVerifiedProvider);

      // While loading verification state, don't bounce.
      if (verifiedAsync.isLoading) return null;

      final verified = verifiedAsync.valueOrNull ?? false;

      // 4) Unverified: force verify-pending, but allow verify-email deep link and reset flows.
      if (!verified) {
        if (loc == '/verify-pending' ||
            loc == '/verify-email' ||
            loc == '/forgot-password' ||
            loc == '/reset-password' ||
            isPublic) {
          return null;
        }
        return '/verify-pending';
      }

      // 5) Verified: never let verified users sit on auth screens again.
      // Your rule: after login, land on /me.
      if (isAuth) {
        // If they came with a redirect query, honor it (only if it is an internal path).
        final redirectTo = state.uri.queryParameters['redirect'];
        if (redirectTo != null && redirectTo.startsWith('/')) {
          return redirectTo;
        }
        return '/me';
      }

      return null;
    },
    routes: [
      // Keep AppShell global frame (footer, nav rules) across public + member routes.
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          // Public entry
          GoRoute(
            path: '/public',
            builder: (context, state) => const PublicHomeScreen(),
          ),
          GoRoute(
            path: '/mission',
            builder: (context, state) => const MissionScreen(),
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
            builder: (context, state) => const InstitutionRequestVerificationScreen(),
          ),
          GoRoute(
            path: '/patrons',
            builder: (context, state) => const PatronsHubScreen(),
          ),
          GoRoute(
            path: '/supporters',
            builder: (context, state) => const SupportersHubScreen(),
          ),

          // Auth (public)
          GoRoute(
            path: '/login',
            builder: (context, state) {
              final redirectTo = state.uri.queryParameters['redirect'];
              return AuthScreen(redirectTo: redirectTo);
            },
          ),
          GoRoute(
            path: '/register',
            builder: (context, state) {
              final redirectTo = state.uri.queryParameters['redirect'];
              return RegisterScreen(redirectTo: redirectTo);
            },
          ),
          GoRoute(
            path: '/verify-pending',
            builder: (context, state) => const VerifyPendingScreen(),
          ),
          GoRoute(
            path: '/verify-email',
            builder: (context, state) {
              final redirectTo = state.uri.queryParameters['redirect'];
              final token = state.uri.queryParameters['token'];
              return VerifyEmailScreen(token: token, redirectTo: redirectTo);
            },
          ),
          GoRoute(
            path: '/forgot-password',
            builder: (context, state) => const ForgotPasswordScreen(),
          ),
          GoRoute(
            path: '/reset-password',
            builder: (context, state) {
              final token = state.uri.queryParameters['token'] ?? '';
              return ResetPasswordScreen(initialToken: token);
            },
          ),

          // Member area
          GoRoute(
            path: '/home',
            builder: (context, state) => const MemberHomeScreen(),
          ),
          GoRoute(
            path: '/search',
            builder: (context, state) => const SearchScreen(),
          ),
          GoRoute(
            path: '/updates',
            builder: (context, state) => const UpdatesScreen(),
          ),
          GoRoute(
            path: '/me',
            builder: (context, state) => const MeScreen(),
          ),
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
            builder: (context, state) =>
                AuthorProfileScreen(handle: state.pathParameters['handle'] ?? ''),
          ),
          GoRoute(
            path: '/support/:handle',
            builder: (context, state) =>
                SupportScreen(handle: state.pathParameters['handle'] ?? ''),
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