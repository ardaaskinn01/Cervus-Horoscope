import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:horoscope/core/constants/app_colors.dart';
import 'package:horoscope/core/constants/app_text_styles.dart';
import 'package:horoscope/core/providers/language_provider.dart';
import 'package:horoscope/shared/widgets/glass_card.dart';
import 'package:horoscope/shared/widgets/gradient_button.dart';
import 'package:horoscope/shared/widgets/star_background.dart';

class MoonPhasesScreen extends ConsumerStatefulWidget {
  const MoonPhasesScreen({super.key});

  @override
  ConsumerState<MoonPhasesScreen> createState() => _MoonPhasesScreenState();
}

class _MoonPhasesScreenState extends ConsumerState<MoonPhasesScreen> {
  bool _isLoading = true;
  List<dynamic> _fullMoons = [];
  List<dynamic> _newMoons = [];
  
  // Bir sonraki dolunay
  Map<String, dynamic>? _nextFullMoon;
  int _daysUntilNextFullMoon = 0;

  // Ay fazı hesaplayıcı
  DateTime _calcDate = DateTime.now();
  String _calcPhaseName = '';
  String _calcPhaseEmoji = '🌑';
  String _calcPhaseDesc = '';
  double _calcMoonAge = 0.0;

  @override
  void initState() {
    super.initState();
    _loadLunarData();
    _calculatePhaseForDate(_calcDate);
  }

