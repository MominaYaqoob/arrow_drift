import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.system);

/// Design tokens for light and dark themes.
class AppColors {
  AppColors._();

  // Light
  static const Color lightBackground = Color(0xFFF6F3EC);
  static const Color background = lightBackground;
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurface2 = Color(0xFFEDE8DC);
  static const Color lightBorder = Color(0xFFD8D0C2);
  static const Color lightPrimaryText = Color(0xFF0E1726);
  static const Color lightSecondaryText = Color(0xFF6B7280);
  static const Color lightAccentTealSoft = Color(0xFFD9F5EE);
  static const Color lightGold = Color(0xFFE0B13A);
  static const Color lightArrowLight = Color(0xFFEEF3F8);

  // Shared accents
  static const Color accentTeal = Color(0xFF2EC4A6);
  static const Color accentTealDeep = Color(0xFF0F8F7A);
  static const Color heartRed = Color(0xFFE25563);

  // Dark
  static const Color darkBackground = Color(0xFF0A101A);
  static const Color darkSurface = Color(0xFF141C2A);
  static const Color darkSurface2 = Color(0xFF1C2638);
  static const Color darkBorder = Color(0xFF2A3648);
  static const Color darkPrimaryText = Color(0xFFFFFFFF);
  static const Color darkSecondaryText = Color(0xFF9AA5B5);

  /// Resolves theme-aware colors from [BuildContext].
  static AppColorScheme of(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return brightness == Brightness.dark ? dark : light;
  }

  static const AppColorScheme light = AppColorScheme(
    background: lightBackground,
    surface: lightSurface,
    surface2: lightSurface2,
    border: lightBorder,
    primaryText: lightPrimaryText,
    secondaryText: lightSecondaryText,
    accentTeal: accentTeal,
    accentTealDeep: accentTealDeep,
    accentTealSoft: lightAccentTealSoft,
    gold: lightGold,
    heartRed: heartRed,
    arrowLight: lightArrowLight,
  );

  static const AppColorScheme dark = AppColorScheme(
    background: darkBackground,
    surface: darkSurface,
    surface2: darkSurface2,
    border: darkBorder,
    primaryText: darkPrimaryText,
    secondaryText: darkSecondaryText,
    accentTeal: accentTeal,
    accentTealDeep: accentTealDeep,
    accentTealSoft: Color(0xFF1A3D38),
    gold: lightGold,
    heartRed: heartRed,
    // Dark-theme default arrow stroke (#EEF3F8).
    arrowLight: lightArrowLight,
  );
}

/// Theme-aware color palette used by screens.
class AppColorScheme {
  const AppColorScheme({
    required this.background,
    required this.surface,
    required this.surface2,
    required this.border,
    required this.primaryText,
    required this.secondaryText,
    required this.accentTeal,
    required this.accentTealDeep,
    required this.accentTealSoft,
    required this.gold,
    required this.heartRed,
    required this.arrowLight,
  });

  final Color background;
  final Color surface;
  final Color surface2;
  final Color border;
  final Color primaryText;
  final Color secondaryText;
  final Color accentTeal;
  final Color accentTealDeep;
  final Color accentTealSoft;
  final Color gold;
  final Color heartRed;
  final Color arrowLight;
}

/// Typography using Fraunces (headings) and DM Sans (body).
class AppTextStyles {
  AppTextStyles._();

  static TextStyle heading({
    double fontSize = 28,
    FontWeight fontWeight = FontWeight.w700,
    Color? color,
    double? height,
    double? letterSpacing,
  }) {
    return GoogleFonts.fraunces(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
    );
  }

  static TextStyle headingLarge({Color? color}) => heading(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        color: color,
      );

  static TextStyle headingMedium({Color? color}) => heading(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        color: color,
      );

  static TextStyle headingSmall({Color? color}) => heading(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: color,
      );

  static TextStyle body({
    double fontSize = 16,
    FontWeight fontWeight = FontWeight.w400,
    Color? color,
    double? height,
    double? letterSpacing,
  }) {
    return GoogleFonts.dmSans(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
    );
  }

  static TextStyle bodyLarge({Color? color, FontWeight fontWeight = FontWeight.w400}) =>
      body(fontSize: 18, fontWeight: fontWeight, color: color);

  static TextStyle bodyMedium({Color? color, FontWeight fontWeight = FontWeight.w400}) =>
      body(fontSize: 16, fontWeight: fontWeight, color: color);

  static TextStyle bodySmall({Color? color, FontWeight fontWeight = FontWeight.w400}) =>
      body(fontSize: 14, fontWeight: fontWeight, color: color);

  static TextStyle label({
    double fontSize = 12,
    FontWeight fontWeight = FontWeight.w600,
    Color? color,
  }) {
    return GoogleFonts.dmSans(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
    );
  }

  static TextStyle button({
    double fontSize = 16,
    FontWeight fontWeight = FontWeight.w700,
    Color? color,
  }) {
    return GoogleFonts.dmSans(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
    );
  }
}

class AppTheme {
  AppTheme._();

  static ThemeData get light => _build(Brightness.light, AppColors.light);

