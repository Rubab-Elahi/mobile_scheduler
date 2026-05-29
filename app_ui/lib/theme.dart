import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class MidnightForestTheme {
  // ── Colors ──────────────────────────────────────────────────
  static const Color background = Color(0xFF0F172A); // Deep Midnight Blue
  static const Color surface = Color(0xFF1E293B);    // Sleek Dark Gray
  static const Color primary = Color(0xFFA855F7);    // Vibrant Amethyst
  static const Color secondary = Color(0xFF10B981);  // Emerald Calm
  static const Color textPrimary = Colors.white;
  static const Color textSecondary = Color(0xFF94A3B8);

  // ── Theme Data ──────────────────────────────────────────────
  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      primaryColor: primary,
      colorScheme: const ColorScheme.dark(
        primary: primary,
        secondary: secondary,
        surface: surface,
        onSurface: textPrimary,
      ),
      textTheme: GoogleFonts.outfitTextTheme().apply(
        bodyColor: textPrimary,
        displayColor: textPrimary,
      ),
      cardTheme: CardTheme(
        color: surface,
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}
