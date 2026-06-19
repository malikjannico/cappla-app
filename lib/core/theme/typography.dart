import 'package:flutter/material.dart';

final appTextTheme = const TextTheme(
  displayLarge: TextStyle(
    fontFamily: 'Figtree',
    fontWeight: FontWeight.w400,
    fontSize: 57,
    height: 64 / 57,
    letterSpacing: -0.228, // -0.4%
  ),
  displayMedium: TextStyle(
    fontFamily: 'Figtree',
    fontWeight: FontWeight.w400,
    fontSize: 45,
    height: 52 / 45,
    letterSpacing: 0,
  ),
  displaySmall: TextStyle(
    fontFamily: 'Figtree',
    fontWeight: FontWeight.w400,
    fontSize: 36,
    height: 44 / 36,
    letterSpacing: 0,
  ),
  headlineLarge: TextStyle(
    fontFamily: 'Figtree',
    fontWeight: FontWeight.w400,
    fontSize: 32,
    height: 40 / 32,
    letterSpacing: 0,
  ),
  headlineMedium: TextStyle(
    fontFamily: 'Figtree',
    fontWeight: FontWeight.w400,
    fontSize: 28,
    height: 36 / 28,
    letterSpacing: 0,
  ),
  headlineSmall: TextStyle(
    fontFamily: 'Figtree',
    fontWeight: FontWeight.w400,
    fontSize: 24,
    height: 32 / 24,
    letterSpacing: 0,
  ),
  titleLarge: TextStyle(
    fontFamily: 'Figtree',
    fontWeight: FontWeight.w400,
    fontSize: 22,
    height: 28 / 22,
    letterSpacing: 0,
  ),
  titleMedium: TextStyle(
    fontFamily: 'Figtree',
    fontWeight: FontWeight.w500,
    fontSize: 16,
    height: 24 / 16,
    letterSpacing: 0.144, // 0.9%
  ),
  titleSmall: TextStyle(
    fontFamily: 'Figtree',
    fontWeight: FontWeight.w500,
    fontSize: 14,
    height: 20 / 14,
    letterSpacing: 0.098, // 0.7%
  ),
  bodyLarge: TextStyle(
    fontFamily: 'Figtree',
    fontWeight: FontWeight.w400,
    fontSize: 16,
    height: 24 / 16,
    letterSpacing: 0.496, // 3.1%
  ),
  bodyMedium: TextStyle(
    fontFamily: 'Figtree',
    fontWeight: FontWeight.w400,
    fontSize: 14,
    height: 20 / 14,
    letterSpacing: 0.252, // 1.8%
  ),
  bodySmall: TextStyle(
    fontFamily: 'Figtree',
    fontWeight: FontWeight.w400,
    fontSize: 12,
    height: 16 / 12,
    letterSpacing: 0.396, // 3.3%
  ),
  labelLarge: TextStyle(
    fontFamily: 'Figtree',
    fontWeight: FontWeight.w500,
    fontSize: 14,
    height: 20 / 14,
    letterSpacing: 0.098, // 0.7%
  ),
  labelMedium: TextStyle(
    fontFamily: 'Figtree',
    fontWeight: FontWeight.w500,
    fontSize: 12,
    height: 16 / 12,
    letterSpacing: 0.504, // 4.2%
  ),
  labelSmall: TextStyle(
    fontFamily: 'Figtree',
    fontWeight: FontWeight.w500,
    fontSize: 11,
    height: 16 / 11,
    letterSpacing: 0.495, // 4.5%
  ),
);

// Emphasized Styles mapping to Roboto Font (w500 for displays/headlines/bodies, w600 for label/title)
class AppEmphasizedTypography {
  static const displayLarge = TextStyle(
    fontFamily: 'Roboto',
    fontWeight: FontWeight.w500,
    fontSize: 57,
    height: 64 / 57,
    letterSpacing: -0.228,
  );
  static const displayMedium = TextStyle(
    fontFamily: 'Roboto',
    fontWeight: FontWeight.w500,
    fontSize: 45,
    height: 52 / 45,
    letterSpacing: 0,
  );
  static const displaySmall = TextStyle(
    fontFamily: 'Roboto',
    fontWeight: FontWeight.w500,
    fontSize: 36,
    height: 44 / 36,
    letterSpacing: 0,
  );
  static const headlineLarge = TextStyle(
    fontFamily: 'Roboto',
    fontWeight: FontWeight.w500,
    fontSize: 32,
    height: 40 / 32,
    letterSpacing: 0,
  );
  static const headlineMedium = TextStyle(
    fontFamily: 'Roboto',
    fontWeight: FontWeight.w500,
    fontSize: 28,
    height: 36 / 28,
    letterSpacing: 0,
  );
  static const headlineSmall = TextStyle(
    fontFamily: 'Roboto',
    fontWeight: FontWeight.w500,
    fontSize: 24,
    height: 32 / 24,
    letterSpacing: 0,
  );
  static const titleLarge = TextStyle(
    fontFamily: 'Roboto',
    fontWeight: FontWeight.w500,
    fontSize: 22,
    height: 28 / 22,
    letterSpacing: 0,
  );
  static const titleMedium = TextStyle(
    fontFamily: 'Roboto',
    fontWeight: FontWeight.w600,
    fontSize: 16,
    height: 24 / 16,
    letterSpacing: 0.144,
  );
  static const titleSmall = TextStyle(
    fontFamily: 'Roboto',
    fontWeight: FontWeight.w600,
    fontSize: 14,
    height: 20 / 14,
    letterSpacing: 0.098,
  );
  static const bodyLarge = TextStyle(
    fontFamily: 'Roboto',
    fontWeight: FontWeight.w500,
    fontSize: 16,
    height: 24 / 16,
    letterSpacing: 0.496,
  );
  static const bodyMedium = TextStyle(
    fontFamily: 'Roboto',
    fontWeight: FontWeight.w500,
    fontSize: 14,
    height: 20 / 14,
    letterSpacing: 0.252,
  );
  static const bodySmall = TextStyle(
    fontFamily: 'Roboto',
    fontWeight: FontWeight.w500,
    fontSize: 12,
    height: 16 / 12,
    letterSpacing: 0.396,
  );
  static const labelLarge = TextStyle(
    fontFamily: 'Roboto',
    fontWeight: FontWeight.w600,
    fontSize: 14,
    height: 20 / 14,
    letterSpacing: 0.098,
  );
  static const labelMedium = TextStyle(
    fontFamily: 'Roboto',
    fontWeight: FontWeight.w600,
    fontSize: 12,
    height: 16 / 12,
    letterSpacing: 0.504,
  );
  static const labelSmall = TextStyle(
    fontFamily: 'Roboto',
    fontWeight: FontWeight.w600,
    fontSize: 11,
    height: 16 / 11,
    letterSpacing: 0.495,
  );
}
