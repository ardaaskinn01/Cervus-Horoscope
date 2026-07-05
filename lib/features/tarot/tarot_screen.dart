import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shake/shake.dart';
import 'package:horoscope/core/constants/app_colors.dart';
import 'package:horoscope/core/constants/app_text_styles.dart';
import 'package:horoscope/core/models/tarot_card.dart';
import 'package:horoscope/core/models/tarot_reading_model.dart';
import 'package:horoscope/core/providers/user_provider.dart';
import 'package:horoscope/core/providers/language_provider.dart';
import 'package:horoscope/core/services/ai_service.dart';
import 'package:horoscope/shared/widgets/glass_card.dart';
import 'package:horoscope/shared/widgets/gradient_button.dart';
import 'package:horoscope/shared/widgets/star_background.dart';
import 'package:horoscope/shared/widgets/custom_toast.dart';
import 'package:horoscope/features/tarot/tarot_result_screen.dart';
import 'package:horoscope/core/services/limit_service.dart';
import 'package:horoscope/shared/widgets/limit_dialog_helper.dart';

class TarotScreen extends ConsumerStatefulWidget {
  const TarotScreen({super.key});

  @override
  ConsumerState<TarotScreen> createState() => _TarotScreenState();
}

class _TarotScreenState extends ConsumerState<TarotScreen> {
  final List<int> _selectedCardIds = [];
  final Map<int, bool> _cardOrientations = {}; // cardId -> isUpright
  bool _isLoading = false;
  
  // Karıştırma durumları
  bool _isShuffling = true;
  double _shuffleProgress = 0.0;
  int? _hoveredCardIndex;

  late List<int> _deckOrder;
  late ShakeDetector _shakeDetector;

  @override
  void initState() {
    super.initState();
    // 78 kartlık desteyi hazırla ve karıştır
    _shuffleDeck();

    // Shake listener kurulumu
    _shakeDetector = ShakeDetector.autoStart(
      onPhoneShake: () {
        if (_isShuffling && mounted) {
          _triggerShuffleProgress(0.12);
        }
      },
    );
  }

  @override
  void dispose() {
    _shakeDetector.stopListening();
    super.dispose();
  }

  void _shuffleDeck() {
    _deckOrder = List.generate(78, (index) => index);
    _deckOrder.shuffle();
    _selectedCardIds.clear();
    _cardOrientations.clear();
    _shuffleProgress = 0.0;
    _isShuffling = true;
  }

  void _triggerShuffleProgress(double amount) {
    setState(() {
      _shuffleProgress = (_shuffleProgress + amount).clamp(0.0, 1.0);
      if (_shuffleProgress >= 1.0) {
        _isShuffling = false;
        HapticFeedback.heavyImpact();
      } else {
        HapticFeedback.lightImpact();
      }
    });
  }

  void _toggleCardSelection(int cardId) {
    if (_selectedCardIds.contains(cardId)) {
      setState(() {
        _selectedCardIds.remove(cardId);
        _cardOrientations.remove(cardId);
      });
      HapticFeedback.mediumImpact();
    } else {
      if (_selectedCardIds.length >= 7) {
        final isTr = ref.read(languageProvider).languageCode == 'tr';
        CustomToast.show(
          context,
          isTr ? 'En fazla 7 kart seçebilirsiniz.' : 'You can select up to 7 cards.',
        );
        return;
      }
      
      // Fiziksel micro-zamanlamaya dayalı ters kart tayini (upright/reversed)
      final int micro = DateTime.now().microsecond;
      final double drawForce = (micro % 100) / 100.0;
      
      // %15 ile %85 aralığı düz, diğer uçlar ters gelsin (fiziksel kaos taklidi)
      final bool isUpright = drawForce > 0.15 && drawForce < 0.85;

      setState(() {
        _selectedCardIds.add(cardId);
        _cardOrientations[cardId] = isUpright;
      });
      HapticFeedback.lightImpact();
    }
  }

