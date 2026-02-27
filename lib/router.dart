import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'app/app_shell.dart';

// ✅ Use the existing auth boolean provider (we know this exists in your project)
import 'core/auth/session_providers.dart';

// Screens / features
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

import 'features/saves/presentation/saved_screen.dart';

import 'screens/support_fallback_screen.dart';

import 'screens/mission_screen.dart';
import 'screens/founder_message_screen.dart';
import 'screens/privacy_policy_screen.dart';
import 'screens/investors_hub_screen.dart';
import 'screens/institutions_hub_screen.dart';
import 'screens/patrons_hub_screen.dart';
import 'screens/supporters_hub_screen.dart';
import 'screens/institution_sign_in_screen.dart';
import 'screens/institution_request_verification_screen.dart';

// NEW
import 'screens/white_paper_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  // ✅ This exists in your repo and is used elsewhere.
  final isAuthed = ref.watch(isAuthedProvider);

  return GoRouter(
    initialLocation: '/public',
    redirect: (context, state) {
      final loc = state.uri.toString();

      // Public routes always allowed
      const publicPrefixes = <String>[
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
        '/support/',
      ];

      final isPublic = publicPrefixes.any((p) => loc.startsWith(p));

      // Auth routes
      final isAuthRoute = loc.startsWith('/auth') ||
          loc.startsWith('/register') ||
          loc.startsWith('/verify-email') ||
          loc.startsWith('/verify-pending') ||
          loc.startsWith('/forgot-password') ||
          loc.startsWith('/reset-password');

      // If not authed, block member-only routes
      if (!isAuthed && !isPublic && !isAuthRoute) {
        return '/auth';
      }

      // If authed, avoid landing on auth/register
      if (isAuthed && (loc == '/auth' || loc == '/register')) {
        return '/home';
      }

      return null;
    },
    routes: [
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
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
          GoRoute(path: '/auth', builder: (context, state) => const AuthScreen()),
          GoRoute(path: '/register', builder: (context, state) => const RegisterScreen()),
          GoRoute(path: '/verify-email', builder: (context, state) => const VerifyEmailScreen()),
          GoRoute(path: '/verify-pending', builder: (context, state) => const VerifyPendingScreen()),
          GoRoute(path: '/forgot-password', builder: (context, state) => const ForgotPasswordScreen()),
          GoRoute(path: '/reset-password', builder: (context, state) => const ResetPasswordScreen()),

          // Member
          GoRoute(path: '/home', builder: (context, state) => const MemberHomeScreen()),
          GoRoute(path: '/search', builder: (context, state) => const SearchScreen()),
          GoRoute(path: '/updates', builder: (context, state) => const UpdatesScreen()),
          GoRoute(path: '/me', builder: (context, state) => const MeScreen()),
          GoRoute(path: '/me/edit', builder: (context, state) => const EditProfileScreen()),
          GoRoute(path: '/compose', builder: (context, state) => const ComposeScreen()),
          GoRoute(
            path: '/post/:id',
            builder: (context, state) => PostDetailScreen(
              postId: state.pathParameters['id'] ?? '',
            ),
          ),
          GoRoute(
            path: '/author/:handle',
            builder: (context, state) => AuthorProfileScreen(
              handle: state.pathParameters['handle'] ?? '',
            ),
          ),
          GoRoute(path: '/saved', builder: (context, state) => const SavedScreen()),

          // Support fallback
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