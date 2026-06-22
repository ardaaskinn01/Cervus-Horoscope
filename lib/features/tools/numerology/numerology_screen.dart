import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:horoscope/core/constants/app_colors.dart';
import 'package:horoscope/core/constants/app_text_styles.dart';
import 'package:horoscope/core/models/numerology_model.dart';
import 'package:horoscope/core/providers/language_provider.dart';
import 'package:horoscope/core/providers/user_provider.dart';
import 'package:horoscope/core/services/ai_service.dart';
import 'package:horoscope/shared/widgets/glass_card.dart';
import 'package:horoscope/shared/widgets/gradient_button.dart';
import 'package:horoscope/shared/widgets/star_background.dart';
import 'package:horoscope/core/services/ad_service.dart';
import 'package:horoscope/shared/widgets/custom_toast.dart';

class NumerologyScreen extends ConsumerStatefulWidget {
  const NumerologyScreen({super.key});

  @override
  ConsumerState<NumerologyScreen> createState() => _NumerologyScreenState();
}

class _NumerologyScreenState extends ConsumerState<NumerologyScreen> {
  // Hesaplanan Sayılar
  int _lifePathNumber = 0;
  int _personalYearNumber = 0;
  int _soulNumber = 0;
  int _destinyNumber = 0;
  int _activeYear = 2026;

  // AI Analiz Durumu
  bool _isLoadingAi = false;
  String? _aiAnalysisTr;
  String? _aiAnalysisEn;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _calculateNumerology();
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  int _sumDigits(int n) {
    int s = 0;
    while (n > 0) {
      s += n % 10;
      n = (n / 10).floor();
    }
    return s;
  }

  // Rakamların toplamını tek haneye indirger (11, 22, 33 master sayıları hariç)
  int _reduceNumber(int val, {bool allowMaster = true}) {
    int result = val;
    while (result > 9) {
      if (allowMaster && (result == 11 || result == 22 || result == 33)) {
        break;
      }
      result = _sumDigits(result);
    }
    return result;
  }

  Future<void> _checkAndLoadCachedNumerology(String name) async {
    final user = ref.read(userProvider);
    if (user == null) return;
    if (name.trim().isEmpty) return;

    try {
      final NumerologyModel? cached = await AiService().getSavedNumerology(
        userId: user.uid,
        name: name,
      );

      if (cached != null &&
          cached.lifePathNumber == _lifePathNumber &&
          cached.personalYearNumber == _personalYearNumber &&
          mounted) {
        setState(() {
          _aiAnalysisTr = cached.aiAnalysisTr;
          _aiAnalysisEn = cached.aiAnalysisEn;
        });
      } else {
        if (mounted) {
          setState(() {
            _aiAnalysisTr = null;
            _aiAnalysisEn = null;
          });
        }
      }
    } catch (_) {}
  }

  // Numeroloji hesaplayıcı
  void _calculateNumerology() {
    final user = ref.read(userProvider);
    if (user == null || user.birthDate == null) return;

    final birth = user.birthDate!;

    // 1. Yaşam Yolu Sayısı (Tüm rakamların toplamı)
    final int daySum = _sumDigits(birth.day);
    final int monthSum = _sumDigits(birth.month);
    final int yearSum = _sumDigits(birth.year);
    final int dateSum = daySum + monthSum + yearSum;
    _lifePathNumber = _reduceNumber(dateSum, allowMaster: true);

    // 2. Kişisel Yıl Sayısı (Doğum günü + doğum ayı + aktif yılın rakamlarının toplamı)
    // Astroseek/Klasik numerolojiye göre, kişisel yıl doğum gününde değişir.
    // Bugün eğer doğum gününden önce ise önceki yıl, doğum günü veya sonrasında ise bu yıl kullanılır.
    final now = DateTime.now();
    int activeYear = now.year;
    if (now.month < birth.month || (now.month == birth.month && now.day < birth.day)) {
      activeYear = now.year - 1;
    }
    _activeYear = activeYear;

    final int personalYearSum = daySum + monthSum + _sumDigits(activeYear);
    _personalYearNumber = _reduceNumber(personalYearSum, allowMaster: false); // Yıl sayısı genelde 1-9 arasıdır

    // 3. İsim Analizi (Ruh ve Kader Sayıları)
    final String fullName = user.name ?? '';

    _calculateNameNumerology(fullName);
    _checkAndLoadCachedNumerology(fullName);
  }

