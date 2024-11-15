import 'package:flutter/material.dart';

class AppTheme {
  static const Color themePurple = Color(0XFF6C63FF);
  static const Color themePink = Color(0xFFC83DA4);
  static const Color themeGray = Color(0xFF4F4F4f);
  static const Color themeRed = Color(0xFFE33629);
  static const Color themeGreen = Color(0xFF319F43);
  static const Color themeYellow = Color(0XFFF88D00);
  static const Color themeBlue = Color(0xFF587D8D);
  static const Color themeWhite = Color(0xFFFFFFFF);
  static const Color themeSecondaryGray = Color(0xFFE6E6E6);
  static const Color themePlaceHolderText = Color(0xFF838EA1);

  static const borderPadding = 28.0;

  static final ThemeData lightTheme = ThemeData(
    primaryColor: themePurple,
    hintColor: themePink,
  );
}
