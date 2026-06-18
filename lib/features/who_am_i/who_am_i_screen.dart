import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:horoscope/core/constants/app_colors.dart';
import 'package:horoscope/core/constants/app_text_styles.dart';
import 'package:horoscope/core/models/character_analysis_model.dart';
import 'package:horoscope/core/providers/user_provider.dart';
import 'package:horoscope/core/providers/language_provider.dart';
import 'package:horoscope/core/services/ai_service.dart';
import 'package:horoscope/shared/widgets/glass_card.dart';
import 'package:horoscope/shared/widgets/gradient_button.dart';
import 'package:horoscope/shared/widgets/custom_toast.dart';
import 'package:horoscope/core/services/ad_service.dart';

class WhoAmIScreen extends ConsumerStatefulWidget {
  const WhoAmIScreen({super.key});

  @override
  ConsumerState<WhoAmIScreen> createState() => _WhoAmIScreenState();
}

class _WhoAmIScreenState extends ConsumerState<WhoAmIScreen> {
  bool _isLoading = false;
  CharacterAnalysisModel? _analysis;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndLoadAnalysis(forceCalculate: false);
    });
  }

  void _showAiToolsLimitDialog(bool isTr, String userId, VoidCallback onAdCompleted) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: GlassCard(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('📊', style: TextStyle(fontSize: 48))
                    .animate().scale(duration: 400.ms, curve: Curves.elasticOut),
                const SizedBox(height: 16),
                Text(
                  isTr ? 'Yapay Zeka Analiz Limiti' : 'AI Calculation Limit',
                  style: AppTextStyles.h3.copyWith(color: AppColors.primaryGold, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  isTr
                      ? 'Günlük 3 adet ücretsiz analiz hakkınız dolmuştur. Bir ödüllü reklam izleyerek hemen +1 analiz hakkı kazanabilir veya Premium\'a geçerek sınırsız analiz yapabilirsiniz.'
                      : 'You have reached your daily limit of 3 free calculations. Watch a rewarded ad to earn +1 calculation right now, or upgrade to Premium for unlimited access.',
                  style: AppTextStyles.bodyMedium.copyWith(height: 1.45),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                GradientButton(
                  text: isTr ? 'Reklam İzle 📺' : 'Watch Ad 📺',
                  onTap: () {
                    Navigator.pop(context);
                    AdService.instance.showRewardedAd(
                      placement: 'ai_tools_rewarded',
                      context: context,
                      isPremium: false,
                      onRewardEarned: () async {
                        await AiService().incrementAiToolsRewardedCount(userId);
                        onAdCompleted();
                      },
                    );
                  },
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    CustomToast.show(context,
                        isTr ? 'Premium paketler çok yakında!' : 'Premium bundles coming soon!');
                  },
                  child: Text(
                    isTr ? 'Premium\'a Geç 🚀' : 'Upgrade to Premium 🚀',
                    style: const TextStyle(color: AppColors.primaryGold, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 4),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    isTr ? 'Kapat' : 'Close',
                    style: const TextStyle(color: Colors.white70),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _checkAndLoadAnalysis({required bool forceCalculate}) async {
    final user = ref.read(userProvider);
    if (user == null) return;

    final bool hasBirthData =
        user.birthDate != null && user.birthTime != null && user.birthPlace != null;
    if (!hasBirthData) return;

    final isTr = ref.read(languageProvider).languageCode == 'tr';

    if (!forceCalculate) {
      setState(() { _isLoading = true; });
      try {
        final docRef = FirebaseFirestore.instance
            .doc('users/${user.uid}/character_analysis/data');
        final docSnapshot = await docRef.get();
        if (docSnapshot.exists && docSnapshot.data() != null) {
          final data = docSnapshot.data()!;
          final dims = data['personalityDimensions'] as List?;
          if (dims != null && dims.isNotEmpty) {
            // Yeni format: direkt göster
            final analysis = CharacterAnalysisModel.fromMap(data);
            if (mounted) {
              setState(() { _analysis = analysis; _isLoading = false; });
            }
            return;
          }
          // Eski format: kullanıcıya hesapla ekranı göster, otomatik üretme
        }
        // Veri yok veya eski format → hesapla ekranı
        if (mounted) setState(() { _analysis = null; _isLoading = false; });
      } catch (_) {
        if (mounted) setState(() { _isLoading = false; });
      }
      return;
    }


    final limitInfo = await AiService().checkAiToolsDailyLimit(user.uid);
    if (limitInfo['allowed'] == false) {
      _showAiToolsLimitDialog(isTr, user.uid, () {
        _executeCalculation(user.uid, forceRecalculate: true);
      });
      return;
    }

    _executeCalculation(user.uid, forceRecalculate: true);
  }

  Future<void> _executeCalculation(String userId,
      {bool forceRecalculate = false}) async {
    setState(() { _isLoading = true; });

    try {
      final aiService = AiService();
      final user = ref.read(userProvider);
      if (user == null) return;

      final chart = await aiService.calculateAndSaveNatalChart(
        userId: user.uid,
        name: user.name ?? 'Gezgin',
        birthDate: user.birthDate!,
        birthTime: user.birthTime!,
        birthPlace: user.birthPlace!,
      );

      if (chart != null) {
        final analysis = await aiService.generateCharacterAnalysis(
          userId: user.uid,
          name: user.name ?? 'Gezgin',
          natalChart: chart,
          forceRecalculate: forceRecalculate,
        );

        if (analysis != null && !forceRecalculate) {
          await AiService().incrementAiToolsCalculationCount(userId);
        }

        if (mounted) {
          setState(() { _analysis = analysis; _isLoading = false; });
        }
      } else {
        if (mounted) setState(() { _isLoading = false; });
      }
    } catch (_) {
      if (mounted) setState(() { _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(userProvider);
    final locale = ref.watch(languageProvider);
    final isTr = locale.languageCode == 'tr';
    final bool hasBirthData =
        user?.birthDate != null && user?.birthTime != null && user?.birthPlace != null;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(isTr ? 'Karakter Analizi (Ben Kimim?)' : 'Character Analysis'),
        actions: [
          if (hasBirthData && _analysis != null)
            IconButton(
              icon: const Icon(Icons.favorite_rounded, color: AppColors.primaryGold),
              onPressed: () {
                HapticFeedback.lightImpact();
                context.push('/best-matches');
              },
              tooltip: isTr ? 'Kozmik Eşleşmeler' : 'Cosmic Matches',
            ),
        ],
      ),
      body: _isLoading
          ? _buildLoadingView(isTr)
          : !hasBirthData
              ? _buildMissingDataView(isTr)
              : _analysis == null
                  ? _buildCalculateView(isTr)
                  : _buildResultView(isTr),
    );
  }

  Widget _buildMissingDataView(bool isTr) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: GlassCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('💫', style: TextStyle(fontSize: 48)),
              const SizedBox(height: 16),
              Text(
                isTr ? 'Profil Bilgileri Eksik' : 'Missing Profile Info',
                style: AppTextStyles.h3.copyWith(color: AppColors.primaryGold),
              ),
              const SizedBox(height: 12),
              Text(
                isTr
                    ? 'Derinlemesine karakter analizi yapabilmemiz için doğum bilgileriniz gereklidir. Lütfen Ayarlar sekmesine gidip bu bilgileri doldurun.'
                    : 'We need your birth parameters to calculate your character analysis. Please update them in the Settings tab.',
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCalculateView(bool isTr) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            GestureDetector(
              onTap: () {
                HapticFeedback.mediumImpact();
                _checkAndLoadAnalysis(forceCalculate: true);
              },
              child: Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const RadialGradient(
                    colors: [Color(0xFF7B5EA7), Color(0xFF1A1428)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryGold.withValues(alpha: 0.3),
                      blurRadius: 40,
                      spreadRadius: 10,
                    )
                  ],
                  border: Border.all(
                      color: AppColors.primaryGold.withValues(alpha: 0.4), width: 2),
                ),
                alignment: Alignment.center,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('🔮', style: TextStyle(fontSize: 50)),
                    const SizedBox(height: 8),
                    Text(
                      isTr ? 'KEŞFET' : 'DISCOVER',
                      style: AppTextStyles.label.copyWith(
                        color: AppColors.primaryGold,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                      ),
                    ),
                  ],
                ),
              )
                  .animate(onPlay: (c) => c.repeat(reverse: true))
                  .scale(
                      begin: const Offset(1, 1),
                      end: const Offset(1.08, 1.08),
                      duration: 1200.ms,
                      curve: Curves.easeInOut),
            ),
            const SizedBox(height: 32),
            Text(
              isTr ? 'Kendini Yıldızlarda Tanı' : 'Know Yourself in the Stars',
              style: AppTextStyles.h2
                  .copyWith(color: AppColors.primaryGold, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              isTr
                  ? 'Gezegen konumlarına göre kişilik boyutlarını, güçlü yönlerini ve ruhsal haritanı analiz etmek için kristal küreye dokun.'
                  : 'Tap the crystal ball to reveal your personality dimensions, strengths, and spiritual map.',
              style: AppTextStyles.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingView(bool isTr) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('✨🌌✨', style: TextStyle(fontSize: 50))
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .scale(
                    begin: const Offset(1, 1),
                    end: const Offset(1.2, 1.2),
                    duration: 1.seconds),
            const SizedBox(height: 32),
            Text(
              isTr ? 'Kozmik Veriler Çözümleniyor...' : 'Decoding Cosmic Data...',
              style: AppTextStyles.h3.copyWith(color: AppColors.primaryGold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              isTr
                  ? 'Kişilik kodlarınız, güçlü yönleriniz ve ruhsal haritanız analiz ediliyor.'
                  : 'Your personality codes, strengths, and spiritual map are being analyzed.',
              style: AppTextStyles.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultView(bool isTr) {
    final res = _analysis!;

    return SingleChildScrollView(
      padding: const EdgeInsets.only(left: 16.0, right: 16.0, top: 10.0, bottom: 160.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // ─── 1. KİŞİLİK HARİTASI ───────────────────────────────
          Text(isTr ? 'Kişilik Haritası' : 'Personality Map', style: AppTextStyles.h3),
          const SizedBox(height: 10),
          GlassCard(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Column(
              children: res.personalityDimensions.isEmpty
                  ? [
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          isTr ? 'Veri yükleniyor...' : 'Loading data...',
                          style: AppTextStyles.bodySmall,
                        ),
                      )
                    ]
                  : res.personalityDimensions.asMap().entries.map((entry) {
                      final dim = entry.value;
                      final leftLabel = isTr ? dim.leftLabelTr : dim.leftLabelEn;
                      final rightLabel = isTr ? dim.rightLabelTr : dim.rightLabelEn;
                      return _buildDimensionBar(
                        leftLabel: leftLabel,
                        rightLabel: rightLabel,
                        leftPercent: dim.leftPercent,
                        isLast: entry.key == res.personalityDimensions.length - 1,
                      );
                    }).toList(),
            ),
          ).animate().fade().slideY(begin: 0.1, duration: 400.ms),
          const SizedBox(height: 20),

          // ─── 2. GÜÇLÜ YÖNLER & GELİŞİM ALANLARI ───────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: GlassCard(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isTr ? '🍀 Güçlü Yönler' : '🍀 Strengths',
                        style: AppTextStyles.label.copyWith(
                            color: Colors.greenAccent, fontWeight: FontWeight.bold),
                      ),
                      const Divider(color: Colors.white12),
                      ...(isTr ? res.strengthsTr : res.strengthsEn).map((item) =>
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4.0),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('✦',
                                    style: TextStyle(color: Colors.greenAccent, fontSize: 12)),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(item,
                                      style: AppTextStyles.bodySmall.copyWith(fontSize: 11)),
                                ),
                              ],
                            ),
                          )),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GlassCard(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isTr ? '⚠️ Gelişim Alanları' : '⚠️ Growth Areas',
                        style: AppTextStyles.label.copyWith(
                            color: Colors.amberAccent, fontWeight: FontWeight.bold),
                      ),
                      const Divider(color: Colors.white12),
                      ...(isTr ? res.weaknessesTr : res.weaknessesEn).map((item) =>
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4.0),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('✦',
                                    style: TextStyle(color: Colors.amberAccent, fontSize: 12)),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(item,
                                      style: AppTextStyles.bodySmall.copyWith(fontSize: 11)),
                                ),
                              ],
                            ),
                          )),
                    ],
                  ),
                ),
              ),
            ],
          ).animate().fade(delay: 100.ms).slideY(begin: 0.1, duration: 400.ms),
          const SizedBox(height: 20),

          // ─── 3. KARİYER EĞİLİMLERİ ─────────────────────────────
          Text(isTr ? 'Kariyer ve Yetenek Eğilimleri' : 'Career & Talent Tendencies',
              style: AppTextStyles.h3),
          const SizedBox(height: 10),
          GlassCard(
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: (isTr ? res.careersTr : res.careersEn).map((job) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primaryGold.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.primaryGold.withValues(alpha: 0.3)),
                ),
                child: Text(
                  job,
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.primaryGold, fontWeight: FontWeight.bold),
                ),
              )).toList(),
            ),
          ).animate().fade(delay: 200.ms).slideY(begin: 0.1, duration: 400.ms),
          const SizedBox(height: 20),

          // ─── 4. İÇSEL DÜNYA ────────────────────────────────────
          Text(isTr ? 'İçsel Dünyan (Gizli Benliğin)' : 'Your Inner World (Secret Self)',
              style: AppTextStyles.h3),
          const SizedBox(height: 10),
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text('🌙', style: TextStyle(fontSize: 20)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        isTr
                            ? 'Ay Burcu • Bilinçaltı ve Duygusal Dünya'
                            : 'Moon Sign • Subconscious & Emotional World',
                        style: AppTextStyles.label.copyWith(
                            color: AppColors.primaryGold, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const Divider(),
                Text(
                  isTr ? res.secretSelfTr : res.secretSelfEn,
                  style: AppTextStyles.bodyMedium.copyWith(height: 1.65),
                ),
              ],
            ),
          ).animate().fade(delay: 300.ms).slideY(begin: 0.1, duration: 400.ms),
          const SizedBox(height: 20),

          // ─── 5. RUHSAL YOLCULUK ─────────────────────────────────
          Text(isTr ? 'Ruhsal Yolculuğun (Yaşam Dersin)' : 'Your Spiritual Journey (Life Lesson)',
              style: AppTextStyles.h3),
          const SizedBox(height: 10),
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text('🌅', style: TextStyle(fontSize: 20)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        isTr
                            ? 'Yükselen Burç • Hayat Amacı ve Dış Dünya'
                            : 'Rising Sign • Life Purpose & Outer World',
                        style: AppTextStyles.label.copyWith(
                            color: AppColors.primaryGold, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const Divider(),
                Text(
                  isTr ? res.spiritualJourneyTr : res.spiritualJourneyEn,
                  style: AppTextStyles.bodyMedium.copyWith(height: 1.65),
                ),
              ],
            ),
          ).animate().fade(delay: 400.ms).slideY(begin: 0.1, duration: 400.ms),
          const SizedBox(height: 32),

          // ─── Kozmik Eşleşmeler Butonu ───────────────────────────
          GradientButton(
            text: isTr ? 'Kozmik Eşleşmelerimi Gör 🗺️' : 'View Cosmic Matches 🗺️',
            onTap: () {
              HapticFeedback.lightImpact();
              context.push('/best-matches');
            },
          ),
        ],
      ),
    );
  }

  /// Zıt kişilik boyutu barı — iki kutup arası renkli bar
  Widget _buildDimensionBar({
    required String leftLabel,
    required String rightLabel,
    required int leftPercent,
    bool isLast = false,
  }) {
    final rightPercent = 100 - leftPercent;
    final leftDominant = leftPercent >= rightPercent;

    // Renk: sola kaymışsa altın, sağa kaymışsa mor-pembe
    final dominantColor = leftDominant
        ? const Color(0xFFD4AF37)
        : const Color(0xFFB57BFF);
    final dominantColorLight = leftDominant
        ? const Color(0xFFFFF0A0)
        : const Color(0xFFE0B4FF);

    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 4 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ─ Etiket satırı ─
          Row(
            children: [
              Expanded(
                child: Text(
                  leftLabel,
                  style: AppTextStyles.bodySmall.copyWith(
                    fontSize: 12,
                    fontWeight: leftDominant ? FontWeight.bold : FontWeight.normal,
                    color: leftDominant ? dominantColor : Colors.white38,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              // Yüzde badge — dominant olan
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: dominantColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: dominantColor.withValues(alpha: 0.4)),
                ),
                child: Text(
                  leftDominant ? '%$leftPercent' : '%$rightPercent',
                  style: TextStyle(
                    color: dominantColor,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  rightLabel,
                  textAlign: TextAlign.right,
                  style: AppTextStyles.bodySmall.copyWith(
                    fontSize: 12,
                    fontWeight: !leftDominant ? FontWeight.bold : FontWeight.normal,
                    color: !leftDominant ? dominantColor : Colors.white38,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),

          // ─ Bar ─
          LayoutBuilder(
            builder: (context, constraints) {
              final totalWidth = constraints.maxWidth;
              return Stack(
                children: [
                  // Arkaplan
                  Container(
                    height: 10,
                    width: totalWidth,
                    decoration: BoxDecoration(
                      color: Colors.white10,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  // Merkez çizgi
                  Positioned(
                    left: totalWidth / 2 - 1,
                    child: Container(
                      width: 2,
                      height: 10,
                      color: Colors.white24,
                    ),
                  ),
                  // Dolgu — sol yüzde kadar
                  Animate().custom(
                    duration: 900.ms,
                    curve: Curves.easeOutCubic,
                    builder: (context, val, child) => Container(
                      height: 10,
                      width: totalWidth * val * (leftPercent / 100.0),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [dominantColor.withValues(alpha: 0.6), dominantColorLight],
                        ),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
