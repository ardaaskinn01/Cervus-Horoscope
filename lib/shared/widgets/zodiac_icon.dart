import 'package:flutter/material.dart';
import 'package:horoscope/core/constants/app_colors.dart';

class ZodiacIcon extends StatelessWidget {
  final String sign; // e.g. 'aries', 'koç', 'scorpio' vb.
  final double size;
  final bool showGlow;
  final VoidCallback? onTap;

  const ZodiacIcon({
    super.key,
    required this.sign,
    this.size = 60,
    this.showGlow = true,
    this.onTap,
  });

  // Burç anahtar kelimelerini sembollere eşleştir
  static const Map<String, String> _symbols = {
    'aries': '♈',
    'koç': '♈',
    'taurus': '♉',
    'boğa': '♉',
    'gemini': '♊',
    'ikizler': '♊',
    'cancer': '♋',
    'yengeç': '♋',
    'leo': '♌',
    'aslan': '♌',
    'virgo': '♍',
    'başak': '♍',
    'libra': '♎',
    'terazi': '♎',
    'scorpio': '♏',
    'akrep': '♏',
    'sagittarius': '♐',
    'yay': '♐',
    'capricorn': '♑',
    'oğlak': '♑',
    'aquarius': '♒',
    'kova': '♒',
    'pisces': '♓',
    'balık': '♓',
  };


  String get _symbol {
    final normalized = sign.toLowerCase().trim();
    return _symbols[normalized] ?? '🔮';
  }

  @override
  Widget build(BuildContext context) {
    final double innerSize = size * 0.55;
    
    Widget iconWidget = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: AppColors.goldGradient,
        boxShadow: showGlow
            ? [
                BoxShadow(
                  color: AppColors.warmAmber.withValues(alpha: 0.35),
                  blurRadius: size * 0.3,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: Center(
        child: Container(
          width: size - 4,
          height: size - 4,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.cardSurface,
          ),
          child: Center(
            child: ShaderMask(
              shaderCallback: (bounds) => AppColors.goldGradient.createShader(bounds),
              child: Text(
                _symbol,
                style: TextStyle(
                  fontSize: innerSize,
                  fontWeight: FontWeight.normal,
                  color: Colors.white, // Maskeleme için gerekli
                  fontFamily: 'sans-serif', // Unicode sembol desteği için
                ),
              ),
            ),
          ),
        ),
      ),
    );

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        child: iconWidget,
      );
    }

    return iconWidget;
  }
}
