import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'app_shell.dart';

import '../core/auth/session_providers.dart';
import '../features/auth/presentation/auth_screen.dart';
import '../features/auth/presentation/register_screen.dart';

import '../features/home/presentation/member_home_screen.dart';
import '../features/home/presentation/public_home_screen.dart';
import '../features/search/presentation/search_screen.dart';
import '../features/updates/presentation/updates_screen.dart';
import '../features/me/presentation/me_screen.dart';
import '../features/me/presentation/edit_profile_screen.dart';

import '../features/posts/presentation/compose_screen.dart';
import '../features/posts/presentation/post_detail_screen.dart';
import '../features/profile/presentation/author_profile_screen.dart';
import '../features/monetization/presentation/support_screen.dart';

// Static/document pages (lib/screens/*)
import '../screens/privacy_policy_screen.dart';
import '../screens/mission_screen.dart';
import '../screens/founder_message_screen.dart';
import '../screens/investors_hub_screen.dart';
import '../screens/institutions_hub_screen.dart';
import '../screens/patrons_hub_screen.dart';
import '../screens/supporters_hub_screen.dart';

GoRouter buildRouter(WidgetRef ref) {
  return GoRouter(
    initialLocation: '/public',
    refreshListenable: ref.watch(tokenStoreProvider),
    redirect: (context, state) {
      final isAuthed = ref.read(isAuthedProvider);

      final loc = state.uri.toString();
      final path = state.uri.path;

      // Public landing always exists
      if (path == '/public') {
        return isAuthed ? '/home' : null;
      }

      // Allow /login and /register. If already authed, bounce to target/home.
      if (path == '/login' || path == '/register') {
        if (isAuthed) {
          final target = state.uri.queryParameters['redirect'];
          if (target != null && target.isNotEmpty) return target;
          return '/home';
        }
        return null;
      }

      // Routes that require auth:
      // - compose
      // - me tab and all /me/* routes
      final requiresAuth = path == '/compose' || path == '/me' || path.startsWith('/me/');

      if (requiresAuth && !isAuthed) {
        final redirectTo = Uri.encodeComponent(loc);
        return '/login?redirect=$redirectTo';
      }

      // If not authed, keep shell tabs behind the public landing
      final isShellTab = path == '/home' || path == '/search' || path == '/updates' || path == '/me';
      if (!isAuthed && isShellTab) return '/public';

      return null;
    },
    routes: [
      // Everything that should share the same layout (center/footer/nav rules)
      // goes inside the ShellRoute.
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          // Public landing (NOW inside shell so it centers properly)
          GoRoute(
            path: '/public',
            pageBuilder: (context, state) => const NoTransitionPage(child: PublicHomeScreen()),
          ),

          // Tabs
          GoRoute(
            path: '/home',
            pageBuilder: (context, state) => const NoTransitionPage(child: MemberHomeScreen()),
          ),
          GoRoute(
            path: '/search',
            pageBuilder: (context, state) => const NoTransitionPage(child: SearchScreen()),
          ),
          GoRoute(
            path: '/updates',
            pageBuilder: (context, state) => const NoTransitionPage(child: UpdatesScreen()),
          ),
          GoRoute(
            path: '/me',
            pageBuilder: (context, state) => const NoTransitionPage(child: MeScreen()),
          ),

          // Me sub-routes (keep consistent layout)
          GoRoute(
            path: '/me/profile',
            builder: (context, state) => const EditProfileScreen(),
          ),

          // Content routes (keep consistent layout)
          GoRoute(
            path: '/compose',
            builder: (context, state) {
              final replyTo = state.uri.queryParameters['replyTo'];
              return ComposeScreen(replyToPostId: replyTo);
            },
          ),
          GoRoute(
            path: '/post/:id',
            builder: (context, state) => PostDetailScreen(postId: state.pathParameters['id']!),
          ),
          GoRoute(
            path: '/author/:handle',
            builder: (context, state) => AuthorProfileScreen(handle: state.pathParameters['handle']!),
          ),
          GoRoute(
            path: '/support/:handle',
            builder: (context, state) => SupportScreen(handle: state.pathParameters['handle']!),
          ),

          // Document pages (NOW inside shell)
          GoRoute(
            path: '/privacy',
            builder: (context, state) => const PrivacyPolicyScreen(),
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
            path: '/investors',
            builder: (context, state) => const InvestorsHubScreen(),
          ),

          // Hub placeholders (NOW inside shell)
          GoRoute(
            path: '/institutions',
            builder: (context, state) => const InstitutionsHubScreen(),
          ),
          GoRoute(
            path: '/patrons',
            builder: (context, state) => const PatronsHubScreen(),
          ),
          GoRoute(
            path: '/supporters',
            builder: (context, state) => const SupportersHubScreen(),
          ),
        ],
      ),

      // Auth routes OUTSIDE shell (so no footer/nav while logging in)
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
    ],
  );
}
