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
import 'package:horoscope/core/services/limit_service.dart';
import 'package:horoscope/shared/widgets/limit_dialog_helper.dart';

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

  List<_PartnerNumerologyHistoryItem> _history = [];

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
          final numerology = NumerologyModel.fromMap(doc.data());
          return _PartnerNumerologyHistoryItem(docId: doc.id, numerology: numerology);
        } catch (e) {
          debugPrint('⚠️ Error parsing partner numerology doc ${doc.id}: $e');
          return null;
        }
      }).whereType<_PartnerNumerologyHistoryItem>().toList();

      items.sort((a, b) => b.numerology.generatedAt.compareTo(a.numerology.generatedAt));

      if (mounted) {
        setState(() {
          _history = items;
        });
      }
    } catch (e) {
      debugPrint('⚠️ Partner numeroloji geçmişi okuma hatası: $e');
    }
  }

  Future<void> _deleteHistoryItem(_PartnerNumerologyHistoryItem item) async {
    final user = ref.read(userProvider);
    if (user == null) return;

    final isTr = ref.read(languageProvider).languageCode == 'tr';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: GlassCard(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  '🗑️',
                  style: TextStyle(fontSize: 40),
                ),
                const SizedBox(height: 16),
                Text(
                  isTr ? 'Geçmişi Sil' : 'Delete History',
                  style: AppTextStyles.h3.copyWith(color: AppColors.primaryGold, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  isTr
                      ? '${item.numerology.name} kişisinin numeroloji analizini silmek istediğinize emin misiniz?'
                      : 'Are you sure you want to delete the numerology analysis of ${item.numerology.name}?',
                  style: AppTextStyles.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: Text(
                          isTr ? 'İptal' : 'Cancel',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GradientButton(
                        text: isTr ? 'Sil' : 'Delete',
                        onTap: () => Navigator.pop(context, true),
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

    if (confirmed != true) return;

    try {
      final docPath = 'users/${user.uid}/partner_numerology/${item.docId}';
      await FirebaseFirestore.instance.doc(docPath).delete();

      if (mounted) {
        setState(() {
          _history.removeWhere((x) => x.docId == item.docId);
          if (_nameController.text == item.numerology.name) {
            _aiAnalysisTr = null;
            _aiAnalysisEn = null;
          }
        });
        CustomToast.show(
          context,
          isTr ? 'Analiz başarıyla silindi.' : 'Analysis deleted successfully.',
        );
      }
    } catch (e) {
      debugPrint('⚠️ Geçmiş silme hatası: $e');
      if (mounted) {
        CustomToast.show(
          context,
          isTr ? 'Silinirken bir hata oluştu.' : 'Failed to delete.',
          isError: true,
        );
      }
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

    final limitStatus = await LimitService.instance.checkLimit('partner_numerology');
    if (limitStatus == LimitStatus.locked) {
      LimitDialogHelper.showDailyLimitReachedDialog(context: context, ref: ref);
      return;
    } else if (limitStatus == LimitStatus.needAd) {
      LimitDialogHelper.showAdRequiredDialog(
        context: context,
        ref: ref,
        featureKey: 'partner_numerology',
        onAdCompleted: () {
          _executeCalculation(user.uid, name);
        },
      );
      return;
    }

    _executeCalculation(user.uid, name);
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
        await LimitService.instance.registerCalculation('partner_numerology');
      }

      if (numerology != null && mounted) {
        final formattedDate = "${_selectedDate!.year}_${_selectedDate!.month}_${_selectedDate!.day}";
        final String docKey = "${name}_$formattedDate";
        final docId = docKey.toLowerCase().trim().replaceAll(' ', '_');

        setState(() {
          _aiAnalysisTr = numerology.aiAnalysisTr;
          _aiAnalysisEn = numerology.aiAnalysisEn;
          _isLoadingAi = false;
          _history.removeWhere((item) => item.numerology.name.toLowerCase() == numerology.name.toLowerCase());
          _history.insert(0, _PartnerNumerologyHistoryItem(docId: docId, numerology: numerology));
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
          isPremium: ref.watch(userProvider)?.isAnyPremium ?? false,
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
            child: Stack(
              children: [
                Positioned.fill(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _nameController.text = item.numerology.name;
                        _selectedDate = DateTime.now();
                        _lifePathNumber = item.numerology.lifePathNumber;
                        _personalYearNumber = item.numerology.personalYearNumber;
                        _aiAnalysisTr = item.numerology.aiAnalysisTr;
                        _aiAnalysisEn = item.numerology.aiAnalysisEn;
                      });
                    },
                    child: GlassCard(
                      padding: const EdgeInsets.all(10),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(right: 16.0),
                            child: Text(
                              item.numerology.name,
                              style: AppTextStyles.bodyMedium.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppColors.primaryGold,
                                overflow: TextOverflow.ellipsis,
                              ),
                              maxLines: 1,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Y.Yolu:${item.numerology.lifePathNumber}  Yıl:${item.numerology.personalYearNumber}',
                            style: AppTextStyles.caption.copyWith(fontSize: 9, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 4,
                  right: 4,
                  child: GestureDetector(
                    onTap: () => _deleteHistoryItem(item),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.4),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close,
                        size: 10,
                        color: Colors.white70,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _PartnerNumerologyHistoryItem {
  final String docId;
  final NumerologyModel numerology;

  _PartnerNumerologyHistoryItem({
    required this.docId,
    required this.numerology,
  });
}
