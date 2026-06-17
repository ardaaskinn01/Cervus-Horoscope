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

class AstroCalendarScreen extends ConsumerStatefulWidget {
  const AstroCalendarScreen({super.key});

  @override
  ConsumerState<AstroCalendarScreen> createState() => _AstroCalendarScreenState();
}

class _AstroCalendarScreenState extends ConsumerState<AstroCalendarScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  List<dynamic> _yearlyEvents = [];
  Map<String, dynamic> _monthlyNotes = {};

  // Aylık Görünüm Tercihleri
  int _selectedMonth = DateTime.now().month;
  int _selectedDay = DateTime.now().day;
  Map<String, dynamic>? _activeDayNote;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadCalendarData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadCalendarData() async {
    try {
      final jsonStr = await rootBundle.loadString('assets/data/astro_calendar_2026.json');
      final data = jsonDecode(jsonStr);
      
      setState(() {
        _yearlyEvents = data['yearlyEvents'] as List<dynamic>;
        _monthlyNotes = Map<String, dynamic>.from(data['monthlyNotes'] ?? {});
        _isLoading = false;
      });
      _updateActiveDayNote(_selectedDay);

    } catch (e) {
      debugPrint('⚠️ Takvim verisi yükleme hatası: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Seçilen güne ait takvim notunu güncelle
  void _updateActiveDayNote(int day) {
    final monthNotes = _monthlyNotes[_selectedMonth.toString()] as List<dynamic>?;
    Map<String, dynamic>? foundNote;
    
    if (monthNotes != null) {
      for (final note in monthNotes) {
        if (note['day'] == day) {
          foundNote = Map<String, dynamic>.from(note);
          break;
        }
      }
    }
    
    setState(() {
      _selectedDay = day;
      _activeDayNote = foundNote;
    });
  }

  // Ay değiştirme
  void _changeMonth(int change) {
    int newMonth = _selectedMonth + change;
    if (newMonth < 1) newMonth = 12;
    if (newMonth > 12) newMonth = 1;
    
    setState(() {
      _selectedMonth = newMonth;
      _selectedDay = 1; // Ay değişince ilk güne dön
    });
    _updateActiveDayNote(1);
  }

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(languageProvider);
    final isTr = locale.languageCode == 'tr';

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(isTr ? 'Astroloji Takvimi 2026' : 'Astro Calendar 2026'),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: StarBackground(
        child: SafeArea(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: AppColors.primaryGold))
              : Column(
                  children: [
                    // TabBar seçici
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
                            Tab(text: isTr ? 'Aylık Etkiler' : 'Monthly Transits'),
                            Tab(text: isTr ? 'Önemli Olaylar' : 'Yearly Events'),
                          ],
                        ),
                      ),
                    ),
                    
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _buildMonthlyView(isTr),
                          _buildYearlyView(isTr),
                        ],
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  // 1. Aylık Takvim Görünümü
  Widget _buildMonthlyView(bool isTr) {
    final year = 2026;
    final date = DateTime(year, _selectedMonth, 1);
    final monthName = DateFormat('MMMM', isTr ? 'tr' : 'en').format(date);
    
    // Ayın kaç gün çektiği ve hangi gün başladığı
    final int totalDays = DateTime(year, _selectedMonth + 1, 0).day;
    final int startWeekday = DateTime(year, _selectedMonth, 1).weekday; // Pazartesi=1, Pazar=7

    final List<String> weekdays = isTr 
        ? ['Pt', 'Sa', 'Çr', 'Pr', 'Cu', 'Ct', 'Pz'] 
        : ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su'];

    // Aylık notlardaki günlerin listesi (Takvimde işaretlemek için)
    final monthNotes = _monthlyNotes[_selectedMonth.toString()] as List<dynamic>?;
    final List<int> notedDays = monthNotes?.map((note) => note['day'] as int).toList() ?? [];

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Column(
        children: [
          // Ay Seçici Başlık
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left, color: AppColors.primaryGold),
                onPressed: () => _changeMonth(-1),
              ),
              Text(
                '$monthName $year',
                style: AppTextStyles.h3.copyWith(color: AppColors.primaryGold, fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right, color: AppColors.primaryGold),
                onPressed: () => _changeMonth(1),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Takvim Haftalık Gün Başlıkları
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: weekdays.map((day) => Expanded(
              child: Center(
                child: Text(
                  day,
                  style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                ),
              ),
            )).toList(),
          ),
          const SizedBox(height: 8),

          // Takvim Izgarası
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: totalDays + (startWeekday - 1),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              crossAxisSpacing: 6,
              mainAxisSpacing: 6,
            ),
            itemBuilder: (context, index) {
              if (index < startWeekday - 1) {
                return const SizedBox();
              }
              
              final int dayNumber = index - (startWeekday - 2);
              final bool isSelected = dayNumber == _selectedDay;
              final bool hasNote = notedDays.contains(dayNumber);
              
              // Gün notunun kozmik rengini tespit et
              Color? noteColor;
              if (hasNote && monthNotes != null) {
                final note = monthNotes.firstWhere((n) => n['day'] == dayNumber);
                noteColor = note['type'] == 'positive' ? Colors.greenAccent : Colors.redAccent;
              }

              return GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  _updateActiveDayNote(dayNumber);
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: isSelected 
                        ? AppColors.primaryGold.withValues(alpha: 0.25)
                        : hasNote 
                            ? Colors.white.withValues(alpha: 0.03) 
                            : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected 
                          ? AppColors.primaryGold 
                          : hasNote 
                              ? noteColor!.withValues(alpha: 0.4) 
                              : Colors.white10,
                      width: isSelected ? 1.5 : 1,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        dayNumber.toString(),
                        style: AppTextStyles.bodyMedium.copyWith(
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isSelected 
                              ? AppColors.primaryGold 
                              : hasNote 
                                  ? AppColors.textPrimary 
                                  : AppColors.textSecondary,
                        ),
                      ),
                      if (hasNote) ...[
                        const SizedBox(height: 2),
                        Container(
                          width: 4,
                          height: 4,
                          decoration: BoxDecoration(
                            color: noteColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 20),

          // Alt Detay Kartı (Seçilen Gün Etkileri)
          _buildDayNoteCard(isTr),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildDayNoteCard(bool isTr) {
    if (_activeDayNote == null) {
      return GlassCard(
        child: Row(
          children: [
            const Text('✨', style: TextStyle(fontSize: 24)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                isTr 
                    ? '$_selectedDay. Gün için sakin ve rutin gökyüzü enerjileri hakim.'
                    : 'Calm and routine cosmic energies rule for day $_selectedDay.',
                style: AppTextStyles.bodyMedium,
              ),
            ),
          ],
        ),
      );
    }

    final note = _activeDayNote!;
    final moonSign = note['moonSign'] as String;
    final type = note['type'] as String;
    final isPositive = type == 'positive';
    final desc = isTr ? note['descTr'] : note['descEn'];

    return GlassCard(
      color: isPositive 
          ? Colors.green.withValues(alpha: 0.08)
          : Colors.red.withValues(alpha: 0.08),
      border: Border.all(
        color: isPositive 
            ? Colors.greenAccent.withValues(alpha: 0.3)
            : Colors.redAccent.withValues(alpha: 0.3),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    isPositive ? Icons.check_circle_rounded : Icons.warning_rounded,
                    color: isPositive ? Colors.greenAccent : Colors.redAccent,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isPositive 
                        ? (isTr ? 'Olumlu Kozmik Gün' : 'Positive Cosmic Day')
                        : (isTr ? 'Dikkatli Olunası Gün' : 'Day of Caution'),
                    style: AppTextStyles.label.copyWith(
                      color: isPositive ? Colors.greenAccent : Colors.redAccent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              // Ay burcu ikonu ve ismi
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white10,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '🌙 ${_getZodiacTrName(moonSign, isTr)}',
                  style: AppTextStyles.caption.copyWith(color: AppColors.primaryGold, fontSize: 10),
                ),
              ),
            ],
          ),
          const Divider(),
          Text(
            desc,
            style: AppTextStyles.bodyMedium.copyWith(height: 1.5),
          ),
        ],
      ),
    ).animate(key: ValueKey(_selectedDay)).fade(duration: 300.ms).slideY(begin: 0.05, duration: 300.ms);
  }

  // 2. Yıllık Takvim Görünümü
  Widget _buildYearlyView(bool isTr) {
    if (_yearlyEvents.isEmpty) {
      return Center(
        child: Text(
          isTr ? 'Yıllık takvim olayları bulunamadı.' : 'No yearly calendar events found.',
          style: AppTextStyles.bodyMedium,
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(left: 20.0, right: 20.0, top: 10.0, bottom: 40.0),
      itemCount: _yearlyEvents.length,
      itemBuilder: (context, index) {
        final event = _yearlyEvents[index];
        final eventDate = DateTime.parse(event['date']);
        final formattedDate = DateFormat('dd MMMM yyyy', isTr ? 'tr' : 'en').format(eventDate);
        final name = isTr ? event['nameTr'] : event['nameEn'];

        // Tutulma mı kontrol et
        final bool isEclipse = name.contains('Tutulması') || name.contains('Eclipse');

        return Padding(
          padding: const EdgeInsets.only(bottom: 12.0),
          child: GlassCard(
            color: isEclipse ? AppColors.warmAmber.withValues(alpha: 0.08) : AppColors.cardSurface,
            border: Border.all(
              color: isEclipse ? AppColors.primaryGold.withValues(alpha: 0.3) : Colors.white10,
            ),
            child: Row(
              children: [
                // İkon
                Text(
                  isEclipse ? '🌘' : '☀️',
                  style: const TextStyle(fontSize: 22),
                ),
                const SizedBox(width: 16),
                // Etkinlik Detayı
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: AppTextStyles.label.copyWith(
                          color: isEclipse ? AppColors.primaryGold : AppColors.textPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        formattedDate,
                        style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        )
            .animate()
            .fade(delay: (index * 60).ms, duration: 300.ms)
            .slideX(begin: 0.08, delay: (index * 60).ms, duration: 300.ms);
      },
    );
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
}
