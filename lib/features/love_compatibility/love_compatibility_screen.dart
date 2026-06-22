import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:horoscope/core/constants/app_colors.dart';
import 'package:horoscope/core/constants/app_text_styles.dart';
import 'package:horoscope/core/models/compatibility_model.dart';
import 'package:horoscope/core/providers/user_provider.dart';
import 'package:horoscope/core/providers/language_provider.dart';
import 'package:horoscope/core/services/ai_service.dart';
import 'package:horoscope/core/utils/astrology_utils.dart';
import 'package:horoscope/shared/widgets/glass_card.dart';
import 'package:horoscope/shared/widgets/gradient_button.dart';
import 'package:horoscope/shared/widgets/score_bar.dart';
import 'package:horoscope/shared/widgets/star_background.dart';
import 'package:horoscope/shared/widgets/custom_toast.dart';
import 'package:horoscope/shared/widgets/birth_place_search_sheet.dart';
import 'package:horoscope/core/services/ad_service.dart';
import 'package:horoscope/core/utils/firestore_extension.dart';
import 'package:horoscope/shared/widgets/premium_dialog_helper.dart';

class LoveCompatibilityScreen extends ConsumerStatefulWidget {
  const LoveCompatibilityScreen({super.key});

  @override
  ConsumerState<LoveCompatibilityScreen> createState() => _LoveCompatibilityScreenState();
}

