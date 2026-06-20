import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:horoscope/core/constants/app_colors.dart';
import 'package:horoscope/core/constants/app_text_styles.dart';
import 'package:horoscope/core/providers/user_provider.dart';
import 'package:horoscope/core/providers/language_provider.dart';
import 'package:horoscope/core/providers/theme_provider.dart';
import 'package:horoscope/core/providers/navigation_provider.dart';
import 'package:horoscope/core/services/notification_service.dart';
import 'package:horoscope/core/utils/astrology_utils.dart';
import 'package:horoscope/shared/widgets/glass_card.dart';
import 'package:horoscope/shared/widgets/gradient_button.dart';
import 'package:horoscope/shared/widgets/custom_toast.dart';
import 'package:horoscope/shared/widgets/birth_place_search_sheet.dart';
import 'package:horoscope/shared/widgets/premium_dialog_helper.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  // Profil Alanları
  final _nameController = TextEditingController();
  final _birthPlaceController = TextEditingController();
  DateTime? _birthDate;
  String? _birthTime;
  String? _gender;
  
  bool _isProfileEditing = false;
  bool _isSavingProfile = false;

  // Bildirim Alanları
  bool _dailyNotificationEnabled = true;
  bool _fullMoonNotificationEnabled = true;

  // Uygulama Bilgileri
  String _appVersion = '1.0.0';

  @override
  void initState() {
    super.initState();
    _loadProfileData();
    _loadNotificationSettings();
    _loadAppVersion();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _birthPlaceController.dispose();
    super.dispose();
  }

  // Profil Verilerini Formu Doldurmak İçin Yükle
  void _loadProfileData() {
    final user = ref.read(userProvider);
    if (user != null) {
      _nameController.text = user.name ?? '';
      _birthPlaceController.text = user.birthPlace ?? '';
      _birthDate = user.birthDate;
      _birthTime = user.birthTime;
      _gender = user.gender;
    }
  }

  // Bildirim Ayarlarını SharedPreferences'tan Yükle
  Future<void> _loadNotificationSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _dailyNotificationEnabled = prefs.getBool('daily_notification_enabled') ?? true;
        _fullMoonNotificationEnabled = prefs.getBool('full_moon_notification_enabled') ?? true;
      });
    } catch (_) {}
  }

  // Sürüm Bilgisi Yükle
  Future<void> _loadAppVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      setState(() {
        _appVersion = packageInfo.version;
      });
    } catch (_) {}
  }

  // Profil Kaydetme
  Future<void> _saveProfile() async {
    final user = ref.read(userProvider);
    if (user == null) return;

    setState(() {
      _isSavingProfile = true;
    });

    // Burcu hesapla
    String? recalculatedZodiac;
    if (_birthDate != null) {
      recalculatedZodiac = AstrologyUtils.calculateZodiacSign(_birthDate!.day, _birthDate!.month);
    }

    try {
      await ref.read(userProvider.notifier).updateProfile(
        name: _nameController.text.trim(),
        birthDate: _birthDate,
        birthTime: _birthTime,
        birthPlace: _birthPlaceController.text.trim(),
        gender: _gender,
        zodiacSign: recalculatedZodiac,
      );

      setState(() {
        _isProfileEditing = false;
        _isSavingProfile = false;
      });

      if (mounted) {
        final isTr = ref.read(languageProvider).languageCode == 'tr';
        CustomToast.show(
          context,
          isTr ? 'Profil güncellendi ve yıldızlar yeniden hizalandı! ✨' : 'Profile updated and stars realigned! ✨',
        );
      }
    } catch (e) {
      setState(() {
        _isSavingProfile = false;
      });
      if (mounted) {
        final isTr = ref.read(languageProvider).languageCode == 'tr';
        CustomToast.show(
          context,
          isTr ? 'Hata oluştu, lütfen tekrar deneyin.' : 'An error occurred, please try again.',
          isError: true,
        );
      }
    }
  }

  // Tarih ve Saat Seçimi
  Future<void> _selectBirthDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(2000, 1, 1),
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
    if (picked != null) {
      setState(() {
        _birthDate = picked;
      });
    }
  }

  Future<void> _selectBirthTime(BuildContext context) async {
    int initialHour = 12;
    int initialMinute = 0;
    
    if (_birthTime != null) {
      final parts = _birthTime!.split(':');
      if (parts.length == 2) {
        initialHour = int.parse(parts[0]);
        initialMinute = int.parse(parts[1]);
      }
    }

    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: initialHour, minute: initialMinute),
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

    if (picked != null) {
      final String formattedTime = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      setState(() {
        _birthTime = formattedTime;
      });
    }
  }

  Future<void> _selectBirthPlace(BuildContext context) async {
    final selected = await BirthPlaceSearchSheet.show(context);
    if (selected != null) {
      setState(() {
        _birthPlaceController.text = selected;
      });
    }
  }

  // Dil Değiştirme
  void _changeLanguage(WidgetRef ref, String languageCode) {
    HapticFeedback.selectionClick();
    ref.read(languageProvider.notifier).changeLanguage(languageCode);
  }

  // Bildirim Toggle
  Future<void> _toggleDailyNotification(bool value) async {
    HapticFeedback.lightImpact();
    setState(() {
      _dailyNotificationEnabled = value;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('daily_notification_enabled', value);
      
      final notificationService = NotificationService();
      if (value) {
        await notificationService.scheduleDaily4AmNotification();
      } else {
        await notificationService.cancelDailyNotification();
      }
    } catch (_) {}
  }

  Future<void> _toggleFullMoonNotification(bool value) async {
    HapticFeedback.lightImpact();
    setState(() {
      _fullMoonNotificationEnabled = value;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('full_moon_notification_enabled', value);
    } catch (_) {}
  }

  // Gizlilik Politikası Aç
  Future<void> _openPrivacyPolicy() async {
    HapticFeedback.lightImpact();
    final url = Uri.parse('https://cervusdigital.com/pickeat/privacy-policy/');
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
  }

  // Hesabı/Uygulamayı Sıfırla
  Future<void> _resetAccount() async {
    final isTr = ref.read(languageProvider).languageCode == 'tr';
    
    // Onay İletişim Kutusu
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardSurface,
        title: Text(
          isTr ? 'Hesabı Sıfırla' : 'Reset Account',
          style: AppTextStyles.h4.copyWith(color: AppColors.primaryGold, fontWeight: FontWeight.bold),
        ),
        content: Text(
          isTr
              ? 'Tüm kişisel bilgileriniz ve onboarding tercihleriniz silinecek. Emin misiniz?'
              : 'All your personal profile data and onboarding choices will be deleted. Are you sure?',
          style: AppTextStyles.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(isTr ? 'İptal' : 'Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Sıfırla / Reset', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      HapticFeedback.heavyImpact();
      
      // 1. SharedPreferences'ı temizle
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      // 2. Riverpod Onboarding durumunu sıfırla
      await ref.read(onboardingCompleteProvider.notifier).resetOnboarding();

      // 3. Bildirimleri iptal et
      await NotificationService().cancelDailyNotification();

      // 4. Tab dizinini sıfırla ve onboarding rotasına git
      ref.read(bottomNavIndexProvider.notifier).state = 0;
      
      if (mounted) {
        context.go('/onboarding');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(languageProvider);
    final isTr = locale.languageCode == 'tr';
    final themeMode = ref.watch(themeProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(isTr ? 'Uygulama Ayarları' : 'App Settings'),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(left: 20.0, right: 20.0, top: 10.0, bottom: 160.0), // bottom nav boşluğu
        child: Column(
          children: [
            // 1. Profil Yönetim Kartı
            _buildProfileSection(isTr),
            const SizedBox(height: 20),

            // Premium Banner
            _buildPremiumBanner(isTr),
            const SizedBox(height: 20),

            // 2. Dil Ayarları Kartı
            _buildLanguageSection(isTr, locale.languageCode),
            const SizedBox(height: 20),

            // Tema Tercihi Kartı
            _buildThemeSection(isTr, themeMode),
            const SizedBox(height: 20),

            // 3. Bildirim Tercihleri Kartı
            _buildNotificationsSection(isTr),
            const SizedBox(height: 20),

            // 4. Hakkında & Sıfırlama Kartı
            _buildAboutSection(isTr),
          ],
        ),
      ),
    );
  }

  // Premium Banner
  Widget _buildPremiumBanner(bool isTr) {
    final user = ref.watch(userProvider);
    final isPremium = user?.isPremium ?? false;

    if (isPremium) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.primaryGold, width: 1.5),
          gradient: LinearGradient(
            colors: [
              AppColors.primaryGold.withValues(alpha: 0.15),
              AppColors.warmAmber.withValues(alpha: 0.05),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Row(
          children: [
            const Icon(Icons.workspace_premium_rounded, color: AppColors.primaryGold, size: 36)
                .animate(onPlay: (controller) => controller.repeat())
                .shimmer(delay: 2000.ms, duration: 1500.ms),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isTr ? "Horoscope Pro Üyesiniz" : "You are a Horoscope Pro Member",
                    style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.bold, color: AppColors.primaryGold),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isTr ? "Tüm kozmik kapılar ve yapay zeka sınırları kalktı. ✨" : "All cosmic gates and AI limits are removed. ✨",
                    style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary, fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
      ).animate().fade(duration: 350.ms);
    }

    // Pro'ya geç bannerı (Göz alıcı, altın ve mor parıltılı)
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primaryGold.withValues(alpha: 0.6), width: 1),
        gradient: LinearGradient(
          colors: [
            const Color(0xFF1D1635),
            AppColors.cardSurface,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryGold.withValues(alpha: 0.1),
            blurRadius: 10,
            spreadRadius: 2,
          )
        ]
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            // Yıldız tozu arka plan efekti
            Positioned(
              right: -20,
              top: -20,
              child: Opacity(
                opacity: 0.3,
                child: Icon(Icons.auto_awesome_outlined, size: 100, color: AppColors.primaryGold.withValues(alpha: 0.5)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(18.0),
              child: Row(
                children: [
                  // Sol ikon
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.primaryGold.withValues(alpha: 0.15),
                    ),
                    child: const Icon(Icons.workspace_premium_rounded, color: AppColors.primaryGold, size: 28)
                        .animate(onPlay: (controller) => controller.repeat())
                        .shake(hz: 2, curve: Curves.easeInOut, duration: 1500.ms),
                  ),
                  const SizedBox(width: 16),
                  // Metin ve Buton
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isTr ? "Horoscope Pro'ya Yükseltin" : "Upgrade to Horoscope Pro",
                          style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.bold, color: AppColors.primaryGold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isTr 
                              ? "Yapay zeka analizlerine sınırsız erişin ve reklamları kaldırın." 
                              : "Access AI readings without limits and remove ads.",
                          style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary, fontSize: 11),
                        ),
                        const SizedBox(height: 12),
                        // Şık, ışıltılı Pro Butonu
                        GestureDetector(
                          onTap: () {
                            HapticFeedback.mediumImpact();
                            PremiumDialogHelper.show(context, ref);
                          },
                          child: Container(
                            height: 38,
                            decoration: BoxDecoration(
                              gradient: AppColors.goldGradient,
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primaryGold.withValues(alpha: 0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                )
                              ]
                            ),
                            child: Center(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.auto_awesome, color: AppColors.textDark, size: 16),
                                  const SizedBox(width: 8),
                                  Text(
                                    isTr ? "PRO'ya Geç" : "Go PRO",
                                    style: TextStyle(
                                      color: AppColors.textDark,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ).animate(onPlay: (controller) => controller.repeat())
                           .shimmer(delay: 3000.ms, duration: 1800.ms),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ).animate().fade(delay: 50.ms, duration: 350.ms);
  }

  // 1. Profil Yönetimi
  Widget _buildProfileSection(bool isTr) {
    if (!_isProfileEditing) {
      final user = ref.watch(userProvider);
      final birthDateStr = user?.birthDate != null
          ? DateFormat('dd MMMM yyyy', isTr ? 'tr' : 'en').format(user!.birthDate!)
          : (isTr ? 'Seçilmedi' : 'Not set');

      return GlassCard(
        child: Row(
          children: [
            const Icon(Icons.account_circle_rounded, size: 48, color: AppColors.primaryGold),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user?.name ?? (isTr ? 'Gezgin' : 'Traveler'),
                    style: AppTextStyles.h4.copyWith(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '$birthDateStr, ${user?.birthPlace ?? ''}',
                    style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.edit_rounded, color: AppColors.primaryGold),
              onPressed: () {
                HapticFeedback.lightImpact();
                _loadProfileData();
                setState(() {
                  _isProfileEditing = true;
                });
              },
            ),
          ],
        ),
      ).animate().fade(duration: 350.ms);
    }

    // Edit Modu
    final dateDisplay = _birthDate == null
        ? (isTr ? 'Tarih Seç' : 'Select Date')
        : DateFormat('dd.MM.yyyy').format(_birthDate!);
    final timeDisplay = _birthTime ?? (isTr ? 'Saat Seç' : 'Select Time');

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isTr ? 'Kozmik Profilini Güncelle' : 'Update Cosmic Profile',
            style: AppTextStyles.label.copyWith(color: AppColors.primaryGold, fontWeight: FontWeight.bold),
          ),
          const Divider(),
          const SizedBox(height: 8),

          // İsim
          TextField(
            controller: _nameController,
            style: TextStyle(color: AppColors.textPrimary),
            decoration: InputDecoration(
              labelText: isTr ? 'Adınız' : 'Your Name',
              labelStyle: TextStyle(color: AppColors.textSecondary),
              prefixIcon: const Icon(Icons.person, color: AppColors.primaryGold),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),

          // Doğum Yeri
          TextField(
            controller: _birthPlaceController,
            readOnly: true,
            style: TextStyle(color: AppColors.textPrimary),
            onTap: () => _selectBirthPlace(context),
            decoration: InputDecoration(
              labelText: isTr ? 'Doğum Yeri' : 'Birth Place',
              labelStyle: TextStyle(color: AppColors.textSecondary),
              prefixIcon: const Icon(Icons.map_rounded, color: AppColors.primaryGold),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),

          // Tarih & Saat Seçimi
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _selectBirthDate(context),
                  icon: const Icon(Icons.calendar_month_rounded, color: AppColors.primaryGold),
                  label: Text(dateDisplay, style: TextStyle(color: AppColors.textPrimary)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _selectBirthTime(context),
                  icon: const Icon(Icons.access_time_rounded, color: AppColors.primaryGold),
                  label: Text(timeDisplay, style: TextStyle(color: AppColors.textPrimary)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
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
                child: ChoiceChip(
                  label: Text(isTr ? 'Kadın' : 'Female'),
                  selected: _gender == 'female',
                  onSelected: (val) {
                    if (val) setState(() { _gender = 'female'; });
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ChoiceChip(
                  label: Text(isTr ? 'Erkek' : 'Male'),
                  selected: _gender == 'male',
                  onSelected: (val) {
                    if (val) setState(() { _gender = 'male'; });
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Butonlar
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () {
                  setState(() { _isProfileEditing = false; });
                },
                child: Text(isTr ? 'İptal' : 'Cancel', style: TextStyle(color: AppColors.textSecondary)),
              ),
              const SizedBox(width: 12),
              _isSavingProfile
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryGold))
                  : GradientButton(
                      width: 120,
                      text: isTr ? 'Kaydet' : 'Save',
                      onTap: _saveProfile,
                    ),
            ],
          ),
        ],
      ),
    );
  }

  // 2. Dil Seçimi
  Widget _buildLanguageSection(bool isTr, String activeCode) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isTr ? 'Dil Tercihi' : 'Language Option',
            style: AppTextStyles.label.copyWith(color: AppColors.primaryGold, fontWeight: FontWeight.bold),
          ),
          const Divider(),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => _changeLanguage(ref, 'tr'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: activeCode == 'tr'
                          ? AppColors.primaryGold.withValues(alpha: 0.15)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: activeCode == 'tr' ? AppColors.primaryGold : Colors.white10,
                      ),
                    ),
                    child: Column(
                      children: [
                        const Text('🇹🇷', style: TextStyle(fontSize: 24)),
                        const SizedBox(height: 4),
                        Text(
                          'Türkçe',
                          style: AppTextStyles.label.copyWith(
                            fontWeight: activeCode == 'tr' ? FontWeight.bold : FontWeight.normal,
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
                  onTap: () => _changeLanguage(ref, 'en'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: activeCode == 'en'
                          ? AppColors.primaryGold.withValues(alpha: 0.15)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: activeCode == 'en' ? AppColors.primaryGold : Colors.white10,
                      ),
                    ),
                    child: Column(
                      children: [
                        const Text('🇬🇧', style: TextStyle(fontSize: 24)),
                        const SizedBox(height: 4),
                        Text(
                          'English',
                          style: AppTextStyles.label.copyWith(
                            fontWeight: activeCode == 'en' ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    ).animate().fade(delay: 80.ms, duration: 350.ms);
  }

  // 2b. Tema Seçimi
  Widget _buildThemeSection(bool isTr, ThemeMode themeMode) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isTr ? 'Tema Tercihi' : 'Theme Preference',
            style: AppTextStyles.label.copyWith(color: AppColors.primaryGold, fontWeight: FontWeight.bold),
          ),
          const Divider(),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    ref.read(themeProvider.notifier).changeThemeMode(ThemeMode.light);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: themeMode == ThemeMode.light
                          ? AppColors.primaryGold.withValues(alpha: 0.15)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: themeMode == ThemeMode.light ? AppColors.primaryGold : AppColors.borderLight,
                      ),
                    ),
                    child: Column(
                      children: [
                        const Text('☀️', style: TextStyle(fontSize: 24)),
                        const SizedBox(height: 4),
                        Text(
                          isTr ? 'Açık' : 'Light',
                          style: AppTextStyles.label.copyWith(
                            fontWeight: themeMode == ThemeMode.light ? FontWeight.bold : FontWeight.normal,
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
                    HapticFeedback.lightImpact();
                    ref.read(themeProvider.notifier).changeThemeMode(ThemeMode.dark);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: themeMode == ThemeMode.dark
                          ? AppColors.primaryGold.withValues(alpha: 0.15)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: themeMode == ThemeMode.dark ? AppColors.primaryGold : AppColors.borderLight,
                      ),
                    ),
                    child: Column(
                      children: [
                        const Text('🔮', style: TextStyle(fontSize: 24)),
                        const SizedBox(height: 4),
                        Text(
                          isTr ? 'Karanlık' : 'Dark',
                          style: AppTextStyles.label.copyWith(
                            fontWeight: themeMode == ThemeMode.dark ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    ).animate().fade(delay: 120.ms, duration: 350.ms);
  }

  // 3. Bildirimler
  Widget _buildNotificationsSection(bool isTr) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isTr ? 'Kozmik Bildirimler' : 'Cosmic Notifications',
            style: AppTextStyles.label.copyWith(color: AppColors.primaryGold, fontWeight: FontWeight.bold),
          ),
          const Divider(),
          // Günlük Yorum
          SwitchListTile(
            title: Text(isTr ? 'Günlük Burç Yorumu' : 'Daily Horoscope', style: AppTextStyles.bodyMedium),
            subtitle: Text(
              isTr ? 'Her sabah 04.00\'da gökyüzü raporu hazır olduğunda haber ver' : 'Notify every morning at 04:00 when cosmic report is ready',
              style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary, fontSize: 10),
            ),
            value: _dailyNotificationEnabled,
            activeColor: AppColors.primaryGold,
            onChanged: _toggleDailyNotification,
          ),
          const Divider(height: 1, color: Colors.white12),
          // Dolunay
          SwitchListTile(
            title: Text(isTr ? 'Dolunay Hatırlatıcısı' : 'Full Moon Reminder', style: AppTextStyles.bodyMedium),
            subtitle: Text(
              isTr ? 'Dolunay ve Yeniay dönemlerindeki kozmik hasat zamanlarında haber ver' : 'Notify during full moon and new moon dates',
              style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary, fontSize: 10),
            ),
            value: _fullMoonNotificationEnabled,
            activeColor: AppColors.primaryGold,
            onChanged: _toggleFullMoonNotification,
          ),
        ],
      ),
    ).animate().fade(delay: 160.ms, duration: 350.ms);
  }

  // 4. Hakkında & Hesap Sıfırlama
  Widget _buildAboutSection(bool isTr) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isTr ? 'Uygulama Hakkında' : 'About Application',
            style: AppTextStyles.label.copyWith(color: AppColors.primaryGold, fontWeight: FontWeight.bold),
          ),
          const Divider(),
          // Gizlilik Politikası
          ListTile(
            leading: const Icon(Icons.privacy_tip_rounded, color: AppColors.primaryGold),
            title: Text(isTr ? 'Gizlilik Politikası' : 'Privacy Policy', style: AppTextStyles.bodyMedium),
            trailing: Icon(Icons.chevron_right, color: AppColors.textSecondary),
            onTap: _openPrivacyPolicy,
          ),
          const Divider(height: 1, color: Colors.white12),
          // Sürüm
          ListTile(
            leading: const Icon(Icons.info_outline, color: AppColors.primaryGold),
            title: Text(isTr ? 'Sürüm' : 'Version', style: AppTextStyles.bodyMedium),
            trailing: Text(
              _appVersion,
              style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary, fontWeight: FontWeight.bold),
            ),
          ),
          const Divider(height: 1, color: Colors.white12),
          // Hesabı Sıfırla
          ListTile(
            leading: const Icon(Icons.delete_forever_rounded, color: Colors.redAccent),
            title: Text(
              isTr ? 'Hesabı Sıfırla' : 'Reset Account',
              style: AppTextStyles.bodyMedium.copyWith(color: Colors.redAccent, fontWeight: FontWeight.bold),
            ),
            onTap: _resetAccount,
          ),
        ],
      ),
    ).animate().fade(delay: 240.ms, duration: 350.ms);
  }

}
