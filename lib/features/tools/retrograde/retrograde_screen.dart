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
import 'package:horoscope/shared/widgets/star_background.dart';

class RetrogradeScreen extends ConsumerStatefulWidget {
  const RetrogradeScreen({super.key});

  @override
  ConsumerState<RetrogradeScreen> createState() => _RetrogradeScreenState();
}

class _RetrogradeScreenState extends ConsumerState<RetrogradeScreen> {
  bool _isLoading = true;
  List<dynamic> _activeRetrogrades = [];
  List<dynamic> _upcomingRetrogrades = [];

  @override
  void initState() {
    super.initState();
    _loadRetrogradeData();
  }

  Future<void> _loadRetrogradeData() async {
    try {
      final jsonStr = await rootBundle.loadString('assets/data/astro_calendar_2026.json');
      final data = jsonDecode(jsonStr);
      final list = data['retrogrades'] as List<dynamic>;

      final now = DateTime.now();
      final todayStr = DateFormat('yyyy-MM-dd').format(now);
      
      final List<dynamic> active = [];
      final List<dynamic> upcoming = [];

      for (final r in list) {
        final start = r['start'] as String;
        final end = r['end'] as String;

        if (todayStr.compareTo(start) >= 0 && todayStr.compareTo(end) <= 0) {
          active.add(r);
        } else {
          upcoming.add(r);
        }
      }

      setState(() {
        _activeRetrogrades = active;
        _upcomingRetrogrades = upcoming;
        _isLoading = false;
      });

    } catch (e) {
      debugPrint('⚠️ Retro verisi yükleme hatası: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(languageProvider);
    final isTr = locale.languageCode == 'tr';

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(isTr ? 'Geri Giden Gezegenler' : 'Retrograde Periods'),
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
                      // 1. Giriş Bilgisi
                      _buildIntroCard(isTr),
                      const SizedBox(height: 24),

                      // 2. Aktif Retrogradeler (Varsa)
                      if (_activeRetrogrades.isNotEmpty) ...[
                        Text(
                          isTr ? 'Şu Anda Aktif Retrogradeler ⚡' : 'Currently Active Retrogrades ⚡',
                          style: AppTextStyles.h3.copyWith(color: AppColors.primaryGold),
                        ),
                        const SizedBox(height: 12),
                        ... _activeRetrogrades.map((r) => _buildRetroCard(r, isTr, true)),
                        const SizedBox(height: 24),
                      ],

                      // 3. Tümü / Gelecek Retrogradeler
                      Text(
                        isTr ? '2026 Retrograde Takvimi' : '2026 Retrograde Schedule',
                        style: AppTextStyles.h3,
                      ),
                      const SizedBox(height: 12),
                      ... _upcomingRetrogrades.map((r) => _buildRetroCard(r, isTr, false)),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildIntroCard(bool isTr) {
    return GlassCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('🪐', style: TextStyle(fontSize: 32)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isTr ? 'Retrograd Nedir?' : 'What is a Retrograde?',
                  style: AppTextStyles.label.copyWith(color: AppColors.primaryGold, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Text(
                  isTr
                      ? 'Bir gezegenin dünyadan bakıldığında gökyüzünde geriye gidiyormuş gibi göründüğü süreçtir. Bu dönemler yeni başlangıçlar yerine yavaşlama, geçmişi değerlendirme ve eksikleri tamamlama zamanıdır.'
                      : 'It is a period where a planet appears to move backward in the sky from Earth\'s perspective. These times are meant for slowing down, reflecting, and wrapping up the past, rather than starting anew.',
                  style: AppTextStyles.bodyMedium.copyWith(height: 1.45),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fade(duration: 400.ms);
  }

  Widget _buildRetroCard(Map<String, dynamic> r, bool isTr, bool isActive) {
    final planet = isTr ? r['planet'] : r['planetEn'];
    final symbol = r['symbol'] as String;
    final startStr = r['start'] as String;
    final endStr = r['end'] as String;
    
    final parsedStart = DateTime.parse(startStr);
    final parsedEnd = DateTime.parse(endStr);
    
    final formattedStart = DateFormat('d MMM', isTr ? 'tr' : 'en').format(parsedStart);
    final formattedEnd = DateFormat('d MMM yyyy', isTr ? 'tr' : 'en').format(parsedEnd);

    final area = isTr ? r['areaTr'] : r['areaEn'];
    final desc = isTr ? r['descTr'] : r['descEn'];

    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: GlassCard(
        color: isActive 
            ? AppColors.warmAmber.withValues(alpha: 0.12)
            : AppColors.cardSurface,
        border: Border.all(
          color: isActive 
              ? AppColors.primaryGold.withValues(alpha: 0.5)
              : Colors.white10,
          width: isActive ? 1.5 : 1,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: AppColors.primaryGold.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.primaryGold.withValues(alpha: 0.3)),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        symbol,
                        style: const TextStyle(fontSize: 20, color: AppColors.primaryGold, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          planet,
                          style: AppTextStyles.h4.copyWith(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '$formattedStart - $formattedEnd',
                          style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ],
                ),
                if (isActive)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primaryGold.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.primaryGold),
                    ),
                    child: Text(
                      isTr ? 'AKTİF' : 'ACTIVE',
                      style: AppTextStyles.caption.copyWith(color: AppColors.primaryGold, fontWeight: FontWeight.bold, fontSize: 10),
                    ),
                  ),
              ],
            ),
            const Divider(height: 20),
            // Etki Alanı
            RichText(
              text: TextSpan(
                style: AppTextStyles.bodyMedium,
                children: [
                  TextSpan(
                    text: '${isTr ? 'Etkilediği Alan' : 'Area of Effect'}: ',
                    style: const TextStyle(color: AppColors.primaryGold, fontWeight: FontWeight.bold),
                  ),
                  TextSpan(text: area),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // Açıklama / Öneri
            Text(
              desc,
              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary, height: 1.45),
            ),
          ],
        ),
      ),
    )
        .animate()
        .fade(duration: 400.ms)
        .slideY(begin: 0.08, duration: 400.ms);
  }
}
