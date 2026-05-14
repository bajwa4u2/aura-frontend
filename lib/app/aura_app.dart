import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/auth/auth_broadcast.dart';
import '../core/auth/auth_providers.dart';
import '../core/auth/session_bootstrap.dart';
import '../core/auth/session_providers.dart';
import '../core/interactions/presence_repository.dart';
import '../core/media/media_url_resolver.dart';
import '../core/release_governance/update_gate.dart';
import '../core/ui/aura_radius.dart';
import '../core/ui/aura_surface.dart';
import '../core/ui/aura_text.dart';
import '../core/notifications/notification_bridge.dart';
import '../features/correspondence/data/correspondence_live_service.dart';
import '../features/devices/device_providers.dart';
import '../features/realtime/application/realtime_providers.dart';
import '../features/updates/incoming_call_bridge.dart';
import '../router.dart';

class AuraApp extends ConsumerStatefulWidget {
  const AuraApp({super.key});

  @override
  ConsumerState<AuraApp> createState() => _AuraAppState();
}

class _AuraAppState extends ConsumerState<AuraApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Cross-tab logout fan-out: when a sibling tab calls
    // AuthBroadcast.publishLogout(), every other tab on this origin runs
    // the local-clear path here. We deliberately do NOT call the backend
    // logout endpoint — the originating tab already did that. This keeps
    // the cleanup quiet and idempotent. Login events trigger a soft
    // refresh of auth-derived providers so a stale signed-out tab catches
    // up without forcing a hard reload.
    AuthBroadcast.start(onMessage: _onRemoteAuthEvent);

    // Register device if already authed at startup (stored token from prior session)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (ref.read(isAuthedProvider)) {
        try {
          ref.read(deviceServiceProvider).registerCurrentDevice();
        } catch (_) {}
      }
    });
  }

  @override
  void dispose() {
    AuthBroadcast.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Bounded, race-free teardown of the realtime + correspondence sockets
  /// on any auth-drop transition. Returns once both services have
  /// confirmed disconnect or 3 seconds have passed — whichever is first.
  ///
  /// Why a single helper:
  ///   - Both the cross-tab logout handler (`_onRemoteAuthEvent`) and the
  ///     in-tab auth-drop listener used to call `unawaited(disconnect())`
  ///     and then synchronously clear tokens. That allowed a heartbeat
  ///     tick or pending emit to fire between the unawaited call and the
  ///     token clear, producing 401-spam against the auth surface.
  ///   - Awaiting in lockstep guarantees the sockets stop emitting before
  ///     tokens go away. The timeout protects the UI from a permanently-
  ///     hung disconnect (e.g. a half-broken WebSocket pinned by the OS).
  Future<void> _awaitAuthDropTeardown() async {
    Future<void> safeDisconnect(Future<void> Function() run) async {
      try {
        await run();
      } catch (_) {
        // Either service may already be disposed (idempotent) — ignore.
      }
    }

    final correspondence = safeDisconnect(
      () => ref.read(correspondenceLiveServiceProvider).disconnect(),
    );
    final realtime = safeDisconnect(
      () => ref.read(realtimeControllerProvider.notifier).disconnect(),
    );

    try {
      await Future.wait([correspondence, realtime])
          .timeout(const Duration(seconds: 3));
    } on TimeoutException {
      // The timeout case is rare but real: a half-broken transport can
      // leave a socket spinning on close. We accept the leak rather
      // than blocking the rest of the logout pipeline.
    } catch (_) {
      // Defensive — any other surprise here must not prevent the
      // token-clear that follows.
    }

    // Drop any pending incoming-call cards held by the bridge. The
    // provider is long-lived (no autoDispose), so without this a ring
    // received seconds before sign-out would survive into the next
    // identity on the same tab. The bridge re-subscribes to its sockets
    // automatically; clearing state is enough.
    try {
      ref.read(incomingCallBridgeProvider.notifier).clear();
    } catch (_) {
      // Bridge may not have been built yet on a cold logout path.
    }
  }

  Future<void> _onRemoteAuthEvent(String type) async {
    if (!mounted) return;
    if (type == AuthBroadcast.typeLogout) {
      // Local-only teardown: tokens, hint, providers. The originating tab
      // already POSTed /auth/logout, so we deliberately skip the network
      // call to avoid duplicate refresh-cookie clears and 401s.

      // Disconnect runtime sockets BEFORE clearing tokens so any final
      // event fires against a still-valid identity. AWAIT both so a
      // heartbeat tick can't fire mid-clear and produce 401-spam in
      // logs. Bound the wait so a hung disconnect can't freeze the
      // logout path — 3s is well above socket.io's local close cost.
      await _awaitAuthDropTeardown();

      try {
        await ref.read(tokenStoreProvider).clearTokens();
      } catch (_) {}
      try {
        await setSessionHint(false);
      } catch (_) {}
      // Invalidate auth-derived providers in one go so the router refresh
      // listenable picks up the unauthed state on the next frame.
      try {
        ref.invalidate(authStatusProvider);
      } catch (_) {}
      try {
        ref.invalidate(emailVerifiedProvider);
      } catch (_) {}
      try {
        ref.invalidate(authMeDataProvider);
      } catch (_) {}
      // Stop the local device-registration link to the now-revoked record.
      // revokeCurrentDevice gates on _isAuthed and self-clears local state.
      try {
        unawaited(ref.read(deviceServiceProvider).revokeCurrentDevice());
      } catch (_) {}
    } else if (type == AuthBroadcast.typeLogin) {
      // Sibling tab signed in. Re-evaluate session state without forcing a
      // page reload; if a refresh cookie now lives in this browser, the
      // bootstrap on the next provider read will pick it up.
      try {
        ref.invalidate(sessionBootstrapProvider);
      } catch (_) {}
      try {
        ref.invalidate(authMeDataProvider);
      } catch (_) {}
      try {
        ref.invalidate(emailVerifiedProvider);
      } catch (_) {}
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Defensive auth gate: DeviceService also self-gates, but skipping the
      // call entirely on signed-out resumes keeps the network/console clean
      // when a user is parked on a public route and switches tabs.
      if (!ref.read(isAuthedProvider)) return;
      try {
        ref.read(deviceServiceProvider).refreshPresence();
      } catch (_) {}

      // Ringing-card reconciliation on resume.
      //
      // Background scenario the bridge can't recover from on its own: while
      // this client was backgrounded, the call was accepted (or declined/
      // expired/ended) on another device. The backend emitted `call:terminal`
      // to our user-room while our socket was disconnected, so we never
      // received it. The bridge state therefore still holds the ringing card,
      // and the local ring timer happily counts down for up to 90s after the
      // peer device answered — that is the "mobile keeps ringing after I
      // picked up on desktop" report.
      //
      // Fix: on every resume, ask the backend whether each ringing session
      // is still ringing FOR US, and evict the card if not. The repository
      // call is bounded and idempotent; transport errors leave the card
      // alone so the TTL still wins.
      unawaited(_reconcileIncomingCallsOnResume());
    }
  }

  Future<void> _reconcileIncomingCallsOnResume() async {
    try {
      final bridge = ref.read(incomingCallBridgeProvider.notifier);
      final sessionIds = bridge.currentSessionIds();
      if (sessionIds.isEmpty) return;

      final me = await ref.read(authMeDataProvider.future);
      final myUserId = (me['id'] ??
              me['userId'] ??
              (me['user'] is Map ? (me['user'] as Map)['id'] : null) ??
              '')
          .toString()
          .trim();
      if (myUserId.isEmpty) return;

      final repo = ref.read(realtimeRepositoryProvider);
      await Future.wait(
        sessionIds.map((sid) async {
          final resolved = await repo.isCallResolvedForUser(sid, myUserId);
          if (resolved) {
            bridge.removeBySession(sid);
          }
        }),
        eagerError: false,
      );
    } catch (_) {
      // Reconciliation is best-effort; failures should never crash the
      // resume path. The 90s frontend TTL and the 30s backend sweep both
      // back this up.
    }
  }

  @override
  Widget build(BuildContext context) {
    // Register device on any auth transition to authed (login, session restore via bootstrap)
    ref.listen<bool>(isAuthedProvider, (prev, next) {
      if (next && !(prev ?? false)) {
        try {
          ref.read(deviceServiceProvider).registerCurrentDevice();
        } catch (_) {}
      }
      // Auth-drop teardown: any path that flips this tab from authed → unauthed
      // (Dio's clearSessionState on a forced 401, cross-tab logout, manual
      // logout) MUST also stop the live runtime services. Without this, an
      // expired-token tab keeps the realtime socket open and the heartbeat
      // ticker firing — those calls then 401 in a tight loop until the user
      // closes the tab. ref.listen callbacks can't be async, so kick off
      // the awaited teardown helper and ignore the future locally.
      if ((prev ?? false) && !next) {
        unawaited(_awaitAuthDropTeardown());
        // C7 — drop the signed-URL cache so a previous user's RESTRICTED
        // / PRIVATE media URLs don't leak into the next session on the
        // same device.
        try {
          ref.read(mediaUrlResolverProvider).clearAll();
        } catch (_) {}
      }
    });

    final router = ref.watch(routerProvider);

    final theme = _buildTheme();

    return NotificationBridge(
      child: PresencePinger(
        child: MaterialApp.router(
          scaffoldMessengerKey: auraScaffoldMessengerKey,
          debugShowCheckedModeBanner: false,
          title: 'Aura',
          theme: theme,
          darkTheme: theme,
          themeMode: ThemeMode.dark,
          routerConfig: router,
          // UpdateGate sits between MaterialApp and the routed widget so
          // the blocking screens have access to Material/MediaQuery
          // ancestors and the gate watches its own provider without
          // forcing a rebuild of the rest of the tree.
          builder: (context, child) {
            return UpdateGate(child: child ?? const SizedBox.shrink());
          },
        ),
      ),
    );
  }

  ThemeData _buildTheme() {
    const colorScheme = ColorScheme(
      brightness: Brightness.dark,
      primary: AuraSurface.accent,
      onPrimary: Colors.white,
      secondary: AuraSurface.accent,
      onSecondary: Colors.white,
      error: Color(0xFFF07878),
      onError: Colors.white,
      surface: AuraSurface.card,
      onSurface: AuraSurface.ink,
    );

    OutlineInputBorder border(Color color) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(AuraRadius.r14),
      borderSide: BorderSide(color: color, width: 1),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,

      scaffoldBackgroundColor: AuraSurface.page,
      canvasColor: AuraSurface.page,
      cardColor: AuraSurface.card,
      dividerColor: AuraSurface.divider,

      splashColor: AuraSurface.accentSoft,
      highlightColor: Colors.transparent,
      splashFactory: InkRipple.splashFactory,

      textTheme: const TextTheme(
        displayLarge: AuraText.display,
        displayMedium: AuraText.headline,
        titleLarge: AuraText.title,
        titleMedium: AuraText.subtitle,
        bodyLarge: AuraText.body,
        bodyMedium: AuraText.body,
        bodySmall: AuraText.small,
        labelLarge: AuraText.emphasis,
        labelMedium: AuraText.label,
        labelSmall: AuraText.micro,
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AuraSurface.subtle,
        labelStyle: AuraText.small.copyWith(color: AuraSurface.muted),
        hintStyle: AuraText.small.copyWith(color: AuraSurface.faint),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: border(AuraSurface.divider),
        enabledBorder: border(AuraSurface.divider),
        focusedBorder: border(AuraSurface.accent),
        errorBorder: border(AuraSurface.dangerInk.withValues(alpha: 0.5)),
        focusedErrorBorder: border(AuraSurface.dangerInk),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          textStyle: AuraText.body.copyWith(fontWeight: FontWeight.w600),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AuraRadius.r14),
          ),
          backgroundColor: AuraSurface.accent,
          foregroundColor: Colors.white,
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          textStyle: AuraText.body.copyWith(fontWeight: FontWeight.w600),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          foregroundColor: AuraSurface.ink,
          side: const BorderSide(color: AuraSurface.divider),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AuraRadius.r14),
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          textStyle: AuraText.body.copyWith(fontWeight: FontWeight.w600),
          foregroundColor: AuraSurface.ink,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AuraRadius.r12),
          ),
        ),
      ),

      navigationBarTheme: const NavigationBarThemeData(
        backgroundColor: AuraSurface.card,
        indicatorColor: AuraSurface.accentSoft,
        labelTextStyle: WidgetStatePropertyAll(AuraText.label),
      ),

      appBarTheme: const AppBarTheme(
        backgroundColor: AuraSurface.page,
        elevation: 0,
        centerTitle: false,
        foregroundColor: AuraSurface.ink,
      ),

      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AuraSurface.elevated,
        contentTextStyle: AuraText.body.copyWith(color: AuraSurface.ink),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AuraRadius.r12),
          side: const BorderSide(color: AuraSurface.divider),
        ),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: AuraSurface.overlay,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AuraRadius.xl),
          side: const BorderSide(color: AuraSurface.divider),
        ),
        titleTextStyle: AuraText.title,
        contentTextStyle: AuraText.body,
      ),

      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AuraSurface.overlay,
        showDragHandle: false,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AuraRadius.xl),
          ),
        ),
      ),
    );
  }
}
