import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:intl/intl.dart';
import 'package:horoscope/core/models/user_model.dart';
import 'package:horoscope/core/services/firebase_service.dart';
import 'package:horoscope/core/services/dashboard_service.dart';
import 'package:horoscope/core/providers/language_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:horoscope/core/utils/astrology_utils.dart';
import 'package:horoscope/core/services/revenuecat_service.dart';

class UserNotifier extends Notifier<UserModel?> {
  final FirebaseService _firebaseService = FirebaseService();
  final DashboardService _dashboardService = DashboardService();

  @override
  UserModel? build() {
    return null;
  }

  // Çevrimdışı önbellekten kullanıcı yükle
  Future<void> _loadCachedProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheStr = prefs.getString('cached_user_profile');
      if (cacheStr != null) {
        final Map<String, dynamic> map = jsonDecode(cacheStr);
        state = UserModel.fromMap(map);
        debugPrint('ℹ️ Çevrimdışı kullanıcı profili SharedPreferences\'tan yüklendi: ${state?.name}');
      } else {
        // İlk açılışta veya cache boşsa geçici offline profil ata
        final locale = ref.read(languageProvider);
        state = UserModel(
          uid: 'offline_anonymous',
          createdAt: DateTime.now(),
          localeCode: locale.languageCode,
        );
      }
    } catch (e) {
      debugPrint('⚠️ Çevrimdışı profil yüklenirken hata oluştu: $e');
    }
  }

  // Kullanıcıyı Firebase ve Dashboard ile başlat
  Future<void> initializeUser() async {
    try {
      final user = await _firebaseService.signInAnonymously();
      if (user == null) {
        debugPrint('⚠️ Kullanıcı oturumu açılamadı. Çevrimdışı moda geçiliyor.');
        await _loadCachedProfile();
        return;
      }

      final uid = user.uid;
      UserModel? profile;
      try {
        profile = await _firebaseService.getUserProfile(uid);
      } catch (e) {
        debugPrint('⚠️ Firestore kullanıcı profili okunamadı: $e');
      }

      final currentLocale = ref.read(languageProvider);

      if (profile == null) {
        // Önce yerel önbellekte kayıtlı profil var mı kontrol et
        try {
          final prefs = await SharedPreferences.getInstance();
          final cacheStr = prefs.getString('cached_user_profile');
          if (cacheStr != null) {
            final Map<String, dynamic> map = jsonDecode(cacheStr);
            profile = UserModel.fromMap(map);
            debugPrint('ℹ️ Firestore\'da bulunamadı, yerel önbellekteki profil kullanılacak: ${profile.name}');
          }
        } catch (_) {}
      }

      if (profile == null) {
        // Yerelde de yoksa sıfırdan oluştur
        profile = UserModel(
          uid: uid,
          localeCode: currentLocale.languageCode,
          createdAt: DateTime.now(),
        );
        try {
          await _firebaseService.saveUserProfile(profile);
        } catch (_) {}
      } else {
        // Eğer cihazda dil değiştiyse Firestore'u güncelle
        if (profile.localeCode != currentLocale.languageCode) {
          profile = profile.copyWith(localeCode: currentLocale.languageCode);
          try {
            await _firebaseService.saveUserProfile(profile);
          } catch (_) {}
        }
      }

      // RevenueCat premium durumunu kontrol et
      final isRcPremium = await RevenueCatService.checkPremiumStatus();
      if (profile.isPremium != isRcPremium) {
        profile = profile.copyWith(isPremium: isRcPremium);
        try {
          await _firebaseService.saveUserProfile(profile);
        } catch (_) {}
      }

      state = profile;

      // Önbelleği güncelle
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('cached_user_profile', jsonEncode(profile.toJson()));
      } catch (_) {}

      // Dashboard Ziyaret Kaydı & Süre Takibi
      final packageInfo = await PackageInfo.fromPlatform();
      final String appVersion = packageInfo.version;
      final String platform = Platform.isIOS ? 'iOS' : 'Android';
      final String visitId = DateTime.now().millisecondsSinceEpoch.toString();
      final DateTime now = DateTime.now();

      final String time = DateFormat('HH:mm:ss').format(now);
      final String date = DateFormat('yyyy-MM-dd').format(now);

      // Ziyareti kaydet
      try {
        await _dashboardService.logVisit(
          userId: uid,
          visitId: visitId,
          appVersion: appVersion,
          platform: platform,
          time: time,
          date: date,
        );

        // Kullanıcıyı Dashboard ile eşitle
        await _dashboardService.syncExistingUser(uid, {
          'name': profile.name,
          'gender': profile.gender,
        });

        // Oturumu (heartbeat) başlat
        _dashboardService.startSession(uid, visitId);
      } catch (_) {}

    } catch (e) {
      debugPrint('⚠️ Kullanıcı başlatma hatası: $e. Çevrimdışı profile dönülüyor.');
      await _loadCachedProfile();
    }
  }

  // Kullanıcı profil verilerini güncelle
  Future<void> updateProfile({
    String? name,
    DateTime? birthDate,
    String? birthTime,
    String? birthPlace,
    String? gender,
    String? zodiacSign,
  }) async {
    final currentProfile = state ?? UserModel(
      uid: 'offline_anonymous',
      createdAt: DateTime.now(),
      localeCode: ref.read(languageProvider).languageCode,
    );

    // Doğum tarihi ve saati birleştirerek tam yerel zamanı elde et
    DateTime? mergedBirthDate = birthDate;
    if (birthDate != null) {
      final timeToUse = birthTime ?? currentProfile.birthTime;
      if (timeToUse != null && timeToUse.isNotEmpty) {
        final parts = timeToUse.split(':');
        if (parts.length == 2) {
          final hour = int.parse(parts[0]);
          final minute = int.parse(parts[1]);
          final localBirth = DateTime(
            birthDate.year,
            birthDate.month,
            birthDate.day,
            hour,
            minute,
          );
          final offset = AstrologyUtils.getTurkeyOffsetInHours(localBirth);
          
          mergedBirthDate = DateTime.utc(
            birthDate.year,
            birthDate.month,
            birthDate.day,
            hour,
            minute,
          ).subtract(Duration(hours: offset));
        }
      }
    } else if (currentProfile.birthDate != null && birthTime != null && birthTime.isNotEmpty) {
      final parts = birthTime.split(':');
      if (parts.length == 2) {
        final hour = int.parse(parts[0]);
        final minute = int.parse(parts[1]);
        final localBirth = DateTime(
          currentProfile.birthDate!.year,
          currentProfile.birthDate!.month,
          currentProfile.birthDate!.day,
          hour,
          minute,
        );
        final offset = AstrologyUtils.getTurkeyOffsetInHours(localBirth);
        
        mergedBirthDate = DateTime.utc(
          currentProfile.birthDate!.year,
          currentProfile.birthDate!.month,
          currentProfile.birthDate!.day,
          hour,
          minute,
        ).subtract(Duration(hours: offset));
      }
    }

    // Doğum parametrelerinin veya adın değişip değişmediğini kontrol et
    final bool birthDetailsChanged =
        currentProfile.birthDate != mergedBirthDate ||
        currentProfile.birthTime != birthTime ||
        currentProfile.birthPlace != birthPlace ||
        currentProfile.name != name ||
        currentProfile.gender != gender;

    final updated = currentProfile.copyWith(
      name: name,
      birthDate: mergedBirthDate,
      birthTime: birthTime,
      birthPlace: birthPlace,
      gender: gender,
      zodiacSign: zodiacSign,
    );

    state = updated;

    try {
      // Önbelleği güncelle
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('cached_user_profile', jsonEncode(updated.toJson()));

      if (updated.uid != 'offline_anonymous') {
        // Firebase'e kaydet
        await _firebaseService.saveUserProfile(updated);

        // Dashboard profili güncelle/eşitle
        await _dashboardService.syncExistingUser(updated.uid, {
          'name': name,
          'gender': gender,
        });

        // Eğer doğum detayları değiştiyse, eski analiz/harita/numeroloji önbelleklerini temizle
        if (birthDetailsChanged) {
          final firestore = FirebaseFirestore.instance;
          await firestore.doc('users/${updated.uid}/natal_chart/data').delete().catchError((_) {});
          await firestore.doc('users/${updated.uid}/character_analysis/data').delete().catchError((_) {});
          await firestore.doc('users/${updated.uid}/best_matches/data').delete().catchError((_) {});

          final nameToUse = name ?? currentProfile.name;
          if (nameToUse != null && nameToUse.trim().isNotEmpty) {
            final docName = nameToUse.toLowerCase().trim().replaceAll(' ', '_');
            await firestore.doc('users/${updated.uid}/numerology/$docName').delete().catchError((_) {});
          }
        }
      }
    } catch (e) {
      debugPrint('⚠️ Profil güncelleme hatası: $e');
    }
  }

  // Premium durumunu güncelle
  Future<void> updatePremiumStatus(bool isPremium) async {
    final currentProfile = state;
    if (currentProfile == null) return;
    
    final updated = currentProfile.copyWith(isPremium: isPremium);
    state = updated;
    
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('cached_user_profile', jsonEncode(updated.toJson()));
      
      if (updated.uid != 'offline_anonymous') {
        await _firebaseService.saveUserProfile(updated);
      }
      debugPrint('ℹ️ Premium durumu güncellendi: $isPremium');
    } catch (e) {
      debugPrint('⚠️ Premium durumu güncellenirken hata: $e');
    }
  }
}

final userProvider = NotifierProvider<UserNotifier, UserModel?>(() {
  return UserNotifier();
});

class OnboardingNotifier extends Notifier<bool> {
  static const String _prefKey = 'onboarding_complete';

  @override
  bool build() {
    _loadStatus();
    return false;
  }

  Future<void> _loadStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      state = prefs.getBool(_prefKey) ?? false;
    } catch (_) {}
  }

  Future<bool> ensureLoaded() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isComplete = prefs.getBool(_prefKey) ?? false;
      state = isComplete;
      return isComplete;
    } catch (_) {
      return false;
    }
  }

  Future<void> completeOnboarding() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefKey, true);
      state = true;
    } catch (_) {}
  }

  Future<void> resetOnboarding() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefKey);
      state = false;
    } catch (_) {}
  }
}

final onboardingCompleteProvider = NotifierProvider<OnboardingNotifier, bool>(() {
  return OnboardingNotifier();
});
