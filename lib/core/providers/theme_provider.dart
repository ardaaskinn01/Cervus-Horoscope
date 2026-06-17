import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:horoscope/core/constants/app_text_styles.dart';

class ThemeNotifier extends Notifier<ThemeMode> {
  static const String _prefKey = 'theme_mode';

  @override
  ThemeMode build() {
    _loadTheme();
    return ThemeMode.dark; // Varsayılan karanlık tema
  }

  // SharedPreferences'tan kaydedilen temayı yükle
  Future<void> _loadTheme() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final modeString = prefs.getString(_prefKey);
      if (modeString != null) {
        final mode = ThemeMode.values.firstWhere(
          (e) => e.toString() == modeString,
          orElse: () => ThemeMode.dark,
        );
        state = mode;
        AppTextStyles.isDark = mode == ThemeMode.dark;
      }
    } catch (_) {}
  }

  // Temayı değiştir ve kaydet
  Future<void> changeThemeMode(ThemeMode mode) async {
    state = mode;
    AppTextStyles.isDark = mode == ThemeMode.dark;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKey, mode.toString());
    } catch (_) {}
  }
}

final themeProvider = NotifierProvider<ThemeNotifier, ThemeMode>(() {
  return ThemeNotifier();
});
