import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'design_tokens.dart';

class FixoTheme {
  FixoTheme._();

  static ThemeData light() {
    final colorScheme = ColorScheme.light(
      primary: DesignTokens.brand500,
      onPrimary: Colors.white,
      secondary: DesignTokens.brand300,
      onSecondary: Colors.white,
      surface: DesignTokens.paperLight,
      onSurface: DesignTokens.inkLight,
      error: DesignTokens.red,
      onError: Colors.white,
    );

    return _buildTheme(colorScheme, Brightness.light);
  }

  static ThemeData dark() {
    final colorScheme = ColorScheme.dark(
      primary: DesignTokens.brand500,
      onPrimary: Colors.white,
      secondary: DesignTokens.brand700,
      onSecondary: Colors.white,
      surface: DesignTokens.paperDark,
      onSurface: DesignTokens.inkDark,
      // Lighter error ink keeps >=4.5:1 against dark surfaces; ink onError
      // preserves contrast wherever an error fill ever hosts foreground.
      error: DesignTokens.inkDanger(true),
      onError: DesignTokens.inkLight,
    );

    return _buildTheme(colorScheme, Brightness.dark);
  }

  static ThemeData _buildTheme(ColorScheme colorScheme, Brightness brightness) {
    final baseTextTheme = brightness == Brightness.light
        ? ThemeData.light().textTheme
        : ThemeData.dark().textTheme;

    final isDark = brightness == Brightness.dark;
    TextStyle heading(double size, FontWeight weight) =>
        GoogleFonts.spaceGrotesk(
          fontSize: size,
          fontWeight: weight,
          height: 1.25,
          color: DesignTokens.foregroundBrand(isDark),
        );
    TextStyle body(double size, FontWeight weight, {bool muted = false}) =>
        GoogleFonts.ibmPlexSans(
          fontSize: size,
          fontWeight: weight,
          height: 1.4,  // was 1.5 — tighter but still readable; 1.4 × 16 = 22.4 px
          color: muted ? DesignTokens.inkSoft(isDark) : colorScheme.onSurface,
        );
    final controlShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(DesignTokens.radiusControl),
    );
    final textTheme = baseTextTheme.copyWith(
      headlineLarge: heading(DesignTokens.fontSizeH1, FW.bold),          // 24, h: 1.25
      headlineMedium: heading(DesignTokens.fontSizeH2, FW.semibold),     // 20, h: 1.25
      headlineSmall: heading(DesignTokens.fontSizeH3, FW.semibold),      // 17, h: 1.25
      titleLarge: heading(DesignTokens.fontSizeH2, FW.semibold),         // 20, h: 1.25
      titleMedium: heading(DesignTokens.fontSizeH3, FW.semibold),        // 17, h: 1.25 (was body)
      titleSmall: body(DesignTokens.fontSizeSecondary, FW.semibold),     // 14, h: 1.4
      labelLarge: body(DesignTokens.fontSizeControl, FW.semibold),       // 16, h: 1.4 (button label)
      labelMedium: body(DesignTokens.fontSizeStatus, FW.semibold),       // 13, h: 1.4 (chip/status)
      labelSmall: body(DesignTokens.fontSizeCaption, FW.medium),         // 13, h: 1.4
      displayLarge: GoogleFonts.spaceGrotesk(
        fontSize: DesignTokens.fontSizeDisplay,
        fontWeight: FW.bold,
        height: 1.2,
        color: colorScheme.onSurface,
      ),
      displayMedium: GoogleFonts.spaceGrotesk(
        fontSize: DesignTokens.fontSizeH2,
        fontWeight: FW.semibold,
        height: 1.25,
        color: colorScheme.onSurface,
      ),
      displaySmall: GoogleFonts.ibmPlexSans(
        fontSize: DesignTokens.fontSizeH3,
        fontWeight: FW.semibold,
        height: 1.25,
        color: colorScheme.onSurface,
      ),
      bodyLarge: body(DesignTokens.fontSizeBody, FW.regular),            // 16, h: 1.4
      bodyMedium: body(DesignTokens.fontSizeBody, FW.regular),           // 16, h: 1.4
      bodySmall: body(                                                     // 14, h: 1.4 muted
        DesignTokens.fontSizeSecondary,
        FW.regular,
        muted: true,
      ),
    );

