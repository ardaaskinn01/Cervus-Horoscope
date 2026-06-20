import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:horoscope/core/constants/app_colors.dart';
import 'package:horoscope/core/constants/app_text_styles.dart';
import 'package:horoscope/core/models/natal_chart_model.dart';
import 'package:horoscope/core/providers/user_provider.dart';
import 'package:horoscope/core/providers/language_provider.dart';
import 'package:horoscope/core/services/ai_service.dart';
import 'package:horoscope/shared/widgets/glass_card.dart';
import 'package:horoscope/shared/widgets/gradient_button.dart';

class NatalChartScreen extends ConsumerStatefulWidget {
  const NatalChartScreen({super.key});

  @override
  ConsumerState<NatalChartScreen> createState() => _NatalChartScreenState();
}

class _NatalChartScreenState extends ConsumerState<NatalChartScreen> {
  bool _isLoading = false;
  NatalChartModel? _natalChart;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndLoadNatalChart();
    });
  }

  Future<void> _checkAndLoadNatalChart({bool forceRecalculate = false}) async {
    final user = ref.read(userProvider);
    if (user == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Önce Firestore'da var mı kontrol edelim
      final chart = await AiService().calculateAndSaveNatalChart(
        userId: user.uid,
        name: user.name ?? 'Gezgin',
        birthDate: user.birthDate ?? DateTime(2000, 1, 1),
        birthTime: user.birthTime ?? '12:00',
        birthPlace: user.birthPlace ?? 'İstanbul',
        gender: user.gender,
        forceRecalculate: forceRecalculate,
      );
      if (mounted) {
        setState(() {
          _natalChart = chart;
          _isLoading = false;
        });
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
    final user = ref.watch(userProvider);
    final locale = ref.watch(languageProvider);
    final isTr = locale.languageCode == 'tr';

    // Kullanıcının profil bilgileri eksikse uyarı göster
    final bool hasBirthData = user?.birthDate != null && user?.birthTime != null && user?.birthPlace != null;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(isTr ? 'Astro Portrem' : 'Astro Portrait'),
      ),
      body: _isLoading
          ? const Center(
              child: SizedBox(
                width: 32,
                height: 32,
                child: CircularProgressIndicator(
                  color: AppColors.primaryGold,
                  strokeWidth: 3,
                ),
              ),
            )
          : !hasBirthData
              ? _buildMissingDataView(isTr)
              : _natalChart == null
                  ? _buildCalculateView(isTr)
                  : _buildChartView(isTr),
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
                    ? 'Astro portrenizi çıkarabilmemiz için doğum tarihi, saati ve doğum yeri bilgileriniz gereklidir. Lütfen Ayarlar sekmesine gidip bu bilgileri doldurun.'
                    : 'We need your birth date, time, and place to calculate your Astro Portrait. Please update them in the Settings tab.',
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
        child: GlassCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('✨', style: TextStyle(fontSize: 48)),
              const SizedBox(height: 16),
              Text(
                isTr ? 'Astro Portreniz Çıkarılmaya Hazır' : 'Portrait Ready to Calculate',
                style: AppTextStyles.h3.copyWith(color: AppColors.primaryGold),
              ),
              const SizedBox(height: 12),
              Text(
                isTr
                    ? 'Yıldızların konumunu ve evlerinizin dağılımını hesaplamak için aşağıdaki butona basın.'
                    : 'Press the button below to calculate your planetary positions and houses.',
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyMedium,
              ),
              const SizedBox(height: 24),
              GradientButton(
                text: isTr ? 'Portremi Çıkar 🗺️' : 'Calculate Portrait 🗺️',
                onTap: _checkAndLoadNatalChart,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Doğum Haritası Gösterim Ekranı
  Widget _buildChartView(bool isTr) {
    final chart = _natalChart!;
    final List<MapEntry<String, String>> positions = chart.planetPositions.entries.toList();

    return RefreshIndicator(
      onRefresh: () => _checkAndLoadNatalChart(forceRecalculate: true),
      color: AppColors.primaryGold,
      backgroundColor: AppColors.cardSurface,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(left: 20.0, right: 20.0, top: 10.0, bottom: 160.0),
        child: Column(
          children: [


            // 2. Önemli Burçlar Kartı
            Row(
              children: [
                _buildSignSummaryCard(isTr ? 'Güneş Burcu' : 'Sun Sign', _getZodiacIcon(chart.sunSign), _getZodiacTrName(chart.sunSign, isTr)),
                const SizedBox(width: 12),
                _buildSignSummaryCard(isTr ? 'Ay Burcu' : 'Moon Sign', _getZodiacIcon(chart.moonSign), _getZodiacTrName(chart.moonSign, isTr)),
              ],
            ),
            const SizedBox(height: 12),
            _buildRisingSignCard(chart.risingSign, isTr),
            const SizedBox(height: 24),

            // 3. Gezegen Konumları / Tablo
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                isTr ? 'Gezegenler' : 'Planets',
                style: AppTextStyles.h3,
              ),
            ),
            const SizedBox(height: 12),
            if (chart.planetDetails != null && chart.planetDetails!.isNotEmpty)
              _buildPlanetsTable(chart.planetDetails!, isTr)
            else
              _buildLegacyPlanetPositions(positions),

            const SizedBox(height: 24),
            if (chart.elements != null && chart.modalities != null) ...[
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  isTr ? 'Element & Nitelik Dağılımı' : 'Elements & Modalities',
                  style: AppTextStyles.h3,
                ),
              ),
              const SizedBox(height: 12),
              _buildElementsAndModalitiesCard(chart.elements!, chart.modalities!, isTr),
            ],

            const SizedBox(height: 24),
            if (chart.aspects != null && chart.aspects!['list'] != null && (chart.aspects!['list'] as List).isNotEmpty) ...[
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  isTr ? 'Açılar (Aspects)' : 'Aspects',
                  style: AppTextStyles.h3,
                ),
              ),
              const SizedBox(height: 12),
              _buildAspectsTable(chart.aspects!['list'] as List<dynamic>, isTr),
            ],

            const SizedBox(height: 24),
            if (chart.houseDetails != null && chart.houseDetails!.isNotEmpty) ...[
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  isTr ? 'Evler' : 'Houses',
                  style: AppTextStyles.h3,
                ),
              ),
              const SizedBox(height: 12),
              _buildHousesTable(chart.houseDetails!, isTr),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPlanetsTable(Map<String, dynamic> planetDetails, bool isTr) {
    final planetsList = [
      'Güneş',
      'Ay',
      'Merkür',
      'Venüs',
      'Mars',
      'Jüpiter',
      'Satürn',
      'Uranüs',
      'Neptün',
      'Plüton',
      'Kuzey Düğümü',
      'Lilith',
      'Chiron',
    ];

    final Map<String, String> planetNameEn = {
      'Güneş': 'Sun',
      'Ay': 'Moon',
      'Merkür': 'Mercury',
      'Venüs': 'Venus',
      'Mars': 'Mars',
      'Jüpiter': 'Jupiter',
      'Satürn': 'Saturn',
      'Uranüs': 'Uranus',
      'Neptün': 'Neptune',
      'Plüton': 'Pluto',
      'Kuzey Düğümü': 'North Node',
      'Lilith': 'Lilith',
      'Chiron': 'Chiron',
    };

    final Map<String, String> signNameEn = {
      'Koç': 'Aries',
      'Boğa': 'Taurus',
      'İkizler': 'Gemini',
      'Yengeç': 'Cancer',
      'Aslan': 'Leo',
      'Başak': 'Virgo',
      'Terazi': 'Libra',
      'Akrep': 'Scorpio',
      'Yay': 'Sagittarius',
      'Oğlak': 'Capricorn',
      'Kova': 'Aquarius',
      'Balık': 'Pisces',
    };

    String getDirection(String raw, bool isTr) {
      final r = raw.toLowerCase();
      if (r.contains('retro') || r.contains('retró')) {
        return isTr ? 'Retro' : 'Retro';
      }
      return isTr ? 'Düz' : 'Direct';
    }

    final tableRows = <TableRow>[];

    // Header row
    tableRows.add(
      TableRow(
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.primaryGold.withValues(alpha: 0.3), width: 1.2)),
        ),
        children: [
          _buildHeaderCell(isTr ? 'Gezegen' : 'Planet'),
          _buildHeaderCell(isTr ? 'Burç' : 'Sign'),
          _buildHeaderCell(isTr ? 'Derece' : 'Degree'),
          _buildHeaderCell(isTr ? 'Ev' : 'House', alignment: Alignment.center),
          _buildHeaderCell(isTr ? 'Yön' : 'Dir'),
          _buildHeaderCell(isTr ? 'Yorum' : 'Info', alignment: Alignment.center),
        ],
      ),
    );

    for (final p in planetsList) {
      final data = planetDetails[p];
      if (data == null) continue;

      final sign = data['sign'] ?? '';
      final degree = data['degree'] ?? '';
      final house = data['house']?.toString() ?? '';
      final direction = data['direction'] ?? '';

      final localizedPlanetName = isTr ? p : (planetNameEn[p] ?? p);
      final localizedSignName = isTr ? sign : (signNameEn[sign] ?? sign);

      tableRows.add(
        TableRow(
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.05), width: 1)),
          ),
          children: [
            // Gezegen Symbol + Name
            _buildWidgetCell(
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_getPlanetSymbol(p), style: const TextStyle(fontSize: 16, color: AppColors.primaryGold)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      localizedPlanetName,
                      style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            // Burç Name
            _buildCell(localizedSignName),
            // Derece
            _buildCell(degree),
            // Ev
            _buildCell(house, alignment: Alignment.center),
            // Yön
            _buildCell(getDirection(direction, isTr)),
            // Yorum lock
            _buildWidgetCell(
              InkWell(
                onTap: () {
                  HapticFeedback.lightImpact();
                  _showPlanetInterpretationBottomSheet(p, localizedSignName, house, isTr);
                },
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primaryGold.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppColors.primaryGold.withValues(alpha: 0.3)),
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.auto_awesome, size: 12, color: AppColors.primaryGold),
                        const SizedBox(width: 4),
                        Text(
                          isTr ? 'Yorum' : 'Read',
                          style: const TextStyle(fontSize: 10, color: AppColors.primaryGold, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              alignment: Alignment.center,
            ),
          ],
        ),
      );
    }

    return GlassCard(
      padding: const EdgeInsets.all(12),
      child: Table(
        columnWidths: const {
          0: FlexColumnWidth(2.1),
          1: FlexColumnWidth(1.7),
          2: FlexColumnWidth(1.2),
          3: FlexColumnWidth(0.8),
          4: FlexColumnWidth(1.0),
          5: FlexColumnWidth(2.2),
        },
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        children: tableRows,
      ),
    );
  }

  Widget _buildRisingSignCard(String risingSign, bool isTr) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      child: Row(
        children: [
          const Text('🌅', style: TextStyle(fontSize: 26)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isTr ? 'Yükselen Burç (ASC)' : 'Rising Sign (ASC)',
                  style: AppTextStyles.caption,
                ),
                const SizedBox(height: 2),
                Text(
                  _getZodiacTrName(risingSign, isTr),
                  style: AppTextStyles.label.copyWith(color: AppColors.primaryGold, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          InkWell(
            onTap: () {
              HapticFeedback.lightImpact();
              _showRisingSignInterpretationSheet(risingSign, isTr);
            },
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: AppColors.primaryGold.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.primaryGold.withValues(alpha: 0.35)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.auto_awesome, size: 13, color: AppColors.primaryGold),
                  const SizedBox(width: 5),
                  Text(
                    isTr ? 'Yorum' : 'Read',
                    style: const TextStyle(fontSize: 11, color: AppColors.primaryGold, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHousesTable(Map<String, dynamic> houseDetails, bool isTr) {
    return GlassCard(
      padding: const EdgeInsets.all(12),
      child: _buildHousesFullTable(houseDetails, isTr),
    );
  }

  Widget _buildHousesFullTable(Map<String, dynamic> houseDetails, bool isTr) {
    final Map<String, String> signNameEn = {
      'Koç': 'Aries',
      'Boğa': 'Taurus',
      'İkizler': 'Gemini',
      'Yengeç': 'Cancer',
      'Aslan': 'Leo',
      'Başak': 'Virgo',
      'Terazi': 'Libra',
      'Akrep': 'Scorpio',
      'Yay': 'Sagittarius',
      'Oğlak': 'Capricorn',
      'Kova': 'Aquarius',
      'Balık': 'Pisces',
    };

    final tableRows = <TableRow>[];

    // Header row
    tableRows.add(
      TableRow(
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.primaryGold.withValues(alpha: 0.3), width: 1.2)),
        ),
        children: [
          _buildHeaderCell(isTr ? 'Ev' : 'House'),
          _buildHeaderCell(isTr ? 'Burç' : 'Sign'),
          _buildHeaderCell(isTr ? 'Derece' : 'Deg.'),
          _buildHeaderCell(isTr ? 'Yorum' : 'Info', alignment: Alignment.center),
        ],
      ),
    );

    for (int i = 1; i <= 12; i++) {
      final data = houseDetails[i.toString()];
      if (data == null) continue;

      final sign = data['sign'] ?? '';
      final degree = data['degree'] ?? '';
      final annotation = data['annotation'] ?? '';

      final localizedSignName = isTr ? sign : (signNameEn[sign] ?? sign);

      String houseLabel = i.toString();
      if (annotation.toString().isNotEmpty) {
        houseLabel += '\n($annotation)';
      }

      tableRows.add(
        TableRow(
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.05), width: 1)),
          ),
          children: [
            _buildCell(houseLabel, style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600)),
            _buildCell(localizedSignName),
            _buildCell(degree),
            _buildWidgetCell(
              InkWell(
                onTap: () {
                  HapticFeedback.lightImpact();
                  _showHouseInterpretationBottomSheet(i.toString(), localizedSignName, sign, isTr);
                },
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primaryGold.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppColors.primaryGold.withValues(alpha: 0.3)),
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.auto_awesome, size: 12, color: AppColors.primaryGold),
                        const SizedBox(width: 4),
                        Text(
                          isTr ? 'Yorum' : 'Read',
                          style: const TextStyle(fontSize: 10, color: AppColors.primaryGold, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              alignment: Alignment.center,
            ),
          ],
        ),
      );
    }

    return Table(
      columnWidths: const {
        0: FlexColumnWidth(1.4),
        1: FlexColumnWidth(1.8),
        2: FlexColumnWidth(1.4),
        3: FlexColumnWidth(1.8),
      },
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: tableRows,
    );
  }

  Widget _buildLegacyPlanetPositions(List<MapEntry<String, String>> positions) {
    return GlassCard(
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: positions.length,
        separatorBuilder: (context, index) => const Divider(height: 16),
        itemBuilder: (context, index) {
          final entry = positions[index];
          final symbol = _getPlanetSymbol(entry.key);
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(symbol, style: const TextStyle(fontSize: 18, color: AppColors.primaryGold)),
                  const SizedBox(width: 12),
                  Text(
                    entry.key,
                    style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              Text(
                entry.value,
                style: AppTextStyles.bodyMedium,
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeaderCell(String text, {Alignment alignment = Alignment.centerLeft}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 2.0),
      child: Align(
        alignment: alignment,
        child: Text(
          text,
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.primaryGold,
            fontWeight: FontWeight.bold,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  Widget _buildCell(String text, {Alignment alignment = Alignment.centerLeft, TextStyle? style}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 2.0),
      child: Align(
        alignment: alignment,
        child: Text(
          text,
          style: style ?? AppTextStyles.bodyMedium,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  Widget _buildWidgetCell(Widget child, {Alignment alignment = Alignment.centerLeft}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 2.0),
      child: Align(
        alignment: alignment,
        child: child,
      ),
    );
  }

  Widget _buildSignSummaryCard(String label, String icon, String signName) {
    return Expanded(
      child: GlassCard(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        child: Column(
          children: [
            Text(label, style: AppTextStyles.caption),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(icon, style: const TextStyle(fontSize: 22)),
                const SizedBox(width: 8),
                Text(
                  signName,
                  style: AppTextStyles.label.copyWith(color: AppColors.primaryGold, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _getZodiacIcon(String key) {
    switch (key.toLowerCase()) {
      case 'aries': return '♈';
      case 'taurus': return '♉';
      case 'gemini': return '♊';
      case 'cancer': return '♋';
      case 'leo': return '♌';
      case 'virgo': return '♍';
      case 'libra': return '♎';
      case 'scorpio': return '♏';
      case 'sagittarius': return '♐';
      case 'capricorn': return '♑';
      case 'aquarius': return '♒';
      case 'pisces': return '♓';
      default: return '🔮';
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

  Widget _buildElementsAndModalitiesCard(Map<String, int> elements, Map<String, int> modalities, bool isTr) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildElementStat('🔥', isTr ? 'Ateş' : 'Fire', elements['Fire'] ?? 0),
              _buildElementStat('🌍', isTr ? 'Toprak' : 'Earth', elements['Earth'] ?? 0),
              _buildElementStat('💨', isTr ? 'Hava' : 'Air', elements['Air'] ?? 0),
              _buildElementStat('💧', isTr ? 'Su' : 'Water', elements['Water'] ?? 0),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12.0),
            child: Divider(color: Colors.white12),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildElementStat('⚡', isTr ? 'Öncü' : 'Cardinal', modalities['Cardinal'] ?? 0),
              _buildElementStat('⚓', isTr ? 'Sabit' : 'Fixed', modalities['Fixed'] ?? 0),
              _buildElementStat('🌊', isTr ? 'Değişken' : 'Mutable', modalities['Mutable'] ?? 0),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildElementStat(String emoji, String name, int count) {
    return Column(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 20)),
        const SizedBox(height: 4),
        Text(name, style: AppTextStyles.caption),
        const SizedBox(height: 2),
        Text(count.toString(), style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.bold, color: AppColors.primaryGold)),
      ],
    );
  }

  Widget _buildAspectsTable(List<dynamic> aspectsList, bool isTr) {
    return GlassCard(
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: aspectsList.length,
        separatorBuilder: (context, index) => const Divider(height: 8, color: Colors.white12),
        itemBuilder: (context, index) {
          final aspect = aspectsList[index] as Map<String, dynamic>;
          final p1 = aspect['planet1'] as String;
          final p2 = aspect['planet2'] as String;
          final aspectName = aspect['aspect'] as String;
          final orb = aspect['orb'] as double;
          final isHard = aspect['isHard'] as bool;

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            child: Row(
              children: [
                Text(_getPlanetSymbol(p1), style: const TextStyle(fontSize: 16, color: AppColors.primaryGold)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '$p1 - $p2',
                    style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                Text(
                  aspectName,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: isHard ? Colors.redAccent : Colors.lightBlueAccent,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Orb: ${orb.toStringAsFixed(1)}°',
                  style: AppTextStyles.caption.copyWith(color: Colors.white70),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showPlanetInterpretationBottomSheet(String planet, String sign, String house, bool isTr) {
    final user = ref.read(userProvider);
    if (user == null) return;
    final docPath = 'users/${user.uid}/natal_chart/data';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return PlanetInterpretationSheet(
          planet: planet,
          sign: sign,
          house: house,
          isTr: isTr,
          docPath: docPath,
          initialInterpretations: _natalChart?.interpretations,
          gender: _natalChart?.gender ?? user.gender,
        );
      },
    );
  }

  void _showRisingSignInterpretationSheet(String risingSign, bool isTr) {
    final user = ref.read(userProvider);
    if (user == null) return;
    final docPath = 'users/${user.uid}/natal_chart/data';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return RisingSignInterpretationSheet(
          risingSign: risingSign,
          isTr: isTr,
          docPath: docPath,
          initialInterpretations: _natalChart?.interpretations,
        );
      },
    );
  }

  void _showHouseInterpretationBottomSheet(String houseNumber, String localizedSign, String rawSign, bool isTr) {
    final user = ref.read(userProvider);
    if (user == null) return;
    final docPath = 'users/${user.uid}/natal_chart/data';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return HouseInterpretationSheet(
          houseNumber: houseNumber,
          localizedSign: localizedSign,
          rawSign: rawSign,
          isTr: isTr,
          docPath: docPath,
          initialInterpretations: _natalChart?.interpretations,
        );
      },
    );
  }

  String _getPlanetSymbol(String name) {
    switch (name) {
      case 'Güneş': return '☉';
      case 'Ay': return '☽';
      case 'Yükselen': return '🌅';
      case 'Merkür': return '☿';
      case 'Venüs': return '♀';
      case 'Mars': return '♂';
      case 'Jüpiter': return '♃';
      case 'Satürn': return '♄';
      case 'Uranüs': return '♅';
      case 'Neptün': return '♆';
      case 'Plüton': return '♇';
      default: return '✦';
    }
  }
}

// CustomPainter ile Doğum Haritası Çizimi
class NatalChartPainter extends CustomPainter {
  final Map<String, double> planetAngles;
  final double risingAngle; // Yükselen derecesi sol kenara (180°) sabitlenecek
  final double animationValue; // Çizim animasyonu değeri (0.0 - 1.0)
  final List<dynamic>? aspectsList;

  NatalChartPainter({
    required this.planetAngles,
    required this.risingAngle,
    required this.animationValue,
    this.aspectsList,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2 - 10;
    
    // Yükselen derecesini sola (180 derece) sabitlemek için gereken rotasyon açısı (radyan cinsinden)
    final double rotationOffset = (180.0 - risingAngle) * pi / 180.0;

    final Paint outlinePaint = Paint()
      ..color = AppColors.primaryGold.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    // 1. Dış ve İç Çemberlerin Çizilerek Oluşma Efekti (drawArc)
    final double sweepAngle = animationValue * 2 * pi;
    final Rect rectOuter = Rect.fromCircle(center: center, radius: radius);
    final Rect rectMiddle = Rect.fromCircle(center: center, radius: radius * 0.75);
    final Rect rectInner = Rect.fromCircle(center: center, radius: radius * 0.45);

    canvas.drawArc(rectOuter, 0, sweepAngle, false, outlinePaint);
    canvas.drawArc(rectMiddle, 0, sweepAngle, false, outlinePaint);
    canvas.drawArc(rectInner, 0, sweepAngle, false, outlinePaint);

    // 12 Burç Bölümü Çizimi
    final List<String> zodiacSymbols = ['♈', '♉', '♊', '♋', '♌', '♍', '♎', '♏', '♐', '♑', '♒', '♓'];
    
    for (int i = 0; i < 12; i++) {
      final double startAngle = (i * 30.0) * pi / 180.0 + rotationOffset;
      
      // Burçları bölen radyal çizgilerin merkezden dışarı büyüme efekti
      final double currentRadiusStart = radius * 0.45;
      final double currentRadiusEnd = radius * 0.45 + (radius - radius * 0.45) * animationValue;
      
      final double xStart = center.dx + currentRadiusStart * cos(startAngle);
      final double yStart = center.dy + currentRadiusStart * sin(startAngle);
      
      final double lineXEnd = center.dx + currentRadiusEnd * cos(startAngle);
      final double lineYEnd = center.dy + currentRadiusEnd * sin(startAngle);
      
      canvas.drawLine(Offset(xStart, yStart), Offset(lineXEnd, lineYEnd), outlinePaint);

      // Burç sembolünü dilimin ortasına yaz (Opaklık animasyonlu)
      final double symbolOpacity = (animationValue - 0.4).clamp(0.0, 0.6) * (1.0 / 0.6);
      if (symbolOpacity > 0.0) {
        final double textAngle = (i * 30.0 + 15.0) * pi / 180.0 + rotationOffset;
        final double tx = center.dx + radius * 0.875 * cos(textAngle);
        final double ty = center.dy + radius * 0.875 * sin(textAngle);

        final TextPainter tp = TextPainter(
          text: TextSpan(
            text: zodiacSymbols[i],
            style: TextStyle(
              color: AppColors.textPrimary.withValues(alpha: 0.7 * symbolOpacity),
              fontSize: radius * 0.08,
              fontFamily: 'sans-serif',
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        
        tp.paint(canvas, Offset(tx - tp.width / 2, ty - tp.height / 2));
      }
    }

    // 12 Ev Çizgileri (House Cusps) - Yükselen'den başlayıp merkezden dışa uzama efekti
    final Paint housePaint = Paint()
      ..color = AppColors.primaryGold.withValues(alpha: 0.2 * animationValue)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    for (int i = 0; i < 12; i++) {
      final double angle = (i * 30.0) * pi / 180.0 + rotationOffset + (risingAngle * pi / 180.0);
      final double currentHouseRadius = (radius * 0.75) * animationValue;
      final double hx = center.dx + currentHouseRadius * cos(angle);
      final double hy = center.dy + currentHouseRadius * sin(angle);
      
      canvas.drawLine(center, Offset(hx, hy), housePaint);
    }

    // Yükselen (ASC) ve Alçalan (DES) Yatay Eksen Çizgisi (Çizilerek uzama efekti)
    final Paint ascPaint = Paint()
      ..color = AppColors.primaryGold.withValues(alpha: animationValue)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    
    final double currentLineRadius = radius * animationValue;
    canvas.drawLine(
      Offset(center.dx - currentLineRadius, center.dy),
      Offset(center.dx + currentLineRadius, center.dy),
      ascPaint,
    );

    // ASC ve DES metinleri (Opaklık animasyonlu)
    final double labelOpacity = (animationValue - 0.7).clamp(0.0, 0.3) * (1.0 / 0.3);
    if (labelOpacity > 0.0) {
      _drawLabel(canvas, 'ASC', Offset(center.dx - radius - 15, center.dy), radius * 0.07, labelOpacity);
      _drawLabel(canvas, 'DSC', Offset(center.dx + radius + 15, center.dy), radius * 0.07, labelOpacity);
    }

    // Gezegenleri konumlandır (Merkezden dışarı kayarak yerleşme ve opaklık efekti)
    planetAngles.forEach((planet, angle) {
      if (planet == 'Yükselen') return; // Yükseleni zaten ASC çizgisiyle çizdik

      final double planetRad = angle * pi / 180.0 + rotationOffset;
      // Gezegenler merkezden radius * 0.6 konumuna doğru kayarak yerleşir
      final double planetRadiusFactor = radius * 0.6 * animationValue;
      final double px = center.dx + planetRadiusFactor * cos(planetRad);
      final double py = center.dy + planetRadiusFactor * sin(planetRad);

      // Küçük gezegen noktası çiz
      canvas.drawCircle(Offset(px, py), 2.5, Paint()..color = AppColors.primaryGold.withValues(alpha: animationValue));

      // Gezegen sembolünü yaz (Opaklık animasyonlu)
      final double planetOpacity = (animationValue - 0.5).clamp(0.0, 0.5) * 2.0;
      if (planetOpacity > 0.0) {
        final symbol = _getPlanetSymbol(planet);
        final TextPainter pt = TextPainter(
          text: TextSpan(
            text: symbol,
            style: TextStyle(
              color: AppColors.primaryGold.withValues(alpha: planetOpacity),
              fontSize: radius * 0.1,
              fontWeight: FontWeight.bold,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();

        pt.paint(canvas, Offset(px - pt.width / 2, py - pt.height / 2 - 8));
      }
    });

    // Draw aspects if available
    if (aspectsList != null && animationValue > 0.8) {
      final aspectOpacity = ((animationValue - 0.8) * 5).clamp(0.0, 1.0);
      for (final aspect in aspectsList!) {
        final p1 = aspect['planet1'] as String;
        final p2 = aspect['planet2'] as String;
        final isHard = aspect['isHard'] as bool;
        final aType = aspect['angle'] as int;

        final a1 = planetAngles[p1];
        final a2 = planetAngles[p2];
        if (a1 == null || a2 == null) continue;

        final rad1 = a1 * pi / 180.0 + rotationOffset;
        final rad2 = a2 * pi / 180.0 + rotationOffset;
        final innerRadius = radius * 0.45;

        final x1 = center.dx + innerRadius * cos(rad1);
        final y1 = center.dy + innerRadius * sin(rad1);
        final x2 = center.dx + innerRadius * cos(rad2);
        final y2 = center.dy + innerRadius * sin(rad2);

        Color aspectColor;
        if (aType == 120) {
          aspectColor = Colors.lightBlueAccent; // Trine
        } else if (aType == 60) {
          aspectColor = Colors.greenAccent; // Sextile
        } else if (isHard) {
          aspectColor = Colors.redAccent; // Square, Opposition
        } else {
          aspectColor = Colors.white54; // Conjunction
        }

        final aspectPaint = Paint()
          ..color = aspectColor.withValues(alpha: aspectOpacity * 0.4)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0;

        canvas.drawLine(Offset(x1, y1), Offset(x2, y2), aspectPaint);
      }
    }
  }

  void _drawLabel(Canvas canvas, String text, Offset offset, double fontSize, double opacity) {
    final TextPainter tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: AppColors.primaryGold.withValues(alpha: opacity),
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(offset.dx - tp.width / 2, offset.dy - tp.height / 2));
  }

  String _getPlanetSymbol(String name) {
    switch (name) {
      case 'Güneş': return '☉';
      case 'Ay': return '☽';
      case 'Merkür': return '☿';
      case 'Venüs': return '♀';
      case 'Mars': return '♂';
      case 'Jüpiter': return '♃';
      case 'Satürn': return '♄';
      case 'Uranüs': return '♅';
      case 'Neptün': return '♆';
      case 'Plüton': return '♇';
      default: return '✦';
    }
  }

  @override
  bool shouldRepaint(covariant NatalChartPainter oldDelegate) {
    return oldDelegate.planetAngles != planetAngles || 
        oldDelegate.risingAngle != risingAngle ||
        oldDelegate.animationValue != animationValue;
  }
}

// ─── Rising Sign Interpretation Sheet ───────────────────────────────────────
class RisingSignInterpretationSheet extends StatefulWidget {
  final String risingSign;
  final bool isTr;
  final String docPath;
  final Map<String, dynamic>? initialInterpretations;

  const RisingSignInterpretationSheet({
    super.key,
    required this.risingSign,
    required this.isTr,
    required this.docPath,
    this.initialInterpretations,
  });

  @override
  State<RisingSignInterpretationSheet> createState() => _RisingSignInterpretationSheetState();
}

class _RisingSignInterpretationSheetState extends State<RisingSignInterpretationSheet> {
  bool _isLoading = true;
  String? _interpretation;

  @override
  void initState() {
    super.initState();
    _fetchInterpretation();
  }

  Future<void> _fetchInterpretation() async {
    final langCode = widget.isTr ? 'tr' : 'en';
    final cacheKey = 'rising_${widget.risingSign}';

    // 1. Önce lokal önbelleği kontrol et
    final cachedText = widget.initialInterpretations?[langCode]?[cacheKey];
    if (cachedText != null && cachedText.toString().isNotEmpty) {
      if (mounted) {
        setState(() {
          _interpretation = cachedText.toString();
          _isLoading = false;
        });
      }
      return;
    }

    // 2. Gemini'dan üret
    final result = await AiService().generateRisingSignInterpretation(
      risingSign: widget.risingSign,
      languageCode: langCode,
    );

    if (result != null && result.isNotEmpty) {
      // 3. Firestore'a kaydet
      try {
        final docRef = FirebaseFirestore.instance.doc(widget.docPath);
        await docRef.update({
          'interpretations.$langCode.$cacheKey': result,
        });
        if (widget.initialInterpretations != null) {
          widget.initialInterpretations![langCode] ??= <String, dynamic>{};
          widget.initialInterpretations![langCode][cacheKey] = result;
        }
      } catch (e) {
        debugPrint('⚠️ Rising sign yorumu kaydedilemedi: $e');
      }
    }

    if (mounted) {
      setState(() {
        _interpretation = result;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  widget.isTr
                      ? '🌅 Yükselen Burç Yorumu'
                      : '🌅 Rising Sign Interpretation',
                  style: AppTextStyles.h2.copyWith(color: AppColors.primaryGold),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white70),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          Text(
            widget.isTr
                ? 'ASC · ${widget.risingSign}'
                : 'ASC · ${widget.risingSign}',
            style: AppTextStyles.bodyMedium.copyWith(color: Colors.white70),
          ),
          const SizedBox(height: 24),
          if (_isLoading)
            const Center(child: CircularProgressIndicator(color: AppColors.primaryGold))
          else if (_interpretation == null)
            Center(
              child: Text(
                widget.isTr ? 'Yorum yüklenemedi.' : 'Failed to load interpretation.',
                style: AppTextStyles.bodyMedium.copyWith(color: Colors.redAccent),
              ),
            )
          else
            Flexible(
              child: SingleChildScrollView(
                child: Text(_interpretation!, style: AppTextStyles.bodyLarge.copyWith(height: 1.6)),
              ),
            ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// ─── House Interpretation Sheet ──────────────────────────────────────────────
class HouseInterpretationSheet extends StatefulWidget {
  final String houseNumber;
  final String localizedSign;
  final String rawSign;
  final bool isTr;
  final String docPath;
  final Map<String, dynamic>? initialInterpretations;

  const HouseInterpretationSheet({
    super.key,
    required this.houseNumber,
    required this.localizedSign,
    required this.rawSign,
    required this.isTr,
    required this.docPath,
    this.initialInterpretations,
  });

  @override
  State<HouseInterpretationSheet> createState() => _HouseInterpretationSheetState();
}

class _HouseInterpretationSheetState extends State<HouseInterpretationSheet> {
  bool _isLoading = true;
  String? _interpretation;

  @override
  void initState() {
    super.initState();
    _fetchInterpretation();
  }

  Future<void> _fetchInterpretation() async {
    final langCode = widget.isTr ? 'tr' : 'en';
    final cacheKey = 'house_${widget.houseNumber}';

    // 1. Lokal önbellek
    final cachedText = widget.initialInterpretations?[langCode]?[cacheKey];
    if (cachedText != null && cachedText.toString().isNotEmpty) {
      if (mounted) {
        setState(() {
          _interpretation = cachedText.toString();
          _isLoading = false;
        });
      }
      return;
    }

    // 2. Gemini'dan üret
    final result = await AiService().generateHouseInterpretation(
      houseNumber: widget.houseNumber,
      sign: widget.rawSign,
      languageCode: langCode,
    );

    if (result != null && result.isNotEmpty) {
      try {
        final docRef = FirebaseFirestore.instance.doc(widget.docPath);
        await docRef.update({
          'interpretations.$langCode.$cacheKey': result,
        });
        if (widget.initialInterpretations != null) {
          widget.initialInterpretations![langCode] ??= <String, dynamic>{};
          widget.initialInterpretations![langCode][cacheKey] = result;
        }
      } catch (e) {
        debugPrint('⚠️ Ev yorumu kaydedilemedi: $e');
      }
    }

    if (mounted) {
      setState(() {
        _interpretation = result;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  widget.isTr
                      ? '🏠 ${widget.houseNumber}. Ev Yorumu'
                      : '🏠 House ${widget.houseNumber} Interpretation',
                  style: AppTextStyles.h2.copyWith(color: AppColors.primaryGold),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white70),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          Text(
            widget.localizedSign,
            style: AppTextStyles.bodyMedium.copyWith(color: Colors.white70),
          ),
          const SizedBox(height: 24),
          if (_isLoading)
            const Center(child: CircularProgressIndicator(color: AppColors.primaryGold))
          else if (_interpretation == null)
            Center(
              child: Text(
                widget.isTr ? 'Yorum yüklenemedi.' : 'Failed to load interpretation.',
                style: AppTextStyles.bodyMedium.copyWith(color: Colors.redAccent),
              ),
            )
          else
            Flexible(
              child: SingleChildScrollView(
                child: Text(_interpretation!, style: AppTextStyles.bodyLarge.copyWith(height: 1.6)),
              ),
            ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class PlanetInterpretationSheet extends StatefulWidget {
  final String planet;
  final String sign;
  final String house;
  final bool isTr;
  final String docPath;
  final Map<String, dynamic>? initialInterpretations;
  final String? gender;

  const PlanetInterpretationSheet({
    super.key,
    required this.planet,
    required this.sign,
    required this.house,
    required this.isTr,
    required this.docPath,
    this.initialInterpretations,
    this.gender,
  });

  @override
  State<PlanetInterpretationSheet> createState() => PlanetInterpretationSheetState();
}

class PlanetInterpretationSheetState extends State<PlanetInterpretationSheet> {
  bool _isLoading = true;
  String? _interpretation;

  @override
  void initState() {
    super.initState();
    _fetchInterpretation();
  }

  Future<void> _fetchInterpretation() async {
    final langCode = widget.isTr ? 'tr' : 'en';
    
    // 1. Önce lokal/hafızadaki önbelleği kontrol et
    final cachedText = widget.initialInterpretations?[langCode]?[widget.planet];
    if (cachedText != null && cachedText.toString().isNotEmpty) {
      if (mounted) {
        setState(() {
          _interpretation = cachedText.toString();
          _isLoading = false;
        });
      }
      return;
    }

    // 2. Yoksa Gemini'dan üret
    final result = await AiService().generatePlanetInterpretation(
      planet: widget.planet,
      sign: widget.sign,
      house: widget.house,
      languageCode: langCode,
      gender: widget.gender,
    );

    if (result != null && result.isNotEmpty) {
      // 3. Firestore'a kaydet (Astro Portre belgesine yaz)
      try {
        final docRef = FirebaseFirestore.instance.doc(widget.docPath);
        await docRef.update({
          "interpretations.$langCode.${widget.planet}": result,
        });

        // Lokal hafızadaki nesneyi de güncelle (aynı oturumda tekrar tıklanırsa API'ye gitmesin)
        if (widget.initialInterpretations != null) {
          if (widget.initialInterpretations![langCode] == null) {
            widget.initialInterpretations![langCode] = <String, dynamic>{};
          }
          widget.initialInterpretations![langCode][widget.planet] = result;
        }
      } catch (e) {
        debugPrint('⚠️ Planet yorumu Firestore kaydetme hatası: $e');
      }
    }

    if (mounted) {
      setState(() {
        _interpretation = result;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${widget.planet} ${widget.isTr ? 'Yorumu' : 'Interpretation'}',
                style: AppTextStyles.h2.copyWith(color: AppColors.primaryGold),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white70),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${widget.sign} • ${widget.house}. ${widget.isTr ? 'Ev' : 'House'}',
            style: AppTextStyles.bodyMedium.copyWith(color: Colors.white70),
          ),
          const SizedBox(height: 24),
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(color: AppColors.primaryGold),
            )
          else if (_interpretation == null)
            Center(
              child: Text(
                widget.isTr ? 'Yorum yüklenemedi. Lütfen tekrar deneyin.' : 'Failed to load interpretation. Please try again.',
                style: AppTextStyles.bodyMedium.copyWith(color: Colors.redAccent),
              ),
            )
          else
            Flexible(
              child: SingleChildScrollView(
                child: Text(
                  _interpretation!,
                  style: AppTextStyles.bodyLarge.copyWith(height: 1.6),
                ),
              ),
            ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
