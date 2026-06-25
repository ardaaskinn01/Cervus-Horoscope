import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:horoscope/core/constants/app_colors.dart';
import 'package:horoscope/core/constants/app_text_styles.dart';
import 'package:horoscope/core/models/numerology_model.dart';
import 'package:horoscope/core/providers/language_provider.dart';
import 'package:horoscope/core/providers/user_provider.dart';
import 'package:horoscope/core/services/ai_service.dart';
import 'package:horoscope/shared/widgets/glass_card.dart';
import 'package:horoscope/shared/widgets/gradient_button.dart';
import 'package:horoscope/shared/widgets/star_background.dart';
import 'package:horoscope/shared/widgets/custom_toast.dart';
import 'package:horoscope/core/services/ad_service.dart';
import 'package:horoscope/core/utils/firestore_extension.dart';
import 'package:horoscope/core/utils/date_formatter.dart';

class PartnerNumerologyScreen extends ConsumerStatefulWidget {
  const PartnerNumerologyScreen({super.key});

  @override
  ConsumerState<PartnerNumerologyScreen> createState() => _PartnerNumerologyScreenState();
}

class _PartnerNumerologyScreenState extends ConsumerState<PartnerNumerologyScreen> {
  final _nameController = TextEditingController();
  final _dateController = TextEditingController();
  DateTime? _selectedDate;
  
  // Hesaplanan Sayılar
  int _lifePathNumber = 0;
  int _personalYearNumber = 0;
  int _activeYear = 2026;

  // AI Analiz Durumu
  bool _isLoadingAi = false;
  String? _aiAnalysisTr;
  String? _aiAnalysisEn;

  List<NumerologyModel> _history = [];

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
    _dateController.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    final user = ref.read(userProvider);
    if (user == null) return;

    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('users/${user.uid}/partner_numerology')
          .safeGet();

      final items = querySnapshot.docs.map((doc) {
        try {
          return NumerologyModel.fromMap(doc.data());
        } catch (e) {
          debugPrint('⚠️ Error parsing partner numerology doc ${doc.id}: $e');
          return null;
        }
      }).whereType<NumerologyModel>().toList();

      items.sort((a, b) => b.generatedAt.compareTo(a.generatedAt));

