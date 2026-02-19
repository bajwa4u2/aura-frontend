import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/auth/session_providers.dart';
import '../core/net/dio_provider.dart';

// Shell + screens
import '../features/shell/app_shell.dart';
import '../features/home/presentation/member_home_screen.dart';
import '../features/search/presentation/search_screen.dart';
import '../features/updates/presentation/updates_screen.dart';
import '../features/me/presentation/me_screen.dart';
import '../features/compose/presentation/compose_screen.dart';
import '../features/posts/presentation/post_detail_screen.dart';
import '../features/authors/presentation/author_profile_screen.dart';
import '../features/support/presentation/support_screen.dart';

// Docs (in shell)
import '../features/legal/privacy_policy_screen.dart';
import '../features/docs/mission_screen.dart';
import '../features/docs/founder_message_screen.dart';
import '../features/docs/investors_hub_screen.dart';

// Auth
import '../features/auth/presentation/auth_screen.dart';
import '../features/auth/presentation/verify_pending_screen.dart';
import '../features/auth/presentation/verify_email_screen.dart';

Map<String, dynamic>? _unwrapUser(dynamic data) {
  if (data == null) return null;
  if (data is Map) {
    final m = Map<String, dynamic>.from(data as Map);

    // Support common envelope shapes:
    // { data: {...} } or { user: {...} }
    final inner = m['data'] ?? m['user'];
    if (inner is Map) return Map<String, dynamic>.from(inner as Map);

    // Or already user-like map
    return m;
  }
  return null;
}

/// Fetch current user (authed). Used only for verification gating.
/// Supports both:
/// - GET /users/me -> { ...userFields... }
/// - GET /users/me -> { data: { ...userFields... } }
/// - GET /users/me -> { user: { ...userFields... } }
final meForGateProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  final dio = ref.read(dioProvider);
  try {
    final res = await dio.get('/users/me');
    return _unwrapUser(res.data);
  } on DioException catch (e) {
    // If token expired or missing, treat as "no user" and let auth redirect handle it.
    if (e.response?.statusCode == 401) return null;
    rethrow;
  }
});

bool _isEmailVerified(Map<String, dynamic>? me) {
  if (me == null) return true; // don't hard-lock on missing data

  // Forever-truth: emailVerifiedAt (timestamp or null)
  final verifiedAt = me['emailVerifiedAt'];
  if (verifiedAt != null) {
    // could be ISO string or DateTime-ish; any non-null means verified
    return true;
  }

  // Back/forward compatibility with boolean-style APIs
  final candidates = [
    me['emailVerified'],
    me['isEmailVerified'],
    me['verified'],
    me['isVerified'],
  ];
  for (final v in candidates) {
    if (v is bool) return v;
    if (v is String) {
      final t = v.trim().toLowerCase();
      if (t == 'true') return true;
      if (t == 'false') return false;
    }
    if (v is num) {
      if (v == 1) return true;
      if (v == 0) return false;
    }
  }

  // If the backend exposes neither field, do not block.
  return true;
}

GoRouter buildRouter(WidgetRef ref) {
  return GoRouter(
    initialLocation: '/home',
    redirect: (context, state) async {
      final isAuthed = ref.read(isAuthedProvider);
      final path = state.uri.path;
      final fullLoc = state.uri.toString();

      // Public routes
      final isPublicAuthRoute = path == '/login' || path == '/verify-email';

      // If already authed and hits /login, go to redirect target or home.
      if (path == '/login') {
        if (isAuthed) {
          final target = state.uri.queryParameters['redirect'];
          if (target != null && target.isNotEmpty) return target;
          return '/home';
        }
        return null;
      }

      // Verification routes:
      // - /verify-email is public (user comes from email link)
      // - /verify-pending is authed-only (needs resend for logged-in user)
      final isVerifyPending = path == '/verify-pending';
      final isVerifyEmail = path == '/verify-email';

      // If route requires auth:
      final requiresAuth = path == '/me' || path == '/compose' || path == '/verify-pending';

      if (requiresAuth && !isAuthed) {
        final redirectTo = Uri.encodeComponent(fullLoc);
        return '/login?redirect=$redirectTo';
      }

      // If authed, enforce verification gate (Option A).
      // Allow these routes while unverified:
      // - /verify-pending (the gate screen)
      // - /verify-email (link landing / finalize)
      // - /login (won't happen when authed, but harmless)
      if (isAuthed && !isVerifyEmail && !isPublicAuthRoute) {
        final me = await ref.read(meForGateProvider.future);
        final verified = _isEmailVerified(me);

        if (!verified) {
          final allowedWhileUnverified = (path == '/verify-pending' || path == '/verify-email');
          if (!allowedWhileUnverified) {
            return '/verify-pending?redirect=${Uri.encodeComponent(fullLoc)}';
          }
        }
      }

      // If user is verified and somehow stuck on verify-pending, release them.
      if (isAuthed && isVerifyPending) {
        final me = await ref.read(meForGateProvider.future);
        final verified = _isEmailVerified(me);
        if (verified) {
          final target = state.uri.queryParameters['redirect'];
          if (target != null && target.isNotEmpty) return target;
          return '/home';
        }
      }

      return null;
    },
    routes: [
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
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

          // Content routes
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

          // Document pages (inside shell)
          GoRoute(path: '/privacy', builder: (context, state) => const PrivacyPolicyScreen()),
          GoRoute(path: '/mission', builder: (context, state) => const MissionScreen()),
          GoRoute(path: '/founder', builder: (context, state) => const FounderMessageScreen()),
          GoRoute(path: '/investors', builder: (context, state) => const InvestorsHubScreen()),
        ],
      ),

      // Auth outside shell
      GoRoute(
        path: '/login',
        builder: (context, state) {
          final redirectTo = state.uri.queryParameters['redirect'];
          return AuthScreen(redirectTo: redirectTo);
        },
      ),

      // Option A gate screen (authed only)
      GoRoute(
        path: '/verify-pending',
        builder: (context, state) {
          final redirectTo = state.uri.queryParameters['redirect'];
          return VerifyPendingScreen(redirectTo: redirectTo);
        },
      ),

      // Email link landing (public)
      GoRoute(
        path: '/verify-email',
        builder: (context, state) {
          final token = state.uri.queryParameters['token'];
          return VerifyEmailScreen(token: token);
        },
      ),
    ],
  );
}