  Future<void> _interpretReading() async {
    final user = ref.read(userProvider);
    if (user == null) return;

    final isTr = ref.read(languageProvider).languageCode == 'tr';

    if (_selectedCardIds.length < 7) {
      CustomToast.show(
        context,
        isTr ? 'Lütfen yorum için 7 adet kart seçin.' : 'Please select 7 cards for reading.',
      );
      return;
    }

    final limitStatus = await LimitService.instance.checkLimit('tarot');
    if (limitStatus == LimitStatus.locked) {
      LimitDialogHelper.showDailyLimitReachedDialog(context: context, ref: ref);
      return;
    } else if (limitStatus == LimitStatus.needAd) {
      LimitDialogHelper.showAdRequiredDialog(
        context: context,
        ref: ref,
        featureKey: 'tarot',
        onAdCompleted: () {
          _executeTarotReading(user, isTr);
        },
      );
      return;
    }

    _executeTarotReading(user, isTr);
  }

  Future<void> _executeTarotReading(dynamic user, bool isTr) async {
    setState(() {
      _isLoading = true;
    });

    try {
      // 7 farklı konu başlığı için draws listesi hazırlayalım
      final positions = ['love', 'career', 'finance', 'health', 'family', 'social', 'future'];
      final List<TarotCardDraw> draws = [];

      for (int i = 0; i < 7; i++) {
        final cardId = _selectedCardIds[i];
        final card = TarotCard.getCardById(cardId);
        draws.add(TarotCardDraw(
          cardId: card.id,
          cardNameTr: card.nameTr,
          cardNameEn: card.nameEn,
          symbol: card.symbol,
          isUpright: _cardOrientations[cardId] ?? true,
          position: positions[i],
        ));
      }

      // AI ile tarot yorumunu hesapla (Natal chart parametresi artık null gönderiliyor)
      final result = await AiService().generateTarotReading(
        userId: user.uid,
        category: 'general', // Kategori seçimi artık kaldırıldı, genel 7'li açılım yapılıyor
        draws: draws,
        user: user,
        userNatalChart: null,
      );

      if (result != null) {
        await LimitService.instance.registerCalculation('tarot');
      }

      if (result != null && mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => TarotResultScreen(reading: result),
          ),
        ).then((_) {
          // Geri dönüldüğünde desteyi sıfırla
          setState(() {
            _shuffleDeck();
          });
        });
      } else {
        if (mounted) {
          CustomToast.show(
            context,
            isTr ? 'Yorum oluşturulurken bir hata oluştu.' : 'Failed to generate tarot reading.',
          );
        }
      }
    } catch (e) {
      debugPrint('⚠️ Tarot yorumlama hatası: $e');
      if (mounted) {
        CustomToast.show(
          context,
          isTr ? 'Bir hata oluştu. Lütfen tekrar deneyin.' : 'An error occurred. Please try again.',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isTr = ref.watch(languageProvider).languageCode == 'tr';

    return Scaffold(
      appBar: AppBar(
        title: Text(isTr ? 'Mistik Tarot Açılımı' : 'Mystic Tarot Spread'),
        actions: [
          IconButton(
            icon: const Icon(Icons.shuffle),
            onPressed: () {
              setState(() {
                _shuffleDeck();
              });
              CustomToast.show(
                context,
                isTr ? 'Kartlar yeniden karıştırıldı.' : 'Cards shuffled.',
              );
            },
          )
        ],
      ),
      body: StarBackground(
        child: Stack(
          children: [
            _isShuffling 
                ? _buildShufflingSection(isTr)
                : _buildDrawingSection(isTr),

            // Yükleme Göstergesi
            if (_isLoading)
              Container(
                color: Colors.black.withValues(alpha: 0.75),
                child: Center(
                  child: GlassCard(
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(
                          width: 48,
                          height: 48,
                          child: CircularProgressIndicator(
                            color: AppColors.primaryGold,
                            strokeWidth: 4,
                          ),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          isTr
                              ? 'Kartların Kozmik Frekansı\nÇözümleniyor...'
                              : 'Analyzing Cosmic Frequency\nof the Cards...',
                          style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // Karıştırma Ritüeli Görünümü
  Widget _buildShufflingSection(bool isTr) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              isTr ? 'Enerjinizi Desteye Aktarın' : 'Channel Your Energy',
              style: AppTextStyles.h2.copyWith(color: AppColors.primaryGold, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              isTr 
                ? 'Telefonunuzu sallayarak ya da desteyi dairesel hareketlerle karıştırarak kartları mistik ritüele hazırlayın.' 
                : 'Shake your phone or drag circularly to mix the cards and connect with their cosmic energy.',
              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
            
            // İnteraktif Dairesel Karıştırma Bölgesi
            GestureDetector(
              onPanUpdate: (details) {
                final dist = details.delta.distance;
                _triggerShuffleProgress(dist / 3200.0);
              },
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 210,
                    height: 210,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.primaryGold.withValues(alpha: 0.12), width: 1.5),
                    ),
                  ).animate(onPlay: (c) => c.repeat()).rotate(duration: 12.seconds),
                  
                  ...List.generate(6, (index) {
                    final double angle = (index - 2.5) * 0.15 + (_shuffleProgress * pi * 2 * (index + 1) * 0.08);
                    return Transform.rotate(
                      angle: angle,
                      child: Container(
                        width: 95,
                        height: 145,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.primaryGold.withValues(alpha: 0.3)),
                          boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 8)],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.asset(
                            'assets/images/tarot_card_back.png',
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
            const SizedBox(height: 40),
            
            // İlerleme Çubuğu
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 250,
                child: LinearProgressIndicator(
                  value: _shuffleProgress,
                  backgroundColor: Colors.white10,
                  color: AppColors.primaryGold,
                  minHeight: 6,
                ),
              ),
            ),
            const SizedBox(height: 32),
            
            // Skip Butonu
            GradientButton(
              height: 42,
              text: isTr ? 'Ritüeli Tamamla 🔮' : 'Complete Ritual 🔮',
              onTap: () {
                setState(() {
                  _shuffleProgress = 1.0;
                  _isShuffling = false;
                  _deckOrder.shuffle();
                  HapticFeedback.heavyImpact();
                });
              },
            ),
          ],
        ),
      ),
    ).animate().fade(duration: 400.ms);
  }

  // Kart Çekme Görünümü (3D Yelpaze)
  Widget _buildDrawingSection(bool isTr) {
    return Column(
      children: [
        const SizedBox(height: 12),
        // 1. Üst Kısım: Seçilen Slotlar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _buildSlotsSection(isTr),
        ),
        const Spacer(),

        // 2. Mistik Başlık
        Text(
          isTr ? 'Mistik Yelpazeden 7 Kart Seçin' : 'Draw 7 Cards from the Fan',
          style: AppTextStyles.caption.copyWith(color: AppColors.primaryGold, letterSpacing: 1.2),
        ).animate().fade(duration: 400.ms),
        const SizedBox(height: 16),

        // 3. 3D Yelpaze Kart Listesi (Fan Spread)
        SizedBox(
          height: 240,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 60),
            itemCount: 78,
            itemBuilder: (context, index) {
              final cardId = _deckOrder[index];
              final isSelected = _selectedCardIds.contains(cardId);
              final selectOrder = _selectedCardIds.indexOf(cardId) + 1;
              final isHovered = _hoveredCardIndex == index;

              // Yelpaze kıvrımı ve mikro etkileşimler
              final double angle = (index - 38.5) * 0.006;
              final double liftOffset = isHovered ? -28.0 : 0.0;

              return GestureDetector(
                onTapDown: (_) {
                  setState(() {
                    _hoveredCardIndex = index;
                  });
                  HapticFeedback.selectionClick();
                },
                onTapCancel: () {
                  setState(() {
                    _hoveredCardIndex = null;
                  });
                },
                onTapUp: (_) {
                  setState(() {
                    _hoveredCardIndex = null;
                  });
                  if (!isSelected) {
                    _toggleCardSelection(cardId);
                  }
                },
                child: Transform.translate(
                  offset: Offset(index > 0 ? -48.0 : 0.0, liftOffset + (index - 38.5).abs() * 0.15),
                  child: Transform.rotate(
                    angle: angle,
                    child: Container(
                      width: 105,
                      height: 175,
                      margin: const EdgeInsets.only(bottom: 24),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected ? AppColors.primaryGold : AppColors.borderLight.withValues(alpha: 0.4),
                          width: isSelected ? 2.5 : 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: isSelected 
                                ? AppColors.primaryGold.withValues(alpha: 0.35)
                                : Colors.black45,
                            blurRadius: isSelected ? 12 : 6,
                            offset: const Offset(2, 4),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Stack(
                          children: [
                            Image.asset(
                              'assets/images/tarot_card_back.png',
                              fit: BoxFit.cover,
                              width: double.infinity,
                              height: double.infinity,
                            ),
                            if (isSelected)
                              Container(
                                color: Colors.black54,
                                child: Center(
                                  child: Container(
                                    width: 26,
                                    height: 26,
                                    decoration: BoxDecoration(
                                      color: AppColors.primaryGold,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Center(
                                      child: Text(
                                        selectOrder.toString(),
                                        style: TextStyle(
                                          color: AppColors.cardSurface,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const Spacer(),

        // 4. Sabit Yorumlama Butonu
        Padding(
          padding: const EdgeInsets.only(left: 20, right: 20, bottom: 24),
          child: Opacity(
            opacity: _selectedCardIds.length == 7 ? 1.0 : 0.5,
            child: AbsorbPointer(
              absorbing: _selectedCardIds.length < 7,
              child: GradientButton(
                text: isTr ? 'Kozmik Açılımı Yorumla 🔮' : 'Interpret Cosmic Spread 🔮',
                onTap: () => _interpretReading(),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // Yuvalar (Slots) Bölümü
  Widget _buildSlotsSection(bool isTr) {
    final positions = [
      isTr ? 'Aşk & İlişkiler' : 'Love & Relations',
      isTr ? 'Kariyer & İş' : 'Career & Work',
      isTr ? 'Maddiyat & Para' : 'Finance & Money',
      isTr ? 'Sağlık & Zihin' : 'Health & Mind',
      isTr ? 'Aile & Ev' : 'Family & Home',
      isTr ? 'Sosyal & Çevre' : 'Social & Friends',
      isTr ? 'Genel Gelecek' : 'General Future',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              isTr ? 'Seçilen Kartlar' : 'Selected Cards',
              style: AppTextStyles.label.copyWith(color: AppColors.primaryGold, fontWeight: FontWeight.bold),
            ),
            Text(
              '${_selectedCardIds.length} / 7',
              style: AppTextStyles.label.copyWith(color: AppColors.primaryGold, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 115,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: 7,
            itemBuilder: (context, index) {
              final cardDrawn = _selectedCardIds.length > index;
              final cardId = cardDrawn ? _selectedCardIds[index] : null;
              final isUpright = cardId != null ? (_cardOrientations[cardId] ?? true) : true;

              return Container(
                width: 76,
                margin: const EdgeInsets.only(right: 10),
                child: Column(
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: cardDrawn ? AppColors.primaryGold.withValues(alpha: 0.05) : AppColors.borderLight.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: cardDrawn ? AppColors.primaryGold.withValues(alpha: 0.7) : AppColors.borderLight,
                            width: cardDrawn ? 1.5 : 1.0,
                          ),
                        ),
                        child: cardDrawn
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Stack(
                                  children: [
                                    Container(
                                      decoration: const BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            Color(0xFF2C243B),
                                            Color(0xFF151021),
                                          ],
                                        ),
                                      ),
                                      child: Center(
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              '✦',
                                              style: TextStyle(
                                                fontSize: 16,
                                                color: AppColors.primaryGold.withValues(alpha: 0.8),
                                              ),
                                            ),
                                            Text(
                                              isTr ? 'Seçildi' : 'Drawn',
                                              style: AppTextStyles.caption.copyWith(
                                                fontSize: 8,
                                                fontWeight: FontWeight.bold,
                                                color: AppColors.primaryGold,
                                              ),
                                            ),
                                            if (!isUpright) ...[
                                              const SizedBox(height: 2),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                                decoration: BoxDecoration(
                                                  color: Colors.redAccent.withValues(alpha: 0.2),
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  isTr ? 'Ters' : 'Rev.',
                                                  style: const TextStyle(fontSize: 6, color: Colors.redAccent, fontWeight: FontWeight.bold),
                                                ),
                                              ),
                                            ]
                                          ],
                                        ),
                                      ),
                                    ),
                                    // Kaldırma Butonu
                                    Positioned(
                                      top: 2,
                                      right: 2,
                                      child: GestureDetector(
                                        onTap: () => _toggleCardSelection(cardId!),
                                        child: Container(
                                          padding: const EdgeInsets.all(2),
                                          decoration: const BoxDecoration(
                                            color: Colors.black54,
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(Icons.close, size: 8, color: Colors.white70),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ).animate().scale(duration: 400.ms, curve: Curves.easeOutBack).slideY(begin: 1.2, end: 0.0)
                            : const Center(
                                child: Icon(Icons.add, color: Colors.white24, size: 16),
                              ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      positions[index],
                      style: AppTextStyles.caption.copyWith(fontSize: 8, color: AppColors.textSecondary),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
