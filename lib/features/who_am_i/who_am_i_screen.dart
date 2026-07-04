import 'dart:ui';

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
import 'package:horoscope/core/utils/firestore_extension.dart';
import 'package:horoscope/shared/widgets/glass_card.dart';
import 'package:horoscope/shared/widgets/gradient_button.dart';
import 'package:horoscope/shared/widgets/custom_toast.dart';
import 'package:horoscope/shared/widgets/premium_dialog_helper.dart';

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

  Future<void> _checkAndLoadAnalysis({required bool forceCalculate}) async {
    final user = ref.read(userProvider);
    if (user == null) return;

    final bool hasBirthData =
        user.birthDate != null && user.birthTime != null && user.birthPlace != null;
    if (!hasBirthData) return;

    if (!forceCalculate) {
      setState(() { _isLoading = true; });
      try {
        final docRef = FirebaseFirestore.instance
            .doc('users/${user.uid}/character_analysis/data');
        final docSnapshot = await docRef.safeGet();
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

    _executeCalculation(user.uid, forceRecalculate: true);
  }

  Future<void> _executeCalculation(String userId,
      {bool forceRecalculate = false}) async {
    setState(() { _isLoading = true; });
    final isTr = ref.read(languageProvider).languageCode == 'tr';

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
        gender: user.gender,
      );

      if (chart != null) {
        final analysis = await aiService.generateCharacterAnalysis(
          userId: user.uid,
          name: user.name ?? 'Gezgin',
          natalChart: chart,
          forceRecalculate: forceRecalculate,
        );

        if (analysis != null) {
          if (mounted) {
            setState(() { _analysis = analysis; _isLoading = false; });
          }
        } else {
          if (mounted) {
            setState(() { _isLoading = false; });
            CustomToast.show(
              context,
              isTr ? 'Karakter analizi oluşturulamadı. Lütfen internetinizi kontrol edin.' : 'Could not generate character analysis. Please check your internet connection.',
              isError: true,
            );
          }
        }
      } else {
        if (mounted) {
          setState(() { _isLoading = false; });
          CustomToast.show(
            context,
            isTr ? 'Gök haritası hesaplanamadı. Lütfen internetinizi kontrol edin.' : 'Could not calculate natal chart. Please check your internet connection.',
            isError: true,
          );
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() { _isLoading = false; });
        CustomToast.show(
          context,
          isTr ? 'Bir hata oluştu. Lütfen tekrar deneyin.' : 'An error occurred. Please try again.',
          isError: true,
        );
      }
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
    final user = ref.watch(userProvider);
    final isPro = user?.isAnyPremium ?? false;

    return SingleChildScrollView(
      padding: const EdgeInsets.only(left: 16.0, right: 16.0, top: 10.0, bottom: 120.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // ─── 1. KİŞİLİK HARİTASI (ÜCRETSİZ) ───────────────────
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
          const SizedBox(height: 24),

          // ─── 2. GÜÇLÜ YÖNLER & GELİŞİM ALANLARI (PRO) ─────────
          if (isPro) ...[  
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
                        Divider(color: AppColors.borderLight),
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
                        Divider(color: AppColors.borderLight),
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
          ] else ...[  
            _buildProLockedSection(
              title: isTr ? 'Güçlü Yönler & Gelişim Alanları' : 'Strengths & Growth Areas',
              isTr: isTr,
              minHeight: 140,
            ),
            const SizedBox(height: 20),
          ],

          // ─── 3. KARİYER EĞİLİMLERİ (PRO) ───────────────────────
          if (isPro) ...[  
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
          ] else ...[  
            _buildProLockedSection(
              title: isTr ? 'Kariyer ve Yetenek Eğilimleri' : 'Career & Talent Tendencies',
              isTr: isTr,
              minHeight: 100,
            ),
            const SizedBox(height: 20),
          ],

          // ─── 4. İÇSEL DÜNYA (PRO) ───────────────────────────────
          if (isPro) ...[  
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
          ] else ...[  
            _buildProLockedSection(
              title: isTr ? 'İçsel Dünyan (Gizli Benliğin)' : 'Your Inner World (Secret Self)',
              isTr: isTr,
              minHeight: 120,
            ),
            const SizedBox(height: 20),
          ],

          // ─── 5. RUHSAL YOLCULUK (PRO) ────────────────────────────
          if (isPro) ...[  
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
          ] else ...[  
            _buildProLockedSection(
              title: isTr ? 'Ruhsal Yolculuğun (Yaşam Dersin)' : 'Your Spiritual Journey (Life Lesson)',
              isTr: isTr,
              minHeight: 120,
            ),
            const SizedBox(height: 32),
          ],

          // ─── Burç Eşleşmeleri ────────────────────────────────────
          if (isPro)
            GradientButton(
              text: isTr ? 'Burç Eşleşmelerini Gör ♊' : 'View Zodiac Matches ♊',
              onTap: () {
                HapticFeedback.lightImpact();
                context.push('/best-matches');
              },
            )
          else
            _buildProLockedSection(
              title: isTr ? 'Burç Eşleşmeleri' : 'Zodiac Matches',
              isTr: isTr,
              minHeight: 80,
            ),
        ],
      ),
    );
  }

  Widget _buildDimensionBar({
    required String leftLabel,
    required String rightLabel,
    required int leftPercent,
    bool isLast = false,
  }) {
    final rightPercent = 100 - leftPercent;
    final leftDominant = leftPercent >= rightPercent;

    final Color dominantColor = leftDominant
        ? const Color(0xFFD4AF37)
        : const Color(0xFFB57BFF);
    final Color dominantColorLight = leftDominant
        ? const Color(0xFFFFF0A0)
        : const Color(0xFFE0B4FF);

    final isDark = AppTextStyles.isDark;
    final inactiveTextColor = isDark ? const Color(0x61FFFFFF) : const Color(0x8A000000); 
    final barBgColor = isDark ? const Color(0x1AFFFFFF) : const Color(0x12000000); 
    final barCenterColor = isDark ? const Color(0x3DFFFFFF) : const Color(0x24000000); 

    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 4 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  leftLabel,
                  style: AppTextStyles.bodySmall.copyWith(
                    fontSize: 12,
                    fontWeight: leftDominant ? FontWeight.bold : FontWeight.normal,
                    color: leftDominant ? dominantColor : inactiveTextColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
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
                    color: !leftDominant ? dominantColor : inactiveTextColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          LayoutBuilder(
            builder: (context, constraints) {
              final totalWidth = constraints.maxWidth;
              return Stack(
                children: [
                  Container(
                    height: 10,
                    width: totalWidth,
                    decoration: BoxDecoration(
                      color: barBgColor,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  Positioned(
                    left: totalWidth / 2 - 1,
                    child: Container(
                      width: 2,
                      height: 10,
                      color: barCenterColor,
                    ),
                  ),
                  // Dolgu — sol dominant ise soldan sağa, sağ dominant ise sağdan sola
                  Positioned(
                    left: leftDominant ? 0 : null,
                    right: leftDominant ? null : 0,
                    child: Animate().custom(
                      duration: 900.ms,
                      curve: Curves.easeOutCubic,
                      builder: (context, val, child) => Container(
                        height: 10,
                        width: totalWidth * val * ((leftDominant ? leftPercent : rightPercent) / 100.0),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: leftDominant
                                ? [dominantColor.withValues(alpha: 0.6), dominantColorLight]
                                : [dominantColorLight, dominantColor.withValues(alpha: 0.6)],
                          ),
                          borderRadius: BorderRadius.circular(6),
                        ),
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

  Widget _buildProLockedSection({
    required String title,
    required bool isTr,
    double minHeight = 100,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AppTextStyles.h3),
        const SizedBox(height: 10),
        GestureDetector(
          onTap: () => PremiumDialogHelper.show(context, ref),
          child: Stack(
            children: [
              // Blurlu içerik taklidi
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: ImageFiltered(
                  imageFilter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                  child: Container(
                    width: double.infinity,
                    constraints: BoxConstraints(minHeight: minHeight),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (int i = 0; i < 4; i++)
                          Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            height: 11,
                            width: i == 1 ? 160 : double.infinity,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(
                                  alpha: i == 0 ? 0.45 : 0.18),
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              // Kilit katmanı
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.primaryGold.withValues(alpha: 0.4),
                    ),
                  ),
                  constraints: BoxConstraints(minHeight: minHeight),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.primaryGold.withValues(alpha: 0.15),
                          border: Border.all(
                              color: AppColors.primaryGold.withValues(alpha: 0.5)),
                        ),
                        child: const Icon(Icons.lock_rounded,
                            color: AppColors.primaryGold, size: 28),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        isTr ? 'PRO\'ya Geç' : 'Unlock with PRO',
                        style: AppTextStyles.label.copyWith(
                          color: AppColors.primaryGold,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
