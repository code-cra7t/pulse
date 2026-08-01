import 'package:flutter/material.dart';

class AppColors {
  static const background = Color(0xFFF8F5EE);
  static const surface = Color(0xFFFFFDF8);
  static const ink = Color(0xFF292824);
  static const muted = Color(0xFF77736A);
  static const primary = Color(0xFFE96B4C);
  static const primarySoft = Color(0xFFFFD9CE);
  static const teal = Color(0xFF3C8C82);
  static const butter = Color(0xFFFFE8A8);
  static const peach = Color(0xFFFFCDBD);
  static const mint = Color(0xFFCDEAD8);
  static const sky = Color(0xFFCFE8F6);
  static const blush = Color(0xFFF4D5DF);
  static const lavender = Color(0xFFE1D9F2);
  static const warning = Color(0xFFD9773D);
  static const desktopCanvas = Color(0xFFF4F0E8);
  static const panel = Color(0xFFFFFEFB);
  static const panelBorder = Color(0x1A292824);
  static const sidebarActive = Color(0xFFFFE8A8);
  static const selectionBorder = Color(0xFFE96B4C);

  static const notePastels = <Color>[butter, sky, mint, blush, lavender];

  static Color canvasFor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF1D1B18)
        : background;
  }

  static Color panelFor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF24221F)
        : panel;
  }

  static Color panelBorderFor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? Colors.white.withValues(alpha: 0.10)
        : panelBorder;
  }

  static Color textFor(Color background) {
    return background.computeLuminance() > 0.48 ? ink : const Color(0xFFF8F5EE);
  }

  static Color mutedTextFor(Color background) {
    return background.computeLuminance() > 0.48
        ? muted
        : const Color(0xFFCFC7BA);
  }
}

class AppSpacing {
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
}

class AppRadii {
  static const double sm = 12;
  static const double md = 18;
  static const double lg = 26;
  static const double pill = 999;
}

class AppTheme {
  static ThemeData build() {
    final colorScheme =
        ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          brightness: Brightness.light,
          surface: AppColors.surface,
        ).copyWith(
          primary: AppColors.primary,
          secondary: AppColors.teal,
          onSurface: AppColors.ink,
          onSurfaceVariant: AppColors.muted,
          surfaceContainerLowest: AppColors.surface,
          surfaceContainerLow: const Color(0xFFF3EFE6),
          surfaceContainer: const Color(0xFFEEE9DF),
          surfaceContainerHigh: const Color(0xFFE9E3D8),
          surfaceContainerHighest: const Color(0xFFE3DDD1),
        );

    final textTheme = Typography.blackCupertino.copyWith(
      displaySmall: const TextStyle(
        fontSize: 38,
        fontWeight: FontWeight.w800,
        letterSpacing: -1.3,
        height: 1.02,
        color: AppColors.ink,
      ),
      headlineMedium: const TextStyle(
        fontSize: 30,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.9,
        height: 1.08,
        color: AppColors.ink,
      ),
      headlineSmall: const TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.55,
        height: 1.12,
        color: AppColors.ink,
      ),
      titleLarge: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.35,
        height: 1.18,
        color: AppColors.ink,
      ),
      titleMedium: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        height: 1.25,
        color: AppColors.ink,
      ),
      titleSmall: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.1,
        color: AppColors.muted,
      ),
      bodyLarge: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        height: 1.5,
        color: AppColors.ink,
      ),
      bodyMedium: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 1.45,
        color: AppColors.ink,
      ),
      bodySmall: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        height: 1.35,
        color: AppColors.muted,
      ),
      labelLarge: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.1,
      ),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.background,
      textTheme: textTheme,
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.ink,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: textTheme.titleLarge,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.lg),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        hintStyle: textTheme.bodyMedium?.copyWith(color: AppColors.muted),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: 15,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
          borderSide: const BorderSide(color: Color(0x14000000)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          foregroundColor: Colors.white,
          backgroundColor: AppColors.ink,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.md),
          ),
          textStyle: textTheme.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(50),
          foregroundColor: AppColors.ink,
          side: const BorderSide(color: Color(0x22000000)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.md),
          ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: AppColors.ink,
          backgroundColor: const Color(0x0D000000),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surface,
        modalBackgroundColor: AppColors.surface,
        showDragHandle: true,
        surfaceTintColor: Colors.transparent,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.ink,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surface,
        selectedColor: AppColors.primarySoft,
        side: const BorderSide(color: Color(0x14000000)),
        labelStyle: textTheme.bodySmall?.copyWith(
          color: AppColors.ink,
          fontWeight: FontWeight.w700,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.pill),
        ),
      ),
      dividerColor: const Color(0x16000000),
    );
  }

  static ThemeData buildDark() {
    final base = build();
    final colorScheme =
        ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          brightness: Brightness.dark,
        ).copyWith(
          primary: AppColors.primarySoft,
          secondary: AppColors.mint,
          surface: const Color(0xFF24221F),
          onSurface: const Color(0xFFF8F5EE),
          onSurfaceVariant: const Color(0xFFC8C0B2),
        );

    return base.copyWith(
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: const Color(0xFF1D1B18),
      textTheme: base.textTheme.apply(
        bodyColor: colorScheme.onSurface,
        displayColor: colorScheme.onSurface,
      ),
      appBarTheme: base.appBarTheme.copyWith(
        foregroundColor: colorScheme.onSurface,
      ),
      cardTheme: base.cardTheme.copyWith(color: colorScheme.surface),
      inputDecorationTheme: base.inputDecorationTheme.copyWith(
        fillColor: const Color(0xFF2D2A26),
        hintStyle: base.textTheme.bodyMedium?.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
          borderSide: const BorderSide(
            color: AppColors.primarySoft,
            width: 1.5,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          foregroundColor: AppColors.ink,
          backgroundColor: AppColors.primarySoft,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.md),
          ),
          textStyle: base.textTheme.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(50),
          foregroundColor: colorScheme.onSurface,
          side: BorderSide(color: Colors.white.withValues(alpha: 0.18)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.md),
          ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: colorScheme.onSurface,
          backgroundColor: Colors.white.withValues(alpha: 0.08),
        ),
      ),
      bottomSheetTheme: base.bottomSheetTheme.copyWith(
        backgroundColor: colorScheme.surface,
        modalBackgroundColor: colorScheme.surface,
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: const Color(0xFF2D2A26),
        selectedColor: AppColors.primary.withValues(alpha: 0.36),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
        labelStyle: base.textTheme.bodySmall?.copyWith(
          color: colorScheme.onSurface,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