  static ThemeData get dark => _build(Brightness.dark, AppColors.dark);

  static ThemeData _build(Brightness brightness, AppColorScheme colors) {
    final isDark = brightness == Brightness.dark;

    final baseTextTheme = TextTheme(
      displayLarge: AppTextStyles.heading(fontSize: 40, fontWeight: FontWeight.w700),
      displayMedium: AppTextStyles.heading(fontSize: 36, fontWeight: FontWeight.w700),
      displaySmall: AppTextStyles.heading(fontSize: 32, fontWeight: FontWeight.w700),
      headlineLarge: AppTextStyles.heading(fontSize: 28, fontWeight: FontWeight.w700),
      headlineMedium: AppTextStyles.heading(fontSize: 24, fontWeight: FontWeight.w600),
      headlineSmall: AppTextStyles.heading(fontSize: 20, fontWeight: FontWeight.w600),
      titleLarge: AppTextStyles.body(fontSize: 18, fontWeight: FontWeight.w700),
      titleMedium: AppTextStyles.body(fontSize: 16, fontWeight: FontWeight.w600),
      titleSmall: AppTextStyles.body(fontSize: 14, fontWeight: FontWeight.w600),
      bodyLarge: AppTextStyles.body(fontSize: 16, fontWeight: FontWeight.w400),
      bodyMedium: AppTextStyles.body(fontSize: 14, fontWeight: FontWeight.w400),
      bodySmall: AppTextStyles.body(fontSize: 12, fontWeight: FontWeight.w400),
      labelLarge: AppTextStyles.body(fontSize: 14, fontWeight: FontWeight.w700),
      labelMedium: AppTextStyles.body(fontSize: 12, fontWeight: FontWeight.w600),
      labelSmall: AppTextStyles.body(fontSize: 11, fontWeight: FontWeight.w500),
    ).apply(
      bodyColor: colors.primaryText,
      displayColor: colors.primaryText,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: colors.background,
      canvasColor: colors.background,
      cardColor: colors.surface,
      dividerColor: colors.border,
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: colors.accentTeal,
        onPrimary: isDark ? colors.primaryText : colors.lightOnAccent,
        primaryContainer: colors.accentTealSoft,
        onPrimaryContainer: colors.accentTealDeep,
        secondary: colors.accentTealDeep,
        onSecondary: isDark ? colors.primaryText : colors.lightOnAccent,
        secondaryContainer: colors.surface2,
        onSecondaryContainer: colors.primaryText,
        tertiary: colors.gold,
        onTertiary: colors.primaryText,
        error: colors.heartRed,
        onError: Colors.white,
        surface: colors.surface,
        onSurface: colors.primaryText,
        onSurfaceVariant: colors.secondaryText,
        outline: colors.border,
        outlineVariant: colors.border,
        surfaceContainerHighest: colors.surface2,
        surfaceContainerHigh: colors.surface2,
        surfaceContainer: colors.surface,
        surfaceContainerLow: colors.surface,
        surfaceContainerLowest: colors.background,
      ),
      textTheme: baseTextTheme,
      primaryTextTheme: baseTextTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: colors.background,
        foregroundColor: colors.primaryText,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: AppTextStyles.heading(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: colors.primaryText,
        ),
      ),
      cardTheme: CardThemeData(
        color: colors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: colors.border),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: colors.border,
        thickness: 1,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colors.accentTeal,
          foregroundColor: isDark ? colors.primaryText : const Color(0xFF0E1726),
          textStyle: AppTextStyles.button(),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colors.accentTealDeep,
          textStyle: AppTextStyles.button(fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colors.primaryText,
          side: BorderSide(color: colors.border),
          textStyle: AppTextStyles.button(fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.surface,
        hintStyle: AppTextStyles.body(color: colors.secondaryText),
        labelStyle: AppTextStyles.body(color: colors.secondaryText),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.accentTeal, width: 2),
        ),
      ),
      iconTheme: IconThemeData(color: colors.primaryText),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colors.accentTeal,
        foregroundColor: isDark ? colors.primaryText : const Color(0xFF0E1726),
      ),
      extensions: <ThemeExtension<dynamic>>[
        AppThemeColors(colors),
      ],
    );
  }
}

extension on AppColorScheme {
  Color get lightOnAccent => const Color(0xFF0E1726);
}

/// Theme extension so widgets can read [AppColorScheme] via Theme.of(context).
class AppThemeColors extends ThemeExtension<AppThemeColors> {
  const AppThemeColors(this.colors);

  final AppColorScheme colors;

  @override
  AppThemeColors copyWith({AppColorScheme? colors}) {
    return AppThemeColors(colors ?? this.colors);
  }

  @override
  AppThemeColors lerp(ThemeExtension<AppThemeColors>? other, double t) {
    if (other is! AppThemeColors) return this;
    return t < 0.5 ? this : other;
  }
}

extension AppThemeColorsX on BuildContext {
  AppColorScheme get appColors =>
      Theme.of(this).extension<AppThemeColors>()?.colors ?? AppColors.of(this);
}
