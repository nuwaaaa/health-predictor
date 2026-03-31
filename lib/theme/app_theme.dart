import 'package:flutter/material.dart';

// ─────────────────────────────────────────────
// Design Tokens — "Tech Black"
// ─────────────────────────────────────────────

class AppColors {
  AppColors._();

  static const background = Color(0xFF080C12);
  static const card = Color(0xFF0F1520);
  static const primary = Color(0xFF6F95E6);
  static const primaryTint = Color(0xFF0D1E3A);
  static const textMain = Color(0xFFE2E8F0);
  static const textSub = Color(0xFF8899AA);
  static const divider = Color(0xFF1A2540);
  static const cautionSoft = Color(0xFF2A1A0E);
  static const cautionSoft2 = Color(0xFF3A2010);
  static const destructive = Color(0xFFE06060);

  // Chart palette
  static const chartBlue = Color(0xFF7FA8E8);
  static const chartOrange = Color(0xFFD4956A);
  static const chartGreen = Color(0xFF6DB895);
  static const chartGrid = Color(0xFF1A2540);

  // Confidence badge
  static const confidenceHighBg = Color(0xFF0D2B1F);
  static const confidenceHighText = Color(0xFF6DB895);
  static const confidenceMedBg = Color(0xFF2B2008);
  static const confidenceMedText = Color(0xFFD4B060);

  // Unified mood/health state colors (1=最悪 〜 5=最良)
  static const mood1 = Color(0xFFE06060); // とても悪い — red
  static const mood2 = Color(0xFFD4956A); // 悪い       — orange
  static const mood3 = Color(0xFFD4B060); // 普通       — amber
  static const mood4 = Color(0xFF6DB895); // 良い       — teal-green
  static const mood5 = Color(0xFF7FCFB0); // とても良い — bright teal-green
}

class AppTextStyles {
  AppTextStyles._();

  static const title = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w600,
    height: 1.3,
  );

  static const section = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    height: 1.3,
  );

  static const body = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.5,
  );

  static const caption = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.4,
  );

  static const captionSmall = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 1.4,
  );
}

class AppSpacing {
  AppSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
}

class AppRadii {
  AppRadii._();

  static const double card = 16;
  static const double pill = 20;
  static const double button = 12;
  static const double input = 12;
}

class AppShadows {
  AppShadows._();

  static final card = [
    BoxShadow(
      color: const Color(0xFF6F95E6).withAlpha(18),
      offset: const Offset(0, 2),
      blurRadius: 16,
    ),
  ];
}

// ─────────────────────────────────────────────
// Dark Colors — Tech Black Deep
// ─────────────────────────────────────────────

class AppColorsDark {
  AppColorsDark._();

  static const background = Color(0xFF050810);
  static const card = Color(0xFF0A0E14);
  static const textMain = Color(0xFFE2E8F0);
  static const textSub = Color(0xFF8899AA);
  static const divider = Color(0xFF142035);

  // Primary tint (dark)
  static const primaryTint = Color(0xFF0A1830);

  // Caution (dark)
  static const cautionSoft = Color(0xFF221508);
  static const cautionSoft2 = Color(0xFF301A0A);

  // Chart palette (dark)
  static const chartBlue = Color(0xFF7FA8E8);
  static const chartOrange = Color(0xFFD4956A);
  static const chartGreen = Color(0xFF6DB895);
  static const chartGrid = Color(0xFF142035);

  // Confidence badge (dark)
  static const confidenceHighBg = Color(0xFF0A2018);
  static const confidenceHighText = Color(0xFF6DB895);
  static const confidenceMedBg = Color(0xFF231A06);
  static const confidenceMedText = Color(0xFFD4B060);

  // Risk colors — mood colors と同一値で統一
  static const riskHigh = AppColors.mood1;
  static const riskMedium = AppColors.mood2;
  static const riskLow = AppColors.mood3;

