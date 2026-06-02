import 'package:flutter/material.dart';

class CoagTheme {
  // --- Primary Brand Colors ---
  static const Color primary = Color(0xFF2196F3); // Material Blue
  static const Color primaryDark = Color(0xFF1565C0);
  static const Color accentCyan = Color(0xFF00BCD4); // Live graph line 1

  // --- Signal Quality Colors ---
  static const Color signalGood = Color(0xFF4CAF50); // Green
  static const Color signalWeak = Color(0xFFFFC107); // Amber
  static const Color signalPoor = Color(0xFFF44336); // Red

  // --- Coagulation Tendency Zone Colors ---
  static const Color hypoZone = Color(0xFF2196F3); // Blue
  static const Color normalZone = Color(0xFF4CAF50); // Green
  static const Color hyperZone = Color(0xFFF44336); // Red

  // --- Legacy Status Colors (kept for compatibility) ---
  static const Color statusNormal = Color(0xFF4CAF50);
  static const Color statusTherapeutic = Color(0xFF2196F3);
  static const Color statusElevated = Color(0xFFFFC107);
  static const Color statusHigh = Color(0xFFF44336);
  static const Color statusCritical = Color(0xFF9C27B0);
  static const Color secondary = Color(0xFF6366F1);

  // --- Dark Theme Colors (matching spec: #0D1B2A / #1A2B3C) ---
  static const Color bgDark = Color(0xFF0D1B2A);
  static const Color surfaceDark = Color(0xFF1A2B3C);
  static const Color cardDark = Color(0xFF243547);
  static const Color textDarkPrimary = Color(0xFFFFFFFF);
  static const Color textDarkSecondary = Color(0xFF8899AA);

  // --- Light Theme Colors ---
  static const Color bgLight = Color(0xFFF8FAFC);
  static const Color surfaceLight = Colors.white;
  static const Color cardLight = Color(0xFFF1F5F9);
  static const Color textLightPrimary = Color(0xFF0F172A);
  static const Color textLightSecondary = Color(0xFF64748B);

  // --- Signal Quality Helper ---
  static Color getSignalColor(String quality) {
    switch (quality) {
      case 'GOOD': return signalGood;
      case 'WEAK': return signalWeak;
      case 'POOR': return signalPoor;
      default: return signalWeak;
    }
  }

  // --- Coag Tendency Helper ---
  static Color getTendencyColor(String tendency) {
    switch (tendency) {
      case 'HYPO': return hypoZone;
      case 'HYPER': return hyperZone;
      default: return normalZone;
    }
  }

  // --- Legacy Status Color ---
  static Color getStatusColor(String status) {
    switch (status) {
      case 'Normal': return statusNormal;
      case 'Therapeutic': return statusTherapeutic;
      case 'Elevated':
      case 'Low': return statusElevated;
      case 'High': return statusHigh;
      case 'Critical': return statusCritical;
      default: return textLightSecondary;
    }
  }

  static const Gradient primaryGradient = LinearGradient(
    colors: [primary, Color(0xFF00BCD4)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static List<BoxShadow> getCardShadow(bool isDark) {
    if (isDark) {
      return [
        BoxShadow(
          color: Colors.black.withOpacity(0.35),
          blurRadius: 12,
          offset: const Offset(0, 4),
        )
      ];
    } else {
      return [
        BoxShadow(
          color: const Color(0xFF0F172A).withOpacity(0.06),
          blurRadius: 15,
          offset: const Offset(0, 8),
        ),
      ];
    }
  }

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: primary,
      scaffoldBackgroundColor: bgLight,
      colorScheme: const ColorScheme.light(
        primary: primary,
        secondary: accentCyan,
        surface: surfaceLight,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: surfaceLight,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: textLightPrimary),
        titleTextStyle: TextStyle(
          color: textLightPrimary,
          fontSize: 18,
          fontWeight: FontWeight.bold,
          fontFamily: 'Roboto',
        ),
      ),
      cardTheme: CardThemeData(
        color: surfaceLight,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFFE2E8F0), width: 1),
        ),
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: primary,
      scaffoldBackgroundColor: bgDark,
      colorScheme: const ColorScheme.dark(
        primary: primary,
        secondary: accentCyan,
        surface: surfaceDark,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: surfaceDark,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: textDarkPrimary),
        titleTextStyle: const TextStyle(
          color: textDarkPrimary,
          fontSize: 18,
          fontWeight: FontWeight.bold,
          fontFamily: 'Roboto',
        ),
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        color: surfaceDark,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.white.withOpacity(0.08), width: 1),
        ),
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(color: textDarkPrimary, fontWeight: FontWeight.bold),
        titleLarge: TextStyle(color: textDarkPrimary, fontWeight: FontWeight.bold),
        bodyLarge: TextStyle(color: textDarkPrimary),
        bodyMedium: TextStyle(color: textDarkSecondary),
      ),
    );
  }
}
