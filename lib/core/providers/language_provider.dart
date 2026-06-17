import 'dart:ui';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

class LanguageNotifier extends Notifier<Locale> {
  static const String _prefKey = 'locale_code';

  @override
  Locale build() {
    _loadLocale();
    return const Locale('tr'); // Varsayılan dil Türkçe
  }

  // SharedPreferences'tan kaydedilen dili yükle
  Future<void> _loadLocale() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final code = prefs.getString(_prefKey);
      if (code != null) {
        final newLocale = Locale(code);
        state = newLocale;
        Intl.defaultLocale = code;
      } else {
        Intl.defaultLocale = 'tr';
      }
    } catch (e) {
      // Hata durumunda varsayılan tr kalır
      Intl.defaultLocale = 'tr';
    }
  }

  // Dili değiştir ve kaydet
  Future<void> changeLanguage(String languageCode) async {
    final newLocale = Locale(languageCode);
    state = newLocale;
    Intl.defaultLocale = languageCode;
    
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKey, languageCode);
    } catch (_) {
      // SharedPreferences yazma hatası yutulabilir
    }
  }
}

final languageProvider = NotifierProvider<LanguageNotifier, Locale>(() {
  return LanguageNotifier();
});
