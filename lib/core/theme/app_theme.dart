import 'package:flutter/material.dart';

/// A quiet, civic identity. Components consume ColorScheme instead of hex values.
abstract final class AppTheme {
  static const evergreen = Color(0xFF174D3C);
  static const paper = Color(0xFFF6F7F2);
  static const ink = Color(0xFF202B26);
  static const attention = Color(0xFF885C12);
  static const fast = Duration(milliseconds: 160);
  static const normal = Duration(milliseconds: 280);

  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final scheme =
        ColorScheme.fromSeed(seedColor: evergreen, brightness: brightness)
            .copyWith(
      primary: dark ? const Color(0xFFA9D4BC) : evergreen,
      onPrimary: dark ? const Color(0xFF103628) : Colors.white,
      primaryContainer:
          dark ? const Color(0xFF244637) : const Color(0xFFE6EEE3),
      onPrimaryContainer: dark ? const Color(0xFFD4EAD9) : evergreen,
      secondary: dark ? const Color(0xFFE2C58B) : attention,
      secondaryContainer:
          dark ? const Color(0xFF463A24) : const Color(0xFFF7EEDB),
      onSecondaryContainer:
          dark ? const Color(0xFFF5DAA5) : const Color(0xFF76500B),
      surface: dark ? const Color(0xFF1B2520) : const Color(0xFFFFFFFC),
      onSurface: dark ? const Color(0xFFE9EEE8) : ink,
      onSurfaceVariant:
          dark ? const Color(0xFFB6C1B7) : const Color(0xFF5A665D),
      surfaceContainerLowest: dark ? const Color(0xFF141C17) : paper,
      surfaceContainerLow:
          dark ? const Color(0xFF202D24) : const Color(0xFFF0F3EC),
      surfaceContainerHighest:
          dark ? const Color(0xFF334037) : const Color(0xFFE9EDE4),
      outline: dark ? const Color(0xFF7F9283) : const Color(0xFF788675),
      outlineVariant: dark ? const Color(0xFF39493D) : const Color(0xFFDEE4D8),
      error: dark ? const Color(0xFFFFB4AB) : const Color(0xFFAF352E),
    );
    final base = ThemeData(
        useMaterial3: true,
        colorScheme: scheme,
        brightness: brightness,
        fontFamily: 'PublicSans');
    final text = base.textTheme
        .copyWith(
          displaySmall: TextStyle(
              fontSize: 36,
              height: 1.2,
              fontWeight: FontWeight.w700,
              color: scheme.onSurface),
          headlineLarge: TextStyle(
              fontSize: 32,
              height: 1.2,
              fontWeight: FontWeight.w700,
              color: scheme.onSurface),
          headlineMedium: TextStyle(
              fontSize: 28,
              height: 1.25,
              fontWeight: FontWeight.w700,
              color: scheme.onSurface),
          headlineSmall: TextStyle(
              fontSize: 24,
              height: 1.3,
              fontWeight: FontWeight.w700,
              color: scheme.onSurface),
          titleLarge: TextStyle(
              fontSize: 20,
              height: 1.35,
              fontWeight: FontWeight.w600,
              color: scheme.onSurface),
          titleMedium: TextStyle(
              fontSize: 16,
              height: 1.45,
              fontWeight: FontWeight.w600,
              color: scheme.onSurface),
          bodyLarge:
              TextStyle(fontSize: 16, height: 1.6, color: scheme.onSurface),
          bodyMedium:
              TextStyle(fontSize: 14, height: 1.55, color: scheme.onSurface),
          bodySmall: TextStyle(
              fontSize: 12, height: 1.5, color: scheme.onSurfaceVariant),
          labelLarge: TextStyle(
              fontSize: 14,
              height: 1.4,
              fontWeight: FontWeight.w600,
              color: scheme.onSurface),
        )
        .apply(fontFamily: 'PublicSans');
    final border = OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: scheme.outline));
    return base.copyWith(
      textTheme: text,
      scaffoldBackgroundColor: scheme.surfaceContainerLowest,
      appBarTheme: AppBarTheme(
          backgroundColor: scheme.surfaceContainerLowest,
          foregroundColor: scheme.onSurface,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: false,
          titleTextStyle: text.titleLarge),
      cardTheme: CardThemeData(
          color: scheme.surface,
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: scheme.outlineVariant))),
      inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: scheme.surface,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
          border: border,
          enabledBorder: border,
          focusedBorder: border.copyWith(
              borderSide: BorderSide(color: scheme.primary, width: 2)),
          errorBorder:
              border.copyWith(borderSide: BorderSide(color: scheme.error)),
          focusedErrorBorder: border.copyWith(
              borderSide: BorderSide(color: scheme.error, width: 2)),
          labelStyle: TextStyle(color: scheme.onSurfaceVariant),
          hintStyle: TextStyle(color: scheme.onSurfaceVariant),
          errorMaxLines: 4),
      filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
              minimumSize: const Size(48, 52),
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
              textStyle: text.labelLarge,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)))),
      elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
              backgroundColor: scheme.primary,
              foregroundColor: scheme.onPrimary,
              minimumSize: const Size(48, 52),
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)))),
      outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
              minimumSize: const Size(48, 48),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              side: BorderSide(color: scheme.outline),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)))),
      textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
              minimumSize: const Size(48, 48), textStyle: text.labelLarge)),
      iconButtonTheme: IconButtonThemeData(
          style: IconButton.styleFrom(minimumSize: const Size(48, 48))),
      chipTheme: ChipThemeData(
          side: BorderSide(color: scheme.outlineVariant),
          selectedColor: scheme.primaryContainer,
          backgroundColor: scheme.surface,
          labelStyle: text.labelLarge,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
      dividerTheme: DividerThemeData(
          color: scheme.outlineVariant, thickness: 1, space: 1),
      navigationBarTheme: NavigationBarThemeData(
          backgroundColor: scheme.surface,
          indicatorColor: scheme.primaryContainer,
          iconTheme: WidgetStateProperty.resolveWith((states) => IconThemeData(
              color: states.contains(WidgetState.selected)
                  ? scheme.primary
                  : scheme.onSurfaceVariant)),
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          elevation: 0,
          height: 76),
      snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          backgroundColor: scheme.inverseSurface,
          contentTextStyle: TextStyle(color: scheme.onInverseSurface),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
      dialogTheme: DialogThemeData(
          backgroundColor: scheme.surface,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24))),
      bottomSheetTheme: BottomSheetThemeData(
          backgroundColor: scheme.surface,
          showDragHandle: true,
          shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)))),
      progressIndicatorTheme: ProgressIndicatorThemeData(
          color: scheme.primary, linearTrackColor: scheme.primaryContainer),
      tooltipTheme:
          const TooltipThemeData(waitDuration: Duration(milliseconds: 450)),
    );
  }
}
