import 'package:flutter/material.dart';

/// PlotShot palette: deep slate with a violet accent and a mint level line.
class AppColors {
  static const background = Color(0xFF0D0F14);
  static const surface = Color(0xFF161922);
  static const card = Color(0xFF1C202B);
  static const cardHigh = Color(0xFF252A37);
  static const outline = Color(0xFF2E3443);
  static const accent = Color(0xFFA594FF);
  static const onAccent = Color(0xFF1B1238);
  static const level = Color(0xFF5EE6C4);
  static const text = Color(0xFFEDEFF5);
  static const muted = Color(0xFF8D93A5);
  static const danger = Color(0xFFFF7A85);
  static const warning = Color(0xFFFFC36B);
  static const success = Color(0xFF6FE0A0);

  /// Colours for successive doses on charts, low to high.
  static const doses = [
    Color(0xFF7DD3FC),
    Color(0xFF60A5FA),
    Color(0xFF818CF8),
    Color(0xFFA78BFA),
    Color(0xFFC084FC),
    Color(0xFFE879F9),
    Color(0xFFF472B6),
    Color(0xFFFB7185),
    Color(0xFFFB923C),
    Color(0xFFFBBF24),
    Color(0xFFA3E635),
    Color(0xFF34D399),
  ];
}

ThemeData buildTheme() {
  final scheme =
      ColorScheme.fromSeed(
        seedColor: AppColors.accent,
        brightness: Brightness.dark,
      ).copyWith(
        primary: AppColors.accent,
        onPrimary: AppColors.onAccent,
        surface: AppColors.background,
        onSurface: AppColors.text,
        surfaceContainerLowest: AppColors.background,
        surfaceContainerLow: AppColors.surface,
        surfaceContainer: AppColors.surface,
        surfaceContainerHigh: AppColors.card,
        surfaceContainerHighest: AppColors.cardHigh,
        outline: AppColors.outline,
        outlineVariant: AppColors.outline,
        onSurfaceVariant: AppColors.muted,
        error: AppColors.danger,
      );
  final base = ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    fontFamily: 'Roboto',
  );
  return base.copyWith(
    scaffoldBackgroundColor: AppColors.background,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.background,
      surfaceTintColor: Colors.transparent,
      centerTitle: true,
      elevation: 0,
      titleTextStyle: TextStyle(
        fontFamily: 'Roboto',
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: AppColors.text,
      ),
    ),
    cardTheme: CardThemeData(
      color: AppColors.card,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.surface,
      indicatorColor: AppColors.accent.withValues(alpha: 0.18),
      surfaceTintColor: Colors.transparent,
      iconTheme: WidgetStateProperty.resolveWith(
        (s) => IconThemeData(
          color: s.contains(WidgetState.selected)
              ? AppColors.accent
              : AppColors.muted,
        ),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (s) => TextStyle(
          fontSize: 12,
          color: s.contains(WidgetState.selected)
              ? AppColors.accent
              : AppColors.muted,
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.outline),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.outline),
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
    ),
    dialogTheme: const DialogThemeData(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
    ),
    listTileTheme: const ListTileThemeData(iconColor: AppColors.accent),
    dividerTheme: const DividerThemeData(color: AppColors.outline, space: 1),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
  );
}
