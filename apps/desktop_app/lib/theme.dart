import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class SigapTheme {
  static const Color primaryColor = Color(
    0xFFFF1744,
  ); // Neon red for critical alarms
  static const Color secondaryColor = Color(
    0xFF00E5FF,
  ); // Neon cyan for active tracking
  static const Color backgroundColor = Color(
    0xFF0A0D14,
  ); // Very deep slate/black
  static const Color surfaceColor = Color(0xFF131824); // Slightly lighter slate
  static const Color cardColor = Color(0xFF1A2234); // Slate card color
  static const Color textPrimaryColor = Colors.white;
  static const Color textSecondaryColor = Color(
    0xFF8E9EB6,
  ); // Desaturated blue-grey

  static const Color successColor = Color(0xFF00E676); // Neon green
  static const Color warningColor = Color(0xFFFFC400); // Yellow/Amber
  static const Color errorColor = Color(0xFFFF1744);
  static const Color infoColor = Color(0xFF2979FF); // Bright blue

  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      primaryColor: primaryColor,
      scaffoldBackgroundColor: backgroundColor,
      cardColor: cardColor,
      fontFamily: GoogleFonts.outfit().fontFamily,
      textTheme: GoogleFonts.outfitTextTheme(
        ThemeData.dark().textTheme.copyWith(
          displayLarge: const TextStyle(
            color: textPrimaryColor,
            fontWeight: FontWeight.bold,
          ),
          titleLarge: const TextStyle(
            color: textPrimaryColor,
            fontWeight: FontWeight.bold,
          ),
          bodyLarge: const TextStyle(color: textPrimaryColor),
          bodyMedium: const TextStyle(color: textSecondaryColor),
        ),
      ),
      colorScheme: const ColorScheme.dark(
        primary: primaryColor,
        secondary: secondaryColor,
        surface: surfaceColor,
        error: errorColor,
      ),
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStateProperty.all(Colors.white.withOpacity(0.15)),
        trackColor: WidgetStateProperty.all(Colors.transparent),
        radius: const Radius.circular(8),
      ),
    );
  }
}
