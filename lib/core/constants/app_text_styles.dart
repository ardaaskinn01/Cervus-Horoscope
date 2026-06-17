import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTextStyles {
  AppTextStyles._();

  // Dinamik olarak tema sağlayıcısı tarafından değiştirilir
  static bool isDark = true;

  static Color get _textPrimaryColor => isDark ? const Color(0xFFF5E6C8) : const Color(0xFF2E2214);
  static Color get _textSecondaryColor => isDark ? const Color(0xFFB8A88A) : const Color(0xFF705C49);

  // Headings (Cormorant Garamond - Mistik & Zarif)
  static TextStyle get h1 => GoogleFonts.cormorantGaramond(
        fontSize: 36,
        fontWeight: FontWeight.bold,
        color: _textPrimaryColor,
        letterSpacing: 0.5,
      );

  static TextStyle get h2 => GoogleFonts.cormorantGaramond(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        color: _textPrimaryColor,
        letterSpacing: 0.5,
      );

  static TextStyle get h3 => GoogleFonts.cormorantGaramond(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        color: _textPrimaryColor,
      );

  static TextStyle get h4 => GoogleFonts.cormorantGaramond(
        fontSize: 20,
        fontWeight: FontWeight.w500,
        color: _textPrimaryColor,
      );

  // Body & Content (Inter - Modern & Okunaklı)
  static TextStyle get bodyLarge => GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.normal,
        color: _textPrimaryColor,
        height: 1.5,
      );

  static TextStyle get bodyMedium => GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.normal,
        color: _textSecondaryColor,
        height: 1.4,
      );

  static TextStyle get bodySmall => GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.normal,
        color: _textSecondaryColor,
        height: 1.3,
      );

  // Labels & Buttons
  static TextStyle get label => GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: _textPrimaryColor,
        letterSpacing: 0.8,
      );

  static TextStyle get caption => GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w300,
        color: _textSecondaryColor,
      );
}
