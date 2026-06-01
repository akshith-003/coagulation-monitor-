import 'package:flutter/material.dart';

class CoagTheme {
  // Brand Colors
  static const Color primary = Color(0xFF0EA5E9); // Neon/Electric Blue
  static const Color primaryDark = Color(0xFF0284C7);
  static const Color secondary = Color(0xFF6366F1); // Indigo Accent
  
  // Status Colors
  static const Color statusNormal = Color(0xFF10B981);      // Emerald Green
  static const Color statusTherapeutic = Color(0xFF3B82F6);  // Royal Blue
  static const Color statusElevated = Color(0xFFF59E0B);     // Amber Orange
  static const Color statusHigh = Color(0xFFEF4444);         // Rose Red
  static const Color statusCritical = Color(0xFF8B5CF6);     // Purple/Critical

  // Dark Theme Colors
  static const Color bgDark = Color(0xFF0F172A); // Slate 900
  static const Color surfaceDark = Color(0xFF1E293B); // Slate 800
  static const Color cardDark = Color(0xFF334155); // Slate 700
  static const Color textDarkPrimary = Color(0xFFF8FAFC);
  static const Color textDarkSecondary = Color(0xFF94A3B8);

  // Light Theme Colors
  static const Color bgLight = Color(0xFFF8FAFC);
  static const Color surfaceLight = Colors.white;
  static const Color cardLight = Color(0xFFF1F5F9);
  static const Color textLightPrimary = Color(0xFF0F172A);
  static const Color textLightSecondary = Color(0xFF64748B);

  // Helper to get status color based on string
  static Color getStatusColor(String status) {
    switch (status) {
      case 'Normal':
        return statusNormal;
      case 'Therapeutic':
        return statusTherapeutic;
      case 'Elevated':
      case 'Low':
        return statusElevated;
      case 'High':
        return statusHigh;
      case 'Critical':
        return statusCritical;
      default:
        return textLightSecondary;
    }
  }

  // Linear Gradients for Premium look
  static const Gradient primaryGradient = LinearGradient(
    colors: [primary, secondary],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static Gradient getStatusGradient(String status) {
    Color baseColor = getStatusColor(status);
    return LinearGradient(
      colors: [baseColor, baseColor.withOpacity(0.7)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  }

  // Neumorphic / Glassmorphic shadow style
  static List<BoxShadow> getCardShadow(bool isDark) {
    if (isDark) {
      return [
        BoxShadow(
          color: Colors.black.withOpacity(0.3),
          blurRadius: 10,
          offset: const Offset(0, 4),
        )
      ];
    } else {
      return [
        BoxShadow(
          color: const Color(0xFF0F172A).withOpacity(0.05),
          blurRadius: 15,
          offset: const Offset(0, 8),
        ),
        BoxShadow(
          color: const Color(0xFF0F172A).withOpacity(0.02),
          blurRadius: 5,
          offset: const Offset(0, 2),
        )
      ];
    }
  }

  // Generate ThemeData for Light Mode
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: primary,
      scaffoldBackgroundColor: bgLight,
      colorScheme: const ColorScheme.light(
        primary: primary,
        secondary: secondary,
        background: bgLight,
        surface: surfaceLight,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: surfaceLight,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: textLightPrimary),
        titleTextStyle: TextStyle(
          color: textLightPrimary,
          fontSize: 20,
          fontWeight: FontWeight.bold,
          fontFamily: 'Roboto',
        ),
      ),
      cardTheme: CardThemeData(
        color: surfaceLight,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFFE2E8F0), width: 1),
        ),
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(color: textLightPrimary, fontWeight: FontWeight.bold),
        titleLarge: TextStyle(color: textLightPrimary, fontWeight: FontWeight.bold),
        bodyLarge: TextStyle(color: textLightPrimary),
        bodyMedium: TextStyle(color: textLightSecondary),
      ),
    );
  }

  // Generate ThemeData for Dark Mode
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: primary,
      scaffoldBackgroundColor: bgDark,
      colorScheme: const ColorScheme.dark(
        primary: primary,
        secondary: secondary,
        background: bgDark,
        surface: surfaceDark,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: surfaceDark,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: textDarkPrimary),
        titleTextStyle: TextStyle(
          color: textDarkPrimary,
          fontSize: 20,
          fontWeight: FontWeight.bold,
          fontFamily: 'Roboto',
        ),
      ),
      cardTheme: CardThemeData(
        color: surfaceDark,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
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
