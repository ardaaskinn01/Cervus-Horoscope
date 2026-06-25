import 'package:flutter/material.dart';
import 'app_text_styles.dart';

class AppColors {
  AppColors._();

  // Ana Renkler
  static Color get background => AppTextStyles.isDark ? const Color(0xFF0B1020) : const Color(0xFFF8F9FD); 
  static Color get cardSurface => AppTextStyles.isDark ? const Color(0xFF171D33) : const Color(0xFFFFFFFF); 
  
  static Color get primary => AppTextStyles.isDark ? const Color(0xFF7C5CFF) : const Color(0xFF6D4AFF);
  static Color get accent => AppTextStyles.isDark ? const Color(0xFFF7C948) : const Color(0xFFFFB703);
  static Color get success => AppTextStyles.isDark ? const Color(0xFF48D597) : const Color(0xFF34C759);

  // Metin Renkleri
  static Color get textPrimary => AppTextStyles.isDark ? const Color(0xFFFFFFFF) : const Color(0xFF111827); 
  static Color get textSecondary => AppTextStyles.isDark ? const Color(0xFFB6BDD6) : const Color(0xFF6B7280); 
  
  // Eski renklerle uyumluluk için sabitler (Böylece const Widget ağaçları kırılmaz)
  static const Color primaryGold = Color(0xFFF7C948); // Altın Vurgu (Yeni Accent rengi)
  static const Color warmAmber = Color(0xFF7C5CFF);   // Mor Vurgu (Yeni Primary rengi)
  static const Color deepBrown = Color(0xFF3D1F0A);   // Koyu Kahve
  static const Color textDark = Color(0xFFFFFFFF);    // Buton içi metin rengi (Beyaz)
  static const Color accentPurple = Color(0xFF7C5CFF); // Mor Vurgu (Yeni Primary rengi)

  // Yardımcı Renkler
  static Color get borderLight => AppTextStyles.isDark ? const Color(0x14FFFFFF) : const Color(0x1B111827); // %8 Opak Beyaz / %10 Koyu
  static const Color shadowColor = Color(0x80000000); // Gölgeler

  // Gradiyentler
  static LinearGradient get cosmicGradient => LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: AppTextStyles.isDark 
        ? [
            const Color(0xFF0B1020),
            const Color(0xFF14192F),
            const Color(0xFF0B1020),
          ]
        : [
            const Color(0xFFF8F9FD),
            const Color(0xFFEFEFF7),
            const Color(0xFFF8F9FD),
          ],
  );

  // Eski goldGradient yerine artık Primary renginden oluşan degradeyi döneriz, böylece tüm butonlar mor olur
  static LinearGradient get goldGradient => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: AppTextStyles.isDark
        ? [
            const Color(0xFF7C5CFF),
            const Color(0xFF9E85FF),
          ]
        : [
            const Color(0xFF6D4AFF),
            const Color(0xFF8B6EFF),
          ],
  );

  static LinearGradient get glassGradient => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: AppTextStyles.isDark
        ? [
            const Color(0x1FFFFFFF), // %12 Opak
            const Color(0x0AFFFFFF), // %4 Opak
          ]
        : [
            const Color(0x1F111827), // %12 Opak Koyu
            const Color(0x0A111827), // %4 Opak Koyu
          ],
  );
}
