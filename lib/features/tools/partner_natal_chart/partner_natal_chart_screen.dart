import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:horoscope/core/constants/app_colors.dart';
import 'package:horoscope/core/constants/app_text_styles.dart';
import 'package:horoscope/core/models/natal_chart_model.dart';
import 'package:horoscope/core/providers/user_provider.dart';
import 'package:horoscope/core/providers/language_provider.dart';
import 'package:horoscope/core/services/ai_service.dart';
import 'package:horoscope/shared/widgets/glass_card.dart';
import 'package:horoscope/shared/widgets/gradient_button.dart';
import 'package:horoscope/shared/widgets/star_background.dart';
import 'package:horoscope/shared/widgets/birth_place_search_sheet.dart';
import 'package:horoscope/shared/widgets/custom_toast.dart';
import 'package:horoscope/features/natal_chart/natal_chart_screen.dart'; // To reuse NatalChartPainter
import 'package:horoscope/core/services/ad_service.dart';

class PartnerNatalChartScreen extends ConsumerStatefulWidget {
  const PartnerNatalChartScreen({super.key});

  @override
  ConsumerState<PartnerNatalChartScreen> createState() => _PartnerNatalChartScreenState();
}

class _PartnerNatalChartScreenState extends ConsumerState<PartnerNatalChartScreen> {
  final _nameController = TextEditingController();
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  String? _selectedPlace;
  String? _selectedGender;
  bool _isLoading = false;
  NatalChartModel? _result;
  String? _currentResultName;

  List<_PartnerNatalChartHistoryItem> _history = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadHistory();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    final user = ref.read(userProvider);
    if (user == null) return;

    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('users/${user.uid}/partner_natal_charts')
          .get();

      final items = querySnapshot.docs.map((doc) {
        final data = doc.data();
        final chart = NatalChartModel.fromMap(data);
        final name = data['name'] ?? doc.id;
        return _PartnerNatalChartHistoryItem(name: name, chart: chart);
      }).toList();

      items.sort((a, b) => b.chart.calculatedAt.compareTo(a.chart.calculatedAt));

