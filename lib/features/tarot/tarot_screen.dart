import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
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
  String _selectedCategory = 'general';
  final List<int> _selectedCardIds = [];
  final Map<int, bool> _cardOrientations = {}; // cardId -> isUpright
  bool _isLoading = false;
  final Random _random = Random();

  // Kart karıştırma durumu
  late List<int> _deckOrder;

  @override
  void initState() {
    super.initState();
    // 22 kartı karıştır
    _shuffleDeck();
  }

  void _shuffleDeck() {
    _deckOrder = List.generate(22, (index) => index);
    _deckOrder.shuffle();
    _selectedCardIds.clear();
    _cardOrientations.clear();
  }

  void _toggleCardSelection(int cardId) {
    if (_selectedCardIds.contains(cardId)) {
      setState(() {
        _selectedCardIds.remove(cardId);
        _cardOrientations.remove(cardId);
      });
      HapticFeedback.mediumImpact();
    } else {
      if (_selectedCardIds.length >= 3) {
        final isTr = ref.read(languageProvider).languageCode == 'tr';
        CustomToast.show(
          context,
          isTr ? 'En fazla 3 kart seçebilirsiniz.' : 'You can select up to 3 cards.',
        );
        return;
      }
      setState(() {
        _selectedCardIds.add(cardId);
        // %85 olasılıkla düz (upright), %15 olasılıkla ters (reversed) gelsin
        _cardOrientations[cardId] = _random.nextDouble() > 0.15;
      });
      HapticFeedback.lightImpact();
    }
  }

  Future<void> _interpretReading() async {
    final user = ref.read(userProvider);
    if (user == null) return;

    final isTr = ref.read(languageProvider).languageCode == 'tr';

    if (_selectedCardIds.length < 3) {
      CustomToast.show(
        context,
        isTr ? 'Lütfen yorum için 3 adet kart seçin.' : 'Please select 3 cards for reading.',
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
      // 1. Kullanıcının harita verilerini yükle/hesapla
      final userNatalChart = await AiService().calculateAndSaveNatalChart(
        userId: user.uid,
        name: user.name ?? 'Kullanıcı',
        birthDate: user.birthDate ?? DateTime(2000, 1, 1),
        birthTime: user.birthTime ?? '12:00',
        birthPlace: user.birthPlace ?? 'İstanbul',
        gender: user.gender,
      );

      // 2. Seçilen kart draw'larını pozisyonlarına göre hazırla
      final positions = ['past', 'present', 'future'];
      final List<TarotCardDraw> draws = [];

      for (int i = 0; i < 3; i++) {
        final cardId = _selectedCardIds[i];
        final card = TarotCard.majorArcana.firstWhere((x) => x.id == cardId);
        draws.add(TarotCardDraw(
          cardId: card.id,
          cardNameTr: card.nameTr,
          cardNameEn: card.nameEn,
          symbol: card.symbol,
          isUpright: _cardOrientations[cardId] ?? true,
          position: positions[i],
        ));
      }

      // 3. AI ile tarot yorumunu hesapla
      final result = await AiService().generateTarotReading(
        userId: user.uid,
        category: _selectedCategory,
        draws: draws,
        user: user,
        userNatalChart: userNatalChart,
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
        );
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

    final categories = [
      {'id': 'general', 'nameTr': 'Kozmik Tavsiye', 'nameEn': 'Cosmic Guidance', 'icon': '🔮'},
      {'id': 'love', 'nameTr': 'Aşk & İlişkiler', 'nameEn': 'Love & Relationships', 'icon': '💘'},
      {'id': 'career', 'nameTr': 'Kariyer & Finans', 'nameEn': 'Career & Finance', 'icon': '💼'},
      {'id': 'health', 'nameTr': 'Sağlık & Enerji', 'nameEn': 'Health & Energy', 'icon': '🌱'},
      {'id': 'decision', 'nameTr': 'Karar Verme / Yol Ayrımı', 'nameEn': 'Decision Making', 'icon': '🚦'},
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(isTr ? 'Tarot Açılımı' : 'Tarot Spread'),
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
            SingleChildScrollView(
              padding: const EdgeInsets.only(left: 20, right: 20, top: 10, bottom: 100),
              child: Column(
                children: [
                  // 1. Kategori Seçici
                  GlassCard(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        Text(
                          isTr ? 'Odak Noktanız:' : 'Your Focus:',
                          style: AppTextStyles.label.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _selectedCategory,
                              isExpanded: true,
                              dropdownColor: AppColors.cardSurface,
                              // selectedItemBuilder: buton içindeki görüntü için (Expanded çalışır)
                              selectedItemBuilder: (context) => categories.map((cat) {
                                return Align(
                                  alignment: Alignment.centerLeft,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(cat['icon']!, style: const TextStyle(fontSize: 16)),
                                      const SizedBox(width: 8),
                                      Flexible(
                                        child: Text(
                                          isTr ? cat['nameTr']! : cat['nameEn']!,
                                          style: AppTextStyles.bodyMedium.copyWith(color: AppColors.primaryGold),
                                          overflow: TextOverflow.ellipsis,
                                          maxLines: 1,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                              // items: popup menüsündeki maddeler (Row yok, taşma yok)
                              items: categories.map((cat) {
                                return DropdownMenuItem<String>(
                                  value: cat['id'],
                                  child: Text(
                                    '${cat['icon']}  ${isTr ? cat['nameTr']! : cat['nameEn']!}',
                                    style: AppTextStyles.bodyMedium.copyWith(color: AppColors.primaryGold),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
                                );
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() {
                                    _selectedCategory = val;
                                  });
                                }
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 2. Çekilen Kart Yuvaları
                  _buildSlotsSection(isTr),
                  const SizedBox(height: 24),

                  // 3. Kapalı Kartların Dizilimi
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 4.0),
                      child: Text(
                        isTr ? 'Mistik Kartlar' : 'Mystical Cards',
                        style: AppTextStyles.h3,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 12,
                      childAspectRatio: 0.65,
                    ),
                    itemCount: 22,
                    itemBuilder: (context, index) {
                      final cardId = _deckOrder[index];
                      final isSelected = _selectedCardIds.contains(cardId);
                      final selectOrder = _selectedCardIds.indexOf(cardId) + 1;

                      return GestureDetector(
                        onTap: () => _toggleCardSelection(cardId),
                        child: AnimatedContainer(
                          duration: 250.ms,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isSelected ? AppColors.primaryGold : AppColors.borderLight,
                              width: isSelected ? 2.0 : 1.0,
                            ),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: AppColors.primaryGold.withValues(alpha: 0.4),
                                      blurRadius: 10,
                                      spreadRadius: 1,
                                    )
                                  ]
                                : null,
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Stack(
                              children: [
                                // Kart Arka Yüz Tasarımı (Premium Glassmorphic Pattern)
                                Container(
                                  decoration: const BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Color(0xFF1F1B2C),
                                        Color(0xFF0F0C1B),
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                  ),
                                  child: Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.star_border_rounded,
                                          size: 24,
                                          color: AppColors.primaryGold.withValues(alpha: 0.6),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '✦',
                                          style: TextStyle(
                                            fontSize: 16,
                                            color: AppColors.primaryGold.withValues(alpha: 0.4),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                // Seçim sırası rozeti
                                if (isSelected)
                                  Positioned(
                                    top: 6,
                                    right: 6,
                                    child: Container(
                                      width: 20,
                                      height: 20,
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
                                            fontSize: 11,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),

            // Sabit Yorumlama Butonu
            Positioned(
              bottom: 24,
              left: 20,
              right: 20,
              child: Opacity(
                opacity: _selectedCardIds.length == 3 ? 1.0 : 0.5,
                child: AbsorbPointer(
                  absorbing: _selectedCardIds.length < 3,
                  child: GradientButton(
                    text: isTr ? 'Kozmik Açılımı Yorumla 🔮' : 'Interpret Cosmic Spread 🔮',
                    onTap: () => _interpretReading(),
                  ),
                ),
              ),
            ),

            // Yükleme Göstergesi
            if (_isLoading)
              Container(
                color: Colors.black54,
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

  // Yuva Tasarımları
  Widget _buildSlotsSection(bool isTr) {
    final positions = [
      isTr ? '1. Durum / Geçmiş' : '1. State / Past',
      isTr ? '2. Engel / Şimdi' : '2. Obstacle / Present',
      isTr ? '3. Tavsiye / Gelecek' : '3. Advice / Future',
    ];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(3, (index) {
        final cardDrawn = _selectedCardIds.length > index;
        final cardId = cardDrawn ? _selectedCardIds[index] : null;
        final isUpright = cardId != null ? (_cardOrientations[cardId] ?? true) : true;

        return Expanded(
          child: Container(
            margin: EdgeInsets.only(
              left: index == 0 ? 0 : 6,
              right: index == 2 ? 0 : 6,
            ),
            child: Column(
              children: [
                AspectRatio(
                  aspectRatio: 0.65,
                  child: Container(
                    decoration: BoxDecoration(
                      color: cardDrawn ? AppColors.primaryGold.withValues(alpha: 0.05) : AppColors.borderLight.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: cardDrawn ? AppColors.primaryGold.withValues(alpha: 0.7) : AppColors.borderLight,
                        width: cardDrawn ? 1.5 : 1.0,
                        style: cardDrawn ? BorderStyle.solid : BorderStyle.solid,
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
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                  ),
                                  child: Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          '✦',
                                          style: TextStyle(
                                            fontSize: 22,
                                            color: AppColors.primaryGold.withValues(alpha: 0.8),
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          isTr ? 'Seçildi' : 'Selected',
                                          style: AppTextStyles.caption.copyWith(
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.primaryGold,
                                          ),
                                        ),
                                        if (!isUpright) ...[
                                          const SizedBox(height: 4),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                            decoration: BoxDecoration(
                                              color: Colors.redAccent.withValues(alpha: 0.2),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              isTr ? 'Ters' : 'Rev.',
                                              style: const TextStyle(fontSize: 8, color: Colors.redAccent, fontWeight: FontWeight.bold),
                                            ),
                                          ),
                                        ]
                                      ],
                                    ),
                                  ),
                                ),
                                // Çıkarma Butonu
                                Positioned(
                                  top: 4,
                                  right: 4,
                                  child: GestureDetector(
                                    onTap: () => _toggleCardSelection(cardId!),
                                    child: Container(
                                      padding: const EdgeInsets.all(2),
                                      decoration: const BoxDecoration(
                                        color: Colors.black54,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.close, size: 10, color: Colors.white70),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )
                        : Center(
                            child: Icon(Icons.add, color: AppColors.textSecondary.withValues(alpha: 0.5), size: 20),
                          ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  positions[index],
                  style: AppTextStyles.caption.copyWith(fontSize: 8, color: AppColors.textSecondary),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      }),
    );
  }
}
