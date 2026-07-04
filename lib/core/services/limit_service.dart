import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:horoscope/core/constants/app_colors.dart';
import 'package:horoscope/core/constants/app_text_styles.dart';
import 'package:horoscope/core/providers/language_provider.dart';
import 'package:horoscope/core/services/ad_service.dart';
import 'package:horoscope/core/services/device_service.dart';
import 'package:horoscope/core/services/firebase_service.dart';
import 'package:horoscope/core/utils/firestore_extension.dart';
import 'package:horoscope/shared/widgets/glass_card.dart';
import 'package:horoscope/shared/widgets/gradient_button.dart';
import 'package:horoscope/shared/widgets/premium_dialog_helper.dart';
import 'package:horoscope/core/models/user_model.dart';

enum LimitStatus {
  allowed,
  needAd,
  locked,
}

class LimitService {
  LimitService._privateConstructor();
  static final LimitService instance = LimitService._privateConstructor();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseService _firebaseService = FirebaseService();

  // En son 04:00 AM zaman damgasını hesaplar (Türkiye/Cihaz yerel saati bazlı)
  DateTime _getMostRecentFourAM() {
    final now = DateTime.now();
    final fourAMToday = DateTime(now.year, now.month, now.day, 4, 0);
    if (now.isBefore(fourAMToday)) {
      return fourAMToday.subtract(const Duration(days: 1));
    } else {
      return fourAMToday;
    }
  }

  // Kullanıcının profil bilgilerini sorgular
  Future<UserModel?> _getUserProfile() async {
    final currentUser = _firebaseService.currentUser;
    if (currentUser == null) return null;
    
    try {
      final userDoc = await _firestore.doc('users/${currentUser.uid}').safeGet();
      if (userDoc.exists && userDoc.data() != null) {
        return UserModel.fromMap(userDoc.data()!);
      }
    } catch (e) {
      debugPrint('⚠️ Error fetching user profile in LimitService: $e');
    }
    return null;
  }

  // Limit durumunu kontrol et
  Future<LimitStatus> checkLimit(String featureKey) async {
    final userProfile = await _getUserProfile();
    final bool isProPlus = userProfile?.isPremium == true;
    final bool isPro = userProfile?.isPro == true;

    // 1. PRO+ (Sınırsız)
    if (isProPlus) {
      return LimitStatus.allowed;
    }

    try {
      final deviceId = await DeviceService.instance.getDeviceId();
      final docRef = _firestore.doc('device_limits/$deviceId');
      final doc = await docRef.safeGet();

      if (!doc.exists || doc.data() == null) {
        return LimitStatus.allowed;
      }

      final data = doc.data()!;
      final limitBoundary = _getMostRecentFourAM();

      // Son hesaplama zamanı
      final lastCalculatedMap = data['lastCalculatedAt'] as Map<String, dynamic>?;
      final dynamic lastCalculatedVal = lastCalculatedMap?[featureKey];
      DateTime lastCalculated = DateTime.fromMillisecondsSinceEpoch(0);
      if (lastCalculatedVal != null) {
        lastCalculated = lastCalculatedVal is Timestamp ? lastCalculatedVal.toDate() : lastCalculatedVal as DateTime;
      }

      // 2. PRO (10 Analiz Limitli, Reklamsız)
      if (isPro) {
        final int todayCount = await getTodayGlobalUsageCount();
        if (todayCount >= 10) {
          return LimitStatus.locked;
        }
        return LimitStatus.allowed;
      }

      // 3. Ücretsiz Kullanıcı Kontrolü
      final firstFreeUsedMap = data['firstFreeUsed'] as Map<String, dynamic>?;
      final bool firstFreeUsed = firstFreeUsedMap?[featureKey] == true;

      if (!firstFreeUsed) {
        return LimitStatus.allowed;
      }

      if (lastCalculated.isAfter(limitBoundary)) {
        return LimitStatus.locked;
      }

      final bool globalLimit = await isGlobalLimitReached();
      if (globalLimit) {
        return LimitStatus.locked;
      }

      final lastAdWatchedMap = data['lastAdWatchedAt'] as Map<String, dynamic>?;
      final dynamic lastAdWatchedVal = lastAdWatchedMap?[featureKey];
      DateTime lastAdWatched = DateTime.fromMillisecondsSinceEpoch(0);
      if (lastAdWatchedVal != null) {
        lastAdWatched = lastAdWatchedVal is Timestamp ? lastAdWatchedVal.toDate() : lastAdWatchedVal as DateTime;
      }

      if (lastAdWatched.isAfter(limitBoundary)) {
        return LimitStatus.allowed;
      }

      return LimitStatus.needAd;

    } catch (e) {
      debugPrint('⚠️ checkLimit hatası: $e');
      return LimitStatus.allowed;
    }
  }