class _LoveCompatibilityScreenState extends ConsumerState<LoveCompatibilityScreen> {
  final _nameController = TextEditingController();
  DateTime? _selectedDate;
  TimeOfDay? _partnerBirthTime;
  bool _knowsPartnerBirthTime = true;
  String? _partnerBirthPlace;
  String _selectedGender = 'female'; // 'male' or 'female'
  bool _isLoading = false;
  CompatibilityModel? _result;
  List<CompatibilityModel> _history = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadHistory();
    });
  }

  Future<void> _loadHistory() async {
    final user = ref.read(userProvider);
    if (user == null) return;

    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('users/${user.uid}/compatibility')
          .where('type', isEqualTo: 'love')
          .safeGet();

      final items = querySnapshot.docs.map((doc) {
        try {
          return CompatibilityModel.fromMap(doc.data());
        } catch (e) {
          debugPrint('⚠️ Error parsing compatibility doc ${doc.id}: $e');
          return null;
        }
      }).whereType<CompatibilityModel>().toList();

      items.sort((a, b) => b.generatedAt.compareTo(a.generatedAt));

      if (mounted) {
        setState(() {
          _history = items;
        });
      }
    } catch (e) {
      debugPrint('⚠️ Aşk geçmişi okuma hatası: $e');
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
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

  // Uyumluluk hesapla
  Future<void> _calculateCompatibility() async {
    final user = ref.read(userProvider);
    if (user == null) return;

    final isTr = ref.read(languageProvider).languageCode == 'tr';
    if (_nameController.text.trim().isEmpty) {
      CustomToast.show(
        context,
        isTr ? 'Lütfen partnerinizin ismini girin!' : 'Please enter your partner\'s name!',
        isError: true,
      );
      return;
    }
    if (_selectedDate == null) {
      CustomToast.show(
        context,
        isTr ? 'Lütfen partnerinizin doğum tarihini seçin!' : 'Please select your partner\'s birth date!',
        isError: true,
      );
      return;
    }
    if (_knowsPartnerBirthTime && _partnerBirthTime == null) {
      CustomToast.show(
        context,
        isTr ? 'Lütfen partnerinizin doğum saatini seçin veya bilmiyorum seçeneğini işaretleyin!' : 'Please select your partner\'s birth time or check I don\'t know!',
        isError: true,
      );
      return;
    }
    if (_partnerBirthPlace == null || _partnerBirthPlace!.trim().isEmpty) {
      CustomToast.show(
        context,
        isTr ? 'Lütfen partnerinizin doğum yerini seçin!' : 'Please select your partner\'s birth place!',
        isError: true,
      );
      return;
    }

    try {
      final limitInfo = await AiService().checkAiToolsDailyLimit(user.uid);
      if (limitInfo['allowed'] == false) {
        _showAiToolsLimitDialog(isTr, user.uid, () {
          _executeCalculation(user.uid);
        });
        return;
      }
      _executeCalculation(user.uid);
    } catch (e) {
      debugPrint('⚠️ Limit check error: $e');
      _executeCalculation(user.uid);
    }
  }

  Future<void> _executeCalculation(String userId) async {
    final user = ref.read(userProvider);
    if (user == null) return;
    final isTr = ref.read(languageProvider).languageCode == 'tr';

    setState(() {
      _isLoading = true;
    });

    final partnerZodiac = AstrologyUtils.calculateZodiacSign(_selectedDate!.day, _selectedDate!.month);

    try {
      final userNatalChart = await AiService().calculateAndSaveNatalChart(
        userId: user.uid,
        name: user.name ?? 'Gezgin',
        birthDate: user.birthDate ?? DateTime(2000, 1, 1),
        birthTime: user.birthTime ?? '12:00',
        birthPlace: user.birthPlace ?? 'İstanbul',
        gender: user.gender,
      );

      final partnerBirthTimeStr = _knowsPartnerBirthTime && _partnerBirthTime != null
          ? '${_partnerBirthTime!.hour.toString().padLeft(2, '0')}:${_partnerBirthTime!.minute.toString().padLeft(2, '0')}'
          : 'Bilinmiyor';

      final compatibility = await AiService().generateCompatibility(
        userId: user.uid,
        user: user,
        userNatalChart: userNatalChart,
        partnerName: _nameController.text.trim(),
        partnerBirthDate: _selectedDate!,
        partnerBirthTime: partnerBirthTimeStr,
        partnerBirthPlace: _partnerBirthPlace,
        partnerGender: _selectedGender,
        partnerZodiacSign: partnerZodiac,
        type: 'love',
      );

      if (compatibility != null) {
        await AiService().incrementAiToolsCalculationCount(userId);
      }

      if (mounted) {
        setState(() {
          _result = compatibility;
          _isLoading = false;
          if (compatibility != null) {
            _history.removeWhere((item) => item.partnerName.toLowerCase() == compatibility.partnerName.toLowerCase());
            _history.insert(0, compatibility);
          } else {
            CustomToast.show(
              context,
              isTr ? 'Gök kubbe ile bağlantı kurulamadı. Lütfen internetinizi kontrol edip tekrar deneyin.' : 'Could not connect to the sky. Please check your internet and try again.',
              isError: true,
            );
          }
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
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
    final user = ref.watch(userProvider);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(isTr ? 'Aşk Uyumu Analizi' : 'Love Compatibility'),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: StarBackground(
        child: SafeArea(
          child: _isLoading
              ? _buildLoadingView(isTr)
              : _result != null
                  ? _buildResultView(isTr)
                  : _buildFormView(isTr, user?.name ?? (isTr ? 'Sen' : 'You'), user?.zodiacSign ?? 'aries'),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: AdService.instance.getBannerAdWidget(
          'love_compatibility_banner',
          isPremium: user?.isPremium ?? false,
        ),
      ),
    );
  }

  // Form Ekranı
  Widget _buildFormView(bool isTr, String userName, String userSign) {
    final dateStr = _selectedDate == null
        ? (isTr ? 'Tarih Seç' : 'Select Date')
        : DateFormat('dd.MM.yyyy').format(_selectedDate!);

    return SingleChildScrollView(
      padding: const EdgeInsets.only(left: 24.0, right: 24.0, top: 24.0, bottom: 80.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Giriş Görsel & Tanıtım
          Center(
            child: Column(
              children: [
                const Text('❤️', style: TextStyle(fontSize: 64))
                    .animate(onPlay: (controller) => controller.repeat(reverse: true))
                    .scale(begin: const Offset(1, 1), end: const Offset(1.15, 1.15), duration: 1.seconds, curve: Curves.easeInOut),
                const SizedBox(height: 12),
                Text(
                  isTr ? 'Kozmik Aşk Uyumu' : 'Cosmic Love Synastry',
                  style: AppTextStyles.h2.copyWith(color: AppColors.primaryGold, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  isTr
                      ? 'Yıldızların konumuna göre aşkınızın potansiyelini keşfedin.'
                      : 'Discover the potential of your love according to the alignment of the stars.',
                  style: AppTextStyles.bodyMedium,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // Kullanıcı Kartı (Önizleme)
          GlassCard(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.person, color: AppColors.primaryGold, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(isTr ? 'Birinci Kişi (Sen)' : 'First Person (You)', style: AppTextStyles.caption),
                      Text(
                        '$userName (${_getZodiacName(userSign, isTr)})',
                        style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.bold, color: AppColors.primaryGold),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Form Başlığı
          Text(
            isTr ? 'Partnerinizin Bilgileri' : 'Partner\'s Information',
            style: AppTextStyles.h4.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),

          // İsim Alanı
          GlassCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: TextField(
              controller: _nameController,
              style: TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: isTr ? 'Partnerin İsmi' : 'Partner\'s Name',
                hintStyle: const TextStyle(color: Colors.white38),
                icon: const Icon(Icons.favorite_border_rounded, color: AppColors.primaryGold),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Doğum Tarihi
          GestureDetector(
            onTap: () => _selectDate(context),
            child: GlassCard(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Row(
                children: [
                  const Icon(Icons.calendar_month_rounded, color: AppColors.primaryGold),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      dateStr,
                      style: AppTextStyles.bodyLarge.copyWith(
                        color: _selectedDate == null ? Colors.white38 : AppColors.textPrimary,
                      ),
                    ),
                  ),
                  const Icon(Icons.arrow_drop_down, color: AppColors.primaryGold),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Doğum Saati Başlığı ve Bilmiyorum Switch'i
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isTr ? 'Doğum Saati' : 'Birth Time',
                style: AppTextStyles.label.copyWith(color: AppColors.textSecondary),
              ),
              Row(
                children: [
                  Text(
                    isTr ? 'Bilmiyorum' : "I don't know",
                    style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                  ),
                  Switch(
                    value: !_knowsPartnerBirthTime,
                    activeColor: AppColors.primaryGold,
                    onChanged: (val) {
                      setState(() {
                        _knowsPartnerBirthTime = !val;
                      });
                    },
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_knowsPartnerBirthTime) ...[
            GestureDetector(
              onTap: () async {
                final time = await showTimePicker(
                  context: context,
                  initialTime: const TimeOfDay(hour: 12, minute: 0),
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
                if (time != null) {
                  setState(() {
                    _partnerBirthTime = time;
                  });
                }
              },
              child: GlassCard(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                child: Row(
                  children: [
                    const Icon(Icons.access_time_rounded, color: AppColors.primaryGold),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        _partnerBirthTime == null
                            ? (isTr ? 'Saat seçin...' : 'Select time...')
                            : '${_partnerBirthTime!.hour.toString().padLeft(2, '0')}:${_partnerBirthTime!.minute.toString().padLeft(2, '0')}',
                        style: AppTextStyles.bodyLarge.copyWith(
                          color: _partnerBirthTime == null ? Colors.white38 : AppColors.textPrimary,
                        ),
                      ),
                    ),
                    const Icon(Icons.arrow_drop_down, color: AppColors.primaryGold),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Doğum Yeri
          Text(
            isTr ? 'Doğum Yeri (Şehir)' : 'Birth Place (City)',
            style: AppTextStyles.label.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () async {
              final selected = await BirthPlaceSearchSheet.show(context);
              if (selected != null) {
                setState(() {
                  _partnerBirthPlace = selected;
                });
              }
            },
            child: GlassCard(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Row(
                children: [
                  const Icon(Icons.location_on_rounded, color: AppColors.primaryGold),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      _partnerBirthPlace ?? (isTr ? 'Şehir seçin...' : 'Select city...'),
                      style: AppTextStyles.bodyLarge.copyWith(
                        color: _partnerBirthPlace == null ? Colors.white38 : AppColors.textPrimary,
                      ),
                    ),
                  ),
                  const Icon(Icons.arrow_drop_down, color: AppColors.primaryGold),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Cinsiyet Başlığı
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isTr ? 'Cinsiyet' : 'Gender',
                style: AppTextStyles.label.copyWith(color: AppColors.textSecondary),
              ),
              Row(
                children: [
                  const Text('🏳️‍🌈', style: TextStyle(fontSize: 12)),
                  const SizedBox(width: 4),
                  Text(
                    isTr ? 'LGBTQ+ Dostu' : 'LGBTQ+ Friendly',
                    style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary, fontSize: 10),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Cinsiyet Toggle
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() { _selectedGender = 'female'; });
                    HapticFeedback.selectionClick();
                  },
                  child: GlassCard(
                    color: _selectedGender == 'female'
                        ? AppColors.warmAmber.withValues(alpha: 0.2)
                        : AppColors.cardSurface,
                    border: _selectedGender == 'female'
                        ? Border.all(color: AppColors.primaryGold, width: 1.5)
                        : Border.all(color: Colors.white10),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Column(
                      children: [
                        const Text('👩', style: TextStyle(fontSize: 24)),
                        const SizedBox(height: 4),
                        Text(
                          isTr ? 'Kadın' : 'Female',
                          style: AppTextStyles.label.copyWith(
                            color: _selectedGender == 'female' ? AppColors.primaryGold : AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() { _selectedGender = 'male'; });
                    HapticFeedback.selectionClick();
                  },
                  child: GlassCard(
                    color: _selectedGender == 'male'
                        ? AppColors.warmAmber.withValues(alpha: 0.2)
                        : AppColors.cardSurface,
                    border: _selectedGender == 'male'
                        ? Border.all(color: AppColors.primaryGold, width: 1.5)
                        : Border.all(color: Colors.white10),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Column(
                      children: [
                        const Text('👨', style: TextStyle(fontSize: 24)),
                        const SizedBox(height: 4),
                        Text(
                          isTr ? 'Erkek' : 'Male',
                          style: AppTextStyles.label.copyWith(
                            color: _selectedGender == 'male' ? AppColors.primaryGold : AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),

          // Hesapla Butonu
          GradientButton(
            text: isTr ? 'Uyum Analizini Başlat 🔮' : 'Start Compatibility Analysis 🔮',
            onTap: _calculateCompatibility,
          ),

          // Kozmik Geçmiş
          if (_history.isNotEmpty) ...[
            const SizedBox(height: 32),
            Text(
              isTr ? 'Kozmik Geçmişiniz 🔮' : 'Cosmic History 🔮',
              style: AppTextStyles.h4.copyWith(color: AppColors.primaryGold, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 120,
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
                          _result = item;
                        });
                      },
                      child: GlassCard(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _getZodiacEmoji(item.partnerZodiacSign, fontSize: 24),
                                Text(
                                  '%${item.overallScore}',
                                  style: AppTextStyles.label.copyWith(
                                    color: AppColors.primaryGold,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                            const Spacer(),
                            Text(
                              item.partnerName,
                              style: AppTextStyles.bodyMedium.copyWith(
                                fontWeight: FontWeight.bold,
                                overflow: TextOverflow.ellipsis,
                              ),
                              maxLines: 1,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${_getZodiacName(item.partnerZodiacSign, isTr)} ${item.partnerGender == 'female' ? '👩' : '👨'}',
                              style: AppTextStyles.caption.copyWith(fontSize: 9, color: AppColors.textSecondary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    ).animate().fade(duration: 400.ms);
  }

  // Yükleme Ekranı
  Widget _buildLoadingView(bool isTr) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Parlayan atan kalp lottiesiz Custom
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.redAccent.withValues(alpha: 0.3),
                    blurRadius: 30,
                    spreadRadius: 10,
                  )
                ],
              ),
              child: const Text('💖', style: TextStyle(fontSize: 80)),
            )
                .animate(onPlay: (controller) => controller.repeat(reverse: true))
                .scale(begin: const Offset(1, 1), end: const Offset(1.2, 1.2), duration: 800.ms, curve: Curves.easeInOut),
            const SizedBox(height: 32),
            Text(
              isTr ? 'Gökyüzü Haritaları Karşılaştırılıyor...' : 'Comparing Sky Charts...',
              style: AppTextStyles.h3.copyWith(color: AppColors.primaryGold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              isTr
                  ? 'Gezegenlerin çekim kuvvetleri ve sinastri açıları hesaplanıyor. Lütfen bekleyin.'
                  : 'Calculating planetary gravity forces and synastry angles. Please wait.',
              style: AppTextStyles.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // Sonuç Ekranı — Sinastri Tabanlı Gelişmiş Görünüm
  Widget _buildResultView(bool isTr) {
    final res = _result!;
    final user = ref.watch(userProvider)!;
    final userSign = user.zodiacSign ?? 'aries';
    final showPremiumContent = true;

    // Açı ikonları
    Widget aspectBadge(String aspect, bool isHard) {
      final color = isHard ? Colors.redAccent : Colors.lightBlueAccent;
      final emoji = isHard ? '⚡' : '✨';
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.5)),
        ),
        child: Text(
          '$emoji ${aspect.split('(').first.trim()}',
          style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.only(left: 20.0, right: 20.0, top: 10.0, bottom: 80.0),
      child: Column(
        children: [

          // ── 1. Çift Harita Özet Kartı ─────────────────────────────────
          GlassCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Text(
                  isTr ? 'Kozmik Sinastri Analizi' : 'Cosmic Synastry Analysis',
                  style: AppTextStyles.caption.copyWith(color: AppColors.primaryGold, letterSpacing: 1.5),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    // Kişi 1 (Kullanıcı)
                    Expanded(
                      child: Column(
                        children: [
                          _getZodiacEmoji(userSign, fontSize: 36),
                          const SizedBox(height: 6),
                          Text(
                            user.name ?? (isTr ? 'Sen' : 'You'),
                            style: AppTextStyles.label.copyWith(fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 8),
                          _buildMiniSignRow('☀️', _getZodiacName(userSign, isTr)),
                          if (res.userPlanetPositions != null) ...[
                            _buildMiniSignRow('🌙', _getPlanetSignFromPositions(res.userPlanetPositions!, 'Ay', isTr)),
                            _buildMiniSignRow('🌅', _getPlanetSignFromPositions(res.userPlanetPositions!, 'Yükselen', isTr)),
                          ],
                        ],
                      ),
                    ),
                    // Merkez — Uyum yüzdesi
                    Column(
                      children: [
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            SizedBox(
                              width: 90,
                              height: 90,
                              child: Animate().custom(
                                duration: 1500.ms,
                                curve: Curves.easeOutCubic,
                                builder: (ctx, val, _) => CircularProgressIndicator(
                                  value: val * (res.overallScore / 100.0),
                                  strokeWidth: 7,
                                  backgroundColor: Colors.white10,
                                  color: AppColors.primaryGold,
                                ),
                              ),
                            ),
                            Column(
                              children: [
                                Text(
                                  '${res.overallScore}%',
                                  style: AppTextStyles.h3.copyWith(
                                    color: AppColors.primaryGold,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  '💘',
                                  style: const TextStyle(fontSize: 14),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _getMatchLabel(res.overallScore, isTr),
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.primaryGold,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                    // Kişi 2 (Partner)
                    Expanded(
                      child: Column(
                        children: [
                          _getZodiacEmoji(res.partnerZodiacSign, fontSize: 36),
                          const SizedBox(height: 6),
                          Text(
                            res.partnerName,
                            style: AppTextStyles.label.copyWith(fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 8),
                          _buildMiniSignRow('☀️', _getZodiacName(res.partnerZodiacSign, isTr)),
                          if (res.partnerPlanetPositions != null) ...[
                            _buildMiniSignRow('🌙', _getPlanetSignFromPositions(res.partnerPlanetPositions!, 'Ay', isTr)),
                            _buildMiniSignRow('🌅', _getPlanetSignFromPositions(res.partnerPlanetPositions!, 'Yükselen', isTr)),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ).animate().fade(duration: 400.ms).slideY(begin: 0.1),
          const SizedBox(height: 20),

          // ── 2. Sinastri Açıları Tablosu ──────────────────────────────
          if (res.synastrAspects != null && res.synastrAspects!.isNotEmpty) ...[
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                isTr ? '🔭 Sinastri Açıları' : '🔭 Synastry Aspects',
                style: AppTextStyles.h3,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              isTr
                  ? '${user.name ?? "Sen"} ve ${res.partnerName} arasındaki gezegen açıları'
                  : 'Planetary angles between ${user.name ?? "You"} and ${res.partnerName}',
              style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 10),
            GlassCard(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: res.synastrAspects!.asMap().entries.map((entry) {
                  final i = entry.key;
                  final aspect = entry.value;
                  final isHard = (aspect['isHard'] as bool?) == true;
                  return Column(
                    children: [
                      if (i > 0) const Divider(height: 12, color: Colors.white12),
                      Row(
                        children: [
                          Text(
                            '${aspect['planet1']}',
                            style: AppTextStyles.bodySmall.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppColors.primaryGold,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(Icons.swap_horiz_rounded, size: 14, color: Colors.white38),
                          const SizedBox(width: 4),
                          Text(
                            '${aspect['planet2']}',
                            style: AppTextStyles.bodySmall.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppColors.primaryGold,
                            ),
                          ),
                          const Spacer(),
                          aspectBadge(aspect['aspect'] as String, isHard),
                          const SizedBox(width: 8),
                          Text(
                            '${(aspect['orb'] as double).toStringAsFixed(1)}°',
                            style: AppTextStyles.caption.copyWith(color: Colors.white38, fontSize: 9),
                          ),
                        ],
                      ),
                    ],
                  );
                }).toList(),
              ),
            ).animate().fade(duration: 500.ms, delay: 100.ms),
            const SizedBox(height: 24),
          ],

          // ── 3. Sinastri Spotlight'ları (Gemini Yorumları) ─────────────
          if (res.synastriHighlights != null && res.synastriHighlights!.isNotEmpty) ...[
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                isTr ? '✨ Kozmik Bağlantı Noktaları' : '✨ Cosmic Connection Points',
                style: AppTextStyles.h3,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              isTr ? 'En güçlü sinastri etkileşimleri' : 'Most powerful synastry interactions',
              style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 10),
            ...res.synastriHighlights!.asMap().entries.map((entry) {
              final i = entry.key;
              final h = entry.value;
              final isHard = h['isHard'] == true;
              final accentColor = isHard ? Colors.redAccent : AppColors.primaryGold;
              final interpretation = isTr
                  ? (h['interpretationTr'] ?? '')
                  : (h['interpretationEn'] ?? '');

              return GlassCard(
                padding: const EdgeInsets.all(14),
                border: Border.all(
                  color: accentColor.withValues(alpha: 0.35),
                  width: 1.0,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: accentColor.withValues(alpha: 0.15),
                      ),
                      child: Center(
                        child: Text(
                          isHard ? '⚡' : '✨',
                          style: const TextStyle(fontSize: 18),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                '${h['planet1'] ?? ''} — ${h['planet2'] ?? ''}',
                                style: AppTextStyles.label.copyWith(
                                  color: accentColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: accentColor.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  (h['aspect'] as String? ?? '').split('(').first.trim(),
                                  style: TextStyle(
                                    color: accentColor,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            interpretation,
                            style: AppTextStyles.bodySmall.copyWith(
                              height: 1.5,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ).animate().fade(duration: 400.ms, delay: Duration(milliseconds: 150 + i * 80));
            }),
            const SizedBox(height: 24),
          ],

          // ── 4. Aşk Boyutları Skor Barları ────────────────────────────
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              isTr ? '📊 Aşk Boyutları' : '📊 Love Dimensions',
              style: AppTextStyles.h3,
            ),
          ),
          const SizedBox(height: 10),
          GlassCard(
            child: Column(
              children: [
                ScoreBar(
                  label: isTr ? 'Aşk Potansiyeli' : 'Love Potential',
                  value: res.scores['loveScore'] ?? 70,
                  icon: Icons.favorite_rounded,
                ),
                ScoreBar(
                  label: isTr ? 'Cinsellik ve Çekim' : 'Sexuality & Chemistry',
                  value: res.scores['sexualityScore'] ?? 70,
                  icon: Icons.flash_on_rounded,
                ),
                ScoreBar(
                  label: isTr ? 'İletişim Uyumu' : 'Communication Match',
                  value: res.scores['communicationScore'] ?? 70,
                  icon: Icons.chat_bubble_rounded,
                ),
                ScoreBar(
                  label: isTr ? 'Uzun Vade & Evlilik' : 'Long-Term & Marriage',
                  value: res.scores['longTermScore'] ?? 70,
                  icon: Icons.favorite_border_rounded,
                ),
              ],
            ),
          ).animate().fade(duration: 500.ms, delay: 200.ms),
          const SizedBox(height: 24),

          // ── 5. Kozmik Genel Yorum ─────────────────────────────────────
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              isTr ? '🔮 Kozmik Yorum' : '🔮 Cosmic Commentary',
              style: AppTextStyles.h3,
            ),
          ),
          const SizedBox(height: 10),
          GlassCard(
            child: Text(
              isTr ? res.commentTr : res.commentEn,
              style: AppTextStyles.bodyMedium.copyWith(height: 1.65),
            ),
          ).animate().fade(duration: 500.ms, delay: 250.ms),
          const SizedBox(height: 24),

          // ignore: dead_code
          if (!showPremiumContent) ...[
            GestureDetector(
              onTap: () => PremiumDialogHelper.show(context, ref),
              child: GlassCard(
                border: Border.all(color: AppColors.primaryGold.withValues(alpha: 0.4), width: 1.5),
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.lock_outline_rounded, color: AppColors.primaryGold, size: 24)
                            .animate(onPlay: (controller) => controller.repeat(reverse: true))
                            .shake(hz: 2, curve: Curves.easeInOut, duration: 2.seconds),
                        const SizedBox(width: 8),
                        Text(
                          isTr ? 'Derin Sinastri Analizi (PRO)' : 'Deep Synastry Analysis (PRO)',
                          style: AppTextStyles.h3.copyWith(color: AppColors.primaryGold, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      isTr
                          ? 'İlişkinizin gizli kodlarını ve kozmik bağlarını keşfetmek için premium özellikleri açın:'
                          : 'Unlock premium features to discover the hidden codes and cosmic bonds of your relationship:',
                      style: AppTextStyles.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    _buildTeaserFeatureRow(Icons.psychology_outlined, isTr ? '🔮 Ruh Eşi & Karmik Bağlar' : '🔮 Soul Connection & Karmic Bonds', isTr ? 'Geçmiş yaşam karması ve ruhsal çekim dereceniz' : 'Past life karma and level of spiritual attraction'),
                    _buildTeaserFeatureRow(Icons.gavel_outlined, isTr ? '🛡️ İletişim & Çatışma Çözümü' : '🛡️ Communication & Conflict Resolution', isTr ? 'Zor açılara karşı usta astrolog tavsiyeleri' : 'Master astrolog advice against hard aspects'),
                    _buildTeaserFeatureRow(Icons.timeline_outlined, isTr ? '⏳ Gelecek Kozmik Zaman Tüneli' : '⏳ Future Cosmic Timeline', isTr ? 'Gelecek 1 yıldaki ilişki dönüm noktaları' : 'Relationship milestones in the next 1 year'),
                    const SizedBox(height: 20),
                    Container(
                      width: double.infinity,
                      height: 50,
                      decoration: BoxDecoration(
                        gradient: AppColors.goldGradient,
                        borderRadius: BorderRadius.circular(25),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primaryGold.withValues(alpha: 0.3),
                            blurRadius: 12,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          isTr ? 'Horoscope Pro ile Şimdi Keşfet ✨' : 'Discover Now with Horoscope Pro ✨',
                          style: AppTextStyles.bodyLarge.copyWith(color: AppColors.textDark, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ).animate(onPlay: (controller) => controller.repeat(reverse: true))
                     .shimmer(duration: 2.seconds, color: Colors.white54),
                  ],
                ),
              ).animate().fade(duration: 500.ms, delay: 300.ms),
            ),
            const SizedBox(height: 32),
          ] else ...[
            // ── Pro 1. Ruh Eşi ve Karmik Bağlar ─────────────────────────────
            if (isTr ? (res.karmicBondsTr?.isNotEmpty ?? false) : (res.karmicBondsEn?.isNotEmpty ?? false)) ...[
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  isTr ? '🔮 Ruh Eşi & Karmik Bağlar' : '🔮 Soul Connection & Karmic Bonds',
                  style: AppTextStyles.h3.copyWith(color: AppColors.primaryGold),
                ),
              ),
              const SizedBox(height: 10),
              GlassCard(
                border: Border.all(color: AppColors.primaryGold.withValues(alpha: 0.35), width: 1),
                child: Text(
                  isTr ? res.karmicBondsTr! : res.karmicBondsEn!,
                  style: AppTextStyles.bodyMedium.copyWith(height: 1.65),
                ),
              ).animate().fade(duration: 500.ms, delay: 300.ms),
              const SizedBox(height: 24),
            ],

            // ── Pro 2. Çatışma Çözüm Rehberi ──────────────────────────────
            if (isTr ? (res.conflictResolutionTr?.isNotEmpty ?? false) : (res.conflictResolutionEn?.isNotEmpty ?? false)) ...[
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  isTr ? '🛡️ İletişim & Çatışma Çözümü' : '🛡️ Communication & Conflict Resolution',
                  style: AppTextStyles.h3.copyWith(color: AppColors.primaryGold),
                ),
              ),
              const SizedBox(height: 10),
              GlassCard(
                border: Border.all(color: AppColors.primaryGold.withValues(alpha: 0.35), width: 1),
                child: Text(
                  isTr ? res.conflictResolutionTr! : res.conflictResolutionEn!,
                  style: AppTextStyles.bodyMedium.copyWith(height: 1.65),
                ),
              ).animate().fade(duration: 500.ms, delay: 350.ms),
              const SizedBox(height: 24),
            ],

            // ── Pro 3. Gelecek Kozmik Zaman Tüneli ─────────────────────────
            if (isTr ? (res.growthTimelineTr?.isNotEmpty ?? false) : (res.growthTimelineEn?.isNotEmpty ?? false)) ...[
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  isTr ? '⏳ Gelecek Kozmik Zaman Tüneli' : '⏳ Future Cosmic Timeline',
                  style: AppTextStyles.h3.copyWith(color: AppColors.primaryGold),
                ),
              ),
              const SizedBox(height: 10),
              GlassCard(
                border: Border.all(color: AppColors.primaryGold.withValues(alpha: 0.35), width: 1),
                child: Text(
                  isTr ? res.growthTimelineTr! : res.growthTimelineEn!,
                  style: AppTextStyles.bodyMedium.copyWith(height: 1.65),
                ),
              ).animate().fade(duration: 500.ms, delay: 400.ms),
              const SizedBox(height: 32),
            ],
          ],

          // Tekrar Dene Butonu
          GradientButton(
            text: isTr ? 'Başka Bir Uyum Hesapla 🔄' : 'Check Another Match 🔄',
            onTap: () {
              setState(() {
                _result = null;
                _nameController.clear();
                _selectedDate = null;
                _partnerBirthTime = null;
                _knowsPartnerBirthTime = true;
                _partnerBirthPlace = null;
              });
            },
          ),
        ],
      ),
    ).animate().fade(duration: 400.ms);
  }

  Widget _buildTeaserFeatureRow(IconData icon, String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.primaryGold.withValues(alpha: 0.8), size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                ),
                Text(
                  subtitle,
                  style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }


  // Mini burç satırı (Çift Harita Kartı için)
  Widget _buildMiniSignRow(String emoji, String signName) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 11)),
          const SizedBox(width: 4),
          Text(
            signName,
            style: AppTextStyles.caption.copyWith(fontSize: 10, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  // Gezegen konumlarından burç ismini çıkar (örn. "Akrep Burcu, 3. Ev" → "Akrep")
  String _getPlanetSignFromPositions(Map<String, dynamic> positions, String planet, bool isTr) {
    final raw = positions[planet]?.toString() ?? '';
    if (raw.isEmpty) return '—';
    // Format: "Akrep Burcu, 3. Ev" veya "Koç Burcu, 1. Ev"
    final parts = raw.split(' Burcu');
    if (parts.isNotEmpty) return parts[0].trim();
    return raw;
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

  Widget _getZodiacEmoji(String key, {double fontSize = 40}) {
    switch (key.toLowerCase()) {
      case 'aries': return Text('♈', style: TextStyle(fontSize: fontSize));
      case 'taurus': return Text('♉', style: TextStyle(fontSize: fontSize));
      case 'gemini': return Text('♊', style: TextStyle(fontSize: fontSize));
      case 'cancer': return Text('♋', style: TextStyle(fontSize: fontSize));
      case 'leo': return Text('♌', style: TextStyle(fontSize: fontSize));
      case 'virgo': return Text('♍', style: TextStyle(fontSize: fontSize));
      case 'libra': return Text('♎', style: TextStyle(fontSize: fontSize));
      case 'scorpio': return Text('♏', style: TextStyle(fontSize: fontSize));
      case 'sagittarius': return Text('♐', style: TextStyle(fontSize: fontSize));
      case 'capricorn': return Text('♑', style: TextStyle(fontSize: fontSize));
      case 'aquarius': return Text('♒', style: TextStyle(fontSize: fontSize));
      case 'pisces': return Text('♓', style: TextStyle(fontSize: fontSize));
      default: return Text('🔮', style: TextStyle(fontSize: fontSize));
    }
  }

  String _getMatchLabel(int score, bool isTr) {
    if (score >= 90) return isTr ? 'Mükemmel Uyum' : 'Perfect Match';
    if (score >= 75) return isTr ? 'Yüksek Uyum' : 'High Match';
    if (score >= 60) return isTr ? 'Ortalama Uyum' : 'Average Match';
    if (score >= 45) return isTr ? 'Hassas Dengeler' : 'Delicate Balance';
    return isTr ? 'Kozmik Zıtlıklar' : 'Cosmic Opposites';
  }
}
