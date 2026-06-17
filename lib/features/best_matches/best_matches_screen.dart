import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:horoscope/core/constants/app_colors.dart';
import 'package:horoscope/core/constants/app_text_styles.dart';
import 'package:horoscope/core/models/best_matches_model.dart';
import 'package:horoscope/core/providers/user_provider.dart';
import 'package:horoscope/core/providers/language_provider.dart';
import 'package:horoscope/core/services/ai_service.dart';
import 'package:horoscope/shared/widgets/glass_card.dart';
import 'package:horoscope/shared/widgets/star_background.dart';

class BestMatchesScreen extends ConsumerStatefulWidget {
  const BestMatchesScreen({super.key});

  @override
  ConsumerState<BestMatchesScreen> createState() => _BestMatchesScreenState();
}

class _BestMatchesScreenState extends ConsumerState<BestMatchesScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = false;
  BestMatchesModel? _bestMatches;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndLoadMatches();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _checkAndLoadMatches() async {
    final user = ref.read(userProvider);
    if (user == null) return;

    final bool hasBirthData = user.birthDate != null && user.birthTime != null && user.birthPlace != null;
    if (!hasBirthData) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final aiService = AiService();
      
      // Önce doğum haritasını al veya hesapla
      final chart = await aiService.calculateAndSaveNatalChart(
        userId: user.uid,
        name: user.name ?? 'Gezgin',
        birthDate: user.birthDate!,
        birthTime: user.birthTime!,
        birthPlace: user.birthPlace!,
      );

      if (chart != null) {
        final matches = await aiService.generateBestMatches(
          userId: user.uid,
          sunSign: chart.sunSign,
          moonSign: chart.moonSign,
          risingSign: chart.risingSign,
        );

        if (mounted) {
          setState(() {
            _bestMatches = matches;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(languageProvider);
    final isTr = locale.languageCode == 'tr';
    final user = ref.watch(userProvider);
    final bool hasBirthData = user?.birthDate != null && user?.birthTime != null && user?.birthPlace != null;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(isTr ? 'Kozmik Eşleşmelerim' : 'My Cosmic Matches'),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: StarBackground(
        child: SafeArea(
          child: _isLoading
              ? _buildLoadingView(isTr)
              : !hasBirthData
                  ? _buildMissingDataView(isTr)
                  : _bestMatches == null
                      ? _buildErrorView(isTr)
                      : _buildMainView(isTr),
        ),
      ),
    );
  }

  Widget _buildLoadingView(bool isTr) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: 40,
            height: 40,
            child: CircularProgressIndicator(
              color: AppColors.primaryGold,
              strokeWidth: 3,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            isTr ? 'En Uyumlu Burçlar Hesaplanıyor...' : 'Calculating Harmonious Signs...',
            style: AppTextStyles.h3.copyWith(color: AppColors.primaryGold),
          ),
        ],
      ),
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
              const Text('🗺️', style: TextStyle(fontSize: 48)),
              const SizedBox(height: 16),
              Text(
                isTr ? 'Profil Bilgileri Eksik' : 'Missing Profile Info',
                style: AppTextStyles.h3.copyWith(color: AppColors.primaryGold),
              ),
              const SizedBox(height: 12),
              Text(
                isTr
                    ? 'Eşleşmelerinizi hesaplayabilmemiz için doğum bilgileriniz gereklidir. Lütfen Ayarlar sekmesinden profilinizi güncelleyin.'
                    : 'We need your birth parameters to calculate your matches. Please update your profile in the Settings tab.',
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorView(bool isTr) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: GlassCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('⚠️', style: TextStyle(fontSize: 48)),
              const SizedBox(height: 16),
              Text(
                isTr ? 'Bir Hata Oluştu' : 'An Error Occurred',
                style: AppTextStyles.h3.copyWith(color: AppColors.primaryGold),
              ),
              const SizedBox(height: 12),
              Text(
                isTr ? 'Veriler alınamadı, lütfen tekrar deneyin.' : 'Failed to retrieve data, please try again.',
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyMedium,
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: _checkAndLoadMatches,
                child: Text(isTr ? 'Tekrar Dene' : 'Retry', style: const TextStyle(color: AppColors.primaryGold)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMainView(bool isTr) {
    return Column(
      children: [
        // Tab Seçici
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
          child: GlassCard(
            borderRadius: 16,
            padding: const EdgeInsets.all(4),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                gradient: AppColors.goldGradient,
                borderRadius: BorderRadius.circular(12),
              ),
              labelColor: AppColors.cardSurface,
              unselectedLabelColor: AppColors.textSecondary,
              labelStyle: AppTextStyles.label.copyWith(fontWeight: FontWeight.bold),
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              tabs: [
                Tab(text: isTr ? 'Aşk Eşleşmeleri' : 'Love Matches'),
                Tab(text: isTr ? 'Arkadaşlık' : 'Friendship'),
              ],
            ),
          ),
        ),

        // Tab İçerikleri
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildMatchesList(_bestMatches!.romanticMatches, isTr, true),
              _buildMatchesList(_bestMatches!.friendMatches, isTr, false),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMatchesList(List<MatchDetail> list, bool isTr, bool isLove) {
    if (list.isEmpty) {
      return Center(
        child: Text(
          isTr ? 'Henüz veri yok.' : 'No data yet.',
          style: AppTextStyles.bodyMedium,
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(left: 20.0, right: 20.0, top: 10.0, bottom: 40.0),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final item = list[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 16.0),
          child: GlassCard(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Burç İkonu
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primaryGold.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.primaryGold.withValues(alpha: 0.3)),
                  ),
                  child: _getZodiacEmoji(item.zodiacSign),
                ),
                const SizedBox(width: 16),

                // Açıklama
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _getZodiacName(item.zodiacSign, isTr),
                            style: AppTextStyles.h4.copyWith(
                              color: AppColors.primaryGold,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '#${index + 1}',
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.primaryGold.withValues(alpha: 0.5),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        isTr ? item.reasonTr : item.reasonEn,
                        style: AppTextStyles.bodyMedium.copyWith(height: 1.5),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        )
            .animate()
            .fade(delay: (index * 100).ms, duration: 400.ms)
            .slideX(begin: 0.1, delay: (index * 100).ms, duration: 400.ms);
      },
    );
  }

  // Yardımcı Metotlar
  String _getZodiacName(String? key, bool isTr) {
    if (key == null) return '';
    if (!isTr) return key[0].toUpperCase() + key.substring(1);
    switch (key.toLowerCase()) {
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
      default: return key;
    }
  }

  Widget _getZodiacEmoji(String key) {
    switch (key.toLowerCase()) {
      case 'aries': return const Text('♈', style: TextStyle(fontSize: 28));
      case 'taurus': return const Text('♉', style: TextStyle(fontSize: 28));
      case 'gemini': return const Text('♊', style: TextStyle(fontSize: 28));
      case 'cancer': return const Text('♋', style: TextStyle(fontSize: 28));
      case 'leo': return const Text('♌', style: TextStyle(fontSize: 28));
      case 'virgo': return const Text('♍', style: TextStyle(fontSize: 28));
      case 'libra': return const Text('♎', style: TextStyle(fontSize: 28));
      case 'scorpio': return const Text('♏', style: TextStyle(fontSize: 28));
      case 'sagittarius': return const Text('♐', style: TextStyle(fontSize: 28));
      case 'capricorn': return const Text('♑', style: TextStyle(fontSize: 28));
      case 'aquarius': return const Text('♒', style: TextStyle(fontSize: 28));
      case 'pisces': return const Text('♓', style: TextStyle(fontSize: 28));
      default: return const Text('🔮', style: TextStyle(fontSize: 28));
    }
  }
}
