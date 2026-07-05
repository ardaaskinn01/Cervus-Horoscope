import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:horoscope/core/constants/app_colors.dart';
import 'package:horoscope/core/constants/app_text_styles.dart';
import 'package:horoscope/core/constants/app_strings.dart';
import 'package:horoscope/core/providers/language_provider.dart';
import 'package:horoscope/core/providers/user_provider.dart';
import 'package:horoscope/core/utils/astrology_utils.dart';
import 'package:horoscope/shared/widgets/glass_card.dart';
import 'package:horoscope/shared/widgets/star_background.dart';
import 'package:horoscope/shared/widgets/zodiac_icon.dart';
import 'package:horoscope/shared/widgets/gradient_button.dart';
import 'package:horoscope/shared/widgets/birth_place_search_sheet.dart';
import 'package:horoscope/core/utils/date_formatter.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _pageController = PageController();
  final TextEditingController _dateController = TextEditingController();
  int _currentPage = 0;

  // Form Verileri
  String _name = '';
  String? _gender; // 'male' or 'female'
  DateTime? _birthDate;
  TimeOfDay? _birthTime;
  bool _knowsBirthTime = true;
  String _birthPlace = 'İstanbul';
  String? _relationshipStatus;
  String? _relationshipDuration;

  @override
  void dispose() {
    _pageController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < 4) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    }
  }

  // Burç Hesapla
  String get _zodiacSign {
    if (_birthDate == null) return 'aries';
    return AstrologyUtils.calculateZodiacSign(_birthDate!.day, _birthDate!.month);
  }

  // Burcun Türkçe Adı
  String _getZodiacTrName(String sign) {
    switch (sign) {
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

  // Tamamlama ve Kaydetme
  Future<void> _completeOnboarding() async {
    final userNotifier = ref.read(userProvider.notifier);
    
    // Profili güncelle
    await userNotifier.updateProfile(
      name: _name,
      birthDate: _birthDate,
      birthTime: _knowsBirthTime && _birthTime != null 
          ? '${_birthTime!.hour.toString().padLeft(2, '0')}:${_birthTime!.minute.toString().padLeft(2, '0')}'
          : null,
      birthPlace: _birthPlace,
      gender: _gender,
      zodiacSign: _zodiacSign,
      relationshipStatus: _relationshipStatus,
      relationshipDuration: _relationshipDuration,
    );

    // Onboarding bitti flagini işaretle
    await ref.read(onboardingCompleteProvider.notifier).completeOnboarding();

    if (mounted) {
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StarBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: SafeArea(
            child: Column(
              children: [
                // İlerleme Çubuğu (Onboarding Steps Progress)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                  child: Row(
                    children: List.generate(5, (index) {
                      final isCompleted = index <= _currentPage;
                      return Expanded(
                        child: Container(
                          height: 4,
                          margin: const EdgeInsets.symmetric(horizontal: 4.0),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(2),
                            gradient: isCompleted ? AppColors.goldGradient : null,
                            color: isCompleted ? null : AppColors.borderLight,
                          ),
                        ),
                      );
                    }),
                  ),
                ),
                // İçerik Sayfaları
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    physics: const NeverScrollableScrollPhysics(), // Kaydırma butonlarla yapılacak
                    onPageChanged: (page) {
                      setState(() {
                        _currentPage = page;
                      });
                    },
                    children: [
                      _buildLanguageStep(),
                      _buildWelcomeStep(),
                      _buildProfileStep(),
                      _buildRelationshipStep(),
                      _buildZodiacStep(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Adım 0: Dil Seçimi
  Widget _buildLanguageStep() {
    final currentLocale = ref.watch(languageProvider);
    final isTurkish = currentLocale.languageCode == 'tr';

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            context.translate('language_select'),
            style: AppTextStyles.h1.copyWith(
              shadows: [Shadow(color: AppColors.warmAmber.withValues(alpha: 0.5), blurRadius: 10)],
            ),
          ).animate().fade().slideY(begin: -0.2),
          const SizedBox(height: 32),
          Row(
            children: [
              // Türkçe Kartı
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    ref.read(languageProvider.notifier).changeLanguage('tr');
                    HapticFeedback.mediumImpact();
                  },
                  child: GlassCard(
                    border: Border.all(
                      color: isTurkish ? AppColors.primaryGold : AppColors.borderLight,
                      width: isTurkish ? 2.0 : 1.0,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('🇹🇷', style: TextStyle(fontSize: 48)),
                        const SizedBox(height: 12),
                        Text(
                          'Türkçe',
                          style: AppTextStyles.label.copyWith(
                            color: isTurkish ? AppColors.primaryGold : AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // İngilizce Kartı
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    ref.read(languageProvider.notifier).changeLanguage('en');
                    HapticFeedback.mediumImpact();
                  },
                  child: GlassCard(
                    border: Border.all(
                      color: !isTurkish ? AppColors.primaryGold : AppColors.borderLight,
                      width: !isTurkish ? 2.0 : 1.0,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('🇬🇧', style: TextStyle(fontSize: 48)),
                        const SizedBox(height: 12),
                        Text(
                          'English',
                          style: AppTextStyles.label.copyWith(
                            color: !isTurkish ? AppColors.primaryGold : AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ).animate().fade(delay: 100.ms).slideY(begin: 0.2),
          const SizedBox(height: 64),
          GradientButton(
            text: context.translate('onboarding_next'),
            onTap: _nextPage,
          ).animate().fade(delay: 200.ms),
        ],
      ),
    );
  }

  // Adım 1: Karşılama
  Widget _buildWelcomeStep() {
    final isTurkish = ref.watch(languageProvider).languageCode == 'tr';

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            '🔮',
            style: TextStyle(fontSize: 64),
          ).animate().fade().scale(),
          const SizedBox(height: 24),
          Text(
            isTurkish ? 'Evren seni bekliyordu...' : 'The universe was waiting for you...',
            textAlign: TextAlign.center,
            style: AppTextStyles.h1.copyWith(
              shadows: [Shadow(color: AppColors.warmAmber.withValues(alpha: 0.5), blurRadius: 15)],
            ),
          ).animate().fade(delay: 100.ms).slideY(begin: 0.2),
          const SizedBox(height: 16),
          Text(
            isTurkish 
                ? 'Yıldızların ve gezegenlerin hizalanması, senin bu dünyaya getirdiğin enerjiyi keşfetmen için hazır.'
                : 'The alignment of the stars and planets is ready for you to explore the energy you brought into this world.',
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyMedium,
          ).animate().fade(delay: 200.ms),
          const SizedBox(height: 64),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.primaryGold),
                onPressed: _previousPage,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GradientButton(
                  text: context.translate('onboarding_next'),
                  onTap: _nextPage,
                ),
              ),
            ],
          ).animate().fade(delay: 300.ms),
        ],
      ),
    );
  }

  // Adım 2: Kişisel Bilgiler
  Widget _buildProfileStep() {
    final isTurkish = ref.watch(languageProvider).languageCode == 'tr';
    final bool isFormValid = _name.trim().isNotEmpty && _gender != null && _birthDate != null;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isTurkish ? 'Kendinden Bahset' : 'Tell Us About Yourself',
            style: AppTextStyles.h2,
          ).animate().fade(),
          const SizedBox(height: 16),
          
          // İsim
          Text(context.translate('onboarding_name_hint'), style: AppTextStyles.label),
          const SizedBox(height: 8),
          TextField(
            style: AppTextStyles.bodyLarge,
            decoration: InputDecoration(
              filled: true,
              fillColor: AppColors.cardSurface.withValues(alpha: 0.4),
              hintText: isTurkish ? 'Adınız...' : 'Your name...',
              hintStyle: TextStyle(color: AppColors.textSecondary.withValues(alpha: 0.5)),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.borderLight),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.borderLight),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.primaryGold, width: 1.5),
              ),
            ),
            onChanged: (val) {
              setState(() {
                _name = val;
              });
            },
          ),
          const SizedBox(height: 20),

          Text(isTurkish ? 'Cinsiyet' : 'Gender', style: AppTextStyles.label),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _gender = 'female';
                    });
                  },
                  child: GlassCard(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    border: Border.all(
                      color: _gender == 'female' ? AppColors.primaryGold : AppColors.borderLight,
                      width: _gender == 'female' ? 1.5 : 1.0,
                    ),
                    child: Center(
                      child: Text(
                        context.translate('onboarding_gender_female'),
                        style: AppTextStyles.label.copyWith(
                          color: _gender == 'female' ? AppColors.primaryGold : AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _gender = 'male';
                    });
                  },
                  child: GlassCard(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    border: Border.all(
                      color: _gender == 'male' ? AppColors.primaryGold : AppColors.borderLight,
                      width: _gender == 'male' ? 1.5 : 1.0,
                    ),
                    child: Center(
                      child: Text(
                        context.translate('onboarding_gender_male'),
                        style: AppTextStyles.label.copyWith(
                          color: _gender == 'male' ? AppColors.primaryGold : AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Doğum Tarihi
          Text(isTurkish ? 'Doğum Tarihi' : 'Birth Date', style: AppTextStyles.label),
          const SizedBox(height: 8),
          GlassCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
            child: TextField(
              controller: _dateController,
              keyboardType: TextInputType.datetime,
              inputFormatters: [
                DateTextInputFormatter(),
                LengthLimitingTextInputFormatter(10),
              ],
              style: AppTextStyles.bodyLarge,
              onChanged: (val) {
                final date = parseFormattedDate(val);
                if (date != null) {
                  setState(() {
                    _birthDate = date;
                  });
                } else {
                  setState(() {
                    _birthDate = null;
                  });
                }
              },
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: isTurkish ? 'GG.AA.YYYY' : 'DD.MM.YYYY',
                hintStyle: TextStyle(color: AppColors.textSecondary.withValues(alpha: 0.5)),
                icon: const Icon(Icons.calendar_today_rounded, color: AppColors.primaryGold, size: 20),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.arrow_drop_down, color: AppColors.primaryGold),
                  onPressed: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: _birthDate ?? DateTime(2000, 1, 1),
                      firstDate: DateTime(1900),
                      lastDate: DateTime.now(),
                      builder: (context, child) {
                        return Theme(
                          data: Theme.of(context).copyWith(
                            colorScheme: ColorScheme.dark(
                              primary: AppColors.primaryGold,
                              onPrimary: AppColors.textDark,
                              surface: AppColors.cardSurface,
                              onSurface: AppColors.textPrimary,
                            ),
                          ),
                          child: child!,
                        );
                      },
                    );
                    if (date != null) {
                      setState(() {
                        _birthDate = date;
                        _dateController.text = "${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}";
                      });
                    }
                  },
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Doğum Saati
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(isTurkish ? 'Doğum Saati' : 'Birth Time', style: AppTextStyles.label),
              Row(
                children: [
                  Text(
                    isTurkish ? 'Bilmiyorum' : "I don't know",
                    style: AppTextStyles.caption,
                  ),
                  Switch(
                    value: !_knowsBirthTime,
                    activeColor: AppColors.primaryGold,
                    onChanged: (val) {
                      setState(() {
                        _knowsBirthTime = !val;
                      });
                    },
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_knowsBirthTime)
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
                          onPrimary: AppColors.textDark,
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
                    _birthTime = time;
                  });
                }
              },
              child: GlassCard(
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _birthTime == null
                          ? (isTurkish ? 'Saat seçin...' : 'Select time...')
                          : '${_birthTime!.hour.toString().padLeft(2, '0')}:${_birthTime!.minute.toString().padLeft(2, '0')}',
                      style: AppTextStyles.bodyLarge,
                    ),
                    const Icon(Icons.access_time_rounded, color: AppColors.primaryGold),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 20),

          // Doğum Yeri
          Text(isTurkish ? 'Doğum Yeri (Şehir)' : 'Birth Place (City)', style: AppTextStyles.label),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () async {
              final selected = await BirthPlaceSearchSheet.show(context);
              if (selected != null) {
                setState(() {
                  _birthPlace = selected;
                });
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
              decoration: BoxDecoration(
                color: AppColors.cardSurface.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.borderLight),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _birthPlace,
                    style: AppTextStyles.bodyLarge,
                  ),
                  const Icon(Icons.map_rounded, color: AppColors.primaryGold),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          
          // Saat dilimi uyarı notu
          Text(
            isTurkish
                ? 'ℹ️ Doğum saatinizi yerel saatle girin. Sistem geçmişteki kış/yaz saati değişikliklerini otomatik hesaplar.'
                : 'ℹ️ Enter your birth time in local time. The system automatically handles historic DST changes.',
            style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary.withValues(alpha: 0.7)),
          ),
          const SizedBox(height: 36),

          // Devam Butonları
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.primaryGold),
                onPressed: _previousPage,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GradientButton(
                  text: context.translate('onboarding_next'),
                  onTap: isFormValid ? _nextPage : () {},
                  isLoading: false,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Adım 3: İlişki Durumu
  Widget _buildRelationshipStep() {
    final isTurkish = ref.watch(languageProvider).languageCode == 'tr';
    
    final List<Map<String, String>> statuses = [
      {'key': 'single', 'tr': 'Bekar', 'en': 'Single'},
      {'key': 'platonic', 'tr': 'Platonik', 'en': 'Platonic / Crush'},
      {'key': 'dating', 'tr': 'Flört', 'en': 'Dating'},
      {'key': 'in_relationship', 'tr': 'Sevgili', 'en': 'In Relationship'},
      {'key': 'recently_broken_up', 'tr': 'Yeni Ayrılmış', 'en': 'Recently Broken Up'},
      {'key': 'married', 'tr': 'Evli', 'en': 'Married'},
      {'key': 'recently_divorced', 'tr': 'Yeni Boşanmış', 'en': 'Recently Divorced'},
    ];

    final List<Map<String, String>> relationshipDurations = [
      {'key': '0-1', 'tr': '0-1 yıl', 'en': '0-1 year'},
      {'key': '1-3', 'tr': '1-3 yıl', 'en': '1-3 years'},
      {'key': '3+', 'tr': '3+ yıl', 'en': '3+ years'},
    ];

    final List<Map<String, String>> marriageDurations = [
      {'key': '0-3', 'tr': '0-3 yıl', 'en': '0-3 years'},
      {'key': '3-7', 'tr': '3-7 yıl', 'en': '3-7 years'},
      {'key': '7+', 'tr': '7+ yıl', 'en': '7+ years'},
    ];

    final bool isNextEnabled = _relationshipStatus != null &&
        ((_relationshipStatus != 'in_relationship' && _relationshipStatus != 'married') ||
            _relationshipDuration != null);

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isTurkish ? 'İlişki Durumun Nedir?' : 'What is Your Relationship Status?',
            style: AppTextStyles.h2,
          ).animate().fade(),
          const SizedBox(height: 8),
          Text(
            isTurkish 
                ? 'Sana özel aşk ve ilişki yorumları yapabilmemiz için ilişki durumunu seç.'
                : 'Select your status for personalized love and relationship guidance.',
            style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
          ).animate().fade(delay: 100.ms),
          const SizedBox(height: 24),
          
          ...statuses.map((status) {
            final isSelected = _relationshipStatus == status['key'];
            final showDuration = isSelected && (status['key'] == 'in_relationship' || status['key'] == 'married');
            
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _relationshipStatus = status['key'];
                        _relationshipDuration = null;
                      });
                    },
                    child: GlassCard(
                      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                      border: Border.all(
                        color: isSelected ? AppColors.primaryGold : AppColors.borderLight,
                        width: isSelected ? 1.5 : 1.0,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            isTurkish ? status['tr']! : status['en']!,
                            style: AppTextStyles.label.copyWith(
                              color: isSelected ? AppColors.primaryGold : AppColors.textPrimary,
                            ),
                          ),
                          if (isSelected)
                            const Icon(Icons.check_circle_rounded, color: AppColors.primaryGold, size: 20)
                          else
                            Icon(Icons.circle_outlined, color: AppColors.textSecondary.withValues(alpha: 0.5), size: 20),
                        ],
                      ),
                    ),
                  ),
                ),
                
                if (showDuration) ...[
                  Padding(
                    padding: const EdgeInsets.only(left: 8.0, right: 8.0, bottom: 20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isTurkish ? 'İlişki Süresi' : 'Relationship Duration',
                          style: AppTextStyles.caption.copyWith(color: AppColors.primaryGold, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: (status['key'] == 'in_relationship' ? relationshipDurations : marriageDurations).map((dur) {
                            final isDurSelected = _relationshipDuration == dur['key'];
                            return Expanded(
                              child: GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _relationshipDuration = dur['key'];
                                  });
                                },
                                child: Container(
                                  margin: const EdgeInsets.symmetric(horizontal: 4.0),
                                  padding: const EdgeInsets.symmetric(vertical: 10.0),
                                  decoration: BoxDecoration(
                                    color: isDurSelected ? AppColors.primaryGold.withValues(alpha: 0.15) : AppColors.cardSurface.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: isDurSelected ? AppColors.primaryGold : AppColors.borderLight,
                                      width: isDurSelected ? 1.2 : 0.8,
                                    ),
                                  ),
                                  child: Center(
                                    child: Text(
                                      isTurkish ? dur['tr']! : dur['en']!,
                                      style: AppTextStyles.caption.copyWith(
                                        fontWeight: isDurSelected ? FontWeight.bold : FontWeight.normal,
                                        color: isDurSelected ? AppColors.primaryGold : AppColors.textPrimary,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            );
          }),
          
          const SizedBox(height: 24),
          
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.primaryGold),
                onPressed: _previousPage,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GradientButton(
                  text: context.translate('onboarding_next'),
                  onTap: isNextEnabled ? _nextPage : () {},
                  isLoading: false,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Adım 4: Burç Gösterimi (Zodiac Reveal)
  Widget _buildZodiacStep() {
    final isTurkish = ref.watch(languageProvider).languageCode == 'tr';
    final sign = _zodiacSign;
    final signName = isTurkish ? _getZodiacTrName(sign) : sign[0].toUpperCase() + sign.substring(1);

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            isTurkish ? 'Senin Burcun:' : 'Your Sign:',
            style: AppTextStyles.h3,
          ).animate().fade(),
          const SizedBox(height: 24),
          ZodiacIcon(
            sign: sign,
            size: 130,
            showGlow: true,
          ).animate().fade(delay: 200.ms).scale(curve: Curves.elasticOut, duration: 800.ms),
          const SizedBox(height: 16),
          Text(
            signName,
            style: AppTextStyles.h1.copyWith(
              color: AppColors.primaryGold,
              fontWeight: FontWeight.bold,
              shadows: [Shadow(color: AppColors.warmAmber.withValues(alpha: 0.6), blurRadius: 15)],
            ),
          ).animate().fade(delay: 400.ms).slideY(begin: 0.1),
          const SizedBox(height: 12),
          Text(
            isTurkish
                ? 'Merhaba $_name, gökyüzü haritana göre bir $signName burcusun!'
                : 'Hello $_name, according to your sky chart you are a $signName!',
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyLarge,
          ).animate().fade(delay: 500.ms),
          const SizedBox(height: 64),
          GradientButton(
            text: isTurkish ? 'Keşfetmeye Başla 🔮' : 'Start Exploring 🔮',
            onTap: _completeOnboarding,
          ).animate().fade(delay: 700.ms),
        ],
      ),
    );
  }
}
