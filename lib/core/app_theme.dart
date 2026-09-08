import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_colors.dart';

/// Extra tokens the widgets need that [ColorScheme] has no slot for.
@immutable
class AppTokens extends ThemeExtension<AppTokens> {
  const AppTokens({
    required this.surfaceAlt,
    required this.textMuted,
    required this.focus,
    required this.shortBreak,
    required this.longBreak,
    required this.tomatoTop,
    required this.tomatoBottom,
    required this.leaf,
    required this.heatmapEmpty,
    required this.cardShadow,
  });

  final Color surfaceAlt;
  final Color textMuted;
  final Color focus;
  final Color shortBreak;
  final Color longBreak;
  final Color tomatoTop;
  final Color tomatoBottom;
  final Color leaf;
  final Color heatmapEmpty;
  final List<BoxShadow> cardShadow;

  static const light = AppTokens(
    surfaceAlt: AppColors.lightSurfaceAlt,
    textMuted: AppColors.lightTextMuted,
    focus: AppColors.focus,
    shortBreak: AppColors.shortBreak,
    longBreak: AppColors.longBreak,
    tomatoTop: AppColors.tomatoTop,
    tomatoBottom: AppColors.tomatoBottom,
    leaf: AppColors.leaf,
    heatmapEmpty: Color(0xFFF3E1DB),
    cardShadow: [
      BoxShadow(color: Color(0x147A2A1E), blurRadius: 18, offset: Offset(0, 6)),
    ],
  );

  static const dark = AppTokens(
    surfaceAlt: AppColors.darkSurfaceAlt,
    textMuted: AppColors.darkTextMuted,
    focus: AppColors.focusLight,
    shortBreak: AppColors.shortBreakLight,
    longBreak: AppColors.longBreakLight,
    tomatoTop: AppColors.tomatoTopDark,
    tomatoBottom: AppColors.tomatoBottomDark,
    leaf: AppColors.leafDark,
    heatmapEmpty: Color(0xFF332926),
    cardShadow: [
      BoxShadow(color: Color(0x33000000), blurRadius: 18, offset: Offset(0, 6)),
    ],
  );

  @override
  AppTokens copyWith({
    Color? surfaceAlt,
    Color? textMuted,
    Color? focus,
    Color? shortBreak,
    Color? longBreak,
    Color? tomatoTop,
    Color? tomatoBottom,
    Color? leaf,
    Color? heatmapEmpty,
    List<BoxShadow>? cardShadow,
  }) {
    return AppTokens(
      surfaceAlt: surfaceAlt ?? this.surfaceAlt,
      textMuted: textMuted ?? this.textMuted,
      focus: focus ?? this.focus,
      shortBreak: shortBreak ?? this.shortBreak,
      longBreak: longBreak ?? this.longBreak,
      tomatoTop: tomatoTop ?? this.tomatoTop,
      tomatoBottom: tomatoBottom ?? this.tomatoBottom,
      leaf: leaf ?? this.leaf,
      heatmapEmpty: heatmapEmpty ?? this.heatmapEmpty,
      cardShadow: cardShadow ?? this.cardShadow,
    );
  }

  @override
  AppTokens lerp(covariant AppTokens? other, double t) {
    if (other == null) return this;
    return AppTokens(
      surfaceAlt: Color.lerp(surfaceAlt, other.surfaceAlt, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      focus: Color.lerp(focus, other.focus, t)!,
      shortBreak: Color.lerp(shortBreak, other.shortBreak, t)!,
      longBreak: Color.lerp(longBreak, other.longBreak, t)!,
      tomatoTop: Color.lerp(tomatoTop, other.tomatoTop, t)!,
      tomatoBottom: Color.lerp(tomatoBottom, other.tomatoBottom, t)!,
      leaf: Color.lerp(leaf, other.leaf, t)!,
      heatmapEmpty: Color.lerp(heatmapEmpty, other.heatmapEmpty, t)!,
      cardShadow: t < 0.5 ? cardShadow : other.cardShadow,
    );
  }
}

/// Convenience accessor: `context.tokens.focus`.
extension AppThemeX on BuildContext {
  AppTokens get tokens => Theme.of(this).extension<AppTokens>() ?? AppTokens.light;
  ColorScheme get colors => Theme.of(this).colorScheme;
  TextTheme get texts => Theme.of(this).textTheme;
}

abstract final class AppTheme {
  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isLight = brightness == Brightness.light;
    final tokens = isLight ? AppTokens.light : AppTokens.dark;

    final scheme = ColorScheme(
      brightness: brightness,
      primary: isLight ? AppColors.primary : AppColors.focusLight,
      onPrimary: Colors.white,
      primaryContainer: isLight ? AppColors.accentPale : const Color(0xFF3D211C),
      onPrimaryContainer: isLight ? AppColors.lightText : AppColors.darkText,
      secondary: isLight ? AppColors.accent : AppColors.accentSoft,
      onSecondary: AppColors.lightText,
      secondaryContainer: isLight ? AppColors.accentSoft : const Color(0xFF3A2A26),
      onSecondaryContainer: isLight ? AppColors.lightText : AppColors.darkText,
      error: AppColors.danger,
      onError: Colors.white,
      surface: isLight ? AppColors.lightSurface : AppColors.darkSurface,
      onSurface: isLight ? AppColors.lightText : AppColors.darkText,
      onSurfaceVariant: isLight ? AppColors.lightTextMuted : AppColors.darkTextMuted,
      surfaceContainerLowest: isLight ? AppColors.lightSurface : const Color(0xFF100D0C),
      surfaceContainerLow: isLight ? AppColors.lightBackground : const Color(0xFF1A1615),
      surfaceContainer: isLight ? AppColors.lightSurfaceAlt : AppColors.darkSurface,
      surfaceContainerHigh: isLight ? const Color(0xFFF7E3DD) : AppColors.darkSurfaceAlt,
      surfaceContainerHighest: isLight ? const Color(0xFFF2D7CF) : const Color(0xFF352C29),
      outline: isLight ? AppColors.lightOutline : AppColors.darkOutline,
      outlineVariant: isLight ? const Color(0xFFF6E2DC) : const Color(0xFF382E2B),
      inverseSurface: isLight ? AppColors.lightText : AppColors.darkText,
      onInverseSurface: isLight ? Colors.white : AppColors.lightText,
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor:
          isLight ? AppColors.lightBackground : AppColors.darkBackground,
      splashFactory: InkSparkle.splashFactory,
    );

    return base.copyWith(
      extensions: [tokens],
      textTheme: base.textTheme.apply(
        bodyColor: scheme.onSurface,
        displayColor: scheme.onSurface,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        foregroundColor: scheme.onSurface,
        titleTextStyle: base.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          color: scheme.onSurface,
        ),
        systemOverlayStyle:
            isLight ? SystemUiOverlayStyle.dark : SystemUiOverlayStyle.light,
      ),
      cardTheme: CardThemeData(
        color: scheme.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 52),
          side: BorderSide(color: scheme.outline),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: tokens.surfaceAlt,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surface,
        indicatorColor: isLight ? AppColors.accentPale : AppColors.darkSurfaceAlt,
        elevation: 0,
        height: 68,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ),
      dividerTheme: DividerThemeData(color: scheme.outlineVariant, thickness: 1),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
    );
  }
}
