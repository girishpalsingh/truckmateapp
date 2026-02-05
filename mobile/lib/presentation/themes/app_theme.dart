import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// TruckMate App Theme - Bright, action-oriented design for truck drivers
class AppTheme {
  static const Color primaryColor = Color(0xFF2563EB); // Vivid Blue
  static const Color secondaryColor = Color(0xFF0EA5E9); // Sky Blue
  static const Color accentColor = Color(0xFFF59E0B); // Amber
  static const Color successColor = Color(0xFF10B981); // Emerald
  static const Color warningColor = Color(0xFFF97316); // Orange
  static const Color errorColor = Color(0xFFEF4444); // Red
  static const Color surfaceColor = Color(0xFFF1F5F9); // Slightly cooler gray
  static const Color cardColor = Colors.white;
  static const Color textPrimary = Color(0xFF0F172A); // Darker blue-gray
  static const Color textSecondary = Color(0xFF475569);
  static const Color textSubtitle = Color(0xFF94A3B8);

  // Modern Gradients - "Liquid" feel
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF2563EB), Color(0xFF3B82F6)], // Blue to lighter blue
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient accentGradient = LinearGradient(
    colors: [Color(0xFFF59E0B), Color(0xFFFBBF24)], // Amber to yellow-amber
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient glassGradient = LinearGradient(
    colors: [
      Color(0x99FFFFFF), // White 60%
      Color(0x4DFFFFFF), // White 30%
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    stops: [0.1, 1.0],
  );

  static const LinearGradient darkGlassGradient = LinearGradient(
    colors: [
      Color(0xCC1E293B), // Dark Blue-Gray 80%
      Color(0x991E293B), // Dark Blue-Gray 60%
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.light(
        primary: primaryColor,
        secondary: secondaryColor,
        tertiary: accentColor,
        surface: surfaceColor,
        error: errorColor,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: textPrimary,
        onError: Colors.white,
      ),
      scaffoldBackgroundColor: surfaceColor,
      cardColor: cardColor,
      textTheme: GoogleFonts.interTextTheme().copyWith(
        displayLarge: GoogleFonts.inter(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: textPrimary,
        ),
        displayMedium: GoogleFonts.inter(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: textPrimary,
        ),
        headlineLarge: GoogleFonts.inter(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        headlineMedium: GoogleFonts.inter(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        titleLarge: GoogleFonts.inter(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        titleMedium: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: textPrimary,
        ),
        bodyLarge: GoogleFonts.inter(fontSize: 16, color: textPrimary),
        bodyMedium: GoogleFonts.inter(fontSize: 14, color: textSecondary),
        bodySmall: GoogleFonts.inter(fontSize: 12, color: textSubtitle),
        labelLarge: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryColor,
          side: const BorderSide(color: primaryColor, width: 2),
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
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
          borderSide: const BorderSide(color: primaryColor, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: errorColor),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        labelStyle: GoogleFonts.inter(color: textSecondary),
        hintStyle: GoogleFonts.inter(color: textSubtitle),
      ),
      cardTheme: CardThemeData(
        color: cardColor,
        elevation: 2,
        shadowColor: Colors.black.withOpacity(0.1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: accentColor,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: primaryColor,
        unselectedItemColor: textSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
    );
  }

  // Large action button style for main dashboard actions
  static ButtonStyle get actionButtonStyle => ElevatedButton.styleFrom(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        minimumSize: const Size(double.infinity, 80),
        padding: const EdgeInsets.all(20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        elevation: 4,
      );

  // Accent action button
  static ButtonStyle get accentButtonStyle => ElevatedButton.styleFrom(
        backgroundColor: accentColor,
        foregroundColor: Colors.white,
        minimumSize: const Size(double.infinity, 80),
        padding: const EdgeInsets.all(20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        elevation: 4,
      );

  // Success button
  static ButtonStyle get successButtonStyle => ElevatedButton.styleFrom(
        backgroundColor: successColor,
        foregroundColor: Colors.white,
        minimumSize: const Size(double.infinity, 60),
        padding: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 3,
      );
  // Button text styles
  static TextStyle get buttonSubtitleStyle => GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: Colors.white.withOpacity(0.9),
      );
}

/// Widget for displaying dual-language text (English primary, Punjabi subtitle)
class DualLanguageText extends StatelessWidget {
  final String primaryText;
  final String? subtitleText;
  final TextStyle? primaryStyle;
  final TextStyle? subtitleStyle;
  final TextAlign? textAlign;
  final CrossAxisAlignment alignment;

  const DualLanguageText({
    super.key,
    required this.primaryText,
    this.subtitleText,
    this.primaryStyle,
    this.subtitleStyle,
    this.textAlign,
    this.alignment = CrossAxisAlignment.start,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (subtitleText == null || subtitleText!.isEmpty) {
      return Text(
        primaryText,
        style: primaryStyle ?? theme.textTheme.bodyLarge,
        textAlign: textAlign,
      );
    }

    return Column(
      crossAxisAlignment: alignment,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          primaryText,
          style: primaryStyle ?? theme.textTheme.bodyLarge,
          textAlign: textAlign,
        ),
        const SizedBox(height: 2),
        Text(
          subtitleText!,
          style: subtitleStyle ??
              theme.textTheme.bodySmall?.copyWith(
                color: AppTheme.textSubtitle,
                fontSize: 11,
              ),
          textAlign: textAlign,
        ),
      ],
    );
  }
}
