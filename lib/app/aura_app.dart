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

      navigationBarTheme: const NavigationBarThemeData(
        backgroundColor: AuraSurface.card,
        indicatorColor: AuraSurface.accentSoft,
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