      if (mounted) {
        setState(() {
          _history = items;
        });
      }
    } catch (e) {
      debugPrint('⚠️ Partner doğum haritası geçmişi okuma hatası: $e');
    }
  }

  // Tarih seçme diyaloğu
  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime(2000, 1, 1),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
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
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  // Saat seçme diyaloğu
  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 12, minute: 0),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            timePickerTheme: TimePickerThemeData(
              backgroundColor: AppColors.cardSurface,
              dialHandColor: AppColors.primaryGold,
              dialBackgroundColor: Colors.white12,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedTime) {
      setState(() {
        _selectedTime = picked;
      });
    }
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

  // Doğum haritası hesapla
  Future<void> _calculateNatalChart() async {
    final user = ref.read(userProvider);
    if (user == null) return;

    final isTr = ref.read(languageProvider).languageCode == 'tr';
    final name = _nameController.text.trim();

    if (name.isEmpty) {
      CustomToast.show(
        context,
        isTr ? 'Lütfen bir isim girin!' : 'Please enter a name!',
        isError: true,
      );
      return;
    }

    if (_selectedGender == null) {
      CustomToast.show(
        context,
        isTr ? 'Lütfen cinsiyet seçin!' : 'Please select gender!',
        isError: true,
      );
      return;
    }

    if (_selectedDate == null) {
      CustomToast.show(
        context,
        isTr ? 'Lütfen doğum tarihini seçin!' : 'Please select birth date!',
        isError: true,
      );
      return;
    }

    if (_selectedTime == null) {
      CustomToast.show(
        context,
        isTr ? 'Lütfen doğum saatini seçin!' : 'Please select birth time!',
        isError: true,
      );
      return;
    }

    if (_selectedPlace == null) {
      CustomToast.show(
        context,
        isTr ? 'Lütfen doğum yerini seçin!' : 'Please select birth place!',
        isError: true,
      );
      return;
    }

    final String timeStr = '${_selectedTime!.hour.toString().padLeft(2, '0')}:${_selectedTime!.minute.toString().padLeft(2, '0')}';
    final String normalizedDocName = name.toLowerCase().replaceAll(' ', '_');
    final String partnerPath = 'users/${user.uid}/partner_natal_charts/$normalizedDocName';

    final limitInfo = await AiService().checkAiToolsDailyLimit(user.uid);
    if (limitInfo['allowed'] == false) {
      _showAiToolsLimitDialog(isTr, user.uid, () {
        _executeCalculation(user.uid, name, timeStr, partnerPath, _selectedGender!);
      });
      return;
    }

    _executeCalculation(user.uid, name, timeStr, partnerPath, _selectedGender!);
  }

  Future<void> _executeCalculation(String userId, String name, String timeStr, String partnerPath, String gender) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final chart = await AiService().calculateAndSaveNatalChart(
        userId: userId,
        name: name,
        birthDate: _selectedDate!,
        birthTime: timeStr,
        birthPlace: _selectedPlace!,
        customPath: partnerPath,
        gender: gender,
        forceRecalculate: true,
      );

      if (chart != null) {
        await AiService().incrementAiToolsCalculationCount(userId);
      }

      if (chart != null && mounted) {
        setState(() {
          _result = chart;
          _currentResultName = name;
          _isLoading = false;
          _history.removeWhere((item) => item.name.toLowerCase() == name.toLowerCase());
          _history.insert(0, _PartnerNatalChartHistoryItem(name: name, chart: chart));
        });
      } else {
        setState(() {
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
    final locale = ref.watch(languageProvider);
    final isTr = locale.languageCode == 'tr';

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(isTr ? 'Astro Portre Hesapla' : 'Astro Portrait Creator'),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: StarBackground(
        child: SafeArea(
          child: _isLoading
              ? _buildLoadingView(isTr)
              : _result != null
                  ? _buildResultView(isTr)
                  : _buildFormView(isTr),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: AdService.instance.getBannerAdWidget(
          'partner_chart_banner',
          isPremium: ref.watch(userProvider)?.isPremium ?? false,
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
            const CircularProgressIndicator(color: AppColors.primaryGold),
            const SizedBox(height: 24),
            Text(
              isTr ? 'Yıldız Haritası Çiziliyor...' : 'Drawing Sky Chart...',
              style: AppTextStyles.h3.copyWith(color: AppColors.primaryGold),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormView(bool isTr) {
    final dateStr = _selectedDate == null
        ? (isTr ? 'Doğum Tarihi Seç' : 'Select Birth Date')
        : DateFormat('dd.MM.yyyy').format(_selectedDate!);

    final timeStr = _selectedTime == null
        ? (isTr ? 'Doğum Saati Seç' : 'Select Birth Time')
        : '${_selectedTime!.hour.toString().padLeft(2, '0')}:${_selectedTime!.minute.toString().padLeft(2, '0')}';

    final placeStr = _selectedPlace ?? (isTr ? 'Doğum Yeri Seç' : 'Select Birth Place');

    return SingleChildScrollView(
      padding: const EdgeInsets.only(left: 20.0, right: 20.0, top: 10.0, bottom: 80.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isTr ? 'Kişinin Bilgileri' : 'Person\'s Information',
            style: AppTextStyles.h3,
          ),
          const SizedBox(height: 12),
          GlassCard(
            child: Column(
              children: [
                TextField(
                  controller: _nameController,
                  style: TextStyle(color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    icon: const Icon(Icons.person_outline_rounded, color: AppColors.primaryGold),
                    border: const UnderlineInputBorder(),
                    hintText: isTr ? 'Kişinin Adı / Takma Adı' : 'Person\'s Name / Nickname',
                    hintStyle: const TextStyle(color: Colors.white38),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isTr ? 'Cinsiyet' : 'Gender',
                      style: AppTextStyles.label.copyWith(color: AppColors.primaryGold),
                    ),
                    Row(
                      children: [
                        _buildGenderButton('female', isTr ? 'Kadın' : 'Female'),
                        const SizedBox(width: 8),
                        _buildGenderButton('male', isTr ? 'Erkek' : 'Male'),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: () => _selectDate(context),
                  child: GlassCard(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                    color: Colors.white.withValues(alpha: 0.03),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today_rounded, color: AppColors.primaryGold, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            dateStr,
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: _selectedDate == null ? Colors.white38 : AppColors.textPrimary,
                            ),
                          ),
                        ),
                        const Icon(Icons.arrow_drop_down, color: AppColors.primaryGold),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: () => _selectTime(context),
                  child: GlassCard(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                    color: Colors.white.withValues(alpha: 0.03),
                    child: Row(
                      children: [
                        const Icon(Icons.access_time_rounded, color: AppColors.primaryGold, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            timeStr,
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: _selectedTime == null ? Colors.white38 : AppColors.textPrimary,
                            ),
                          ),
                        ),
                        const Icon(Icons.arrow_drop_down, color: AppColors.primaryGold),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: () async {
                    final selected = await BirthPlaceSearchSheet.show(context);
                    if (selected != null) {
                      setState(() {
                        _selectedPlace = selected;
                      });
                    }
                  },
                  child: GlassCard(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                    color: Colors.white.withValues(alpha: 0.03),
                    child: Row(
                      children: [
                        const Icon(Icons.location_on_outlined, color: AppColors.primaryGold, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            placeStr,
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: _selectedPlace == null ? Colors.white38 : AppColors.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const Icon(Icons.arrow_drop_down, color: AppColors.primaryGold),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          GradientButton(
            text: isTr ? 'Haritayı Çıkar 🗺️' : 'Calculate Chart 🗺️',
            onTap: _calculateNatalChart,
          ),
          const SizedBox(height: 32),

          // Geçmiş Listesi
          if (_history.isNotEmpty) ...[
            Text(
              isTr ? 'Kozmik Geçmiş' : 'Cosmic History',
              style: AppTextStyles.h3,
            ),
            const SizedBox(height: 12),
            _buildHistoryList(isTr),
          ],
        ],
      ),
    );
  }

  Widget _buildGenderButton(String gender, String label) {
    final isSelected = _selectedGender == gender;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedGender = gender;
        });
      },
      child: GlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        border: Border.all(
          color: isSelected ? AppColors.primaryGold : AppColors.borderLight,
          width: isSelected ? 1.5 : 1.0,
        ),
        color: isSelected ? AppColors.primaryGold.withValues(alpha: 0.1) : Colors.white.withValues(alpha: 0.03),
        child: Text(
          label,
          style: AppTextStyles.bodyMedium.copyWith(
            color: isSelected ? AppColors.primaryGold : AppColors.textPrimary,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildResultView(bool isTr) {
    final chart = _result!;
    final List<MapEntry<String, String>> positions = chart.planetPositions.entries.toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.only(left: 20.0, right: 20.0, top: 10.0, bottom: 80.0),
      child: Column(
        children: [
          Text(
            isTr ? '${_currentResultName ?? ""}\'ın Astro Portresi' : '${_currentResultName ?? ""}\'s Astro Portrait',
            style: AppTextStyles.h3.copyWith(color: AppColors.primaryGold),
          ),
          const SizedBox(height: 12),

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

          // 3. Gezegenler ve Evler (Planets Table)
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

          // 4. Elements and Modalities
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
            const SizedBox(height: 24),
          ],

          // 5. Aspects
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
            const SizedBox(height: 24),
          ],

          // 6. Evler (Houses Table)
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
          const SizedBox(height: 32),
          GradientButton(
            text: isTr ? 'Başka Bir Portre Hesapla 🔄' : 'Calculate Another Portrait 🔄',
            onTap: () {
              setState(() {
                _result = null;
                _currentResultName = null;
                _nameController.clear();
                _selectedDate = null;
                _selectedTime = null;
                _selectedPlace = null;
              });
            },
          ),
        ],
      ),
    );
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

  Widget _buildSignSummaryCard(String title, String iconOrEmoji, String signName) {
    return Expanded(
      child: GlassCard(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        child: Column(
          children: [
            Text(title, style: AppTextStyles.caption),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(iconOrEmoji, style: const TextStyle(fontSize: 22)),
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

  void _showPlanetInterpretationBottomSheet(String planet, String sign, String house, bool isTr) {
    final user = ref.read(userProvider);
    if (user == null) return;
    final docName = _currentResultName!.toLowerCase().replaceAll(' ', '_');
    final docPath = 'users/${user.uid}/partner_natal_charts/$docName';

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
          initialInterpretations: _result?.interpretations,
          gender: _result?.gender,
        );
      },
    );
  }

  void _showRisingSignInterpretationSheet(String risingSign, bool isTr) {
    final user = ref.read(userProvider);
    if (user == null) return;
    final docName = _currentResultName!.toLowerCase().replaceAll(' ', '_');
    final docPath = 'users/${user.uid}/partner_natal_charts/$docName';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return RisingSignInterpretationSheet(
          risingSign: risingSign,
          isTr: isTr,
          docPath: docPath,
          initialInterpretations: _result?.interpretations,
        );
      },
    );
  }

  void _showHouseInterpretationBottomSheet(String houseNumber, String localizedSign, String rawSign, bool isTr) {
    final user = ref.read(userProvider);
    if (user == null) return;
    final docName = _currentResultName!.toLowerCase().replaceAll(' ', '_');
    final docPath = 'users/${user.uid}/partner_natal_charts/$docName';

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
          initialInterpretations: _result?.interpretations,
        );
      },
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

  Widget _buildHistoryList(bool isTr) {
    return SizedBox(
      height: 64,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _history.length,
        itemBuilder: (context, index) {
          final item = _history[index];
          return Container(
            width: 140,
            margin: const EdgeInsets.only(right: 12),
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _result = item.chart;
                  _currentResultName = item.name;
                });
              },
              child: GlassCard(
                padding: const EdgeInsets.all(10),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: AppTextStyles.bodyMedium.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryGold,
                        overflow: TextOverflow.ellipsis,
                      ),
                      maxLines: 1,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${_getZodiacIcon(item.chart.sunSign)} ${_getZodiacTrName(item.chart.sunSign, isTr)}',
                      style: AppTextStyles.caption.copyWith(fontSize: 9, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _PartnerNatalChartHistoryItem {
  final String name;
  final NatalChartModel chart;

  _PartnerNatalChartHistoryItem({
    required this.name,
    required this.chart,
  });
}
