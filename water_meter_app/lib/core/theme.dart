import 'package:flutter/material.dart';

class AppTheme {
  static const Color primaryBlue  = Color(0xFF1565C0);
  static const Color accentCyan   = Color(0xFF0288D1);
  static const Color errorRed     = Color(0xFFD32F2F);
  static const Color scaffoldBg   = Color(0xFFE8EFF9);

  // ── Semantic status colours ─────────────────────────────────────────────────
  static const Color statusPaid    = Color(0xFF2E7D32);
  static const Color statusUnpaid  = Color(0xFFF57F17);
  static const Color statusOverdue = Color(0xFFC62828);

  static const Color statusPaidBg    = Color(0xFFE8F5E9);
  static const Color statusUnpaidBg  = Color(0xFFFFFDE7);
  static const Color statusOverdueBg = Color(0xFFFFEBEE);

  static ThemeData get lightTheme {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryBlue,
        primary: primaryBlue,
        secondary: accentCyan,
        error: errorRed,
        brightness: Brightness.light,
        surface: Colors.white,
      ),
      scaffoldBackgroundColor: scaffoldBg,
    );

    return base.copyWith(
      // ── AppBar ──────────────────────────────────────────────────────────────
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 1,
        backgroundColor: primaryBlue,
        foregroundColor: Colors.white,
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
        ),
        iconTheme: IconThemeData(color: Colors.white),
      ),

      // ── Cards ───────────────────────────────────────────────────────────────
      cardTheme: CardThemeData(
        elevation: 0,
        color: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      ),

      // ── Buttons ─────────────────────────────────────────────────────────────
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryBlue,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryBlue,
          side: const BorderSide(color: primaryBlue),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryBlue,
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),

      // ── Inputs ──────────────────────────────────────────────────────────────
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primaryBlue, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: errorRed),
        ),
        labelStyle: TextStyle(color: Colors.grey.shade600),
        floatingLabelStyle: const TextStyle(color: primaryBlue),
      ),

      // ── Navigation bar ───────────────────────────────────────────────────────
      navigationBarTheme: NavigationBarThemeData(
        elevation: 0,
        backgroundColor: Colors.white,
        indicatorColor: primaryBlue.withValues(alpha: 0.12),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
                fontSize: 12, fontWeight: FontWeight.w600, color: primaryBlue);
          }
          return TextStyle(fontSize: 12, color: Colors.grey.shade600);
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: primaryBlue, size: 24);
          }
          return IconThemeData(color: Colors.grey.shade500, size: 24);
        }),
      ),

      // ── Chips ───────────────────────────────────────────────────────────────
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
      ),

      // ── List tiles ───────────────────────────────────────────────────────────
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),

      // ── Divider ─────────────────────────────────────────────────────────────
      dividerTheme: DividerThemeData(
        color: Colors.grey.shade200,
        thickness: 1,
        space: 1,
      ),

      // ── Text ────────────────────────────────────────────────────────────────
      textTheme: base.textTheme.copyWith(
        headlineLarge: const TextStyle(
            fontSize: 32, fontWeight: FontWeight.w800, color: Color(0xFF1A1A2E)),
        headlineMedium: const TextStyle(
            fontSize: 26, fontWeight: FontWeight.w700, color: Color(0xFF1A1A2E)),
        headlineSmall: const TextStyle(
            fontSize: 22, fontWeight: FontWeight.w700, color: Color(0xFF1A1A2E)),
        titleLarge: const TextStyle(
            fontSize: 18, fontWeight: FontWeight.w600, color: Color(0xFF1A1A2E)),
        titleMedium: const TextStyle(
            fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF1A1A2E)),
        titleSmall: const TextStyle(
            fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1A1A2E)),
        bodyLarge: const TextStyle(fontSize: 15, color: Color(0xFF2D2D3A)),
        bodyMedium: TextStyle(fontSize: 14, color: Colors.grey.shade700),
        bodySmall: TextStyle(fontSize: 12, color: Colors.grey.shade500),
        labelLarge: const TextStyle(
            fontSize: 14, fontWeight: FontWeight.w600, color: primaryBlue),
      ),
    );
  }

  // Dark theme palette
  static const Color _darkBg     = Color(0xFF0D1117); // deep navy-black
  static const Color _darkSurface = Color(0xFF161B22); // card surface
  static const Color _darkElevated = Color(0xFF1C2333); // slightly raised

  static ThemeData get darkTheme {
    const primary = Color(0xFF64B5F6);   // soft blue readable on dark
    const secondary = Color(0xFF4DD0E1);

    return ThemeData(
      useMaterial3: true,
      colorScheme: const ColorScheme(
        brightness: Brightness.dark,
        primary: primary,
        onPrimary: Color(0xFF0D1117),
        primaryContainer: Color(0xFF1565C0),
        onPrimaryContainer: Colors.white,
        secondary: secondary,
        onSecondary: Color(0xFF0D1117),
        secondaryContainer: Color(0xFF0277BD),
        onSecondaryContainer: Colors.white,
        error: Color(0xFFCF6679),
        onError: Colors.white,
        surface: _darkSurface,
        onSurface: Color(0xFFE6EDF3),
        surfaceContainerHighest: _darkElevated,
        outline: Color(0xFF30363D),
      ),
      scaffoldBackgroundColor: _darkBg,

      // ── AppBar ──────────────────────────────────────────────────────────────
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        elevation: 0,
        backgroundColor: Color(0xFF1565C0),
        foregroundColor: Colors.white,
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
        ),
        iconTheme: IconThemeData(color: Colors.white),
      ),

      // ── Cards ───────────────────────────────────────────────────────────────
      cardTheme: CardThemeData(
        elevation: 0,
        color: _darkSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Color(0xFF30363D)),
        ),
        margin: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      ),

      // ── Buttons ─────────────────────────────────────────────────────────────
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Color(0xFF0D1117),
          elevation: 0,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          textStyle:
              TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          side: BorderSide(color: primary),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
        ),
      ),

      // ── Inputs ──────────────────────────────────────────────────────────────
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _darkElevated,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF30363D)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF30363D)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primary, width: 2),
        ),
        labelStyle: const TextStyle(color: Color(0xFF8B949E)),
        floatingLabelStyle: const TextStyle(color: primary),
        hintStyle: const TextStyle(color: Color(0xFF8B949E)),
      ),

      // ── Navigation bar ───────────────────────────────────────────────────────
      navigationBarTheme: NavigationBarThemeData(
        elevation: 0,
        backgroundColor: _darkSurface,
        indicatorColor: primary.withValues(alpha: 0.15),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: primary);
          }
          return const TextStyle(
              fontSize: 12, color: Color(0xFF8B949E));
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: primary, size: 24);
          }
          return const IconThemeData(
              color: Color(0xFF8B949E), size: 24);
        }),
      ),

      // ── Chips ───────────────────────────────────────────────────────────────
      chipTheme: ChipThemeData(
        backgroundColor: _darkElevated,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        labelStyle: const TextStyle(fontSize: 13, color: Color(0xFFE6EDF3)),
        side: const BorderSide(color: Color(0xFF30363D)),
      ),

      // ── Divider ─────────────────────────────────────────────────────────────
      dividerTheme: const DividerThemeData(
        color: Color(0xFF30363D),
        thickness: 1,
        space: 1,
      ),

      // ── Text ────────────────────────────────────────────────────────────────
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
            fontSize: 32, fontWeight: FontWeight.w800, color: Color(0xFFE6EDF3)),
        headlineMedium: TextStyle(
            fontSize: 26, fontWeight: FontWeight.w700, color: Color(0xFFE6EDF3)),
        headlineSmall: TextStyle(
            fontSize: 22, fontWeight: FontWeight.w700, color: Color(0xFFE6EDF3)),
        titleLarge: TextStyle(
            fontSize: 18, fontWeight: FontWeight.w600, color: Color(0xFFE6EDF3)),
        titleMedium: TextStyle(
            fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFFE6EDF3)),
        titleSmall: TextStyle(
            fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFFE6EDF3)),
        bodyLarge: TextStyle(fontSize: 15, color: Color(0xFFCDD9E5)),
        bodyMedium: TextStyle(fontSize: 14, color: Color(0xFF8B949E)),
        bodySmall: TextStyle(fontSize: 12, color: Color(0xFF6E7681)),
        labelLarge: TextStyle(
            fontSize: 14, fontWeight: FontWeight.w600, color: primary),
      ),
    );
  }
}
