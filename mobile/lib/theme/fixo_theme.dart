import 'package:flutter/material.dart';
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
      error: DesignTokens.red,
      onError: Colors.white,
    );

    return _buildTheme(colorScheme, Brightness.dark);
  }

  static ThemeData _buildTheme(ColorScheme colorScheme, Brightness brightness) {
    final baseTextTheme = brightness == Brightness.light
        ? ThemeData.light().textTheme
        : ThemeData.dark().textTheme;

    final textTheme = baseTextTheme.copyWith(
      displayLarge: GoogleFonts.spaceGrotesk(
        fontSize: DesignTokens.fontSizeDisplay,
        fontWeight: FontWeight.w700,
        color: colorScheme.onSurface,
      ),
      displayMedium: GoogleFonts.spaceGrotesk(
        fontSize: DesignTokens.fontSizeH2,
        fontWeight: FontWeight.w600,
        color: colorScheme.onSurface,
      ),
      displaySmall: GoogleFonts.ibmPlexSans(
        fontSize: DesignTokens.fontSizeH3,
        fontWeight: FontWeight.w600,
        color: colorScheme.onSurface,
      ),
      bodyLarge: GoogleFonts.ibmPlexSans(
        fontSize: DesignTokens.fontSizeBody,
        fontWeight: FontWeight.w400,
        color: colorScheme.onSurface,
      ),
      bodyMedium: GoogleFonts.ibmPlexSans(
        fontSize: DesignTokens.fontSizeBody,
        fontWeight: FontWeight.w400,
        color: colorScheme.onSurface,
      ),
      bodySmall: GoogleFonts.ibmPlexMono(
        fontSize: DesignTokens.fontSizeMono,
        fontWeight: FontWeight.w400,
        color: colorScheme.onSurface,
      ),
    );

    return ThemeData(
      brightness: brightness,
      colorScheme: colorScheme,
      textTheme: textTheme,
      scaffoldBackgroundColor: colorScheme.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        centerTitle: true,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          // Primary CTA is amber per design-system.html (hi-vis tape rule).
          backgroundColor: DesignTokens.amber,
          foregroundColor: DesignTokens.onAmber,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(DesignTokens.radius),
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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(DesignTokens.radius),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: DesignTokens.space4,
            vertical: DesignTokens.space3,
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
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DesignTokens.radius),
        ),
        selectedColor: DesignTokens.amber.withValues(alpha: 0.15),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DesignTokens.radius),
          borderSide: BorderSide(
            color: brightness == Brightness.light
                ? DesignTokens.paperLineLight
                : DesignTokens.paperLineDark,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DesignTokens.radius),
          borderSide: BorderSide(
            color: brightness == Brightness.light
                ? DesignTokens.paperLineLight
                : DesignTokens.paperLineDark,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(DesignTokens.radius),
          borderSide: BorderSide(
            color: DesignTokens.brand500,
            width: 2,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: DesignTokens.space4,
          vertical: DesignTokens.space3,
        ),
      ),
    );
  }
}
