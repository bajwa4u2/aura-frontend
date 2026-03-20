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
import 'features/conversations/presentation/conversations_screen.dart';
import 'features/activity/presentation/activity_screen.dart';
import 'features/announcements/presentation/announcements_screen.dart';
import 'features/announcements/presentation/announcement_detail_screen.dart';
import 'features/announcements/presentation/announcement_editor_screen.dart';
import 'features/ai/presentation/claim_audit_screen.dart';
import 'features/me/presentation/me_screen.dart';
import 'features/me/presentation/edit_profile_screen.dart';
import 'features/me/presentation/security_screen.dart';
import 'features/posts/presentation/compose_screen.dart';
import 'features/posts/presentation/post_detail_screen.dart';
import 'features/profile/presentation/author_profile_screen.dart';
import 'features/profile/presentation/follow_requests_screen.dart';
import 'features/profile/presentation/followers_screen.dart';
import 'features/profile/presentation/following_screen.dart';
import 'features/institutions/presentation/institution_detail_screen.dart';
import 'features/institutions/presentation/institution_dashboard_screen.dart';
import 'features/institutions/domain/institution_domains_screen.dart';
import 'features/institutions/profile/institution_profile_screen.dart';
import 'features/institutions/verification/institution_request_verification_screen.dart';
import 'features/institutions/announcements/institution_announcements_screen.dart';
import 'features/institutions/correspondence/institution_correspondence_screen.dart';
import 'features/saves/presentation/saved_screen.dart';
import 'features/correspondence/presentation/correspondence_hub_screen.dart';
import 'features/correspondence/presentation/space_screen.dart';
import 'features/correspondence/presentation/thread_screen.dart';
import 'features/correspondence/presentation/invite_member_screen.dart';
import 'features/create/presentation/new_conversation_screen.dart';
import 'features/create/presentation/create_hub_screen.dart';

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
import 'screens/contact_screen.dart';
import 'screens/account_deletion_screen.dart';

const String kInstitutionDashboardRoute = '/institution/dashboard';
const String kInstitutionCreateRoute = '/institution/create';
const String kInstitutionDomainsRoute = '/institution/domains';
const String kInstitutionProfileRoute = '/institution/profile';
const String kInstitutionVerificationRoute = '/institution/request-verification';
const String kInstitutionAnnouncementsRoute = '/institution/announcements';
const String kInstitutionCorrespondenceRoute = '/institution/correspondence';
const String kEnterInstitutionRoute = '/enter-institution';
const String kRouterBootRoute = '/_boot';

const String kCorrespondenceHubRoute = '/me/correspondence';
const String kCreateConversationRoute = '/me/correspondence/create/conversation';
const String kCreateSpaceRoute = '/me/correspondence/create/space';

