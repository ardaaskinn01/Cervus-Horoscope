import 'dart:math';
import 'dart:ui';
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
import 'package:horoscope/core/services/ai_service.dart';
import 'package:horoscope/shared/widgets/custom_toast.dart';
import 'package:horoscope/shared/widgets/limit_dialog_helper.dart';

class TarotResultScreen extends ConsumerStatefulWidget {
  final TarotReadingModel reading;

  const TarotResultScreen({super.key, required this.reading});

  @override
  ConsumerState<TarotResultScreen> createState() => _TarotResultScreenState();
}

class _TarotResultScreenState extends ConsumerState<TarotResultScreen> {
  // Kartların açılıp açılmadığı durumları tutan dinamik liste
  late final List<bool> _isFlipped;

  // Pro Deepening Chat durumları
  final List<Map<String, String>> _chatHistory = [];
  int _remainingQuestions = 3;
  bool _isChatGenerating = false;
  final _chatController = TextEditingController();
  final _chatFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _isFlipped = List.generate(widget.reading.draws.length, (index) => false);
  }

  @override
  void dispose() {
    _chatController.dispose();
    _chatFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isTr = ref.watch(languageProvider).languageCode == 'tr';
    final user = ref.watch(userProvider);

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

              // ── 1. Kart Yayılımı (Yatay Kaydırılabilir Şerit) ─────────────────
              SizedBox(
                height: 205,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: widget.reading.draws.length,
                  itemBuilder: (context, index) {
                    final draw = widget.reading.draws[index];
                    
                    // Pozisyon başlıklarını haritalandır (Geriye dönük uyumluluk dahil)
                    final String positionLabel;
                    if (draw.position == 'love') {
                      positionLabel = isTr ? 'Aşk & İlişkiler' : 'Love & Relations';
                    } else if (draw.position == 'career') {
                      positionLabel = isTr ? 'Kariyer & İş' : 'Career & Work';
                    } else if (draw.position == 'finance') {
                      positionLabel = isTr ? 'Maddiyat & Para' : 'Finance & Money';
                    } else if (draw.position == 'health') {
                      positionLabel = isTr ? 'Sağlık & Zihin' : 'Health & Mind';
                    } else if (draw.position == 'family') {
                      positionLabel = isTr ? 'Aile & Ev' : 'Family & Home';
                    } else if (draw.position == 'social') {
                      positionLabel = isTr ? 'Sosyal & Çevre' : 'Social & Friends';
                    } else if (draw.position == 'future') {
                      positionLabel = isTr ? 'Genel Gelecek' : 'General Future';
                    } else {
                      // Eski okumaların konum başlıkları (Geçmiş, Şimdi, Gelecek)
                      positionLabel = draw.position == 'past'
                          ? (isTr ? 'Durum / Geçmiş' : 'Past')
                          : (draw.position == 'present'
                              ? (isTr ? 'Engel / Şimdi' : 'Present')
                              : (isTr ? 'Tavsiye / Gelecek' : 'Future'));
                    }

                    return Container(
                      width: 110,
                      margin: const EdgeInsets.only(right: 12),
                      child: Column(
                        children: [
                          Text(
                            positionLabel,
                            style: AppTextStyles.caption.copyWith(fontSize: 8, fontWeight: FontWeight.bold),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
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
                    );
                  },
                ),
              ),
              const SizedBox(height: 32),

              // ── 2. AI Kozmik Yorum Kartları ──────────────────────────────
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  isTr ? '🔮 Mistik Analiz' : '🔮 Mystical Analysis',
                  style: AppTextStyles.h3.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 12),
              
              ...() {
                final commentText = isTr ? widget.reading.commentTr : widget.reading.commentEn;
                final parsedSections = _parseCommentSections(commentText);
                final drawsLength = widget.reading.draws.length;

                if (parsedSections.length == drawsLength) {
                  // Her bir çekilen karta karşılık gelen yorum kartı listelenir
                  return List.generate(drawsLength, (index) {
                    final section = parsedSections[index];
                    final isFlipped = _isFlipped[index];

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16.0),
                      child: GlassCard(
                        padding: const EdgeInsets.all(18),
                        child: _buildSectionText(
                          section['title'] ?? '',
                          section['content'] ?? '',
                          isFlipped,
                          isTr,
                        ),
                      ),
                    ).animate().fade(duration: 500.ms, delay: (index * 80).ms);
                  });
                } else {
                  // Geriye dönük uyumluluk: Tek parça yorum ise, en az bir kart açılana kadar blurla
                  final bool anyFlipped = _isFlipped.any((x) => x == true);
                  return [
                    GlassCard(
                      padding: const EdgeInsets.all(18),
                      child: _buildSectionText(
                        '',
                        commentText,
                        anyFlipped,
                        isTr,
                      ),
                    ).animate().fade(duration: 600.ms, delay: 200.ms)
                  ];
                }
              }(),
              const SizedBox(height: 32),

              // ── 3. Pro Soru Sorma Arayüzü (Deepening Chat) ─────────────
              _buildDeepeningChatSection(isTr, user),
              const SizedBox(height: 40),

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
    // 78 kartlık allCards listesinden ID'ye göre kartı bulur
    final card = TarotCard.getCardById(draw.cardId);
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
              child: RotatedBox(
                quarterTurns: draw.isUpright ? 0 : 2,
                child: Image.asset(
                  'assets/images/tarot/${card.imageName}',
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
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
          ),
          
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

  // Pro Deepening Chat Arayüzü
  Widget _buildDeepeningChatSection(bool isTr, UserModel? user) {
    final isPremium = user?.isAnyPremium ?? false;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              isTr ? '🔮 Bilgeye Soru Sor' : '🔮 Ask the Sage',
              style: AppTextStyles.h3.copyWith(color: AppColors.primaryGold, fontWeight: FontWeight.bold),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primaryGold.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                isTr ? 'Hak: $_remainingQuestions/3' : 'Remaining: $_remainingQuestions/3',
                style: AppTextStyles.caption.copyWith(color: AppColors.primaryGold, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        
        // Sohbet Geçmişi Balonları
        if (_chatHistory.isNotEmpty) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.cardSurface.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.borderLight),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: _chatHistory.map((msg) {
                final isUser = msg['role'] == 'user';
                return Align(
                  alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isUser 
                          ? Colors.deepPurple.withValues(alpha: 0.25)
                          : AppColors.cardSurface.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(12),
                        topRight: const Radius.circular(12),
                        bottomLeft: isUser ? const Radius.circular(12) : Radius.zero,
                        bottomRight: isUser ? Radius.zero : const Radius.circular(12),
                      ),
                      border: Border.all(
                        color: isUser 
                            ? Colors.deepPurpleAccent.withValues(alpha: 0.3)
                            : AppColors.borderLight,
                      ),
                    ),
                    child: Text(
                      msg['content'] ?? '',
                      style: AppTextStyles.bodyMedium,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Input / Kilit Durum Panelleri
        if (!isPremium && _chatHistory.isEmpty) ...[
          _buildLockOverlay(isTr)
        ] else ...[
          _buildChatInputArea(isTr, user),
        ],
      ],
    );
  }

  Widget _buildLockOverlay(bool isTr) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      child: Center(
        child: Column(
          children: [
            const Icon(Icons.lock_rounded, color: AppColors.primaryGold, size: 36),
            const SizedBox(height: 12),
            Text(
              isTr ? 'Kozmik Bilgeye Sorularını Sor 💎' : 'Ask Questions to Cosmic Sage 💎',
              style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.bold, color: AppColors.primaryGold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              isTr 
                ? 'Açılımınız hakkında Kâhin\'e ek sorular sorarak analizi derinleştirin (Maks. 3 Soru).'
                : 'Ask follow-up questions to the Sage to deepen your reading analysis (Max 3 Questions).',
              style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            GradientButton(
              height: 38,
              text: isTr ? 'Premium ile Kilidi Aç 🔓' : 'Unlock with Premium 🔓',
              onTap: () {
                LimitDialogHelper.showDailyLimitReachedDialog(context: context, ref: ref);
              },
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () {
                LimitDialogHelper.showAdRequiredDialog(
                  context: context,
                  ref: ref,
                  featureKey: 'tarot',
                  onAdCompleted: () {
                    setState(() {
                      // Kilit açma simülasyonu olarak 1 soru hakkı tanımlanır
                      _remainingQuestions = 1;
                    });
                    CustomToast.show(context, isTr ? '1 Soru hakkı kazandınız!' : 'You earned 1 question credit!');
                  },
                );
              },
              child: Text(
                isTr ? 'Veya Reklam İzleyerek 1 Hak Kazan' : 'Or Watch Ad to Earn 1 Credit',
                style: AppTextStyles.caption.copyWith(color: AppColors.primaryGold, decoration: TextDecoration.underline),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChatInputArea(bool isTr, UserModel? user) {
    if (_remainingQuestions <= 0) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Text(
            isTr ? 'Tüm ek soru haklarınızı kullandınız.' : 'You have used all follow-up questions.',
            style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
          ),
        ),
      );
    }

    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _chatController,
            focusNode: _chatFocusNode,
            style: AppTextStyles.bodyMedium,
            decoration: InputDecoration(
              hintText: isTr ? 'Kozmik bilgeye sor...' : 'Ask the cosmic sage...',
              hintStyle: AppTextStyles.caption.copyWith(color: Colors.white30),
              filled: true,
              fillColor: AppColors.cardSurface,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: BorderSide(color: AppColors.borderLight),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: const BorderSide(color: AppColors.primaryGold),
              ),
            ),
            onSubmitted: (_) => _submitFollowUpQuestion(isTr, user),
          ),
        ),
        const SizedBox(width: 8),
        _isChatGenerating
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(color: AppColors.primaryGold, strokeWidth: 2),
              )
            : Container(
                decoration: BoxDecoration(
                  gradient: AppColors.goldGradient,
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: Icon(Icons.send_rounded, color: AppColors.cardSurface, size: 18),
                  onPressed: () => _submitFollowUpQuestion(isTr, user),
                ),
              ),
      ],
    );
  }

  Future<void> _submitFollowUpQuestion(bool isTr, UserModel? user) async {
    if (user == null) return;
    final question = _chatController.text.trim();
    if (question.isEmpty || _isChatGenerating || _remainingQuestions <= 0) return;

    setState(() {
      _isChatGenerating = true;
      _chatHistory.add({'role': 'user', 'content': question});
    });

    _chatController.clear();
    _chatFocusNode.unfocus();

    try {
      final response = await AiService().answerTarotFollowUpQuestion(
        reading: widget.reading,
        chatHistory: _chatHistory,
        userQuestion: question,
        user: user,
      );

      if (mounted) {
        setState(() {
          _isChatGenerating = false;
          _remainingQuestions--;
          if (response != null) {
            _chatHistory.add({'role': 'model', 'content': response});
          } else {
            _chatHistory.add({
              'role': 'model',
              'content': isTr 
                  ? 'Kozmik frekansta bir parazit oluştu. Lütfen tekrar deneyin.'
                  : 'An interference occurred in the cosmic frequency. Please try again.'
            });
          }
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isChatGenerating = false;
          _chatHistory.add({
            'role': 'model',
            'content': isTr 
                ? 'Bir bağlantı hatası oluştu.'
                : 'A connection error occurred.'
          });
        });
      }
    }
  }

  List<Map<String, String>> _parseCommentSections(String commentText) {
    final List<Map<String, String>> sections = [];
    final lines = commentText.split('\n');
    String currentTitle = '';
    List<String> currentContentLines = [];

    for (var line in lines) {
      final trimmed = line.trim();
      if (trimmed.startsWith('###')) {
        if (currentTitle.isNotEmpty || currentContentLines.isNotEmpty) {
          sections.add({
            'title': currentTitle,
            'content': currentContentLines.join('\n').trim(),
          });
        }
        currentTitle = trimmed.replaceFirst('###', '').trim();
        currentContentLines = [];
      } else {
        if (trimmed.isNotEmpty || currentContentLines.isNotEmpty) {
          currentContentLines.add(line);
        }
      }
    }

    if (currentTitle.isNotEmpty || currentContentLines.isNotEmpty) {
      sections.add({
        'title': currentTitle,
        'content': currentContentLines.join('\n').trim(),
      });
    }

    return sections;
  }

  Widget _buildSectionText(String title, String content, bool isFlipped, bool isTr) {
    if (isFlipped) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title.isNotEmpty) ...[
            Text(
              title,
              style: AppTextStyles.bodyLarge.copyWith(color: AppColors.primaryGold, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
          ],
          Text(
            content,
            style: AppTextStyles.bodyMedium.copyWith(height: 1.65),
          ),
        ],
      );
    } else {
      // Blurred state with mask overlay
      return Stack(
        alignment: Alignment.center,
        children: [
          ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 7.0, sigmaY: 7.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title.isNotEmpty) ...[
                  Text(
                    title,
                    style: AppTextStyles.bodyLarge.copyWith(color: AppColors.primaryGold, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                ],
                Text(
                  "${content.substring(0, min(content.length, 140))}...",
                  style: AppTextStyles.bodyMedium.copyWith(height: 1.65),
                ),
              ],
            ),
          ),
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.remove_red_eye_outlined, color: AppColors.primaryGold, size: 28),
              const SizedBox(height: 6),
              Text(
                isTr ? 'Yorumu görmek için yukarıdan kartı çevirin' : 'Flip the card above to reveal commentary',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.primaryGold,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                  shadows: const [Shadow(color: Colors.black, blurRadius: 4)],
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ],
      );
    }
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
