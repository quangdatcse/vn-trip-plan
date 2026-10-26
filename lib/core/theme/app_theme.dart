import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';

import 'tokens.dart';

class AppTheme {
  const AppTheme._();

  static const fontFamily = 'PlusJakartaSans';

  static ThemeData light() => _build(
        ColorScheme.fromSeed(
          seedColor: Palette.sea,
          primary: Palette.sea,
          secondary: Palette.lantern,
          tertiary: Palette.lanternRed,
          surface: Palette.sand,
          brightness: Brightness.light,
        ).copyWith(
          surfaceContainerLowest: Colors.white,
          surfaceContainerLow: const Color(0xFFFFFCF7),
          surfaceContainer: Palette.sandDeep,
          onSurface: Palette.ink,
        ),
      );

  static ThemeData dark() => _build(
        ColorScheme.fromSeed(
          seedColor: Palette.sea,
          primary: Palette.lagoon,
          secondary: Palette.lantern,
          tertiary: const Color(0xFFFF8A75),
          surface: Palette.night,
          brightness: Brightness.dark,
        ).copyWith(
          surfaceContainerLowest: const Color(0xFF0A1418),
          surfaceContainerLow: Palette.nightRaised,
          surfaceContainer: const Color(0xFF1C2E36),
        ),
      );

  static TextTheme _text(TextTheme base, Color color) {
    TextStyle? s(TextStyle? style, int weight, {double? size, double? spacing, double? height}) =>
        style
            ?.copyWith(
              fontFamily: fontFamily,
              fontSize: size,
              letterSpacing: spacing,
              height: height,
              color: color,
            )
            .w(weight);
    return base.copyWith(
      displayLarge: s(base.displayLarge, 800, spacing: -1.5),
      displayMedium: s(base.displayMedium, 800, spacing: -1.2),
      displaySmall: s(base.displaySmall, 800, size: 34, spacing: -1, height: 1.1),
      headlineLarge: s(base.headlineLarge, 800, size: 30, spacing: -0.8, height: 1.15),
      headlineMedium: s(base.headlineMedium, 800, size: 26, spacing: -0.6, height: 1.2),
      headlineSmall: s(base.headlineSmall, 700, size: 22, spacing: -0.4),
      titleLarge: s(base.titleLarge, 700, size: 20, spacing: -0.3),
      titleMedium: s(base.titleMedium, 700, size: 16, spacing: -0.1),
      titleSmall: s(base.titleSmall, 700, size: 14),
      bodyLarge: s(base.bodyLarge, 400, size: 16, height: 1.5),
      bodyMedium: s(base.bodyMedium, 400, size: 14, height: 1.45),
      bodySmall: s(base.bodySmall, 500, size: 12.5, height: 1.4),
      labelLarge: s(base.labelLarge, 700, size: 14),
      labelMedium: s(base.labelMedium, 600, size: 12.5),
      labelSmall: s(base.labelSmall, 700, size: 11, spacing: 0.6),
    );
  }

  static ThemeData _build(ColorScheme scheme) {
    final base = ThemeData(colorScheme: scheme, useMaterial3: true);
    final text = _text(base.textTheme, scheme.onSurface);
    final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.md));

    return base.copyWith(
      scaffoldBackgroundColor: scheme.surface,
      textTheme: text,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        centerTitle: false,
        titleTextStyle: text.titleLarge,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        color: scheme.surfaceContainerLowest,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.lg),
          side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.5)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 54),
          padding: const EdgeInsets.symmetric(horizontal: Space.xl),
          textStyle: text.labelLarge?.copyWith(fontSize: 15),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.pill)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: Space.lg + 4),
          textStyle: text.labelLarge,
          foregroundColor: scheme.onSurface,
          side: BorderSide(color: scheme.outlineVariant),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.pill)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(textStyle: text.labelLarge),
      ),
      chipTheme: base.chipTheme.copyWith(
        labelStyle: text.labelMedium,
        side: BorderSide(color: scheme.outlineVariant),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.pill)),
        showCheckmark: false,
        selectedColor: scheme.primary,
        secondaryLabelStyle: text.labelMedium?.copyWith(color: scheme.onPrimary),
        padding: const EdgeInsets.symmetric(horizontal: Space.sm, vertical: Space.sm),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerLowest,
        contentPadding: const EdgeInsets.symmetric(horizontal: Space.lg, vertical: 18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Radii.md),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Radii.md),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Radii.md),
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 68,
        elevation: 0,
        backgroundColor: scheme.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        indicatorColor: scheme.primary.withValues(alpha: 0.14),
        indicatorShape: shape,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => text.labelSmall?.copyWith(
            letterSpacing: 0.2,
            color: states.contains(WidgetState.selected)
                ? scheme.primary
                : scheme.onSurfaceVariant,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? scheme.primary
                : scheme.onSurfaceVariant,
          ),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.xl)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.lg)),
        titleTextStyle: text.titleLarge,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: shape,
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: text.bodyMedium?.copyWith(color: scheme.onInverseSurface),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          textStyle: text.labelMedium,
          selectedBackgroundColor: scheme.primary,
          selectedForegroundColor: scheme.onPrimary,
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.secondary,
        foregroundColor: Colors.white,
        elevation: 2,
        highlightElevation: 4,
        extendedTextStyle: text.labelLarge?.copyWith(fontSize: 15),
        shape: const StadiumBorder(),
      ),
      dividerTheme: DividerThemeData(color: scheme.outlineVariant.withValues(alpha: 0.6), space: 1),
      listTileTheme: ListTileThemeData(
        titleTextStyle: text.titleSmall?.copyWith(fontSize: 15),
        subtitleTextStyle: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }
}
