// 파일 경로: lib/core/theme/app_theme.dart
import 'package:flutter/material.dart';

class AppTheme {
  // 'unnecessary_const' lint에 따라 Color 생성자 앞의 const 제거
  static const Color decathlonBlue = Color(0xFF007DBC);
  static const Color decathlonDarkBlue = Color(0xFF003E7E);
  static const Color decathlonActionBlue = Color(0xFF00A9E0);

  static const Color textPrimaryLight = Color(0xFF1D1D1F);
  static const Color textSecondaryLight = Color(0xFF3A3A3C);

  static const Color textPrimaryDark = Color(0xFFE1E1E6);
  static const Color textSecondaryDark = Color(0xFF8E8E93);

  static const Color backgroundLight = Color(0xFFF9F9F9);
  static const Color surfaceLight = Colors.white; // Colors.white는 이미 const

  static const Color backgroundDark = Color(0xFF121212);
  static const Color surfaceDark = Color(0xFF1E1E1E);

  // ThemeData 타입의 lightTheme, darkTheme은 _buildTheme 함수 결과로 초기화되므로
  // const가 될 수 없고 static final이 올바른 선언입니다.
  // 이전 flutter analyze 결과의 prefer_const_declarations (line 23,24,29)는
  // 위의 Color 정의들이 const Color()가 아닌 Color()로 수정되면서 자연스럽게 해결될 것입니다.
  // (static const Color ... = Color(...); 형태는 Color(...)가 const 표현식으로 간주됨)

  static ThemeData _buildTheme({required Brightness brightness}) {
    final bool isDark = brightness == Brightness.dark;
    final Color primaryColor = decathlonBlue;
    final Color secondaryColor = decathlonActionBlue;
    final Color backgroundColor = isDark ? backgroundDark : backgroundLight;
    final Color surfaceColor = isDark ? surfaceDark : surfaceLight;
    final Color textColorPrimary = isDark ? textPrimaryDark : textPrimaryLight;
    final Color textColorSecondary = isDark ? textSecondaryDark : textSecondaryLight;
    final Color onPrimaryColor = Colors.white;
    final Color cardColor = isDark ? const Color(0xFF2C2C2E) : Colors.white;

    return ThemeData(
      brightness: brightness,
      primaryColor: primaryColor,
      scaffoldBackgroundColor: backgroundColor,
      appBarTheme: AppBarTheme(
        backgroundColor: isDark ? surfaceDark : primaryColor,
        elevation: isDark ? 0 : 1,
        iconTheme: IconThemeData(color: isDark ? textColorPrimary : onPrimaryColor),
        titleTextStyle: TextStyle(
          color: isDark ? textColorPrimary : onPrimaryColor,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
      ),
      cardTheme: CardTheme(
        elevation: isDark ? 1 : 2,
        color: surfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: secondaryColor,
          foregroundColor: onPrimaryColor,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cardColor,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: secondaryColor, width: 2),
        ),
        hintStyle: TextStyle(color: textColorSecondary.withAlpha((255 * 0.7).round())),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: secondaryColor),
      ),
      iconButtonTheme: IconButtonThemeData(
          style: IconButton.styleFrom(foregroundColor: secondaryColor)
      ),
      textTheme: TextTheme(
        displayLarge: TextStyle(color: textColorPrimary, fontWeight: FontWeight.bold, fontSize: 28),
        displayMedium: TextStyle(color: textColorPrimary, fontWeight: FontWeight.bold, fontSize: 24),
        headlineMedium: TextStyle(color: textColorPrimary, fontWeight: FontWeight.w600, fontSize: 20),
        titleLarge: TextStyle(color: textColorPrimary, fontWeight: FontWeight.w500, fontSize: 18),
        bodyLarge: TextStyle(color: textColorPrimary, fontSize: 16, height: 1.5),
        bodyMedium: TextStyle(color: textColorSecondary, fontSize: 14, height: 1.4),
        labelLarge: TextStyle(color: onPrimaryColor, fontWeight: FontWeight.w500, fontSize: 16),
      ).apply(
        displayColor: textColorPrimary,
        bodyColor: textColorPrimary,
      ),
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        brightness: brightness,
        primary: primaryColor,
        secondary: secondaryColor,
        surface: surfaceColor,
        error: Colors.redAccent,
        onPrimary: onPrimaryColor,
        onSecondary: onPrimaryColor,
        onSurface: textColorPrimary,
        onError: onPrimaryColor,
      ).copyWith(
        surfaceTint: Colors.transparent,
      ),
      dialogTheme: DialogTheme(
        backgroundColor: surfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  static final ThemeData lightTheme = _buildTheme(brightness: Brightness.light);
  static final ThemeData darkTheme = _buildTheme(brightness: Brightness.dark);
}