    return ThemeData(
      extensions: [isDark ? THColors.dark : THColors.light],
      brightness: brightness,
      colorScheme: colorScheme,
      textTheme: textTheme,
      scaffoldBackgroundColor: colorScheme.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        centerTitle: true,
        // Reset status bar icons to match theme whenever a screen with an
        // AppBar is active. Prevents the dashboard's forced-light style from
        // bleeding into other screens on iOS.
        systemOverlayStyle: isDark
            ? SystemUiOverlayStyle.light.copyWith(
                statusBarColor: Colors.transparent,
              )
            : SystemUiOverlayStyle.dark.copyWith(
                statusBarColor: Colors.transparent,
              ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          // Primary CTA is amber per design-system.html (hi-vis tape rule).
          backgroundColor: DesignTokens.amber,
          foregroundColor: DesignTokens.onAmber,
          disabledBackgroundColor: DesignTokens.surfaceDisabled(isDark),
          disabledForegroundColor: DesignTokens.foregroundDisabled(isDark),
          minimumSize: const Size(
            DesignTokens.targetMinimum,
            DesignTokens.heightPrimary,
          ),
          textStyle: textTheme.labelLarge,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(DesignTokens.radiusControl),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: DesignTokens.space4,
            vertical: DesignTokens.space3,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: DesignTokens.amber,
          foregroundColor: DesignTokens.onAmber,
          disabledBackgroundColor: DesignTokens.surfaceDisabled(isDark),
          disabledForegroundColor: DesignTokens.foregroundDisabled(isDark),
          minimumSize: const Size(
            DesignTokens.targetMinimum,
            DesignTokens.heightPrimary,
          ),
          textStyle: textTheme.labelLarge,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(DesignTokens.radiusControl),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: DesignTokens.space4,
            vertical: DesignTokens.space3,
          ),
        ),
      ),
      materialTapTargetSize: MaterialTapTargetSize.padded,
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: DesignTokens.foregroundBrand(isDark),
          minimumSize: const Size(
            DesignTokens.targetMinimum,
            DesignTokens.heightSecondary,
          ),
          textStyle: textTheme.labelLarge,
          shape: controlShape,
          side: BorderSide(
            color: DesignTokens.borderCard(isDark),
            width: DesignTokens.borderWidthFor(isDark),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: DesignTokens.foregroundBrand(isDark),
          minimumSize: const Size(
            DesignTokens.targetMinimum,
            DesignTokens.targetMinimum,
          ),
          shape: controlShape,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size.square(DesignTokens.targetMinimum),
        ),
      ),
      cardTheme: CardThemeData(
        color: DesignTokens.surfaceCard(isDark),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DesignTokens.radiusCard),
          side: BorderSide(
            color: DesignTokens.borderCard(isDark),
            width: DesignTokens.borderWidthFor(isDark),
          ),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: DesignTokens.amber,
        foregroundColor: DesignTokens.onAmber,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return Colors.white;
          return null;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return DesignTokens.brand500;
          }
          return null;
        }),
      ),
      dividerTheme: DividerThemeData(
        color: brightness == Brightness.light
            ? DesignTokens.paperLineLight
            : DesignTokens.paperLineDark,
        thickness: 1,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: brightness == Brightness.light
            ? Colors.white
            : DesignTokens.cardDark,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(DesignTokens.radiusSheet),
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        labelStyle: textTheme.labelMedium,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DesignTokens.radiusPill),
        ),
        selectedColor: DesignTokens.amber.withValues(alpha: Alpha.tintAccent),
      ),
      inputDecorationTheme: InputDecorationTheme(
        constraints: const BoxConstraints(minHeight: DesignTokens.heightInput),
        helperStyle: textTheme.bodySmall,
        hintStyle: body(
          DesignTokens.fontSizeBody,
          FW.regular,
          muted: true,
        ),
        labelStyle: textTheme.bodyMedium,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DesignTokens.radiusInput),
          borderSide: BorderSide(
            color: DesignTokens.borderCard(isDark),
            width: DesignTokens.borderWidthFor(isDark),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DesignTokens.radiusInput),
          borderSide: BorderSide(
            color: DesignTokens.borderCard(isDark),
            width: DesignTokens.borderWidthFor(isDark),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DesignTokens.radiusInput),
          borderSide: BorderSide(color: DesignTokens.focus, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: DesignTokens.space4,
          vertical: DesignTokens.space3,
        ),
      ),
    );
  }
}