  // Pisagor Alfabe Eşleştirmesi ile İsim Numerolojisi
  void _calculateNameNumerology(String name) {
    if (name.isEmpty) {
      setState(() {
        _soulNumber = 0;
        _destinyNumber = 0;
      });
      return;
    }

    final String lowerName = name.toLowerCase();
    
    // Pisagor Harf Değerleri Map
    final Map<String, int> letterValues = {
      'a': 1, 'j': 1, 's': 1, 'ş': 1,
      'b': 2, 'k': 2, 't': 2,
      'c': 3, 'ç': 3, 'l': 3, 'u': 3, 'ü': 3,
      'd': 4, 'm': 4, 'v': 4,
      'e': 5, 'n': 5, 'w': 5,
      'f': 6, 'o': 6, 'ö': 6, 'x': 6,
      'g': 7, 'ğ': 7, 'p': 7, 'y': 7,
      'h': 8, 'i': 8, 'ı': 8, 'q': 8, 'z': 8,
      'r': 9
    };

    final List<String> vowels = ['a', 'e', 'i', 'ı', 'o', 'ö', 'u', 'ü'];

    int totalVowelsSum = 0;
    int totalLettersSum = 0;

    for (int i = 0; i < lowerName.length; i++) {
      final char = lowerName[i];
      final val = letterValues[char];
      if (val != null) {
        totalLettersSum += val;
        if (vowels.contains(char)) {
          totalVowelsSum += val;
        }
      }
    }

    setState(() {
      _soulNumber = _reduceNumber(totalVowelsSum, allowMaster: true);
      _destinyNumber = _reduceNumber(totalLettersSum, allowMaster: true);
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
                const Text(
                  '📊',
                  style: TextStyle(fontSize: 48),
                ).animate().scale(duration: 400.ms, curve: Curves.elasticOut),
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
                Column(
                  children: [
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
                        CustomToast.show(
                          context,
                          isTr ? 'Premium paketler çok yakında!' : 'Premium bundles coming soon!',
                        );
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
              ],
            ),
          ),
        );
      },
    );
  }

  // Gemini AI Numeroloji Analizi İsteme
  Future<void> _fetchAiNumerology() async {
    final user = ref.read(userProvider);
    if (user == null) return;
    final isTr = ref.read(languageProvider).languageCode == 'tr';
    final String fullName = user.name ?? '';

    try {
      final limitInfo = await AiService().checkAiToolsDailyLimit(user.uid);
      if (limitInfo['allowed'] == false) {
        _showAiToolsLimitDialog(isTr, user.uid, () {
          _executeCalculation(user.uid, fullName);
        });
        return;
      }
      _executeCalculation(user.uid, fullName);
    } catch (e) {
      debugPrint('⚠️ Limit check error: $e');
      _executeCalculation(user.uid, fullName);
    }
  }

  Future<void> _executeCalculation(String userId, String fullName) async {
    setState(() {
      _isLoadingAi = true;
    });

    try {
      final numerology = await AiService().generateAndSaveNumerology(
        userId: userId,
        name: fullName,
        lifePath: _lifePathNumber,
        destiny: _destinyNumber,
        soul: _soulNumber,
        personalYear: _personalYearNumber,
      );

      if (numerology != null) {
        await AiService().incrementAiToolsCalculationCount(userId);
      }

      if (numerology != null && mounted) {
        setState(() {
          _aiAnalysisTr = numerology.aiAnalysisTr;
          _aiAnalysisEn = numerology.aiAnalysisEn;
          _isLoadingAi = false;
        });
      } else {
        if (mounted) {
          setState(() { _isLoadingAi = false; });
          final isTr = ref.read(languageProvider).languageCode == 'tr';
          CustomToast.show(
            context,
            isTr ? 'Numeroloji analizi oluşturulamadı. Lütfen internetinizi kontrol edin.' : 'Could not generate numerology analysis. Please check your internet connection.',
            isError: true,
          );
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() { _isLoadingAi = false; });
        final isTr = ref.read(languageProvider).languageCode == 'tr';
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
    final locale = ref.watch(languageProvider);
    final isTr = locale.languageCode == 'tr';

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(isTr ? 'Kişisel Numeroloji' : 'Personal Numerology'),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: StarBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(left: 20.0, right: 20.0, top: 10.0, bottom: 80.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Kozmik Sayı Kartları
                Text(
                  isTr ? 'Kozmik Sayılarınız' : 'Your Cosmic Numbers',
                  style: AppTextStyles.h3,
                ),
                const SizedBox(height: 12),
                _buildNumbersGrid(isTr),
                const SizedBox(height: 24),

                // 3. AI Analiz Kartı
                Text(
                  isTr ? 'Mistik Sayı Analizi' : 'Mystic Number Analysis',
                  style: AppTextStyles.h3,
                ),
                const SizedBox(height: 12),
                _buildAiAnalysisCard(isTr),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: AdService.instance.getBannerAdWidget(
          'numerology_banner',
          isPremium: ref.watch(userProvider)?.isPremium ?? false,
        ),
      ),
    );
  }

  // Sayılar Grid
  Widget _buildNumbersGrid(bool isTr) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.45,
      children: [
        _buildNumberCard(
          isTr ? 'Yaşam Yolu' : 'Life Path',
          _lifePathNumber.toString(),
          isTr ? 'Hayat amacınızı gösterir' : 'Shows your life purpose',
          Colors.amberAccent,
        ),
        _buildNumberCard(
          isTr ? 'Kişisel Yıl' : 'Personal Year',
          _personalYearNumber.toString(),
          isTr ? '$_activeYear yılındaki temanız' : 'Your theme in $_activeYear',
          Colors.blueAccent,
        ),
        _buildNumberCard(
          isTr ? 'Ruh Sayısı' : 'Soul Number',
          _soulNumber > 0 ? _soulNumber.toString() : '-',
          isTr ? 'İçsel arzularınızı yansıtır' : 'Reflects inner desires',
          Colors.purpleAccent,
        ),
        _buildNumberCard(
          isTr ? 'Kader Sayısı' : 'Destiny Number',
          _destinyNumber > 0 ? _destinyNumber.toString() : '-',
          isTr ? 'Yeteneklerinizi gösterir' : 'Indicates your talents',
          Colors.greenAccent,
        ),
      ],
    ).animate().fade(duration: 400.ms);
  }

  Widget _buildNumberCard(String title, String val, String desc, Color color) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.bold)),
          const Spacer(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                val,
                style: AppTextStyles.h1.copyWith(color: AppColors.primaryGold, fontSize: 28, fontWeight: FontWeight.bold),
              ),
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
            ],
          ),
          const Spacer(),
          Text(desc, style: AppTextStyles.caption.copyWith(fontSize: 9, color: AppColors.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }



  // AI Analiz Kartı
  Widget _buildAiAnalysisCard(bool isTr) {
    if (_isLoadingAi) {
      return GlassCard(
        child: Center(
          child: Column(
            children: [
              const CircularProgressIndicator(color: AppColors.primaryGold),
              const SizedBox(height: 16),
              Text(
                isTr ? 'Sayıların Mistik Titreşimleri İnceleniyor...' : 'Analyzing Mystical Vibrations...',
                style: AppTextStyles.bodyMedium,
              ),
            ],
          ),
        ),
      );
    }

    final analysis = isTr ? _aiAnalysisTr : _aiAnalysisEn;

    if (analysis != null && analysis.isNotEmpty) {
      return GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.auto_awesome_rounded, color: AppColors.primaryGold),
                const SizedBox(width: 8),
                Text(
                  isTr ? 'Sayıların Dili Raporu' : 'Cosmic Number Report',
                  style: AppTextStyles.label.copyWith(color: AppColors.primaryGold, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const Divider(),
            Text(
              analysis,
              style: AppTextStyles.bodyMedium.copyWith(height: 1.55),
            ),
          ],
        ),
      ).animate().fade(duration: 400.ms);
    }

    // Yüklenmemiş durum (Fallback / Buton)
    final pathDetails = isTr
        ? 'Yaşam Yolu sayınız olan $_lifePathNumber hakkında Gemini AI tabanlı derin kader ve şans yorumunu hemen oluşturun.'
        : 'Generate a Gemini AI analysis about your Life Path number $_lifePathNumber immediately.';

    return GlassCard(
      child: Column(
        children: [
          const Text('🔢✨', style: TextStyle(fontSize: 32)),
          const SizedBox(height: 12),
          Text(
            pathDetails,
            style: AppTextStyles.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          GradientButton(
            text: isTr ? 'Kozmik Raporu Oluştur' : 'Generate Cosmic Report',
            onTap: _fetchAiNumerology,
          ),
        ],
      ),
    );
  }
}
