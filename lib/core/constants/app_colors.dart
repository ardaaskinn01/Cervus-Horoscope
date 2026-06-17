import 'package:flutter/material.dart';
import 'app_text_styles.dart';

class AppColors {
  AppColors._();

  // Ana Renkler
  static Color get background => AppTextStyles.isDark ? const Color(0xFF0D0A1A) : const Color(0xFFF9F7FA); // Derin Uzay Moru / Krem
  static const Color primaryGold = Color(0xFFD4A843); // Altın Vurgu
  static const Color warmAmber = Color(0xFFC17B2A); // Sıcak Kehribar
  static const Color deepBrown = Color(0xFF3D1F0A); // Koyu Kahve
  static Color get cardSurface => AppTextStyles.isDark ? const Color(0xFF1A1428) : const Color(0xFFFFFFFF); // Glassmorphism / Beyaz
  
  // Metin Renkleri
  static Color get textPrimary => AppTextStyles.isDark ? const Color(0xFFF5E6C8) : const Color(0xFF2E2214); // Krem Beyaz / Koyu Kahve
  static Color get textSecondary => AppTextStyles.isDark ? const Color(0xFFB8A88A) : const Color(0xFF705C49); // Mistik İkincil Altın / Orta Kahve
  static const Color textDark = Color(0xFF0D0A1A); // Buton içi vb. için koyu renk

  // Yardımcı Renkler
  static const Color accentPurple = Color(0xFF7B5EA7); // Yıldız Tozu Moru
  static const Color shadowColor = Color(0x80000000); // Gölgeler
  static Color get borderLight => AppTextStyles.isDark ? const Color(0x14FFFFFF) : const Color(0x1B0D0A1A); // %8 Opak Beyaz / %10 Koyu

  // Gradiyentler
  static LinearGradient get cosmicGradient => LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: AppTextStyles.isDark 
        ? [
            const Color(0xFF0D0A1A),
            const Color(0xFF1D1635),
            const Color(0xFF0D0A1A),
          ]
        : [
            const Color(0xFFF9F7FA),
            const Color(0xFFF1EDF5),
            const Color(0xFFF9F7FA),
          ],
  );

  static const LinearGradient goldGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFF5D061),
      Color(0xFFD4A843),
      Color(0xFFC17B2A),
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
            const Color(0x1F0D0A1A), // %12 Opak Koyu
            const Color(0x0A0D0A1A), // %4 Opak Koyu
          ],
  );
}
