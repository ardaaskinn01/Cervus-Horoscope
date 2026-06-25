import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:horoscope/core/providers/language_provider.dart';

class AppStrings {
  AppStrings._();

  static const Map<String, Map<String, String>> _localizedValues = {
    'tr': {
      'app_title': 'Mistik Burçlar',
      'welcome_title': 'Gökyüzü Bugün Seninle Konuşuyor...',
      'welcome_subtitle': 'Burcunuzu seçin ve evrenin size özel bugünkü enerjilerini keşfedin.',
      'daily_scores': 'Bugünkü Enerji Puanları',
      'love': 'Aşk',
      'money': 'Para',
      'career': 'Kariyer',
      'energy': 'Enerji',
      'daily_comment_title': 'Günlük Kozmik Yorum',
      'analyze_chart': 'Yıldız Haritasını Analiz Et',
      'zodiac_list_title': 'Burçlar',
      'sample_comment': 'Bugün gökyüzü, hayata karşı hissettiğiniz heyecan ve tutkunun ön planda olacağını gösteriyor. Yıldız haritanızda beliren etkiler sayesinde, çevrenizdekilerle kurduğunuz derin bağlar daha da güçlenecek. Finansal olarak dengede durmalı, kariyer fırsatları için sakin ama cesur adımlar atmalısınız.',
      'chart_updated': 'Yıldız haritanız başarıyla güncellendi!',
      'language_select': 'Dil Seçimi',
      // Onboarding
      'onboarding_name_hint': 'İsminiz',
      'onboarding_next': 'Devam Et',
      'onboarding_gender_male': 'Erkek',
      'onboarding_gender_female': 'Kadın',
      // Tools
      'tools_title': 'Astroloji Araçları',
      // Settings
      'settings_title': 'Ayarlar',
      // Version Update Check
      'update_new_version_title': 'Yeni Sürüm Mevcut',
      'update_new_version_desc': 'Uygulamamızı daha stabil ve yeni özelliklerle kullanabilmek için lütfen güncelleyin.',
      'update_btn_later': 'Daha Sonra',
      'update_btn_confirm': 'Güncelle',
    },
    'en': {
      'app_title': 'Mystic Horoscope',
      'welcome_title': 'The Sky Speaks with You Today...',
      'welcome_subtitle': 'Select your zodiac sign and discover the universe\'s special energies for you today.',
      'daily_scores': 'Today\'s Energy Scores',
      'love': 'Love',
      'money': 'Money',
      'career': 'Career',
      'energy': 'Energy',
      'daily_comment_title': 'Daily Cosmic Commentary',
      'analyze_chart': 'Analyze Natal Chart',
      'zodiac_list_title': 'Zodiac Signs',
      'sample_comment': 'Today the sky indicates that your excitement and passion for life will be at the forefront. Thanks to the influences appearing in your natal chart, the deep bonds you establish with those around you will become even stronger. You should stay balanced financially and take calm but brave steps for career opportunities.',
      'chart_updated': 'Your natal chart has been successfully updated!',
      'language_select': 'Language Selection',
      // Onboarding
      'onboarding_name_hint': 'Your Name',
      'onboarding_next': 'Continue',
      'onboarding_gender_male': 'Male',
      'onboarding_gender_female': 'Female',
      // Tools
      'tools_title': 'Astrology Tools',
      // Settings
      'settings_title': 'Settings',
      // Version Update Check
      'update_new_version_title': 'New Version Available',
      'update_new_version_desc': 'Please update our app to the latest version to enjoy new features and improvements.',
      'update_btn_later': 'Later',
      'update_btn_confirm': 'Update',
    },
  };

  static String get(String key, String localeCode) {
    return _localizedValues[localeCode]?[key] ?? key;
  }
}

// BuildContext üzerinden doğrudan çeviriye erişebilmek için extension
extension AppLocalizations on BuildContext {
  String translate(String key) {
    // Riverpod context read ile mevcut locale'i çekiyoruz
    final container = ProviderScope.containerOf(this, listen: false);
    final locale = container.read(languageProvider);
    return AppStrings.get(key, locale.languageCode);
  }
}
