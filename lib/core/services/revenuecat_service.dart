import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

class RevenueCatService {
  static bool _isConfigured = false;

  /// RevenueCat'i başlatır
  static Future<void> init() async {
    try {
      await Purchases.setLogLevel(LogLevel.debug);

      String? apiKey;
      if (Platform.isAndroid) {
        apiKey = dotenv.env['REVENUECAT_ANDROID_KEY'];
      } else if (Platform.isIOS) {
        apiKey = dotenv.env['REVENUECAT_IOS_KEY'];
      }

      if (apiKey == null || apiKey.isEmpty || apiKey.contains('placeholder')) {
        debugPrint("⚠️ RevenueCat API Key bulunamadı veya placeholder. Yapılandırma atlanıyor.");
        return;
      }

      PurchasesConfiguration configuration = PurchasesConfiguration(apiKey);
      await Purchases.configure(configuration);
      _isConfigured = true;
      debugPrint("✅ RevenueCat başarıyla yapılandırıldı.");
    } catch (e) {
      debugPrint("❌ RevenueCat Init Hatası: $e");
    }
  }

  /// Mevcut kullanıcının premium durumunu kontrol eder
  static Future<bool> checkPremiumStatus() async {
    if (!_isConfigured) return false;
    try {
      CustomerInfo customerInfo = await Purchases.getCustomerInfo();
      return customerInfo.entitlements.all["pro"]?.isActive ?? false;
    } catch (e) {
      debugPrint("⚠️ Premium durumu kontrol edilirken hata: $e");
      return false;
    }
  }

  /// Market tekliflerini (paketleri) getirir
  static Future<Offerings?> getOfferings() async {
    if (!_isConfigured) {
      debugPrint("⚠️ RevenueCat yapılandırılmamış - getOfferings atlanıyor.");
      return null;
    }
    try {
      return await Purchases.getOfferings();
    } catch (e) {
      debugPrint("❌ Paketleri getirme hatası: $e");
      return null;
    }
  }

  /// Belirli bir paketi satın alır
  static Future<bool> purchasePackage(Package package) async {
    if (!_isConfigured) return false;
    try {
      final result = await Purchases.purchase(PurchaseParams.package(package));
      final customerInfo = result.customerInfo;
      return customerInfo.entitlements.all["pro"]?.isActive ?? false;
    } on PlatformException catch (e) {
      var errorCode = PurchasesErrorHelper.getErrorCode(e);
      if (errorCode == PurchasesErrorCode.purchaseCancelledError) {
        debugPrint("ℹ️ Satın alma kullanıcı tarafından iptal edildi.");
      } else {
        debugPrint("❌ Satın alma platform hatası: $e");
      }
      rethrow;
    } catch (e) {
      debugPrint("❌ Beklenmedik satın alma hatası: $e");
      rethrow;
    }
  }

  /// Satın alımları geri yükler
  static Future<bool> restorePurchases() async {
    if (!_isConfigured) return false;
    try {
      CustomerInfo customerInfo = await Purchases.restorePurchases();
      return customerInfo.entitlements.all["pro"]?.isActive ?? false;
    } catch (e) {
      debugPrint("❌ Geri yükleme hatası: $e");
      rethrow;
    }
  }
}
