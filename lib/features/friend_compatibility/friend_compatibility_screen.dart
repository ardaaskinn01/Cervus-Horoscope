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

class FriendCompatibilityScreen extends ConsumerStatefulWidget {
  const FriendCompatibilityScreen({super.key});

  @override
  ConsumerState<FriendCompatibilityScreen> createState() => _FriendCompatibilityScreenState();
}

class _FriendCompatibilityScreenState extends ConsumerState<FriendCompatibilityScreen> {
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
          .where('type', isEqualTo: 'friendship')
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
      debugPrint('⚠️ Arkadaşlık geçmişi okuma hatası: $e');
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

  // Arkadaşlık Uyumu hesapla
  Future<void> _calculateCompatibility() async {
    final user = ref.read(userProvider);
    if (user == null) return;

    final isTr = ref.read(languageProvider).languageCode == 'tr';
    if (_nameController.text.trim().isEmpty) {
      CustomToast.show(
        context,
        isTr ? 'Lütfen arkadaşınızın ismini girin!' : 'Please enter your friend\'s name!',
        isError: true,
      );
      return;
    }
    if (_selectedDate == null) {
      CustomToast.show(
        context,
        isTr ? 'Lütfen arkadaşınızın doğum tarihini seçin!' : 'Please select your friend\'s birth date!',
        isError: true,
      );
      return;
    }
    if (_knowsPartnerBirthTime && _partnerBirthTime == null) {
      CustomToast.show(
        context,
        isTr ? 'Lütfen arkadaşınızın doğum saatini seçin veya bilmiyorum seçeneğini işaretleyin!' : 'Please select your friend\'s birth time or check I don\'t know!',
        isError: true,
      );
      return;
    }
    if (_partnerBirthPlace == null || _partnerBirthPlace!.trim().isEmpty) {
      CustomToast.show(
        context,
        isTr ? 'Lütfen arkadaşınızın doğum yerini seçin!' : 'Please select your friend\'s birth place!',
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
        type: 'friendship',
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
        title: Text(isTr ? 'Arkadaşlık Uyumu Analizi' : 'Friendship Compatibility'),
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
          'friend_compatibility_banner',
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
                const Text('🤝', style: TextStyle(fontSize: 64))
                    .animate(onPlay: (controller) => controller.repeat(reverse: true))
                    .scale(begin: const Offset(1, 1), end: const Offset(1.15, 1.15), duration: 1.seconds, curve: Curves.easeInOut),
                const SizedBox(height: 12),
                Text(
                  isTr ? 'Kozmik Arkadaşlık Uyumu' : 'Cosmic Friendship Match',
                  style: AppTextStyles.h2.copyWith(color: AppColors.primaryGold, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  isTr
                      ? 'Yıldız haritalarınız arasındaki sosyal ve dostane rezonansı çözün.'
                      : 'Unravel the social and friendly resonance between your star charts.',
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
            isTr ? 'Arkadaşınızın Bilgileri' : 'Friend\'s Information',
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
                hintText: isTr ? 'Arkadaşınızın İsmi' : 'Friend\'s Name',
                hintStyle: const TextStyle(color: Colors.white38),
                icon: const Icon(Icons.people_alt_rounded, color: AppColors.primaryGold),
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
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryGold.withValues(alpha: 0.3),
                    blurRadius: 30,
                    spreadRadius: 10,
                  )
                ],
              ),
              child: const Text('🤝', style: TextStyle(fontSize: 80)),
            )
                .animate(onPlay: (controller) => controller.repeat(reverse: true))
                .scale(begin: const Offset(1, 1), end: const Offset(1.2, 1.2), duration: 800.ms, curve: Curves.easeInOut),
            const SizedBox(height: 32),
            Text(
              isTr ? 'Kozmik Rezonans Ölçülüyor...' : 'Measuring Cosmic Resonance...',
              style: AppTextStyles.h3.copyWith(color: AppColors.primaryGold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              isTr
                  ? 'Gezegenlerin arkadaşlık ve uyum rezonansı hesaplanıyor. Lütfen bekleyin.'
                  : 'Friendship and synergy resonance of planets is being calculated. Please wait.',
              style: AppTextStyles.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // Sonuç Ekranı
  Widget _buildResultView(bool isTr) {
    final res = _result!;
    final user = ref.read(userProvider);
    final userSign = user?.zodiacSign ?? 'aries';

    return SingleChildScrollView(
      padding: const EdgeInsets.only(left: 20.0, right: 20.0, top: 10.0, bottom: 80.0),
      child: Column(
        children: [
          // 1. Üst Başlık & Eşleşen İsimler
          GlassCard(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(
                  children: [
                    _getZodiacEmoji(userSign),
                    const SizedBox(height: 4),
                    Text(
                      user?.name ?? (isTr ? 'Sen' : 'You'),
                      style: AppTextStyles.label.copyWith(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      _getZodiacName(userSign, isTr),
                      style: AppTextStyles.caption.copyWith(color: AppColors.primaryGold),
                    ),
                  ],
                ),
                const Text('🌟', style: TextStyle(fontSize: 32))
                    .animate(onPlay: (controller) => controller.repeat(reverse: true))
                    .scale(begin: const Offset(1, 1), end: const Offset(1.15, 1.15), duration: 800.ms),
                Column(
                  children: [
                    _getZodiacEmoji(res.partnerZodiacSign),
                    const SizedBox(height: 4),
                    Text(
                      res.partnerName,
                      style: AppTextStyles.label.copyWith(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      _getZodiacName(res.partnerZodiacSign, isTr),
                      style: AppTextStyles.caption.copyWith(color: AppColors.primaryGold),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 2. Büyük Uyum Yüzdesi
          GlassCard(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Column(
              children: [
                Text(
                  isTr ? 'Genel Arkadaşlık Uyumu' : 'Overall Friendship Match',
                  style: AppTextStyles.caption,
                ),
                const SizedBox(height: 12),
                Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 140,
                      height: 140,
                      child: Animate().custom(
                        duration: 1500.ms,
                        curve: Curves.easeOutCubic,
                        builder: (context, value, child) => CircularProgressIndicator(
                          value: value * (res.overallScore / 100.0),
                          strokeWidth: 10,
                          backgroundColor: Colors.white10,
                          color: AppColors.primaryGold,
                        ),
                      ),
                    ),
                    Column(
                      children: [
                        Text(
                          '%${res.overallScore}',
                          style: AppTextStyles.h1.copyWith(
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryGold,
                          ),
                        ),
                        Text(
                          _getMatchLabel(res.overallScore, isTr),
                          style: AppTextStyles.caption.copyWith(fontSize: 10),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 3. Alt Başlık Skorları
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              isTr ? 'Arkadaşlık Boyutları' : 'Friendship Dimensions',
              style: AppTextStyles.h3,
            ),
          ),
          const SizedBox(height: 10),
          GlassCard(
            child: Column(
              children: [
                ScoreBar(
                  label: isTr ? 'Sadakat' : 'Loyalty',
                  value: res.scores['loyaltyScore'] ?? 70,
                  icon: Icons.verified_user_rounded,
                ),
                ScoreBar(
                  label: isTr ? 'Ortak İlgi' : 'Mutual Interests',
                  value: res.scores['mutualInterestScore'] ?? 70,
                  icon: Icons.auto_awesome_motion_rounded,
                ),
                ScoreBar(
                  label: isTr ? 'Eğlence ve Uyum' : 'Fun & Synergy',
                  value: res.scores['funScore'] ?? 70,
                  icon: Icons.sentiment_very_satisfied_rounded,
                ),
                ScoreBar(
                  label: isTr ? 'Güven' : 'Trust',
                  value: res.scores['trustScore'] ?? 70,
                  icon: Icons.shield_rounded,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // 4. Mistik AI Analizi Yorumu
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              isTr ? 'Kozmik Yorum Analizi' : 'Cosmic Commentary Analysis',
              style: AppTextStyles.h3,
            ),
          ),
          const SizedBox(height: 10),
          GlassCard(
            child: Text(
              isTr ? res.commentTr : res.commentEn,
              style: AppTextStyles.bodyMedium.copyWith(height: 1.6),
            ),
          ),
          const SizedBox(height: 32),

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
    if (score >= 90) return isTr ? 'Ruh İkizi Dostlar' : 'Soulmate Friends';
    if (score >= 75) return isTr ? 'Sıkı Dostlar' : 'Close Friends';
    if (score >= 60) return isTr ? 'İyi Arkadaşlar' : 'Good Friends';
    if (score >= 45) return isTr ? 'Kafa Dengi' : 'Likeminded';
    return isTr ? 'Farklı Dünyalar' : 'Different Worlds';
  }
}
