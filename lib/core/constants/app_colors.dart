import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Ana Renkler
  static const Color background = Color(0xFF0D0A1A); // Derin Uzay Moru
  static const Color primaryGold = Color(0xFFD4A843); // Altın Vurgu
  static const Color warmAmber = Color(0xFFC17B2A); // Sıcak Kehribar
  static const Color deepBrown = Color(0xFF3D1F0A); // Koyu Kahve
  static const Color cardSurface = Color(0xFF1A1428); // Glassmorphism Tabanı
  
  // Metin Renkleri
  static const Color textPrimary = Color(0xFFF5E6C8); // Krem Beyaz
  static const Color textSecondary = Color(0xFFB8A88A); // Mistik İkincil Altın
  static const Color textDark = Color(0xFF0D0A1A); // Buton içi vb. için koyu renk

  // Yardımcı Renkler
  static const Color accentPurple = Color(0xFF7B5EA7); // Yıldız Tozu Moru
  static const Color shadowColor = Color(0x80000000); // Gölgeler
  static const Color borderLight = Color(0x14FFFFFF); // %8 Opak Beyaz Border

  // Gradiyentler
  static const LinearGradient cosmicGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFF0D0A1A),
      Color(0xFF1D1635),
      Color(0xFF0D0A1A),
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

  static const LinearGradient glassGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0x1FFFFFFF), // %12 Opak
      Color(0x0AFFFFFF), // %4 Opak
    ],
  );
}
