import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/ui/aura_surface.dart';
import '../core/ui/aura_text.dart';
import '../core/notifications/notification_bridge.dart';
import '../router.dart';

class AuraApp extends ConsumerWidget {
  const AuraApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    final theme = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,

      scaffoldBackgroundColor: AuraSurface.page,
      canvasColor: AuraSurface.page,
      cardColor: AuraSurface.card,

      colorScheme: const ColorScheme(
        brightness: Brightness.dark,
        primary: AuraSurface.accent,
        onPrimary: Colors.white,
        secondary: AuraSurface.accent,
        onSecondary: Colors.white,
        error: Color(0xFFCF6679),
        onError: Colors.black,
        surface: AuraSurface.card,
        onSurface: AuraSurface.ink,
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AuraSurface.card.withValues(alpha: 0.9),
        labelStyle: const TextStyle(color: AuraSurface.muted),
        hintStyle: const TextStyle(color: AuraSurface.muted),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AuraSurface.divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AuraSurface.divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AuraSurface.accent),
        ),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          backgroundColor: AuraSurface.accent,
          foregroundColor: Colors.white,
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          foregroundColor: AuraSurface.ink,
          side: const BorderSide(color: AuraSurface.divider),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AuraSurface.ink,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
      ),

      navigationBarTheme: const NavigationBarThemeData(
        backgroundColor: AuraSurface.card,
        indicatorColor: AuraSurface.accentSoft,
      ),

      textTheme: const TextTheme(
        titleLarge: AuraText.title,
        bodyLarge: AuraText.body,
        bodyMedium: AuraText.body,
        bodySmall: AuraText.small,
        labelLarge: AuraText.emphasis,
      ),

      dividerColor: AuraSurface.divider,

      appBarTheme: const AppBarTheme(
        backgroundColor: AuraSurface.page,
        elevation: 0,
        centerTitle: false,
      ),

      splashColor: AuraSurface.accentSoft,
      highlightColor: Colors.transparent,
    );

    return NotificationBridge(
      child: MaterialApp.router(
        scaffoldMessengerKey: auraScaffoldMessengerKey,
        debugShowCheckedModeBanner: false,
        title: 'Aura',
        theme: theme,
        darkTheme: theme,
        themeMode: ThemeMode.dark,
        routerConfig: router,
      ),
    );
  }
}