String _normalizeRedirectDest(
  String? dest, {
  String fallback = '/home',
}) {
  final trimmed = (dest ?? '').trim();
  if (trimmed.isEmpty || trimmed == '/') return fallback;
  if (!trimmed.startsWith('/')) return fallback;
  if (trimmed == kRouterBootRoute) return fallback;
  return trimmed;
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  ref.onDispose(refresh.dispose);

  ref.listen<AuthStatus>(authStatusProvider, (prev, next) {
    if (prev != next) refresh.value++;
  });

  ref.listen<AsyncValue<bool>>(emailVerifiedProvider, (prev, next) {
    final prevValue = prev?.maybeWhen(
      data: (value) => value,
      orElse: () => null,
    );
    final nextValue = next.maybeWhen(
      data: (value) => value,
      orElse: () => null,
    );

    final prevLoading = prev?.isLoading ?? false;
    final nextLoading = next.isLoading;

    if (prevValue != nextValue || prevLoading != nextLoading) {
      refresh.value++;
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
        path == '/founder' ||
        path == '/privacy' ||
        path == '/contact' ||
        path == '/account-deletion' ||
        path == '/investors' ||
        path == '/institutions' ||
        path.startsWith('/institutions/') ||
        path == '/institution/sign-in' ||
        path == kInstitutionCreateRoute ||
        path == '/patrons' ||
        path == '/supporters') {
      return true;
    }

    if (path == '/announcements') return true;
    if (path.startsWith('/announcements/')) return true;

    return false;
  }

  bool isMemberPath(String path) {
    return path == '/home' ||
        path == '/search' ||
        path == '/saved' ||
        path == '/updates' ||
        path == '/conversations' ||
        path == '/activity' ||
        path == '/create' ||
        path == '/announcements/create' ||
        path == '/ai/claim-audit' ||
        path == '/me' ||
        path == '/me/edit' ||
        path == '/security' ||
        path == '/me/follow-requests' ||
        path == kCorrespondenceHubRoute ||
        path == kCreateConversationRoute ||
        path == kCreateSpaceRoute ||
        path.startsWith('$kCorrespondenceHubRoute/') ||
        path == kInstitutionDashboardRoute ||
        path == kInstitutionDomainsRoute ||
        path == kInstitutionProfileRoute ||
        path == kInstitutionVerificationRoute ||
        path == kInstitutionAnnouncementsRoute ||
        path == kInstitutionCorrespondenceRoute ||
        path == kEnterInstitutionRoute ||
        path == '/compose' ||
        path.startsWith('/posts/') ||
        path.startsWith('/u/') ||
        path.startsWith('/author/') ||
        path.startsWith('/support/');
  }

  bool requiresAuth(String path) => isMemberPath(path);

  bool requiresVerifiedEmail(String path) {
    return requiresAuth(path) &&
        path != '/verify-email' &&
        path != '/verify-pending';
  }

  bool isGuestOnly(String path) => isPlainAuthPage(path);

  String bootRedirectFor(String target, {required String fallback}) {
    final encoded = Uri.encodeComponent(
      _normalizeRedirectDest(target, fallback: fallback),
    );
    return '$kRouterBootRoute?redirect=$encoded';
  }

  return GoRouter(
    refreshListenable: refresh,
    redirect: (context, state) {
      final path = state.uri.path;
      final currentLocation = state.uri.toString();

      final bootstrap = ref.read(sessionBootstrapProvider);
      final authStatus = ref.read(authStatusProvider);
      final emailVerifiedAsync = ref.read(emailVerifiedProvider);

      final defaultRedirect = authStatus == AuthStatus.authed ? '/home' : '/public';
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

      final isVerificationLoading = isLoggedIn && emailVerifiedAsync.isLoading;

      final isVerified = emailVerifiedAsync.maybeWhen(
        data: (value) => value,
        orElse: () => false,
      );

      if (isBootstrapping) {
        if (isBootPath(path)) return null;

        return bootRedirectFor(
          currentLocation,
          fallback: defaultRedirect,
        );
      }

      if (isLoggedIn && isVerificationLoading) {
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

        if (!isVerified) {
          final encoded = Uri.encodeComponent(
            _normalizeRedirectDest(redirectDest, fallback: '/home'),
          );
          return '/verify-pending?redirect=$encoded';
        }

        return redirectDest;
      }

      if (!isLoggedIn) {
        if (requiresAuth(path)) {
          final encoded = Uri.encodeComponent(
            _normalizeRedirectDest(currentLocation, fallback: '/public'),
          );
          return '/login?redirect=$encoded';
        }

        return null;
      }

      if (isVerifyEmail) {
        return null;
      }

      if (!isVerified) {
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

      if (isVerified) {
        if (isGuestOnly(path) || isVerifyPending) {
          return redirectDest;
        }
      }

      return null;
    },
    routes: [
      GoRoute(
        path: kRouterBootRoute,
        builder: (_, __) => const _RouterBootScreen(),
      ),

      GoRoute(path: '/', builder: (_, __) => const PublicHomeScreen()),
      GoRoute(path: '/auth', redirect: (_, __) => '/login'),

      // Public routes
      GoRoute(path: '/public', builder: (_, __) => const PublicHomeScreen()),
      GoRoute(path: '/mission', builder: (_, __) => const MissionScreen()),
      GoRoute(path: '/white-paper', builder: (_, __) => const WhitePaperScreen()),
      GoRoute(path: '/founder', builder: (_, __) => const FounderMessageScreen()),
      GoRoute(path: '/privacy', builder: (_, __) => const PrivacyPolicyScreen()),
      GoRoute(path: '/contact', builder: (_, __) => const ContactScreen()),
      GoRoute(
        path: '/account-deletion',
        builder: (_, __) => const AccountDeletionScreen(),
      ),
      GoRoute(path: '/investors', builder: (_, __) => const InvestorsHubScreen()),
      GoRoute(
        path: '/institutions',
        builder: (_, __) => const InstitutionsHubScreen(),
      ),
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
      GoRoute(
        path: '/announcements',
        builder: (_, __) => const AnnouncementsScreen(),
      ),
      GoRoute(
        path: '/announcements/create',
        builder: (context, state) {
          final scope = (state.uri.queryParameters['scope'] ?? '').trim().toLowerCase();
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

      // Auth routes
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

      // Member shell
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(path: '/home', builder: (_, __) => const MemberHomeScreen()),
          GoRoute(path: '/create', builder: (_, __) => const CreateHubScreen()),
          GoRoute(path: '/search', builder: (_, __) => const SearchScreen()),
          GoRoute(path: '/saved', builder: (_, __) => const SavedScreen()),
          GoRoute(path: '/updates', builder: (_, __) => const UpdatesScreen()),
          GoRoute(
            path: '/conversations',
            builder: (_, __) => const ConversationsScreen(),
          ),
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
            path: '/me/follow-requests',
            builder: (_, __) => const FollowRequestsScreen(),
          ),

          // Correspondence routes flattened for stable direct navigation
          GoRoute(
            path: kCorrespondenceHubRoute,
            builder: (_, __) => const CorrespondenceHubScreen(),
          ),
          GoRoute(
            path: kCreateConversationRoute,
            builder: (context, state) => NewConversationScreen(
              isSharedSpaceMode: false,
              initialUserId: state.uri.queryParameters['userId'],
              initialHandle: state.uri.queryParameters['handle'],
              initialName: state.uri.queryParameters['name'],
            ),
          ),
          GoRoute(
            path: kCreateSpaceRoute,
            builder: (context, state) => NewConversationScreen(
              isSharedSpaceMode: true,
              initialUserId: state.uri.queryParameters['userId'],
              initialHandle: state.uri.queryParameters['handle'],
              initialName: state.uri.queryParameters['name'],
            ),
          ),
          GoRoute(
            path: '/me/correspondence/:spaceId',
            builder: (context, state) => SpaceScreen(
              spaceId: state.pathParameters['spaceId'] ?? '',
            ),
          ),
          GoRoute(
            path: '/me/correspondence/:spaceId/invite',
            builder: (context, state) => InviteMemberScreen(
              spaceId: state.pathParameters['spaceId'] ?? '',
            ),
          ),
          GoRoute(
            path: '/me/correspondence/:spaceId/thread/:threadId',
            builder: (context, state) => ThreadScreen(
              threadId: state.pathParameters['threadId'] ?? '',
            ),
          ),

          GoRoute(
            path: '/compose',
            builder: (context, state) => ComposeScreen(
              replyToPostId: state.uri.queryParameters['replyTo'],
              heldPostId: state.uri.queryParameters['held'],
            ),
          ),
          GoRoute(
            path: '/posts/:id',
            builder: (context, state) => PostDetailScreen(
              postId: state.pathParameters['id'] ?? '',
            ),
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
            builder: (context, state) => FollowersScreen(
              handle: state.pathParameters['handle'] ?? '',
            ),
          ),
          GoRoute(
            path: '/u/:handle/following',
            builder: (context, state) => FollowingScreen(
              handle: state.pathParameters['handle'] ?? '',
            ),
          ),
          GoRoute(
            path: '/support/:handle',
            builder: (context, state) => SupportFallbackScreen(
              handle: state.pathParameters['handle'] ?? '',
            ),
          ),
          GoRoute(
            path: kEnterInstitutionRoute,
            builder: (_, __) => const InstitutionSignInScreen(),
          ),
          GoRoute(
            path: kInstitutionDashboardRoute,
            builder: (_, __) => const InstitutionDashboardScreen(),
          ),
          GoRoute(
            path: kInstitutionDomainsRoute,
            builder: (_, __) => const InstitutionDomainsScreen(),
          ),
          GoRoute(
            path: kInstitutionProfileRoute,
            builder: (_, __) => const InstitutionProfileScreen(),
          ),
          GoRoute(
            path: kInstitutionVerificationRoute,
            builder: (_, __) => const InstitutionRequestVerificationScreen(),
          ),
          GoRoute(
            path: kInstitutionAnnouncementsRoute,
            builder: (_, __) => const InstitutionAnnouncementsScreen(),
          ),
          GoRoute(
            path: kInstitutionCorrespondenceRoute,
            builder: (_, __) => const InstitutionCorrespondenceScreen(),
          ),
        ],
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