  // Hesaplama yapıldığında Firestore'u güncelle
  Future<void> registerCalculation(String featureKey) async {
    try {
      final deviceId = await DeviceService.instance.getDeviceId();
      final docRef = _firestore.doc('device_limits/$deviceId');
      final doc = await docRef.safeGet();

      Map<String, dynamic> firstFreeUsedMap = {};
      Map<String, dynamic> lastCalculatedMap = {};

      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        firstFreeUsedMap = Map<String, dynamic>.from(data['firstFreeUsed'] ?? {});
        lastCalculatedMap = Map<String, dynamic>.from(data['lastCalculatedAt'] ?? {});
      }

      if (firstFreeUsedMap[featureKey] != true) {
        firstFreeUsedMap[featureKey] = true;
      }

      lastCalculatedMap[featureKey] = FieldValue.serverTimestamp();

      await docRef.set({
        'firstFreeUsed': firstFreeUsedMap,
        'lastCalculatedAt': lastCalculatedMap,
      }, SetOptions(merge: true));

    } catch (e) {
      debugPrint('⚠️ registerCalculation hatası: $e');
    }
  }

  // Ad izlendiğinde Firestore'u güncelle
  Future<void> registerAdWatch(String featureKey) async {
    try {
      final deviceId = await DeviceService.instance.getDeviceId();
      final docRef = _firestore.doc('device_limits/$deviceId');
      final doc = await docRef.safeGet();

      Map<String, dynamic> lastAdWatchedMap = {};

      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        lastAdWatchedMap = Map<String, dynamic>.from(data['lastAdWatchedAt'] ?? {});
      }

      lastAdWatchedMap[featureKey] = FieldValue.serverTimestamp();

      await docRef.set({
        'lastAdWatchedAt': lastAdWatchedMap,
      }, SetOptions(merge: true));

    } catch (e) {
      debugPrint('⚠️ registerAdWatch hatası: $e');
    }
  }

  /// Bugün (gece 04:00'ten beri) yapılan toplam yapay zeka hesaplama sayısını döner
  Future<int> getTodayGlobalUsageCount() async {
    try {
      final deviceId = await DeviceService.instance.getDeviceId();
      final docRef = _firestore.doc('device_limits/$deviceId');
      final doc = await docRef.safeGet();

      if (!doc.exists || doc.data() == null) return 0;

      final data = doc.data()!;
      final lastCalculatedMap = data['lastCalculatedAt'] as Map<String, dynamic>?;
      if (lastCalculatedMap == null) return 0;

      final limitBoundary = _getMostRecentFourAM();
      int todayGlobalCount = 0;

      final aiFeatures = [
        'love_compatibility',
        'friend_compatibility',
        'cosmic_oracle',
        'tarot',
        'partner_natal_chart',
        'numerology',
        'partner_numerology'
      ];

      lastCalculatedMap.forEach((key, value) {
        if (aiFeatures.contains(key)) {
          DateTime calcTime;
          if (value is Timestamp) {
            calcTime = value.toDate();
          } else if (value is DateTime) {
            calcTime = value;
          } else {
            return;
          }

          if (calcTime.isAfter(limitBoundary)) {
            todayGlobalCount++;
          }
        }
      });

      return todayGlobalCount;
    } catch (e) {
      debugPrint('⚠️ getTodayGlobalUsageCount error: $e');
      return 0;
    }
  }

  // Günlük toplam yapay zeka limitinin aşılıp aşılmadığını kontrol eder
  Future<bool> isGlobalLimitReached() async {
    final userProfile = await _getUserProfile();
    final bool isProPlus = userProfile?.isPremium == true;
    final bool isPro = userProfile?.isPro == true;

    if (isProPlus) return false;
    
    final int todayCount = await getTodayGlobalUsageCount();

    if (isPro) {
      return todayCount >= 10;
    }

    return todayCount >= 3;
  }

  /// Astro portre yorumları için ücretsiz sürümde her 2 okumada bir ödüllü reklam istemcisi
  Future<bool> checkAndRequestPortraitCommentAccess({
    required BuildContext context,
    required WidgetRef ref,
  }) async {
    final userProfile = await _getUserProfile();
    final isAnyPremium = userProfile?.isAnyPremium == true;
    if (isAnyPremium) return true;

    final prefs = await SharedPreferences.getInstance();
    final int readCount = prefs.getInt('portrait_comment_read_count') ?? 0;

    if (readCount < 2) {
      await prefs.setInt('portrait_comment_read_count', readCount + 1);
      return true;
    }

    final completer = Completer<bool>();
    final isTr = ref.read(languageProvider).languageCode == 'tr';

    if (!context.mounted) return false;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogCtx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: GlassCard(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('📺', style: TextStyle(fontSize: 48)),
                const SizedBox(height: 16),
                Text(
                  isTr ? 'Reklam İzle ve Devam Et' : 'Watch Ad to Continue',
                  style: AppTextStyles.h3.copyWith(color: AppColors.primaryGold, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  isTr
                      ? 'Ücretsiz sürümde her 2 detaylı astrolojik yorumdan sonra devam etmek için ödüllü bir reklam izlemeniz gerekmektedir. Reklamı izleyerek sonraki 2 yorumu hemen okuyabilirsiniz.'
                      : 'In the free version, you need to watch a rewarded ad after reading 2 detailed astrological comments. Watch now to unlock and continue reading.',
                  style: AppTextStyles.bodyMedium.copyWith(height: 1.45),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                GradientButton(
                  text: isTr ? 'Reklam İzle 📺' : 'Watch Ad 📺',
                  onTap: () {
                    Navigator.pop(dialogCtx);
                    AdService.instance.showRewardedAd(
                      placement: 'ai_tools_rewarded',
                      context: context,
                      isPremium: false,
                      onRewardEarned: () async {
                        await prefs.setInt('portrait_comment_read_count', 1);
                        completer.complete(true);
                      },
                    );
                  },
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () {
                    Navigator.pop(dialogCtx);
                    PremiumDialogHelper.show(context, ref);
                    completer.complete(false);
                  },
                  child: Text(
                    isTr ? 'Premium\'a Geç 🚀' : 'Upgrade to Premium 🚀',
                    style: const TextStyle(color: AppColors.primaryGold, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 4),
                TextButton(
                  onPressed: () {
                    Navigator.pop(dialogCtx);
                    completer.complete(false);
                  },
                  child: Text(
                    isTr ? 'Kapat' : 'Close',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    return completer.future;
  }
}
