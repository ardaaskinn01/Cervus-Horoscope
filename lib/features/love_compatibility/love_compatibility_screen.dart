import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_animate/flutter_animate.dart';
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
import 'package:horoscope/core/services/limit_service.dart';
import 'package:horoscope/shared/widgets/limit_dialog_helper.dart';
import 'package:horoscope/shared/widgets/premium_dialog_helper.dart';

import 'package:horoscope/core/utils/date_formatter.dart';

class LoveCompatibilityScreen extends ConsumerStatefulWidget {
  const LoveCompatibilityScreen({super.key});

  @override
  ConsumerState<LoveCompatibilityScreen> createState() => _LoveCompatibilityScreenState();
}

class _LoveCompatibilityScreenState extends ConsumerState<LoveCompatibilityScreen> {
  final _nameController = TextEditingController();
  final _dateController = TextEditingController();
  DateTime? _selectedDate;
  TimeOfDay? _partnerBirthTime;
  bool _knowsPartnerBirthTime = true;
  String? _partnerBirthPlace;
  String _selectedGender = 'female'; // 'male' or 'female'
  String _selectedRelationshipStatus = 'dating'; // 'dating' | 'new_relationship' | 'long_term_relationship' | 'newlywed' | 'long_term_marriage' | 'ex_relationship'
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

