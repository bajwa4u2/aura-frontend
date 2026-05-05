import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/auth/session_providers.dart';
import '../core/interactions/presence_repository.dart';
import '../core/ui/aura_radius.dart';
import '../core/ui/aura_surface.dart';
import '../core/ui/aura_text.dart';
import '../core/notifications/notification_bridge.dart';
import '../features/devices/device_providers.dart';
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
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      try {
        ref.read(deviceServiceProvider).refreshPresence();
      } catch (_) {}
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
