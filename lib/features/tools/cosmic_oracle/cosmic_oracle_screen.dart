import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:horoscope/core/constants/app_colors.dart';
import 'package:horoscope/core/constants/app_text_styles.dart';
import 'package:horoscope/core/models/natal_chart_model.dart';
import 'package:horoscope/core/models/user_model.dart';
import 'package:horoscope/core/providers/language_provider.dart';
import 'package:horoscope/core/providers/user_provider.dart';
import 'package:horoscope/core/services/ai_service.dart';
import 'package:horoscope/shared/widgets/custom_toast.dart';
import 'package:horoscope/shared/widgets/gradient_button.dart';
import 'package:horoscope/shared/widgets/star_background.dart';
import 'package:horoscope/core/services/ad_service.dart';

// Impeller OpenGLES BackdropFilter çökme hatasını önlemek için tasarlanmış özel cam görünümlü kart.
// BackdropFilter yerine hafif opak arka plan kullanarak çökme riskini tamamen sıfırlar.
class GlassContainer extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double borderRadius;
  final Color? color;
  final Border? border;

  const GlassContainer({
    super.key,
    required this.child,
    this.padding,
    this.borderRadius = 16.0,
    this.color,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding ?? const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: color ?? AppColors.cardSurface.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(borderRadius),
        border: border ??
            Border.all(
              color: AppColors.borderLight,
              width: 1,
            ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 20,
            spreadRadius: -2,
          ),
        ],
      ),
      child: child,
    );
  }
}

class CosmicOracleScreen extends ConsumerStatefulWidget {
  const CosmicOracleScreen({super.key});

  @override
  ConsumerState<CosmicOracleScreen> createState() => _CosmicOracleScreenState();
}

class _CosmicOracleScreenState extends ConsumerState<CosmicOracleScreen> {
  final _questionController = TextEditingController();
  final _scrollController = ScrollController();
  final _focusNode = FocusNode();
  
