import 'package:flutter/material.dart';

import 'aura_radius.dart';
import 'aura_surface.dart';
import 'aura_text.dart';

/// Global ThemeData for Aura.
///
/// This keeps inputs, buttons, dividers, and default text consistent
/// without screens hardcoding styling.
class AuraAppTheme {
  AuraAppTheme._();

  static ThemeData light() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AuraSurface.ink,
      brightness: Brightness.light,
      surface: AuraSurface.card,
    );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AuraSurface.page,
      cardColor: AuraSurface.card,
      dividerColor: AuraSurface.divider,
      splashFactory: InkSparkle.splashFactory,
      visualDensity: VisualDensity.standard,
    );

    OutlineInputBorder outline(Color color) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(AuraRadius.r14),
          borderSide: BorderSide(color: color, width: 1),
        );

    return base.copyWith(
      textTheme: base.textTheme.copyWith(
        titleMedium: AuraText.title,
        bodyMedium: AuraText.body,
        bodySmall: AuraText.small,
      ),
      inputDecorationTheme: InputDecorationTheme(
        isDense: true,
        filled: true,
        fillColor: AuraSurface.card,
        labelStyle: AuraText.small.copyWith(color: AuraSurface.muted),
        hintStyle: AuraText.small,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: outline(AuraSurface.divider),
        enabledBorder: outline(AuraSurface.divider),
        focusedBorder: outline(AuraSurface.ink.withValues(alpha: 0.35)),
        errorBorder: outline(Colors.red.withValues(alpha: 0.6)),
        focusedErrorBorder: outline(Colors.red.withValues(alpha: 0.8)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          textStyle: AuraText.body.copyWith(fontWeight: FontWeight.w600),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AuraRadius.r14),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          textStyle: AuraText.body.copyWith(fontWeight: FontWeight.w600),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          side: BorderSide(color: AuraSurface.divider),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AuraRadius.r14),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          textStyle: AuraText.body.copyWith(fontWeight: FontWeight.w600),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AuraRadius.r14),
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AuraSurface.ink,
        contentTextStyle: AuraText.body.copyWith(color: Colors.white),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AuraRadius.r14),
        ),
      ),
    );
  }
}
