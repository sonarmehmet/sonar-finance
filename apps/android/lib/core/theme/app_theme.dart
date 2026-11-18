import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'tokens.dart';

/// Token'lardan koyu Material 3 temasi uretir.
ThemeData buildTheme(SonarTokens t) {
  final accent = t.color('accent');
  final bg = t.color('bg');
  final card = t.color('card');
  final border = t.color('border');
  final textPrimary = t.color('textPrimary');
  final textSecondary = t.color('textSecondary');

  final scheme = ColorScheme.dark(
    primary: accent,
    onPrimary: t.color('sidebar'),
    secondary: accent,
    surface: card,
    onSurface: textPrimary,
    error: t.color('negative'),
    outline: border,
  );

  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
    scaffoldBackgroundColor: bg,
  );

  final textTheme = GoogleFonts.interTextTheme(base.textTheme).apply(
    bodyColor: textPrimary,
    displayColor: textPrimary,
  );

  OutlineInputBorder inputBorder(Color c) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(t.radius('input')),
        borderSide: BorderSide(color: c),
      );

  return base.copyWith(
    textTheme: textTheme,
    appBarTheme: AppBarTheme(
      backgroundColor: bg,
      foregroundColor: textPrimary,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: textTheme.titleLarge?.copyWith(
        fontSize: t.fontSize('title'),
        fontWeight: t.fontWeight('semibold'),
      ),
    ),
    cardTheme: CardThemeData(
      color: card,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(t.radius('card')),
        side: BorderSide(color: border),
      ),
    ),
    dividerTheme: DividerThemeData(color: border, space: 1),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: card,
      contentPadding: EdgeInsets.symmetric(
        horizontal: t.spacing('lg'),
        vertical: t.spacing('md'),
      ),
      border: inputBorder(border),
      enabledBorder: inputBorder(border),
      focusedBorder: inputBorder(accent),
      errorBorder: inputBorder(t.color('negative')),
      focusedErrorBorder: inputBorder(t.color('negative')),
      labelStyle: TextStyle(color: textSecondary),
      hintStyle: TextStyle(color: textSecondary),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: Size.fromHeight(t.minTouchTarget),
        backgroundColor: accent,
        foregroundColor: t.color('sidebar'),
        textStyle: TextStyle(fontWeight: t.fontWeight('semibold')),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(t.radius('button')),
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: Size.fromHeight(t.minTouchTarget),
        foregroundColor: textPrimary,
        side: BorderSide(color: border),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(t.radius('button')),
        ),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: t.bottomNavHeight,
      backgroundColor: t.color('sidebar'),
      indicatorColor: accent.withValues(alpha: 0.16),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return TextStyle(
          fontSize: t.fontSize('caption'),
          fontWeight: t.fontWeight(selected ? 'semibold' : 'regular'),
          color: selected ? accent : textSecondary,
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return IconThemeData(
          color: selected ? accent : textSecondary,
          size: 24,
        );
      }),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: t.color('cardAlt'),
      contentTextStyle: TextStyle(color: textPrimary),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(t.radius('button')),
      ),
    ),
  );
}