  List<Map<String, dynamic>> _history = [];
  bool _isLoadingHistory = true;
  bool _isGenerating = false;
  int _questionsAskedToday = 0;
  bool _rewardedAdWatchedToday = false;
  bool _needAdToAsk = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadHistoryData();
    });
  }

  @override
  void dispose() {
    _questionController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }


  Future<void> _loadHistoryData() async {
    final user = ref.read(userProvider);
    if (user == null) return;

    setState(() {
      _isLoadingHistory = true;
    });

    try {
      final history = await AiService().getCosmicOracleHistory(user.uid);
      final limitInfo = await AiService().checkCosmicOracleLimit(user.uid);
      if (mounted) {
        setState(() {
          _history = history;
          _questionsAskedToday = limitInfo['questionsAsked'] ?? 0;
          _rewardedAdWatchedToday = limitInfo['rewardedWatched'] ?? false;
          _needAdToAsk = limitInfo['needAd'] ?? false;
          _isLoadingHistory = false;
        });
        _scrollToBottom(delayMs: 200);
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoadingHistory = false;
        });
      }
    }
  }

  void _scrollToBottom({int delayMs = 100}) {
    Future.delayed(Duration(milliseconds: delayMs), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // Premium Üyelik Teşvik Dialogu
  void _showPremiumLimitDialog(bool isTr) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: GlassContainer(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  '🌌',
                  style: TextStyle(fontSize: 48),
                ).animate().scale(duration: 400.ms, curve: Curves.elasticOut),
                const SizedBox(height: 16),
                Text(
                  isTr ? 'Kozmik Limit Aşıldı!' : 'Cosmic Limit Reached!',
                  style: AppTextStyles.h3.copyWith(color: AppColors.primaryGold, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  isTr
                      ? 'Kozmik Kâhine günde 1 soru sorma hakkınız bulunmaktadır. Soru sınırınızı günde 10 soruya çıkarmak ve tüm premium astroloji araçlarını sınırsız kullanmak için Yıldız Üyeliğine geçin!'
                      : 'You have 1 cosmic query per day. Upgrade to Star Membership to ask up to 10 questions daily and unlock all premium astrological features!',
                  style: AppTextStyles.bodyMedium.copyWith(height: 1.45),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  isTr
                      ? 'Soru haklarınız her sabah 04:00\'da sıfırlanır.'
                      : 'Daily question quotas reset every morning at 04:00 AM.',
                  style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(
                          isTr ? 'Daha Sonra' : 'Maybe Later',
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: GradientButton(
                        text: isTr ? 'Keşfet' : 'Explore',
                        onTap: () {
                          Navigator.pop(context);
                          CustomToast.show(
                            context,
                            isTr ? 'Premium paketler çok yakında!' : 'Premium bundles coming soon!',
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Soru sorma tetikleyicisi
  Future<void> _submitQuestion() async {
    final user = ref.read(userProvider);
    if (user == null) return;

    final isTr = ref.read(languageProvider).languageCode == 'tr';
    final questionText = _questionController.text.trim();
    if (questionText.isEmpty) return;

    // Günlük limit kontrolü
    final limitInfo = await AiService().checkCosmicOracleLimit(user.uid);
    if (limitInfo['allowed'] == false) {
      _focusNode.unfocus();
      _showPremiumLimitDialog(isTr);
      return;
    }

    setState(() {
      _isGenerating = true;
    });

    _questionController.clear();
    _focusNode.unfocus();

    // Geçici olarak soruyu ekrana ekle (AskedAt: now)
    final tempEntry = {
      'question': questionText,
      'answerTr': '',
      'answerEn': '',
      'askedAt': DateTime.now(),
      'isTemp': true, // Yükleniyor durumunu görselleştirmek için
    };

    setState(() {
      _history.insert(0, tempEntry); // En son soru en altta kalacak şekilde ters sıralı history listesinden dolayı ekle
      _scrollToBottom();
    });

    try {
      // Doğum haritası bilgilerini Firestore'dan çekelim
      final natalChartDoc = await FirebaseFirestore.instance.doc('users/${user.uid}/natal_chart/data').get();
      NatalChartModel? natalChart;
      if (natalChartDoc.exists && natalChartDoc.data() != null) {
        natalChart = NatalChartModel.fromMap(natalChartDoc.data()!);
      }

      final result = await AiService().generateCosmicOracleResponse(
        userId: user.uid,
        question: questionText,
        user: user,
        natalChart: natalChart,
      );

      if (result != null && mounted) {
        // Firestore'dan limitleri ve geçmişi yeniden çek
        await _loadHistoryData();
      } else {
        _handleError(isTr);
      }
    } catch (_) {
      _handleError(isTr);
    }
  }

  void _handleError(bool isTr) {
    if (mounted) {
      setState(() {
        _history.removeWhere((item) => item['isTemp'] == true);
        _isGenerating = false;
      });
      CustomToast.show(
        context,
        isTr ? 'Gök kubbe ile bağlantı kurulamadı. Lütfen tekrar deneyin.' : 'Could not connect with the stars. Please try again.',
        isError: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(languageProvider);
    final isTr = locale.languageCode == 'tr';
    final user = ref.watch(userProvider);
    
    // Geriye kalan hak miktarı
    int displayQuota = 0;
    if (_questionsAskedToday == 0) {
      displayQuota = 1;
    } else if (_questionsAskedToday == 1 && _rewardedAdWatchedToday) {
      displayQuota = 1;
    }

    final int totalQuota = 1 + (_rewardedAdWatchedToday ? 1 : 0);
    final bool needRewardedAd = _needAdToAsk && !_rewardedAdWatchedToday;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(isTr ? 'Kozmik Kâhin' : 'Cosmic Oracle'),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: StarBackground(
        child: SafeArea(
          child: Column(
            children: [
              // 1. Üst Kota Göstergesi & Bilgi Paneli
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: GlassContainer(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(
                    children: [
                      const Icon(Icons.stars_rounded, color: AppColors.primaryGold, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isTr ? 'Soru Hakkı: $displayQuota / $totalQuota' : 'Queries Left: $displayQuota / $totalQuota',
                              style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.bold),
                            ),
                            Text(
                              isTr 
                                  ? (needRewardedAd ? 'Ek hak almak için reklam izleyebilirsiniz.' : 'Haklar her sabah 04:00\'da yenilenir.')
                                  : (needRewardedAd ? 'Watch ad for +1 query.' : 'Resets daily at 04:00 AM.'),
                              style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary, fontSize: 9.5),
                            ),
                          ],
                        ),
                      ),
                      if (displayQuota == 0) ...[
                        GestureDetector(
                          onTap: () => _showPremiumLimitDialog(isTr),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              gradient: AppColors.goldGradient,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.workspace_premium_rounded, color: AppColors.cardSurface, size: 14),
                                const SizedBox(width: 4),
                                Text(
                                  isTr ? 'Yükselt' : 'Upgrade',
                                  style: AppTextStyles.caption.copyWith(
                                    color: AppColors.cardSurface,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ).animate().shimmer(delay: 1.seconds, duration: 1.5.seconds),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              // 2. Chat / Mesaj Geçmişi Alanı
              Expanded(
                child: _isLoadingHistory
                    ? const Center(
                        child: CircularProgressIndicator(color: AppColors.primaryGold),
                      )
                    : _history.isEmpty
                        ? _buildWelcomeState(isTr)
                        : _buildChatList(isTr),
              ),

              // Reklam Banner'ı
              AdService.instance.getBannerAdWidget('cosmic_oracle_banner', isPremium: user?.isPremium ?? false),

              // 3. Soru Giriş Alanı
              _buildInputArea(isTr, displayQuota, user),
            ],
          ),
        ),
      ),
    );
  }

  // Karşılama Ekranı
  Widget _buildWelcomeState(bool isTr) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              '🔮',
              style: TextStyle(fontSize: 64),
            ).animate().slideY(begin: 0.1, duration: 600.ms, curve: Curves.easeOutBack),
            const SizedBox(height: 16),
            Text(
              isTr ? 'Kozmik Kâhin\'e Sor' : 'Ask the Cosmic Oracle',
              style: AppTextStyles.h3.copyWith(color: AppColors.primaryGold, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            GlassContainer(
              padding: const EdgeInsets.all(16),
              child: Text(
                isTr
                    ? 'Kişisel doğum haritanız ve astrolojik potansiyelinizin ışığında, sormak istediğiniz soruları kâhine sorun. Kozmik kâhin sizin için yıldızları yorumlayacaktır.'
                    : 'Ask the oracle questions close to your heart. Using your personalized birth chart and celestial configurations, the oracle will read the stars for you.',
                style: AppTextStyles.bodyMedium.copyWith(height: 1.45),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Chat Listesi
  Widget _buildChatList(bool isTr) {
    // History listemiz Firestore'dan en yeni en üstte olacak şekilde geliyor (sort by askedAt desc).
    // Ancak sohbet akışı için en eski en üstte, en yeni en altta olmalıdır.
    final chatItems = List<Map<String, dynamic>>.from(_history.reversed);

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: chatItems.length + (_isGenerating ? 1 : 0),
      itemBuilder: (context, index) {
        // En sondaki kâhin düşünüyor animasyonu
        if (index == chatItems.length) {
          return _buildThinkingBubble(isTr);
        }

        final item = chatItems[index];
        final isTemp = item['isTemp'] == true;
        final String question = item['question'] ?? '';
        final String answer = isTr
            ? (item['answerTr'] ?? '')
            : (item['answerEn'] ?? '');
        final askedAt = item['askedAt'] != null
            ? (item['askedAt'] is Timestamp
                ? (item['askedAt'] as Timestamp).toDate()
                : item['askedAt'] as DateTime)
            : DateTime.now();

        final String timeStr = DateFormat('HH:mm').format(askedAt);

        return Column(
          children: [
            // Kullanıcı Sorusu
            Align(
              alignment: Alignment.centerRight,
              child: Container(
                margin: const EdgeInsets.only(left: 48, bottom: 4, top: 12),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.deepPurple.withValues(alpha: 0.25),
                      Colors.indigo.withValues(alpha: 0.2),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                    bottomLeft: Radius.circular(16),
                  ),
                  border: Border.all(color: Colors.deepPurpleAccent.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      question,
                      style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      timeStr,
                      style: AppTextStyles.caption.copyWith(fontSize: 8, color: Colors.white38),
                    ),
                  ],
                ),
              ),
            ).animate().fade(duration: 300.ms).slideX(begin: 0.05),

            // Kâhin Cevabı
            if (isTemp)
              const SizedBox.shrink()
            else if (answer.isNotEmpty)
              Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  margin: const EdgeInsets.only(right: 48, bottom: 12, top: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.cardSurface.withValues(alpha: 0.8),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                      bottomRight: Radius.circular(16),
                    ),
                    border: Border.all(color: AppColors.primaryGold.withValues(alpha: 0.25)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.auto_awesome_rounded, color: AppColors.primaryGold, size: 14),
                          const SizedBox(width: 6),
                          Text(
                            isTr ? 'Kâhin' : 'Oracle',
                            style: AppTextStyles.caption.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppColors.primaryGold,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                      const Divider(color: Colors.white10),
                      Text(
                        answer,
                        style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textPrimary, height: 1.5),
                      ),
                    ],
                  ),
                ),
              ).animate().fade(duration: 400.ms).slideX(begin: -0.05),
          ],
        );
      },
    );
  }

  // Düşünüyor Baloncuğu
  Widget _buildThinkingBubble(bool isTr) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(right: 48, bottom: 12, top: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.cardSurface.withValues(alpha: 0.8),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomRight: Radius.circular(16),
          ),
          border: Border.all(color: AppColors.primaryGold.withValues(alpha: 0.25)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.auto_awesome_rounded, color: AppColors.primaryGold, size: 14),
                const SizedBox(width: 6),
                Text(
                  isTr ? 'Kâhin gök kubbeyi inceliyor...' : 'Oracle is reading the stars...',
                  style: AppTextStyles.caption.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryGold,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Center(
              child: SizedBox(
                width: 40,
                height: 40,
                child: const CircularProgressIndicator(
                  color: AppColors.primaryGold,
                  strokeWidth: 2,
                )
                    .animate(onPlay: (controller) => controller.repeat())
                    .scale(begin: const Offset(0.8, 0.8), end: const Offset(1.1, 1.1), duration: 1.seconds, curve: Curves.easeInOutSine)
                    .then()
                    .scale(begin: const Offset(1.1, 1.1), end: const Offset(0.8, 0.8), duration: 1.seconds, curve: Curves.easeInOutSine),
              ),
            ),
          ],
        ),
      ),
    ).animate().fade(duration: 300.ms);
  }

  // Alt Soru Yazma Çubuğu
  Widget _buildInputArea(bool isTr, int displayQuota, UserModel? user) {
    final bool needRewardedAd = _needAdToAsk && !_rewardedAdWatchedToday;
    final bool isLocked = displayQuota == 0 && !needRewardedAd;

    if (needRewardedAd) {
      return Container(
        padding: const EdgeInsets.only(left: 16, right: 16, top: 8, bottom: 20),
        decoration: BoxDecoration(
          color: AppColors.cardSurface.withValues(alpha: 0.65),
          border: const Border(top: BorderSide(color: Colors.white10)),
        ),
        child: GradientButton(
          height: 48,
          text: isTr ? 'Reklam İzle ve Soru Sor (+1 Hak) 📺' : 'Watch Ad & Ask (+1 Query) 📺',
          onTap: () {
            AdService.instance.showRewardedAd(
              placement: 'cosmic_oracle_rewarded',
              context: context,
              isPremium: user?.isPremium ?? false,
              onRewardEarned: () async {
                if (user != null) {
                  await AiService().incrementCosmicOracleRewardedWatch(user.uid);
                  await _loadHistoryData();
                  if (mounted) {
                    CustomToast.show(
                      context,
                      isTr ? 'Ek soru hakkı tanımlandı! Soru sorabilirsiniz. 🔮' : 'Extra query unlocked! You can ask your question now. 🔮',
                    );
                  }
                }
              },
            );
          },
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.only(left: 16, right: 16, top: 8, bottom: 20),
      decoration: BoxDecoration(
        color: AppColors.cardSurface.withValues(alpha: 0.65),
        border: const Border(top: BorderSide(color: Colors.white10)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _questionController,
              focusNode: _focusNode,
              enabled: !isLocked && !_isGenerating,
              maxLines: null,
              keyboardType: TextInputType.multiline,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) {
                if (!_isGenerating && !isLocked) {
                  _submitQuestion();
                }
              },
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
              decoration: InputDecoration(
                hintText: isLocked
                    ? (isTr ? 'Görüşme kotası doldu.' : 'Daily limit reached.')
                    : (isTr ? 'Kozmik Kahin\'e sorun...' : 'Ask the Cosmic Oracle...'),
                hintStyle: const TextStyle(color: Colors.white38, fontSize: 13.5),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(color: AppColors.primaryGold.withValues(alpha: 0.2)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: const BorderSide(color: AppColors.primaryGold),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                fillColor: Colors.black26,
                filled: true,
                prefixIcon: Icon(
                  isLocked ? Icons.lock_outline_rounded : Icons.psychology_alt_rounded,
                  color: isLocked ? Colors.white24 : AppColors.primaryGold,
                  size: 20,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () {
              if (isLocked) {
                _showPremiumLimitDialog(isTr);
              } else if (!_isGenerating) {
                _submitQuestion();
              }
            },
            child: Container(
              height: 42,
              width: 42,
              decoration: BoxDecoration(
                gradient: isLocked ? null : AppColors.goldGradient,
                color: isLocked ? Colors.white12 : null,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Icon(
                Icons.send_rounded,
                color: isLocked ? Colors.white30 : AppColors.cardSurface,
                size: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
