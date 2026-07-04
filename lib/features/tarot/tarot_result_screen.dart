import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:horoscope/core/constants/app_colors.dart';
import 'package:horoscope/core/constants/app_text_styles.dart';
import 'package:horoscope/core/models/tarot_card.dart';
import 'package:horoscope/core/models/tarot_reading_model.dart';
import 'package:horoscope/core/models/user_model.dart';
import 'package:horoscope/core/providers/user_provider.dart';
import 'package:horoscope/core/providers/language_provider.dart';
import 'package:horoscope/shared/widgets/glass_card.dart';
import 'package:horoscope/shared/widgets/gradient_button.dart';
import 'package:horoscope/shared/widgets/star_background.dart';

class TarotResultScreen extends ConsumerStatefulWidget {
  final TarotReadingModel reading;

  const TarotResultScreen({super.key, required this.reading});

  @override
  ConsumerState<TarotResultScreen> createState() => _TarotResultScreenState();
}

class _TarotResultScreenState extends ConsumerState<TarotResultScreen> {
  // Kartların açılıp açılmadığı durumları tutan liste
  final List<bool> _isFlipped = [false, false, false];

  @override
  Widget build(BuildContext context) {
    final isTr = ref.watch(languageProvider).languageCode == 'tr';
    final user = ref.watch(userProvider);
    
    // Asenkron olarak harita verisini alan provider'dan haritayı okuyalım (varsa UI rezonans için)
    // Bu sayede kozmik bağlantıyı ekranda gösterebiliriz
    // Not: Harita local sweph veritabanından zaten ai_service içinde çekilmişti.
    // Biz burada basitçe isme göre kozmik bağlantı eşleştirmesi yapacağız.

    return Scaffold(
      appBar: AppBar(
        title: Text(isTr ? 'Kozmik Tarot Yorumu' : 'Cosmic Tarot Reading'),
      ),
      body: StarBackground(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(left: 20.0, right: 20.0, top: 10.0, bottom: 60.0),
          child: Column(
            children: [
              // Açıklama Metni
              Text(
                isTr ? 'Açılım Sonuçlarınız' : 'Your Spread Results',
                style: AppTextStyles.caption.copyWith(color: AppColors.primaryGold, letterSpacing: 1.5),
              ),
              const SizedBox(height: 4),
              Text(
                isTr
                    ? 'Kartların üzerine dokunarak gizemlerini ortaya çıkarın.'
                    : 'Tap on the cards to reveal their mysteries.',
                style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),

              // ── 1. Üç Kart Yayılımı (3D Flip Kartlar) ─────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(3, (index) {
                  final draw = widget.reading.draws[index];
                  final positionLabel = index == 0
                      ? (isTr ? '1. Durum / Geçmiş' : 'Situation / Past')
                      : (index == 1
                          ? (isTr ? '2. Engel / Şimdi' : 'Obstacle / Present')
                          : (isTr ? '3. Tavsiye / Gelecek' : 'Advice / Future'));

                  return Expanded(
                    child: Container(
                      margin: EdgeInsets.only(
                        left: index == 0 ? 0 : 4,
                        right: index == 2 ? 0 : 4,
                      ),
                      child: Column(
                        children: [
                          Text(
                            positionLabel,
                            style: AppTextStyles.caption.copyWith(fontSize: 8, fontWeight: FontWeight.bold),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _isFlipped[index] = !_isFlipped[index];
                              });
                              HapticFeedback.mediumImpact();
                            },
                            child: AspectRatio(
                              aspectRatio: 0.62,
                              child: _FlipCard(
                                isFlipped: _isFlipped[index],
                                front: _buildCardFront(draw, isTr, user),
                                back: _buildCardBack(),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 32),

              // ── 2. AI Kozmik Yorum Kartı ──────────────────────────────
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  isTr ? '🔮 Mistik Analiz' : '🔮 Mystical Analysis',
                  style: AppTextStyles.h3,
                ),
              ),
              const SizedBox(height: 12),
              GlassCard(
                padding: const EdgeInsets.all(18),
                child: Text(
                  isTr ? widget.reading.commentTr : widget.reading.commentEn,
                  style: AppTextStyles.bodyMedium.copyWith(height: 1.65),
                ),
              ).animate().fade(duration: 600.ms, delay: 200.ms),
              const SizedBox(height: 32),

              // Kapat / Başa Dön Butonu
              GradientButton(
                text: isTr ? 'Yeni Bir Açılım Yap 🔄' : 'Make Another Spread 🔄',
                onTap: () {
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Kart Arka Yüzü Tasarımı
  Widget _buildCardBack() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primaryGold.withValues(alpha: 0.4), width: 1.5),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.asset(
          'assets/images/tarot_card_back.png',
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
        ),
      ),
    );
  }

  // Kart Ön Yüzü Tasarımı
  Widget _buildCardFront(TarotCardDraw draw, bool isTr, UserModel? user) {
    final card = TarotCard.majorArcana.firstWhere((x) => x.id == draw.cardId);
    final association = isTr ? card.astrologicalAssociationTr : card.astrologicalAssociationEn;
    
    // Kozmik Bağlantı Kontrolü (kullanıcı burcuyla eşleşme)
    bool hasCosmicLink = false;
    if (user?.zodiacSign != null) {
      final userZodiacName = _getZodiacTrName(user!.zodiacSign!, true).toLowerCase();
      if (association.toLowerCase().contains(userZodiacName)) {
        hasCosmicLink = true;
      }
    }

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: hasCosmicLink ? AppColors.primaryGold : AppColors.primaryGold.withValues(alpha: 0.35),
          width: hasCosmicLink ? 2.0 : 1.2,
        ),
        gradient: const RadialGradient(
          colors: [
            Color(0xFF2E224E),
            Color(0xFF140E26),
          ],
          center: Alignment.center,
          radius: 0.8,
        ),
        boxShadow: hasCosmicLink
            ? [
                BoxShadow(
                  color: AppColors.primaryGold.withValues(alpha: 0.35),
                  blurRadius: 10,
                  spreadRadius: 1,
                )
              ]
            : null,
      ),
      child: Stack(
        children: [
          // ── Resim Arka Planı (Rider-Waite İllüstrasyonu) ──
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.asset(
                'assets/images/tarot/${card.id}.jpg',
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  // Resim yoksa, eski altın tılsımlı emoji stilimizi gösteriyoruz!
                  return Center(
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.primaryGold.withValues(alpha: 0.35),
                          width: 1.2,
                        ),
                        gradient: RadialGradient(
                          colors: [
                            AppColors.primaryGold.withValues(alpha: 0.08),
                            Colors.transparent,
                          ],
                        ),
                      ),
                      child: Text(
                        draw.symbol,
                        style: const TextStyle(fontSize: 26),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          
          // Görselin üstüne hafif koyu degrade atıyoruz ki üzerindeki yazılar (kart ismi, astroloji) rahat okunsun
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                gradient: LinearGradient(
                  colors: [
                    Colors.black.withValues(alpha: 0.75),
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.85),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
            ),
          ),

          // İç İnce Altın Çerçeve
          Positioned.fill(
            child: Container(
              margin: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                border: Border.all(
                  color: AppColors.primaryGold.withValues(alpha: 0.15),
                  width: 0.8,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),

          // Köşe Yıldızları (✦ Süslemeler)
          Positioned(
            top: 8,
            left: 8,
            child: Text('✦', style: TextStyle(fontSize: 6, color: AppColors.primaryGold.withValues(alpha: 0.5))),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: Text('✦', style: TextStyle(fontSize: 6, color: AppColors.primaryGold.withValues(alpha: 0.5))),
          ),
          Positioned(
            bottom: 8,
            left: 8,
            child: Text('✦', style: TextStyle(fontSize: 6, color: AppColors.primaryGold.withValues(alpha: 0.5))),
          ),
          Positioned(
            bottom: 8,
            right: 8,
            child: Text('✦', style: TextStyle(fontSize: 6, color: AppColors.primaryGold.withValues(alpha: 0.5))),
          ),

          // Kart İçeriği (Yazılar)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // ── Üst: Astrolojik Eşleşme ──
                SizedBox(
                  height: 32,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            association,
                            style: TextStyle(
                              fontSize: 7.5,
                              fontWeight: FontWeight.bold,
                              color: hasCosmicLink ? AppColors.primaryGold : const Color(0xFFCBB6E6),
                              letterSpacing: 0.5,
                              shadows: const [
                                Shadow(
                                  color: Colors.black54,
                                  offset: Offset(0.5, 0.5),
                                  blurRadius: 2,
                                ),
                              ],
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        if (hasCosmicLink)
                          Container(
                            margin: const EdgeInsets.only(top: 2),
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(
                              color: AppColors.primaryGold.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              isTr ? '✨ BAĞLANTI' : '✨ LINK',
                              style: const TextStyle(
                                fontSize: 6,
                                color: AppColors.primaryGold,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                // ── Alt: Kart İsmi + Yön Rozeti ──
                SizedBox(
                  height: 36,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          isTr ? draw.cardNameTr.split(' (').first : draw.cardNameEn,
                          style: AppTextStyles.label.copyWith(
                            fontWeight: FontWeight.bold,
                            fontSize: 9.5,
                            color: hasCosmicLink ? AppColors.primaryGold : Colors.white,
                            shadows: [
                              Shadow(
                                color: Colors.black.withValues(alpha: 0.9),
                                offset: const Offset(1, 1),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: draw.isUpright
                              ? Colors.green.withValues(alpha: 0.2)
                              : Colors.redAccent.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: draw.isUpright ? Colors.green.withValues(alpha: 0.5) : Colors.redAccent.withValues(alpha: 0.5),
                            width: 0.5,
                          ),
                        ),
                        child: Text(
                          draw.isUpright
                              ? (isTr ? 'DÜZ' : 'UPRIGHT')
                              : (isTr ? 'TERS' : 'REVERSED'),
                          style: TextStyle(
                            fontSize: 7,
                            fontWeight: FontWeight.bold,
                            color: draw.isUpright ? Colors.greenAccent : Colors.redAccent,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getZodiacTrName(String sign, bool isTr) {
    if (!isTr) return sign[0].toUpperCase() + sign.substring(1);
    switch (sign.toLowerCase()) {
      case 'aries': return 'Koç';
      case 'taurus': return 'Boğa';
      case 'gemini': return 'İkizler';
      case 'cancer': return 'Yengeç';
      case 'leo': return 'Aslan';
      case 'virgo': return 'Başak';
      case 'libra': return 'Terazi';
      case 'scorpio': return 'Akrep';
      case 'sagittarius': return 'Yay';
      case 'capricorn': return 'Oğlak';
      case 'aquarius': return 'Kova';
      case 'pisces': return 'Balık';
      default: return sign;
    }
  }
}

// ── 3D Card Flip Widget ──────────────────────────────────────────
class _FlipCard extends StatelessWidget {
  final bool isFlipped;
  final Widget front;
  final Widget back;

  const _FlipCard({
    required this.isFlipped,
    required this.front,
    required this.back,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: isFlipped ? pi : 0.0),
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOutCubic,
      builder: (context, angle, child) {
        final isFront = angle >= pi / 2;
        return Transform(
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.002) // Perspektif
            ..rotateY(angle),
          alignment: Alignment.center,
          child: isFront
              ? Transform(
                  // Ön yüzün ters (aynalanmış) durmasını önlemek için 180 derece Y rotasyonu yapıyoruz
                  transform: Matrix4.identity()..rotateY(pi),
                  alignment: Alignment.center,
                  child: front,
                )
              : back,
        );
      },
    );
  }
}