  // Semantic feedback (dark)
  static const positiveBg = Color(0xFF0A2018);
  static const negativeBg = Color(0xFF220A0A);
  static const positiveText = Color(0xFF6DB895);
  static const negativeText = Color(0xFFE06060);

  // Auto-import badge text
  static const autoImportText = Color(0xFF6DB895);
}

// ─────────────────────────────────────────────
// ライト/ダーク対応カラーヘルパー
// ─────────────────────────────────────────────

extension AdaptiveColors on BuildContext {
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
  Color get cardColor => isDark ? AppColorsDark.card : AppColors.card;
  Color get bgColor => isDark ? AppColorsDark.background : AppColors.background;
  Color get textMainColor => isDark ? AppColorsDark.textMain : AppColors.textMain;
  Color get textSubColor => isDark ? AppColorsDark.textSub : AppColors.textSub;
  Color get dividerColor => isDark ? AppColorsDark.divider : AppColors.divider;
  Color get primaryTintColor => isDark ? AppColorsDark.primaryTint : AppColors.primaryTint;
  Color get cautionSoftColor => isDark ? AppColorsDark.cautionSoft : AppColors.cautionSoft;

  // Chart
  Color get chartBlueColor => isDark ? AppColorsDark.chartBlue : AppColors.chartBlue;
  Color get chartOrangeColor => isDark ? AppColorsDark.chartOrange : AppColors.chartOrange;
  Color get chartGreenColor => isDark ? AppColorsDark.chartGreen : AppColors.chartGreen;
  Color get chartGridColor => isDark ? AppColorsDark.chartGrid : AppColors.chartGrid;

  // Confidence badge
  Color get confidenceHighBg => isDark ? AppColorsDark.confidenceHighBg : AppColors.confidenceHighBg;
  Color get confidenceHighText => isDark ? AppColorsDark.confidenceHighText : AppColors.confidenceHighText;
  Color get confidenceMedBg => isDark ? AppColorsDark.confidenceMedBg : AppColors.confidenceMedBg;
  Color get confidenceMedText => isDark ? AppColorsDark.confidenceMedText : AppColors.confidenceMedText;

  // Mood (1〜5) → 統一体調色
  Color moodColor(int score) {
    switch (score) {
      case 1: return AppColors.mood1;
      case 2: return AppColors.mood2;
      case 3: return AppColors.mood3;
      case 4: return AppColors.mood4;
      case 5: return AppColors.mood5;
      default: return AppColors.textSub;
    }
  }

  // Risk (予測リスク確率) → mood colors と統一
  Color riskColor(double p) {
    if (p >= 0.6) return AppColors.mood1;
    if (p >= 0.4) return AppColors.mood2;
    if (p >= 0.2) return AppColors.mood3;
    return AppColors.mood5;
  }

  // Feedback / contribution
  Color get positiveBgColor => AppColorsDark.positiveBg;
  Color get negativeBgColor => AppColorsDark.negativeBg;
  Color get positiveTextColor => AppColorsDark.positiveText;
  Color get negativeTextColor => AppColorsDark.negativeText;

  // Auto-import badge
  Color get autoImportTextColor => AppColorsDark.autoImportText;

  // Alpha helper — ダーク時は alpha を高くして可視性を確保
  Color primaryWithAlpha(int lightAlpha) =>
      AppColors.primary.withAlpha(isDark ? (lightAlpha * 2.5).round().clamp(0, 255) : lightAlpha);

  Color colorWithAdaptiveAlpha(Color color, int lightAlpha) =>
      color.withAlpha(isDark ? (lightAlpha * 2.5).round().clamp(0, 255) : lightAlpha);
}

// ─────────────────────────────────────────────
// ThemeData — Material 3 + Calm Blue
// ─────────────────────────────────────────────

