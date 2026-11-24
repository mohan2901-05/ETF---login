import 'package:flutter/material.dart';

class ThemeConfig {
  // ETF Loans palette from the website (https://etf-loans.vercel.app/)
  // Verified from CSS :root tokens
  static const Color paperBg = Color(0xFFF3F8F3);          // --paper
  static const Color cardBg = Color(0xFFFFFFFF);           // --card
  static const Color tintGreen = Color(0xFFE6F4E9);        // --tint
  static const Color limeTint = Color(0xFFEFF8DE);         // --lime-tint
  static const Color ruleLight = Color(0xFFE0EAE2);        // --rule
  static const Color ruleStrong = Color(0xFFC3D3C8);       // --rule-strong
  static const Color ink = Color(0xFF0A2E1B);              // --ink / --green-deep
  static const Color bodyText = Color(0xFF334E41);         // --body
  static const Color mutedText = Color(0xFF5B7268);        // --muted
  static const Color primaryGreen = Color(0xFF15803F);     // --green
  static const Color primaryGreenMid = Color(0xFF12522F);  // --green-mid
  static const Color primaryGreenDeep = Color(0xFF0A2E1B); // --green-deep
  static const Color onDeep = Color(0xFFF1F9F3);           // --on-deep
  static const Color onDeepMuted = Color(0xFFA9CFB6);      // --on-deep-muted
  static const Color accentLime = Color(0xFF7AC70C);       // --lime
  static const Color warnAmber = Color(0xFFA86400);        // --warn
  static const Color errorRed = Color(0xFFC0392B);         // --bad

  // Radii (verified from CSS)
  static const double radiusBase = 14;       // --r
  static const double radiusLarge = 20;      // --r-lg
  static const double radiusButton = 16;     // button override
  static const double radiusPill = 999;      // pills
  static const double radiusTile = 16;       // OTP tiles

  // Shadows (verified from CSS)
  static const List<BoxShadow> shadowBase = [
    BoxShadow(color: Color(0x0D0A2E1B), offset: Offset(0, 1), blurRadius: 2),
    BoxShadow(color: Color(0x380A2E1B), offset: Offset(0, 10), blurRadius: 24, spreadRadius: -14),
  ];
  static const List<BoxShadow> shadowTile = [
    BoxShadow(color: Color(0x0F0A2E1B), offset: Offset(0, 1), blurRadius: 2),
    BoxShadow(color: Color(0x590A2E1B), offset: Offset(0, 10), blurRadius: 22, spreadRadius: -14),
  ];
  static const List<BoxShadow> shadowButtonPrimary = [
    BoxShadow(color: Color(0xE615803F), offset: Offset(0, 10), blurRadius: 20, spreadRadius: -12),
  ];

  // Sizing (verified from CSS)
  static const double buttonHeight = 54;
  static const double inputHeight = 54;
  static const double buttonFontSize = 16;
  static const double inputFontSize = 16;
  static const FontWeight buttonFontWeight = FontWeight.w700;
  static const String headingFontFamily = 'Plus Jakarta Sans';
  static const String bodyFontFamily = 'DM Sans';
  static const String technicalFontFamily = 'JetBrains Mono';