  Future<void> _loadLunarData() async {
    try {
      final jsonStr = await rootBundle.loadString('assets/data/astro_calendar_2026.json');
      final data = jsonDecode(jsonStr);
      
      final fullMoonsList = data['fullMoons'] as List<dynamic>;
      final newMoonsList = data['newMoons'] as List<dynamic>;

      // Bir sonraki dolunayı bul
      final now = DateTime.now();
      final todayStr = DateFormat('yyyy-MM-dd').format(now);
      
      Map<String, dynamic>? nextFM;
      int daysLeft = 0;

      for (final fm in fullMoonsList) {
        final dateStr = fm['date'] as String;
        final fmDate = DateTime.parse(dateStr);
        if (dateStr.compareTo(todayStr) >= 0) {
          nextFM = Map<String, dynamic>.from(fm);
          daysLeft = fmDate.difference(DateTime(now.year, now.month, now.day)).inDays;
          break;
        }
      }

      // Eğer 2026 dolunayı bittiyse varsayılan yap
      if (nextFM == null && fullMoonsList.isNotEmpty) {
        nextFM = Map<String, dynamic>.from(fullMoonsList.last);
      }

      setState(() {
        _fullMoons = fullMoonsList;
        _newMoons = newMoonsList;
        _nextFullMoon = nextFM;
        _daysUntilNextFullMoon = daysLeft;
        _isLoading = false;
      });

    } catch (e) {
      debugPrint('⚠️ Ay verisi yükleme hatası: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Tarihe Göre Ay Fazı Hesapla (Astronomik Yaklaşım Formülü)
  void _calculatePhaseForDate(DateTime date) {
    // Bilinen referans Yeniay tarihi (6 Ocak 2000, 18:14 UTC)
    final refNewMoon = DateTime.utc(2000, 1, 6, 18, 14);
    final diffDays = date.toUtc().difference(refNewMoon).inSeconds / (24 * 3600);
    
    // Sinodik ay süresi ~29.530588853 gün
    const synodicPeriod = 29.530588853;
    final phasesCompleted = diffDays / synodicPeriod;
    final fractionalPart = phasesCompleted - phasesCompleted.floor();
    final moonAge = fractionalPart * synodicPeriod;

    final isTr = ref.read(languageProvider).languageCode == 'tr';
    
    String emoji = '🌑';
    String name = '';
    String desc = '';

    if (moonAge < 1.845) {
      emoji = '🌑';
      name = isTr ? 'Yeni Ay' : 'New Moon';
      desc = isTr
          ? 'Niyetlerinizi belirlemek, taze başlangıçlar yapmak ve tohum ekmek için ideal kozmik zaman.'
          : 'Ideal cosmic time for setting intentions, starting fresh, and planting seeds.';
    } else if (moonAge < 5.5369) {
      emoji = '🌒';
      name = isTr ? 'Hilal (Büyüyen)' : 'Waxing Crescent';
      desc = isTr
          ? 'Niyetlerinizi eyleme dökme, planlama yapma ve ilk adımları atma süreci.'
          : 'The process of putting your intentions into action, planning, and taking first steps.';
    } else if (moonAge < 9.2288) {
      emoji = '🌓';
      name = isTr ? 'İlk Dördün' : 'First Quarter';
      desc = isTr
          ? 'Engelleri aşma, karar alma ve eylemlerinizde kararlı durma zamanı.'
          : 'Time to overcome obstacles, make decisions, and stay determined in your actions.';
    } else if (moonAge < 12.9207) {
      emoji = '🌔';
      name = isTr ? 'Şişkin Ay (Büyüyen)' : 'Waxing Gibbous';
      desc = isTr
          ? 'Planları gözden geçirme, sabırlı olma ve projelere son şeklini verme dönemi.'
          : 'Period for reviewing plans, practicing patience, and putting final touches on projects.';
    } else if (moonAge < 16.6126) {
      emoji = '🌕';
      name = isTr ? 'Dolunay' : 'Full Moon';
      desc = isTr
          ? 'Hasat zamanı. Enerjinin zirve yaptığı, kutlama, farkındalık ve arınma süreci.'
          : 'Harvest time. Energy peaks; a period of celebration, realization, and release.';
    } else if (moonAge < 20.3045) {
      emoji = '🌖';
      name = isTr ? 'Kambur Ay (Küçülen)' : 'Waning Gibbous';
      desc = isTr
          ? 'Şükretme, tecrübeleri paylaşma ve elde edilenleri koruma zamanı.'
          : 'Time to practice gratitude, share experiences, and protect what has been achieved.';
    } else if (moonAge < 23.9964) {
      emoji = '🌗';
      name = isTr ? 'Son Dördün' : 'Third Quarter';
      desc = isTr
          ? 'Bırakma, affetme, alışkanlıklardan kurtulma ve içsel muhasebe süreci.'
          : 'A process of letting go, forgiving, breaking bad habits, and inner reflection.';
    } else if (moonAge < 27.6883) {
      emoji = '🌘';
      name = isTr ? 'Balsamik Ay (Küçülen Hilal)' : 'Waning Crescent';
      desc = isTr
          ? 'Dinlenme, zihni boşaltma, meditasyon yapma ve yeni döngüye hazırlanma zamanı.'
          : 'Time for resting, clearing your mind, meditating, and preparing for the next cycle.';
    } else {
      emoji = '🌑';
      name = isTr ? 'Yeni Ay' : 'New Moon';
      desc = isTr
          ? 'Niyetlerinizi belirlemek, taze başlangıçlar yapmak ve tohum ekmek için ideal kozmik zaman.'
          : 'Ideal cosmic time for setting intentions, starting fresh, and planting seeds.';
    }

    setState(() {
      _calcDate = date;
      _calcPhaseName = name;
      _calcPhaseEmoji = emoji;
      _calcPhaseDesc = desc;
      _calcMoonAge = moonAge;
    });
  }

  // Tarih seçimi tetikleme
  Future<void> _selectCalcDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _calcDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.dark(
              primary: AppColors.primaryGold,
              onPrimary: AppColors.cardSurface,
              surface: AppColors.cardSurface,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      _calculatePhaseForDate(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(languageProvider);
    final isTr = locale.languageCode == 'tr';

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(isTr ? 'Ay Fazları Takvimi' : 'Moon Phases'),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: StarBackground(
        child: SafeArea(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: AppColors.primaryGold))
              : SingleChildScrollView(
                  padding: const EdgeInsets.only(left: 20.0, right: 20.0, top: 10.0, bottom: 40.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. Bir Sonraki Dolunay Kartı
                      if (_nextFullMoon != null) ...[
                        _buildNextFullMoonCard(isTr),
                        const SizedBox(height: 24),
                      ],

                      // 2. Ay Fazı Hesaplayıcı Kartı
                      Text(
                        isTr ? 'Kozmik Ay Fazı Hesaplayıcı' : 'Cosmic Moon Phase Calculator',
                        style: AppTextStyles.h3,
                      ),
                      const SizedBox(height: 12),
                      _buildCalculatorCard(isTr),
                      const SizedBox(height: 24),

                      // 3. 2026 Dolunay ve Yeniay Takvimi
                      Text(
                        isTr ? '2026 Dolunay & Yeniay Listesi' : '2026 Full Moon & New Moon Calendar',
                        style: AppTextStyles.h3,
                      ),
                      const SizedBox(height: 12),
                      _buildLunarEventsCard(isTr),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  // Bir Sonraki Dolunay Gösterim Kartı
  Widget _buildNextFullMoonCard(bool isTr) {
    final name = isTr ? _nextFullMoon!['nameTr'] : _nextFullMoon!['nameEn'];
    final dateStr = _nextFullMoon!['date'] as String;
    final parsedDate = DateTime.parse(dateStr);
    final formattedDate = DateFormat('d MMMM yyyy', isTr ? 'tr' : 'en').format(parsedDate);

    return GlassCard(
      color: AppColors.primaryGold.withValues(alpha: 0.1),
      border: Border.all(color: AppColors.primaryGold.withValues(alpha: 0.4), width: 1.5),
      child: Column(
        children: [
          Row(
            children: [
              const Text('🌕', style: TextStyle(fontSize: 32))
                  .animate(onPlay: (controller) => controller.repeat(reverse: true))
                  .scale(begin: const Offset(1, 1), end: const Offset(1.15, 1.15), duration: 1200.ms),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isTr ? 'Sıradaki Dolunay' : 'Next Full Moon',
                      style: AppTextStyles.caption.copyWith(color: AppColors.primaryGold, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      name,
                      style: AppTextStyles.h3.copyWith(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      formattedDate,
                      style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 24, color: AppColors.primaryGold),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isTr ? 'Kozmik Hasata Kalan Süre:' : 'Time Until Cosmic Harvest:',
                style: AppTextStyles.bodyMedium,
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  gradient: AppColors.goldGradient,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  isTr ? '$_daysUntilNextFullMoon Gün' : '$_daysUntilNextFullMoon Days',
                  style: AppTextStyles.label.copyWith(color: AppColors.cardSurface, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ],
      ),
    ).animate().fade(duration: 450.ms);
  }

  // Faz Hesaplama Kartı
  Widget _buildCalculatorCard(bool isTr) {
    final formattedCalcDate = DateFormat('dd MMMM yyyy', isTr ? 'tr' : 'en').format(_calcDate);

    return GlassCard(
      child: Column(
        children: [
          Row(
            children: [
              // Büyük Faz Emojisi
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white10),
                ),
                alignment: Alignment.center,
                child: Text(
                  _calcPhaseEmoji,
                  style: const TextStyle(fontSize: 44),
                ),
              ).animate(key: ValueKey(_calcPhaseEmoji)).scale(duration: 300.ms, curve: Curves.easeOutBack),
              const SizedBox(width: 16),
              // Faz Detayı
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isTr ? 'Seçilen Tarih Fazı:' : 'Phase for Selected Date:',
                      style: AppTextStyles.caption,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _calcPhaseName,
                      style: AppTextStyles.h4.copyWith(color: AppColors.primaryGold, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '${isTr ? 'Ay Yaşı' : 'Moon Age'}: ${_calcMoonAge.toStringAsFixed(1)} ${isTr ? 'gün' : 'days'}',
                      style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            _calcPhaseDesc,
            style: AppTextStyles.bodyMedium.copyWith(height: 1.5),
          ),
          const SizedBox(height: 20),
          GradientButton(
            text: '$formattedCalcDate 📅',
            onTap: () => _selectCalcDate(context),
          ),
        ],
      ),
    ).animate().fade(delay: 100.ms);
  }

  // 2026 Ay Olayları Listesi
  Widget _buildLunarEventsCard(bool isTr) {
    return GlassCard(
      padding: EdgeInsets.zero,
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _fullMoons.length,
        separatorBuilder: (context, index) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final fm = _fullMoons[index];
          final nm = index < _newMoons.length ? _newMoons[index] : null;

          final fmDate = DateTime.parse(fm['date']);
          final fmFormatted = DateFormat('dd MMM yyyy', isTr ? 'tr' : 'en').format(fmDate);
          final fmName = isTr ? fm['nameTr'] : fm['nameEn'];

          String nmFormatted = '';
          String nmName = '';
          if (nm != null) {
            final nmDate = DateTime.parse(nm['date']);
            nmFormatted = DateFormat('dd MMM yyyy', isTr ? 'tr' : 'en').format(nmDate);
            nmName = isTr ? nm['nameTr'] : nm['nameEn'];
          }

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: Row(
              children: [
                // Dolunay sütunu
                Expanded(
                  child: Row(
                    children: [
                      const Text('🌕', style: TextStyle(fontSize: 16)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              fmName,
                              style: AppTextStyles.label.copyWith(fontSize: 12, fontWeight: FontWeight.bold),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              fmFormatted,
                              style: AppTextStyles.caption.copyWith(fontSize: 10),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // Ortada ince bölücü
                Container(
                  height: 28,
                  width: 1,
                  color: Colors.white12,
                ),
                const SizedBox(width: 12),
                // Yeniay sütunu
                if (nm != null)
                  Expanded(
                    child: Row(
                      children: [
                        const Text('🌑', style: TextStyle(fontSize: 16)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                nmName,
                                style: AppTextStyles.label.copyWith(fontSize: 12, fontWeight: FontWeight.bold),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                nmFormatted,
                                style: AppTextStyles.caption.copyWith(fontSize: 10),
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
        },
      ),
    ).animate().fade(delay: 200.ms);
  }
}
