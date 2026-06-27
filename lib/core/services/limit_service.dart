import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:horoscope/core/services/device_service.dart';
import 'package:horoscope/core/services/firebase_service.dart';
import 'package:horoscope/core/utils/firestore_extension.dart';

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

  // Kullanıcının premium olup olmadığını sorgular
  Future<bool> _isUserPremium() async {
    final currentUser = _firebaseService.currentUser;
    if (currentUser == null) return false;
    
    try {
      final userDoc = await _firestore.doc('users/${currentUser.uid}').safeGet();
      if (userDoc.exists && userDoc.data() != null) {
        return userDoc.data()?['isPremium'] == true;
      }
    } catch (e) {
      debugPrint('⚠️ Premium check error in LimitService: $e');
    }
    return false;
  }

  // Limit durumunu kontrol et
  Future<LimitStatus> checkLimit(String featureKey) async {
    // 1. Premium kontrolü (Sınırsız)
    final isPremium = await _isUserPremium();
    if (isPremium) {
      return LimitStatus.allowed;
    }

    try {
      final deviceId = await DeviceService.instance.getDeviceId();
      final docRef = _firestore.doc('device_limits/$deviceId');
      final doc = await docRef.safeGet();

      if (!doc.exists || doc.data() == null) {
        // Cihaz hiç kaydolmamışsa ilk hak ücretsiz
        return LimitStatus.allowed;
      }

      final data = doc.data()!;
      
      // 2. İlk hak (1 lifetime free use) kullanıldı mı?
      final firstFreeUsedMap = data['firstFreeUsed'] as Map<String, dynamic>?;
      final bool firstFreeUsed = firstFreeUsedMap?[featureKey] == true;

      if (!firstFreeUsed) {
        return LimitStatus.allowed;
      }

      // 3. Günlük hak (gece 04:00'den beri) durumunu kontrol et
      final limitBoundary = _getMostRecentFourAM();

      // Son hesaplama zamanı
      final lastCalculatedMap = data['lastCalculatedAt'] as Map<String, dynamic>?;
      final dynamic lastCalculatedVal = lastCalculatedMap?[featureKey];
      DateTime lastCalculated = DateTime.fromMillisecondsSinceEpoch(0);
      if (lastCalculatedVal != null) {
        lastCalculated = lastCalculatedVal is Timestamp ? lastCalculatedVal.toDate() : lastCalculatedVal as DateTime;
      }

      // Son ad izleme zamanı
      final lastAdWatchedMap = data['lastAdWatchedAt'] as Map<String, dynamic>?;
      final dynamic lastAdWatchedVal = lastAdWatchedMap?[featureKey];
      DateTime lastAdWatched = DateTime.fromMillisecondsSinceEpoch(0);
      if (lastAdWatchedVal != null) {
        lastAdWatched = lastAdWatchedVal is Timestamp ? lastAdWatchedVal.toDate() : lastAdWatchedVal as DateTime;
      }

      // Eğer son hesaplama bugün 04:00'dan sonraysa, bugünkü hakkını doldurmuş demektir.
      if (lastCalculated.isAfter(limitBoundary)) {
        return LimitStatus.locked;
      }

      // Eğer son ad izleme bugün 04:00'dan sonraysa ve henüz hesaplama yapılmadıysa (ya da hesaplama adden önceyse), izin ver.
      if (lastAdWatched.isAfter(limitBoundary)) {
        return LimitStatus.allowed;
      }

      // Aksi halde ad izlenmesi gerekir.
      return LimitStatus.needAd;

    } catch (e) {
      debugPrint('⚠️ checkLimit hatası: $e');
      // Ağ hatasında akışı engellememek için varsayılan olarak izin ver
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

      // Eğer ilk kullanım ise, ilk kullanım flag'ini true yap
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
}