      if (mounted) {
        setState(() {
          _history = items;
        });
      }
    } catch (e) {
      debugPrint('⚠️ Partner numeroloji geçmişi okuma hatası: $e');
    }
  }

  // Tarih seçme diyaloğu
  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime(2000, 1, 1),
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
        _dateController.text = "${picked.day.toString().padLeft(2, '0')}.${picked.month.toString().padLeft(2, '0')}.${picked.year}";
        _calculateNumerology();
      });
      final name = _nameController.text.trim();
      if (name.isNotEmpty) {
        final formattedDate = "${picked.year}_${picked.month}_${picked.day}";
        _checkAndLoadCachedNumerology("${name}_$formattedDate");
      }
    }
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

  // Numeroloji hesaplayıcı
  void _calculateNumerology() {
    if (_selectedDate == null) return;
    final birth = _selectedDate!;

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
    _personalYearNumber = _reduceNumber(personalYearSum, allowMaster: false);
  }

  Future<void> _checkAndLoadCachedNumerology(String key) async {
    final user = ref.read(userProvider);
    if (user == null) return;

    try {
      final NumerologyModel? cached = await AiService().getSavedPartnerNumerology(
        userId: user.uid,
        key: key,
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
                        style: TextStyle(color: AppColors.textSecondary),
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

  // Gemini AI Rapor İsteme
  Future<void> _fetchAiNumerology() async {
    final user = ref.read(userProvider);
    if (user == null) return;

    final String name = _nameController.text.trim();
    final isTr = ref.read(languageProvider).languageCode == 'tr';

    if (name.isEmpty) {
      CustomToast.show(
        context,
        isTr ? 'Lütfen kişi ismi girin!' : 'Please enter a name!',
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

    try {
      final limitInfo = await AiService().checkAiToolsDailyLimit(user.uid);
      if (limitInfo['allowed'] == false) {
        _showAiToolsLimitDialog(isTr, user.uid, () {
          _executeCalculation(user.uid, name);
        });
        return;
      }
      _executeCalculation(user.uid, name);
    } catch (e) {
      debugPrint('⚠️ Limit check error: $e');
      _executeCalculation(user.uid, name);
    }
  }

  Future<void> _executeCalculation(String userId, String name) async {
    setState(() {
      _isLoadingAi = true;
    });

    final isTr = ref.read(languageProvider).languageCode == 'tr';

    try {
      final numerology = await AiService().generateAndSavePartnerNumerology(
        userId: userId,
        name: name,
        birthDate: _selectedDate!,
        lifePath: _lifePathNumber,
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
          _history.removeWhere((item) => item.name.toLowerCase() == numerology.name.toLowerCase());
          _history.insert(0, numerology);
        });
      } else {
        if (mounted) {
          setState(() { _isLoadingAi = false; });
          CustomToast.show(
            context,
            isTr ? 'Mistik rapor oluşturulamadı. Lütfen internetinizi kontrol edin.' : 'Could not generate cosmic report. Please check your internet connection.',
            isError: true,
          );
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() { _isLoadingAi = false; });
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
        title: Text(isTr ? 'Doğum Tarihi Numerolojisi' : 'Birth Date Numerology'),
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
                // 1. Giriş Kartı & Form
                Text(
                  isTr ? 'Hesaplama Formu' : 'Calculation Form',
                  style: AppTextStyles.h3,
                ),
                const SizedBox(height: 12),
                _buildFormCard(isTr),
                const SizedBox(height: 24),

                // 2. Kozmik Sayılar Grid (Tarih seçildiyse)
                if (_selectedDate != null) ...[
                  Text(
                    isTr ? 'Kozmik Sayılar' : 'Cosmic Numbers',
                    style: AppTextStyles.h3,
                  ),
                  const SizedBox(height: 12),
                  _buildNumbersGrid(isTr),
                  const SizedBox(height: 24),
                ],

                // 3. AI Rapor Kartı
                if (_selectedDate != null) ...[
                  Text(
                    isTr ? 'Mistik Rapor' : 'Mystic Report',
                    style: AppTextStyles.h3,
                  ),
                  const SizedBox(height: 12),
                  _buildAiAnalysisCard(isTr),
                  const SizedBox(height: 32),
                ],

                // 4. Geçmiş Analizler
                if (_history.isNotEmpty) ...[
                  Text(
                    isTr ? 'Geçmiş Analizler' : 'Past Analyses',
                    style: AppTextStyles.h3,
                  ),
                  const SizedBox(height: 12),
                  _buildHistoryList(isTr),
                ],
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: AdService.instance.getBannerAdWidget(
          'partner_numerology_banner',
          isPremium: ref.watch(userProvider)?.isPremium ?? false,
        ),
      ),
    );
  }

  Widget _buildFormCard(bool isTr) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _nameController,
            style: TextStyle(color: AppColors.textPrimary),
            decoration: InputDecoration(
              icon: const Icon(Icons.person_outline_rounded, color: AppColors.primaryGold),
              border: const UnderlineInputBorder(),
              hintText: isTr ? 'Kişinin Adı / Takma Adı' : 'Person\'s Name / Nickname',
              hintStyle: TextStyle(color: AppColors.textSecondary.withValues(alpha: 0.6)),
            ),
            onChanged: (text) {
              if (text.trim().isNotEmpty && _selectedDate != null) {
                final formattedDate = "${_selectedDate!.year}_${_selectedDate!.month}_${_selectedDate!.day}";
                _checkAndLoadCachedNumerology("${text.trim()}_$formattedDate");
              }
            },
          ),
          const SizedBox(height: 16),
          GlassCard(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
            color: AppColors.borderLight.withValues(alpha: 0.1),
            child: TextField(
              controller: _dateController,
              keyboardType: TextInputType.datetime,
              inputFormatters: [
                DateTextInputFormatter(),
                LengthLimitingTextInputFormatter(10),
              ],
              style: TextStyle(color: AppColors.textPrimary),
              onChanged: (val) {
                final date = parseFormattedDate(val);
                if (date != null) {
                  setState(() {
                    _selectedDate = date;
                    _calculateNumerology();
                  });
                  final name = _nameController.text.trim();
                  if (name.isNotEmpty) {
                    final formattedDate = "${date.year}_${date.month}_${date.day}";
                    _checkAndLoadCachedNumerology("${name}_$formattedDate");
                  }
                } else {
                  setState(() {
                    _selectedDate = null;
                  });
                }
              },
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: isTr ? 'Doğum Tarihi (GG.AA.YYYY)' : 'Birth Date (DD.MM.YYYY)',
                hintStyle: TextStyle(color: AppColors.textSecondary.withValues(alpha: 0.6)),
                icon: const Icon(Icons.calendar_today_rounded, color: AppColors.primaryGold, size: 20),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.arrow_drop_down, color: AppColors.primaryGold),
                  onPressed: () => _selectDate(context),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

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
          isTr ? 'Hayat amacını temsil eder' : 'Represents life purpose',
          Colors.amberAccent,
        ),
        _buildNumberCard(
          isTr ? 'Kişisel Yıl' : 'Personal Year',
          _personalYearNumber.toString(),
          isTr ? '$_activeYear yılı kozmik teması' : 'Cosmic theme in $_activeYear',
          Colors.blueAccent,
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

  Widget _buildAiAnalysisCard(bool isTr) {
    if (_isLoadingAi) {
      return GlassCard(
        child: Center(
          child: Column(
            children: [
              const CircularProgressIndicator(color: AppColors.primaryGold),
              const SizedBox(height: 16),
              Text(
                isTr ? 'Kozmik Rapor Hazırlanıyor...' : 'Preparing Cosmic Report...',
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
                  isTr ? 'Kozmik Analiz Sonucu' : 'Cosmic Analysis Result',
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

    final String name = _nameController.text.trim();
    final pathDetails = isTr
        ? (name.isNotEmpty
            ? '"$name" isimli arkadaşınızın doğum tarihine göre detaylı kozmik analiz raporunu oluşturun.'
            : 'Rapor oluşturmak için lütfen yukarıya kişi adı girin.')
        : (name.isNotEmpty
            ? 'Generate a detailed cosmic report for "$name" based on birth date.'
            : 'Please enter a name above to generate the report.');

    return GlassCard(
      child: Column(
        children: [
          const Text('🔮✨', style: TextStyle(fontSize: 32)),
          const SizedBox(height: 12),
          Text(
            pathDetails,
            style: AppTextStyles.bodyMedium,
            textAlign: TextAlign.center,
          ),
          if (name.isNotEmpty) ...[
            const SizedBox(height: 20),
            GradientButton(
              text: isTr ? 'Kozmik Raporu Oluştur' : 'Generate Cosmic Report',
              onTap: _fetchAiNumerology,
            ),
          ],
        ],
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
                  _nameController.text = item.name;
                  _selectedDate = DateTime.now(); // Date details are not recalculated in UI as we restore direct values
                  _lifePathNumber = item.lifePathNumber;
                  _personalYearNumber = item.personalYearNumber;
                  _aiAnalysisTr = item.aiAnalysisTr;
                  _aiAnalysisEn = item.aiAnalysisEn;
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
                      'Y.Yolu:${item.lifePathNumber}  Yıl:${item.personalYearNumber}',
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
