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
import 'features/institutions/presentation/institution_detail_screen.dart';
import 'features/saves/presentation/saved_screen.dart';
import 'features/correspondence/presentation/correspondence_hub_screen.dart';

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
import 'screens/enter_institution_screen.dart';
import 'screens/institution_dashboard_screen.dart';
import 'screens/contact_screen.dart';

const String kInstitutionDashboardRoute = '/institution/dashboard';
const String kInstitutionCreateRoute = '/institution/create';
const String kEnterInstitutionRoute = '/enter-institution';

String _normalizeRedirectDest(String? dest) {
  final trimmed = (dest ?? '').trim();
  if (trimmed.isEmpty) return '/home';
  if (trimmed == '/') return '/home';
  if (!trimmed.startsWith('/')) return '/home';
  return trimmed;
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  ref.onDispose(refresh.dispose);

  ref.listen<AuthStatus>(authStatusProvider, (_, __) => refresh.value++);
  ref.listen<AsyncValue<bool>>(emailVerifiedProvider, (_, __) => refresh.value++);
  ref.listen<AsyncValue<void>>(sessionBootstrapProvider, (_, __) => refresh.value++);

  bool isPublicPath(String path) {
    if (path == '/' || path == '/public') return true;

    if (path == '/mission' ||
        path == '/white-paper' ||
        path == '/founder' ||
        path == '/privacy' ||
        path == '/contact' ||
        path == '/investors' ||
        path == '/institutions' ||
        path.startsWith('/institutions/') ||
        path == '/institution/sign-in' ||
        path == kInstitutionCreateRoute ||
        path == '/patrons' ||
        path == '/supporters') {
      return true;
    }

    if (path == '/announcements' || path.startsWith('/announcements/')) {
      return true;
    }

    if (path == '/auth') return true;

    return false;
  }

  bool isMemberPath(String path) {
    return path == '/home' ||
        path == '/search' ||
        path == '/saved' ||
        path == '/updates' ||
        path == '/ai/claim-audit' ||
        path == '/me' ||
        path == '/me/edit' ||
        path == '/me/correspondence' ||
        path == kInstitutionDashboardRoute ||
        path == kEnterInstitutionRoute ||
        path == '/compose' ||
        path.startsWith('/posts/') ||
        path.startsWith('/u/') ||
        path.startsWith('/support/');
  }

  bool isPlainAuthPage(String path) {
    return path == '/login' || path == '/register' || path == '/auth';
  }

  bool isAuthActionPath(String path) {
    return path == '/forgot-password' ||
        path == '/reset-password' ||
        path == '/verify-email' ||
        path == '/verify-pending';
  }

  bool isAnyAuthPath(String path) {
    return isPlainAuthPage(path) || isAuthActionPath(path);
  }

  return GoRouter(
    refreshListenable: refresh,
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
      final uri = state.uri;
      final path = uri.path;

      final boot = ref.read(sessionBootstrapProvider);
      final authStatus = ref.read(authStatusProvider);

      final isPublic = isPublicPath(path);
      final isMember = isMemberPath(path);
      final isPlainAuth = isPlainAuthPage(path);
      final isAuthAction = isAuthActionPath(path);
      final isAuth = isAnyAuthPath(path);

      if (boot.isLoading || authStatus == AuthStatus.loading) {
        return null;
      }

      if (path == '/auth') {
        final dest = uri.queryParameters['redirect'];
        if (dest != null && dest.trim().isNotEmpty) {
          return '/login?redirect=${Uri.encodeComponent(dest)}';
        }
        return '/login';
      }

      if (path == '/') {
        if (authStatus == AuthStatus.unauthed) return '/public';

        final verifiedAsync = ref.read(emailVerifiedProvider);
        if (verifiedAsync.isLoading) return null;

        final verified = verifiedAsync.value ?? false;
        return verified ? '/home' : '/verify-pending';
      }

      if (authStatus == AuthStatus.unauthed) {
        if (isPublic || isAuth) return null;

        final dest = uri.toString();
        return '/login?redirect=${Uri.encodeComponent(dest)}';
      }

      final verifiedAsync = ref.read(emailVerifiedProvider);

      if (verifiedAsync.isLoading) {
        return null;
      }

      final verified = verifiedAsync.value ?? false;

      if (path == '/login' || path == '/register') {
        final redirectTo = uri.queryParameters['redirect'];

        if (!verified) {
          if (redirectTo != null && redirectTo.startsWith('/')) {
            return '/verify-pending?redirect=${Uri.encodeComponent(redirectTo)}';
          }
          return '/verify-pending';
        }

        if (redirectTo != null && redirectTo.startsWith('/')) {
          return _normalizeRedirectDest(redirectTo);
        }

        return '/home';
      }

      if (!verified) {
        if (isPublic || isAuthAction) return null;

        final current = uri.toString();
        return '/verify-pending?redirect=${Uri.encodeComponent(current)}';
      }

      if (path == '/verify-email') {
        final redirectTo = uri.queryParameters['redirect'];
        if (redirectTo != null && redirectTo.startsWith('/')) {
          return _normalizeRedirectDest(redirectTo);
        }
        return kInstitutionDashboardRoute;
      }

      if (path == '/verify-pending') {
        final redirectTo = uri.queryParameters['redirect'];
        if (redirectTo != null && redirectTo.startsWith('/')) {
          return _normalizeRedirectDest(redirectTo);
        }
        return kInstitutionDashboardRoute;
      }

      if (isPlainAuth) {
        final redirectTo = uri.queryParameters['redirect'];
        return _normalizeRedirectDest(redirectTo);
      }

      if (path == '/institution/sign-in') {
        return kInstitutionDashboardRoute;
      }

      if (isPublic || isMember || isAuthAction) {
        return null;
      }

      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (_, __) => const PublicHomeScreen()),
      GoRoute(path: '/auth', redirect: (_, __) => '/login'),
      GoRoute(path: '/feed', redirect: (_, __) => '/home'),

      // Public
      GoRoute(path: '/public', builder: (_, __) => const PublicHomeScreen()),
      GoRoute(path: '/mission', builder: (_, __) => const MissionScreen()),
      GoRoute(path: '/white-paper', builder: (_, __) => const WhitePaperScreen()),
      GoRoute(path: '/founder', builder: (_, __) => const FounderMessageScreen()),
      GoRoute(path: '/privacy', builder: (_, __) => const PrivacyPolicyScreen()),
      GoRoute(path: '/contact', builder: (_, __) => const ContactScreen()),
      GoRoute(path: '/investors', builder: (_, __) => const InvestorsHubScreen()),
      GoRoute(path: '/institutions', builder: (_, __) => const InstitutionsHubScreen()),
      GoRoute(
        path: '/institutions/:slug',
        builder: (context, state) => InstitutionDetailScreen(
          slug: state.pathParameters['slug'] ?? '',
        ),
      ),
      GoRoute(
        path: '/institution/sign-in',
        builder: (_, __) => const InstitutionSignInScreen(),
      ),
      GoRoute(
        path: kInstitutionCreateRoute,
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

      // Auth
      GoRoute(
        path: '/login',
        builder: (context, state) => AuthScreen(
          redirectTo: state.uri.queryParameters['redirect'],
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
        ),
      ),
      GoRoute(
        path: '/verify-pending',
        builder: (context, state) => VerifyPendingScreen(
          email: state.uri.queryParameters['email'],
          redirectTo: state.uri.queryParameters['redirect'],
        ),
      ),

      // Member area
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
          GoRoute(
            path: '/me/correspondence',
            builder: (_, __) => const CorrespondenceHubScreen(),
          ),
          GoRoute(
            path: kEnterInstitutionRoute,
            builder: (_, __) => const EnterInstitutionScreen(),
          ),
          GoRoute(
            path: kInstitutionDashboardRoute,
            builder: (_, __) => const InstitutionDashboardScreen(),
          ),
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