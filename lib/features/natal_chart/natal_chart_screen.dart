import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:horoscope/core/constants/app_colors.dart';
import 'package:horoscope/core/constants/app_text_styles.dart';
import 'package:horoscope/core/models/natal_chart_model.dart';
import 'package:horoscope/core/providers/user_provider.dart';
import 'package:horoscope/core/providers/language_provider.dart';
import 'package:horoscope/core/services/ai_service.dart';
import 'package:horoscope/shared/widgets/glass_card.dart';
import 'package:horoscope/shared/widgets/gradient_button.dart';
import 'package:horoscope/shared/widgets/custom_toast.dart';
import 'package:horoscope/core/services/ad_service.dart';

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
        title: Text(isTr ? 'Doğum Haritam' : 'Natal Chart'),
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
                    ? 'Doğum haritanızı çıkarabilmemiz için doğum tarihi, saati ve doğum yeri bilgileriniz gereklidir. Lütfen Ayarlar sekmesine gidip bu bilgileri doldurun.'
                    : 'We need your birth date, time, and place to calculate your natal chart. Please update them in the Settings tab.',
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
                isTr ? 'Yıldız Haritanız Çıkarılmaya Hazır' : 'Chart Ready to Calculate',
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
                text: isTr ? 'Haritamı Çıkar 🗺️' : 'Calculate Chart 🗺️',
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
    final user = ref.watch(userProvider);

    return RefreshIndicator(
      onRefresh: () => _checkAndLoadNatalChart(forceRecalculate: true),
      color: AppColors.primaryGold,
      backgroundColor: AppColors.cardSurface,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(left: 20.0, right: 20.0, top: 10.0, bottom: 90.0),
        child: Column(
          children: [
            // 1. Dairesel CustomPainter Haritası
            AspectRatio(
              aspectRatio: 1,
              child: GlassCard(
                padding: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween<double>(begin: 0.0, end: 1.0),
                    duration: const Duration(milliseconds: 1500),
                    curve: Curves.easeOutCubic,
                    builder: (context, value, child) {
                      return CustomPaint(
                        painter: NatalChartPainter(
                          planetAngles: chart.planetAngles,
                          risingAngle: chart.planetAngles['Yükselen'] ?? 0.0,
                          animationValue: value,
                        ),
                      );
                    },
                  ),
                ),
              ),
            ).animate().fade().scale(duration: 400.ms),
            const SizedBox(height: 24),

            // 2. Önemli Burçlar Kartı
            Row(
              children: [
                _buildSignSummaryCard(isTr ? 'Güneş Burcu' : 'Sun Sign', _getZodiacIcon(chart.sunSign), _getZodiacTrName(chart.sunSign, isTr)),
                const SizedBox(width: 12),
                _buildSignSummaryCard(isTr ? 'Ay Burcu' : 'Moon Sign', _getZodiacIcon(chart.moonSign), _getZodiacTrName(chart.moonSign, isTr)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildSignSummaryCard(isTr ? 'Yükselen Burç' : 'Rising Sign (ASC)', '🌅', _getZodiacTrName(chart.risingSign, isTr)),
              ],
            ),
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
            const SizedBox(height: 24),
            AdService.instance.getBannerAdWidget('chart_banner', isPremium: user?.isPremium ?? false),
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
                  CustomToast.show(
                    context,
                    isTr
                        ? 'Bu özellik Premium abonelerimize özeldir! 🚀'
                        : 'This feature is exclusive to Premium subscribers! 🚀',
                  );
                },
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.lock_outline_rounded, size: 10, color: Colors.white.withValues(alpha: 0.5)),
                      const SizedBox(width: 2),
                      Text(
                        isTr ? 'Yorum' : 'Unlock',
                        style: const TextStyle(fontSize: 9, color: Colors.white70),
                      ),
                    ],
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
          0: FlexColumnWidth(2.3),
          1: FlexColumnWidth(1.9),
          2: FlexColumnWidth(1.5),
          3: FlexColumnWidth(0.9),
          4: FlexColumnWidth(1.2),
          5: FlexColumnWidth(1.7),
        },
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        children: tableRows,
      ),
    );
  }

  Widget _buildHousesTable(Map<String, dynamic> houseDetails, bool isTr) {
    return GlassCard(
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: _buildHousesSubTable(1, 6, houseDetails, isTr)),
          const SizedBox(width: 16),
          Expanded(child: _buildHousesSubTable(7, 12, houseDetails, isTr)),
        ],
      ),
    );
  }

  Widget _buildHousesSubTable(int start, int end, Map<String, dynamic> houseDetails, bool isTr) {
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
          _buildHeaderCell(isTr ? 'Derece' : 'Degree'),
        ],
      ),
    );

    for (int i = start; i <= end; i++) {
      final data = houseDetails[i.toString()];
      if (data == null) continue;

      final sign = data['sign'] ?? '';
      final degree = data['degree'] ?? '';
      final annotation = data['annotation'] ?? '';

      final localizedSignName = isTr ? sign : (signNameEn[sign] ?? sign);

      String houseLabel = i.toString();
      if (annotation.toString().isNotEmpty) {
        houseLabel += ' ($annotation)';
      }

      tableRows.add(
        TableRow(
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.05), width: 1)),
          ),
          children: [
            _buildCell(houseLabel, style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600)),
            // Burç Name
            _buildCell(localizedSignName),
            _buildCell(degree),
          ],
        ),
      );
    }

    return Table(
      columnWidths: const {
        0: FlexColumnWidth(1.6),
        1: FlexColumnWidth(2.0),
        2: FlexColumnWidth(1.6),
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

  NatalChartPainter({
    required this.planetAngles,
    required this.risingAngle,
    required this.animationValue,
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
