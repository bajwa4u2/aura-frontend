GoRouter buildRouter(WidgetRef ref) {
  return GoRouter(
    initialLocation: '/home',

    redirect: (context, state) {
      final isAuthed = ref.read(isAuthedProvider);

      final path = state.uri.path;
      final fullLoc = state.uri.toString();

      if (path == '/login') {
        if (isAuthed) {
          final target = state.uri.queryParameters['redirect'];
          if (target != null && target.isNotEmpty) return target;
          return '/home';
        }
        return null;
      }

      final requiresAuth = path == '/me' || path == '/compose';

      if (requiresAuth && !isAuthed) {
        final redirectTo = Uri.encodeComponent(fullLoc);
        return '/login?redirect=$redirectTo';
      }

      return null;
    },

    routes: [
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          // Core member routes
          GoRoute(
            path: '/home',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: MemberHomeScreen()),
          ),
          GoRoute(
            path: '/search',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: SearchScreen()),
          ),
          GoRoute(
            path: '/updates',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: UpdatesScreen()),
          ),
          GoRoute(
            path: '/me',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: MeScreen()),
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
            builder: (context, state) =>
                PostDetailScreen(postId: state.pathParameters['id']!),
          ),
          GoRoute(
            path: '/author/:handle',
            builder: (context, state) =>
                AuthorProfileScreen(handle: state.pathParameters['handle']!),
          ),
          GoRoute(
            path: '/support/:handle',
            builder: (context, state) =>
                SupportScreen(handle: state.pathParameters['handle']!),
          ),

          // Document pages (NOW inside shell)
          GoRoute(
            path: '/privacy',
            builder: (context, state) =>
                const PrivacyPolicyScreen(),
          ),
          GoRoute(
            path: '/mission',
            builder: (context, state) =>
                const MissionScreen(),
          ),
          GoRoute(
            path: '/founder',
            builder: (context, state) =>
                const FounderMessageScreen(),
          ),
          GoRoute(
            path: '/investors',
            builder: (context, state) =>
                const InvestorsHubScreen(),
          ),
        ],
      ),

      // Login outside shell
      GoRoute(
        path: '/login',
        builder: (context, state) {
          final redirectTo = state.uri.queryParameters['redirect'];
          return AuthScreen(redirectTo: redirectTo);
        },
      ),
    ],
  );
}