  // Hero gradients (verified from CSS)
  static const heroGradientMobile = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF15703B), Color(0xFF0F3D24), Color(0xFF0A2E1B)],
    stops: [0, 0.45, 1],
  );

  static const heroGradientDesktop = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF12522F), Color(0xFF0A2E1B), Color(0xFF061E12)],
    stops: [0, 0.55, 1],
  );

  // Iridescent background for OTP screen (verified from CSS)
  static const iridescentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFBDF0D6),
      Color(0xFFD9F7B5),
      Color(0xFFB9E8F5),
      Color(0xFFDCD6FB),
      Color(0xFFFDE0CF),
      Color(0xFFC8F3E0),
      Color(0xFFBDF0D6),
    ],
    stops: [0, 0.16, 0.33, 0.5, 0.66, 0.83, 1],
  );

  static const sheenGradient = LinearGradient(
    begin: Alignment(-0.42, -0.91), // ~115deg
    end: Alignment(0.42, 0.91),
    colors: [
      Colors.transparent,
      Color(0x8CFFFFFF), // 55%
      Colors.transparent,
      Color(0x59FFFFFF), // 35%
      Colors.transparent,
    ],
    stops: [0, 0.2, 0.32, 0.58, 0.7],
  );

  static const radialHighlight = RadialGradient(
    center: Alignment(0, -0.4), // 50% 30%
    radius: 0.8,
    colors: [
      Color(0x33FFFFFF),
      Colors.transparent,
    ],
    stops: [0, 1],
  );

  // Light Theme
  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    fontFamily: bodyFontFamily,
    brightness: Brightness.light,
    colorScheme: ColorScheme.light(
      surface: cardBg,
      primary: primaryGreenDeep,
      onPrimary: cardBg,
      secondary: primaryGreen,
      onSecondary: cardBg,
      error: errorRed,
      onError: cardBg,
      outline: ruleStrong,
    ),
    scaffoldBackgroundColor: paperBg,
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: ink,
      elevation: 0,
      centerTitle: false,
      surfaceTintColor: Colors.transparent,
    ),
    cardTheme: CardThemeData(
      color: cardBg,
      elevation: 0,
      shadowColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radiusLarge),
        side: BorderSide(color: ruleLight),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryGreen,
        foregroundColor: onDeep,
        elevation: 0,
        shadowColor: shadowButtonPrimary.first.color,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusButton),
        ),
        minimumSize: Size(double.infinity, buttonHeight),
        padding: EdgeInsets.symmetric(horizontal: 16),
        textStyle: TextStyle(
          fontFamily: headingFontFamily,
          fontSize: buttonFontSize,
          fontWeight: buttonFontWeight,
          fontVariations: [FontVariation.weight(700)],
          letterSpacing: -0.16,
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: primaryGreen,
        textStyle: TextStyle(
          fontFamily: bodyFontFamily,
          fontSize: 14,
          fontWeight: FontWeight.w500,
          decoration: TextDecoration.underline,
          decorationColor: primaryGreen,
          decorationThickness: 2,
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: cardBg,
      contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 0),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusBase),
        borderSide: BorderSide(color: ruleStrong, width: 1.5),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusBase),
        borderSide: BorderSide(color: ruleStrong, width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusBase),
        borderSide: BorderSide(color: primaryGreen, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusBase),
        borderSide: BorderSide(color: errorRed, width: 2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusBase),
        borderSide: BorderSide(color: errorRed, width: 2),
      ),
      hintStyle: TextStyle(
        fontFamily: bodyFontFamily,
        fontSize: inputFontSize,
        color: Color(0xFF9AA39B),
      ),
      labelStyle: TextStyle(
        fontFamily: bodyFontFamily,
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: ink,
      ),
      errorStyle: TextStyle(
        fontFamily: bodyFontFamily,
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: errorRed,
      ),
      floatingLabelBehavior: FloatingLabelBehavior.always,
    ),
    textTheme: TextTheme(
      displayLarge: TextStyle(
        fontFamily: headingFontFamily,
        fontSize: 36,
        fontWeight: FontWeight.w700,
        fontVariations: [FontVariation.weight(700)],
        color: ink,
        letterSpacing: -0.36,
        height: 1.1,
      ),
      displayMedium: TextStyle(
        fontFamily: headingFontFamily,
        fontSize: 30,
        fontWeight: FontWeight.w800,
        fontVariations: [FontVariation.weight(800)],
        color: ink,
        letterSpacing: -0.3,
        height: 1.1,
      ),
      titleLarge: TextStyle(
        fontFamily: headingFontFamily,
        fontSize: 27,
        fontWeight: FontWeight.w700,
        fontVariations: [FontVariation.weight(700)],
        color: ink,
        letterSpacing: -0.27,
        height: 1.15,
      ),
      bodyLarge: TextStyle(
        fontFamily: bodyFontFamily,
        fontSize: 15,
        fontWeight: FontWeight.w400,
        color: bodyText,
        height: 1.5,
      ),
      bodyMedium: TextStyle(
        fontFamily: bodyFontFamily,
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: mutedText,
        height: 1.45,
      ),
      labelLarge: TextStyle(
        fontFamily: bodyFontFamily,
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: ink,
      ),
      labelMedium: TextStyle(
        fontFamily: bodyFontFamily,
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: mutedText,
        height: 1.4,
      ),
      labelSmall: TextStyle(
        fontFamily: bodyFontFamily,
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: mutedText,
        height: 1.5,
      ),
    ),
  );

  // Dark Theme (kept for completeness, not used in login flow)
  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: ColorScheme.dark(
      surface: Color(0xFF2D4A3A),
      primary: primaryGreenDeep,
      onPrimary: cardBg,
      secondary: primaryGreen,
      onSecondary: cardBg,
      error: errorRed,
      onError: cardBg,
      outline: ruleStrong,
    ),
    scaffoldBackgroundColor: Color(0xFF1A3A25),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: onDeep,
      elevation: 0,
      centerTitle: false,
      surfaceTintColor: Colors.transparent,
    ),
    cardTheme: CardThemeData(
      color: Color(0xFF2D4A3A),
      elevation: 0,
      shadowColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radiusLarge),
      ),
    ),
  );
}