  Future<void> _deleteHistoryItem(CompatibilityModel item) async {
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
                      ? '${item.partnerName} ile olan aşk uyumu analizini silmek istediğinize emin misiniz?'
                      : 'Are you sure you want to delete the love compatibility analysis with ${item.partnerName}?',
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
      final docPath = 'users/${user.uid}/compatibility/${item.partnerName}_${item.type}';
      await FirebaseFirestore.instance.doc(docPath).delete();

      if (mounted) {
        setState(() {
          _history.removeWhere((x) => x.partnerName == item.partnerName && x.type == item.type);
          if (_result?.partnerName == item.partnerName && _result?.type == item.type) {
            _result = null;
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

  @override
  void dispose() {
    _nameController.dispose();
    _dateController.dispose();
    super.dispose();
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
      });
    }
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

    final limitStatus = await LimitService.instance.checkLimit('love_compatibility');
    if (limitStatus == LimitStatus.locked) {
      LimitDialogHelper.showDailyLimitReachedDialog(context: context, ref: ref);
      return;
    } else if (limitStatus == LimitStatus.needAd) {
      LimitDialogHelper.showAdRequiredDialog(
        context: context,
        ref: ref,
        featureKey: 'love_compatibility',
        onAdCompleted: () {
          _executeCalculation(user.uid);
        },
      );
      return;
    }

    _executeCalculation(user.uid);
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
        relationshipStatus: _selectedRelationshipStatus,
      );

      if (compatibility != null) {
        await LimitService.instance.registerCalculation('love_compatibility');
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
          isPremium: user?.isAnyPremium ?? false,
        ),
      ),
    );
  }

  // Form Ekranı
  Widget _buildFormView(bool isTr, String userName, String userSign) {
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
          GlassCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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
                  });
                } else {
                  setState(() {
                    _selectedDate = null;
                  });
                }
              },
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: isTr ? 'Doğum Tarihi (GG.AA.YYYY)' : 'Birth Date (DD.MM.YYYY)',
                hintStyle: const TextStyle(color: Colors.white38),
                icon: const Icon(Icons.calendar_month_rounded, color: AppColors.primaryGold),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.arrow_drop_down, color: AppColors.primaryGold),
                  onPressed: () => _selectDate(context),
                ),
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

          // İlişki Durumu Başlığı
          Text(
            isTr ? 'İlişki Durumu' : 'Relationship Status',
            style: AppTextStyles.label.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 8),

          // İlişki Durumu Seçimi Dropdown
          GlassCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedRelationshipStatus,
                isExpanded: true,
                dropdownColor: AppColors.cardSurface,
                icon: const Icon(Icons.arrow_drop_down, color: AppColors.primaryGold),
                style: AppTextStyles.bodyLarge.copyWith(color: AppColors.textPrimary),
                items: [
                  DropdownMenuItem(
                    value: 'dating',
                    child: Text(isTr ? 'Flört' : 'Dating'),
                  ),
                  DropdownMenuItem(
                    value: 'new_relationship',
                    child: Text(isTr ? 'Yeni İlişki' : 'New Relationship'),
                  ),
                  DropdownMenuItem(
                    value: 'long_term_relationship',
                    child: Text(isTr ? 'Uzun İlişki' : 'Long-Term Relationship'),
                  ),
                  DropdownMenuItem(
                    value: 'newlywed',
                    child: Text(isTr ? 'Yeni Evli' : 'Newlywed'),
                  ),
                  DropdownMenuItem(
                    value: 'long_term_marriage',
                    child: Text(isTr ? 'Uzun Süreli Evli' : 'Long-Term Marriage'),
                  ),
                  DropdownMenuItem(
                    value: 'ex_relationship',
                    child: Text(isTr ? 'Eski İlişki' : 'Ex Relationship'),
                  ),
                ],
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _selectedRelationshipStatus = val;
                    });
                  }
                },
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Cinsiyet Başlığı
          Text(
            isTr ? 'Cinsiyet' : 'Gender',
            style: AppTextStyles.label.copyWith(color: AppColors.textSecondary),
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
                    child: Stack(
                      children: [
                        Positioned.fill(
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
                                      Padding(
                                        padding: const EdgeInsets.only(right: 16.0),
                                        child: Text(
                                          '%${item.overallScore}',
                                          style: AppTextStyles.label.copyWith(
                                            color: AppColors.primaryGold,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
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
                                size: 14,
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
    final isPro = user.isAnyPremium;

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
                if (res.relationshipStatus != null) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primaryGold.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.primaryGold.withValues(alpha: 0.3), width: 0.8),
                    ),
                    child: Text(
                      _getRelationshipStatusTrName(res.relationshipStatus!, isTr),
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.primaryGold,
                        fontWeight: FontWeight.bold,
                        fontSize: 9.5,
                      ),
                    ),
                  ),
                ],
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

          // ── Diğer bölümler PRO durumuna göre ──────────────────────────
          if (!isPro) ...[
            _buildProLockedSection(
              title: isTr ? '🔭 Sinastri Açıları' : '🔭 Synastry Aspects',
              isTr: isTr, minHeight: 160,
            ),
            const SizedBox(height: 20),
            _buildProLockedSection(
              title: isTr ? '✨ Kozmik Bağlantı Noktaları' : '✨ Cosmic Connection Points',
              isTr: isTr, minHeight: 160,
            ),
            const SizedBox(height: 20),
            _buildProLockedSection(
              title: isTr ? '📊 Aşk Boyutları' : '📊 Love Dimensions',
              isTr: isTr, minHeight: 160,
            ),
            const SizedBox(height: 20),
            _buildProLockedSection(
              title: isTr ? '🔮 Kozmik Yorum' : '🔮 Cosmic Commentary',
              isTr: isTr, minHeight: 120,
            ),
            const SizedBox(height: 20),
            _buildProLockedSection(
              title: isTr ? '🔮 Ruh Eşi & Karmik Bağlar' : '🔮 Soul Connection & Karmic Bonds',
              isTr: isTr, minHeight: 120,
            ),
            const SizedBox(height: 20),
            _buildProLockedSection(
              title: isTr ? '🛡️ İletişim & Çatışma Çözümü' : '🛡️ Communication & Conflict Resolution',
              isTr: isTr, minHeight: 120,
            ),
            const SizedBox(height: 20),
            _buildProLockedSection(
              title: isTr ? '⏳ Gelecek Kozmik Zaman Tüneli' : '⏳ Future Cosmic Timeline',
              isTr: isTr, minHeight: 120,
            ),
            const SizedBox(height: 32),
          ] else ...[
            // ── 2. Sinastri Açıları Tablosu
            if (res.synastrAspects != null && res.synastrAspects!.isNotEmpty) ...[
              Align(
                alignment: Alignment.centerLeft,
                child: Text(isTr ? '🔭 Sinastri Açıları' : '🔭 Synastry Aspects', style: AppTextStyles.h3),
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
                Builder(
                  builder: (context) {
                    final currentUser = ref.watch(userProvider);
                    int getAge(DateTime bDate) {
                      final now = DateTime.now();
                      int age = now.year - bDate.year;
                      if (now.month < bDate.month || (now.month == bDate.month && now.day < bDate.day)) {
                        age--;
                      }
                      return age;
                    }
                    final bool isUnder18 = (currentUser?.isUnder18 ?? false) || getAge(res.partnerBirthDate) < 18;
                    return ScoreBar(
                      label: isUnder18
                          ? (isTr ? 'Çekim ve Uyum' : 'Attraction & Energy')
                          : (isTr ? 'Cinsellik ve Çekim' : 'Sexuality & Chemistry'),
                      value: res.scores['sexualityScore'] ?? 70,
                      icon: Icons.flash_on_rounded,
                    );
                  },
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

  Widget _buildProLockedSection({
    required String title,
    required bool isTr,
    double minHeight = 100,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AppTextStyles.h3),
        const SizedBox(height: 10),
        GestureDetector(
          onTap: () => PremiumDialogHelper.show(context, ref),
          child: Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: ImageFiltered(
                  imageFilter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                  child: Container(
                    width: double.infinity,
                    constraints: BoxConstraints(minHeight: minHeight),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (int i = 0; i < 4; i++)
                          Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            height: 11,
                            width: i == 1 ? 160 : double.infinity,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: i == 0 ? 0.45 : 0.18),
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.primaryGold.withValues(alpha: 0.4)),
                  ),
                  constraints: BoxConstraints(minHeight: minHeight),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.primaryGold.withValues(alpha: 0.15),
                          border: Border.all(color: AppColors.primaryGold.withValues(alpha: 0.5)),
                        ),
                        child: const Icon(Icons.lock_rounded, color: AppColors.primaryGold, size: 28),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        isTr ? 'PRO\'ya Geç' : 'Unlock with PRO',
                        style: AppTextStyles.label.copyWith(
                          color: AppColors.primaryGold,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
  String _getRelationshipStatusTrName(String status, bool isTr) {
    switch (status) {
      case 'dating':
        return isTr ? 'Flört' : 'Dating';
      case 'new_relationship':
        return isTr ? 'Yeni İlişki' : 'New Relationship';
      case 'long_term_relationship':
        return isTr ? 'Uzun İlişki' : 'Long-Term Relationship';
      case 'newlywed':
        return isTr ? 'Yeni Evli' : 'Newlywed';
      case 'long_term_marriage':
        return isTr ? 'Uzun Süreli Evli' : 'Long-Term Marriage';
      case 'ex_relationship':
        return isTr ? 'Eski İlişki' : 'Ex Relationship';
      default:
        return isTr ? 'Bilinmiyor' : 'Unknown';
    }
  }
}
