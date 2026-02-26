import 'package:flutter/material.dart';

// ─────────────────────────────────────────────
// Design Tokens — "Calm Blue"
// ─────────────────────────────────────────────

class AppColors {
  AppColors._();

  static const background = Color(0xFFF8FAFD);
  static const card = Color(0xFFFFFFFF);
  static const primary = Color(0xFF6F95E6);
  static const primaryTint = Color(0xFFE6EEFF);
  static const textMain = Color(0xFF243447);
  static const textSub = Color(0xFF7B8A9A);
  static const divider = Color(0xFFE6ECF3);
  static const cautionSoft = Color(0xFFFFD9C7);
  static const cautionSoft2 = Color(0xFFFFC9B2);
  static const destructive = Colors.red;

  // Chart palette
  static const chartBlue = Color(0xFF6F95E6);
  static const chartOrange = Color(0xFFE8A87C);
  static const chartGreen = Color(0xFF7EC8A8);
  static const chartGrid = Color(0xFFE6ECF3);
}

class AppTextStyles {
  AppTextStyles._();

  static const title = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w600,
    color: AppColors.textMain,
    height: 1.3,
  );

  static const section = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: AppColors.textMain,
    height: 1.3,
  );

  static const body = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: AppColors.textMain,
    height: 1.5,
  );

  static const caption = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.textSub,
    height: 1.4,
  );

  static const captionSmall = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: AppColors.textSub,
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
      color: const Color(0xFF243447).withOpacity(0.06),
      offset: const Offset(0, 4),
      blurRadius: 12,
    ),
  ];
}

// ─────────────────────────────────────────────
// ThemeData — Material 3 + Calm Blue
// ─────────────────────────────────────────────

ThemeData buildCalmBlueTheme() {
  return ThemeData(
    useMaterial3: true,
    colorSchemeSeed: AppColors.primary,
    brightness: Brightness.light,
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
      fillColor: AppColors.background,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.input),
        borderSide: const BorderSide(color: AppColors.divider),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.input),
        borderSide: const BorderSide(color: AppColors.divider),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.input),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
      labelStyle: AppTextStyles.caption,
      hintStyle: AppTextStyles.caption,
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
      backgroundColor: AppColors.textMain,
      contentTextStyle:
          const TextStyle(fontSize: 14, color: Colors.white),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.button),
      ),
      behavior: SnackBarBehavior.floating,
    ),
  );
}
