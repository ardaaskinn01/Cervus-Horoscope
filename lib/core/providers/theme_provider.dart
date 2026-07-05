import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:horoscope/core/constants/app_text_styles.dart';

class ThemeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    AppTextStyles.isDark = true;
    return ThemeMode.dark;
  }

  Future<void> changeThemeMode(ThemeMode mode) async {
    state = ThemeMode.dark;
    AppTextStyles.isDark = true;
  }
}

final themeProvider = NotifierProvider<ThemeNotifier, ThemeMode>(() {
  return ThemeNotifier();
});