ThemeData buildCalmBlueTheme() {
  return ThemeData(
    useMaterial3: true,
    colorSchemeSeed: AppColors.primary,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.background,

    // AppBar
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.background,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: AppColors.textMain,
      ),
      iconTheme: IconThemeData(color: AppColors.textMain),
    ),

    // Card
    cardTheme: CardThemeData(
      color: AppColors.card,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.card),
      ),
      margin: EdgeInsets.zero,
    ),

    // Divider
    dividerTheme: const DividerThemeData(
      color: AppColors.divider,
      thickness: 1,
      space: 0,
    ),

    // Bottom Nav
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: AppColors.card,
      selectedItemColor: AppColors.primary,
      unselectedItemColor: AppColors.textSub,
      type: BottomNavigationBarType.fixed,
      elevation: 0,
      selectedLabelStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      unselectedLabelStyle: TextStyle(fontSize: 12),
    ),

    // Elevated Button
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.button),
        ),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),

    // Outlined Button
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primary,
        side: const BorderSide(color: AppColors.divider),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.button),
        ),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),

    // TextField / InputDecoration
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.card,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.input),
        borderSide: const BorderSide(color: AppColors.divider, width: 1.5),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.input),
        borderSide: const BorderSide(color: AppColors.divider, width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.input),
        borderSide: const BorderSide(color: AppColors.primary, width: 2),
      ),
      labelStyle: const TextStyle(fontSize: 14, color: AppColors.textSub),
      hintStyle: const TextStyle(fontSize: 14, color: AppColors.textSub),
    ),

    // ChoiceChip / Chip
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.card,
      selectedColor: AppColors.primaryTint,
      side: const BorderSide(color: AppColors.divider),
      labelStyle: const TextStyle(fontSize: 13, color: AppColors.textMain),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    ),

    // Snackbar
    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppColors.card,
      contentTextStyle:
          const TextStyle(fontSize: 14, color: AppColors.textMain),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.button),
      ),
      behavior: SnackBarBehavior.floating,
    ),
  );
}

ThemeData buildCalmBlueDarkTheme() {
  return ThemeData(
    useMaterial3: true,
    colorSchemeSeed: AppColors.primary,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColorsDark.background,

    appBarTheme: const AppBarTheme(
      backgroundColor: AppColorsDark.background,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: AppColorsDark.textMain,
      ),
      iconTheme: IconThemeData(color: AppColorsDark.textMain),
    ),

    cardTheme: CardThemeData(
      color: AppColorsDark.card,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.card),
      ),
      margin: EdgeInsets.zero,
    ),

    dividerTheme: const DividerThemeData(
      color: AppColorsDark.divider,
      thickness: 1,
      space: 0,
    ),

    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: AppColorsDark.card,
      selectedItemColor: AppColors.primary,
      unselectedItemColor: AppColorsDark.textSub,
      type: BottomNavigationBarType.fixed,
      elevation: 0,
      selectedLabelStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      unselectedLabelStyle: TextStyle(fontSize: 12),
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.button),
        ),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),

    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primary,
        side: const BorderSide(color: AppColorsDark.divider),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.button),
        ),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColorsDark.card,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.input),
        borderSide: const BorderSide(color: AppColorsDark.textSub, width: 1.5),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.input),
        borderSide: const BorderSide(color: AppColorsDark.textSub, width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.input),
        borderSide: const BorderSide(color: AppColors.primary, width: 2),
      ),
      labelStyle: const TextStyle(fontSize: 14, color: AppColorsDark.textSub),
      hintStyle: const TextStyle(fontSize: 14, color: AppColorsDark.textSub),
    ),

    chipTheme: ChipThemeData(
      backgroundColor: AppColorsDark.card,
      selectedColor: const Color(0xFF2A3A55),
      side: const BorderSide(color: AppColorsDark.divider),
      labelStyle: const TextStyle(fontSize: 13, color: AppColorsDark.textMain),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    ),

    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppColorsDark.textMain,
      contentTextStyle:
          const TextStyle(fontSize: 14, color: AppColorsDark.background),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.button),
      ),
      behavior: SnackBarBehavior.floating,
    ),
  );
}
